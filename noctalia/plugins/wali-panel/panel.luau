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

local frameWidth, frameHeight = 540, 304

local function frame()
  if state.current then
    return ui.image({
      path = state.current.path, width = frameWidth, height = frameHeight, radius = 14, fit = "contain",
      border = "outline/0.5", borderWidth = 1,
    })
  end
  return ui.box({
    width = frameWidth, height = frameHeight, radius = 14, fill = "surface_variant",
    border = "outline/0.5", borderWidth = 1,
  }, {
    ui.glyph({ name = state.loading and "loader" or "wallpaper", size = 48, color = "on_surface_variant/0.6" }),
  })
end

local function caption(current, enabled)
  local favorite = current ~= nil and current.favorite
  local detail = Logic.captionDetail(current, state.errorText)
  return ui.row({ align = "center", gap = 12 }, {
    ui.column({ gap = 2, flexGrow = 1 }, {
      ui.row({ align = "center", gap = 8 }, {
        ui.label({ text = Logic.captionTitle(current), fontSize = 20, fontWeight = "semibold", maxLines = 1 }),
        ui.label({ text = "variant", fontSize = 11, fontWeight = "medium", color = "tertiary",
          visible = current ~= nil and current.variant_path ~= nil }),
      }),
      ui.label({ text = detail.text, fontSize = 12, fontFamily = "monospace", color = detail.color, maxLines = 2 }),
    }),
    ui.button({ key = "favorite", glyph = Logic.favoriteGlyph(favorite), glyphSize = 22,
      selected = favorite == true, variant = "ghost", controlSize = "md",
      tooltip = favorite and "Remove favorite" or "Favorite",
      enabled = enabled and current ~= nil, onClick = function() startAction("favorite") end }),
  })
end

local function navButton(key, glyph, tooltip, enabled, variant)
  return ui.button({ key = key, glyph = glyph, glyphSize = 20, variant = variant or "outline", controlSize = "md",
    width = 56, tooltip = tooltip, enabled = enabled, onClick = function() startAction(key) end })
end

local function utilityButton(key, glyph, tooltip, enabled, onClick)
  return ui.button({ key = key, glyph = glyph, glyphSize = 16, variant = "ghost", controlSize = "sm",
    tooltip = tooltip, enabled = enabled, onClick = onClick })
end

local function actions(current, enabled)
  local loaded = enabled and current ~= nil
  return ui.row({ align = "center", gap = 8 }, {
    navButton("previous", "arrow-left", "Previous", enabled),
    navButton("next", "arrow-right", "Next", enabled),
    navButton("random", "dice", "Random", enabled, "primary"),
    ui.spacer({ flexGrow = 1 }),
    utilityButton("refresh", "refresh", "Refresh", enabled, function() refresh() end),
    utilityButton("edit", "photo-edit", "Edit in GIMP", loaded, function() startAction("edit") end),
    utilityButton("copy", "clipboard", "Copy source path", current ~= nil, copyPath),
  })
end

render = function()
  local enabled = not state.busy
  local current = state.current
  panel.render(ui.column({ flexGrow = 1, gap = 16, padding = 24 }, {
    frame(),
    caption(current, enabled),
    actions(current, enabled),
  }))
end

function onOpen(_context)
  refresh()
end
