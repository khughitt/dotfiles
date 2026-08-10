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

return M
