local M = {}

local commands = {
  current = { "walictl", "current", "--json" },
  backward = { "walictl", "backward" },
  forward = { "walictl", "forward" },
  random = { "walictl", "random" },
  ["save-current"] = { "walictl", "save-current" },
  ["edit-current"] = { "walictl", "edit-current" },
}

function M.commandFor(action)
  return assert(commands[action], "unknown Wali action: " .. tostring(action))
end

function M.validateCurrent(payload)
  if type(payload) ~= "table" then return nil, "walictl current did not return an object" end
  if type(payload.ok) ~= "boolean" then return nil, "walictl current returned an invalid ok field" end
  if not payload.ok then return nil, "walictl current reported failure" end
  for _, field in ipairs({
    "current_wallpaper_path", "source_wallpaper_path", "parsed_date", "display_date",
  }) do
    if payload[field] ~= nil and type(payload[field]) ~= "string" then
      return nil, "walictl current returned an invalid " .. field .. " field"
    end
  end
  return payload
end

function M.decodeCurrent(text, decoder)
  local decoded, payload, decodeError = pcall(decoder, text)
  if not decoded then return nil, tostring(payload) end
  if payload == nil then return nil, tostring(decodeError or "walictl current returned invalid JSON") end
  return M.validateCurrent(payload)
end

function M.refreshAfter(action)
  return action == "backward" or action == "forward" or action == "random"
end

function M.canStart(busy)
  return not busy
end

function M.canCopy(sourcePath)
  return sourcePath ~= nil
end

return M
