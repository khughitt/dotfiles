local Logic = require("./logic.luau")
local Shell = require("./shell.luau")

local state = { busy = false, loading = false, errorText = nil, current = nil }

local render
local refresh

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
    state.current = nil
    state.errorText = message
  else
    state.current = payload
    state.errorText = nil
  end
  render()
end

refresh = function()
  if not Logic.canStart(state.busy) then return end
  state.busy = true
  state.loading = true
  state.errorText = nil
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
  state.errorText = nil
  if Logic.refreshAfter(action) then
    refresh()
    return
  end
  if action == "edit" then noctalia.notify("Wali Panel", trimmed(result.stdout)) end
  render()
end

local function startAction(action)
  if not Logic.canStart(state.busy) then return end
  state.busy = true
  state.errorText = nil
  render()
  if not run(Logic.commandFor(action), function(result) finishAction(action, result) end) then
    state.busy = false
    state.errorText = "Failed to launch walictl " .. action
    render()
  end
end

local function copyPath()
  if not state.current then return end
  if noctalia.copyToClipboard(Logic.copyTarget(state.current), "text/plain") then
    state.errorText = nil
  else
    state.errorText = "Failed to copy the wallpaper path"
  end
  render()
end

local function preview()
  if state.current then
    return ui.image({ path = state.current.path, width = 520, height = 430, radius = 12, fit = "contain" })
  end
  return ui.box({ width = 520, height = 430, radius = 12, fill = "surface_variant" }, {
    ui.glyph({ name = state.loading and "loader" or "wallpaper", size = 56, color = "on_surface_variant" }),
  })
end

local function line(label, value)
  return ui.label({ text = label .. ": " .. (value or "Unavailable"), color = "on_surface_variant", maxLines = 2 })
end

render = function()
  local enabled = not state.busy
  local current = state.current
  local favorite = current ~= nil and current.favorite
  panel.render(ui.column({ flexGrow = 1, gap = 12 }, {
    ui.row({ align = "center", gap = 8 }, {
      ui.label({ text = "Wali Panel", fontSize = 18, fontWeight = "bold", flexGrow = 1 }),
      ui.label({ text = state.loading and "Loading…" or "", color = "on_surface_variant" }),
    }),
    preview(),
    ui.column({ gap = 4 }, {
      line("Taken", current and current.display_date),
      line("Favorite", current and (favorite and "yes" or "no")),
      line("Source", current and current.source_path),
      ui.label({ text = "Variant: " .. (current and current.variant_path or ""), color = "on_surface_variant",
        visible = current ~= nil and current.variant_path ~= nil, maxLines = 2 }),
      ui.label({ text = state.errorText or "", color = "error", visible = state.errorText ~= nil, maxLines = 3 }),
    }),
    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.button({ text = "Refresh", glyph = "refresh", enabled = enabled, onClick = function() refresh() end }),
      ui.button({ text = "Previous", glyph = "arrow-left", enabled = enabled, onClick = function() startAction("previous") end }),
      ui.button({ text = "Next", glyph = "arrow-right", enabled = enabled, onClick = function() startAction("next") end }),
      ui.button({ text = "Random", glyph = "dice", enabled = enabled, onClick = function() startAction("random") end }),
    }),
    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.button({ text = "Favorite", glyph = Logic.favoriteGlyph(favorite), enabled = enabled and current ~= nil,
        onClick = function() startAction("favorite") end }),
      ui.button({ text = "Edit", glyph = "photo-edit", enabled = enabled and current ~= nil,
        onClick = function() startAction("edit") end }),
      ui.button({ text = "Copy", glyph = "clipboard", enabled = current ~= nil, onClick = copyPath }),
    }),
  }))
end

function onOpen(_context)
  refresh()
end
