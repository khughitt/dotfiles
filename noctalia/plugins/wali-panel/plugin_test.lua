local here = (arg[0]:match("(.*/)") or "")
local Shell = dofile(here .. "shell.luau")
local Logic = dofile(here .. "logic.luau")

local function equal(actual, expected, message)
  if type(actual) ~= type(expected) then
    error(message or ("expected " .. type(expected) .. ", got " .. type(actual)))
  end
  if type(actual) ~= "table" then
    assert(actual == expected, message or ("expected " .. tostring(expected) .. ", got " .. tostring(actual)))
    return
  end
  for key, value in pairs(expected) do equal(actual[key], value, message) end
  for key in pairs(actual) do assert(expected[key] ~= nil, message or "unexpected key") end
end

local commands = {
  current = { "walictl", "current", "--json" },
  previous = { "walictl", "previous" },
  next = { "walictl", "next" },
  random = { "walictl", "random" },
  favorite = { "walictl", "favorite" },
  edit = { "walictl", "edit" },
}

for action, expected in pairs(commands) do equal(Logic.commandFor(action), expected) end
equal(Shell.command({ "walictl", "save-current", "/wall papers/a'b.jpg" }),
  "'walictl' 'save-current' '/wall papers/a'\"'\"'b.jpg'")

local payload = {
  ok = true,
  id = "PXL_20260820_000000000",
  date = "2026-08-20",
  display_date = "August 20, 2026",
  path = "/wall/current.jpg",
  source_path = "/wall/source.jpg",
  variant_path = nil,
  favorite = true,
  history = { cursor = 3, length = 4 },
}
equal(Logic.decodeCurrent("valid", function(text)
  assert(text == "valid")
  return payload
end), payload)

local decoded, decodeError = Logic.decodeCurrent("invalid", function() error("invalid JSON") end)
assert(decoded == nil and type(decodeError) == "string" and decodeError:find("invalid JSON", 1, true))

local invalid, invalidError = Logic.validateCurrent({ source_path = "/wall/source.jpg" })
assert(invalid == nil and type(invalidError) == "string")

for _, field in ipairs({ "date", "display_date", "source_path", "variant_path" }) do
  local candidate = { ok = true, id = "x", path = "/p", favorite = false }
  candidate[field] = 42
  invalid, invalidError = Logic.validateCurrent(candidate)
  assert(invalid == nil and type(invalidError) == "string" and invalidError:find(field, 1, true))
end

for _, field in ipairs({ "id", "path" }) do
  local candidate = { ok = true, id = "x", path = "/p", favorite = false }
  candidate[field] = nil
  invalid, invalidError = Logic.validateCurrent(candidate)
  assert(invalid == nil and type(invalidError) == "string" and invalidError:find(field, 1, true))
end
local invalidFavorite, favoriteError = Logic.validateCurrent({ ok = true, id = "x", path = "/p", favorite = "yes" })
assert(invalidFavorite == nil and favoriteError:find("favorite", 1, true))

for _, action in ipairs({ "previous", "next", "random", "favorite" }) do
  assert(Logic.refreshAfter(action), action .. " must refresh current wallpaper metadata")
end
assert(not Logic.refreshAfter("current"))
assert(not Logic.refreshAfter("edit"))
assert(Logic.canStart(false))
assert(not Logic.canStart(true))
equal(Logic.copyTarget({ path = "/p", source_path = "/s" }), "/s")
equal(Logic.copyTarget({ path = "/p" }), "/p")
equal(Logic.favoriteGlyph(true), "heart-filled")
equal(Logic.favoriteGlyph(false), "heart")
equal(Logic.captionTitle(payload), "August 20, 2026")
equal(Logic.captionTitle({ ok = true, id = "x", path = "/p", favorite = false, date = "2026-08-20" }), "2026-08-20")
equal(Logic.captionTitle({ ok = true, id = "x", path = "/p", favorite = false }), "x")
equal(Logic.captionTitle(nil), "")
equal(Logic.captionDetail(payload, nil), { text = "PXL_20260820_000000000", color = "on_surface_variant" })
equal(Logic.captionDetail(payload, "walictl next exited 1"), { text = "walictl next exited 1", color = "error" })
equal(Logic.captionDetail(nil, nil), { text = "", color = "on_surface_variant" })
equal(Logic.captionDetail(nil, "boom"), { text = "boom", color = "error" })

