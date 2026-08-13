local function test_clipboard_behavior()
  local clipboard = vim.opt.clipboard:get()
  assert(vim.tbl_contains(clipboard, 'unnamed'), 'PRIMARY clipboard sync is disabled')
  assert(vim.tbl_contains(clipboard, 'unnamedplus'), 'CLIPBOARD sync is disabled')

  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'alpha', 'beta' })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local x = vim.fn.maparg('x', 'n', false, true)
  vim.cmd('normal! ' .. x.rhs)

  assert(vim.api.nvim_get_current_line() == 'lpha', 'x did not delete the character')
  assert(vim.fn.getreg('-') == 'a', 'x did not preserve the small-delete register')
end

local ok, err = xpcall(test_clipboard_behavior, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd('cquit 1')
end
