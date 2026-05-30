local M = {}

local function group_name(kind)
  return 'ScienceMd' .. kind:gsub('^%l', string.upper):gsub('_(%l)', function(char)
    return char:upper()
  end)
end

local function highlight_spec(entity)
  local hl = vim.deepcopy(entity)
  hl.pattern = nil
  local link = hl.link
  hl.link = nil

  if link and next(hl) then
    local ok, base = pcall(vim.api.nvim_get_hl, 0, { name = link, link = false })
    if ok and next(base) then
      return vim.tbl_extend('force', base, hl)
    end
  end

  if link then
    hl.link = link
  end
  return hl
end

function M.define(config)
  for kind, entity in pairs(config.entities) do
    vim.api.nvim_set_hl(0, group_name(kind), highlight_spec(entity))
  end
end

function M.group_name(kind)
  return group_name(kind)
end

return M
