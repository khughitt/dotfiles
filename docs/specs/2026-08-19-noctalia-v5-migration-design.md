# Noctalia v5 migration

**Status:** Revised after review; approval pending.

## Goal

Replace the active Quickshell-based Noctalia v4 integration with the native
Noctalia v5 shell while preserving the stable desktop behavior that belongs in
dotfiles. The first cutover covers shell startup, compositor IPC, wallpaper
automation, wallpaper-derived colors, app-theme generation, and core bar
behavior. Noctalia v4 plugins are deferred because v5 uses a different plugin
runtime.

The migration must leave a warning-free v5 configuration, keep private and
transient state out of the repository, and preserve a one-login rollback path.

## Current state

- Both `noctalia-git` v5 and `noctalia-shell` v4 are installed, but Niri and
  Hyprland still launch v4 with `qs -c noctalia-shell`.
- Compositor keybindings, `shell/wali`, `bin/walictl`, its tests, and plugin QML
  embed the v4 Quickshell IPC interface.
- `noctalia/templates.toml` is a valid v5 overlay and registers Glow, but the
  running v4 shell does not read it. This is why wallpaper changes do not
  regenerate `~/.cache/noctalia/glow.json`.
- `~/.config/noctalia/user-templates.toml` still registers Nvim, Claude Code,
  Codex, and Ohai using the v4 schema. V5 loads every root `*.toml`, reports the
  old sections as unknown, and ignores those template entries.
- Stable v4 behavior lives in machine-owned JSON instead of the repository:
  wallpaper rotation, palette source, bar composition, notifications, OSD,
  idle actions, and UI preferences.
- The Wali Panel and Memory Pressure Alert plugins in this repository and the
  Prism plugin in its own repository use v4 QML manifests. V5 requires
  `plugin.toml` manifests and Luau entry scripts, so these plugins cannot be
  installed unchanged.

Noctalia documents v5 as a fresh install rather than an automatic v4 upgrade.
Its v5 configuration and IPC are intentionally separate from the Quickshell
line:

- <https://docs.noctalia.dev/v5/getting-started/faq/>
- <https://docs.noctalia.dev/v5/configuration/>
- <https://docs.noctalia.dev/v5/ipc/>

## Decision

Perform a curated, declarative core cutover.

1. Track stable v5 behavior in one `noctalia/config.toml`.
2. Consolidate all app-theme registrations in
   `noctalia/templates.toml` using the v5 schema.
3. Replace v4 startup and IPC calls directly with `noctalia` and
   `noctalia msg`; do not add a version-detecting wrapper.
4. Stop installing v4 QML plugins. Keep their source available for later,
   separately designed v5 ports.
5. Keep `noctalia-shell` installed but inactive through one successful v5
   login. Remove it only after live validation and explicit confirmation.

This is smaller and more reproducible than exporting the full effective v5
configuration, which would pin hundreds of upstream defaults. It is safer than
changing only startup commands, which would leave desired behavior unspecified
and therefore controlled by upstream defaults. The existing v5 state contains
only lock-screen widget placement, so it presents little cutover risk.

## Configuration ownership

| Concern | Tracked source | Runtime destination |
|---|---|---|
| Stable shell behavior | `noctalia/config.toml` | `~/.config/noctalia/config.toml` |
| App-theme registry | `noctalia/templates.toml` | `~/.config/noctalia/templates.toml` |
| Template sources | `noctalia/templates/` | `~/.config/noctalia/templates/` |
| Custom palette files | `noctalia/palettes/*.json` | `~/.config/noctalia/palettes/*.json` |
| Generated compositor themes | Not tracked | `~/.config/{hypr,niri}/noctalia.*` |
| Transient or private state | Not tracked | `~/.local/state/noctalia/` |

Noctalia loads tracked config first and GUI-managed `settings.toml` last. A GUI
change may therefore override a tracked default intentionally. The repository
does not track app history, credentials, the current wallpaper, location,
avatar, plugin caches, or UI runtime state.

