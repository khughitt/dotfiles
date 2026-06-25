# Niri Workspace Profiles — Phase 3: Bar Identity Design

## Goal

Make each niri workspace carry its **profile identity in the noctalia bar**: a
recolored workspace strip where every workspace shows its profile **icon** in the
profile's **ring color**, and the focused workspace expands into a filled pill
showing the friendly **label**. This completes the "each workspace has its own
feel" loop at the bar level, complementing Phase 1's per-workspace focus ring and
Phase 2's `Mod+P` selector.

Phase 3 is a **self-contained noctalia v4 plugin** — it reuses the
`~/.config/niri/wsprofiles.json` view model the Phase 1 daemon already emits, and
requires **no changes** to the daemon, niri, or the selector.

## Non-Goals

- No daemon, niri, or `wsprofile-menu` changes. This phase reads existing state only.
- No scroll-to-cycle over the strip in v1 (click-to-switch only).
- No per-monitor / multi-output specialization beyond what noctalia's
  `CompositorService` already provides.
- No ohai avatars yet (later phase). The cell shows the catalog `icon` glyph.
- No guided settings UI in v1 beyond an optional manifest `metadata.defaultSettings`.
- No patching of the installed noctalia package (`/etc/xdg/quickshell/noctalia-shell/`,
  root-owned, overwritten on update). All code lives in the user plugins dir.
- No compatibility/legacy layers.

## Background: noctalia v4 plugin surface (verified)

The installed `noctalia-shell` 4.7.7 exposes a QML plugin system (not the Luau
plugins of the unreleased native v5). Verified against the installed package and
the user's existing `catwalk` / `wali-panel` plugins:

- Plugins live in `~/.config/noctalia/plugins/<id>/` (the user symlinks each from
  `~/d/dotfiles/noctalia/plugins/<id>/`).
- A `manifest.json` with `entryPoints.barWidget` registers a **bar widget**
  (`Services/Noctalia/PluginRegistry.qml`, `Services/UI/BarWidgetRegistry.qml`,
  `Services/Noctalia/PluginService.qml`). The widget id is `plugin:<id>`.
- Bar widgets receive `pluginApi`, `screen`, `widgetId`, `section` and may import
  `qs.Commons` (`Color`, `Style`, `Settings`), `qs.Services.Compositor`
  (`CompositorService`), `qs.Services.UI` (`BarService`), `qs.Widgets`.
- `CompositorService.workspaces` is a `ListModel` of the live niri workspaces, each
  `{ id, idx, name, output, isFocused, isActive, isUrgent, isOccupied }`. `name` is
  the niri workspace name — i.e. the profile slot name (`ember`, `tide`, `tide-2`).
- `CompositorService.switchToWorkspace(ws)` focuses a workspace model object — the
  same call noctalia's core `Workspace.qml` uses on click.
- `Color` (Material 3 singleton: `mPrimary`, `mOnSurface`, `mSurface`,
  `mSurfaceVariant`, `mError`, `mOutline`, …) and `Style` (sizing/animation, e.g.
  `Style.getCapsuleHeightForScreen(name)`) provide theme-consistent styling.
- `FileView` + `watchChanges`/`onFileChanged` (`Quickshell.Io`) reads and watches
  external files such as `~/.config/niri/wsprofiles.json`.

## Architecture

```
~/.config/niri/wsprofiles.json  ──FileView(watch)──┐
  [{id,label,icon,ring,border,instances}]           │
                                                     v
CompositorService.workspaces  ───────────►  niri-workspace-profiles (plugin)
  (live niri workspaces:                     ┌──────────────────────────────┐
   name, idx, isFocused,                     │ BarWidget.qml (the strip)     │
   isOccupied, isUrgent, …) ───────────────► │  logic.buildCells(...) model  │
                                             │  Repeater → one cell / ws     │
                                             │  click → switchToWorkspace    │
                                             └──────────────────────────────┘
        replaces noctalia's core "Workspace" bar widget
```

The plugin is a **view + click launcher** over existing state: it renders a cell
per workspace and, on click, delegates to `CompositorService.switchToWorkspace`.
The Phase 1 daemon's event-stream applies the colorscheme/wallpaper on the
resulting focus change exactly as it does for keyboard- and selector-driven
switches — one shared switching path.

