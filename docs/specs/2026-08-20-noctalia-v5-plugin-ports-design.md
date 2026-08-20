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
The vendored Pomodoro plugin matches the available
`thepunkoff/pomodoro 1.2.0` community plugin; replacing it is a separate
delete-and-enable cleanup, not a port.

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
- The v5 widget API exposes the widget's output but not its global screen
  coordinate or bar section.
- Noctalia loads state `settings.toml` after tracked config files. A state
  `[plugins] enabled` value replaces the tracked value rather than merging it,
  and plugin enablement has no offline CLI.
- `noctalia/config.toml` currently places `ui_scale` under `[shell]`, which the
  installed validator now reports as an unknown setting. The current schema
  places it under `[accessibility]`.

The installed API level at which each required capability is available is:

| Capability | API | Use |
| --- | ---: | --- |
| String-form `runAsync`, JSON, notifications, shared-state read/write, focused output, clipboard, color picker, panel toggle, and basic UI callbacks | 3 | Both plugins |
| UI callback closures | 9 | Wali actions and Prism controls |
| Monotonic `nowMs` | 12 | Prism drag sampling |
| `setNeedsFrameTick` and `onFrameTick` | 18 | Prism 100 ms live-drag cadence |
| Luau modules via `require` | 22 | Prism presentation and queue modules |

Wali therefore targets API 9 and Prism targets API 22. Both are within the
installed 3–23 range. Prism enables frame ticks only during a live drag. The
default outside-click dismissal is sufficient, and neither plugin opts into
the unrelated `persistent` panel setting. Runtime survival across panel close
remains an acceptance-time hypothesis, not a confirmed constraint.

References:

- <https://docs.noctalia.dev/noctalia/plugins/development/>
- <https://docs.noctalia.dev/noctalia/plugins/development/manifest/>
- <https://docs.noctalia.dev/noctalia/plugins/development/entries/>
- <https://docs.noctalia.dev/noctalia/plugins/development/declarative-ui/>
- <https://docs.noctalia.dev/noctalia/plugins/development/runtime-api/>
- <https://docs.noctalia.dev/noctalia/plugins/development/plugin-api/>
- <https://docs.noctalia.dev/noctalia/plugins/development/workflow/>
- <https://docs.noctalia.dev/noctalia/bar/widgets/>

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

Each `plugin.toml` uses the v5 array-table entry schema, not the v4-style
generic entry list:

```toml
[[widget]]
id = "widget"
entry = "widget.luau"

[[panel]]
id = "panel"
entry = "panel.luau"
width = 588
height = 798
placement = "attached"
position = "auto"
```

Both v4 panels declare a 560 by 760 preferred size multiplied by the tracked
1.05 UI scale, while v5 manifest extents are raw logical pixels. The 588 by 798
manifest geometry therefore preserves this machine's current footprint.
Attached placement and the installed host's valid `auto` position preserve the
current bar-panel behavior. Live acceptance still checks the resulting
footprint and attachment for clipping or scale drift.
Wali sets `dependencies = ["walictl"]`; Prism sets `dependencies = ["prism",
"qs"]`. Neither plugin declares root `[[setting]]`, `[[widget.setting]]`, or
`[[panel.setting]]` tables because the ports have no user-configurable plugin
settings.

Dotfiles links the source directories into the v5 local-plugin directory:

```text
$XDG_DATA_HOME/noctalia/plugins/wali-panel
  -> dotfiles/noctalia/plugins/wali-panel

$XDG_DATA_HOME/noctalia/plugins/prism
  -> ~/d/prism/integrations/noctalia-plugin
```

The tracked Noctalia config places both fully qualified entry IDs directly in
the default bar:

```toml
[bar.default]
end = [
  "tray", "battery", "notifications", "output_volume",
  "khughitt/prism:widget", "khughitt/wali-panel:widget", "clock",
]
```

When a bar-list value has no matching `[widget.<name>]` table, v5 treats that
value itself as the widget type; its plugin registry resolves the fully
qualified ID. Named widget tables are unnecessary because these plugins have
no instance settings. They also trigger false `unrecognized widget type`
warnings in the installed standalone validator, so the design avoids them
instead of weakening health with an allowlist. The temporary built-in
`wallpaper` stand-in is removed so two wallpaper controls are not shipped side
by side. Local drop-ins have higher precedence than configured official and
community sources, so no extra plugin source is required.

The explicit `noctalia-plugins` setup phase fails early if either source is
missing. This deliberately makes plugin activation depend on the adjacent
`~/d/prism` checkout, matching the existing niri-glass integration; ordinary
and headless setup remain independent.

Tracked `[plugins] enabled` is deliberately omitted: state settings override
that array wholesale, so tracked enablement silently loses after any GUI or IPC
plugin toggle. A fresh machine runs ordinary setup, starts Noctalia, then runs
`./setup.sh --only noctalia-plugins`. That named phase links both sources and
runs `noctalia msg plugins enable khughitt/wali-panel` followed by `noctalia
msg plugins enable khughitt/prism`. A running v5 shell is therefore an explicit
precondition for the phase; an unavailable IPC endpoint fails early instead of
leaving invisible bar entries. Health checks verify the two links, their v5
manifests, and exact `enabled` lines for both IDs in `noctalia msg plugins
list`. Linux hosts without a running shell pass the explicit
`dotfiles-health --skip-noctalia-ipc` flag; it skips only the enabled-state
query, not static plugin, config, or template checks. The default `just health`
and `just verify` recipes use that offline-safe flag; `just health-live` and
`just health-systemd` retain the runtime enabled-state gate.

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
- previous, next, random, save, and edit actions call `walictl backward`,
  `forward`, `random`, `save-current`, and `edit-current`, respectively;