The v4 `user-templates.toml` is renamed outside the `*.toml` pattern during the
rollback window so v5 cannot merge its obsolete schema. JSON files and the v4
plugin directory remain untouched until the rollback window closes. No
permanent compatibility or migration path is added to `setup.sh` for this
one-machine transition.

## Stable shell behavior

### Theme and wallpaper

Track these v5 settings:

- dark mode;
- wallpaper palette source with `m3-tonal-spot` generation;
- wallpaper directory `~/d/linux/backgrounds/3440`;
- alphabetical automation every 900 seconds;
- a fade-only transition with edge smoothing `0.05`, preserving the current
  behavior rather than v5's `0.3` default;
- startup transition enabled;
- Niri stationary-wallpaper mode with Noctalia backdrop disabled.

The current wallpaper path is runtime state. Automation chooses and persists
the active image without committing it to dotfiles. Pure upstream defaults,
including the 1500 ms transition duration and recursive discovery, are omitted.
Dark mode and a disabled backdrop remain explicit because they are stable
desktop invariants even though they currently match v5 defaults.

### Bar and shell UI

Reproduce the useful v4 layout with v5 built-ins:

- start: workspaces, CPU, and RAM;
- center: active window;
- end: tray, battery, notifications, output volume, wallpaper, and clock.

The Catwalk, Prism, and Wali Panel slots are absent until compatible plugins
exist. The built-in wallpaper widget replaces the core picker entry point, but
does not attempt to reproduce Wali Panel's custom source-photo actions.

Preserve the existing UI scale, panel transparency, top-right notification and
OSD placement, and disabled dock and desktop widgets.

### Idle and hooks

Track the current idle policy using native v5 actions:

- screen off after 600 seconds;
- lock after 3600 seconds;
- lock and suspend after 86400 seconds.

Retain Familiar's theme-mode synchronization as a v5
`theme_mode_changed` hook. Remove the v4 wallpaper hook that writes `~/.fehbg`.
Update the shared current-wallpaper lookup used by `wali_print` and
`wali_rotate`: the Noctalia backend uses `noctalia msg wallpaper-get`, swww
continues to query swww, and only the feh backend reads `~/.fehbg`.

## Template pipeline

`noctalia/templates.toml` becomes the only template registry. It explicitly
enables:

- user templates: Glow, Nvim/glass synchronization, Claude Code, Codex, and
  Ohai;
- built-ins: Hyprland, GTK 3, GTK 4, Qt, Niri, Ghostty, and Btop;
- community template: Zathura.

Template paths use `~` or XDG variables rather than machine-specific physical
paths. In particular, Ohai's input is
`~/d/software/ohai/ohai/templates/noctalia/ohai-config.toml`. The existing Nvim
post-hook remains the sole atomic generation boundary for Nvim, Kitty glass,
and OpenCode. The built-in Kitty template is not enabled because its post-hook
rewrites tracked Kitty configuration and would create a second owner for the
same colors.

Built-in templates are not assumed to be render-only. Their post-hooks edit
whichever config file the app reads, and for Niri, Hyprland, Ghostty, and GTK
that file resolves into this repository. Each hook is a no-op today only
because the tracked file already carries the exact marker the hook looks for:
`include "./noctalia.kdl"` in `niri/config.kdl`, `theme = noctalia` in
`ghostty/config.ghostty`, and `@import url("noctalia.css");` in both
`gtk-3.0/gtk.css` and `gtk-4.0/gtk.css`. Those markers are load-bearing, not
incidental: removing one turns every theme apply into a repository write, and
the GTK hook deletes the symlink outright when it cannot write through it.
Repository tests therefore require every enabled hook to leave its tracked
target byte-for-byte unchanged and to leave the symlink intact. Only Btop is
genuinely app-local, writing `~/.config/btop/btop.conf`, which this repository
does not track. Generated `hypr/noctalia.conf` is ignored alongside the
existing generated `niri/noctalia.kdl`.

The resulting data flow is:

