local Logic = require('./logic.luau')
local previous=noctalia.state.get('model')
local epoch=previous and previous.epoch+1 or 1
local records={}
local sourceErrors={}
local watched={}
local config=nil
local signatures={}
local lastStamp=nil
local lastChange=nil
local lastObservation=nil
local revision=0
local modelSignature=nil
local rootId=nil
local rootSource=nil
local publish
local function finite(v)return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge end
local function percentage(v)return finite(v) and v>=0 and v<=100 end
local function slot(id)
  return 'dismiss/'..id:gsub('([^%w%-_])',function(c)return string.format('%%%02X',string.byte(c))end)
end
local function watch(id)
  if watched[id] then return end
  watched[id]=true
  local function receive(token)
    if type(token)~='table' or token.epoch~=epoch then return end
    local source=sourceErrors[id]
    if source and source.visible and token.episode==source.episode and token.generation==source.generation then
      source.acknowledged=true;source.visible=false;publish();return
    end
    local r=records[id]
    if r and r.present and r.policy.enabled then
      r.state=Logic.reduce(r.state,{type='dismiss',episode=token.episode,generation=token.generation},r.policy)
      publish()
    end
  end
  noctalia.state.watch(slot(id),receive)
  local existing=noctalia.state.get(slot(id))
  if existing~=nil then receive(existing) end
end
local function resetRecord(r)
  local old=r.state
  r.state=Logic.initial();r.state.episode=old.episode;r.state.generation=old.generation+1
  r.lastConsumed=nil;r.data=nil;r.stale=true
  local e=sourceErrors['source:'..r.id]
  if e then e.unknown=false;e.visible=false;e.acknowledged=false end
end
local function ensure(id,kind,label,policy,now)
  local r=records[id]
  if not r then
    r={id=id,kind=kind,label=label,state=Logic.initial(),stale=true,policy=policy,present=true}
    records[id]=r
    sourceErrors['source:'..id]={id='source:'..id,episode=0,generation=0,unknown=false,visible=false}
    watch(id);watch('source:'..id)
  elseif not r.present then resetRecord(r) end
  r.present=true;r.policy=policy;r.label=label
  return r
end
local function unknown(r,now)
  r.stale=true;r.state.pendingSinceMs=nil
  local e=sourceErrors['source:'..r.id]
  if not e.unknown then
    e.unknown=true;e.since=now;e.episode=e.episode+1;e.generation=e.generation+1;e.acknowledged=false
    noctalia.log('Resource alert source unavailable: '..r.label)
  end
  e.message=r.label..' source unavailable; enable/inspect System Monitor sampling.'
  e.visible=not e.acknowledged and now-e.since>=r.policy.graceMs
end
local function accept(r,data,now,stamp)
  local e=sourceErrors['source:'..r.id]
  e.unknown=false;e.visible=false;e.acknowledged=false
  r.stale=false;r.data=data
  -- Continuity follows observations, including those skipped by the native poll cadence.
  local s=r.state
  if r.kind=='cpu' and s.lastMonoMs and (now<s.lastMonoMs or stamp<s.lastWallMs
      or now-s.lastMonoMs>9000 or stamp-s.lastWallMs>9000) then s.pendingSinceMs=nil end
  if r.lastConsumed==nil or now-r.lastConsumed>=r.policy.pollMs then
    r.state=Logic.reduce(s,{type='sample',percent=data.percent,availableBytes=data.availableBytes,
      monoMs=now,sampleWallMs=stamp},r.policy)
    r.lastConsumed=now
  end
  if r.kind=='cpu' then r.state.lastMonoMs=now;r.state.lastWallMs=stamp end
end
local function readConfig()
  local plugin={}
  for _,key in ipairs({'memoryEnabled','cpuEnabled','diskEnabled','memoryWarningPercent','diskWarningPercent',
      'diskWarningFreeGiB','diskCriticalFreeGiB','cpuCriticalSeconds','excludedMounts','monitorCommand'}) do
    plugin[key]=noctalia.getConfig(key)
  end
  local monitor={}
  for _,key in ipairs({'enabled','ram_pct_critical_threshold','cpu_usage_critical_threshold','disk_used_pct_critical_threshold',
      'cpu_poll_seconds','memory_poll_seconds','disk_poll_seconds','network_poll_seconds','gpu_poll_seconds'})do
    local value=noctalia.getSetting('system.monitor.'..key)
    if key:find('_poll_seconds$') and finite(value) and value>0 then value=math.max(1,math.min(120,value)) end
    monitor[key]=value
  end
  config=Logic.normalize(plugin,monitor)
  for kind,p in pairs(config.families)do
    local signature=noctalia.json.encode(p)
    if signatures[kind] and signatures[kind]~=signature then
      for _,r in pairs(records)do if r.kind==kind then resetRecord(r)end end
    end
    signatures[kind]=signature
  end