## Components

### Plugin package (`~/d/dotfiles/noctalia/plugins/niri-workspace-profiles/`)

Symlinked into `~/.config/noctalia/plugins/niri-workspace-profiles` (the same way
`wali-panel` is linked).

- **`manifest.json`** — follows the `catwalk` shape:
  ```json
  {
    "id": "niri-workspace-profiles",
    "name": "Niri Workspace Profiles",
    "version": "1.0.0",
    "minNoctaliaVersion": "4.7.0",
    "author": "Keith Hughitt",
    "license": "MIT",
    "description": "Recolored niri workspace strip showing per-profile icon, color, and label.",
    "tags": ["Bar", "Niri"],
    "entryPoints": { "main": "Main.qml", "barWidget": "BarWidget.qml" },
    "dependencies": { "plugins": [] },
    "metadata": { "defaultSettings": {} }
  }
  ```
  `Main.qml` is a minimal `QtObject {}` (no panel features in v1), mirroring the
  plugin convention.

- **`BarWidget.qml`** — the strip. Responsibilities:
  - A `FileView` on `~/.config/niri/wsprofiles.json` with `watchChanges: true` +
    `onFileChanged: reload()`; on `onLoaded` parse `JSON.parse(text())` into a
    `profiles` array, on `onLoadFailed` set `profiles = []` (degrade to neutral).
  - A `Repeater` over `CompositorService.workspaces` rendering one cell per
    workspace from the model produced by `logic.buildCells(...)`.
  - Each cell renders per the **Rendering** section; click →
    `CompositorService.switchToWorkspace(ws)`; hover → tooltip with the label.
  - Theme fallbacks: when a cell has no profile (`ring === null`) it uses neutral
    `Color` tokens; the profile `ring` hex is used directly otherwise.

- **`logic.js`** — pure classic-QML-JS library (`.pragma library` + top-level
  `function` declarations, **no** `export`), node-tested via the `node:vm` loader
  pattern established in Phase 2's `menu-logic.js`. Holds the only non-trivial logic:
  - `resolveProfile(name, profiles) -> profile | null`
    - exact `id` match first;
    - else strip a single trailing `-<digits>` from `name` and match (so instance
      slots `tide-2`/`tide-3` resolve to `tide`). Unambiguous because the Phase 1
      `id` grammar forbids ids ending in `-<digits>`.
    - no match → `null`.
  - `buildCells(workspaces, profiles) -> Array<cell>` where each `cell` is
    `{ id, idx, name, hasProfile, ring|null, icon, label, isFocused, isOccupied, isUrgent }`,
    in `workspaces` order. `ring`/`icon`/`label` come from the resolved profile;
    when unresolved, `hasProfile=false`, `ring=null`, `icon=''`, `label=name`. The
    function is pure — it never references `Color`/`Style`; the QML maps `ring===null`
    to a neutral theme token at render time.

### Bar swap (one-time, manual)

`plugin:niri-workspace-profiles` replaces noctalia's core `Workspace` widget. Bar
layout lives in `~/.config/noctalia/settings.json` (`bar.widgets.{left,center,right}`),
which is **not** tracked in the dotfiles repo, so this is a documented one-time
step, not a scripted change: enable the plugin in noctalia → place its widget where
`Workspace` sat (typically `center`) → remove the core `Workspace` entry.

## Rendering

A horizontal row of cells in niri workspace order (`idx`), each sized to the bar
capsule height (`Style.getCapsuleHeightForScreen(screenName)`):

- **Profiled, not focused:** the profile **icon** glyph drawn in the profile's
  **ring color**, transparent background. `isOccupied === false` dims the icon
  (reduced opacity); occupied is full strength.
- **Profiled, focused:** a **filled pill in the ring color** containing the **icon +
  `label`**, with a contrasting foreground (white/black chosen for legibility on the
  ring color, or `Color.mOnSurface`/`mSurface` as the theme-aware default). This is
  the only cell that shows a label.
- **Unprofiled** (no `resolveProfile` match — e.g. `scratchpad`): a **neutral** cell
  using `Color` tokens — the `idx` number (or a dot) in `Color.mOnSurface`; focused
  unprofiled = a neutral filled pill with the number. Kept visible for navigation.
