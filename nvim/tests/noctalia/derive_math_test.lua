package.path = 'nvim/lua/?.lua;nvim/lua/?/init.lua;' .. package.path
local d = require('user.noctalia.derive')

local function close(a, b) return math.abs(a - b) < 0.01 end

-- primaries roundtrip
local h, s, l = d.hex_to_hsl('#ff0000')
assert(close(h, 0) and close(s, 1) and close(l, 0.5), 'red hsl')
assert(d.hsl_to_hex(0, 1, 0.5) == '#ff0000', 'red back')
assert(d.hsl_to_hex(120, 1, 0.5) == '#00ff00', 'green back')
assert(d.hsl_to_hex(240, 1, 0.5) == '#0000ff', 'blue back')

-- greys have zero saturation and survive the roundtrip
local gh, gs, gl = d.hex_to_hsl('#808080')
assert(close(gs, 0), 'grey sat')
assert(d.hsl_to_hex(gh, gs, gl) == '#808080', 'grey back')

-- arbitrary roundtrip is exact through hex quantization
local rt = d.hsl_to_hex(d.hex_to_hsl('#82aaff'))
assert(rt == '#82aaff', 'roundtrip: ' .. rt)

-- transforms
assert(d.with_hue('#ff0000', 120) == '#00ff00', 'with_hue')
assert(d.blend('#ffffff', 0.5, '#000000') == '#808080', 'blend')
assert(d.lighten('#000000', 1) == '#ffffff', 'lighten to white')
assert(d.darken('#ff0000', 1) == '#000000', 'darken to black')
assert(d.saturate('#997777', 2) == '#aa6666', 'saturate')

print('OK derive_math')
