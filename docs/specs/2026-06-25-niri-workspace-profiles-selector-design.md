# Niri Workspace Profiles — Phase 2: Selector Design

## Goal

Give the workspace-profile engine (Phase 1, merged) a front-end: a `Mod+P`
popup for **picking and switching between project workspaces by their visual
identity**, and for **adding a new profile**. The popup replaces the hand-
maintained `Super+Alt+N` binds with a dynamic, catalog-driven menu.

This builds directly on the merged Phase 1 engine: the `wsprofiled` daemon, its
`wsprofilectl` control client, the `profiles.yaml` catalog, and the generated
`profiles.kdl`. The selector adds **no new switching logic** — every selection
routes through the existing `wsprofilectl open|new <id>` path, so menu-, keyboard-,
and modifier-driven switches all share the one tested code path, and the daemon's
event-stream applies the colorscheme/wallpaper/ring cues exactly as it does today.

## Non-Goals

- No guided "new profile" form. v1 "+ new" opens `profiles.yaml` in `$EDITOR`;
  a wizard is a later phase.
- No search/filter field. Numbers + arrows cover navigation at current scale; a
  filter is a later add if the list grows long.
- No live occupancy/window-count display in the menu. The `new` (free-instance)
  logic already lives in the daemon; the menu just delegates to it.
- No ohai per-profile avatars yet (later phase). The row swatch is the v1 identity.
- No noctalia bar integration (that is Phase 3). This popup is standalone.
- No horizontal "card" layout. v1 is a vertical list.
- No compatibility/legacy layers.

## Architecture

```
   profiles.yaml (catalog) ──edited──┐
                                      v
                          ┌────────────────────────┐
                          │   wsprofiled (Phase 1)  │
                          │   + emits view model    │
                          └───┬─────────────────┬───┘
              generates KDL   │                 │  generates view model
                              v                 v
                     profiles.kdl        ~/.config/niri/wsprofiles.json
                  (per-ws ring/border)   [{id,label,icon,ring,border,instances}]
                                                 │ read reactively (FileView)
                                                 v
   Mod+P ──ipc call menu toggle──>  ┌────────────────────────────┐
                                    │   wsprofile-menu (qs)       │
                                    │   resident, hidden default  │
                                    │   vertical list popup       │
                                    └─────────────┬──────────────┘
                                                  │ spawn on select
                                                  v
                                    wsprofilectl open|new <id>  (Phase 1)
                                                  │
                                                  v
                                    wsprofiled focuses workspace ─► event-stream
                                    ─► colorscheme + wallpaper + niri ring apply
```

### Single switching path

The selector is a **view + launcher**, not a second switching engine. It renders
the catalog and, on a pick, spawns `wsprofilectl`:

- direct number key / `Enter` on highlight → `wsprofilectl open <id>`
- `Shift`+number / `Shift+Enter` → `wsprofilectl new <id>`

`wsprofilectl` talks to the daemon's existing control socket; the daemon focuses
the predeclared named workspace (`open`) or the next free instance slot (`new`),
and its event-stream listener applies the cues. The popup never touches niri,
noctalia, or the socket protocol directly.

## Components

### Daemon view-model emitter (`wsprofiled`)

The daemon already regenerates `profiles.kdl` and reloads niri at startup and on
every catalog edit (`watchFile`). On that **same path**, it additionally writes a
machine-readable view model:

`~/.config/niri/wsprofiles.json`

```json
[
  { "id": "ember", "label": "Ember — client-api", "icon": "", "ring": "#ff7a45", "border": "#ff7a45", "instances": 1 },
  { "id": "tide",  "label": "Tide — infra",       "icon": "", "ring": "#3aa6ff", "border": null,      "instances": 2 }
]
```

- Order matches catalog order (defines the stable 1..N numbering).
- This is the **single source** the popup reads. QML has no YAML parser;
  `JSON.parse` is trivial. The daemon already owns "regenerate artifacts on
  catalog change," so this is one additive write — no new control-socket verb and
  no YAML parsing in QML.
- A pure function `viewModel(catalog)` produces the object (mirroring the existing
  `generateKdl(catalog)`), so it is unit-testable with `node:test`.
- The write happens wherever `generateKdl` output is written today (startup +
  `reloadCatalog`). The KDL and the JSON form **one artifact transaction**: both
  are written from the next catalog, and if `loadConfig()` fails, **both** are
  restored to their previous on-disk contents and the daemon's in-memory catalog is
  **not** swapped — so the JSON never gets ahead of the KDL niri actually accepted.
  This mirrors the Phase 1 KDL-only revert; the JSON is captured (`prevJson`) and
  restored on the same failure branch.
  - **Startup failure** (initial `loadConfig()` rejects): if a previous
    `wsprofiles.json` exists it is restored to that content (matching the existing
    `prevKdl` restore), then the daemon exits non-zero as today. If none existed,
    the freshly written JSON is removed so a stale/never-accepted file is not left
    behind for the menu to read.

