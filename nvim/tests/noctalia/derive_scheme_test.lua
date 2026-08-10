package.path = 'nvim/lua/?.lua;nvim/lua/?/init.lua;' .. package.path
local d = require('user.noctalia.derive')

local function read_json(path)
  local fh = assert(io.open(path))
  local text = fh:read('*a')
  fh:close()
  return vim.json.decode(text)
end
local raw = read_json('nvim/tests/noctalia/fixtures/raw_palette.json')

local BASE = {
  'bg', 'bg_dark', 'bg_dark1', 'bg_highlight', 'blue', 'blue0', 'blue1',
  'blue2', 'blue5', 'blue6', 'blue7', 'comment', 'cyan', 'dark3', 'dark5',
  'fg', 'fg_dark', 'fg_gutter', 'green', 'green1', 'green2', 'magenta',
  'magenta2', 'orange', 'purple', 'red', 'red1', 'teal', 'terminal_black',
  'yellow',
}
local DERIVED = {
  'black', 'border_highlight', 'border', 'bg_popup', 'bg_statusline',
  'bg_sidebar', 'bg_float', 'bg_visual', 'bg_search', 'fg_sidebar',
  'fg_float', 'error', 'todo', 'warning', 'info', 'hint',
}
local TERMINAL = {
  'black', 'black_bright', 'red', 'red_bright', 'green', 'green_bright',
  'yellow', 'yellow_bright', 'blue', 'blue_bright', 'magenta',
  'magenta_bright', 'cyan', 'cyan_bright', 'white', 'white_bright',
}

local function is_hex(v) return type(v) == 'string' and v:match('^#%x%x%x%x%x%x$') end
local function close(a, b, tol) return math.abs(a - b) < (tol or 0.02) end

for _, mood in ipairs(d.MOODS) do
  local c = d.colorscheme(raw, mood)
  for _, k in ipairs(BASE) do assert(is_hex(c[k]), mood .. ': bad ' .. k) end
  for _, k in ipairs(DERIVED) do assert(is_hex(c[k]), mood .. ': bad ' .. k) end
  assert(c.none == 'NONE', mood .. ': none')
  for _, k in ipairs({ 'add', 'delete', 'change', 'text' }) do
    assert(is_hex(c.diff[k]), mood .. ': diff.' .. k)
  end
  for _, k in ipairs({ 'add', 'change', 'delete', 'ignore' }) do
    assert(is_hex(c.git[k]), mood .. ': git.' .. k)
  end
  assert(#c.rainbow == 8, mood .. ': rainbow')
  for _, k in ipairs(TERMINAL) do assert(is_hex(c.terminal[k]), mood .. ': terminal.' .. k) end
  -- glass alignment: chrome-painting fields must come from the glass table
  assert(c.bg_statusline == raw.glass.chrome, mood .. ': bg_statusline')
  assert(c.bg_float == raw.glass.float, mood .. ': bg_float')
  assert(c.bg_highlight == raw.glass.cursorline, mood .. ': bg_highlight')
  assert(c.bg == raw.surface, mood .. ': bg')
end

-- exact mood behavior (through hex quantization, so small tolerances)
local ph, ps, pl = d.hex_to_hsl(raw.primary)

local spec = d.accents(raw, 'spectrum')
assert(spec.blue == raw.primary and spec.red == raw.error, 'spectrum passthrough')
local gh, gs, gl = d.hex_to_hsl(spec.green)
assert(close(gh, 130, 1.5), 'spectrum green hue anchor, got ' .. gh)
assert(close(gs, ps) and close(gl, pl), 'spectrum green keeps primary s/l')

local warm = d.accents(raw, 'warm')
local oh = d.hex_to_hsl(warm.orange)
assert(close(oh, 35 + (45 - 35) * 0.25, 1.5), 'warm orange hue pulled toward 45, got ' .. oh)

local pastel = d.accents(raw, 'pastel')
local _, pas, pal_ = d.hex_to_hsl(pastel.green)
assert(close(pas, ps * 0.6, 0.03), 'pastel desaturates')
assert(close(pal_, pl + (1 - pl) * 0.3, 0.03), 'pastel lifts lightness')

-- material uses only the four accents
local mat = d.accents(raw, 'material')
assert(mat.blue == raw.primary and mat.green == raw.secondary
  and mat.yellow == raw.tertiary_fixed_dim and mat.red == raw.error, 'material mapping')

-- unknown mood errors and names the valid ones
local ok, err = pcall(d.colorscheme, raw, 'vaporwave')
assert(not ok and err:match('spectrum'), 'unknown mood must error listing moods')

print('OK derive_scheme')