```text
wallpaper automation
  -> v5 wallpaper service
  -> wallpaper-derived palette
  -> shell colors and registered templates
  -> Glow, Nvim/Kitty/OpenCode, agent themes, and other app themes
```

Noctalia v5 requires built-in and community template IDs to be selected
explicitly:

<https://docs.noctalia.dev/v5/theming/app-theming/>

## Compositor and CLI integration

### Niri

- Launch `noctalia` at startup.
- Replace each Quickshell IPC binding with the corresponding
  `noctalia msg` command.
- Keep the stationary `^noctalia-wallpaper` backdrop rule.
- Replace the v4 layer namespace expression with the documented v5 surfaces.
- Add a floating window rule for app id `dev.noctalia.Noctalia`.

The relevant v5 surface and keybinding contracts are documented at
<https://docs.noctalia.dev/v5/compositor-settings/niri/>.

### Hyprland

- Launch `noctalia` at startup.
- Set `$ipc = noctalia msg` and translate the existing bindings one for one.
- Replace the v4 layer namespace expression with the documented v5 expression.
- Replace the obsolete
  `source = ~/.config/hypr/noctalia/noctalia-colors.conf` with
  `source = ~/.config/hypr/noctalia.conf` before enabling the built-in
  Hyprland template.

The active Hyprland configuration remains in its current format; adopting the
new Lua configuration system is unrelated to this migration. The v5 surface
contract is documented at
<https://docs.noctalia.dev/v5/compositor-settings/hyprland/>.

### IPC mapping

| Action | V5 command |
|---|---|
| Launcher | `noctalia msg panel-toggle launcher` |
| Control center | `noctalia msg panel-toggle control-center` |
| Settings | `noctalia msg settings-toggle` |
| Volume up/down/mute | `noctalia msg volume-up`, `volume-down`, `volume-mute` |
| Brightness up/down | `noctalia msg brightness-up`, `brightness-down` |
| Current wallpaper | `noctalia msg wallpaper-get` |
| Set default wallpaper | `noctalia msg wallpaper-set <path>` |
| Random default wallpaper | `noctalia msg wallpaper-random` |

`bin/walictl` uses these commands as argument arrays so paths remain safe.
On Wayland, `shell/wali` selects Noctalia when the v5 executable is installed,
not only while its process happens to be running. A stopped shell therefore
produces an IPC failure instead of silently switching wallpaper backends. The
user-facing `walictl random` command is preserved by replacing its
`plugin:wali-panel random all` call with `noctalia msg wallpaper-random`. The
v4 plugin IPC helper is removed only after its callers have migrated.

## Plugin boundary

The core migration does not port plugins. `setup.sh` stops linking Wali Panel,
Memory Pressure Alert, or Prism into `~/.config/noctalia/plugins`, and health
checks stop requiring those v4 paths. Their source is not presented as v5 code.

Later ports must be separate designs because v5 plugins are not translations
of QML files: they require new manifests, Luau entry scripts, and possibly
different UI capabilities. The v5 plugin API is still documented as beta:

<https://docs.noctalia.dev/v5/plugins/>

## Setup and health behavior

Graphical setup links the v5 config, templates registry, template directory,
and tracked custom palette files. It does not mutate app-owned `settings.toml`
or delete v4 state.

Health and test checks require:

- each managed v5 link to resolve to the tracked source;
- `noctalia config validate "$XDG_CONFIG_HOME/noctalia"` in an isolated setup
  to produce neither errors nor warnings, without reading live GUI state;
- the expected user templates to appear in
  `noctalia theme --list-templates`;
- active executable code and compositor configuration to contain no
  `noctalia-shell` call.

Warnings are failures for dotfiles even though the v5 validator exits zero for
warning-only configuration. This prevents obsolete or misspelled settings from
being silently ignored. The live cutover separately runs bare
`noctalia config validate` so the merged active config and GUI-managed state are
also warning-free.

The cohesive implementation updates `noctalia/noctalia.md` and
`noctalia/noctalia-wallpaper-switcher.md` after the v5 behavior lands; until
then, those files continue to describe the active v4 system.

