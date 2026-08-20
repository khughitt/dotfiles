local Logic = require("./logic.luau")
local Shell = require("./shell.luau")

local state = {
  busy = false,
  loading = false,
  errorText = nil,
  currentPath = nil,
  sourcePath = nil,
  parsedDate = nil,
  displayDate = nil,
}

local render
local refresh

local function clearCurrent()
  state.currentPath = nil
  state.sourcePath = nil
  state.parsedDate = nil
  state.displayDate = nil
end

local function trimmed(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function resultError(result, label)
  if result.timedOut then return label .. " timed out" end
  if result.exitCode ~= 0 then
    local stderr = trimmed(result.stderr)
    return stderr ~= "" and stderr or label .. " exited " .. tostring(result.exitCode)
  end
  return nil
end

local function run(argv, callback)
  return noctalia.runAsync(Shell.command(argv), callback, 10000)
end

local function finishCurrent(result)
  state.busy = false
  state.loading = false
  local message = resultError(result, "walictl current")
  local payload
  if not message then payload, message = Logic.decodeCurrent(result.stdout, noctalia.json.decode) end
  if message then
    clearCurrent()
    state.errorText = message
  else
    state.currentPath = payload.current_wallpaper_path
    state.sourcePath = payload.source_wallpaper_path
    state.parsedDate = payload.parsed_date
    state.displayDate = payload.display_date
    state.errorText = nil
  end
  render()
end

refresh = function()
  if not Logic.canStart(state.busy) then return end
  state.busy = true
  state.loading = true
  state.errorText = nil
  clearCurrent()
  render()
  if not run(Logic.commandFor("current"), finishCurrent) then
    state.busy = false
    state.loading = false
    state.errorText = "Failed to launch walictl current"
    render()
  end
end

local function finishAction(action, result)
  state.busy = false
  local message = resultError(result, "walictl " .. action)
  if message then
    state.errorText = message
    render()
    return
  end
  if Logic.refreshAfter(action) then refresh() end
  if action == "save-current" then
    noctalia.notify("Wali Panel", "Saved the current wallpaper")
  elseif action == "edit-current" then
    noctalia.notify("Wali Panel", "Opened the current wallpaper in GIMP")
  else
    return
  end
  state.errorText = nil
  render()
end

local function startAction(action)
  if not Logic.canStart(state.busy) then return end
  local argv = Logic.commandFor(action)
  state.busy = true
  state.errorText = nil
  render()
  if not run(argv, function(result) finishAction(action, result) end) then
    state.busy = false
    state.errorText = "Failed to launch walictl " .. action
    render()
  end
end

local function copySource()
  if not Logic.canCopy(state.sourcePath) then return end
  if noctalia.copyToClipboard(state.sourcePath, "text/plain") then
    state.errorText = nil
  else
    state.errorText = "Failed to copy the source wallpaper path"
  end
  render()
end

local function preview()
  local path = state.currentPath or state.sourcePath
  if path then
    return ui.image({ path = path, width = 520, height = 430, radius = 12, fit = "contain" })
  end
  return ui.box({ width = 520, height = 430, radius = 12, fill = "surface_variant" }, {
    ui.glyph({ name = state.loading and "loader" or "wallpaper", size = 56, color = "on_surface_variant" }),
  })
end

render = function()
  local subprocessEnabled = not state.busy
  panel.render(ui.column({ flexGrow = 1, gap = 12 }, {
    ui.row({ align = "center", gap = 8 }, {
      ui.label({ text = "Wali Panel", fontSize = 18, fontWeight = "bold", flexGrow = 1 }),
      ui.label({ text = state.loading and "Loading…" or "", color = "on_surface_variant" }),
    }),
    preview(),
    ui.column({ gap = 4 }, {
      ui.label({ text = "Source: " .. (state.sourcePath or "Unavailable"), color = "on_surface_variant", maxLines = 2 }),
      ui.label({ text = "Parsed date: " .. (state.parsedDate or "Unavailable"), color = "on_surface_variant" }),
      ui.label({ text = "Display date: " .. (state.displayDate or "Unavailable"), color = "on_surface_variant" }),
      ui.label({ text = state.errorText or "", color = "error", visible = state.errorText ~= nil, maxLines = 3 }),
    }),
    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.button({ text = "Refresh", glyph = "refresh", enabled = subprocessEnabled, onClick = function() refresh() end }),
      ui.button({ text = "Previous", glyph = "arrow-left", enabled = subprocessEnabled,
        onClick = function() startAction("backward") end }),
      ui.button({ text = "Next", glyph = "arrow-right", enabled = subprocessEnabled,
        onClick = function() startAction("forward") end }),
      ui.button({ text = "Random", glyph = "dice", enabled = subprocessEnabled,
        onClick = function() startAction("random") end }),
    }),
    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.button({ text = "Save", glyph = "heart", enabled = subprocessEnabled,
        onClick = function() startAction("save-current") end }),
      ui.button({ text = "Edit", glyph = "photo-edit", enabled = subprocessEnabled,
        onClick = function() startAction("edit-current") end }),
      ui.button({ text = "Copy", glyph = "clipboard", enabled = Logic.canCopy(state.sourcePath),
        onClick = copySource }),
    }),
  }))
end

function onOpen(_context)
  refresh()
end
