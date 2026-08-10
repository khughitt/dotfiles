# Noctalia → Neovim Theming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Neovim follows noctalia's wallpaper-derived palette (syntax + chrome) with live reload, mood variants, and the kitty glass translucency preserved.

**Architecture:** One noctalia user template renders a candidate JSON palette artifact; a hook script validates the complete artifact, stages the promoted palette plus a generated kitty `transparent_background_colors` include into a version directory, atomically flips a `current` symlink over both, then signals kitty and nvim. In nvim, a pure-Lua derivation layer turns the raw material palette into a complete tokyonight `ColorScheme` table (mood-variant accent hues included), injected via tokyonight's `on_colors` — which must also refresh tokyonight's cached `Util.bg`/`Util.fg`; `glass.lua` recomputes its chrome tones from the same artifact on every apply.

**Tech Stack:** Lua (nvim config, tests via `nvim -l`), Python 3 stdlib (hook + check scripts), noctalia user templates, tokyonight.nvim, lualine, kitty.

**Spec:** `docs/specs/2026-08-09-noctalia-nvim-theme-design.md` — read it first.

## Global Constraints

- Work happens in the existing worktree `.worktrees/noctalia-nvim-theme` (branch `noctalia-nvim-theme`); all paths below are relative to its root.
- Conventional commits; NO AI-attribution trailers or footers.
- `docs/` contents are gitignored: committing plan/spec updates needs `git add -f`.
- Generated files live ONLY under `~/.cache/noctalia/` — never inside the repo tree (it syncs via Dropbox across machines).
- **Cache path contract:** production paths are pinned to literal `~/.cache/noctalia/` everywhere — kitty's `include` line and noctalia's `user-templates.toml` cannot express an XDG fallback, so nothing in this pipeline honors `XDG_CACHE_HOME`. The Python scripts accept a dedicated `NOCTALIA_GLASS_DIR` env override, used ONLY by tests.
- No new nvim plugin dependencies; no Python packages beyond stdlib.
- Do not use paths like `/home/keith` or `/mnt/ssd/Dropbox` in code comments or docs; `~` is fine.
- Lua tests run headless from the repo root: `nvim -l nvim/tests/noctalia/<name>_test.lua` — they must print `OK <name>` and exit 0. `nvim -l` does not load user config, which is what we want.
- Every task is red-first: write the test, watch it fail for the expected reason, then implement.
- The glass-role → material-token mapping lives ONLY in the template (Task 4). Every other component consumes the artifact's `glass` table verbatim.
- The committed fallback palette's `glass` table MUST stay byte-identical to the hardcoded `transparent_background_colors` line in `kitty/kitty.conf` (fresh-machine invariant; enforced by a test in Task 3).
- The required-key list exists twice — `palette.lua` (Lua) and `bin/noctalia-glass-sync` (Python). Both carry a comment pointing at the other; change them together.

## Artifact contract (used by Tasks 3–7)

The artifact is JSON — chosen so the hook can syntax-validate the whole file with `json.loads` and nvim can read it with `vim.json.decode`, no hand-rolled parsing anywhere.

- Render target (written by noctalia, consumed by the hook): `~/.cache/noctalia/nvim-palette.candidate.json`
- Promoted (read by nvim): `~/.cache/noctalia/nvim-glass/current/nvim-palette.json`
- Kitty include (read by kitty): `~/.cache/noctalia/nvim-glass/current/kitty-glass.conf`
- `current` is a symlink into a sibling version directory; the hook stages both files in a new version dir and flips the symlink with one atomic rename, so readers never see a half-promoted state.

```json
{
  "primary": "#82aaff",
  "primary_fixed_dim": "#65bcff",
  "on_primary": "#1e2030",
  "secondary": "#86e1fc",
  "secondary_fixed_dim": "#4fd6be",
  "tertiary": "#c099ff",
  "tertiary_fixed_dim": "#fca7ea",
  "error": "#ff757f",
  "error_container": "#c53b53",
  "surface": "#222436",
  "on_surface": "#c8d3f5",
  "on_surface_variant": "#828bb8",
  "on_background": "#c8d3f5",
  "outline": "#636da6",
  "outline_variant": "#545c7e",
  "surface_variant": "#2f334d",
  "glass": {
    "chrome": "#1e2030",
    "cursorline": "#2f334d",
    "tab_on": "#222436",
    "tab_off": "#272a3f",
    "tab_fill": "#2c3048",
    "raised": "#3b4261",
    "float": "#16161e"
  }
}
```

Semantics: the six glass tones `chrome/cursorline/tab_on/tab_off/tab_fill/raised` become kitty's `transparent_background_colors` (translucent chrome), in that order; `float` is the solid popup background and must NOT be one of the six nor equal `surface`.

---

### Task 1: derive.lua — color math primitives

**Files:**
- Create: `nvim/lua/user/noctalia/derive.lua`
- Test: `nvim/tests/noctalia/derive_math_test.lua`

**Interfaces:**
- Produces (consumed by Task 2 internally and its tests):
  - `derive.hex_to_hsl(hex) -> h, s, l` (h in degrees 0–360, s/l in 0–1)
  - `derive.hsl_to_hex(h, s, l) -> "#rrggbb"`
  - `derive.with_hue(hex, deg) -> hex`
  - `derive.saturate(hex, factor) -> hex` (multiply s, clamp to 1)
  - `derive.lighten(hex, amt) -> hex` (`l = l + amt*(1-l)`)
  - `derive.darken(hex, amt) -> hex` (`l = l * (1-amt)`)
  - `derive.blend(fg_hex, alpha, bg_hex) -> hex` (per-channel `alpha*fg + (1-alpha)*bg`; mirror of tokyonight `Util.blend`)

- [ ] **Step 1: Write the failing test**

```lua
-- nvim/tests/noctalia/derive_math_test.lua
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
local _, s2 = d.hex_to_hsl(d.saturate('#997777', 2))
assert(s2 > 0.3, 'saturate raised s')

print('OK derive_math')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim -l nvim/tests/noctalia/derive_math_test.lua`
Expected: FAIL — `module 'user.noctalia.derive' not found`

- [ ] **Step 3: Write the implementation**

```lua
-- nvim/lua/user/noctalia/derive.lua
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
  local max, min = math.max(r, g, b), math.min(r, g, b)
  local l = (max + min) / 2
  if max == min then return 0, 0, l end
  local d = max - min
  local s = l > 0.5 and d / (2 - max - min) or d / (max + min)
  local h
  if max == r then h = ((g - b) / d) % 6
  elseif max == g then h = (b - r) / d + 2
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nvim -l nvim/tests/noctalia/derive_math_test.lua`
Expected: `OK derive_math`

- [ ] **Step 5: Commit**

```bash
git add nvim/lua/user/noctalia/derive.lua nvim/tests/noctalia/derive_math_test.lua
git commit -m "feat(nvim): noctalia color math primitives"
```

---

### Task 2: derive.lua — moods and full ColorScheme assembly

**Files:**
- Modify: `nvim/lua/user/noctalia/derive.lua` (append; keep Task 1 content)
- Create: `nvim/tests/noctalia/fixtures/raw_palette.json` (the Artifact contract example, verbatim)
- Test: `nvim/tests/noctalia/derive_scheme_test.lua`

