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
- No left/right vertical bar layout in v1. This phase targets horizontal noctalia
  bars; vertical bars should keep the core `Workspace` widget until a later phase
  adds a Column-oriented version.
- No *new* multi-monitor features. The strip replicates the core Workspace widget's
  existing per-screen filtering on horizontal bars, but adds nothing beyond it.
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
        replaces noctalia's core "Workspace" bar widget on horizontal bars
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
    `onFileChanged: reload()`; on `onLoaded`, call `logic.parseProfiles(text())`
    inside the view layer and assign the returned `profiles` array. Missing,
    corrupt, or wrong-shaped JSON sets `profiles = []` and records a load error,
    then refreshes cells so the strip degrades to neutral instead of crashing or
    rendering stale profile data. `onLoadFailed` follows the same neutral path.
  - **Reactivity bridge.** `CompositorService.workspaces` is a `ListModel`, not a
    plain array, so a computed `buildCells(...)` would not refresh on its own. A
    `refreshCells()` function snapshots the live model into a plain JS array
    (`for i in 0..count: workspaces.get(i)`), runs `filterWorkspaces(snapshot, opts)`
    then `buildCells(filtered, profiles)`, and assigns the result to a `cells`
    property. The `Repeater` uses **`cells`** as its model (not the live ListModel).
    `refreshCells()` is invoked from `Connections { target: CompositorService;
    function onWorkspacesChanged(); function onWindowListChanged();
    function onActiveWindowChanged() }` and on profiles reload, coalesced with
    `Qt.callLater(refreshCells)` (matching the core widget's dedupe).
  - `opts` for `filterWorkspaces` is read from the bar context: `screenName =
    screen?.name`, `focusedOutput` from `CompositorService`, and
    `globalWorkspaces`/`followFocusedScreen`/`hideUnoccupied` from the widget/Settings
    (defaults: `followFocusedScreen=false`, `hideUnoccupied=false`,
    `globalWorkspaces=CompositorService.globalWorkspaces`). `filterWorkspaces`
    lowercases `screenName`, `focusedOutput`, and each `ws.output` internally before
    comparing, so mixed-case output names such as `DP-1` do not disappear.
  - Each cell renders per the **Rendering** section; click →
    `CompositorService.switchToWorkspace(ws)` (the snapshot keeps each cell's `idx`
    so the matching live workspace can be passed); hover → tooltip with the label.
  - Theme fallbacks: a cell with `ring === null` uses neutral `Color` tokens; a
    profiled cell uses its `ring` hex directly, with the focused pill's foreground
    from `logic.pickForeground(cell.ring)`.

- **`logic.js`** — pure classic-QML-JS library (`.pragma library` + top-level
  `function` declarations, **no** `export`), node-tested via the `node:vm` loader
  pattern established in Phase 2's `menu-logic.js`. Holds all non-trivial logic:
  - `parseProfiles(text) -> {profiles, error}` — parses the JSON view model and
    validates that it is an array of objects with string `id`, `label`, and valid
    hex `ring` fields. Empty, malformed, non-array, wrong-shaped, or invalid-ring
    input returns `{profiles: [], error: <string>}`. Valid input returns
    `{profiles, error: null}`.
  - `resolveProfile(name, profiles) -> profile | null`
    - exact `id` match first;
    - else strip a single trailing `-<digits>` from `name` and match (so instance
      slots `tide-2`/`tide-3` resolve to `tide`). Unambiguous because the Phase 1
      `id` grammar forbids ids ending in `-<digits>`.
    - no match → `null`.
  - `filterWorkspaces(workspaces, opts) -> Array` — replicates noctalia's core
    Workspace filtering so replacing that widget is not a multi-monitor regression.
    `opts = { screenName, focusedOutput, globalWorkspaces, followFocusedScreen,
    hideUnoccupied }`. For each ws keep it when
    `globalWorkspaces || (followFocusedScreen && output === focusedOutput) ||
    (!followFocusedScreen && output === screenName)`, where `output`, `screenName`,
    and `focusedOutput` are all normalized to lowercase strings inside the function.
    Then drop it when `hideUnoccupied && !ws.isOccupied && !ws.isFocused`. Order
    preserved. (Mirrors Workspace.qml:343–347, with explicit normalization.)
  - `buildCells(workspaces, profiles) -> Array<cell>` where each `cell` is
    `{ id, idx, name, output, hasProfile, ring|null, glyph, label, isFocused, isOccupied, isUrgent }`,
    in `workspaces` order (caller passes the already-`filterWorkspaces`'d list).
    `ring`/`label` come from the resolved profile. **Profiled `glyph`** is the
    profile `icon` when non-empty, else the first character of `label` (so empty-icon
    catalogs — the current state — still render a visible cell). **Unprofiled
    cells** have `hasProfile=false`, `ring=null`, `label=name`, and `glyph =
    String(idx)` when `idx` is present, else `'.'`; QML renders that glyph with
    neutral theme tokens. Pure: never references `Color`/`Style`; the QML maps
    `ring===null` to a neutral theme token.
  - `pickForeground(ring) -> '#000000' | '#ffffff'` — deterministic readable
    foreground for the focused pill: parse the `#rgb`/`#rrggbb` hex, compute relative
    luminance, compare black and white contrast ratios, and return the higher
    contrast foreground. Invalid or missing `ring` → `'#ffffff'`. (Self-contained
    and node-testable, rather than coupling to noctalia's internal
    `ColorsConvert.generateOnColor`.)

### Bar swap (one-time, manual)

`plugin:niri-workspace-profiles` replaces noctalia's core `Workspace` widget on
horizontal bars. Bar layout lives in `~/.config/noctalia/settings.json`
(`bar.widgets.{left,center,right}`), which is **not** tracked in the dotfiles repo,
so this is a documented one-time step, not a scripted change: enable the plugin in
noctalia → place its widget where `Workspace` sat on a horizontal bar (typically
`center`) → remove the core `Workspace` entry for that horizontal bar. Keep the
core `Workspace` widget on left/right vertical bars in v1.

## Rendering

A horizontal row of cells in niri workspace order (`idx`), each sized to the bar
capsule height (`Style.getCapsuleHeightForScreen(screenName)`):

- **Profiled, not focused:** the cell's **`glyph`** (profile `icon`, or the first
  label character when the icon is empty — the current catalog state) drawn in the
  profile's **ring color**, transparent background. `isOccupied === false` dims the
  glyph (reduced opacity); occupied is full strength.
- **Profiled, focused:** a **filled pill in the ring color** containing the **glyph +
  `label`**, with foreground from `logic.pickForeground(ring)` (black on light rings,
  white on dark) so the text stays legible on any catalog color. This is the only
  cell that shows a label. Hover must preserve the focused pill's ring background
  and readable foreground; hover styling only changes non-focused cells. The focused
  label is capped and elided so long profile labels cannot consume the whole bar.
- **Unprofiled** (no `resolveProfile` match — e.g. `scratchpad`): a **neutral** cell
  using `Color` tokens — `cell.glyph`, which is the `idx` number or `.` when `idx`
  is absent, in `Color.mOnSurface`; focused unprofiled = a neutral filled pill with
  that same glyph. Kept visible for navigation.
- **Urgent** (`isUrgent`): subtle highlight using `Color.mError`.
- Color treatment is **focused-pill + colored-icons**: only the focused cell is a
  filled ring-color pill; other profiled cells carry color via their icon only.

## Data flow

- **catalog edit** → daemon rewrites `wsprofiles.json` (Phase 1) → plugin
  `FileView.onFileChanged` reloads → `profiles` updates → cells recompute.
- **workspace focus / occupancy change** (any source: `Mod+P`, keyboard, click) →
  `CompositorService` signals → `Qt.callLater(refreshCells)` →
  `filterWorkspaces` + `buildCells` → `cells` updates → strip re-renders; the daemon
  separately applies the theme on focus.
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

- `parseProfiles(text)`:
  - valid array of objects with `id`/`label`/`ring` returns profiles and `error=null`
  - empty string, malformed JSON, non-array JSON, and wrong-shaped entries return
    `profiles=[]` and a non-empty `error`
  - invalid `ring` color strings return `profiles=[]` and a non-empty `error`
- `resolveProfile(name, profiles)`:
  - exact id match returns that profile (`'ember'` → ember)
  - instance slot strips the suffix (`'tide-2'` → tide, `'tide-3'` → tide)
  - an id that itself contains digits but does not end in `-<digits>` still matches
    exactly and is not mis-stripped (`'api'` with a profile `api`)
  - unknown name → `null` (`'scratchpad'` → null)
- `filterWorkspaces(workspaces, opts)`:
  - `globalWorkspaces=true` keeps workspaces from every output
  - `followFocusedScreen=false` keeps only `ws.output === screenName`
  - `followFocusedScreen=true` keeps only `ws.output === focusedOutput`
  - mixed-case values (`screenName='DP-1'`, `ws.output='dp-1'`) still match because
    normalization happens inside `filterWorkspaces`
  - `hideUnoccupied=true` drops empty workspaces but keeps the focused one even if
    empty; `hideUnoccupied=false` keeps all
  - order is preserved
- `buildCells(workspaces, profiles)`:
  - maps each workspace in order to `{hasProfile, ring, glyph, label, isFocused, …}`
  - unprofiled workspace → `hasProfile=false`, `ring=null`, `label=name`,
    `glyph=String(idx)` (or `'.'` without an `idx`)
  - profiled workspace → `ring`/`label` from the profile
  - `glyph` = profile `icon` when non-empty; first character of `label` when the
    icon is `''` (verifies the empty-catalog fallback)
  - carries through `isFocused`, `isOccupied`, `isUrgent`, `idx`, `output`
  - empty profiles array → all cells neutral; empty workspaces → `[]`
- `pickForeground(ring)`:
  - light ring (`'#ffffff'`, `'#ff7a45'`) → `'#000000'`
  - dark ring (`'#000000'`, `'#1e1e2e'`) → `'#ffffff'`
  - middle-gray rings choose the higher-contrast foreground (`'#777777'` and
    `'#808080'` return `'#000000'`)
  - invalid/missing (`''`, `'nothex'`, `undefined`) → `'#ffffff'`

The QML reactivity bridge (`refreshCells()` + `Connections` + `Qt.callLater`) is
exercised by the manual checks, not unit tests, since it depends on noctalia's live
`CompositorService` model.

**Manual verification (running niri + noctalia v4 bar):**

1. Symlink + enable the plugin on a horizontal bar; swap its widget in for the core
   `Workspace` widget on that horizontal bar only. The strip renders one cell per
   workspace. Leave vertical left/right bars on the core `Workspace` widget in v1.
2. With the current empty-icon catalog, `ember` shows the glyph `E` in `#ff7a45`
   and `tide`/`tide-2` show `T` in `#3aa6ff` (the first-label-character fallback);
   setting a real `icon` in the catalog shows that glyph instead.
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
9. Temporarily replace `wsprofiles.json` with malformed JSON → strip degrades to
   neutral numbered cells, logs the load error, and does not crash; restoring the
   valid file restores colors.

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
