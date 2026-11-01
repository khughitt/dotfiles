local here=arg[0]:match('(.*/)') or ''
local function encode(v)
  if type(v)~='table' then return tostring(v) end
  local keys={};for k in pairs(v)do keys[#keys+1]=k end
  table.sort(keys,function(a,b)return tostring(a)<tostring(b) end)
  local parts={};for _,k in ipairs(keys)do parts[#parts+1]=tostring(k)..'='..encode(v[k]) end
  return '{'..table.concat(parts,',')..'}'
end
local function fixture()
  local f={renders=0,sent={},launches={},launchOk=true,exists=true,opened=0,palette='dark',
    model={epoch=1,revision=1,monitorCommand={'ghostty','-e','btop'},rows={
      {id='memory',label='Memory',percent=85,usedMb=870,totalMb=1024,level='warning',stale=false,
        episode=1,generation=1,dismissible=true},
      {id='disk:/dev/data',label='/data',percent=96,availableBytes=10*2^30,level='critical',stale=false,
        episode=2,generation=3,dismissible=true}},diagnostics={}}}
  local ui={}
  for _,kind in ipairs({'column','row','label','button','scroll'})do
    ui[kind]=function(props,children)return {kind=kind,props=props,children=children or {}}end
  end
  local callbacks={}
  local env=setmetatable({ui=ui,layer={outputName=function()return 'test-output' end,
    render=function(tree)f.tree=tree;f.renders=f.renders+1 end},
    noctalia={outputs=function()return {{name='test-output',width=640,height=480}}end,
      getColor=function(role)
        assert(role=='surface' or role=='outline_variant','use current semantic palette roles')
        return f.palette..':'..role
      end,json={encode=encode},
      setUpdateInterval=function()end,log=function()end,
      commandExists=function()return f.exists end,
      runAsync=function(argv,callback)assert(callback==nil,'monitor must not be killed by a command-capture timeout')
        f.launches[#f.launches+1]=argv;return f.launchOk end,
      openSettings=function()f.opened=f.opened+1 end,
      state={get=function(k)assert(k=='model');return f.model end,
        watch=function(k,fn)callbacks[k]=fn end,set=function(k,v)f.sent[#f.sent+1]={key=k,value=v}end}}},
    {__index=_G})
  assert(loadfile(here..'layer.luau','t',env))();f.env=env
  function f.refresh()callbacks.model(f.model)end
  function f.find(key)
    local function visit(node)
      if node.props.key==key then return node end
      for _,child in ipairs(node.children)do local found=visit(child);if found then return found end end
    end
    return visit(f.tree)
  end
  function f.text()
    local texts={}
    local function visit(node)
      if node.props.text then texts[#texts+1]=node.props.text end
      for _,child in ipairs(node.children)do visit(child)end
    end
    visit(f.tree);return table.concat(texts,'\n')
  end
  return f
end
local count=0
local function test(name,run)run();count=count+1;print('PASS '..name)end

test('severity is textual, critical sorts first, disk availability is displayed',function()
  local f=fixture();local text=f.text()
  assert(text:find('Critical')<text:find('Warning') and text:find('10.0 GiB available',1,true))
  assert(f.tree.props.width<=640 and f.tree.props.height<=480)
end)
test('dismissal writes one resource token and does not mutate another row',function()
  local f=fixture();f.find('dismiss:memory').props.onClick()
  local sent=f.sent[1]
  assert(sent.key=='dismiss/memory' and sent.value.epoch==1 and sent.value.episode==1 and sent.value.generation==1)
  assert(#f.model.rows==2)
end)
test('stale button refuses to send after a new escalation',function()
  local f=fixture();local action=f.find('dismiss:memory').props.onClick
  f.model.rows[1].generation=2;action();assert(#f.sent==0)
end)
test('stale button refuses to send after service restart',function()
  local f=fixture();local action=f.find('dismiss:memory').props.onClick
  f.model.epoch=2;action();assert(#f.sent==0)
end)
test('configuration diagnostics have settings but no dismiss action',function()
  local f=fixture();f.model.diagnostics={{id='config:cpu',message='CPU poll is disabled',dismissible=false}}
  f.refresh();assert(f.text():find('CPU poll is disabled',1,true))
  assert(not f.find('dismiss:config:cpu'))
  f.find('settings').props.onClick();assert(f.opened==1)
end)
test('source failure diagnostic has its own encoded token',function()
  local f=fixture();f.model.diagnostics={{id='source:memory',message='Memory unavailable',dismissible=true,episode=2,generation=1}}
  f.refresh();f.find('dismiss:source:memory').props.onClick()
  assert(f.sent[1].key=='dismiss/source%3Amemory' and f.sent[1].value.episode==2)
end)
test('unchanged model does not rerender but palette changes repaint',function()
  local f=fixture();local renders=f.renders;f.refresh();f.env.update();assert(f.renders==renders)
  f.palette='light';f.env.update();assert(f.renders==renders+1)
end)
test('last-known samples are explicitly marked stale',function()
  local f=fixture();f.model.rows[1].stale=true;f.refresh()
  assert(f.text():find('last known',1,true))
end)
test('monitor launches the configured argv without capture timeout',function()
  local f=fixture();f.find('monitor').props.onClick()
  assert(#f.launches==1 and f.launches[1][1]=='ghostty' and f.launches[1][3]=='btop')
end)
test('invalid monitor argv cannot launch and failure stays visible',function()
  local f=fixture();f.model.monitorCommand={'ghostty',false};f.refresh()
  f.find('monitor').props.onClick();f.env.update()
  assert(#f.launches==0 and f.text():find('Monitor command',1,true))
end)
test('sparse monitor argv cannot launch',function()
  local f=fixture()
  -- Lua may truncate a sparse sequence's length; exercise the other valid boundary.
  local argv=setmetatable({'ghostty',nil,'btop'},{__len=function()return 3 end})
  f.model.monitorCommand=argv;f.refresh()
  f.find('monitor').props.onClick()
  assert(#f.launches==0 and f.text():find('Monitor command',1,true))
end)
test('missing executable and rejected native launch remain visible',function()
  local f=fixture();f.exists=false;f.find('monitor').props.onClick()
  assert(#f.launches==0 and f.text():find('not available',1,true))
  f.exists=true;f.launchOk=false;f.find('monitor').props.onClick()
  assert(#f.launches==1 and f.text():find('could not start',1,true))
end)
print(string.format('%d resource layer tests passed',count))
