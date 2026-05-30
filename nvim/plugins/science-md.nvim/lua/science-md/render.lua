local highlights = require('science-md.highlights')

local M = {}

M.ns = vim.api.nvim_create_namespace('science_md')

function M.apply(buf, matches)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)

  for _, match in ipairs(matches) do
    vim.api.nvim_buf_set_extmark(buf, M.ns, match.row, match.col_start, {
      end_col = match.col_end,
      hl_group = highlights.group_name(match.kind),
      priority = 150,
    })
  end
end

function M.clear(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
  end
end

return M
