local signature=nil
local launchError=nil
local refresh

local function dismiss(id,epoch,episode,generation)
  local current=noctalia.state.get('model')
  if not current or current.epoch~=epoch then return end
  for _,items in ipairs({current.rows,current.diagnostics}) do
    for _,row in ipairs(items) do
      if row.id==id and row.dismissible and row.episode==episode and row.generation==generation then
        local key='dismiss/'..id:gsub('([^%w%-_])',function(c)return string.format('%%%02X',string.byte(c))end)
        noctalia.state.set(key,{epoch=epoch,episode=episode,generation=generation})
        return
      end
    end
  end
end

local function monitor()
  local current=noctalia.state.get('model')
  local argv=current and current.monitorCommand
  local valid=type(argv)=='table' and #argv>0
  if valid then
    local count=0
    for k,v in pairs(argv) do
      count=count+1
      if type(k)~='number' or k%1~=0 or k<1 or k>#argv or type(v)~='string' or v=='' or v:find('\0',1,true) then
        valid=false;break
      end
    end
    valid=valid and count==#argv
  end
  if not valid then launchError='Monitor command must be a nonempty argv of strings.'
  elseif not noctalia.commandExists(argv[1]) then launchError='Monitor executable is not available: '..argv[1]
  -- shortcut: detached launch confirms queueing only; use a native launch-status API when available.
  elseif not noctalia.runAsync(argv) then launchError='Monitor could not start.'
  else launchError=nil end
  refresh()
end

refresh=function()
  local model=noctalia.state.get('model')
  if not model then return end
  local width,height
  for _,output in ipairs(noctalia.outputs()) do
    if output.name==layer.outputName() then width=output.width;height=output.height;break end
  end
  if not width or not height then return end
  local surface=noctalia.getColor('surface')
  local outline=noctalia.getColor('outline_variant')
  local nextSignature=noctalia.json.encode({model=model,surface=surface,outline=outline,
    width=width,height=height,launchError=launchError})
  if signature==nextSignature then return end
  signature=nextSignature
  local items={}
  local rows={}
  for _,row in ipairs(model.rows) do rows[#rows+1]=row end
  table.sort(rows,function(a,b)
    if a.level~=b.level then return a.level=='critical' end
    return a.id<b.id
  end)
  local function add(row,text,color)
    local children={ui.label({text=text,color=color,flexGrow=1,maxLines=4})}
    if row.dismissible then
      local id,epoch,episode,generation=row.id,model.epoch,row.episode,row.generation
      children[#children+1]=ui.button({key='dismiss:'..id,text='Dismiss',
        onClick=function()dismiss(id,epoch,episode,generation)end})
    end
    items[#items+1]=ui.row({key=row.id,gap=12,align='center'},children)
  end
  for _,row in ipairs(rows) do
    local severity=row.level=='critical' and 'Critical' or 'Warning'
    local text=string.format('%s: %s — %.1f%%',severity,row.label,row.percent)
    if row.availableBytes then text=text..string.format(' · %.1f GiB available',row.availableBytes/2^30) end
    if row.usedMb and row.totalMb then text=text..string.format(' · %.1f / %.1f GiB',row.usedMb/1024,row.totalMb/1024) end
    if row.stale then text=text..' (last known)' end
    add(row,text,row.level=='critical' and 'error' or 'tertiary')
  end
  if #model.diagnostics>0 then
    items[#items+1]=ui.label({text='Monitoring diagnostics',color='on_surface_variant'})
    for _,row in ipairs(model.diagnostics) do add(row,row.message,'on_surface_variant') end
  end
  if launchError then items[#items+1]=ui.label({text=launchError,color='error',maxLines=3}) end
  layer.render(ui.column({key='resource-alert',width=math.min(640,width-24),
    height=math.min(height-24,100+76*(#rows+#model.diagnostics)+(launchError and 60 or 0)),
    padding=16,gap=12,radius=12,fill=surface,border=outline,borderWidth=1}, {
    ui.scroll({flexGrow=1,gap=12},items),
    ui.row({gap=12}, {
      ui.button({key='monitor',text='Open monitor',onClick=monitor}),
      ui.button({key='settings',text='Settings',onClick=function()noctalia.openSettings()end}),
    }),
  }))
end

noctalia.state.watch('model',function()refresh()end)
noctalia.setUpdateInterval(2000)
function update()refresh()end
refresh()