local rendered
local runs = {}
local clipboardCalls = {}
local toggledPanel
local widgetGlyph

noctalia = {
  copyToClipboard = function(text, mimeType)
    clipboardCalls[#clipboardCalls + 1] = { text, mimeType }
    return true
  end,
  json = {
    decode = function(text)
      if text == "with source" then return payload end
      if text == "without source" then
        return { ok = true, id = "n", path = "/wall/next.jpg", favorite = false }
      end
      return nil, "invalid JSON"
    end,
  },
  notify = function() end,
  runAsync = function(command, callback, timeout)
    runs[#runs + 1] = { command = command, callback = callback, timeout = timeout }
    return true
  end,
  togglePanel = function(id) toggledPanel = id end,
}

barWidget = {
  setGlyph = function(glyph) widgetGlyph = glyph end,
  setTooltip = function() end,
}
dofile(here .. "widget.luau")
equal(widgetGlyph, "wallpaper")
onClick()
equal(toggledPanel, "khughitt/wali-panel:panel")

panel = { render = function(tree) rendered = tree end }
ui = {}
for _, name in ipairs({ "box", "button", "column", "glyph", "image", "label", "row", "spacer" }) do
  local nodeType = name
  ui[nodeType] = function(props, children)
    return { type = nodeType, props = props or {}, children = children or {} }
  end
end

local realRequire = require
require = function(path)
  if path == "./logic.luau" then return dofile(here .. "logic.luau") end
  if path == "./shell.luau" then return dofile(here .. "shell.luau") end
  return realRequire(path)
end
dofile(here .. "panel.luau")
require = realRequire

local function button(node, key)
  if node.type == "button" and node.props.key == key then return node end
  for _, child in ipairs(node.children) do
    local found = button(child, key)
    if found then return found end
  end
  return nil
end

local function success(stdout)
  return { exitCode = 0, stdout = stdout or "", stderr = "", timedOut = false }
end

local function find(node, nodeType)
  if node.type == nodeType then return node end
  for _, child in ipairs(node.children) do
    local found = find(child, nodeType)
    if found then return found end
  end
  return nil
end

onOpen({})
assert(find(rendered, "box") == nil, "ui.box cannot hold children; the placeholder frame must be a container")
local placeholderGlyph = assert(find(rendered, "glyph"), "placeholder frame lost its glyph")
equal(placeholderGlyph.props.name, "loader")
equal(#runs, 1)
equal(runs[1].command, Shell.command(commands.current))
equal(runs[1].timeout, 10000)
runs[1].callback(success("with source"))

local copy = assert(button(rendered, "copy"))
assert(copy.props.enabled)
copy.props.onClick()
equal(clipboardCalls, { { "/wall/source.jpg", "text/plain" } })

assert(button(rendered, "previous")).props.onClick()
equal(#runs, 2)
equal(runs[2].command, Shell.command(commands.previous))
local nextWhileBusy = assert(button(rendered, "next"))
assert(not nextWhileBusy.props.enabled)
nextWhileBusy.props.onClick()
equal(#runs, 2, "a second action started while the first was busy")

runs[2].callback(success())
equal(#runs, 3, "successful navigation did not refresh current metadata")
equal(runs[3].command, Shell.command(commands.current))
runs[3].callback(success("without source"))

local copyWithoutSource = assert(button(rendered, "copy"))
assert(copyWithoutSource.props.enabled)
copyWithoutSource.props.onClick()
equal(clipboardCalls, {
  { "/wall/source.jpg", "text/plain" },
  { "/wall/next.jpg", "text/plain" },
})

runs[3].callback(success("with source"))
local favorite = assert(button(rendered, "favorite"))
equal(favorite.props.glyph, "heart-filled")
equal(favorite.props.selected, true)
assert(favorite.props.color == nil, "ui.button has no color prop; the host ignores it")
assert(favorite.props.text == nil, "favorite must be glyph-only")
for _, key in ipairs({ "refresh", "previous", "next", "random", "edit", "copy" }) do
  local node = assert(button(rendered, key), key .. " button missing")
  assert(node.props.text == nil, key .. " must be glyph-only")
  assert(type(node.props.tooltip) == "string" and node.props.tooltip ~= "", key .. " needs a tooltip")
end
favorite.props.onClick()
equal(runs[#runs].command, Shell.command(commands.favorite))
runs[#runs].callback(success("favorited PXL_20260820_000000000"))
equal(runs[#runs].command, Shell.command(commands.current), "favorite did not refresh metadata")
runs[#runs].callback(success("without source"))
local unfavorited = assert(button(rendered, "favorite"))
equal(unfavorited.props.glyph, "heart")
equal(unfavorited.props.selected, false)

assert(type(onKey) == "function", "panel must handle captured keys")
for _, binding in ipairs({
  { "h", "previous" }, { "Left", "previous" }, { "l", "next" }, { "Right", "next" },
  { "k", "earlier" }, { "Up", "earlier" }, { "j", "later" }, { "Down", "later" },
  { "r", "random" }, { "f", "favorite" }, { "e", "edit" },
}) do
  local count = #runs
  onKey(binding[1], false)
  equal(#runs, count, "release must not act")
  onKey(binding[1], true)
  equal(#runs, count + 1)
  equal(runs[#runs].command, "'walictl' '" .. binding[2] .. "'")
  onKey("r", true)
  equal(#runs, count + 1, "keyboard action bypassed the busy guard")
  runs[#runs].callback(success())
  if binding[2] ~= "edit" then
    equal(runs[#runs].command, "'walictl' 'current' '--json'")
    runs[#runs].callback(success("with source"))
  end
end

local count = #clipboardCalls
onKey("y", true)
equal(clipboardCalls[count + 1], { "/wall/source.jpg", "text/plain" })
local runCount = #runs
onKey("unknown", true)
equal(#runs, runCount)
onKey("shift+question", true)
assert(find(rendered, "image") == nil, "help must replace the preview")
onKey("shift+question", false)
assert(find(rendered, "image") == nil, "release must leave help open")
onKey("shift+question", true)
assert(find(rendered, "image") ~= nil, "help must toggle back to the preview")
onKey("F1", true)
assert(find(rendered, "image") == nil, "unshifted help key must open help")
onKey("F1", false)
assert(find(rendered, "image") == nil)
onKey("F1", true)
assert(find(rendered, "image") ~= nil)
assert(button(rendered, "help")).props.onClick()
assert(find(rendered, "image") == nil)
onOpen({})
runs[#runs].callback(success("with source"))
assert(find(rendered, "image") ~= nil, "opening must reset help")

onKey("l", true)
runs[#runs].callback({ exitCode = 1, stdout = "", stderr = "navigation failed", timedOut = false })
assert(button(rendered, "next")).props.onClick()
equal(runs[#runs].command, "'walictl' 'next'", "failure must release the busy guard")
runs[#runs].callback(success())
runs[#runs].callback(success("invalid current"))
runCount = #runs
count = #clipboardCalls
for _, chord in ipairs({ "f", "e", "y", "j", "k" }) do onKey(chord, true) end
equal(#runs, runCount, "photo actions require loaded metadata")
equal(#clipboardCalls, count)

print("Wali plugin tests passed")
