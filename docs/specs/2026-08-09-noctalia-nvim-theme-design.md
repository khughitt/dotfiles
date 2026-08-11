# Noctalia → Neovim theming (glass-preserving)

**Status:** Implemented (753305e..0485858); Codex diff/selection refinement
approved, pending implementation.

## Goal

Make neovim follow noctalia's wallpaper-derived material palette — syntax colors
*and* chrome (statusline, barbar tabs, cursorline) — while preserving the kitty
"glass" translucency system, with live updates on wallpaper change and a
switchable mood variant for syntax hues.

## Constraints (why this is not just a template)

- kitty makes a cell translucent only when its background is the default
  background or one of at most 7 colors listed in `transparent_background_colors`
  (`kitty/kitty.conf`). All seven are now used: four neutral nvim chrome tones
  plus shared coding-agent add/remove/selection tones, mirrored in
  `nvim/lua/user/glass.lua`.
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
  - input: `nvim/lua/user/noctalia/palette-template.json` (in repo)
  - output: `~/.cache/noctalia/nvim-palette.candidate.json` (candidate path;
    all generated files live outside the Dropbox-synced tree)
  - post_hook: `~/bin/noctalia-glass-sync` (setup links the repo's `bin/` to
    `~/bin`; noctalia runs hooks through the shell without setting the repo
    as cwd, so the path must not be repo-relative)
  - Emits a JSON object of raw material colors — the 4 accents (+ fixed_dim
    variants), surfaces, outline, on_surface tones — plus a `glass` table of
    role → hex. JSON so the hook syntax-validates the whole file with
    `json.loads` and nvim reads it with `vim.json.decode`; no hand-rolled
    parsing anywhere.

- **`bin/noctalia-glass-sync`** (committed, executable) does, in order:
  1. Parse the candidate with `json.loads` (a syntax error is a validation
     failure).
  2. Validate the COMPLETE artifact: every required key present and
     well-formed hex (mirror of palette.lua's list — a missing accent must
     never reach nvim), seven registered glass tones pairwise distinct,
     `tab_on = chrome`, `tab_fill = tab_off`, and `float` not among the seven
     and ≠ `surface`.
     On failure: `notify-send` warning, nothing written, signal nothing,
     exit non-zero.
  3. Stage BOTH outputs into a fresh version directory
     `~/.cache/noctalia/nvim-glass/v-*/` — `nvim-palette.json` (candidate
     verbatim) and `kitty-glass.conf` (`transparent_background_colors` in
     role order plus `selection_background` using the same registered
     selection tone) — then atomically rename a prepared symlink
     over `~/.cache/noctalia/nvim-glass/current`. One rename switches both
     files; there is no interleaving in which kitty and nvim can read
     different generations. Superseded version dirs are pruned after the
     flip; the consumed candidate is deleted.
  4. Only after the flip: `pkill -SIGUSR1 kitty` (config reload), then
     `pkill -SIGUSR1 nvim`.

  Readers go only through `current/`. The symlink rename is the commit
  point: a failed validation, a hook that never ran, or a kill BEFORE the
  rename leaves `current` on the previous consistent generation, so every
  fresh read sees it whole. The signals are post-commit reconciliation — a
  kill between commit and signalling leaves already-running processes on
  whatever generation they last loaded until the next successful run
  signals them. The guarantee is about reads, not about the momentary
  state of running processes: any fresh read of both files through
  `current` sees a single consistent generation.

- `kitty.conf` keeps hardcoded `transparent_background_colors` and semantic
  `selection_background` fallbacks. After `current-theme.conf`, it includes
  `${HOME}/.cache/noctalia/nvim-glass/current/kitty-glass.conf` (env-var
  expansion in include paths is already used for `${HOSTNAME}.conf`; Kitty is
  last-value-wins, so this final include overrides both the built-in theme and
  fallbacks when present, while a missing file is only a startup warning).

**Path contract:** production paths are pinned to literal `~/.cache/noctalia/`
everywhere — kitty's `include` line and noctalia's `user-templates.toml`
cannot express an XDG fallback, so nothing in this pipeline honors
`XDG_CACHE_HOME`. The Python scripts accept a `NOCTALIA_GLASS_DIR` env
override used only by tests.

**Invariant:** kitty's transparent list is *generated from* the same artifact
nvim reads, validated before either program is signalled. Four neutral slots
come from `surface_container_low` (`chrome`, also `tab_on`), `surface_bright`
(`cursorline`), `surface_container_high` (`tab_off`, also `tab_fill`), and
`outline_variant` (`raised`). The three semantic slots are the shared
coding-agent diff green `#022800` and diff red `#3d0100`, each at opacity
`0.72`, plus the current Noctalia `primary_container` selection color at
opacity `0.55`.
`float = surface_container_lowest` — the only material token darker than
`surface` — and must stay solid and unregistered. The aliases intentionally
merge the two closest neutral pairs to fit all seven Kitty slots. The mapping
lives solely in the template.

Claude Code's native syntax-highlighted diff renderer does not honor custom
theme background tokens. Registering its native red and green cell colors in
Kitty therefore supplies the transparency; the custom Claude theme uses the
same values for its fallback diff renderer and uses `primary_container` for
selection. This preserves syntax highlighting instead of disabling the native
renderer.

