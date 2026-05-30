local M = {}

local compiled_cache = setmetatable({}, { __mode = 'k' })

local function compiled_entities(entities)
  if compiled_cache[entities] then
    return compiled_cache[entities]
  end

  local compiled = {}
  for kind, entity in pairs(entities) do
    table.insert(compiled, {
      kind = kind,
      regex = vim.regex(entity.pattern),
    })
  end
  table.sort(compiled, function(a, b)
    return a.kind < b.kind
  end)

  compiled_cache[entities] = compiled
  return compiled
end

function M.scan_lines(lines, entities, row_offset)
  row_offset = row_offset or 0
  local matches = {}

  for index, line in ipairs(lines) do
    local row = row_offset + index - 1
    for _, entity in ipairs(compiled_entities(entities)) do
      local start_at = 0
      while start_at < #line do
        local col_start, col_end = entity.regex:match_str(line:sub(start_at + 1))
        if not col_start then
          break
        end

        col_start = col_start + start_at
        col_end = col_end + start_at
        table.insert(matches, {
          row = row,
          col_start = col_start,
          col_end = col_end,
          kind = entity.kind,
          text = line:sub(col_start + 1, col_end),
        })
        start_at = math.max(col_end, start_at + 1)
      end
    end
  end

  table.sort(matches, function(a, b)
    if a.row ~= b.row then
      return a.row < b.row
    end
    if a.col_start ~= b.col_start then
      return a.col_start < b.col_start
    end
    return a.kind < b.kind
  end)

  return matches
end

return M