end
publish=function()
  local rows,diagnostics={},{}
  for _,d in ipairs(config.diagnostics)do diagnostics[#diagnostics+1]=d end
  for _,r in pairs(records)do
    if r.present and r.policy.enabled then
      if r.state.visible and r.data then
        rows[#rows+1]={id=r.id,label=r.label,percent=r.data.percent,availableBytes=r.data.availableBytes,
          usedMb=r.data.usedMb,totalMb=r.data.totalMb,level=r.state.level,stale=r.stale,
          episode=r.state.episode,generation=r.state.generation,dismissible=true}
      end
      local e=sourceErrors['source:'..r.id]
      if e.visible then
        diagnostics[#diagnostics+1]={id=e.id,message=e.message,dismissible=true,
          episode=e.episode,generation=e.generation}
      end
    end
  end
  table.sort(rows,function(a,b)
    if a.level~=b.level then return a.level=='critical' end
    return a.id<b.id
  end)
  table.sort(diagnostics,function(a,b)return a.id<b.id end)
  local model={epoch=epoch,rows=rows,diagnostics=diagnostics,monitorCommand=config.monitorCommand}
  local signature=noctalia.json.encode(model)
  if signature~=modelSignature then
    modelSignature=signature;revision=revision+1;model.revision=revision
    noctalia.state.set('model',model)
  end
  local visible=#rows>0 or #diagnostics>0
  -- Native settings reload can replace a layer without restarting this service.
  if visible then noctalia.layer.show('banner') else noctalia.layer.hide('banner') end
end
function update()
  local now=os.clock()*1000
  readConfig()
  local wantsSamples=false
  for _,p in pairs(config.families)do wantsSamples=wantsSamples or p.enabled end
  local snapshot=wantsSamples and noctalia.systemStats() or nil
  local stamp=snapshot and snapshot.sampledAtMs
  local changed=finite(stamp) and stamp~=lastStamp
  if changed then
    if lastStamp and stamp<lastStamp then
      for _,r in pairs(records)do r.state.pendingSinceMs=nil end
    end
    lastStamp=stamp;lastChange=now
  end
  if lastObservation and (now<lastObservation or now-lastObservation>9000) then
    for _,r in pairs(records)do r.state.pendingSinceMs=nil end
  end
  lastObservation=now
  local live=finite(stamp) and lastChange~=nil and now-lastChange<=9000
  for _,kind in ipairs({'memory','cpu'})do
    local p=config.families[kind]
    if p.enabled then
      local r=ensure(kind,kind,kind=='cpu' and 'CPU' or 'Memory',p,now)
      local data=snapshot and snapshot[kind=='memory' and 'ram' or 'cpu']
      local valid=live and data and percentage(data.usagePercent)
      if kind=='memory' then valid=valid and finite(data.totalMb) and data.totalMb>0
        and finite(data.usedMb) and data.usedMb>=0 and data.usedMb<=data.totalMb end
      if not valid then unknown(r,now)
      elseif changed then accept(r,{percent=data.usagePercent,usedMb=data.usedMb,totalMb=data.totalMb},now,stamp) end
    elseif records[kind] then records[kind].present=false end
  end
  local p=config.families.disk
  if p.enabled then
    local mounts=noctalia.diskMounts()
    if type(mounts)~='table' then
      for _,r in pairs(records)do if r.kind=='disk' and r.present then unknown(r,now)end end
    else
      local discoveryKnown=#mounts>0
      local seen,paths,sources={},{},{}
      local excluded={['/boot']=true,['/boot/efi']=true,['/efi']=true}
      for _,path in ipairs(config.excludedMounts)do excluded[path]=true end
      for _,m in ipairs(mounts)do
        if type(m)=='table' and type(m.path)=='string' and m.path:sub(1,1)=='/'
            and type(m.source)=='string' and not excluded[m.path] and not m.path:match('^/boot/')
            and not sources[m.source] then
          paths[#paths+1]=m;sources[m.source]=true
        end
      end
      local hasRoot=false
      for _,m in ipairs(paths)do if m.path=='/' then hasRoot=true end end
      if not hasRoot and not excluded['/'] then
        paths[#paths+1]={path='/',source='/'}
      end
      for _,m in ipairs(paths)do
        local id='disk:'..m.source
        if m.path=='/' then
          -- Keep a warming root's identity when native discovery later names its device.
          if not rootId or (rootSource and m.source~='/' and rootSource~=m.source) then rootId=id end
          if m.source~='/' then rootSource=m.source end
          id=rootId
        end
        seen[id]=true
        local r=ensure(id,'disk',m.path,p,now)
        local data=noctalia.diskStats(m.path)
        if not live or not data or not percentage(data.usagePercent) or not finite(data.totalBytes)
            or data.totalBytes<=0 or not finite(data.availableBytes) or data.availableBytes<0
            or data.availableBytes>data.totalBytes then unknown(r,now)
        elseif r.lastConsumed==nil or now-r.lastConsumed>=p.pollMs then
          accept(r,{percent=data.usagePercent,availableBytes=data.availableBytes},now,stamp)
        end
      end
      for id,r in pairs(records)do
        if r.kind=='disk' and r.present and not seen[id] then
          -- Native empty discovery also means read failure; it cannot confirm removal.
          if discoveryKnown then r.present=false;resetRecord(r) else unknown(r,now)end
        end
      end
    end
  else
    for _,r in pairs(records)do if r.kind=='disk' then r.present=false end end
  end
  publish()
end
function onConfigChanged() update() end
noctalia.setUpdateInterval(2000)
update()
