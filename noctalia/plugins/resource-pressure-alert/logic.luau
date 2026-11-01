local M = {}
local GiB = 2^30
local function finite(v)
  return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge
end
local function percent(v) return finite(v) and v>=0 and v<=100 end
local function copy(value)
  local result={}
  for k,v in pairs(value) do result[k]=v end
  return result
end

function M.normalize(plugin, monitor)
  local result={families={},diagnostics={},monitorCommand=plugin.monitorCommand,excludedMounts=plugin.excludedMounts}
  local function diagnostic(id,message)
    result.diagnostics[#result.diagnostics+1]={id='config:'..id,message=message,dismissible=false}
  end
  local anyEnabled=false
  for _,kind in ipairs({'memory','cpu','disk'}) do
    local critical=monitor[({memory='ram_pct',cpu='cpu_usage',disk='disk_used_pct'})[kind]..'_critical_threshold']
    local enabled=plugin[kind..'Enabled']~=false and critical~=0
    result.families[kind]={kind=kind,enabled=enabled,criticalPercent=critical}
    anyEnabled=anyEnabled or enabled
  end
  if not anyEnabled then return result end
  if monitor.enabled~=true then
    diagnostic('monitor','Enable system.monitor to sample enabled alert families.')
    for _,p in pairs(result.families) do p.enabled=false end
    return result
  end
  for _,group in ipairs({'cpu','memory','network','gpu'}) do
    local poll=monitor[group..'_poll_seconds']
    if finite(poll) and poll>0 and poll<=6 then
      result.driverPollSeconds=math.min(result.driverPollSeconds or poll,poll)
    end
  end
  for _,kind in ipairs({'memory','cpu','disk'}) do
    local p=result.families[kind]
    if p.enabled then
      local problem=nil
      local poll=monitor[kind..'_poll_seconds']
      if not percent(p.criticalPercent) then problem='Critical threshold must be a finite percentage.'
      elseif not finite(poll) or poll<=0 then problem=kind..'_poll_seconds must be positive.'
      elseif kind=='cpu' and poll>6 then problem='cpu_poll_seconds must be at most six seconds.' end
      if not problem then
        p.pollMs=poll*1000
        p.graceMs=math.max(30000,2*p.pollMs+2000)
        p.entryMs=0
        if kind=='cpu' then
          local seconds=plugin.cpuCriticalSeconds
          p.criticalRecoveryPercent=math.max(0,p.criticalPercent-5)
          if not finite(seconds) or seconds<=0 or seconds%1~=0 then problem='CPU duration must be positive whole seconds.'
          elseif p.criticalRecoveryPercent<=0 then problem='CPU critical threshold must allow a positive recovery boundary.'
          else p.entryMs=seconds*1000 end
        else
          p.warningPercent=plugin[kind..'WarningPercent']
          if not percent(p.warningPercent) or p.warningPercent<=0 or p.warningPercent>=p.criticalPercent then
            problem='Warning must be positive and below the shared critical threshold.'
          else
            p.warningRecoveryPercent=kind=='memory' and math.min(65,p.warningPercent-5) or math.max(0,p.warningPercent-5)
            p.criticalRecoveryPercent=math.max(p.warningPercent,p.criticalPercent-5)
            if p.warningRecoveryPercent<0 then problem='Warning threshold must allow a nonnegative recovery boundary.' end
          end
        end
        if kind=='disk' and not problem then
          local warning,critical=plugin.diskWarningFreeGiB,plugin.diskCriticalFreeGiB
          if not finite(warning) or not finite(critical) or critical<=0 or warning<=critical then
            problem='Disk free-space floors must be positive, critical below warning.'
          elseif not result.driverPollSeconds then
            problem='Disk liveness needs a CPU, memory, network or GPU poll interval from one to six seconds.'
          elseif type(plugin.excludedMounts)~='table' then problem='excludedMounts must be a string list.'
          else
            for _,path in ipairs(plugin.excludedMounts) do
              if type(path)~='string' or path=='' then problem='excludedMounts must contain nonempty strings.' end
            end
            p.warningFreeBytes=warning*GiB;p.criticalFreeBytes=critical*GiB
            p.warningRecoveryFreeBytes=(warning+10)*GiB;p.criticalRecoveryFreeBytes=(critical+5)*GiB
          end
        end
      end
      if problem then p.enabled=false;diagnostic(kind,problem) end
    end
  end
  return result
end

function M.initial()
  return {episode=0,generation=0,active=false,level='normal',visible=false,
    warningAcknowledged=false,criticalAcknowledged=false,criticalLatched=false}
end
local function reset(s)
  local next=M.initial();next.episode=s.episode;next.generation=s.generation
  return next
end

function M.reduce(state,event,p)
  assert(p and p.enabled,'Reducer requires an enabled policy.')
  local s=copy(state)
  if event.type=='dismiss' then
    if s.visible and event.episode==s.episode and event.generation==s.generation then
      if s.level=='critical' then s.criticalAcknowledged=true else s.warningAcknowledged=true end
      s.visible=false
    end
    return s
  end
  assert(event.type=='sample','Unknown resource alert event.')
  assert(percent(event.percent),'Sample must be a finite percentage from zero to100.')
  local value=event.percent
  local free=event.availableBytes
  if p.kind=='disk' then assert(finite(free) and free>=0,'Disk availability must be nonnegative bytes.') end
  if p.kind=='cpu' then
    assert(finite(event.monoMs) and finite(event.sampleWallMs),'CPU requires both clock readings.')
    if s.lastMonoMs and (event.monoMs<s.lastMonoMs or event.sampleWallMs<s.lastWallMs
        or event.monoMs-s.lastMonoMs>9000 or event.sampleWallMs-s.lastWallMs>9000) then
      s.pendingSinceMs=nil
    end
    s.lastMonoMs=event.monoMs;s.lastWallMs=event.sampleWallMs
    if s.active then
      if value<p.criticalRecoveryPercent then return reset(s) end
    else
      if value<p.criticalPercent then s.pendingSinceMs=nil;return s end
      if s.pendingSinceMs==nil then s.pendingSinceMs=event.monoMs end
      if event.monoMs-s.pendingSinceMs<p.entryMs then return s end
      s.active=true;s.episode=s.episode+1;s.generation=s.generation+1
    end
    s.level='critical';s.criticalLatched=true;s.visible=not s.criticalAcknowledged
    return s
  end
  local recovered=value<p.warningRecoveryPercent
    or (p.kind=='disk' and free>=p.warningRecoveryFreeBytes)
  if recovered then return reset(s) end
  local warning=value>=p.warningPercent and (p.kind~='disk' or free<p.warningFreeBytes)
  local critical=value>=p.criticalPercent and (p.kind~='disk' or free<p.criticalFreeBytes)
  if not s.active then
    if not warning then return s end
    s.active=true;s.episode=s.episode+1;s.generation=s.generation+1
  end
  if critical and not s.criticalLatched then
    s.criticalLatched=true;s.warningAcknowledged=false;s.generation=s.generation+1
  elseif s.criticalLatched and (value<p.criticalRecoveryPercent
      or (p.kind=='disk' and free>=p.criticalRecoveryFreeBytes)) then
    s.criticalLatched=false;s.generation=s.generation+1
  end
  s.level=s.criticalLatched and 'critical' or 'warning'
  s.visible=not s.criticalAcknowledged and (s.criticalLatched or not s.warningAcknowledged)
  return s
end
return M
