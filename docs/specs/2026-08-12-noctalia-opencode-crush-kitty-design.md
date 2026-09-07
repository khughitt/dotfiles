# Noctalia agent themes: OpenCode glass and Crush transparency (Kitty)

**Status:** Implemented (`eb1e61d^..7fb1ddc`).

## Goal

Make OpenCode follow Noctalia's wallpaper-derived palette and preserve Kitty's
glass effect across its theme-controlled structural surfaces and diffs. Make
Crush's existing native transparent-base setting reproducible, while recording
the upstream feature that blocks a proper Noctalia palette for Crush 0.88.0.

This pass targets Kitty under Niri. Ghostty and the already implemented Claude
Code and Codex themes are outside this change.

## Current state

### OpenCode 1.18.18

- `opencode/themes/noctalia.json` is an untracked, fixed palette. Its root,
  panel, element, menu, and diff backgrounds are opaque and do not follow
  wallpaper changes.
- `opencode/opencode.json` still contains the legacy nested
  `"tui": {"theme": "noctalia"}` setting. OpenCode 1.18.18 removes that key
  while loading server config. Its automatic migration skips the file because
  `opencode/tui.json` already exists.
- The theme nevertheless appears selected on this machine because OpenCode's
  state store remembers `noctalia`. That state is not a configuration
  contract and will not reproduce on a fresh machine.
- `~/.config/opencode` is one symlink to the repo's `opencode/` directory, so a
  generated wallpaper-specific theme under `~/.config/opencode/themes/` lands
  in the Dropbox-synced tree.
- OpenCode discovers user themes from `~/.config/opencode/themes/*.json`. Its
  interactive TUI and `run` mode refresh them on `SIGUSR2`; modes such as
  `serve` do not install that handler.

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
templates could publish different generations. Building the theme inside the
existing sync hook is smaller and preserves one committed data boundary. The
post-commit signals are still asynchronous, so running processes can show a
brief repaint mismatch; signal ordering minimizes but cannot remove that
transient.

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
   OpenCode color-theme object. It includes all 52 color keys, leaves the
   optional numeric `thinkingOpacity` setting at OpenCode's 0.6 default, and
   does not read another file or query live state.
4. The hook stages three files in a fresh
   `~/.cache/noctalia/nvim-glass/v-*/` directory:
   - `nvim-palette.json`
   - `kitty-glass.conf`
   - `opencode-theme.json`
5. Renaming a prepared symlink over
   `~/.cache/noctalia/nvim-glass/current` remains the commit point.
6. After the commit, the hook signals Kitty first and Nvim second with
   `SIGUSR1`, then handles OpenCode last. It enumerates exact-name, current-user
   `opencode` processes and reads each Linux `/proc/<pid>/status` `SigCgt` mask.
   It sends `SIGUSR2` only when that process currently catches the signal. A
   missing process is success; any other signal error is reported as a
   post-commit reconciliation failure.

OpenCode 1.18.18 installs that handler in the interactive TUI and `run`
footer, but not in modes such as `serve`. A broad
`pkill -SIGUSR2 -x opencode` is forbidden: the default action for an
uncaught `SIGUSR2` terminates the process. Checking the kernel's caught-signal
mask targets the capability directly instead of duplicating OpenCode's CLI
mode parsing. This still has an unavoidable read-then-signal race: a process
can disappear, exec and clear its handler, or have its PID reused after
`SigCgt` is read. A vanished PID is ignored; the narrower exec/PID-reuse race is
accepted for this local hook.

Pre-commit failure leaves the previous generation untouched and signals
nothing. A failure after the symlink rename leaves the new generation
committed; already-running programs may remain on their previous palette until
the next successful signal or a restart. Every fresh read through `current`
still sees one complete generation.

The new checker requires all three files and verifies the OpenCode theme's
shape and exact background mappings. A current generation created by the old
format is present-but-incomplete, not a fresh-machine state, and must fail the
checker until Noctalia renders once with the new hook.

Kitty is signalled before OpenCode so its registered RGB opacity rules normally
arrive before OpenCode repaints those RGB values. This ordering is best effort,
not part of the atomic-read guarantee.

### OpenCode configuration layout

Generated state must not live below the Dropbox-synced repo. OpenCode already
works through a symlinked config directory, so setup will atomically retarget
`~/.config/opencode` from the repo to the machine-local backing directory
`~/.config/opencode.local`. Inside that backing directory:

- `~/.config/opencode/opencode.json` → tracked `~/d/dotfiles/opencode/opencode.json`
- `~/.config/opencode/tui.json` → tracked `~/d/dotfiles/opencode/tui.json`
- `~/.config/opencode/themes/noctalia.json` →
  `~/.cache/noctalia/nvim-glass/current/opencode-theme.json`

OpenCode-owned package metadata, installed plugin dependencies, and other
runtime files stay machine-local in `~/.config/opencode/`. Existing ignored
runtime files under the repo's `opencode/` directory are migrated with this
rerunnable contract:

