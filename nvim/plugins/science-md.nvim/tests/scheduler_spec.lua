local scheduler = require('science-md.scheduler')
local config_mod = require('science-md.config')
local render = require('science-md.render')

local function assert_eq(actual, expected, label)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', label, vim.inspect(expected), vim.inspect(actual)))
  end
end

local merged = scheduler.merge_ranges({
  { start_row = 10, end_row = 20 },
  { start_row = 18, end_row = 30 },
  { start_row = 50, end_row = 60 },
})

assert_eq(#merged, 2, 'merged range count')
assert_eq(merged[1].start_row, 10, 'first range start')
assert_eq(merged[1].end_row, 30, 'first range end')
assert_eq(merged[2].start_row, 50, 'second range start')

local calls = 0
scheduler._test_with_refresh(function()
  calls = calls + 1
end)

scheduler._test_debounce(1, 5)
scheduler._test_debounce(1, 5)
vim.wait(100)
assert_eq(calls, 1, 'debounce coalesces repeated calls')
scheduler.clear(1)
scheduler._test_with_refresh(nil)

local full_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(full_buf, 0, -1, false, {
  'Complete task:t001 before review.',
  'Answer question:q01-model-granularity next.',
})

scheduler.schedule(full_buf, config_mod.merge({
  enabled = true,
  viewport_only = false,
}), true)

local full_extmarks = vim.api.nvim_buf_get_extmarks(full_buf, render.ns, 0, -1, {})
assert_eq(#full_extmarks, 2, 'full buffer scan extmarks')
scheduler.clear(full_buf)
vim.api.nvim_buf_delete(full_buf, { force = true })

local visible_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(visible_buf, 0, -1, false, {
  'Visible task:t001 should be highlighted.',
})
vim.api.nvim_win_set_buf(0, visible_buf)

scheduler.schedule(visible_buf, config_mod.merge({
  enabled = true,
  viewport_only = true,
  viewport_margin = 0,
}), true)

local visible_extmarks = vim.api.nvim_buf_get_extmarks(visible_buf, render.ns, 0, -1, {})
if #visible_extmarks < 1 then
  error(string.format('visible window scan extmarks: expected at least 1, got %s', vim.inspect(visible_extmarks)))
end
scheduler.clear(visible_buf)
vim.api.nvim_buf_delete(visible_buf, { force = true })

print('scheduler_spec passed')