### Selector (`wsprofile-menu`, Quickshell)

A standalone Quickshell config at `~/d/dotfiles/wsprofiles/menu/`, symlinked into
`~/.config/quickshell/wsprofile-menu/` — the same dotfiles pattern noctalia/ohai
use. It is a **resident process** started at niri startup, hidden by default,
exposing an IPC handler so `qs -c wsprofile-menu ipc call menu toggle` shows/hides
it (identical pattern to the existing noctalia `launcher toggle` bind).

Responsibilities:

- On show: read `wsprofiles.json` via a `FileView` and render the vertical list,
  then take keyboard focus. On hide: release focus.
  - **Reactivity is not automatic.** `FileView.watchChanges` defaults to `false`,
    so the contract is explicit:
    ```qml
    FileView {
      id: catalogView
      path: "/home/<user>/.config/niri/wsprofiles.json"
      blockLoading: true        // so JSON.parse(text()) sees loaded content
      watchChanges: true        // default is false — required for live reflect
      onFileChanged: this.reload()
    }
    ```
    The model is `JSON.parse(catalogView.text())`, recomputed on `reload()`. Without
    `watchChanges: true` + the `onFileChanged` reload, a saved catalog would not
    appear until the menu restarted (manual step 6 would fail).
  - **Keyboard focus** uses the exact Wayland API, not prose:
    `WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand`. The `OnDemand` docs
    warn it can, on some systems, retain focus over another window unexpectedly; if
    that happens the fallback is `WlrKeyboardFocus.None` with focus handed back
    explicitly. Manual step 7 verifies focus returns to the underlying window after
    hide.
- Render one row per profile: ring-color **swatch**, **number** (catalog position,
  1..N), nerd-font **icon**, **label**. A muted `+ new profile…` row last.
- Highlighted row (arrow/Tab target) gets a raised background and a left **accent
  bar in the ring color**, so browsing previews each project's color.
- Handle keys (see Interaction), spawn `wsprofilectl` for switches, spawn the
  editor for "+ new", then hide.

### Interaction logic (`menu-logic.js`)

The key→action mapping is a **pure module** that QML imports (Quickshell supports
`.js` imports), keeping the testable logic out of QML:

The **input contract is normalized**, so QML-specific key constants never leak
into the logic and unit tests exercise the same values the QML adapter produces:

```
key       : '1'..'9' | 'Enter' | 'Escape' | 'Up' | 'Down' | 'Tab' | '+'
modifiers : { shift: boolean }            // only shift is significant in v1
state     : { profiles, highlight }       // highlight: 0..N-1, or N for "+ new"
```

A thin QML key-event adapter maps Qt's `event.key`/`event.text`/`event.modifiers`
to this normalized `(key, modifiers)` shape before calling `keyToAction`
(`Qt.Key_Return`/`Qt.Key_Enter → 'Enter'`, `Qt.Key_Escape → 'Escape'`,
`Qt.Key_Up/Down`, `Qt.Key_Tab`/`Qt.Key_Backtab → 'Tab'` with `shift`,
`event.text` `'1'..'9'`/`'+'`). The adapter is the one piece confirmed by manual
testing; everything below it is unit-tested.

```
keyToAction(key, modifiers, state) -> action
  and action is one of:
    { type: 'open',   id }          // digit 1..9, or Enter on a profile row
    { type: 'new',    id }          // Shift+digit, or Shift+Enter on a profile row
    { type: 'move',   highlight }   // Up/Down/Tab/Shift+Tab -> new highlight index
    { type: 'editor' }              // '+' key, or Enter on the "+ new" row
    { type: 'hide' }                // Escape
    null                            // unhandled
```

- Digits beyond the profile count, or digit `0`, return `null` (no-op).
- Only the first 9 profiles get digit hotkeys; the rest are reachable via arrows.
- `move` wraps at the ends and includes the `+ new` row as the last stop.

QML calls `keyToAction` on each key event and dispatches the returned action:
`open`/`new` → `Process` running `wsprofilectl <verb> <id>` then hide; `move` →
update highlight; `editor` → spawn editor then hide; `hide` → hide.

### niri wiring (`config.kdl`)

```kdl
spawn-at-startup "qs" "-c" "wsprofile-menu"

binds {
    Mod+P repeat=false { spawn "qs" "-c" "wsprofile-menu" "ipc" "call" "menu" "toggle"; }
}
```

The existing `Super+Alt+1`/`Super+Alt+2` named-slot binds may stay as direct-jump
shortcuts; the popup supplements rather than replaces them.

## The "+ new profile" flow (v1)

Selecting `+ new profile…` (or pressing `+`) spawns the editor on the catalog —
`kitty` running `$EDITOR ~/d/dotfiles/wsprofiles/profiles.yaml` (falling back to a
sane default editor if `$EDITOR` is unset) — and hides the popup. The user edits
and saves; the daemon's existing `watchFile` regenerates `profiles.kdl` +
`wsprofiles.json` and reloads niri, and the menu's `FileView` picks up the new JSON
on its next show. No guided form in v1.