**Interfaces:**
- Consumes: Task 1 math functions; a raw palette table per the Artifact contract.
- Produces:
  - `derive.MOODS` — array `{ 'material', 'spectrum', 'warm', 'pastel' }`
  - `derive.accents(raw, mood) -> { blue, cyan, teal, green, yellow, orange, red, magenta, purple }` (all hex). Behavioral contract, tested exactly:
    - synthesized slots (`orange/yellow/green/teal/cyan/magenta/purple`) sit at fixed hue anchors (35/70/130/172/195/310/285°); `spectrum` uses primary's s/l unchanged; `warm` pulls hue 25% toward 45° and multiplies s by 1.15; `pastel` multiplies s by 0.6 and lifts l by `(1-l)*0.3`
    - `blue` = `raw.primary` and `red` = `raw.error`, verbatim, in every non-material mood
    - `material` maps slots onto the four accents only (blue=primary, cyan=primary_fixed_dim, green=secondary, teal=secondary_fixed_dim, orange=tertiary, yellow=tertiary_fixed_dim, magenta=tertiary, purple=tertiary_fixed_dim, red=error)
  - `derive.colorscheme(raw, mood) -> colors` — a COMPLETE tokyonight `ColorScheme` table: every field tokyonight has after its own derivation and BEFORE `on_colors` runs (verified against `tokyonight/colors/init.lua` + `colors/moon.lua`): base fields `bg, bg_dark, bg_dark1, bg_highlight, blue, blue0, blue1, blue2, blue5, blue6, blue7, comment, cyan, dark3, dark5, fg, fg_dark, fg_gutter, green, green1, green2, magenta, magenta2, orange, purple, red, red1, teal, terminal_black, yellow`, nested `git {add, change, delete, ignore}`, and derived fields `none, diff {add, delete, change, text}, black, border_highlight, border, bg_popup, bg_statusline, bg_sidebar, bg_float, bg_visual, bg_search, fg_sidebar, fg_float, error, todo, warning, info, hint, rainbow (8 entries), terminal (16 entries: black, black_bright, red, red_bright, green, green_bright, yellow, yellow_bright, blue, blue_bright, magenta, magenta_bright, cyan, cyan_bright, white, white_bright)`.

Unknown mood must `error()` with a message listing `derive.MOODS`.

- [ ] **Step 1: Create the fixture and write the failing test**

`nvim/tests/noctalia/fixtures/raw_palette.json` — the JSON block from the Artifact contract section, byte-for-byte.

```lua
-- nvim/tests/noctalia/derive_scheme_test.lua
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim -l nvim/tests/noctalia/derive_scheme_test.lua`
Expected: FAIL — `d.MOODS` is nil

- [ ] **Step 3: Append the implementation to derive.lua**

```lua
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
```

- [ ] **Step 4: Run both derive tests, verify pass**

Run: `nvim -l nvim/tests/noctalia/derive_math_test.lua && nvim -l nvim/tests/noctalia/derive_scheme_test.lua`
Expected: `OK derive_math`, `OK derive_scheme`

- [ ] **Step 5: Commit**

```bash
git add nvim/lua/user/noctalia/derive.lua nvim/tests/noctalia/derive_scheme_test.lua nvim/tests/noctalia/fixtures/raw_palette.json
git commit -m "feat(nvim): mood derivation and full tokyonight ColorScheme assembly"
```

---

### Task 3: default palette + loader (palette.lua)

**Files:**
- Create: `nvim/lua/user/noctalia/default_palette.lua`
- Create: `nvim/lua/user/noctalia/palette.lua`
- Test: `nvim/tests/noctalia/palette_test.lua`

**Interfaces:**
- Consumes: Artifact contract shape (decoded table).
- Produces:
  - `require('user.noctalia.default_palette')` — a raw palette table (Lua module, committed — this one is NOT generated), tokyonight-moon flavored, values identical to the fixture. Its `glass` six MUST equal the hexes on the `transparent_background_colors` line in `kitty/kitty.conf` (fresh-machine invariant, asserted by the test).
  - `palette.path` — string, promoted artifact path (reassignable, so tests can point it at fixtures); default `~/.cache/noctalia/nvim-glass/current/nvim-palette.json` (expanded).
  - `palette.validate(raw) -> raw | nil, err`
  - `palette.load() -> raw` — decoded+validated artifact if the file exists (hard error if unreadable, undecodable, or invalid), else the default (with one `vim.notify` warning).

- [ ] **Step 1: Write the failing test**

```lua
-- nvim/tests/noctalia/palette_test.lua
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

-- validate: glass collision
bad = read_json(fixture); bad.glass.tab_on = bad.glass.chrome
ok, err = p.validate(bad)
assert(not ok and err:match('collide'), 'glass collision detected')

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
-- default glass six, in registered-role order
local conf = assert(io.open('kitty/kitty.conf')):read('*a')
local line = conf:match('\ntransparent_background_colors ([^\n]+)')
assert(line, 'kitty.conf fallback line missing')
local tones = {}
for hex in line:gmatch('#%x%x%x%x%x%x') do tones[#tones + 1] = hex end
local order = { 'chrome', 'cursorline', 'tab_on', 'tab_off', 'tab_fill', 'raised' }
assert(#tones == #order, 'kitty fallback must list exactly six tones')
for i, role in ipairs(order) do
  assert(tones[i] == default.glass[role],
    ('kitty fallback tone %d != default glass.%s'):format(i, role))
end

print('OK palette')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim -l nvim/tests/noctalia/palette_test.lua`
Expected: FAIL — `module 'user.noctalia.palette' not found`

- [ ] **Step 3: Write the implementation**

`default_palette.lua` — the Artifact contract values as a Lua table, with this header:

```lua
-- Fallback raw palette for machines where noctalia has not generated
-- ~/.cache/noctalia/nvim-glass/current/nvim-palette.json yet.
-- Tokyonight-moon flavored. The glass table MUST stay identical to the
-- hardcoded transparent_background_colors fallback line in kitty/kitty.conf
-- (asserted by nvim/tests/noctalia/palette_test.lua).
return {
  primary = '#82aaff',
  primary_fixed_dim = '#65bcff',
  on_primary = '#1e2030',
  secondary = '#86e1fc',
  secondary_fixed_dim = '#4fd6be',
  tertiary = '#c099ff',
  tertiary_fixed_dim = '#fca7ea',
  error = '#ff757f',
  error_container = '#c53b53',
  surface = '#222436',
  on_surface = '#c8d3f5',
  on_surface_variant = '#828bb8',
  on_background = '#c8d3f5',
  outline = '#636da6',
  outline_variant = '#545c7e',
  surface_variant = '#2f334d',
  glass = {
    chrome = '#1e2030',
    cursorline = '#2f334d',
    tab_on = '#222436',
    tab_off = '#272a3f',
    tab_fill = '#2c3048',
    raised = '#3b4261',
    float = '#16161e',
  },
}
```

