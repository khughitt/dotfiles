# Niri Workspace Profiles Design

## Goal

Give each niri workspace its own visual identity ("feel") so that switching
between project workspaces is instantly orienting. Each project workspace adopts
a named **profile** that carries a coordinated set of visual cues:

- A per-workspace **focus-ring / border color**, drawn by niri itself.
- A **noctalia colorscheme** that the whole shell switches to on focus.
- A **wallpaper** that switches with it (and can drive the colorscheme).
- A **name + icon** shown in the noctalia bar.

A single declarative catalog (`profiles.yaml`) is the source of truth. A small
daemon applies a profile's feel whenever its workspace gains focus. A standalone
`mod-p` menu is a front-end for picking and assigning profiles.

This targets the **native (C++) noctalia rewrite** (`noctalia-origin`), which the
user is migrating to. It is designed to be built and tested after that migration.

## Non-Goals

- Do not target the current Quickshell/QML noctalia. Native only.
- Do not build the polished native noctalia "profile switcher" panel from the
  long-term vignette. The v1 selector is a standalone layer-shell menu.
- Do not integrate ohai per-profile avatars yet (later phase).
- Do not add per-monitor differing colorschemes. noctalia's colorscheme and
  wallpaper are global to the shell; only the focused profile's palette shows.
- Do not reload niri config on every focus switch. Config regeneration happens
  only when the catalog changes.
- Do not add compatibility/legacy layers.

## Architecture

```
                  +-------------------------+
                  |  profiles.yaml (catalog)|  <- user edits this
                  |  id, label, ring color, |
                  |  palette/wallpaper, icon|
                  +-----------+-------------+
                              | watched
                              v
   niri --event-stream-->  +------------------+  --noctalia msg-->  noctalia
  (WorkspaceActivated,     |   wsprofiled     |   color-scheme-set,  (recolor +
   name=ember-2)           |   (Node daemon)  |   wallpaper-set       wallpaper)
                           +-------+----------+
        ^                          | generates
        | focus-workspace          v
        |                  +------------------+
   +----+------+           | profiles.kdl     |  included by niri config ->
   | mod-p menu|           | workspace "ember"|  per-workspace ring/border color
   | (fuzzel/  |           | { ring color }   |
   |  qs popup)|           +------------------+
   +-----------+
```

### Two cue layers

- **Persistent (niri-native):** ring/border color per named workspace, from the
  generated KDL include. Visible side-by-side and in the overview, with no daemon
  involvement once generated.
- **Follow-focus (daemon-driven):** colorscheme + wallpaper switch globally to the
  focused workspace's profile. In v1 the bar shows the raw niri workspace name
  (the profile `id`, e.g. `ember`); rendering the friendly `label` and a colored
  icon is the isolated Phase 3.

### Naming and selection model

A profile's `id` **is** the name of its durable **primary** workspace (`ember`).
Selecting a profile is **focus-or-create**: the daemon focuses that named
workspace (`niri msg action focus-workspace "ember"`), which niri creates on
demand if it does not yet exist. Because selection is by name, it never depends
on numeric workspace position or declaration order after a config reload.

Profiles remain reusable styles. A profile may declare `instances:` > 1, and a
separate explicit **"open another instance"** action allocates the next free
extra slot (`ember-2`, `ember-3`, ...), all sharing the profile's colors. "Free"
means a generated slot of that profile that currently holds **no windows**,
computed from `Window.workspace_id` (window events) -- not from
`WorkspacesChanged`, which only exposes the single focused window per workspace.

The daemon pre-generates `instances` named slots per profile in the KDL include.
This keeps the common path **reload-free**: niri only reloads config when a
profile is added or edited in the catalog, never on a focus switch.

### Key tradeoff

noctalia's colorscheme/wallpaper are global to the shell. On multi-monitor only
the focused profile's palette shows everywhere; two differently-colored
workspaces cannot be lit at once. The niri ring/border color *is* per-workspace,
so that layer still differentiates them visually. Accepted.

## Components

### Catalog (`~/d/dotfiles/wsprofiles/profiles.yaml`, symlinked to `~/.config`)

