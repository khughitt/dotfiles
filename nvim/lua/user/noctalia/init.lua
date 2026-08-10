-- Glue: mood persistence, :NoctaliaMood, SIGUSR1 reload, and the on_colors
-- callback that injects the derived palette into tokyonight.

local M = {}

M.state_file = vim.fn.stdpath('state') .. '/noctalia-mood'

local DEFAULT_MOOD = 'spectrum'

local function moods() return require('user.noctalia.derive').MOODS end

local function valid_mood(name) return vim.tbl_contains(moods(), name) end

function M.mood()
  -- Only a genuinely ABSENT state file defaults (fresh machine); any other
  -- I/O failure must surface rather than silently resetting the mood.
  local stat, stat_err = vim.uv.fs_stat(M.state_file)
  if not stat then
    if stat_err and not stat_err:match('^ENOENT') then
      error(('%s: %s'):format(M.state_file, stat_err))
    end
    return DEFAULT_MOOD
  end
  local fh, open_err = io.open(M.state_file)
  if not fh then
    error(('%s exists but cannot be read: %s'):format(M.state_file, tostring(open_err)))
  end
  local name = (fh:read('*l') or ''):gsub('%s+$', '')
  fh:close()
  if not valid_mood(name) then
    error(('%s contains unknown mood %q (valid: %s)'):format(
      M.state_file, name, table.concat(moods(), ', ')))
  end
  return name
end

function M.set_mood(name)
  if not valid_mood(name) then
    error(('unknown noctalia mood %q (valid: %s)'):format(
      name, table.concat(moods(), ', ')))
  end
  local fh = assert(io.open(M.state_file, 'w'))
  assert(fh:write(name, '\n'))
  assert(fh:close())
  M.reload()
end

function M.colors()
  return require('user.noctalia.derive').colorscheme(
    require('user.noctalia.palette').load(), M.mood())
end

-- tokyonight calls this with its own colors table AFTER deriving dependent
-- fields, and ignores our return value: replace the table's contents. It
-- also caches Util.bg/Util.fg BEFORE this callback, and its highlight
-- groups blend against those afterwards -- keep them in step or every
-- blend stays moon-based.
function M.on_colors(colors)
  local derived = M.colors()
  for k in pairs(colors) do colors[k] = nil end
  for k, v in pairs(derived) do colors[k] = v end
  local util = require('tokyonight.util')
  util.bg, util.fg = derived.bg, derived.fg
end

function M.reload()
  -- tokyonight's lualine theme module caches computed colors; bust it so
  -- lualine's own ColorScheme autocmd re-evaluates against fresh colors.
  package.loaded['lualine.themes.tokyonight'] = nil
  vim.cmd.colorscheme('tokyonight')
end

function M.setup()
  vim.api.nvim_create_user_command('NoctaliaMood', function(opts)
    M.set_mood(opts.args)
  end, {
    nargs = 1,
    complete = function() return moods() end,
    desc = 'Switch the noctalia-derived colorscheme mood',
  })
  vim.api.nvim_create_autocmd('Signal', {
    group = vim.api.nvim_create_augroup('user.noctalia', { clear = true }),
    pattern = 'SIGUSR1',
    callback = M.reload,
  })
end

return M
