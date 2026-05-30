local M = {}

local cache = {}

function M.is_project(path, marker)
  marker = marker or 'science.yaml'
  path = vim.fs.normalize(path)
  local cache_key = marker .. '\0' .. path

  if cache[cache_key] ~= nil then
    return cache[cache_key]
  end

  local found = vim.fs.find(marker, { upward = true, path = path })[1]
  cache[cache_key] = found and vim.fs.dirname(found) or false
  return cache[cache_key]
end

function M.clear_cache()
  cache = {}
end

return M
