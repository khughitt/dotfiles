# Noctalia → Neovim theming (glass-preserving)

**Status:** Design approved, not yet implemented.

## Goal

Make neovim follow noctalia's wallpaper-derived material palette — syntax colors
*and* chrome (statusline, barbar tabs, cursorline) — while preserving the kitty
"glass" translucency system, with live updates on wallpaper change and a
switchable mood variant for syntax hues.

## Constraints (why this is not just a template)

- kitty makes a cell translucent only when its background is the default
  background or one of at most 7 colors listed in `transparent_background_colors`
  (`kitty/kitty.conf`). Six are in use, hardcoded to tokyonight-moon chrome
  colors, mirrored in `nvim/lua/user/glass.lua`.
- If nvim chrome colors become dynamic, kitty's transparent list must change in
  lockstep or the statusline/tabs punch opaque rectangles through the glass.
- `~/.config/nvim` and `~/.config/kitty` are symlinks into this Dropbox-synced
  repo; per-machine generated files must not land where they would sync between
  machines with different wallpapers. (Precedent: noctalia already generates
  `kitty/themes/noctalia.conf` in-tree; the new kitty include follows it.)
- Noctalia's `colors.json` exposes only ~12 keys; the surface-container ladder
  needed for chrome tones is available only through template variables
  (`{{colors.surface_container.default.hex}}` etc.), so a user template is
  required — reading `colors.json` directly is not enough.
- Noctalia palette has 4 accent hues (primary, secondary, tertiary, error);
  tokyonight-shaped highlighting wants ~8+. Extra hues are derived, not sampled.

## Decision

Keep **tokyonight.nvim as the highlight engine** and recolor it via its
`on_colors` hook (approach chosen over base16-nvim, which has coarser highlight
coverage and no transparency option, and over keremimo/noctalia.nvim, which
reads only `colors.json` and has no mood concept). This retains tokyonight's
full treesitter/LSP/plugin coverage, `transparent = true`, and the existing
glass + lualine integration.

## Architecture

### Noctalia user templates (`~/.config/noctalia/user-templates.toml`)

1. `[templates.nvim]`
   - input: `nvim/lua/user/noctalia/palette-template.lua` (in repo)
   - output: `~/.cache/noctalia/nvim-palette.lua` (outside repo, per-machine)
   - post_hook: `pkill -SIGUSR1 nvim`
   - Emits a plain Lua table of raw material colors: the 4 accents (+ on_/
     fixed_dim variants), the surface-container ladder, outline, on_surface
     tones.

2. `[templates.kitty-glass]`
   - input: kitty glass template (in repo)
   - output: `kitty/themes/noctalia-glass.conf`
   - post_hook: `pkill -SIGUSR1 kitty` (kitty's config reload)
   - Emits exactly one line: `transparent_background_colors` with the six
     chrome tones. `kitty.conf` replaces its hardcoded line 84 with
     `include themes/noctalia-glass.conf`.

**Invariant:** both templates draw the six chrome tones from the same noctalia
surface variables, so nvim chrome and kitty's transparent list agree by
construction. Candidate mapping for the six tones: `surface_container_lowest`,
`surface_container_low`, `surface_container`, `surface_container_high`,
`surface_container_highest`, `surface_variant`. They must be pairwise distinct
(glass.lua's badge/separator constraint); if a generated scheme collapses two
of them to the same hex, the scripted invariant check fails and the mapping is
adjusted (final assignment settled during the swatch comparison).

### Nvim modules (`nvim/lua/user/noctalia/`)

- **`palette.lua`** — loads `~/.cache/noctalia/nvim-palette.lua` via `dofile`,
  validates expected keys. Missing file (fresh machine): fall back to a
  committed tokyonight-moon-flavored default palette and `vim.notify` once.
  Malformed palette: hard error, no partial theming.
- **`derive.lua`** — pure-Lua hex↔HSL math. Input: raw palette + mood name.
  Output: full tokyonight-shaped color table (~30 named colors). Derived hues
  (green, yellow, orange, cyan, magenta, …) are synthesized by hue rotation at
  the lightness/chroma of the source accents.
- **`glass.lua`** (existing, modified) — `M.palette`'s six chrome colors read
  from the raw palette's surface ladder instead of hardcoded hexes; `float_bg`
  also palette-derived (must NOT be one of the six). Logic otherwise unchanged.

### Moods

| Mood       | Transform |
|------------|-----------|
| `material` | No derived hues; syntax shares the 4 accents at varying tones |
| `spectrum` | Full hue wheel at primary's lightness/chroma (default) |
| `warm`     | Spectrum biased toward amber/red, chroma nudged up |
| `pastel`   | Spectrum with lightness raised, chroma dropped |

Candidates are rendered as truecolor swatch blocks in the terminal during
implementation for side-by-side comparison against the live wallpaper; the set
may be tuned or culled there.

- `:NoctaliaMood <name>` (with completion) re-derives and re-applies live.
- Choice persists to `~/.local/state/nvim/noctalia-mood` (one line), read at
  startup. Unknown mood: error listing valid moods.

### Wiring

- tokyonight opts: `transparent = true` (unchanged) plus `on_colors` replacing
  its palette with the derived table.
- SIGUSR1 handler (pattern from noctalia docs): re-`dofile` the palette,
  re-derive with current mood, re-apply colorscheme. Existing `ColorScheme`
  autocmd re-applies glass; lualine refreshes.

### Data flow

wallpaper change → noctalia regenerates colors → both user templates rewrite
their outputs → kitty reloads via SIGUSR1 → nvim reloads via SIGUSR1 →
palette → derive(mood) → tokyonight `on_colors` → ColorScheme autocmd → glass.

## Error handling

- Palette file missing → committed default + single `vim.notify`.
- Palette malformed → hard error at load with clear message.
- Unknown mood → error listing valid moods.
- `themes/noctalia-glass.conf` absent on fresh install → kitty warns but
  starts; fresh-install doc gains a one-line "apply a noctalia scheme once"
  step.

## Verification

- Manual: switch wallpapers; kitty + nvim recolor live; statusline, tabs and
  cursorline stay translucent (no opaque rectangles); floats stay solid.
- Scripted: check that the six hexes in the generated
  `kitty/themes/noctalia-glass.conf` equal the six chrome tones exposed by the
  generated nvim palette — the one invariant glass depends on.

## Out of scope

- Theming other apps (yazi, btop, …) — noctalia built-ins already cover them.
- Light-mode variants (noctalia runs dark mode here).
- Upstreaming as a standalone plugin.
