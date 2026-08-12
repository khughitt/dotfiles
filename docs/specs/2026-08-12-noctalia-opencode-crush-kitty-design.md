# Noctalia agent themes: OpenCode glass and Crush transparency (Kitty)

**Status:** Proposed.

## Goal

Make OpenCode follow Noctalia's wallpaper-derived palette and preserve Kitty's
glass effect across its theme-controlled structural surfaces and diffs. Make
Crush's existing native transparent-base setting reproducible, while recording
the upstream feature that blocks a proper Noctalia palette for Crush 0.88.0.

This pass targets Kitty under Niri. Ghostty and the already implemented Claude
Code and Codex themes are outside this change.

## Current state

### OpenCode 1.18.16

- `opencode/themes/noctalia.json` is an untracked, fixed palette. Its root,
  panel, element, menu, and diff backgrounds are opaque and do not follow
  wallpaper changes.
- `opencode/opencode.json` still contains the legacy nested
  `"tui": {"theme": "noctalia"}` setting. OpenCode 1.18.16 removes that key
  while loading server config. Its automatic migration skips the file because
  `opencode/tui.json` already exists.
- The theme nevertheless appears selected on this machine because OpenCode's
  state store remembers `noctalia`. That state is not a configuration
  contract and will not reproduce on a fresh machine.
- `~/.config/opencode` is one symlink to the repo's `opencode/` directory, so a
  generated wallpaper-specific theme under `~/.config/opencode/themes/` lands
  in the Dropbox-synced tree.
- OpenCode discovers user themes from `~/.config/opencode/themes/*.json` and
  refreshes them on `SIGUSR2`.

### Crush 0.88.0

- Runtime state already has `options.tui.transparent = true`, so Crush omits
  the full-screen base background and wallpaper is visible between blocks.
- `crush/crushrc` does not declare that option, so a fresh setup need not match
  the current machine.
- The remaining panels, tool blocks, diffs, selections, and dialogs use
  application-painted Charmtone backgrounds. Version 0.88.0 has no custom
  palette or custom-theme configuration.

### Kitty and Niri

- Kitty can make the default background and at most seven exact RGB cell
  backgrounds translucent. All seven custom slots are already assigned by the
  Noctalia glass contract: four neutral surfaces, add/remove diff colors, and
  selection.
- Niri supplies blur, saturation, and noise behind Kitty. It cannot provide
  per-cell translucency without fading glyphs and terminal graphics too.
- Therefore agent-painted backgrounds must either use one of the seven
  registered RGB values or remain opaque. Adding more Kitty colors is not an
  option.

## Decision

Implement OpenCode as another consumer of the existing atomic Noctalia glass
generation. `bin/noctalia-glass-sync` will derive a complete OpenCode theme
from the already validated palette candidate and stage it beside the Nvim and
Kitty artifacts. The same `current` symlink will publish all three consumers'
data at once.

Do not create a second OpenCode-specific Noctalia template. Independent
templates can render and signal in either order, creating a window where
OpenCode paints colors that Kitty has not registered yet. Building the theme
inside the existing sync hook is smaller and preserves the established
transaction boundary.

For Crush, add only the supported `option ui transparent true` setting and
document the remaining opaque application surfaces. Do not fork Crush or
consume Kitty slots for its current fixed Charmtone shades. Revisit its palette
after upstream custom-theme support ships.

## OpenCode architecture

### Generated artifact and atomic promotion

The existing Noctalia Nvim template remains the single render entry point:

1. Noctalia writes `~/.cache/noctalia/nvim-palette.candidate.json`.
2. `bin/noctalia-glass-sync` parses and validates the complete candidate.
3. A pure theme-construction function maps the validated palette to a complete
   OpenCode theme object. It does not read another file or query live state.
4. The hook stages three files in a fresh
   `~/.cache/noctalia/nvim-glass/v-*/` directory:
   - `nvim-palette.json`
   - `kitty-glass.conf`
   - `opencode-theme.json`
5. Renaming a prepared symlink over
   `~/.cache/noctalia/nvim-glass/current` remains the commit point.
6. After the commit, the hook signals Kitty and Nvim with `SIGUSR1` and
   OpenCode with `SIGUSR2`. A missing process is success; any other signal
   error is reported as a post-commit reconciliation failure.

