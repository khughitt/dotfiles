# Noctalia v5 Wali and Prism plugin ports

**Status:** Approved; implementation pending.

## Goal

Restore the custom Wali Panel and Prism bar panels after the Noctalia v5
migration. Replace their v4 QML implementations with native v5 Luau plugins,
preserve their behavior, and manage their local installation declaratively
from dotfiles.

This work spans two repositories:

- dotfiles owns Wali Panel, Noctalia configuration, installation, health
  checks, and user documentation;
- Prism owns its Noctalia integration under
  `~/d/prism/integrations/noctalia-plugin/`.

Memory Pressure Alert and the other deferred v4 plugins remain out of scope.

## Constraints confirmed before design

- The installed `noctalia 5.0.0_beta.8` supports plugin APIs 3 through 23.
- The current v5 documentation describes APIs through 28. In particular,
  direct argv-table subprocess execution requires API 24 and is unavailable on
  the installed build.
- V5 plugins use `plugin.toml` manifests and isolated Luau entry scripts. V4
  `manifest.json` and QML entry points cannot be loaded unchanged.
- Declarative panels provide the controls needed by both ports: images,
  buttons, toggles, sliders, selects, scrolling, and native color-picker
  callbacks.
- A panel runtime starts lazily on first open and persists across later closes
  and reopens. Its state can therefore own Prism's serialized command queue.
- The v5 widget API exposes the widget's output but not its global screen
  coordinate or bar section.
- `noctalia/config.toml` currently places `ui_scale` under `[shell]`, which the
  installed validator now reports as an unknown setting. The current schema
  places it under `[accessibility]`.

References:

- <https://docs.noctalia.dev/noctalia/plugins/development/>
- <https://docs.noctalia.dev/noctalia/plugins/development/manifest/>
- <https://docs.noctalia.dev/noctalia/plugins/development/entries/>
- <https://docs.noctalia.dev/noctalia/plugins/development/declarative-ui/>
- <https://docs.noctalia.dev/noctalia/plugins/development/runtime-api/>
- <https://docs.noctalia.dev/noctalia/plugins/development/plugin-api/>
- <https://docs.noctalia.dev/noctalia/plugins/development/workflow/>

## Decision

Rewrite both plugins directly as native Luau plugins targeting the oldest API
level their implementations require, no higher than the installed API 23.
Keep `walictl`, `prism`, and niri-glass as the authoritative backends instead
of duplicating their domain logic in plugin code.

Replace the v4 sources in place. Do not retain a v4 compatibility layer,
version-detecting branch, standalone Quickshell wrapper, or parallel legacy
manifest.

The rejected alternatives are:

- running the old QML as standalone Quickshell applications, which would
  duplicate Noctalia panel lifecycle, placement, and theming;
- waiting for API 24, which would defer a working port even though API 23 has
  every capability except argv-table subprocess execution;
- moving wallpaper or Prism domain behavior into Luau, which would create a
  second implementation beside the existing tested CLIs.

## Plugin identity and installation

The canonical plugin IDs are:

- `khughitt/wali-panel`;
- `khughitt/prism`.

Their bar entries and panels use stable full IDs such as
`khughitt/wali-panel:widget`, `khughitt/wali-panel:panel`,
`khughitt/prism:widget`, and `khughitt/prism:panel`.

Dotfiles links the source directories into the v5 local-plugin directory:

```text
$XDG_DATA_HOME/noctalia/plugins/wali-panel
  -> dotfiles/noctalia/plugins/wali-panel

$XDG_DATA_HOME/noctalia/plugins/prism
  -> ~/d/prism/integrations/noctalia-plugin
```

The tracked Noctalia config enables both canonical IDs, declares named widget
instances, and adds them to the end section of the default bar. Local drop-ins
have higher precedence than configured official and community sources, so no
extra plugin source is required.

Setup fails early if either source is missing. Health checks verify the two
links, their v5 manifests, and the configured enabled IDs.

## Wali Panel

### Boundary

Wali Panel remains a thin UI over `walictl`. The plugin does not reimplement
archive-path derivation, favorites writes, GIMP launching, directory ordering,
or Noctalia wallpaper IPC.

The v4 `Main.qml` random-wallpaper baseline repair is deleted. The current
`walictl random` command already calls native `noctalia msg
wallpaper-random`, so no service entry or plugin IPC shim is needed.

### Entries and behavior

The v5 plugin contains one bar widget and one panel:

- the widget renders a wallpaper glyph and opens the panel;
- the panel runs `walictl current --json` on open and after successful
  navigation;
- the panel displays the best available current/source image, source path,
  and parsed date;
- previous, next, random, save, and edit actions call the corresponding
  `walictl` subcommands;
- copy uses `noctalia.copyToClipboard` rather than spawning `wl-copy`.

Only one action runs at a time. Navigation reloads the current metadata after
success. Save and edit show native success notifications. The copy action is
disabled when no source path exists.

The panel validates the decoded JSON shape before accepting it. A missing
command, rejected launch, timeout, non-zero exit, invalid JSON document, or
invalid payload becomes a visible panel error. A new open or explicit action
may retry; there is no fallback to stale v4 state.

The manifest declares `walictl` as its external command dependency. The README
also records the existing `BACKGROUND_IMG_DIR`, `WALI_DIR`, and GIMP
requirements for the actions that need them.

## Prism panel

### Boundary

