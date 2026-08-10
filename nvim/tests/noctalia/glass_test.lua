package.path = 'nvim/lua/?.lua;nvim/lua/?/init.lua;' .. package.path
vim.opt.rtp:prepend(vim.fn.getcwd() .. '/nvim')
package.loaded['user.noctalia.palette'] = nil
package.loaded['user.glass'] = nil
local palette = require('user.noctalia.palette')
local glass = require('user.glass')

palette.path = 'nvim/tests/noctalia/fixtures/raw_palette.json'
glass.apply()
assert(glass.palette.chrome == '#1e2030', 'chrome from artifact')
assert(glass.registered['#3b4261'], 'raised registered')
assert(not glass.registered['#16161e'], 'float NOT registered')
assert(vim.api.nvim_get_hl(0, { name = 'NormalFloat' }).bg == tonumber('16161e', 16),
  'NormalFloat painted with glass.float')

-- liveness: a different palette file changes the applied colors (this is the
-- "snapshots vs live state" regression test)
local src = assert(io.open('nvim/tests/noctalia/fixtures/raw_palette.json')):read('*a')
local alt = os.tmpname() .. '.json'
local fh = io.open(alt, 'w')
-- #1e2030 appears as glass.chrome AND on_primary; rewriting both is harmless
-- here (only glass.* is asserted)
fh:write((src:gsub('#1e2030', '#101010')))
fh:close()
palette.path = alt
glass.apply()
os.remove(alt)
assert(glass.palette.chrome == '#101010', 'apply() must re-read the palette')
assert(glass.registered['#101010'] and not glass.registered['#1e2030'],
  'registered set must be recomputed')

print('OK glass')