```lua
-- nvim/lua/user/noctalia/palette.lua
-- Loads the noctalia-generated raw palette (JSON), validating shape and the
-- glass invariants (six distinct registered tones; float solid and
-- unregistered). bin/noctalia-glass-sync enforces the same invariants before
-- promoting, so a hard error here means the promoted file was hand-edited or
-- corrupted. Only a MISSING file falls back (fresh machine).

local M = {}

-- Keep in sync with REQUIRED in bin/noctalia-glass-sync.
local REQUIRED = {
  'primary', 'primary_fixed_dim', 'on_primary',
  'secondary', 'secondary_fixed_dim',
  'tertiary', 'tertiary_fixed_dim',
  'error', 'error_container',
  'surface', 'on_surface', 'on_surface_variant', 'on_background',
  'outline', 'outline_variant', 'surface_variant',
}
local REGISTERED_ROLES = { 'chrome', 'cursorline', 'tab_on', 'tab_off', 'tab_fill', 'raised' }

local function is_hex(v) return type(v) == 'string' and v:match('^#%x%x%x%x%x%x$') ~= nil end

function M.validate(raw)
  if type(raw) ~= 'table' then return nil, 'not a table' end
  for _, key in ipairs(REQUIRED) do
    if not is_hex(raw[key]) then return nil, ('missing/invalid key %q'):format(key) end
  end
  if type(raw.glass) ~= 'table' then return nil, 'missing glass table' end
  local seen = {}
  for _, role in ipairs(REGISTERED_ROLES) do
    local v = raw.glass[role]
    if not is_hex(v) then return nil, ('glass.%s missing/invalid'):format(role) end
    v = v:lower()
    if seen[v] then return nil, ('glass tones collide on %s'):format(v) end
    seen[v] = true
  end
  if not is_hex(raw.glass.float) then return nil, 'glass.float missing/invalid' end
  if seen[raw.glass.float:lower()] then return nil, 'glass.float is a registered tone' end
  if raw.glass.float:lower() == raw.surface:lower() then
    return nil, 'glass.float equals surface (floats would go translucent)'
  end
  return raw
end

M.path = vim.fn.expand('~/.cache/noctalia/nvim-glass/current/nvim-palette.json')

local warned = false

function M.load()
  -- Only a genuinely ABSENT file may fall back (fresh machine). Any other
  -- failure -- permission denied, I/O error, present-but-unopenable -- must
  -- surface, or a broken install silently themes with stale colors.
  local stat, stat_err = vim.uv.fs_stat(M.path)
  if not stat then
    if stat_err and not stat_err:match('^ENOENT') then
      error(('noctalia palette %s: %s'):format(M.path, stat_err))
    end
    if not warned then
      warned = true
      vim.schedule(function()
        vim.notify('noctalia palette missing; using built-in default (apply a noctalia color scheme once)',
          vim.log.levels.WARN)
      end)
    end
    return require('user.noctalia.default_palette')
  end
  local fh, open_err = io.open(M.path)
  if not fh then
    error(('noctalia palette %s exists but cannot be read: %s'):format(
      M.path, tostring(open_err)))
  end
  local text = fh:read('*a')
  fh:close()
  local ok, raw = pcall(vim.json.decode, text)
  if not ok then
    error(('noctalia palette %s is not valid JSON: %s'):format(M.path, raw))
  end
  local valid, err = M.validate(raw)
  if not valid then
    error(('noctalia palette %s invalid: %s'):format(M.path, err))
  end
  return valid
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nvim -l nvim/tests/noctalia/palette_test.lua`
Expected: `OK palette`

- [ ] **Step 5: Commit**

```bash
git add nvim/lua/user/noctalia/default_palette.lua nvim/lua/user/noctalia/palette.lua nvim/tests/noctalia/palette_test.lua
git commit -m "feat(nvim): noctalia palette loader with validated glass invariants"
```

---

### Task 4: the noctalia template

**Files:**
- Create: `nvim/lua/user/noctalia/palette-template.json`
- Test: `nvim/tests/noctalia/template_test.lua`