1. The config path must be missing or a symlink whose resolved target is either
   the current repo directory or `~/.config/opencode.local`; any other type or
   target is a conflict. Both the link and expected target are canonicalized
   before comparison, so `~/d/dotfiles` and its physical Dropbox path compare
   equal. The local backing directory is always the migration destination.
2. Before creating or copying anything, setup inventories
   the complete runtime source and destination. The three managed paths are
   checked separately: a missing path or a symlink whose resolved target is the
   canonical intended target is valid; any other destination entry is a
   conflict. The obsolete source theme remains an ignored, inactive source
   copy after the managed theme link is active.
3. Source-only entries are eligible to copy; destination-only entries are
   preserved; directories are compared recursively. Files with identical bytes
   and symlinks with identical targets are compatible source copies. Any type
   mismatch, differing file contents, or differing symlink target is a conflict.
4. If any conflict exists, setup lists every conflicting relative path and
   fails before mutation. It never chooses a copy or silently discards one.
5. With a clean preflight, setup copies source-only runtime entries into the
   destination and creates the managed links.
   It prepares a new symlink to the local backing directory and renames it over
   `~/.config/opencode`; that atomic rename is the migration commit point. Only
   Source entries are never deleted automatically: a writer can change them
   between any validation and deletion, so automatic cleanup cannot guarantee
   that newer bytes are preserved.

Because source data remains intact before and after the commit point, an interrupted
initial migration can be rerun: copied entries compare identical and missing
entries are copied on the next attempt. A rerun after activation applies the
same full preflight; divergent leftovers stop the run untouched. Identical
inactive leftovers remain ignored until a user explicitly removes them after
stopping OpenCode. The obsolete `opencode/themes/noctalia.json` is retained as
an ignored inactive source rather than migrated. Setup and
health checks treat this as a special config layout rather than using the
generic repo-directory link.

`opencode/tui.json` gains the top-level `"theme": "noctalia"` setting.
The ignored legacy theme file remains an inactive source copy; the nested `tui`
setting in `opencode/opencode.json` is removed. On a fresh machine before Noctalia has
rendered, the theme symlink is dangling; OpenCode does not discover `noctalia`
and falls back to its built-in theme. The first successful render creates the
target and signals any running signal-aware OpenCode TUI or `run` process.

That fallback is an OpenCode 1.18.18 behavior, not an assumption: its glob skips
the dangling link in an isolated installed-binary probe, leaving `noctalia`
undiscovered. Separately, the upstream source function `syncCustomThemes()`
(minified in the shipped bundle) catches a rejected discovery promise and
selects the built-in `opencode` theme. Discovery has no per-file error isolation,
so an unreadable or malformed discovered theme makes all custom themes
unavailable for that refresh, but the TUI remains alive on the built-in theme.
Atomic generation promotion prevents readers from observing a partially written
generated JSON file; automated verification exercises both fallback paths.

### Color mapping

OpenCode and OpenTUI accept eight-digit hex colors internally, but terminals do
not have an SGR alpha channel. OpenTUI blends a partial-alpha color against its
own RGB backdrop and emits an ordinary opaque RGB background. Actual wallpaper
translucency therefore comes only from Kitty's exact-color registration.

The major surfaces reuse existing registered glass roles:

| OpenCode role | Noctalia glass role | Kitty opacity |
|---|---|---|
| `background` | `chrome` | `0.35` |
| `backgroundPanel` | `tab_off` | `0.30` |
| `backgroundElement` | `cursorline` | `0.30` |
| `backgroundMenu` | `raised` | `0.40` |
| `diffAddedBg` | `diff_added` | `0.72` |
| `diffAddedLineNumberBg` | `diff_added` | `0.72` |
| `diffRemovedBg` | `diff_removed` | `0.72` |
| `diffRemovedLineNumberBg` | `diff_removed` | `0.72` |
| `diffContextBg` | `chrome` | `0.35` |

Borders are paired explicitly rather than inferred from the surface mapping:

| OpenCode border role | Noctalia role | Required pairing |
|---|---|---|
| `border` | `outline` | visible on `backgroundMenu` / `raised` |
| `borderSubtle` | `outline_variant` | low-emphasis borders on darker surfaces |
| `borderActive` | `primary` | active controls on every structural surface |

`glass.raised` is derived from `outline_variant`, so mapping the ordinary
`border` to `outline_variant` would erase autocomplete/menu borders. The theme
test requires `border != backgroundMenu` in addition to checking the exact role
mapping.

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
- borders: `outline`, `outline_variant`, and `primary` as paired above;
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

OpenCode 1.18.18 also hard-codes partially alpha black modal backdrops outside
the theme (`RGBA.fromInts(0, 0, 0, 150)` and a similar message overlay). OpenTUI
flattens those overlays against its internal backdrop and emits an opaque RGB
cell, so neither the custom theme nor Kitty's seven registered colors can make
them translucent. No matching upstream issue or pull request was found; issue
#37027 is the nearest general report about application-painted backgrounds.