Pre-commit failure leaves the previous generation untouched and signals
nothing. A failure after the symlink rename leaves the new generation
committed; already-running programs may remain on their previous palette until
the next successful signal or a restart. Every fresh read through `current`
still sees one complete generation.

The new checker requires all three files and verifies the OpenCode theme's
shape and exact background mappings. A current generation created by the old
format is present-but-incomplete, not a fresh-machine state, and must fail the
checker until Noctalia renders once with the new hook.

### OpenCode configuration layout

Generated state must not live below the Dropbox-synced repo. Setup will replace
the whole-directory `~/.config/opencode` symlink with a machine-local directory:

- `~/.config/opencode/opencode.json` → tracked `~/d/dotfiles/opencode/opencode.json`
- `~/.config/opencode/tui.json` → tracked `~/d/dotfiles/opencode/tui.json`
- `~/.config/opencode/themes/noctalia.json` →
  `~/.cache/noctalia/nvim-glass/current/opencode-theme.json`

OpenCode-owned package metadata, installed plugin dependencies, and other
runtime files stay machine-local in `~/.config/opencode/`. Existing ignored
runtime files under the repo's `opencode/` directory are migrated without
overwriting destination files; the obsolete fixed
`opencode/themes/noctalia.json` is discarded rather than migrated. Setup and
health checks treat this as a special config layout rather than using the
generic whole-directory link.

`opencode/tui.json` gains the top-level `"theme": "noctalia"` setting.
The ignored legacy theme file and the ignored nested `tui` setting in
`opencode/opencode.json` are removed. On a fresh machine before Noctalia has
rendered, the theme symlink is dangling; OpenCode does not discover `noctalia`
and falls back to its built-in theme. The first successful render creates the
target and signals any running OpenCode process.

### Color mapping

OpenCode and OpenTUI accept eight-digit hex colors internally, but terminals do
not have an SGR alpha channel. OpenTUI blends a partial-alpha color against its
own RGB backdrop and emits an ordinary opaque RGB background. Actual wallpaper
translucency therefore comes only from Kitty's exact-color registration.

The major surfaces reuse existing registered glass roles:

| OpenCode role | Noctalia glass role | Kitty opacity |
|---|---|---|
| `background` | `chrome` | window background opacity |
| `backgroundPanel` | `tab_off` | window background opacity |
| `backgroundElement` | `cursorline` | window background opacity |
| `backgroundMenu` | `raised` | window background opacity |
| `diffAddedBg` | `diff_added` | `0.72` |
| `diffAddedLineNumberBg` | `diff_added` | `0.72` |
| `diffRemovedBg` | `diff_removed` | `0.72` |
| `diffRemovedLineNumberBg` | `diff_removed` | `0.72` |
| `diffContextBg` | `chrome` | window background opacity |

The root deliberately uses `glass.chrome` instead of `"none"`. This keeps the
whole UI translucent through Kitty while avoiding OpenCode issue #30056:
OpenCode uses `theme.background` as the foreground of attachment badges, so an
alpha-zero root makes their text alpha-zero too.

Foreground, border, Markdown, and syntax roles map directly to the validated
Noctalia palette:

- primary/accent/status: `primary`, `secondary`, `tertiary`, `error`, and their
  fixed-dim variants;
- ordinary text: `on_surface`; muted text and comments:
  `on_surface_variant`/`outline`;
- borders: `outline_variant`, `outline`, and `primary`;
- diff foregrounds: `secondary_fixed_dim` for additions and `error` for
  removals;
- selected-list text: `on_primary`, paired with OpenCode's `primary` selected
  background.

The generated theme is dark-only, matching this Noctalia installation.

### Known OpenCode opacity gaps

OpenCode reuses foreground semantic roles as backgrounds in a few controls:

- `primary` for selected rows and buttons;
- `secondary` for attachment badges;
- `accent` for question confirmation;
- `warning` for permission selection.

Those colors remain true Noctalia accents and therefore remain opaque when
painted as backgrounds. Mapping them to the dark registered glass tones would
make foreground links, borders, and status text less legible throughout the
application. OpenCode has no separate selected-background or badge-background
theme tokens; request #28351 for selection tokens was closed as not planned.

OpenCode 1.18.16 also hard-codes partially alpha black modal backdrops outside
the theme (`RGBA.fromInts(0, 0, 0, 150)` and a similar message overlay). OpenTUI
flattens those overlays against its internal backdrop and emits an opaque RGB
cell, so neither the custom theme nor Kitty's seven registered colors can make
them translucent. No matching upstream issue or pull request was found; issue
#37027 is the nearest general report about application-painted backgrounds.