**Interfaces:**
- Consumes: noctalia template placeholders `{{colors.<token>.default.hex}}` (syntax verified against noctalia's built-in templates; all tokens used appear in those templates).
- Produces: the render-time source of the Artifact contract. **This file is the ONLY place the glass-role → material-token mapping exists.**

- [ ] **Step 1: Write the failing test**

```lua
-- nvim/tests/noctalia/template_test.lua
package.path = 'nvim/lua/?.lua;nvim/lua/?/init.lua;' .. package.path
local p = require('user.noctalia.palette')

local fh = assert(io.open('nvim/lua/user/noctalia/palette-template.json'),
  'template file missing')
local text = fh:read('*a'); fh:close()

-- every placeholder must be a well-formed noctalia color reference
for ph in text:gmatch('{{(.-)}}') do
  assert(ph:match('^colors%.[%w_]+%.default%.hex$'), 'bad placeholder: ' .. ph)
end

-- substitute each DISTINCT token with a distinct hex, then decode + validate
local tokens, n = {}, 0
local rendered = text:gsub('{{colors%.([%w_]+)%.default%.hex}}', function(tok)
  if not tokens[tok] then n = n + 1; tokens[tok] = string.format('#%06x', n * 1111) end
  return tokens[tok]
end)
assert(not rendered:find('{{', 1, true), 'unsubstituted placeholder left')

local ok, raw = pcall(vim.json.decode, rendered)
assert(ok, 'rendered template must be valid JSON: ' .. tostring(raw))
assert(p.validate(raw), 'rendered template must satisfy palette.validate')

print('OK template')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim -l nvim/tests/noctalia/template_test.lua`
Expected: FAIL — `template file missing`

- [ ] **Step 3: Write the template**

```json
{
  "primary": "{{colors.primary.default.hex}}",
  "primary_fixed_dim": "{{colors.primary_fixed_dim.default.hex}}",
  "on_primary": "{{colors.on_primary.default.hex}}",
  "secondary": "{{colors.secondary.default.hex}}",
  "secondary_fixed_dim": "{{colors.secondary_fixed_dim.default.hex}}",
  "tertiary": "{{colors.tertiary.default.hex}}",
  "tertiary_fixed_dim": "{{colors.tertiary_fixed_dim.default.hex}}",
  "error": "{{colors.error.default.hex}}",
  "error_container": "{{colors.error_container.default.hex}}",
  "surface": "{{colors.surface.default.hex}}",
  "on_surface": "{{colors.on_surface.default.hex}}",
  "on_surface_variant": "{{colors.on_surface_variant.default.hex}}",
  "on_background": "{{colors.on_background.default.hex}}",
  "outline": "{{colors.outline.default.hex}}",
  "outline_variant": "{{colors.outline_variant.default.hex}}",
  "surface_variant": "{{colors.surface_variant.default.hex}}",
  "glass": {
    "chrome": "{{colors.surface_container_low.default.hex}}",
    "cursorline": "{{colors.surface_variant.default.hex}}",
    "tab_on": "{{colors.surface_container.default.hex}}",
    "tab_off": "{{colors.surface_container_high.default.hex}}",
    "tab_fill": "{{colors.surface_container_highest.default.hex}}",
    "raised": "{{colors.outline_variant.default.hex}}",
    "float": "{{colors.surface_container_lowest.default.hex}}"
  }
}
```

(JSON has no comments; the glass-mapping rationale lives here in the plan and in the spec: `float` needs a darker-than-`surface` tone that is NOT registered, and `surface_container_lowest` is the only material token darker than surface — so `_lowest` is `float` and `outline_variant` takes the sixth registered slot. The swatch session in Task 9 may re-shuffle this mapping; that is expected and only touches this file.)

- [ ] **Step 4: Run test to verify it passes**

Run: `nvim -l nvim/tests/noctalia/template_test.lua`
Expected: `OK template` (if it fails, the template shape and validator disagree — fix the template, not the validator)

- [ ] **Step 5: Commit**

```bash
git add nvim/lua/user/noctalia/palette-template.json nvim/tests/noctalia/template_test.lua
git commit -m "feat(nvim): noctalia palette template with glass tone mapping"
```

---

### Task 5: bin/noctalia-glass-sync — validate, stage, flip, signal

**Files:**
- Create: `bin/noctalia-glass-sync` (mode 755)
- Test: `nvim/tests/noctalia/glass_sync_test.sh` (mode 755)

**Interfaces:**
- Consumes: `$NOCTALIA_GLASS_DIR/nvim-palette.candidate.json` where `NOCTALIA_GLASS_DIR` defaults to `~/.cache/noctalia` (env override is for tests ONLY; production is the literal default).
- Produces on success: a new version dir `$NOCTALIA_GLASS_DIR/nvim-glass/v-*/` containing `nvim-palette.json` (candidate content verbatim) and `kitty-glass.conf` (one `transparent_background_colors` line, tones in role order); the `current` symlink atomically renamed onto it; the candidate consumed; older version dirs pruned; then `pkill -SIGUSR1 -x kitty` and `pkill -SIGUSR1 -x nvim`. Flag `--no-signal` skips the pkills (tests). On any PRE-COMMIT failure — missing candidate, JSON syntax error, missing/invalid key, glass invariant violation, or an error while staging the version dir before the rename: stderr message + `notify-send` (if available), `current` and existing version dirs untouched, exit 1. A failure AFTER the rename (pkill, prune) leaves the new generation committed; fresh reads through `current` see it, and already-running processes stay on their loaded generation until the next successful run signals them.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# nvim/tests/noctalia/glass_sync_test.sh — run from repo root
set -euo pipefail

SYNC="$PWD/bin/noctalia-glass-sync"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export NOCTALIA_GLASS_DIR="$TMP"
CUR="$TMP/nvim-glass/current"

good_candidate() {
  cp nvim/tests/noctalia/fixtures/raw_palette.json "$TMP/nvim-palette.candidate.json"
}

# 1. success: current symlink appears, both files inside, candidate consumed
good_candidate
"$SYNC" --no-signal
[[ -L "$CUR" ]] || { echo "FAIL: current symlink missing"; exit 1; }
[[ -f "$CUR/nvim-palette.json" && -f "$CUR/kitty-glass.conf" ]] || { echo "FAIL: staged files missing"; exit 1; }
[[ ! -f "$TMP/nvim-palette.candidate.json" ]] || { echo "FAIL: candidate left behind"; exit 1; }
grep -q '^transparent_background_colors #1e2030 #2f334d #222436 #272a3f #2c3048 #3b4261$' \
  "$CUR/kitty-glass.conf" || { echo "FAIL: kitty conf wrong"; cat "$CUR/kitty-glass.conf"; exit 1; }

# 2. second success: symlink flips, exactly one version dir remains
first_target=$(readlink "$CUR")
good_candidate
sed -i 's/#82aaff/#83abff/' "$TMP/nvim-palette.candidate.json"
"$SYNC" --no-signal
[[ "$(readlink "$CUR")" != "$first_target" ]] || { echo "FAIL: symlink did not flip"; exit 1; }
grep -q '#83abff' "$CUR/nvim-palette.json" || { echo "FAIL: new palette not promoted"; exit 1; }
ndirs=$(find "$TMP/nvim-glass" -mindepth 1 -maxdepth 1 -type d | wc -l)
[[ "$ndirs" == 1 ]] || { echo "FAIL: expected 1 version dir, got $ndirs"; exit 1; }

# helper: run sync expecting failure, assert current untouched
expect_reject() {
  local why=$1
  local before=$(readlink "$CUR")
  if "$SYNC" --no-signal 2>/dev/null; then echo "FAIL: accepted $why"; exit 1; fi
  [[ "$(readlink "$CUR")" == "$before" ]] || { echo "FAIL: current moved on $why"; exit 1; }
}

# 3. missing candidate
expect_reject "missing candidate"

# 4. invalid JSON syntax
echo '{ not json' > "$TMP/nvim-palette.candidate.json"
expect_reject "broken JSON"

# 5. missing accent key (complete-artifact validation, not just glass)
good_candidate
python3 - "$TMP/nvim-palette.candidate.json" <<'EOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
del d['tertiary']
json.dump(d, open(p, 'w'))
EOF
expect_reject "missing accent key"

# 6. colliding glass tones
good_candidate
sed -i 's/"tab_on": "#222436"/"tab_on": "#1e2030"/' "$TMP/nvim-palette.candidate.json"
expect_reject "glass collision"

# 7. float equal to a registered tone
good_candidate
sed -i 's/"float": "#16161e"/"float": "#3b4261"/' "$TMP/nvim-palette.candidate.json"
expect_reject "registered float"

# 8. float equal to surface
good_candidate
sed -i 's/"float": "#16161e"/"float": "#222436"/' "$TMP/nvim-palette.candidate.json"
expect_reject "float==surface"

# 9. candidate I/O error uses the clean failure path, not a traceback
rm -f "$TMP/nvim-palette.candidate.json"
mkdir "$TMP/nvim-palette.candidate.json"
before=$(readlink "$CUR")
if err=$("$SYNC" --no-signal 2>&1); then
  echo "FAIL: accepted unreadable candidate"
  exit 1
fi
[[ "$(readlink "$CUR")" == "$before" ]] || { echo "FAIL: current moved on candidate I/O error"; exit 1; }
grep -q '^noctalia-glass-sync:' <<<"$err" || { echo "FAIL: missing clean error prefix"; exit 1; }
! grep -q 'Traceback' <<<"$err" || { echo "FAIL: candidate I/O error produced traceback"; exit 1; }

echo "OK glass_sync"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `chmod +x nvim/tests/noctalia/glass_sync_test.sh && ./nvim/tests/noctalia/glass_sync_test.sh`
Expected: FAIL — `bin/noctalia-glass-sync` does not exist

- [ ] **Step 3: Write the implementation**

```python
#!/usr/bin/env python3
"""Promote the noctalia nvim palette and its kitty glass include, atomically.

Noctalia renders the nvim palette template to nvim-palette.candidate.json and
then runs this hook. We validate the COMPLETE candidate (JSON syntax, every
required key, glass invariants), stage the promoted palette and kitty's
transparent_background_colors include into a fresh version directory, and
flip the `current` symlink over both with a single atomic rename.

The rename is the COMMIT POINT. Before it, any failure or kill leaves the
previous generation fully intact -- readers (kitty include, nvim load) go
through `current` and never see a half-promoted state. The SIGUSR1 signals
after it are post-commit reconciliation, not part of the transaction: a kill
between commit and signalling leaves already-running processes on the old
generation until the next successful run signals them (new processes always
read the committed generation).

Spec: docs/specs/2026-08-09-noctalia-nvim-theme-design.md
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

BASE = Path(os.environ.get('NOCTALIA_GLASS_DIR', str(Path.home() / '.cache' / 'noctalia')))
CANDIDATE = BASE / 'nvim-palette.candidate.json'
GLASS_DIR = BASE / 'nvim-glass'
CURRENT = GLASS_DIR / 'current'

# Keep in sync with REQUIRED in nvim/lua/user/noctalia/palette.lua.
REQUIRED = (
    'primary', 'primary_fixed_dim', 'on_primary',
    'secondary', 'secondary_fixed_dim',
    'tertiary', 'tertiary_fixed_dim',
    'error', 'error_container',
    'surface', 'on_surface', 'on_surface_variant', 'on_background',
    'outline', 'outline_variant', 'surface_variant',
)
# Order matters: the order tones appear on kitty's line.
REGISTERED_ROLES = ('chrome', 'cursorline', 'tab_on', 'tab_off', 'tab_fill', 'raised')


def is_hex(v: object) -> bool:
    return (isinstance(v, str) and len(v) == 7 and v[0] == '#'
            and all(ch in '0123456789abcdefABCDEF' for ch in v[1:]))


def fail(msg: str) -> None:
    print(f'noctalia-glass-sync: {msg}', file=sys.stderr)
    if shutil.which('notify-send'):
        subprocess.run(
            ['notify-send', '-u', 'critical', 'noctalia-glass-sync', msg], check=False)
    sys.exit(1)


def validate(raw: object) -> dict:
    if not isinstance(raw, dict):
        fail('candidate is not a JSON object')
    for key in REQUIRED:
        if not is_hex(raw.get(key)):
            fail(f'missing/invalid key {key!r}')
    glass = raw.get('glass')
    if not isinstance(glass, dict):
        fail('missing glass table')
    seen = set()
    for role in REGISTERED_ROLES:
        v = glass.get(role)
        if not is_hex(v):
            fail(f'glass.{role} missing/invalid')
        v = v.lower()
        if v in seen:
            fail(f'glass tones collide on {v}')
        seen.add(v)
    if not is_hex(glass.get('float')):
        fail('glass.float missing/invalid')
    if glass['float'].lower() in seen:
        fail('glass.float is a registered tone')
    if glass['float'].lower() == raw['surface'].lower():
        fail('glass.float equals surface (floats would go translucent)')
    return raw


def main() -> None:
    signal = '--no-signal' not in sys.argv[1:]
    if not CANDIDATE.exists():
        fail(f'candidate missing: {CANDIDATE}')
    text = CANDIDATE.read_text()
    try:
        raw = json.loads(text)
    except json.JSONDecodeError as exc:
        fail(f'candidate is not valid JSON: {exc}')
    validate(raw)
    tones = [raw['glass'][role].lower() for role in REGISTERED_ROLES]

    GLASS_DIR.mkdir(parents=True, exist_ok=True)
    vdir = Path(tempfile.mkdtemp(dir=GLASS_DIR, prefix='v-'))
    os.chmod(vdir, 0o755)  # mkdtemp defaults to 0700
    (vdir / 'nvim-palette.json').write_text(text)
    (vdir / 'kitty-glass.conf').write_text(
        'transparent_background_colors ' + ' '.join(tones) + '\n')

    # Single atomic switch: rename a prepared symlink over `current`.
    tmplink = GLASS_DIR / f'.current-tmp-{os.getpid()}'
    if tmplink.is_symlink() or tmplink.exists():
        tmplink.unlink()
    os.symlink(vdir.name, tmplink)
    os.replace(tmplink, CURRENT)

    CANDIDATE.unlink()  # consumed only after the flip succeeded

    # Prune superseded version dirs (readers that already opened files in
    # them keep their fds; new readers only ever see `current`).
    target = os.readlink(CURRENT)
    for entry in GLASS_DIR.iterdir():
        if entry.is_dir() and not entry.is_symlink() and entry.name != target:
            shutil.rmtree(entry, ignore_errors=True)

    if signal:
        # pkill exits 1 when no process matched; that is fine (nothing running).
        subprocess.run(['pkill', '-SIGUSR1', '-x', 'kitty'], check=False)
        subprocess.run(['pkill', '-SIGUSR1', '-x', 'nvim'], check=False)


if __name__ == '__main__':
    try:
        main()
    except OSError as exc:
        fail(str(exc))
```

- [ ] **Step 4: Run test to verify it passes**

Run: `chmod +x bin/noctalia-glass-sync && ./nvim/tests/noctalia/glass_sync_test.sh`
Expected: `OK glass_sync`

- [ ] **Step 5: Commit**

```bash
git add bin/noctalia-glass-sync nvim/tests/noctalia/glass_sync_test.sh
git commit -m "feat: noctalia-glass-sync validate-stage-flip hook"
```

---

### Task 6: user/noctalia/init.lua — moods, command, signal, on_colors

**Files:**
- Create: `nvim/lua/user/noctalia/init.lua`
- Test: `nvim/tests/noctalia/noctalia_test.lua`
- Test: `nvim/tests/noctalia/tokyonight_test.lua` (integration against the installed tokyonight)

**Interfaces:**
- Consumes: `palette.load()` (Task 3), `derive.colorscheme(raw, mood)` / `derive.MOODS` (Task 2), `require('tokyonight.util')` (installed plugin).
- Produces (consumed by Task 7's glass and Task 8's wiring):
  - `noctalia.state_file` — string path (reassignable for tests); default `vim.fn.stdpath('state') .. '/noctalia-mood'`
  - `noctalia.mood() -> string` — persisted mood; `'spectrum'` ONLY when the state file is missing (ENOENT). A present-but-invalid state file is a hard error listing valid moods, and a present-but-unreadable one (EACCES, I/O error) is a hard error too (fail early — no silent fallback).
  - `noctalia.set_mood(name)` — validates against `derive.MOODS`, persists, calls `M.reload()`
  - `noctalia.colors() -> colors` — derived ColorScheme for current palette+mood
  - `noctalia.on_colors(colors)` — clears the passed table, repopulates from `colors()`, AND updates `require('tokyonight.util').bg/.fg`. Tokyonight caches `Util.bg`/`Util.fg` BEFORE invoking the callback and its highlight groups blend against them afterwards — without this update, blends keep using moon's background.
  - `noctalia.reload()` — busts the lualine theme cache, re-runs `vim.cmd.colorscheme('tokyonight')` (the name used at `nvim/init.lua:345` — there is no `tokyonight-moon` call in this config; the moon style comes from tokyonight's default `style`)
  - `noctalia.setup()` — registers `:NoctaliaMood` (nargs=1, completion = MOODS) and the `Signal`/`SIGUSR1` autocmd calling `reload()`

- [ ] **Step 1: Write the failing unit test**

```lua
-- nvim/tests/noctalia/noctalia_test.lua
package.path = 'nvim/lua/?.lua;nvim/lua/?/init.lua;' .. package.path
-- on_colors touches tokyonight.util; make the installed plugin requirable
vim.opt.rtp:prepend(vim.fn.stdpath('data') .. '/lazy/tokyonight.nvim')

local noctalia = require('user.noctalia')
local palette = require('user.noctalia.palette')

-- run against the fixture artifact and a temp state file
palette.path = 'nvim/tests/noctalia/fixtures/raw_palette.json'
noctalia.state_file = os.tmpname()

-- default mood only when the state file is MISSING
os.remove(noctalia.state_file)
assert(noctalia.mood() == 'spectrum', 'default mood')

-- persist + read back (reload() is exercised in live nvim in Task 8; here we
-- only care that the choice round-trips)
local called = false
noctalia.reload = function() called = true end
noctalia.set_mood('pastel')
assert(called, 'set_mood must reload')
assert(noctalia.mood() == 'pastel', 'mood persisted')

-- corrupt state file is a hard error naming the valid moods (fail early)
local fh = io.open(noctalia.state_file, 'w'); fh:write('vaporwave\n'); fh:close()
local ok, err = pcall(noctalia.mood)
assert(not ok and err:match('spectrum'), 'corrupt state must error listing moods')

-- a PRESENT but unreadable state file is a hard error, never a default
-- (only ENOENT may default; EACCES etc. must surface)
fh = io.open(noctalia.state_file, 'w'); fh:write('spectrum\n'); fh:close()
os.execute("chmod 000 '" .. noctalia.state_file .. "'")
ok = pcall(noctalia.mood)
os.execute("chmod 600 '" .. noctalia.state_file .. "'")
assert(not ok, 'unreadable state file must error, not default')

-- unknown mood rejected by set_mood
os.remove(noctalia.state_file)
assert(not pcall(noctalia.set_mood, 'vaporwave'), 'unknown mood rejected')

-- on_colors clears and repopulates in place (tokyonight ignores returns)
local tbl = { stale_field = '#123456', bg = '#000000' }
noctalia.on_colors(tbl)
assert(tbl.stale_field == nil, 'stale field must be removed')
assert(tbl.bg == '#222436', 'bg replaced from artifact surface')
assert(tbl.bg_statusline == '#1e2030', 'derived chrome present')

os.remove(noctalia.state_file)
print('OK noctalia')
```

- [ ] **Step 2: Write the failing integration test**

The fixture's `surface` equals moon's `bg`, which would mask a stale `Util.bg`; the test uses an altered surface, exactly the reproduction from review (`colors.bg` updated while `util.bg` stayed `#222436`).

```lua
-- nvim/tests/noctalia/tokyonight_test.lua
package.path = 'nvim/lua/?.lua;nvim/lua/?/init.lua;' .. package.path
vim.opt.rtp:prepend(vim.fn.stdpath('data') .. '/lazy/tokyonight.nvim')

local noctalia = require('user.noctalia')
local palette = require('user.noctalia.palette')
noctalia.state_file = os.tmpname()
os.remove(noctalia.state_file)

-- fixture with surface changed to a value moon never uses
local fh = assert(io.open('nvim/tests/noctalia/fixtures/raw_palette.json'))
local text = fh:read('*a'); fh:close()
local alt = os.tmpname() .. '.json'
-- NB: #222436 also appears as glass.tab_on; rewriting both keeps the glass
-- six distinct and float rules intact, so validation still passes.
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
```

- [ ] **Step 3: Run both to verify they fail**

Run: `nvim -l nvim/tests/noctalia/noctalia_test.lua; nvim -l nvim/tests/noctalia/tokyonight_test.lua`
Expected: both FAIL — `module 'user.noctalia' not found`

- [ ] **Step 4: Write the implementation**

```lua
-- nvim/lua/user/noctalia/init.lua
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
  fh:write(name, '\n')
  fh:close()
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
```

- [ ] **Step 5: Run both tests to verify they pass**

Run: `nvim -l nvim/tests/noctalia/noctalia_test.lua && nvim -l nvim/tests/noctalia/tokyonight_test.lua`
Expected: `OK noctalia`, `OK tokyonight`

- [ ] **Step 6: Commit**

```bash
git add nvim/lua/user/noctalia/init.lua nvim/tests/noctalia/noctalia_test.lua nvim/tests/noctalia/tokyonight_test.lua
git commit -m "feat(nvim): noctalia mood state, SIGUSR1 reload, tokyonight on_colors glue"
```

---

### Task 7: glass.lua — recompute from the palette on every apply

**Files:**
- Modify: `nvim/lua/user/glass.lua`
- Test: `nvim/tests/noctalia/glass_test.lua`

**Interfaces:**
- Consumes: `require('user.noctalia.palette').load().glass` (Task 3).
- Produces (public surface kept for `ui.lua`): `glass.setup()`, `glass.apply()`, `glass.lualine_theme() -> table`, `glass.palette` (role → hex incl. `float`, refreshed by `apply()`/`lualine_theme()`), `glass.registered` (hex → true, refreshed likewise).

Today `glass.lua:22-49` computes `M.palette`, `M.registered`, `float_bg`, and `recolor` once at module load — after this task they are derived from the artifact inside `apply()` (the "snapshots, not live state" review finding). Preserve the existing header comment block (kitty per-cell mechanics) but update the "Keep `palette` in sync with kitty.conf" sentence: the sync is now automatic via the shared artifact; kitty.conf's hardcoded line is only the fresh-machine fallback. Keep the lualine mode-badge comment and logic.

- [ ] **Step 1: Write the failing test**

```lua
-- nvim/tests/noctalia/glass_test.lua
package.path = 'nvim/lua/?.lua;nvim/lua/?/init.lua;' .. package.path
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim -l nvim/tests/noctalia/glass_test.lua`
Expected: FAIL — the liveness asserts at the end MUST fail against the current snapshot implementation (early asserts may pass because the hardcoded values coincide with the fixture).

- [ ] **Step 3: Rework glass.lua**

Keep the file's header comment (updated as described above), then:

```lua
local M = {}

-- Filled by refresh(); role -> hex (incl. float). Exposed because
-- lualine_theme() and plugins/ui.lua read roles from it.
M.palette = {}
-- hex -> true for the six tones kitty will render translucent.
M.registered = {}

local ROLE_KEYS = { 'chrome', 'cursorline', 'tab_on', 'tab_off', 'tab_fill', 'raised' }

local function refresh()
  local glass = require('user.noctalia.palette').load().glass
  M.palette = {}
  M.registered = {}
  for _, role in ipairs(ROLE_KEYS) do
    M.palette[role] = glass[role]
    M.registered[glass[role]:lower()] = true
  end
  M.palette.float = glass.float
end

local function repaint(group, bg)
  vim.api.nvim_set_hl(0, group, vim.tbl_extend('force',
    vim.api.nvim_get_hl(0, { name = group, link = false }), { bg = bg }))
end

function M.apply()
  refresh()
  -- Popups must stay solid: paint them in a color that is NOT on kitty's
  -- transparent list (and differs from the default background).
  for _, group in ipairs({ 'NormalFloat', 'FloatBorder', 'Pmenu' }) do
    repaint(group, M.palette.float)
  end
  -- Groups that paint their own background and would otherwise punch an
  -- opaque rectangle through the glass: reuse already-registered tones.
  repaint('ColorColumn', M.palette.tab_off)
  repaint('ScrollView', M.palette.raised)
end

function M.setup()
  M.apply()
  vim.api.nvim_create_autocmd('ColorScheme', { callback = M.apply })
end

function M.lualine_theme()
  refresh()
  local theme = vim.deepcopy(require('lualine.themes.tokyonight'))
  for _, sections in pairs(theme) do
    for _, key in ipairs({ 'a', 'b', 'c', 'x', 'y', 'z' }) do
      local section = sections[key]
      if type(section) == 'table' and section.bg
         and not M.registered[section.bg:lower()] then
        section.fg, section.bg = section.bg, M.palette.cursorline
      end
    end
  end
  return theme
end

return M
```

(The mode-badge explanation comment above `lualine_theme` stays as in the current file.)

- [ ] **Step 4: Run test to verify it passes**

Run: `nvim -l nvim/tests/noctalia/glass_test.lua`
Expected: `OK glass`

- [ ] **Step 5: Run ALL tests (regression sweep)**

Run: `for t in nvim/tests/noctalia/*_test.lua; do nvim -l "$t" || exit 1; done && ./nvim/tests/noctalia/glass_sync_test.sh`
Expected: every `OK` line, no failures.

- [ ] **Step 6: Commit**

```bash
git add nvim/lua/user/glass.lua nvim/tests/noctalia/glass_test.lua
git commit -m "refactor(nvim): glass recomputes chrome tones from noctalia palette on apply"
```

---

### Task 8: wiring — tokyonight on_colors, lualine function theme, kitty include

**Files:**
- Modify: `nvim/lua/user/plugins/ui.lua` (tokyonight opts at ~line 17; lualine `theme =` at ~line 36)
- Modify: `nvim/init.lua` (before the `vim.cmd.colorscheme('tokyonight')` call at line 345)
- Modify: `kitty/kitty.conf` (after the `transparent_background_colors` line at line 84)

**Interfaces:**
- Consumes: `noctalia.setup()`, `noctalia.on_colors` (Task 6), `glass.lualine_theme` (Task 7).

This task is wiring into a live UI; the automated coverage lives in Tasks 6–7 (on_colors, Util.bg, glass liveness). The steps here are deliberate manual verification of the visible result.

- [ ] **Step 1: ui.lua — tokyonight opts**

Replace `opts = { transparent = true },` in the tokyonight spec with:

```lua
    opts = {
      transparent = true,
      on_colors = function(colors)
        require('user.noctalia').on_colors(colors)
      end,
    },
```

- [ ] **Step 2: ui.lua — lualine theme becomes a function**

Replace `theme = require('user.glass').lualine_theme(),` with:

```lua
          -- A FUNCTION, not a call: lualine re-runs setup() on every
          -- ColorScheme event and re-evaluates function themes, which is what
          -- keeps the statusline in sync with noctalia reloads.
          theme = function() return require('user.glass').lualine_theme() end,
```

- [ ] **Step 3: nvim/init.lua — register the command and signal handler**

Immediately BEFORE the `vim.cmd.colorscheme('tokyonight')` line (345) add:

```lua
-- Noctalia-derived colors: :NoctaliaMood + SIGUSR1 live-reload. Must be set
-- up before the colorscheme loads so the first load already uses on_colors.
require('user.noctalia').setup()
```

(`require('config.lazy')` has already run at this point, so tokyonight's `opts` — including `on_colors` — are registered; `user.glass`'s setup call stays where it is, after the colorscheme.)

- [ ] **Step 4: kitty.conf — the generated include**

After line 84 (`transparent_background_colors #1e2030 ...`) insert:

```
# Noctalia overrides the fallback list above when a scheme has been applied;
# kitty is last-value-wins and only warns if the file does not exist yet.
include ${HOME}/.cache/noctalia/nvim-glass/current/kitty-glass.conf
```

- [ ] **Step 5: Live verification (manual, in a real kitty + nvim)**

1. Simulate a promoted artifact:
   ```bash
   cp nvim/tests/noctalia/fixtures/raw_palette.json ~/.cache/noctalia/nvim-palette.candidate.json
   bin/noctalia-glass-sync --no-signal
   ls -l ~/.cache/noctalia/nvim-glass/current/
   ```
   Expected: `current` symlink with both files (values match tokyonight-moon so nothing should visibly change yet).
2. Open `nvim` in kitty. Expected: no errors on startup, statusline/tabs/cursorline translucent, completion menu and LSP hover floats SOLID.
3. `:NoctaliaMood material` then `:NoctaliaMood spectrum` — syntax colors visibly change per mood, no errors, statusline stays translucent.
4. From another terminal: `pkill -SIGUSR1 -x nvim` — nvim re-applies without errors.
5. `:NoctaliaMood vaporwave` — errors listing valid moods.
6. Open a NEW kitty window — no config errors from the new include line.

- [ ] **Step 6: Commit**

```bash
git add nvim/lua/user/plugins/ui.lua nvim/init.lua kitty/kitty.conf
git commit -m "feat: wire noctalia palette into tokyonight, lualine, and kitty glass include"
```

---

### Task 9: swatch tool + mood tuning session

**Files:**
- Create: `bin/noctalia-mood-swatches` (mode 755)

**Interfaces:**
- Consumes: `palette.load()`, `derive.MOODS`, `derive.accents` (Tasks 2–3).
- Produces: truecolor swatch rows in the terminal — one row per mood (accents) plus a chrome/surface row — for side-by-side comparison against the live wallpaper. This is the tool for the interactive mood-tuning session with the user (per the spec, the mood set/transforms may be tuned or culled there; transform tweaks land in `derive.lua` with its tests updated to match).

- [ ] **Step 1: Write the tool**

```lua
#!/usr/bin/env -S nvim -l
-- bin/noctalia-mood-swatches: print each mood's accent palette as truecolor
-- blocks, plus the glass chrome ladder, for comparison against the live
-- wallpaper. Run from anywhere; resolves the repo via this script's path.

local script = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fs.dirname(vim.fs.dirname(vim.uv.fs_realpath(script)))
package.path = table.concat({
  root .. '/nvim/lua/?.lua',
  root .. '/nvim/lua/?/init.lua',
  package.path,
}, ';')

local derive = require('user.noctalia.derive')
local raw = require('user.noctalia.palette').load()

local function block(hex, label)
  local r, g, b = hex:match('^#(%x%x)(%x%x)(%x%x)$')
  return string.format('\27[48;2;%d;%d;%dm  %s  \27[0m',
    tonumber(r, 16), tonumber(g, 16), tonumber(b, 16), label or hex)
end

local ACCENT_ORDER = { 'red', 'orange', 'yellow', 'green', 'teal', 'cyan', 'blue', 'magenta', 'purple' }
local GLASS_ORDER = { 'chrome', 'tab_on', 'tab_off', 'tab_fill', 'cursorline', 'raised', 'float' }

print('surface ' .. block(raw.surface) .. '  glass:')
local row = {}
for _, role in ipairs(GLASS_ORDER) do
  row[#row + 1] = block(raw.glass[role], role)
end
print('  ' .. table.concat(row, ' '))
print('')

for _, mood in ipairs(derive.MOODS) do
  local acc = derive.accents(raw, mood)
  row = {}
  for _, name in ipairs(ACCENT_ORDER) do
    row[#row + 1] = block(acc[name])
  end
  print(string.format('%-9s %s', mood, table.concat(row, ' ')))
end
```

- [ ] **Step 2: Run it**

Run: `chmod +x bin/noctalia-mood-swatches && bin/noctalia-mood-swatches`
Expected: a glass ladder row and one row of nine colored blocks per mood, no errors. (Colors come from the promoted artifact, or the default palette with a warning if none exists.)

- [ ] **Step 3: CHECKPOINT — interactive tuning with the user**

Show the swatches against the current wallpaper and iterate on `derive.lua`'s `ANCHORS`/`TRANSFORMS` (and, if tone roles read wrong, the template's glass mapping from Task 4) until the user is satisfied. The exact-behavior assertions in `derive_scheme_test.lua` encode the transform constants — update them in the same change as any tuning. Moods may be added or removed here — keep `derive.MOODS`, the tests, and the spec's mood table in sync, and update the spec with `git add -f` if the mood set changes.

- [ ] **Step 4: Commit**

```bash
git add bin/noctalia-mood-swatches nvim/lua/user/noctalia/derive.lua nvim/tests/noctalia/derive_scheme_test.lua
git commit -m "feat: noctalia mood swatch preview tool"
```

(Include `docs/specs/...` with `-f` in the commit if the mood set changed.)

---

### Task 10: glass-check script, activation, docs, end-to-end

**Files:**
- Create: `bin/noctalia-glass-check` (mode 755)
- Test: `nvim/tests/noctalia/glass_check_test.sh` (mode 755)
- Modify: `bin/dotfiles-check`
- Modify: `~/.config/noctalia/user-templates.toml` (machine config — NOT in the repo)
- Modify: `noctalia/noctalia.md`
- Modify: `docs/fresh-install-hardening.md`

**Interfaces:**
- Consumes: the promoted layout from Task 5 (`$NOCTALIA_GLASS_DIR/nvim-glass/current/`, same env override, tests only).
- Produces: `bin/noctalia-glass-check` — exit 0 when the glass state is consistent, exit 1 with a `FAIL:` line otherwise. Consistent means: EITHER no `current` symlink exists (fresh machine — fallbacks apply), OR `current` resolves and both files exist and kitty's six tones equal the palette's six glass tones in role order. Partial state (symlink present but a file missing/unreadable) is a FAILURE, not a skip.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# nvim/tests/noctalia/glass_check_test.sh — run from repo root
set -euo pipefail

CHECK="$PWD/bin/noctalia-glass-check"
SYNC="$PWD/bin/noctalia-glass-sync"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export NOCTALIA_GLASS_DIR="$TMP"

# 1. fresh machine (no current symlink at all): OK
"$CHECK" || { echo "FAIL: fresh state must pass"; exit 1; }

# 2. healthy promoted state: OK
cp nvim/tests/noctalia/fixtures/raw_palette.json "$TMP/nvim-palette.candidate.json"
"$SYNC" --no-signal
"$CHECK" || { echo "FAIL: healthy state must pass"; exit 1; }

# 3. partial state (palette missing): FAIL — this is the case the old
#    dotfiles-check guard silently skipped
rm "$TMP/nvim-glass/current/nvim-palette.json"
if "$CHECK" 2>/dev/null; then echo "FAIL: partial state must fail"; exit 1; fi

# 4. desynced tones: FAIL
cp nvim/tests/noctalia/fixtures/raw_palette.json "$TMP/nvim-palette.candidate.json"
"$SYNC" --no-signal
sed -i 's/#1e2030/#111111/' "$TMP/nvim-glass/current/kitty-glass.conf"
if "$CHECK" 2>/dev/null; then echo "FAIL: desync must fail"; exit 1; fi

# 5. malformed palette shape: a clean FAIL: line, never a traceback
cp nvim/tests/noctalia/fixtures/raw_palette.json "$TMP/nvim-palette.candidate.json"
"$SYNC" --no-signal
echo '{"glass": []}' > "$TMP/nvim-glass/current/nvim-palette.json"
if out=$("$CHECK" 2>&1); then echo "FAIL: malformed shape must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }

echo "OK glass_check"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `chmod +x nvim/tests/noctalia/glass_check_test.sh && ./nvim/tests/noctalia/glass_check_test.sh`
Expected: FAIL — `bin/noctalia-glass-check` does not exist

- [ ] **Step 3: Write the implementation**

```python
#!/usr/bin/env python3
"""Check the promoted noctalia glass state for consistency.

Fresh machines (no `current` symlink) pass: the committed fallbacks apply.
Anything else must be fully consistent: both promoted files present and
kitty's transparent tones equal to the palette's glass tones in role order.
Partial or desynced state fails loudly -- it means a generated file was
hand-edited or a promotion was interrupted, which bin/noctalia-glass-sync
is designed to make impossible.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

BASE = Path(os.environ.get('NOCTALIA_GLASS_DIR', str(Path.home() / '.cache' / 'noctalia')))
CURRENT = BASE / 'nvim-glass' / 'current'
REGISTERED_ROLES = ('chrome', 'cursorline', 'tab_on', 'tab_off', 'tab_fill', 'raised')


def fail(msg: str) -> None:
    print(f'FAIL: noctalia-glass-check: {msg}')
    sys.exit(1)


def main() -> None:
    if not CURRENT.is_symlink() and not CURRENT.exists():
        return  # fresh machine: fallbacks in kitty.conf / default_palette.lua apply
    palette_file = CURRENT / 'nvim-palette.json'
    kitty_file = CURRENT / 'kitty-glass.conf'
    if not palette_file.is_file():
        fail(f'{palette_file} missing (partial promote?)')
    if not kitty_file.is_file():
        fail(f'{kitty_file} missing (partial promote?)')
    # Every failure mode must come out as a FAIL: line, never a traceback --
    # dotfiles-check consumers grep for FAIL.
    try:
        data = json.loads(palette_file.read_text())
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        fail(f'{palette_file} unreadable: {exc}')
    glass = data.get('glass') if isinstance(data, dict) else None
    if not isinstance(glass, dict):
        fail(f'{palette_file} has no glass object')
    palette_tones = []
    for role in REGISTERED_ROLES:
        tone = glass.get(role)
        if not isinstance(tone, str):
            fail(f'{palette_file} glass.{role} missing/malformed')
        palette_tones.append(tone.lower())
    try:
        kitty_text = kitty_file.read_text()
    except (OSError, UnicodeError) as exc:
        fail(f'{kitty_file} unreadable: {exc}')
    m = re.search(r'^transparent_background_colors (.+)$', kitty_text, re.M)
    if not m:
        fail(f'{kitty_file} has no transparent_background_colors line')
    kitty_tones = m.group(1).split()
    if kitty_tones != palette_tones:
        fail(f'tones desynced: kitty={kitty_tones} palette={palette_tones}')


if __name__ == '__main__':
    main()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `chmod +x bin/noctalia-glass-check && ./nvim/tests/noctalia/glass_check_test.sh`
Expected: `OK glass_check`

- [ ] **Step 5: Hook into dotfiles-check**

Add to `bin/dotfiles-check` (follow the script's existing reporting style):

```bash
# noctalia glass invariant: kitty's generated transparent list must equal the
# six chrome tones in the promoted nvim palette. Fails on partial/desynced
# state; passes on fresh machines. See bin/noctalia-glass-check.
bin/noctalia-glass-check
```

Run: `bin/dotfiles-check`
Expected: passes.

- [ ] **Step 6: Register the template on this machine**

Append to `~/.config/noctalia/user-templates.toml` (path style follows the existing `[templates.ohai]` entry; `~` is expanded by noctalia in input/output paths, and the post_hook runs via the shell, so `~/bin` resolves there — the repo's `bin/` is linked to `~/bin` by setup):

```toml
[templates.nvim]
input_path = "~/.config/nvim/lua/user/noctalia/palette-template.json"
output_path = "~/.cache/noctalia/nvim-palette.candidate.json"
post_hook = "~/bin/noctalia-glass-sync"
```

Confirm Settings → Color Scheme → Templates → Advanced → **Enable User Templates** is on (the existing ohai template working is evidence enough).

- [ ] **Step 7: Trigger a real render and verify**

Re-apply the current wallpaper/scheme in noctalia (Settings → Color Scheme → re-select, or change wallpaper). Then:

Run: `ls -l ~/.cache/noctalia/nvim-glass/current/ && cat ~/.cache/noctalia/nvim-glass/current/kitty-glass.conf && bin/noctalia-glass-check && echo CONSISTENT`
Expected: both files with fresh timestamps, six distinct hexes on the kitty line, `CONSISTENT`; `~/.cache/noctalia/nvim-palette.candidate.json` does NOT exist (consumed by promotion).

- [ ] **Step 8: End-to-end wallpaper test (manual)**

1. Open nvim in kitty; change the wallpaper in noctalia.
2. Expected within ~a second: kitty terminal colors change AND nvim recolors (syntax + statusline + tabs) with no manual action.
3. Statusline, barbar tabs, cursorline: translucent (wallpaper visible through them). Completion menu / LSP hover: solid.
4. `:NoctaliaMood` cycling still works after the wallpaper change.
5. `bin/dotfiles-check` still passes.

- [ ] **Step 9: Docs**

- `noctalia/noctalia.md`: add a "Neovim theming" section — one paragraph on the pipeline (template → candidate JSON → `noctalia-glass-sync` validates → version-dir + `current` symlink flip → SIGUSR1), the `user-templates.toml` snippet from Step 6, the mood command, and a pointer to the spec.
- `docs/fresh-install-hardening.md`: add one line to the setup steps: apply a noctalia color scheme once so `~/.cache/noctalia/nvim-glass/current/` exists (until then nvim/kitty use the committed tokyonight-moon fallbacks).

- [ ] **Step 10: Final commit + spec status**

Update the spec's `**Status:**` line to `Implemented (<short-sha range>)` in the same change, per the design-doc rules.

```bash
git add bin/noctalia-glass-check bin/dotfiles-check nvim/tests/noctalia/glass_check_test.sh noctalia/noctalia.md
git add -f docs/fresh-install-hardening.md docs/specs/2026-08-09-noctalia-nvim-theme-design.md
git commit -m "feat: activate noctalia nvim theming (glass check, docs)"
```

---

## Self-review notes (already applied)

- Review round 2 fixes: `on_colors` updates `tokyonight.util.bg/fg` with an integration test using a non-moon surface (T6); the hook validates the COMPLETE artifact and JSON syntax via `json.loads` (T5); promotion is a version-dir + symlink flip — single atomic rename, tested for reject-leaves-current-untouched and flip-then-prune (T5); path contract pinned to `~/.cache/noctalia` with `NOCTALIA_GLASS_DIR` as a tests-only override (Global Constraints, T5, T10); corrupt mood state hard-errors, only a missing file defaults (T6); Task 4 is red-first; `dotfiles-check` delegates to `bin/noctalia-glass-check`, which fails on partial state (T10); mood transforms have exact behavioral tests (T2); the fallback/kitty equality is a committed test, not a manual step (T3); `reload()` and Task 8 use `vim.cmd.colorscheme('tokyonight')` matching `nvim/init.lua:345`.
- Type consistency: `palette.path` / `noctalia.state_file` reassignability used by tests in T3/T6/T7; glass roles are the same seven strings everywhere (artifact contract, `REGISTERED_ROLES` in Lua and Python, `GLASS_ORDER`); the fixture doubles as the hook-test candidate (T5) and equals `default_palette.lua` (asserted in T3).
- Spec sync: the spec was updated alongside this revision (JSON artifact, symlink promotion, full hook validation, mood error semantics, pinned cache path).
- Review round 3 fixes: palette/mood loaders distinguish ENOENT (fallback) from other I/O failures (hard error), with unreadable-present-file tests (T3/T6); the spec's glass mapping matches the template (float = `surface_container_lowest`, sixth slot = `outline_variant`); the transaction guarantee names the symlink rename as the commit point with signalling as post-commit reconciliation (T5 + spec); `noctalia-glass-check` routes shape/read errors through `fail()` with a traceback-regression test (T10).
- Review round 4 fixes: T5's interface scopes the untouched-`current` guarantee to pre-commit failures and describes post-rename failures as leaving the generation committed; the spec's commit-point paragraph limits its claim to fresh reads through `current`; T3's permission test locks a VALID palette copy and asserts `vim.uv.fs_chmod` succeeded, so it can only pass by exercising EACCES; T4's mapping note drops the stale reference to the spec's superseded candidate list.
