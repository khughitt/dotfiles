local here=arg[0]:match('(.*/)') or ''
local count=0
local function clone(v)
  if type(v)~='table' then return v end
  local out={};for k,value in pairs(v) do out[k]=clone(value) end;return out
end
local function encode(v)
  if type(v)~='table' then return tostring(v) end
  local keys={};for k in pairs(v) do keys[#keys+1]=k end
  table.sort(keys,function(a,b)return tostring(a)<tostring(b) end)
  local out={};for _,k in ipairs(keys) do out[#out+1]=tostring(k)..'='..encode(v[k]) end
  return '{'..table.concat(out,',')..'}'
end
local function fixture()
  local f={ms=0,shared={},watchers={},queue={},logs={},shows=0,hides=0,
    plugin={memoryEnabled=true,cpuEnabled=true,diskEnabled=true,memoryWarningPercent=80,
      diskWarningPercent=90,diskWarningFreeGiB=50,diskCriticalFreeGiB=20,
      cpuCriticalSeconds=300,excludedMounts={},monitorCommand={'ghostty','-e','btop'}},
    monitor={enabled=true,ram_pct_critical_threshold=90,cpu_usage_critical_threshold=90,
      disk_used_pct_critical_threshold=95,cpu_poll_seconds=2,memory_poll_seconds=2,
      disk_poll_seconds=10,network_poll_seconds=3,gpu_poll_seconds=5},
    mounts={{path='/',source='/dev/root',filesystem='ext4'}},
    disks={['/']={usagePercent=50,totalBytes=1000*2^30,availableBytes=500*2^30}},
    snap={sampledAtMs=100000,cpu={usagePercent=10},ram={usagePercent=50,usedMb=500,totalMb=1000}}}
  local function set(k,v)
    f.shared[k]=clone(v)
    for _,fn in ipairs(f.watchers[k] or {}) do f.queue[#f.queue+1]={fn=fn,value=clone(v)} end
  end
  local host={getConfig=function(k) assert(f.plugin[k]~=nil,'undeclared config '..k);return clone(f.plugin[k]) end,
    getSetting=function(k)return f.monitor[k:gsub('^system.monitor%.','')] end,
    systemStats=function()f.snapshotReads=(f.snapshotReads or 0)+1;return clone(f.snap)end,diskMounts=function()return clone(f.mounts)end,
    diskStats=function(p)return clone(f.disks[p])end,setUpdateInterval=function()end,
    log=function(msg)f.logs[#f.logs+1]=msg end,json={encode=encode},
    state={get=function(k)return clone(f.shared[k])end,set=set,watch=function(k,fn)
      f.watchers[k]=f.watchers[k] or {};table.insert(f.watchers[k],fn)
    end},layer={show=function()f.shows=f.shows+1 end,hide=function()f.hides=f.hides+1 end}}
  function f.flush()
    while #f.queue>0 do local q=table.remove(f.queue,1);q.fn(q.value) end
  end
  function f.load()
    f.watchers={};f.queue={}
    local env=setmetatable({noctalia=host,os={clock=function()return f.ms/1000 end},require=function(path)
      assert(path=='./logic.luau');return dofile(here..'logic.luau')
    end},{__index=_G})
    assert(loadfile(here..'service.luau','t',env))();f.env=env
    f.flush()
  end
  function f.tick(ms,stamp)
    f.ms=ms;if f.snap then f.snap.sampledAtMs=stamp or 100000+ms end
    f.env.update();f.flush()
  end
  function f.model()return f.shared.model end
  function f.send(id,token)
    local key=id:gsub('([^%w%-_])',function(c)return string.format('%%%02X',string.byte(c))end)
    set('dismiss/'..key,token)
  end
  function f.config()f.env.onConfigChanged();f.flush()end
  return f
end
local function row(f,id)
  for _,r in ipairs(f.model().rows)do if r.id==id then return r end end
end
local function test(name,fn)fn();count=count+1;print('PASS '..name)end
local function token(f,r)return {epoch=f.model().epoch,episode=r.episode,generation=r.generation}end

test('service publishes a warning from a native memory sample',function()
  local f=fixture();f.snap.ram.usagePercent=80;f.load()
  assert(row(f,'memory').level=='warning' and f.shows>0)
end)
test('cross-entry stale token cannot hide escalation in either order',function()
  local f=fixture();f.snap.ram.usagePercent=80;f.load();local old=token(f,row(f,'memory'))
  f.snap.ram.usagePercent=90;f.tick(2000);local valid=token(f,row(f,'memory'))
  f.send('memory',old);f.send('memory',valid);f.flush();assert(not row(f,'memory'))
  f.snap.ram.usagePercent=60;f.tick(4000);f.snap.ram.usagePercent=90;f.tick(6000)
  valid=token(f,row(f,'memory'));f.send('memory',valid);f.send('memory',old);f.flush()
  assert(not row(f,'memory'))
end)
test('dismissal leaves another resource visible and watcher count bounded',function()
  local f=fixture();f.snap.ram.usagePercent=90;f.disks['/'].usagePercent=96;f.disks['/'].availableBytes=10*2^30;f.load()
  f.send('memory',token(f,row(f,'memory')));f.flush()
  assert(not row(f,'memory') and row(f,'disk:/dev/root'))
  for n=1,1000 do f.snap.ram.usagePercent=n%2==0 and 90 or 60;f.tick(n*2000)end
  assert(#f.watchers['dismiss/memory']==1)
end)
test('service restart rejects old epoch',function()
  local f=fixture();f.snap.ram.usagePercent=90;f.load();local old=token(f,row(f,'memory'))
  f.load();f.send('memory',old);f.flush();assert(row(f,'memory') and f.model().epoch>old.epoch)
end)
test('warming source has grace and dismissible failure episode',function()
  local f=fixture();f.disks['/']=nil;f.load();f.tick(29000)
  assert(#f.model().diagnostics==0)
  f.tick(30000);local d=f.model().diagnostics[1];assert(d and d.dismissible)
  f.send(d.id,token(f,d));f.flush();assert(#f.model().diagnostics==0)
  f.tick(32000);assert(#f.model().diagnostics==0)
  f.disks['/']={usagePercent=50,totalBytes=100*2^30,availableBytes=50*2^30};f.tick(40000)
  f.disks['/']=nil;f.tick(42000);f.tick(72000)
  assert(#f.model().diagnostics==1)
end)
test('unavailable data preserves a dismissed episode without fake recovery',function()
  local f=fixture();f.snap.ram.usagePercent=90;f.load()
  f.send('memory',token(f,row(f,'memory')));f.flush()
  f.snap=nil;f.tick(40000);assert(not row(f,'memory'))
  f.snap={sampledAtMs=144000,cpu={usagePercent=10},ram={usagePercent=95,usedMb=950,totalMb=1000}}
  f.tick(44000);assert(not row(f,'memory'))
end)
test('stalled aggregate freezes cached disk as last-known',function()
  local f=fixture();f.disks['/'].usagePercent=96;f.disks['/'].availableBytes=10*2^30;f.load()
  f.tick(10000,100000);assert(row(f,'disk:/dev/root').stale)
  f.tick(40000,100000);assert(#f.model().diagnostics>0)
end)
test('critical zero disables before ordering and suppresses diagnostics',function()
  local f=fixture();f.plugin.memoryWarningPercent=99;f.monitor.ram_pct_critical_threshold=0;f.snap.ram=nil
  f.load();f.tick(40000);assert(not row(f,'memory') and #f.model().diagnostics==0)
end)
test('disk-only polling explains dependency and never enables polling',function()
  local f=fixture();f.plugin.memoryEnabled=false;f.plugin.cpuEnabled=false
  for _,g in ipairs({'cpu','memory','network','gpu'})do f.monitor[g..'_poll_seconds']=0 end
  f.load();assert(#f.model().diagnostics==1 and f.model().diagnostics[1].message:find('liveness'))
  assert(f.monitor.cpu_poll_seconds==0)
end)
test('monitor disabled is consolidated and nondismissible',function()
  local f=fixture();f.monitor.enabled=false;f.load()
  assert(#f.model().diagnostics==1 and not f.model().diagnostics[1].dismissible)
end)
test('CPU tolerates six-second polling observation jitter and enters after duration',function()
  local f=fixture();f.monitor.cpu_poll_seconds=6;f.snap.cpu.usagePercent=90;f.load()
  local t=0
  for n=1,50 do t=t+(n%2==0 and 8000 or 4000);f.tick(t) end
  assert(t==300000 and row(f,'cpu'))
end)
test('CPU suspend or rollback resets pending duration',function()
  local f=fixture();f.snap.cpu.usagePercent=90;f.load()
  for t=2000,200000,2000 do f.tick(t)end
  f.tick(202000,400000)
  for t=204000,302000,2000 do f.tick(t,198000+t)end
  assert(not row(f,'cpu'))
end)
test('confirmed removal and remount reject old disk tokens',function()
  local f=fixture();f.disks['/'].usagePercent=96;f.disks['/'].availableBytes=10*2^30;f.load()
  local old=token(f,row(f,'disk:/dev/root'));f.mounts={};f.disks['/']=nil;f.tick(2000)
  assert(not row(f,'disk:/dev/root'))
  f.mounts={{path='/',source='/dev/root',filesystem='ext4'}}
  f.disks['/']={usagePercent=96,totalBytes=100*2^30,availableBytes=10*2^30};f.tick(4000)
  f.send('disk:/dev/root',old);f.flush();assert(row(f,'disk:/dev/root'))
end)
test('discovery failure preserves existing disk episodes as stale',function()
  local f=fixture();f.disks['/'].usagePercent=96;f.disks['/'].availableBytes=10*2^30;f.load()
  f.mounts=nil;f.tick(2000);assert(row(f,'disk:/dev/root').stale)
end)
test('boot and duplicate mounts are excluded while root remains included',function()
  local f=fixture();f.disks['/'].usagePercent=96;f.disks['/'].availableBytes=10*2^30
  f.mounts={
    {path='/',source='/dev/root'}, {path='/alias',source='/dev/root'},
    {path='/boot',source='/dev/boot'}, {path='/boot/efi',source='/dev/efi'}, {path='/efi',source='/dev/efi2'}}
  f.load();assert(#f.model().rows==1 and row(f,'disk:/dev/root'))
end)
test('correcting invalid configuration restores monitoring',function()
  local f=fixture();f.plugin.memoryWarningPercent=90;f.snap.ram.usagePercent=85;f.load()
  assert(#f.model().diagnostics==1 and not row(f,'memory'))
  f.plugin.memoryWarningPercent=80;f.config();f.tick(2000)
  assert(#f.model().diagnostics==0 and row(f,'memory'))
end)
test('malformed memory sample is unknown rather than false recovery',function()
  local f=fixture();f.snap.ram.usagePercent=90;f.load()
  f.snap.ram.usagePercent=0/0;f.tick(2000)
  assert(row(f,'memory').stale and row(f,'memory').level=='critical')
end)
test('zero memory polling disarms its family',function()
  local f=fixture();f.monitor.memory_poll_seconds=0;f.load()
  assert(#f.model().diagnostics==1 and not row(f,'memory'))
end)
test('duplicate aggregate snapshots cannot earn CPU entry',function()
  local f=fixture();f.snap.cpu.usagePercent=90;f.load()
  for t=2000,302000,2000 do f.tick(t,100000)end
  assert(not row(f,'cpu') and #f.model().diagnostics>0)
end)
test('exact nine-second continuity passes and an extra millisecond resets',function()
  for _,gap in ipairs({9000,9001})do
    local f=fixture();f.snap.cpu.usagePercent=90;f.load()
    for t=2000,290000,2000 do f.tick(t)end
    f.tick(290000+gap);f.tick(292000+gap)
    assert((row(f,'cpu')~=nil)==(gap==9000))
  end
end)
test('disabling every family avoids opting into native probes',function()
  local f=fixture();f.plugin.memoryEnabled=false;f.plugin.cpuEnabled=false;f.plugin.diskEnabled=false
  f.load();f.tick(2000)
  assert((f.snapshotReads or 0)==0 and #f.model().rows==0 and #f.model().diagnostics==0)
end)
print(string.format('%d resource service tests passed',count))
