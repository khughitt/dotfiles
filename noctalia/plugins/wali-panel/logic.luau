local M = {}

local commands = {
  current = { "walictl", "current", "--json" },
  previous = { "walictl", "previous" },
  next = { "walictl", "next" },
  random = { "walictl", "random" },
  earlier = { "walictl", "earlier" },
  later = { "walictl", "later" },
  favorite = { "walictl", "favorite" },
  edit = { "walictl", "edit" },
}

function M.commandFor(action)
  return assert(commands[action], "unknown walictl action: " .. tostring(action))
end

function M.validateCurrent(payload)
  if type(payload) ~= "table" then return nil, "walictl current did not return an object" end
  if payload.ok ~= true then return nil, "walictl current reported failure" end
  for _, field in ipairs({ "id", "path" }) do
    if type(payload[field]) ~= "string" then return nil, "walictl current returned an invalid " .. field .. " field" end
  end
  if type(payload.favorite) ~= "boolean" then return nil, "walictl current returned an invalid favorite field" end
  for _, field in ipairs({ "date", "display_date", "source_path", "variant_path" }) do
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
  return action == "previous" or action == "next" or action == "random" or action == "favorite"
    or action == "earlier" or action == "later"
end

function M.canStart(busy)
  return not busy
end

function M.copyTarget(payload)
  return payload.source_path or payload.path
end

function M.favoriteGlyph(favorite)
  return favorite and "heart-filled" or "heart"
end

function M.captionTitle(payload)
  if payload == nil then return "" end
  return payload.display_date or payload.date or payload.id
end

function M.captionDetail(payload, errorText)
  if errorText ~= nil then return { text = errorText, color = "error" } end
  return { text = payload and payload.id or "", color = "on_surface_variant" }
end

return M
