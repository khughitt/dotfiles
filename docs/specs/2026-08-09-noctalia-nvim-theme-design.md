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
  machines with different wallpapers — all generated outputs go under
  `~/.cache/noctalia/`. (Noctalia's built-in kitty template already writes
  `themes/noctalia.conf` in-tree; that pre-existing flaw is out of scope.)
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

### Single template + sync hook (`~/.config/noctalia/user-templates.toml`)

One user template renders a *candidate* palette artifact; the hook script
validates it and promotes both final outputs before signalling anyone. Noctalia
overwrites the template's output_path before the hook runs, so nvim must never
read the render target directly — only the promoted path:

- `[templates.nvim]`
  - input: `nvim/lua/user/noctalia/palette-template.lua` (in repo)
  - output: `~/.cache/noctalia/nvim-palette.candidate.lua` (candidate path;
    all generated files live outside the Dropbox-synced tree)
  - post_hook: `~/bin/noctalia-glass-sync` (setup links the repo's `bin/` to
    `~/bin`; noctalia runs hooks through the shell without setting the repo
    as cwd, so the path must not be repo-relative)
  - Emits a plain Lua table of raw material colors: the 4 accents (+ on_/
    fixed_dim variants), the surface-container ladder, outline, on_surface
    tones.

- **`bin/noctalia-glass-sync`** (committed, executable) does, in order:
  1. Parse the six chrome tones and `float_bg` out of the candidate artifact.
  2. Validate: all hexes well-formed, six tones pairwise distinct (glass.lua's
     badge/separator constraint), `float_bg` not among the six. On failure:
     leave the promoted palette AND the kitty include untouched, emit a
     `notify-send` warning, signal nothing, exit non-zero.
  3. Atomically write `~/.cache/noctalia/kitty-glass.conf` (tmp + rename),
     then atomically promote the candidate to
     `~/.cache/noctalia/nvim-palette.lua` (rename, same filesystem).
  4. Only after both promotions: `pkill -SIGUSR1 kitty` (config reload), then
     `pkill -SIGUSR1 nvim`.

  Nvim reads only the promoted `nvim-palette.lua`, so a failed validation —
  or a hook that never ran — leaves running *and newly started* programs on
  the previous consistent state.

- `kitty.conf` keeps its hardcoded `transparent_background_colors` line as the
  fallback and gains, after it, `include ${HOME}/.cache/noctalia/kitty-glass.conf`
  (env-var expansion in include paths is already used for `${HOSTNAME}.conf`;
  kitty is last-value-wins, so the include overrides when present and a
  missing file is only a startup warning).

**Invariant:** kitty's transparent list is *generated from* the same artifact
nvim reads, validated before either program is signalled. Candidate mapping
for the six tones: `surface_container_lowest`, `surface_container_low`,
`surface_container`, `surface_container_high`, `surface_container_highest`,
`surface_variant` (final assignment settled during the swatch comparison).
Noctalia's built-in kitty template writing `themes/noctalia.conf` into the
synced tree is a pre-existing noctalia behavior, out of scope here.

### Nvim modules (`nvim/lua/user/noctalia/`)

- **`palette.lua`** — loads `~/.cache/noctalia/nvim-palette.lua` via `dofile`,
  validates expected keys. Missing file (fresh machine): fall back to a
  committed tokyonight-moon-flavored default palette and `vim.notify` once.
  Malformed palette: hard error, no partial theming.
- **`derive.lua`** — pure-Lua hex↔HSL math. Input: raw palette + mood name.
  Output: a **complete** tokyonight `ColorScheme` table — the ~31 base palette
  fields *and* every field tokyonight derives before invoking `on_colors`
  (`diff`, `git.ignore`, `black`, `border`/`border_highlight`, all `bg_*`,
  `fg_*`, `error`/`warning`/`info`/`hint`/`todo`, `rainbow`, `terminal`),
  honoring our fixed opts (`transparent = true`). This is required because
  tokyonight calls `on_colors(colors)` *after* deriving those fields and
  ignores the callback's return value: mutating only base fields would leave
  moon-derived values behind. Derived hues (green, yellow, orange, cyan,
  magenta, …) are synthesized by hue rotation at the lightness/chroma of the
  source accents.
- **`on_colors` contract** — the callback mutates `colors` in place: clear the
  table's keys, then copy in every field from derive.lua's output (including
  the nested `diff`/`git`/`terminal`/`rainbow` tables).
- **`glass.lua`** (existing, modified) — `M.palette`, `M.registered`,
  `float_bg`, and the `recolor` map are **recomputed inside `apply()`** from
  the current palette, not captured at module load; today they are one-time
  snapshots (`glass.lua:22-49`), which would reapply stale colors on reload.
  `float_bg` is palette-derived and must NOT be one of the six chrome tones.

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
  its palette per the contract above.
- lualine: `options.theme` is passed as a **function** (`ui.lua` currently
  calls `glass.lualine_theme()` once at setup, freezing the colors), and the
  reload path re-invokes lualine so the theme function re-evaluates.
- SIGUSR1 handler (pattern from noctalia docs): re-`dofile` the palette,
  re-derive with current mood, re-apply colorscheme, refresh lualine. The
  `ColorScheme` autocmd re-applies glass (which now recomputes from the fresh
  palette).

### Data flow

wallpaper change → noctalia regenerates colors → template writes the
*candidate* artifact → `bin/noctalia-glass-sync` validates it, atomically
writes the kitty include and promotes the palette, then signals kitty and
nvim → nvim: palette → derive(mood) → tokyonight `on_colors` → ColorScheme
autocmd → glass recompute → lualine refresh.

## Error handling

- Palette file missing (fresh machine) → nvim falls back to its committed
  tokyonight-moon default palette + single `vim.notify`; kitty's hardcoded
  fallback line carries the *matching* tokyonight-moon chrome tones, so glass
  works before noctalia has ever run. The missing include is only a kitty
  startup warning. Fresh-install doc gains a one-line "apply a noctalia
  scheme once" step.
- Candidate malformed → glass-sync refuses to promote either output or signal
  anything; nvim keeps reading the last promoted palette. If the promoted
  palette is somehow malformed anyway, nvim hard-errors at load rather than
  partially theming (defense in depth).
- Unknown mood → error listing valid moods.

## Verification

- Manual: switch wallpapers; kitty + nvim recolor live; statusline, tabs and
  cursorline stay translucent (no opaque rectangles); floats stay solid.
- Structural: kitty's transparent list is generated from the same artifact
  nvim reads, and `bin/noctalia-glass-sync` validates distinctness and
  `float_bg` exclusion before signalling — a desync requires the validation
  itself to be wrong, not a race between templates.
- Scripted spot-check (usable manually and in `dotfiles-check`): compare the
  six hexes in `~/.cache/noctalia/kitty-glass.conf` against the chrome tones
  in the palette artifact.

## Out of scope

- Theming other apps (yazi, btop, …) — noctalia built-ins already cover them.
- Light-mode variants (noctalia runs dark mode here).
- Upstreaming as a standalone plugin.
