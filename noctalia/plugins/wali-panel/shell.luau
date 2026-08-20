local M = {}

function M.quote(value)
  return "'" .. tostring(value):gsub("'", "'\"'\"'") .. "'"
end

function M.command(argv)
  local quoted = {}
  for i, value in ipairs(argv) do quoted[i] = M.quote(value) end
  return table.concat(quoted, " ")
end

return M