- **Urgent** (`isUrgent`): subtle highlight using `Color.mError`.
- Color treatment is **focused-pill + colored-icons**: only the focused cell is a
  filled ring-color pill; other profiled cells carry color via their icon only.

## Data flow

- **catalog edit** → daemon rewrites `wsprofiles.json` (Phase 1) → plugin
  `FileView.onFileChanged` reloads → `profiles` updates → cells recompute.
- **workspace focus / occupancy change** (any source: `Mod+P`, keyboard, click) →
  `CompositorService.workspaces` updates → `buildCells` recomputes → strip
  re-renders; the daemon separately applies the theme on focus.
- **click a cell** → `CompositorService.switchToWorkspace(ws)` → focus changes →
  (daemon applies theme; strip re-renders with the new focused pill).

## Error handling

- `wsprofiles.json` missing/corrupt → `profiles = []` → every cell resolves to the
  neutral style; the strip degrades to a plain numbered workspace strip, never
  crashes.
- A workspace whose `name` matches no profile → neutral cell (navigation preserved).
- Empty `CompositorService.workspaces` → empty strip; no crash.
- Plugin/widget load failure surfaces in the noctalia/`qs` log; it does not affect
  the daemon or selector.

## Testing

**Unit (node:test via `node:vm` loader, mirroring `menu-logic.test.js`):**

- `resolveProfile(name, profiles)`:
  - exact id match returns that profile (`'ember'` → ember)
  - instance slot strips the suffix (`'tide-2'` → tide, `'tide-3'` → tide)
  - an id that itself contains digits but does not end in `-<digits>` still matches
    exactly and is not mis-stripped (`'api'` with a profile `api`)
  - unknown name → `null` (`'scratchpad'` → null)
- `buildCells(workspaces, profiles)`:
  - maps each workspace in order to `{hasProfile, ring, icon, label, isFocused, …}`
  - unprofiled workspace → `hasProfile=false`, `ring=null`, `icon=''`, `label=name`
  - profiled workspace → `ring`/`icon`/`label` from the profile
  - carries through `isFocused`, `isOccupied`, `isUrgent`, `idx`
  - empty profiles array → all cells neutral; empty workspaces → `[]`

**Manual verification (running niri + noctalia v4 bar):**

1. Symlink + enable the plugin; swap its widget in for the core `Workspace` widget.
   The strip renders one cell per workspace.
2. `ember` shows its icon in `#ff7a45`; `tide`/`tide-2` show theirs in `#3aa6ff`.
3. Focus `tide` (via `Mod+P` or click) → its cell becomes a filled pill in
   `#3aa6ff` with the icon + "Tide — infra"; the previously focused cell collapses
   to its icon.
4. Click `ember`'s cell → focus switches to `ember`, shell recolors (daemon), the
   pill moves to `ember`.
5. An empty (unoccupied) profiled workspace shows a dimmed icon; opening a window
   there brightens it.
6. Focus `scratchpad` → neutral pill with its number/dot (no profile color).
7. Edit `profiles.yaml` (change `tide`'s color/icon/label), save → daemon rewrites
   `wsprofiles.json` → the strip updates live without a noctalia restart.
8. Rename/remove `wsprofiles.json` → strip degrades to neutral numbered cells, no
   crash; restoring the file restores colors.

## Risks

1. The plugin couples to noctalia internals (`CompositorService.switchToWorkspace`,
   `CompositorService.workspaces` fields, `Color`/`Style` singletons). These can
   change across noctalia versions; `manifest.json` pins `minNoctaliaVersion` and
   the coupling is the accepted cost of customizing the bar without patching the
   package.
2. Replacing the core `Workspace` widget is a manual noctalia-settings step
   (untracked `settings.json`); the plan documents it and the strip is reversible by
   re-adding the core widget.
3. Contrasting-foreground legibility on arbitrary ring colors — the focused pill
   picks a readable foreground; verified by manual step 3 across the catalog colors.

## Out of scope (later phases)

- ohai per-profile avatars in place of / alongside the icon glyph.
- Scroll-to-cycle over the strip.
- A plugin settings panel (label length, show/hide unprofiled, etc.).
- The polished native noctalia "profile switcher" panel from the original vignette.
- noctalia v5 migration (isolated adapter swap, tracked in the Phase 1/2 specs).