- copy uses `noctalia.copyToClipboard` rather than spawning `wl-copy`.

Only one action runs at a time. Navigation reloads the current metadata after
success. Save and edit show native success notifications. The copy action is
disabled when no source path exists.

The panel validates the decoded JSON shape before accepting it. A missing
command, rejected launch, timeout, non-zero exit, invalid JSON document, or
invalid payload becomes a visible panel error. A new open or explicit action
may retry; there is no fallback to stale v4 state.

The manifest records the command metadata with `dependencies = ["walictl"]`.
The README also records the existing `BACKGROUND_IMG_DIR`, `WALI_DIR`, and
GIMP requirements for the actions that need them.

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
decision. The old `presentation.oppositeSide()` helper is deleted.

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

Closing the panel queues preview hide. The design expects the host to keep the
panel runtime alive long enough for cleanup and in-flight writes to finish,
without the manifest's `persistent` panel option. Live acceptance tests this
assumption before the rest of Prism parity; failure stops the cutover and
requires revisiting queue ownership.

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

Before plugin implementation begins, land the independent fix that moves
`ui_scale = 1.05` from `[shell]` to `[accessibility]`. It is a current
configuration-health regression, not a plugin prerequisite to bundle into
either plugin change.

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

- the Wali and Prism `plugin.toml` manifests, exact entry paths, expected two
  entries apiece, and explicit `plugin_api` values 9 and 22 (both at most 23);
- `noctalia plugins lint` for each source directory;
- warning-free `noctalia config validate` against the tracked config root;
- isolated setup topology with disposable Wali and Prism sources, plus an
  expected early failure when the Prism source or Noctalia IPC is absent;
- a shared test stub used by setup and health that forwards only read-only
  config validation and template listing, intercepts plugin enable/list IPC,
  and rejects every other Noctalia command;
- the explicit setup phase's two exact plugin-enable IPC calls and health rejection
  when either installed plugin is not enabled;
- health-check rejection of missing, wrong, or v4 plugin links;
- the two fully qualified widget entry IDs directly in the default bar end
  list, no `[widget.*]` aliases for them, and removal of `wallpaper`;
- existing `walictl` behavior;
- Prism's describe model and rewritten static plugin contract;
- direct Lua execution of the production, standard-Lua-compatible Prism
  presentation and queue modules, including golden mapping and coalescing
  cases;
- the full dotfiles and Prism test suites.

The installed Noctalia linter does not enforce the supported API range, reject
unknown manifest keys, verify that entry types are host-recognized, or compile
Luau. With no declared settings, its settings cross-check is also nearly a
no-op. `noctalia config validate` likewise does not validate widget names in a
bar section list. The explicit static assertions above are therefore separate
gates, not duplicates of those tools.

The production presentation and queue modules stay within the standard
Lua-compatible Luau subset so the already-installed Lua interpreter can
execute their tests without adding a project package dependency. Those modules
therefore use no Luau type annotations, `continue`, or other Luau-only syntax;
the direct Lua test run enforces that constraint. Prism exposes that check as
`npm run test:plugin-lua`, runs its existing Node suite first, and documents the
`lua` executable as a development prerequisite.

Live acceptance begins with an enablement preflight. `noctalia config export
merged` must show both IDs in `[plugins] enabled`, `noctalia msg plugins list`
must report both exact IDs as enabled, and
`~/.cache/noctalia/noctalia.log` must report `loaded plugin '<id>' (2 entries)`
for each. A disabled or missing plugin stops acceptance.

Then:

0. Open Prism, queue a command, close the panel before completion, and confirm
   both the command and queued preview-hide finish. Stop if the runtime does
   not survive close as expected.
1. Both bar widgets render and open their panels attached to the originating
   bar. Their 588 by 798 footprints match the scaled v4 panels without clipping.
2. `~/.cache/noctalia/noctalia.log` contains no Luau compile, timeout, or
   runtime errors for either plugin.
3. Wali current metadata, navigation, random, copy, save, and edit behavior is
   exercised, including an unavailable-source error.
4. Prism renders every visible parameter from `prism describe --json`.
5. One toggle, slider, select, and color value is changed and reconciled.
6. Individual and group reset restore authoritative values.
7. Live and release-only sliders exhibit their distinct write timing.
8. Preview targets the originating output, uses the left side, switches its
   diagnostic background, and hides when the panel closes.
9. The live config directory contains no stale `user-templates.toml` (or
    other v4 file still matched by the v5 `*.toml` loader), and live config
    validation is warning-free.

## Landing order

1. Land the independent Noctalia `ui_scale` schema fix.
2. Implement and commit the Prism v5 plugin in a fresh Prism worktree.
3. Implement Wali, configuration, installation, health checks, and docs in the
   dotfiles worktree.
4. Run both repositories' automated suites.
5. Merge Prism first, then dotfiles.
6. Remove or rename the stale live `user-templates.toml` outside the v5
   `*.toml` load pattern.
7. Run ordinary setup from the dotfiles main checkout, start or reload
   Noctalia, run `./setup.sh --only noctalia-plugins`, and perform live
   acceptance.

This order prevents tracked dotfiles from enabling a Prism plugin that its
owning repository has not yet supplied.
