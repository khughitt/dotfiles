-- Pure-Lua color math and mood derivation: turns the raw material palette
-- from noctalia into a complete tokyonight ColorScheme table. No vim APIs,
-- so it is testable headless.

local M = {}

local function hex_to_rgb(hex)
  local r, g, b = hex:match('^#(%x%x)(%x%x)(%x%x)$')
  assert(r, 'bad hex color: ' .. tostring(hex))
  return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

local function clamp01(v) return math.min(math.max(v, 0), 1) end

local function rgb_to_hex(r, g, b)
  return string.format('#%02x%02x%02x',
    math.floor(clamp01(r) * 255 + 0.5),
    math.floor(clamp01(g) * 255 + 0.5),
    math.floor(clamp01(b) * 255 + 0.5))
end

function M.hex_to_hsl(hex)
  local r, g, b = hex_to_rgb(hex)
  local hi, lo = math.max(r, g, b), math.min(r, g, b)
  local l = (hi + lo) / 2
  if hi == lo then return 0, 0, l end
  local d = hi - lo
  local s = l > 0.5 and d / (2 - hi - lo) or d / (hi + lo)
  local h
  if hi == r then h = ((g - b) / d) % 6
  elseif hi == g then h = (b - r) / d + 2
  else h = (r - g) / d + 4 end
  return h * 60, s, l
end

local function hue_chan(p, q, t)
  t = t % 360
  if t < 60 then return p + (q - p) * t / 60 end
  if t < 180 then return q end
  if t < 240 then return p + (q - p) * (240 - t) / 60 end
  return p
end

function M.hsl_to_hex(h, s, l)
  if s <= 0 then return rgb_to_hex(l, l, l) end
  local q = l < 0.5 and l * (1 + s) or l + s - l * s
  local p = 2 * l - q
  return rgb_to_hex(hue_chan(p, q, h + 120), hue_chan(p, q, h), hue_chan(p, q, h - 120))
end

function M.with_hue(hex, deg)
  local _, s, l = M.hex_to_hsl(hex)
  return M.hsl_to_hex(deg, s, l)
end

function M.saturate(hex, factor)
  local h, s, l = M.hex_to_hsl(hex)
  return M.hsl_to_hex(h, clamp01(s * factor), l)
end

function M.lighten(hex, amt)
  local h, s, l = M.hex_to_hsl(hex)
  return M.hsl_to_hex(h, s, clamp01(l + amt * (1 - l)))
end

function M.darken(hex, amt)
  local h, s, l = M.hex_to_hsl(hex)
  return M.hsl_to_hex(h, s, clamp01(l * (1 - amt)))
end

function M.blend(fg, alpha, bg)
  local fr, fg_, fb = hex_to_rgb(fg)
  local br, bg_, bb = hex_to_rgb(bg)
  return rgb_to_hex(alpha * fr + (1 - alpha) * br,
                    alpha * fg_ + (1 - alpha) * bg_,
                    alpha * fb + (1 - alpha) * bb)
end

-- Mood derivation ----------------------------------------------------------
--
-- Noctalia gives 4 accent hues; tokyonight wants ~9. Synthesized slots get
-- fixed hue anchors at primary's saturation/lightness so they sit at the
-- same perceptual volume as the wallpaper palette. blue tracks primary and
-- red tracks error directly so the wallpaper identity survives.

M.MOODS = { 'material', 'spectrum', 'warm', 'pastel' }

local ANCHORS = {
  orange = 35, yellow = 70, green = 130, teal = 172,
  cyan = 195, magenta = 310, purple = 285,
}

-- mood -> function(h, s, l) -> h, s, l  (applied to synthesized slots)
local TRANSFORMS = {
  spectrum = function(h, s, l) return h, s, l end,
  warm = function(h, s, l)
    -- pull hue a quarter of the way toward amber (45°), richer chroma
    local delta = (45 - h + 540) % 360 - 180
    return (h + delta * 0.25) % 360, math.min(s * 1.15, 1), l
  end,
  pastel = function(h, s, l) return h, s * 0.6, l + (1 - l) * 0.3 end,
}