## Cutover and rollback

The live cutover is an explicit operator sequence:

1. Confirm the v4 package, JSON configuration, and plugin directory still
   exist.
2. Rename `~/.config/noctalia/user-templates.toml` to a suffix v5 will not
   autoload.
3. Run graphical setup to install the tracked v5 links.
4. Validate both the isolated tracked configuration and the merged active
   configuration without warnings.
5. Stop v4 and start v5 manually.
6. Exercise launcher, control center, settings, volume, brightness, wallpaper
   get/set/random, and the built-in wallpaper panel.
7. Change the wallpaper and verify the palette and every generated theme
   consumer update, then confirm the repository remains clean.
8. Reload Niri and complete one fresh login with v5 autostart.
9. After successful validation, request explicit confirmation before removing
   `noctalia-shell` or archiving v4 state.

Before step 9, rollback means stopping v5, restoring the original template
registry name, and launching the untouched v4 installation. If compositor
autostart must also return to v4, revert the cohesive migration change and
rerun setup. No dual-version runtime wrapper is maintained.

## Error handling

- Missing or stopped v5 shell: `walictl` reports an unavailable or failed
  `noctalia` IPC command; it does not call Quickshell.
- Invalid tracked config: setup verification fails before live cutover.
- Unknown or obsolete config: warning text fails the repository check.
- Failed template render: report the renderer or post-hook failure and treat
  a missing or stale expected output as failed validation. The cutover does not
  delete the previous consumer files.
- Failed live validation: leave the v4 package and state intact and use the
  rollback sequence.

## Verification

### Automated

- Update `tests/bin/test_walictl.py` to assert exact v5 argument arrays and
  errors for a missing command, a failed IPC call, and empty wallpaper output.
- Cover both `wali_print` and `wali_rotate` on the Noctalia backend and prove
  neither depends on `~/.fehbg`.
- Update setup and health tests for `config.toml`, `templates.toml`, template
  sources, palettes, and the removal of v4 plugin-link requirements.
- Validate an isolated XDG config installed from the repository and require its
  output to contain no warning or error markers.
- Require the complete user-template set in the template listing.
- Keep direct rendering checks for Glow, Claude Code, Codex, and the existing
  Nvim/glass pipeline.
- Apply the built-in Niri, Hyprland, Ghostty, and GTK 3/4 post-hooks to an
  isolated XDG tree whose entries symlink to the tracked configs, and require
  no byte changes to those tracked files and no replaced symlinks. Require the
  Hyprland copy to source only `~/.config/hypr/noctalia.conf`, and require its
  generated output path to be ignored.
- Scan active configuration and executable code for v4 startup or IPC calls.
- Run the complete `just test` gate.

### Manual

1. Confirm the v5 bar contains the agreed built-in widget layout and no broken
   plugin placeholders.
2. Exercise all compositor keybindings.
3. Confirm stationary wallpaper behavior and v5 blur namespaces in Niri.
4. Trigger random and explicit wallpaper changes through `walictl`.
5. Confirm the wallpaper rotates after 900 seconds in alphabetical order.
6. Compare modification times and visible colors for Glow, Nvim, Kitty,
   OpenCode, Claude Code, Codex, Ohai, and selected built-in templates after a
   wallpaper change.
7. Confirm a theme apply neither edits tracked Hyprland, Niri, Ghostty, GTK, or
   Kitty config nor leaves untracked generated files.
8. Complete one fresh login before approving v4 removal.

## Out of scope

- Porting Wali Panel, Memory Pressure Alert, Prism, Pomodoro, or any downloaded
  v4 community plugin.
- Reproducing Catwalk or another decorative plugin in core configuration.
- Adopting Hyprland's Lua configuration system.
- Tracking personal location, avatar, wallpaper selection, credentials,
  histories, caches, or plugin runtime state.
- A permanent v4/v5 compatibility wrapper or automatic fallback.
- Removing the v4 package or deleting v4 state without a separate explicit
  confirmation after live validation.
