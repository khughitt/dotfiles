package.path = 'nvim/lua/?.lua;nvim/lua/?/init.lua;' .. package.path
local p = require('user.noctalia.palette')
local fixture = 'nvim/tests/noctalia/fixtures/raw_palette.json'

local function read_json(path)
  local fh = assert(io.open(path))
  local text = fh:read('*a')
  fh:close()
  return vim.json.decode(text)
end

-- validate: fixture passes
assert(p.validate(read_json(fixture)), 'fixture must validate')

-- validate: missing key
local bad = read_json(fixture); bad.primary = nil
local ok, err = p.validate(bad)
assert(not ok and err:match('primary'), 'missing key detected')

-- validate: missing selection foreground
bad = read_json(fixture); bad.glass.selection_fg = nil
ok, err = p.validate(bad)
assert(not ok and err:match('selection_fg'),
  'missing selection foreground detected')

-- validate: glass collision
bad = read_json(fixture); bad.glass.cursorline = bad.glass.chrome
ok, err = p.validate(bad)
assert(not ok and err:match('collide'), 'glass collision detected')

-- validate: intentional aliases cannot drift and consume extra kitty slots
bad = read_json(fixture); bad.glass.tab_on = '#222436'
ok, err = p.validate(bad)
assert(not ok and err:match('tab_on'), 'tab_on alias mismatch detected')

-- validate: semantic slots must remain distinct from neutral glass
bad = read_json(fixture); bad.glass.selection = bad.glass.chrome
ok, err = p.validate(bad)
assert(not ok and err:match('collide'), 'semantic glass collision detected')

-- validate: Claude's native diff cells use fixed colors
bad = read_json(fixture); bad.glass.diff_added = '#012345'
ok, err = p.validate(bad)
assert(not ok and err:match('diff_added'), 'changed native diff color detected')

-- validate: float registered
bad = read_json(fixture); bad.glass.float = bad.glass.raised
ok, err = p.validate(bad)
assert(not ok and err:match('float'), 'registered float detected')

-- validate: float equals surface
bad = read_json(fixture); bad.glass.float = bad.surface
ok, err = p.validate(bad)
assert(not ok and err:match('surface'), 'float==surface detected')

-- load: falls back to default when file absent
p.path = '/nonexistent/nvim-palette.json'
local raw = p.load()
assert(raw.glass.chrome == '#1e2030', 'default fallback used')

-- load: reads promoted file when present
p.path = fixture
assert(p.load().primary == '#82aaff', 'artifact loaded')

-- load: hard error on malformed JSON
local malformed = os.tmpname()
local fh = io.open(malformed, 'w'); fh:write('{ not json'); fh:close()
p.path = malformed
ok = pcall(p.load)
assert(not ok, 'malformed promoted palette must hard-error')

-- load: hard error on valid JSON that fails validation
fh = io.open(malformed, 'w'); fh:write('{"primary": "notahex"}'); fh:close()
ok = pcall(p.load)
os.remove(malformed)
assert(not ok, 'invalid promoted palette must hard-error')

-- load: a PRESENT but unreadable file is a hard error, never a fallback
-- (only ENOENT may fall back; EACCES etc. must surface)
-- The locked file holds VALID content: if the chmod were silently skipped
-- (or bypassed), load() would succeed and the assert below would still catch
-- it — the test cannot pass by tripping over invalid content instead of EACCES.
local locked = os.tmpname()
fh = io.open(locked, 'w')
fh:write(assert(io.open(fixture)):read('*a'))
fh:close()
assert(vim.uv.fs_chmod(locked, 0), 'chmod 000 must succeed')
p.path = locked
ok = pcall(p.load)
vim.uv.fs_chmod(locked, 384)  -- 0600, so os.remove can clean up
os.remove(locked)
assert(not ok, 'unreadable present palette must hard-error, not fall back')

-- default palette itself validates and equals the fixture
local default = require('user.noctalia.default_palette')
assert(p.validate(default), 'default must validate')
assert(vim.deep_equal(default, read_json(fixture)), 'default must equal fixture values')

-- fresh-machine invariant: kitty.conf's hardcoded fallback line carries the
-- default seven registered slots, including semantic opacity overrides
local conf = assert(io.open('kitty/kitty.conf')):read('*a')
local line = conf:match('\ntransparent_background_colors ([^\n]+)')
assert(line, 'kitty.conf fallback line missing')
local tones = {}
for token in line:gmatch('%S+') do tones[#tones + 1] = token end
local expected = {
  default.glass.chrome,
  default.glass.cursorline,
  default.glass.tab_off,
  default.glass.raised,
  default.glass.diff_added .. '@0.72',
  default.glass.diff_removed .. '@0.72',
  default.glass.selection .. '@0.55',
}
assert(#tones == #expected, 'kitty fallback must list exactly seven tones')
for i, token in ipairs(expected) do
  assert(tones[i] == token, ('kitty fallback tone %d mismatch'):format(i))
end

print('OK palette')
