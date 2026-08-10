package.path = 'nvim/lua/?.lua;nvim/lua/?/init.lua;' .. package.path
vim.opt.rtp:prepend(vim.fn.stdpath('data') .. '/lazy/tokyonight.nvim')

local noctalia = require('user.noctalia')
local palette = require('user.noctalia.palette')

palette.path = 'nvim/tests/noctalia/fixtures/raw_palette.json'
noctalia.state_file = os.tmpname()

os.remove(noctalia.state_file)
assert(noctalia.mood() == 'spectrum', 'default mood')

local called = false
noctalia.reload = function() called = true end
noctalia.set_mood('pastel')
assert(called, 'set_mood must reload')
assert(noctalia.mood() == 'pastel', 'mood persisted')

local original_open = io.open
local function persistence_failure(handle, message)
  called = false
  io.open = function() return handle end
  local ok, err = pcall(noctalia.set_mood, 'warm')
  io.open = original_open
  assert(not ok and err:match(message), message .. ' must error')
  assert(not called, message .. ' must not reload')
end
persistence_failure({
  write = function() return nil, 'write failed' end,
  close = function() return true end,
}, 'write failed')
persistence_failure({
  write = function() return true end,
  close = function() return nil, 'close failed' end,
}, 'close failed')

local fh = io.open(noctalia.state_file, 'w'); fh:write('vaporwave\n'); fh:close()
local ok, err = pcall(noctalia.mood)
assert(not ok and err:match('spectrum'), 'corrupt state must error listing moods')

fh = io.open(noctalia.state_file, 'w'); fh:write('spectrum\n'); fh:close()
os.execute("chmod 000 '" .. noctalia.state_file .. "'")
ok = pcall(noctalia.mood)
os.execute("chmod 600 '" .. noctalia.state_file .. "'")
assert(not ok, 'unreadable state file must error, not default')

os.remove(noctalia.state_file)
assert(not pcall(noctalia.set_mood, 'vaporwave'), 'unknown mood rejected')

local tbl = { stale_field = '#123456', bg = '#000000' }
noctalia.on_colors(tbl)
assert(tbl.stale_field == nil, 'stale field must be removed')
assert(tbl.bg == '#222436', 'bg replaced from artifact surface')
assert(tbl.bg_statusline == '#1e2030', 'derived chrome present')

os.remove(noctalia.state_file)
print('OK noctalia')