Codex's custom `.tmTheme` has a narrower but useful UI contract. Its
`markup.inserted` and `markup.deleted` scope backgrounds override the native
diff backgrounds, so the Noctalia theme sets them to the same fixed green and
red already registered for Claude. Terminal text selection is owned by Kitty,
not Codex; the generated `selection_background` points it at the registered
`primary_container` tone and therefore updates live on wallpaper changes.

The Codex input box is intentionally unchanged. Codex 0.147.0 derives that
background by blending white at 12% over the terminal background and caches
the result at process startup. Its theme and config expose no input-background
role, and Kitty transparency matches exact cell colors. Registering the
derived tone would therefore go stale at the next 15-minute wallpaper switch;
keeping every historical tone would exceed Kitty's seven-color limit. Fixed
partially transparent colors become viable only if Codex exposes an input-box
theme role (or is replaced by a maintained custom build), neither of which is
part of this dotfiles change.
Noctalia's built-in kitty template writing `themes/noctalia.conf` into the
synced tree is a pre-existing noctalia behavior, out of scope here.

### Nvim modules (`nvim/lua/user/noctalia/`)

- **`palette.lua`** — loads
  `~/.cache/noctalia/nvim-glass/current/nvim-palette.json` via
  `vim.json.decode`, validates expected keys and the glass invariants.
  Missing file — ENOENT specifically — (fresh machine): fall back to a
  committed tokyonight-moon-flavored default palette and `vim.notify` once.
  Present but unreadable (EACCES, I/O error), malformed, or invalid: hard
  error, no partial theming and no silent fallback. The mood state file
  follows the same rule.
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
  the nested `diff`/`git`/`terminal`/`rainbow` tables). It must ALSO update
  `require('tokyonight.util').bg` and `.fg`: tokyonight caches them before
  invoking the callback and its highlight groups blend against them
  afterwards — without the update, every blend stays moon-based.
- **`glass.lua`** (existing, modified) — `M.palette`, `M.registered`,
  `float_bg`, and the `recolor` map are **recomputed inside `apply()`** from
  the current palette, not captured at module load; today they are one-time
  snapshots (`glass.lua:22-49`), which would reapply stale colors on reload.
  `float_bg` is palette-derived and must NOT be one of the seven registered
  tones.

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
  startup. Only a MISSING state file defaults to `spectrum`; a present file
  with unknown content is a hard error listing valid moods (fail early — no
  silent fallback), as is an unknown name passed to the command.

### Wiring

- tokyonight opts: `transparent = true` (unchanged) plus `on_colors` replacing
  its palette per the contract above.
- lualine: `options.theme` is passed as a **function** (`ui.lua` currently
  calls `glass.lualine_theme()` once at setup, freezing the colors), and the
  reload path re-invokes lualine so the theme function re-evaluates.
- SIGUSR1 handler (pattern from noctalia docs): re-read the palette,
  re-derive with current mood, re-run `vim.cmd.colorscheme('tokyonight')`
  (the call at `nvim/init.lua:345`; the moon style comes from tokyonight's
  default `style`). lualine re-runs its setup on every `ColorScheme` event
  and re-evaluates function themes; the `ColorScheme` autocmd re-applies
  glass (which now recomputes from the fresh palette).

### Data flow

wallpaper change → noctalia regenerates colors → template writes the
*candidate* artifact → `bin/noctalia-glass-sync` validates it, stages both
outputs into a version dir and flips the `current` symlink, then signals
kitty and nvim → nvim: palette → derive(mood) → tokyonight `on_colors` →
ColorScheme autocmd → glass recompute → lualine refresh.

## Error handling

- Palette file missing (fresh machine) → nvim falls back to its committed
  tokyonight-moon default palette + single `vim.notify`; kitty's hardcoded
  fallback line carries the *matching* tokyonight-moon chrome tones, so glass
  works before noctalia has ever run. The missing include is only a kitty
  startup warning. Fresh-install doc gains a one-line "apply a noctalia
  scheme once" step.
- Candidate malformed (bad JSON, missing key, glass violation) → glass-sync
  leaves the `current` symlink untouched and signals nothing; running and
  newly started programs keep the last promoted generation. If the promoted
  palette is somehow malformed anyway (hand-edited), nvim hard-errors at load
  rather than partially theming (defense in depth).
- Unknown mood (command argument or corrupt state file) → error listing valid
  moods; only a MISSING state file falls back to the default.

## Verification

- Manual: switch wallpapers; kitty + nvim recolor live; statusline, tabs and
  cursorline stay translucent (no opaque rectangles); floats stay solid.
  In a newly started Codex session, added/deleted diff backgrounds and terminal
  text selection are colored and translucent before and after later wallpaper
  switches; the input box remains Codex-owned and opaque.
- Structural: kitty's transparent list and nvim's palette live in one version
  directory switched by a single atomic symlink rename — a desync requires
  the validation itself to be wrong, not a race or a partial promote.
- Scripted: `bin/noctalia-glass-check` (run manually and from
  `dotfiles-check`) — passes on fresh machines (no `current` symlink), FAILS
  on partial state (symlink present but a file missing) or when Kitty's seven
  color/opacity tokens differ from the palette's glass tones in role order.

## Out of scope

- Theming other apps (yazi, btop, …) — noctalia built-ins already cover them.
- Light-mode variants (noctalia runs dark mode here).
- Upstreaming as a standalone plugin.