This is an explicit trade-off: all theme-controlled structural surfaces and all
diff backgrounds are Noctalia-colored glass, while a few small semantic
controls preserve readable accent colors and modal dimmers remain
upstream-owned. The seven-slot budget also makes each diff line-number gutter
share its add/remove background with the corresponding diff body, unlike the
current fixed theme's subtly different gutter shades. Tests enumerate the
structural background contract so a newly added major theme role cannot
silently become opaque.

## Crush architecture

Add this supported shell-config line to `crush/crushrc`:

```text
option ui transparent true
```

It makes the transparent base the tracked default on a machine with no saved
preference and is the only Crush rendering change in scope. It does not affect
the hard-coded block backgrounds. Crush loads its machine-owned global and
workspace JSON state after `crushrc`, so a user toggle persisted there
deliberately overrides this default. The existing `compact_mode: false` state
overriding `option ui compact true` demonstrates that precedence on this
machine.

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
  `bin/noctalia-glass-check` as a partial/old generation. The `FAIL:` message
  must say that the format changed and instruct the user to re-render the
  current Noctalia wallpaper palette.
- Invalid generated OpenCode JSON or a background that does not match the
  registered role: fail the checker with a `FAIL:` line, never a traceback.
- An exact-name OpenCode process whose `SigCgt` mask does not include
  `SIGUSR2`: leave it untouched. A PID disappearing during discovery or
  signalling is equivalent to no running process. Exec and PID reuse after the
  mask read are accepted residual races. Other `/proc` or signal errors are
  failures, but occur after the generation is already committed.
- A divergent runtime migration collision: report every conflicting path and
  fail before changing the source, destination, or current config symlink.

## Verification

### Automated

- Extend the existing glass-sync test to assert that one promotion produces all
  three artifacts and that a rejected candidate changes none of them.
- Parse `opencode-theme.json`; require OpenCode's complete theme-key set and the
  exact surface/diff/border mapping above, including
  `border != backgroundMenu`.
- Extend the checker test with missing, malformed, and background-drift cases.
- Test signal discovery with exact-name `opencode` process fixtures for TUI,
  `run`, and `serve`: only fixtures whose `SigCgt` mask contains `SIGUSR2` are
  signalled, `serve` is left alive, and no signal is sent before promotion.
- Extend the existing agent-theme/config test to require top-level
  `tui.json.theme = "noctalia"` and reject the legacy `opencode.json.tui` key.
- Extend setup and health tests for the machine-local OpenCode directory and
  its three managed links. The migration test must prove that identical
  source copies remain unchanged after activation and that one divergent
  collision makes preflight fail with both trees and the current symlink
  byte-for-byte unchanged. Include a repo symlink spelled through `~/d/` and prove its
  canonical target is accepted.
- Start OpenCode 1.18.18 against an isolated config containing a dangling
  `themes/noctalia.json` symlink and require the TUI to stay alive on the
  built-in theme because `noctalia` is undiscovered; repeat with malformed JSON
  and require the all-custom-themes fallback rather than a crash. Skip this
  installed-binary probe explicitly when OpenCode or tmux is absent, but fail
  if OpenCode is installed at a version other than 1.18.18.
- Add an agent-config assertion for the exact Crush line
  `option ui transparent true`.
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
7. Start Crush from a directory with no project config while keeping the tracked
   global `crushrc`, but isolate both writable state layers:
   `CRUSH_GLOBAL_DATA=$(mktemp -d) crush --data-dir $(mktemp -d)`. Verify that
   wallpaper is visible between its blocks, then toggle transparency off and
   verify the persisted preference overrides the tracked default on restart.
   Confirm that application-painted blocks remain opaque as documented.

## Upstream tracking

No GitHub write is part of this implementation. If a later follow-up uses `gh`
to create or modify a comment, issue, or pull request, it must first verify that
the effective account reported by `gh api user --jq .login` is `khughitt`, not
the default work account `keith-cainex`. If it temporarily runs
`gh auth switch --user khughitt`, it must record the previously active account
and restore it on both success and failure. The implementation plan must repeat
this guard beside any GitHub-writing step.

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
- OpenCode TUI `SIGUSR2` handler:
  <https://github.com/anomalyco/opencode/blob/v1.18.18/packages/opencode/src/cli/cmd/tui.ts#L204-L212>
- OpenCode `run` footer `SIGUSR2` handler:
  <https://github.com/anomalyco/opencode/blob/v1.18.18/packages/opencode/src/cli/cmd/run/footer.ts#L282-L290>

All upstream references above were read and status-checked on 2026-08-13.

## Out of scope

- Ghostty behavior for Claude Code, Codex, Crush, or OpenCode.
- Changing Niri opacity, blur, saturation, or noise tuning.
- Expanding Kitty beyond its seven supported transparent background colors.
- Forking or patching Crush.
- Migrating Crush's ignored `crush/.crush/` runtime state out of the
  Dropbox-synced config tree; it is the same pollution shape as OpenCode but is
  unrelated to the one supported Crush rendering toggle in this pass.
- Making every small OpenCode semantic control translucent at the cost of
  foreground readability.
- Light-mode agent themes.
