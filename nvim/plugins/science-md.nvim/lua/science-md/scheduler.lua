local scanner = require('science-md.scanner')
local render = require('science-md.render')

local M = {}

local state = {}
local refresh_impl

local function stop_timer(item)
  if not item or not item.timer then
    return
  end

  local timer = item.timer
  item.timer = nil

  pcall(function()
    timer:stop()
  end)
  pcall(function()
    if not timer:is_closing() then
      timer:close()
    end
  end)
end

function M.merge_ranges(ranges)
  local sorted = vim.deepcopy(ranges or {})
  table.sort(sorted, function(a, b)
    if a.start_row ~= b.start_row then
      return a.start_row < b.start_row
    end
    return a.end_row < b.end_row
  end)

  local merged = {}
  for _, range in ipairs(sorted) do
    local last = merged[#merged]
    if last and range.start_row <= last.end_row then
      last.end_row = math.max(last.end_row, range.end_row)
    else
      table.insert(merged, {
        start_row = range.start_row,
        end_row = range.end_row,
      })
    end
  end

  return merged
end

local function visible_ranges(buf, config)
  local margin = config.viewport_margin or 0
  local line_count = vim.api.nvim_buf_line_count(buf)
  local ranges = {}

  if line_count == 0 then
    return ranges
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
      local top = vim.api.nvim_win_call(win, function()
        return vim.fn.line('w0')
      end) - 1
      local bottom = vim.api.nvim_win_call(win, function()
        return vim.fn.line('w$')
      end) - 1

      table.insert(ranges, {
        start_row = math.max(0, top - margin),
        end_row = math.min(line_count - 1, bottom + margin),
      })
    end
  end

  return M.merge_ranges(ranges)
end

local function refresh(buf, config)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  if refresh_impl then
    refresh_impl(buf, config)
    return
  end

  local matches = {}
  if config.viewport_only == false then
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    matches = scanner.scan_lines(lines, config.entities, 0)
  else
    for _, range in ipairs(visible_ranges(buf, config)) do
      local lines = vim.api.nvim_buf_get_lines(buf, range.start_row, range.end_row + 1, false)
      vim.list_extend(matches, scanner.scan_lines(lines, config.entities, range.start_row))
    end
  end

  render.apply(buf, matches)
end

function M.schedule(buf, config, immediate)
  config = config or {}

  local item = state[buf]
  if not item then
    item = { generation = 0 }
    state[buf] = item
  end

  stop_timer(item)
  item.generation = item.generation + 1
  local generation = item.generation

  if immediate then
    refresh(buf, config)
    return
  end

  local timer = vim.loop.new_timer()
  item.timer = timer

  timer:start(config.debounce_ms or 0, 0, function()
    vim.schedule(function()
      local current = state[buf]
      if not current or current.generation ~= generation then
        return
      end

      if not vim.api.nvim_buf_is_valid(buf) then
        M.clear(buf)
        return
      end

      stop_timer(current)
      refresh(buf, config)
    end)
  end)
end

function M.clear(buf)
  stop_timer(state[buf])
  state[buf] = nil
end

function M._test_with_refresh(fn)
  refresh_impl = fn
end

function M._test_debounce(buf, debounce_ms)
  M.schedule(buf, { debounce_ms = debounce_ms }, false)
end

return M
