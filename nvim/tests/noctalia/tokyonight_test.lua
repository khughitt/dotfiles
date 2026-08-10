package.path = 'nvim/lua/?.lua;nvim/lua/?/init.lua;' .. package.path
vim.opt.rtp:prepend(vim.fn.stdpath('data') .. '/lazy/tokyonight.nvim')

local noctalia = require('user.noctalia')
local palette = require('user.noctalia.palette')
noctalia.state_file = os.tmpname()
os.remove(noctalia.state_file)

local fh = assert(io.open('nvim/tests/noctalia/fixtures/raw_palette.json'))
local text = fh:read('*a'); fh:close()
local alt = os.tmpname() .. '.json'
fh = assert(io.open(alt, 'w')); fh:write((text:gsub('#222436', '#010203'))); fh:close()
palette.path = alt

local colors = require('tokyonight.colors').setup({
  style = 'moon',
  transparent = true,
  on_colors = function(c) noctalia.on_colors(c) end,
})
os.remove(alt)

assert(colors.bg == '#010203', 'colors.bg not replaced: ' .. tostring(colors.bg))
assert(require('tokyonight.util').bg == '#010203',
  'Util.bg still moon-derived: ' .. tostring(require('tokyonight.util').bg))
assert(require('tokyonight.util').fg == '#c8d3f5', 'Util.fg not updated')
assert(colors.bg_statusline == '#1e2030', 'derived chrome present')
assert(colors.terminal and colors.terminal.red_bright, 'terminal table present')

print('OK tokyonight')