function M.accents(raw, mood)
  if mood == 'material' then
    return {
      blue = raw.primary, cyan = raw.primary_fixed_dim,
      green = raw.secondary, teal = raw.secondary_fixed_dim,
      orange = raw.tertiary, yellow = raw.tertiary_fixed_dim,
      magenta = raw.tertiary, purple = raw.tertiary_fixed_dim,
      red = raw.error,
    }
  end
  local transform = TRANSFORMS[mood]
  if not transform then
    error(('unknown noctalia mood %q (valid: %s)'):format(mood, table.concat(M.MOODS, ', ')))
  end
  local _, s, l = M.hex_to_hsl(raw.primary)
  local acc = { blue = raw.primary, red = raw.error }
  for name, hue in pairs(ANCHORS) do
    acc[name] = M.hsl_to_hex(transform(hue, s, l))
  end
  return acc
end

-- Build the COMPLETE tokyonight ColorScheme. tokyonight calls on_colors()
-- only after deriving diff/border/bg_*/rainbow/terminal from its built-in
-- palette and ignores the callback's return value, so every one of those
-- fields must be recomputed here and written into the table it passes us.
function M.colorscheme(raw, mood)
  local a = M.accents(raw, mood)
  local g = raw.glass
  local bg = raw.surface

  local c = {
    bg = bg,
    bg_dark = g.chrome,
    bg_dark1 = g.float,
    bg_highlight = g.cursorline,
    fg = raw.on_surface,
    fg_dark = raw.on_surface_variant,
    fg_gutter = g.raised,
    comment = raw.outline,
    dark3 = raw.outline,
    dark5 = raw.outline_variant,
    terminal_black = g.raised,
    blue = a.blue,
    blue0 = M.blend(a.blue, 0.45, bg),
    blue1 = raw.primary_fixed_dim,
    blue2 = a.cyan,
    blue5 = M.lighten(a.cyan, 0.25),
    blue6 = M.lighten(a.teal, 0.45),
    blue7 = M.blend(a.blue, 0.3, bg),
    cyan = a.cyan,
    teal = a.teal,
    green = a.green,
    green1 = a.teal,
    green2 = M.darken(a.teal, 0.2),
    yellow = a.yellow,
    orange = a.orange,
    red = a.red,
    red1 = raw.error_container,
    magenta = a.magenta,
    magenta2 = M.saturate(M.with_hue(a.magenta, 330), 1.4),
    purple = a.purple,
    git = {
      add = M.darken(a.green, 0.08),
      change = M.darken(a.blue, 0.08),
      delete = M.darken(a.red, 0.08),
    },
  }

  c.none = 'NONE'
  c.diff = {
    add = M.blend(c.green2, 0.25, bg),
    delete = M.blend(c.red1, 0.25, bg),
    change = M.blend(c.blue7, 0.15, bg),
    text = c.blue7,
  }
  c.git.ignore = c.dark3
  c.black = M.blend(bg, 0.8, '#000000')
  c.border_highlight = M.blend(c.blue1, 0.8, bg)
  c.border = c.black
  c.bg_popup = g.float
  c.bg_statusline = g.chrome
  c.bg_sidebar = g.chrome
  c.bg_float = g.float
  c.bg_visual = M.blend(c.blue0, 0.4, bg)
  c.bg_search = c.blue0
  c.fg_sidebar = c.fg_dark
  c.fg_float = c.fg
  c.error = c.red1
  c.todo = c.blue
  c.warning = c.yellow
  c.info = c.blue2
  c.hint = c.teal
  c.rainbow = { c.blue, c.yellow, c.green, c.teal, c.magenta, c.purple, c.orange, c.red }
  c.terminal = {
    black = c.black,
    black_bright = c.terminal_black,
    red = c.red,
    red_bright = M.lighten(c.red, 0.1),
    green = c.green,
    green_bright = M.lighten(c.green, 0.1),
    yellow = c.yellow,
    yellow_bright = M.lighten(c.yellow, 0.1),
    blue = c.blue,
    blue_bright = M.lighten(c.blue, 0.1),
    magenta = c.magenta,
    magenta_bright = M.lighten(c.magenta, 0.1),
    cyan = c.cyan,
    cyan_bright = M.lighten(c.cyan, 0.1),
    white = c.fg_dark,
    white_bright = c.fg,
  }
  return c
end

return M
