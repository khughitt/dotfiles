local here = arg[0]:match('(.*/)') or ''
local Logic = dofile(here .. 'logic.luau')
local count = 0
local function test(name, run)
  run()
  count = count + 1
  print('PASS ' .. name)
end
local function settings()
  return {memoryEnabled=true,cpuEnabled=true,diskEnabled=true,memoryWarningPercent=80,
    diskWarningPercent=90,diskWarningFreeGiB=50,diskCriticalFreeGiB=20,
    cpuCriticalSeconds=300,excludedMounts={},monitorCommand={'ghostty','-e','btop'}}
end
local function monitor()
  return {enabled=true,ram_pct_critical_threshold=90,cpu_usage_critical_threshold=90,
    disk_used_pct_critical_threshold=95,cpu_poll_seconds=2,memory_poll_seconds=2,
    disk_poll_seconds=10,network_poll_seconds=3,gpu_poll_seconds=5}
end
local function policies() return Logic.normalize(settings(), monitor()).families end
local function sample(s, p, percent, free, ms)
  return Logic.reduce(s,{type='sample',percent=percent,availableBytes=free and free*2^30,
    monoMs=ms or 0,sampleWallMs=ms or 0},p)
end
local function dismiss(s,p)
  return Logic.reduce(s,{type='dismiss',episode=s.episode,generation=s.generation},p)
end
local function cpuUntil(s,p,percent,start,finish)
  for ms=start,finish,2000 do s=sample(s,p,percent,nil,ms) end
  return s
end