This is an explicit trade-off: all theme-controlled structural surfaces and all
diff backgrounds are Noctalia-colored glass, while a few small semantic
controls preserve readable accent colors and modal dimmers remain
upstream-owned. Tests enumerate the structural background contract so a newly
added major theme role cannot silently become opaque.

## Crush architecture

Add this supported shell-config line to `crush/crushrc`:

```text
option ui transparent true
```

It makes the existing transparent base reproducible and is the only Crush
rendering change in scope. It does not affect the hard-coded block backgrounds.

Crush issue #1334 requests theme selection. Open PR #2731 adds palette-backed
themes, configuration, a picker/editor, and runtime cache refresh. Once a
released Crush version exposes that interface, a separate design can map its
surface tokens onto the same seven Kitty roles and its foreground tokens onto
Noctalia accents. Until then, a local fork or a list of fixed Charmtone Kitty
registrations would be a maintenance burden and would break the shared
seven-slot invariant.

## Error handling

- Malformed or incomplete palette candidate: retain the previous generation;
  write and signal nothing.
- Failure while constructing or staging the OpenCode theme: retain the previous
  generation; write and signal nothing.
- Missing `current` on a fresh machine: Nvim and Kitty use their existing
  fallbacks; OpenCode uses its built-in theme until the first Noctalia render.
- Present `current` without `opencode-theme.json`: fail
  `bin/noctalia-glass-check` as a partial/old generation.
- Invalid generated OpenCode JSON or a background that does not match the
  registered role: fail the checker with a `FAIL:` line, never a traceback.
- No running OpenCode process during reconciliation: accept `pkill` exit 1.
  Other signal errors are failures, but occur after the generation is already
  committed.

## Verification

### Automated

- Extend the existing glass-sync test to assert that one promotion produces all
  three artifacts and that a rejected candidate changes none of them.
- Parse `opencode-theme.json`; require OpenCode's complete theme-key set and the
  exact surface/diff mapping above.
- Extend the checker test with missing, malformed, and background-drift cases.
- Mock signalling and assert `SIGUSR2` targets `opencode` only after promotion.
- Extend the existing agent-theme/config test to require top-level
  `tui.json.theme = "noctalia"` and reject the legacy `opencode.json.tui` key.
- Extend setup and health tests for the machine-local OpenCode directory and
  its three managed links.
- Keep `bin/dotfiles-check` as the aggregate gate.

### Manual

1. Render a Noctalia wallpaper palette once after activation.
2. Start OpenCode in Kitty and verify that the root, sidebar, input surface,
   dialogs, and diff backgrounds show the Niri-blurred wallpaper through their
   Noctalia tones.
3. Switch wallpapers while OpenCode is running and verify that colors update
   without restarting the process.
4. Verify attachment badge text remains visible.
5. Verify selected rows and permission/question controls remain readable,
   noting that these small semantic backgrounds are intentionally opaque.
6. Open a modal and confirm its upstream-owned backdrop remains opaque as
   documented rather than mistaking it for a generated-theme regression.
7. Start Crush from a clean config and verify that wallpaper is visible between
   its blocks; confirm that its application-painted blocks remain opaque as the
   documented upstream limitation.

## Upstream tracking

- Crush theme selection: <https://github.com/charmbracelet/crush/issues/1334>
- Crush theme/palette implementation:
  <https://github.com/charmbracelet/crush/pull/2731>
- OpenCode solid-root report:
  <https://github.com/anomalyco/opencode/issues/37027>
- OpenCode transparency policy:
  <https://github.com/anomalyco/opencode/pull/5657>
- OpenCode transparent-background badge bug:
  <https://github.com/anomalyco/opencode/issues/30056>
- OpenCode selection-token request, closed as not planned:
  <https://github.com/anomalyco/opencode/issues/28351>

## Out of scope

- Ghostty behavior for Claude Code, Codex, Crush, or OpenCode.
- Changing Niri opacity, blur, saturation, or noise tuning.
- Expanding Kitty beyond its seven supported transparent background colors.
- Forking or patching Crush.
- Making every small OpenCode semantic control translucent at the cost of
  foreground readability.
- Light-mode agent themes.
