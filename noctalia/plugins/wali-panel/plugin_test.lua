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
  backward = { "walictl", "backward" },
  forward = { "walictl", "forward" },
  random = { "walictl", "random" },
  ["save-current"] = { "walictl", "save-current" },
  ["edit-current"] = { "walictl", "edit-current" },
}

for action, expected in pairs(commands) do equal(Logic.commandFor(action), expected) end
equal(Shell.command({ "walictl", "save-current", "/wall papers/a'b.jpg" }),
  "'walictl' 'save-current' '/wall papers/a'\"'\"'b.jpg'")

local payload = {
  ok = true,
  current_wallpaper_path = "/wall/current.jpg",
  source_wallpaper_path = "/wall/source.jpg",
  parsed_date = "2026-08-20",
  display_date = "August 20, 2026",
}
equal(Logic.decodeCurrent("valid", function(text)
  assert(text == "valid")
  return payload
end), payload)

local decoded, decodeError = Logic.decodeCurrent("invalid", function() error("invalid JSON") end)
assert(decoded == nil and type(decodeError) == "string" and decodeError:find("invalid JSON", 1, true))

local invalid, invalidError = Logic.validateCurrent({ source_wallpaper_path = "/wall/source.jpg" })
assert(invalid == nil and type(invalidError) == "string")

for _, field in ipairs({
  "current_wallpaper_path", "source_wallpaper_path", "parsed_date", "display_date",
}) do
  local candidate = {
    ok = true,
    current_wallpaper_path = "/wall/current.jpg",
    source_wallpaper_path = "/wall/source.jpg",
    parsed_date = "2026-08-20",
    display_date = "August 20, 2026",
  }
  candidate[field] = 42
  invalid, invalidError = Logic.validateCurrent(candidate)
  assert(invalid == nil and type(invalidError) == "string" and invalidError:find(field, 1, true))
end

for _, action in ipairs({ "backward", "forward", "random" }) do
  assert(Logic.refreshAfter(action), action .. " must refresh current wallpaper metadata")
end
assert(not Logic.refreshAfter("current"))
assert(not Logic.refreshAfter("save-current"))
assert(not Logic.refreshAfter("edit-current"))
assert(Logic.canStart(false))
assert(not Logic.canStart(true))
assert(Logic.canCopy("/wall/source.jpg"))
assert(not Logic.canCopy(nil))

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
        return { ok = true, current_wallpaper_path = "/wall/next.jpg" }
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
for _, name in ipairs({ "box", "button", "column", "glyph", "image", "label", "row" }) do
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

local function button(node, text)
  if node.type == "button" and node.props.text == text then return node end
  for _, child in ipairs(node.children) do
    local found = button(child, text)
    if found then return found end
  end
  return nil
end

local function success(stdout)
  return { exitCode = 0, stdout = stdout or "", stderr = "", timedOut = false }
end

onOpen({})
equal(#runs, 1)
equal(runs[1].command, Shell.command(commands.current))
equal(runs[1].timeout, 10000)
runs[1].callback(success("with source"))

local copy = assert(button(rendered, "Copy"))
assert(copy.props.enabled)
copy.props.onClick()
equal(clipboardCalls, { { "/wall/source.jpg", "text/plain" } })

assert(button(rendered, "Previous")).props.onClick()
equal(#runs, 2)
equal(runs[2].command, Shell.command(commands.backward))
local nextWhileBusy = assert(button(rendered, "Next"))
assert(not nextWhileBusy.props.enabled)
nextWhileBusy.props.onClick()
equal(#runs, 2, "a second action started while the first was busy")

runs[2].callback(success())
equal(#runs, 3, "successful navigation did not refresh current metadata")
equal(runs[3].command, Shell.command(commands.current))
runs[3].callback(success("without source"))

local copyWithoutSource = assert(button(rendered, "Copy"))
assert(not copyWithoutSource.props.enabled)
copyWithoutSource.props.onClick()
equal(clipboardCalls, { { "/wall/source.jpg", "text/plain" } }, "copy ran without a source path")

print("Wali plugin tests passed")
