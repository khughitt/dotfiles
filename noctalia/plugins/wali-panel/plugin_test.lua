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

local function read(name)
  local file = assert(io.open(here .. name, "rb"))
  local text = file:read("a")
  file:close()
  return text
end

local function contains(text, literal, message)
  assert(text:find(literal, 1, true), message or ("missing source contract: " .. literal))
end

local widget = read("widget.luau")
contains(widget, 'barWidget.setGlyph("wallpaper")')
contains(widget, 'noctalia.togglePanel("khughitt/wali-panel:panel")')

local panelSource = read("panel.luau")
contains(panelSource, "noctalia.runAsync(Shell.command(argv), callback, 10000)")
contains(panelSource, 'noctalia.copyToClipboard(state.sourcePath, "text/plain")')
contains(panelSource, "if Logic.refreshAfter(action) then refresh() end")
contains(panelSource, "state.currentPath or state.sourcePath")
contains(panelSource, "function onOpen")
for _, label in ipairs({ "Refresh", "Previous", "Next", "Random", "Save", "Edit", "Copy" }) do
  contains(panelSource, 'text = "' .. label .. '"', "missing " .. label .. " control")
end

print("Wali plugin tests passed")