The panel continues to render the model returned by `prism describe --json`.
It writes only through `prism set` and `prism unset`. It controls the isolated
glass preview only through the existing named niri-glass IPC:

```text
qs -c niri-glass ipc call prismGlass showPreview <output> <side> <diagnostic>
qs -c niri-glass ipc call prismGlass hidePreview
```

No Prism definitions, sink behavior, generated files, or niri-glass shader
logic move into the plugin.

### Presentation parity

The v5 panel preserves the current behavioral contract:

- `Title` contains the single header toggle;
- `Quick` is first and always expanded;
- other groups are collapsible and show their modified count;
- each modified parameter has an individual reset;
- each modified group has a group reset;
- toggle, select, slider, and color controls map from `ui.control`;
- raw, percent, normalized, and logarithmic slider presentation remains
  canonical and snapped to the model's range and step;
- unavailable controls remain visibly unavailable;
- parameters outside preview scope remain usable but are dimmed and labelled
  while preview is active;
- Diagnostics retains Preview and Diagnostic background controls.

Native v5 controls replace the QML components. The promise is behavioral
parity, not pixel-for-pixel reproduction of the v4 layout.

### Output and preview placement

Before opening the panel, the Prism widget stores its output name in the
plugin's shared state. The panel reads that value and falls back to the
focused output only when the widget did not provide one.

The v5 API does not expose the widget's global coordinate, so it cannot compute
the generic opposite side used by the QML implementation. Dotfiles owns the
replacement invariant: Prism remains in the right/end bar section and the
preview opens on the left. Moving the widget requires updating that placement
decision.

### Serialized commands and dragging

Parameter writes and preview operations share one FIFO. A command starts only
after the previous command's callback completes. Consecutive sampled writes
for the same parameter are coalesced.

For live-drag parameters:

1. `onChange` updates the displayed canonical value immediately.
2. A frame callback releases at most one sampled write every 100 ms.
3. `onDragEnd` flushes the final canonical value as a non-sample write.

For release-only parameters, changes update the local display but only the
drag-end callback writes. Wheel and keyboard changes receive the same final
commit boundary from the native v5 slider.

The panel refreshes from `prism describe --json` after a drained parameter
batch unless its last write is only an active drag sample. A describe result
started before or during a new drag is marked stale, discarded, and replayed
after release. This preserves local slider identity and prevents an
authoritative refresh from replacing a pressed control.

Closing the panel queues preview hide. The persistent panel runtime owns the
queue across closes, so cleanup and in-flight writes are not abandoned.

### API-23 subprocess safety

The installed API accepts only command strings. One shared helper converts an
argument list to a POSIX shell command by single-quoting every argument and
escaping embedded single quotes. Every Wali, Prism, and niri-glass argument
passes through that helper; dynamic values are never interpolated directly.

There is no API-version branch. When the minimum supported Noctalia build is
later raised to API 24, direct argv tables can replace this helper in one
mechanical change.

### Errors

Prism rejects a describe response unless it contains the expected parameter
array and the required title/group/control fields. Command launch failures,
timeouts, non-zero exits, and parse errors appear in the panel. A transient
error does not discard the last valid rendered model, so the user can retry
without reopening the panel.

## Configuration and documentation

Before enabling plugins, move `ui_scale = 1.05` from `[shell]` to
`[accessibility]` so the tracked baseline validates without warnings.

Update:

- `noctalia/noctalia.md` to replace the blanket deferred-plugin statement;
- `noctalia/noctalia-wallpaper-switcher.md` to document the restored panel;
- Wali Panel's plugin README;
- Prism's plugin contract and public integration documentation.

After correcting the migration design's now-stale claim that Wali and Prism
are deferred, grep other user-facing documentation for the same claim and
correct it in the same change.

## Verification

Automated checks cover:

- the Wali and Prism `plugin.toml` manifests and entry paths;
- `noctalia plugins lint` for each source directory;
- warning-free `noctalia config validate` against the tracked config root;
- isolated setup topology with disposable Wali and Prism sources;
- health-check rejection of missing, wrong, or v4 plugin links;
- tracked enabled IDs, widget declarations, and bar placement;
- existing `walictl` behavior;
- Prism's describe model and static plugin contract;
- the full dotfiles and Prism test suites.

The installed Noctalia linter cross-checks manifests, settings, and entry
files, but does not compile Luau. Live acceptance is therefore a required
runtime gate:

1. Both local plugins appear enabled in `noctalia msg plugins list`.
2. Both bar widgets render and open their panels.
3. Noctalia logs contain no Luau compile, timeout, or runtime errors.
4. Wali current metadata, navigation, random, copy, save, and edit behavior is
   exercised, including an unavailable-source error.
5. Prism renders every visible parameter from `prism describe --json`.
6. One toggle, slider, select, and color value is changed and reconciled.
7. Individual and group reset restore authoritative values.
8. Live and release-only sliders exhibit their distinct write timing.
9. Preview targets the originating output, uses the left side, switches its
   diagnostic background, and hides when the panel closes.

## Landing order

1. Implement and commit the Prism v5 plugin in a fresh Prism worktree.
2. Implement Wali, configuration, installation, health checks, and docs in the
   dotfiles worktree.
3. Run both repositories' automated suites.
4. Merge Prism first, then dotfiles.
5. Run setup from the dotfiles main checkout, reload Noctalia, and perform live
   acceptance.

This order prevents tracked dotfiles from enabling a Prism plugin that its
owning repository has not yet supplied.