## Data flow

- **catalog edit** → daemon regenerates `profiles.kdl` + `wsprofiles.json` + niri
  reload → popup `FileView` updates automatically.
- **Mod+P** → `menu toggle` → popup reads JSON, shows, grabs keys.
- **pick** → `wsprofilectl open|new <id>` → daemon focuses workspace →
  event-stream → theme + niri ring apply (unchanged Phase 1 path) → popup hides.
- **+ new** → spawn `$EDITOR` on `profiles.yaml`, hide → save → daemon watch
  regenerates + reloads.

## Error handling

- `wsprofiles.json` missing or unparseable → popup renders an empty/error state
  ("No profiles — is wsprofiled running?") instead of crashing. Selecting nothing
  but `+ new` / `Esc` remains possible.
- `wsprofilectl` action fails (daemon down, unknown id) → it exits nonzero; the
  popup logs to stderr and hides. Fire-and-forget; the menu does not block on the
  reply.
- Toggling while shown hides; toggling while hidden shows. No stacking.

## Testing

**Unit (node:test), following the Phase 1 pattern:**

- `viewModel(catalog)`:
  - maps id/label/icon/ring/instances in catalog order
  - emits `border: null` when a profile omits `border`, and the hex when present
  - empty catalog → `[]`

- **Artifact transaction** (the KDL+JSON write/rollback seam, tested with a faked
  `loadConfig` and a temp dir so no real niri is needed):
  - success path: a catalog edit writes both `profiles.kdl` and `wsprofiles.json`
    from the next catalog, and the in-memory catalog is swapped
  - rollback path: previous KDL + previous JSON exist, the next catalog is written
    to both files, `loadConfig()` rejects → **both** files are restored to their
    previous contents and the in-memory catalog is **not** swapped
  - startup with no previous JSON: `loadConfig()` rejects → the freshly written
    `wsprofiles.json` is removed (no stale file left behind)
  - startup with a previous JSON: `loadConfig()` rejects → the previous JSON
    content is restored
- `keyToAction(key, modifiers, state)`:
  - digit `1` with N≥1 profiles → `{type:'open', id:<profiles[0].id>}`
  - `Shift`+digit `1` → `{type:'new', id:<profiles[0].id>}`
  - digit beyond profile count → `null`; digit `0` → `null`
  - `Enter` on a profile-row highlight → `open`; `Shift+Enter` → `new`
  - `Enter`/`+` on the `+ new` row → `{type:'editor'}`; `+` from any state → `editor`
  - `Down`/`Tab` advances highlight, wrapping past the `+ new` row to the top
  - `Up`/`Shift+Tab` moves back, wrapping
  - `Escape` → `{type:'hide'}`
  - unmapped key → `null`

**Manual verification (running niri + noctalia v4 session):**

1. Start the menu resident; press `Mod+P` — popup appears centered, lists `ember`
   and `tide` with correct swatches/numbers/labels and a `+ new` row.
2. Press `2` — popup hides, focus moves to `tide`, shell recolors to its theme,
   niri ring shows `tide`'s color.
3. Press `Mod+P`, `Shift+2` — focus moves to a free `tide` instance (`tide-2`).
4. Press `Mod+P`, arrow down through rows — highlight + accent bar track the ring
   color of each row; wrap includes `+ new`.
5. On the highlighted profile, press `Enter` — switches as the number would.
6. Press `Mod+P`, `+` — editor opens on `profiles.yaml`; add a third profile, save;
   reopen the popup and confirm the new row appears with its swatch (no menu
   restart).
7. Press `Mod+P`, `Esc` — popup hides, focus unchanged.
8. Toggle `Mod+P` twice quickly — show then hide, no stacking.
9. Kill `wsprofiled`, press a number — `wsprofilectl` fails, popup hides without
   crashing (stderr logs the error).
10. Temporarily rename or corrupt `~/.config/niri/wsprofiles.json`, press `Mod+P` —
    popup shows the empty/error state ("No profiles — is wsprofiled running?") and
    `+ new` / `Esc` still work; restore the file and confirm rows return.

## Risks

1. `WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand` is documented to
   sometimes retain focus over another window on some systems. Manual step 7
   confirms focus returns after hide; the fallback is `WlrKeyboardFocus.None` with
   focus handed back explicitly.
2. A resident `qs -c wsprofile-menu` process started from `spawn-at-startup`
   coexists cleanly with the resident noctalia shell — confirm no IPC name clash
   (distinct `-c` config name isolates it).
3. `FileView` reactivity requires `watchChanges: true` + `onFileChanged: reload()`
   (default is no watching); manual step 6 confirms a saved catalog reflects without
   a menu restart.

## Out of scope (later phases)

- Phase 3 — friendly label + colored icon in the noctalia bar.
- Guided profile creator (replacing raw-YAML "+ new").
- ohai per-profile avatars; the polished native noctalia panel.
- Search/filter field; horizontal card layout.