```yaml
profiles:
  - id: ember                       # also the base niri workspace name
    label: "Ember - client-api"     # selector text now; bar label in Phase 3
    instances: 1                    # how many named slots to pre-generate
    ring:   "#ff7a45"               # niri focus-ring active-color
    border: "#ff7a45"               # optional; defaults to ring
    icon:   ""                     # nerd-font glyph for the bar
    theme:
      source: wallpaper             # wallpaper | builtin | custom
      wallpaper: ~/Pictures/Walls/ember.jpg
      scheme: m3-content            # used when source=wallpaper
      # builtin: "Catppuccin"       # used when source=builtin
      mode: dark
```

### Daemon (`wsprofiled`, Node)

Lives alongside the ohai stack (`~/d/software/ohai`) to share a runtime for the
future avatar integration. Responsibilities:

- **On start / catalog change:** regenerate `~/.config/niri/profiles.kdl` (one
  `workspace "id[-n]" { layout { ... } }` block per slot), then `niri msg action
  load-config-file`. `config.kdl` gains a single `include "./profiles.kdl"` line.
  Each block emits `focus-ring { active-color ... }` -- the ring is globally `on`
  (width 3), so this renders immediately. A profile that specifies a `border`
  color additionally emits `border { on; width N; active-color ... }`, because the
  global default is `border { off }` and an `active-color` alone would not show.
- **Subscribe** to `niri msg --json event-stream`; maintain window-to-workspace
  occupancy from window events (`Window.workspace_id`) for the instance
  allocator; on a focused `WorkspaceActivated`, resolve the workspace name to a
  profile (strip any `-n` suffix) and apply the cues:
  - `noctalia msg wallpaper-set <connector> <path>` and `color-scheme-set
    wallpaper <scheme>`; or `color-scheme-set builtin <name>` +
    `theme-mode-set <mode>` for builtin palettes.
- **Expose a control socket** (`wsprofilectl open <id>`) so the selector can
  request "a workspace of profile X."

noctalia native IPC command names come from the `noctalia-origin` C++ source and
must be verified against the installed build before wiring, since the native
shell is in active flux.

### Selector (`mod-p`)

- niri bind: `Mod+P { spawn "wsprofile-menu"; }`
- Lists profiles, each numbered, plus a "+ new" entry (fuzzel or a small
  Quickshell popup).
- Picking `N` calls `wsprofilectl open <id>`; the daemon focuses the profile's
  primary slot (`niri msg action focus-workspace "<id>"`, created on demand). A
  modifier (e.g. `Shift+N`) calls `wsprofilectl new <id>` to allocate the next
  free extra slot instead. Either way the event-stream listener applies the cues
  on the resulting focus change, so menu-, modifier-, and keyboard-driven switches
  share one code path.
- "+ new" (v1) opens `profiles.yaml` in `$EDITOR`; the daemon's file-watch
  regenerates and reloads on save. A guided creator is a later phase.

## Phasing

- **Phase 1 - Engine:** catalog + generated KDL + daemon + focus-driven
  colorscheme/wallpaper + niri ring color. Triggered by **per-profile named-slot
  binds** (e.g. `Mod+1 { focus-workspace "ember"; }`) -- not numeric position
  binds, which do not map stably to named workspaces -- proving the full
  feel-switching loop with no new UI.
- **Phase 2 - Selector:** the `mod-p` menu (focus-or-create on tap, allocate-new
  via the `Shift` modifier + free-slot logic), and "+ new opens YAML."
- **Phase 3 - Bar identity:** the friendly `label` plus a colored profile icon in
  the noctalia bar (small Luau plugin reading daemon state), replacing the raw
  workspace name shown in v1.
- **Later (out of scope now):** ohai per-profile avatars; guided profile creator;
  the polished native noctalia panel from the vignette.

## Risks

1. Native noctalia IPC command names/behavior must be verified against the
   installed build (native shell is in flux).
2. `focus-workspace "<name>"` creating an empty named workspace on demand
   (focus-or-create) needs a quick live test to confirm.
3. The Phase 3 bar colored-icon depends on the experimental Luau plugin API,
   hence it is isolated to its own phase.
