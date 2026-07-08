# Niri Workspace Profiles

`wsprofiles` maps named niri workspaces to profile metadata: display labels, focus-ring colors, optional borders, instance counts, and Noctalia theme settings. The daemon keeps niri's generated workspace config, Noctalia profile selectors, and the workspace-profile bar in sync from one source file.

## Quick Start

From `~/d/dotfiles/wsprofiles`:

```sh
npm install
npm test
```

Run the daemon with `bin/wsprofiled`. It reads `~/d/dotfiles/wsprofiles/profiles.yaml`, writes generated niri and Noctalia view-model files, then listens for niri focus events.

Use the control client to focus an existing profile slot or request a free extra instance:

```sh
bin/wsprofilectl open ember
bin/wsprofilectl new tide
```

## Files

| Path | Purpose |
| --- | --- |
| `profiles.yaml` | The hand-edited profile catalog. |
| `bin/wsprofiled` | Long-running daemon. Applies the catalog, watches edits, and reacts to niri focus events. |
| `bin/wsprofilectl` | Small control client for profile open/new commands. |
| `src/kdl.js` | Generates niri workspace KDL. |
| `src/viewmodel.js` | Generates the JSON consumed by the Noctalia menu and bar. |
| `menu/` | Quickshell launcher menu for opening profile workspaces. |
| `../noctalia/plugins/niri-workspace-profiles/` | Noctalia bar widget that displays profile icons/colors. |

Generated files:

| Path | Purpose |
| --- | --- |
| `~/.config/niri/profiles.kdl` | Workspace blocks loaded by niri. Do not edit by hand. |
| `~/.config/niri/wsprofiles.json` | Profile view model for QML. Do not edit by hand. |

The generated JSON is written only as part of the same transaction as `profiles.kdl`. If niri rejects the generated KDL during reload, the daemon restores both files so QML never gets ahead of the config niri accepted.

## Profile Catalog

`profiles.yaml` has a top-level `profiles` list:

```yaml
profiles:
  - id: ember
    label: "Ember - client-api"
    instances: 1
    ring: "#ff7a45"
    border: "#ff7a45"
    icon: ""
    theme:
      wallpaper: ~/d/linux/backgrounds/3440/PXL_20210602_024124219.jpg
      mode: dark
```

Fields:

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | yes | Profile id and primary workspace name. Must match `^[a-z][a-z0-9-]*$` and must not end in `-<digits>`. |
| `label` | no | Human label shown by selectors and the bar. Defaults to `id`. |
| `instances` | no | Number of slots generated for the profile. Defaults to `1`. |
| `ring` | yes | Focus-ring color for generated niri workspaces. Hex color such as `#ff7a45`. |
| `border` | no | Optional active border color. If omitted, no explicit border block is generated. |
| `icon` | no | Optional glyph shown in Noctalia UI. Empty means QML falls back to the first label character. |
| `theme.wallpaper` | no | Wallpaper path passed to Noctalia for all screens. `~/` is expanded by the daemon. |
| `theme.mode` | no | `dark` or `light`; applied through Noctalia dark-mode IPC. |

When `instances` is greater than `1`, the first slot is the bare id and additional slots use numeric suffixes:

```yaml
id: tide
instances: 3
```

generates `tide`, `tide-2`, and `tide-3`. The base profile id itself cannot end in a numeric suffix because those names are reserved for generated instances.

## Runtime Behavior

On startup, `wsprofiled`:

1. Refuses to start if another daemon already owns the control socket.
2. Parses `profiles.yaml`.
3. Writes `~/.config/niri/profiles.kdl` and `~/.config/niri/wsprofiles.json`.
4. Runs `niri msg action load-config`.
5. Starts a Unix control socket at `$XDG_RUNTIME_DIR/wsprofiled.sock`.
6. Subscribes to `niri msg --json event-stream`.

On workspace focus, the daemon resolves the workspace name back to its profile and applies the profile theme through Noctalia IPC:

```sh
qs -c noctalia-shell ipc call wallpaper set <path> all
qs -c noctalia-shell ipc call darkMode setDark
qs -c noctalia-shell ipc call darkMode setLight
```

The daemon remembers the last theme it successfully applied and skips unchanged dark-mode fields. Wallpaper commands are still sent on focus when `theme.wallpaper` is set, because Noctalia wallpaper automation and manual wallpaper changes can alter the current wallpaper outside `wsprofiled`.

## Color Schemes

Workspace profiles intentionally do not set Noctalia color schemes. Noctalia shows a toast each time `colorScheme set` applies a scheme, so the local catalog uses profile rings and wallpapers for workspace identity instead.

The parser still accepts `theme.colorscheme` for experiments, but adding it back will call Noctalia's `colorScheme set` IPC and can reintroduce the `Color Scheme <name>` popup.

## Integrations

The launcher menu in `menu/` reads `~/.config/niri/wsprofiles.json` and sends `open` or `new` requests to `wsprofiled` through `wsprofilectl`.

The Noctalia bar plugin at `~/d/dotfiles/noctalia/plugins/niri-workspace-profiles` also reads `wsprofiles.json`. It renders the horizontal workspace strip with profile colors and labels, and falls back to plain workspace numbers for unprofiled workspaces.

## wsnamed — auto-derived workspace names

`bin/wsnamed` watches the niri event stream and names each occupied workspace
after the project its focused window is in: for a kitty window it resolves the
foreground shell's cwd via `/proc` and uses the git repo root basename; for a
GUI app it uses the app id. Names are shown by noctalia (`labelMode: index+name`)
and the Expo overview.

It is a **single, safe name authority**: it only ever writes a name that is
empty or one it previously set itself, so `ember`/`tide` and manual names are
never touched (ownership is re-validated against the live name every pass, so an
externally renamed workspace is released and never unset by us). Duplicate
project names get unique `-2`/`-3` slots.

Assumes one kitty process per OS-window; a window with multiple tabs/splits is
ambiguous and falls back to the (sanitized) window title. Started from
`niri/config.kdl` via `spawn-sh-at-startup`; on unrecoverable error it exits so
the failure is visible (a session restart relaunches it).

## Testing

Run the wsprofiles unit tests from this directory:

```sh
npm test
```

The tests cover catalog validation, KDL generation, transactional artifact writes, Noctalia command generation, daemon focus behavior, occupancy tracking, and the menu logic boundary.