test('memory warning and critical boundaries',function()
  local p=policies().memory
  assert(not sample(Logic.initial(),p,79).visible)
  local s=sample(Logic.initial(),p,80)
  assert(s.level=='warning' and s.visible)
  s=sample(s,p,90)
  assert(s.level=='critical' and s.visible)
  s=sample(s,p,85)
  assert(s.level=='critical')
  s=sample(s,p,84)
  assert(s.level=='warning')
  assert(sample(s,p,65).active)
  assert(not sample(s,p,64).active)
end)
test('dismissed warning escalates and downgrades visibly',function()
  local p=policies().memory
  local s=dismiss(sample(Logic.initial(),p,80),p)
  assert(not s.visible)
  s=sample(s,p,90)
  assert(s.visible and s.level=='critical')
  s=sample(s,p,84)
  assert(s.visible and s.level=='warning')
end)
test('critical dismissal lasts until recovery then rearms',function()
  local p=policies().memory
  local s=dismiss(sample(Logic.initial(),p,90),p)
  local episode=s.episode
  assert(not sample(s,p,95).visible)
  assert(not sample(s,p,84).visible)
  s=sample(s,p,64)
  s=sample(s,p,80)
  assert(s.visible and s.episode>episode)
end)
test('stale episode and severity clicks do not hide current alert',function()
  local p=policies().memory
  local s=sample(Logic.initial(),p,80)
  local old={type='dismiss',episode=s.episode,generation=s.generation}
  s=sample(s,p,90)
  assert(Logic.reduce(s,old,p).visible)
  s=sample(s,p,64);s=sample(s,p,90)
  assert(Logic.reduce(s,old,p).visible)
end)
test('disks require percentage and strict free-space floor',function()
  local p=policies().disk
  for _,v in ipairs({{92,614},{94,241},{91,332},{89,1},{90,50}}) do
    assert(not sample(Logic.initial(),p,v[1],v[2]).visible)
  end
  local s=sample(Logic.initial(),p,90,49)
  assert(s.visible and s.level=='warning')
  s=sample(s,p,95,20);assert(s.level=='warning')
  s=sample(s,p,95,19);assert(s.level=='critical')
end)
test('disk recovery is percentage OR available-space with hysteresis',function()
  local p=policies().disk
  local s=sample(Logic.initial(),p,96,19)
  assert(sample(s,p,96,25).level=='warning')
  assert(sample(s,p,89,19).level=='warning')
  assert(not sample(s,p,84,19).active)
  assert(not sample(s,p,96,60).active)
  assert(sample(s,p,96,59).active)
end)
test('resource dismissals stay independent',function()
  local p=policies()
  local memory=dismiss(sample(Logic.initial(),p.memory,90),p.memory)
  local disk=sample(Logic.initial(),p.disk,96,10)
  assert(not memory.visible and disk.visible)
end)
test('CPU earns five minutes and has no warning',function()
  local p=policies().cpu
  local s=cpuUntil(Logic.initial(),p,90,0,298000)
  s=sample(s,p,90,nil,299999);assert(not s.visible)
  s=sample(s,p,90,nil,300000);assert(s.visible and s.level=='critical')
  assert(sample(s,p,85,nil,302000).active)
  s=sample(s,p,84,nil,304000);assert(not s.active)
  s=sample(s,p,90,nil,306000);assert(not s.visible)
end)
test('a CPU dip resets pending entry',function()
  local p=policies().cpu
  local s=cpuUntil(Logic.initial(),p,90,0,200000)
  s=sample(s,p,89,nil,202000)
  s=cpuUntil(s,p,90,204000,400000)
  assert(not s.visible)
end)
test('CPU continuity resets on wall or monotonic gap above nine seconds',function()
  local p=policies().cpu
  local s=sample(Logic.initial(),p,90,nil,0)
  s=Logic.reduce(s,{type='sample',percent=90,monoMs=2000,sampleWallMs=12000},p)
  assert(s.pendingSinceMs==2000)
  s=sample(s,p,90,nil,12000)
  assert(s.pendingSinceMs==12000)
end)
test('activity tint does not change warning policy',function()
  local m=monitor();m.ram_pct_activity_threshold=5;m.cpu_usage_activity_threshold=99
  local c=Logic.normalize(settings(),m)
  assert(c.families.memory.warningPercent==80 and c.families.cpu.warningPercent==nil)
end)
test('critical zero disables before warning ordering validation',function()
  local m=monitor();m.ram_pct_critical_threshold=0
  local s=settings();s.memoryWarningPercent=99
  local c=Logic.normalize(s,m)
  assert(not c.families.memory.enabled and #c.diagnostics==0)
end)
test('invalid warning ordering disarms only its family',function()
  local s=settings();s.memoryWarningPercent=90
  local c=Logic.normalize(s,monitor())
  assert(not c.families.memory.enabled and c.families.disk.enabled and #c.diagnostics==1)
end)
test('fractional critical is retained and nonfinite critical rejected',function()
  local m=monitor();m.ram_pct_critical_threshold=90.5
  assert(Logic.normalize(settings(),m).families.memory.criticalPercent==90.5)
  m.ram_pct_critical_threshold=0/0
  assert(not Logic.normalize(settings(),m).families.memory.enabled)
end)
test('CPU poll above six seconds disarms CPU',function()
  local m=monitor();m.cpu_poll_seconds=7
  local c=Logic.normalize(settings(),m)
  assert(not c.families.cpu.enabled and #c.diagnostics==1)
end)
test('disk-only sampling produces an explicit liveness dependency error',function()
  local m=monitor()
  m.cpu_poll_seconds=0;m.memory_poll_seconds=0;m.network_poll_seconds=0;m.gpu_poll_seconds=0
  local s=settings();s.memoryEnabled=false;s.cpuEnabled=false
  local c=Logic.normalize(s,m)
  assert(not c.families.disk.enabled and #c.diagnostics==1)
  assert(c.diagnostics[1].message:find('liveness'))
end)
test('monitor disabled produces one consolidated configuration error',function()
  local m=monitor();m.enabled=false
  local c=Logic.normalize(settings(),m)
  assert(#c.diagnostics==1 and not c.families.disk.enabled and not c.families.memory.enabled)
end)
test('malformed samples fail explicitly instead of recovering',function()
  local p=policies().memory
  local s=sample(Logic.initial(),p,90)
  local ok=pcall(Logic.reduce,s,{type='sample',percent=0/0,monoMs=0,sampleWallMs=0},p)
  assert(not ok and s.visible)
end)
print(string.format('%d resource policy tests passed',count))
