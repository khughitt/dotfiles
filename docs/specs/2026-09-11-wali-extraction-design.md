# Extract wali from dotfiles into `khughitt/wali`

**Status:** Designed 2026-09-11; not yet implemented. Task `dots-3a1770`.

## Problem

The wallpaper system is a project of its own living inside dotfiles: a 27 KB
Python CLI (`bin/walictl`), a zsh helper fragment (`shell/wali`), a Noctalia
plugin (`noctalia/plugins/wali-panel`), two systemd units, a 46 KB pytest
suite, a zsh test suite, a Lua test, a design spec, a plan, and six open tasks.
The dotfiles root carries a `pyproject.toml` named `dotfiles-wali-tools` for it.

`khughitt/wali` already exists at `~/d/wali` as the previous generation of the
same tool: a click + sqlite switcher last committed in March 2026, with
uncommitted macOS-port work. `shell/wali`'s header already points at that URL.
walictl is its successor, not a fork of it.

`prism` shows the shape this should take: a `~/d/prism` checkout, a 5-line
`bin/prism` shim in dotfiles, setup.sh linking `~/d/prism/integrations/
noctalia-plugin` into Noctalia's plugin dir, and per-host config kept in
dotfiles under `prism/<host>/`.

## Decisions

### Target repo: reuse `khughitt/wali`

walictl replaces the old CLI on `main`. The old code is kept reachable:

1. In `~/d/wali`, commit the uncommitted macOS/desktoppr work on a new branch
   `legacy-click-cli` and tag the last old-CLI commit on `main` (`df850fc`)
   `v0.1-legacy`.
2. `main` then receives the replacement commit: `wali/` (old package),
   `docs/macos-feasibility.md`, and the old `uv.lock` are deleted;
   `pyproject.toml` and `README.md` are rewritten. History stays linear; the
   old commits remain ancestors of `main`.

Rejected: a new `walictl` repo (two wallpaper projects under one author, and
`shell/wali` would have to retarget) and keeping both CLIs on `main` (dead-on-
Linux code carried indefinitely).

### Runtime linkage: the prism pattern

dotfiles reaches the checkout through `~/d/wali`, the one layout the tree
already assumes (`bin/prism`, `bin/mindful`). `bin/walictl` in dotfiles becomes
a wrapper that execs `~/d/wali/bin/walictl`. Every other consumer keeps its
current spelling and keeps working unchanged:

- `systemd/wali-rotate.service`: `ExecStart=%h/bin/walictl next`
- `noctalia/config.toml` hook: `~/bin/walictl observe`
- `niri/config.kdl` binds: `walictl previous|next|random|favorite`
- `noctalia/config.toml` widget: `khughitt/wali-panel:widget`

Rejected: a packaged install (`uv tool install`, `[project.scripts]`). walictl
is stdlib-only, and an installed copy breaks the edit-in-checkout workflow the
Dropbox-shared tree relies on.

### History: plain copy

Files are copied into `khughitt/wali` in one commit whose message cites the
dotfiles commit they were extracted from. Their history stays in dotfiles,
one `git log --follow` away. Rejected: `git filter-repo` / subtree split.

### Tasks: a registered `wali` project

`tasks init --prefix wali` in the new repo. The wali-only tasks move there;
`dots-3a1770` (this migration) stays in dots, where the work happens.

## New repo layout

```
~/d/wali/
  bin/walictl                          ← dotfiles bin/walictl
  shell/wali.zsh                       ← dotfiles shell/wali
  integrations/noctalia-plugin/        ← dotfiles noctalia/plugins/wali-panel
    plugin.toml  logic.luau  panel.luau  shell.luau  widget.luau
    plugin_test.lua  README.md
  systemd/wali-rotate.service          ← dotfiles systemd/user/
  systemd/wali-rotate.timer
  tests/test_walictl.py                ← dotfiles tests/bin/test_walictl.py
  tests/wali.zsh                       ← dotfiles tests/wali.zsh
  tests/tmp_cleanup.zsh                ← copied from dotfiles tests/ (16-line helper wali.zsh sources)
  docs/specs/2026-09-07-wallpaper-management-redesign-design.md
  docs/plans/2026-09-07-wallpaper-management-redesign.md
  docs/noctalia-wallpaper-switcher.md  ← dotfiles noctalia/noctalia-wallpaper-switcher.md
  pyproject.toml                       (name wali; dev group only: pytest, ruff, pyright)
  uv.lock
  justfile
  tasks/.config.toml                   (prefix = "wali")
  README.md
  .gitignore                           (.venv, __pycache__, .pytest_cache)
```

The plugin id `khughitt/wali-panel` and its `plugin.toml` are unchanged, so
Noctalia's enabled-plugin state survives the move.

### justfile

- `setup`: `uv sync`, then `attr -s com.dropbox.ignored -V 1 .venv` (the
  checkout is under Dropbox; the same guard prism applies to `node_modules`).
- `test`: `uv run --frozen pytest -q`, `zsh tests/wali.zsh`,
  `lua integrations/noctalia-plugin/plugin_test.lua` (with the same
  `command -v lua` guard dotfiles uses).
- `check`: `uv run ruff check`, `uv run pyright`, `tasks check`.
- `verify`: `check test`.

### Path adjustments inside moved files

- `tests/test_walictl.py`: `SCRIPT = Path(__file__).resolve().parents[2] /
  "bin" / "walictl"` becomes `parents[1]`.
- `tests/wali.zsh`: `repo_root=${0:A:h:h}` still resolves the repo root;
  `source "${repo_root}/shell/wali"` becomes `shell/wali.zsh`. It keeps
  sourcing `${0:A:h}/tmp_cleanup.zsh`, which is copied alongside it (dotfiles
  keeps its own copy: six other suites there use it).
- `shell/wali.zsh`: no path changes; it calls `walictl` from `$PATH`, which
  resolves to the dotfiles shim.
- `pyproject.toml` `[tool.pyright] include` and `[tool.ruff] extend-include`
  list `bin/walictl` and `tests/test_walictl.py`.
- The redesign spec and plan keep their content; a one-line note under their
  status header records the move.

## What dotfiles keeps

| Item | Change |
|---|---|
| `wali/<host>/config.toml` | Unchanged. Per-host config, linked to `$XDG_CONFIG_HOME/wali/config.toml` by setup.sh as today. |
| `bin/walictl` | Becomes a wrapper: `exec "$HOME/d/wali/bin/walictl" "$@"`, modelled on `bin/prism`. |
| `setup.sh` | `WALI_ROOT="${HOME}/d/wali"` beside `PRISM_ROOT`. `setup_noctalia_plugins` links `${WALI_ROOT}/integrations/noctalia-plugin`; the systemd phase links `${WALI_ROOT}/systemd/wali-rotate.{service,timer}`. A preflight requires `${WALI_ROOT}/bin/walictl` to exist, so a machine without the checkout fails early with the clone command, as the prism node-deps preflight does. |
| `bin/dotfiles-health` | Plugin link check expects `${HOME}/d/wali/integrations/noctalia-plugin`; systemd link checks expect `${HOME}/d/wali/systemd/…`. Plugin-enabled and timer checks unchanged. |
| `zshrc` | `wali` leaves `shell_fragments`; after the loop, `[[ -r "${HOME}/d/wali/shell/wali.zsh" ]] && source "${HOME}/d/wali/shell/wali.zsh"`. |
| `bin/dotfiles-check` | `shell/wali` and `tests/wali.zsh` leave the zsh file list. |
| `justfile` | `test` drops `zsh tests/wali.zsh`, the `lua` guard, and the `lua … plugin_test.lua` line. |
| `pyproject.toml` | Renamed `dotfiles`; `bin/walictl` and `tests/bin/test_walictl.py` leave pyright/ruff includes. Other pytest suites still use it, so it stays. `uv.lock` regenerated. |
| `tests/setup_and_health.zsh` | Link-target assertions retarget to `~/d/wali/…`; `test_active_noctalia_code_has_no_v4_ipc` and its scan-error twin drop `bin/walictl` and `shell/wali` from their file lists; plugin.toml assertions read `${HOME}/d/wali/integrations/noctalia-plugin/plugin.toml`. |
| `tests/justfile.zsh` | Assertions that the `test` recipe includes the wali and lua lines are removed; the ordering assertion goes with them. |
| `tests/dotfiles_check.zsh` | `shell/wali` leaves its expected file list. |
| `niri/config.kdl`, `noctalia/config.toml`, `cheatsheets/niri` | Unchanged. |
| `noctalia/noctalia.md`, `docs/plans/2026-08-19-noctalia-v5-migration.md`, `docs/specs/2026-08-20-noctalia-v5-plugin-ports-design.md` | References to `noctalia/plugins/wali-panel` and `noctalia/noctalia-wallpaper-switcher.md` that describe the live layout are updated to the new location. Historical narrative is left alone. |

Removed from dotfiles: `bin/walictl` (content), `shell/wali`,
`noctalia/plugins/wali-panel/`, `systemd/user/wali-rotate.{service,timer}`,
`tests/bin/test_walictl.py`, `tests/wali.zsh`, the two redesign docs,
`noctalia/noctalia-wallpaper-switcher.md`.

`tests/setup_and_health.zsh` currently reads the plugin's `plugin.toml` and
copies `bin/walictl` from the repo; after the move those tests reference the
`~/d/wali` checkout. This mirrors how prism's plugin link is already checked
against `${HOME}/d/prism/…`, and it means `just test` in dotfiles requires the
wali checkout — which setup.sh's preflight already requires.

## Task migration

`tasks` has no cross-project move, so each task is re-created and the original
dropped. For each of `dots-59c279`, `dots-5760ef`, `dots-9bfdc0`,
`dots-b9ba7c`, `dots-2aa60c`, `dots-b3e5ae`:

1. `tasks add "<title>" --project wali --source dots-<id>` with the same
   status, priority, size, tags, and body.
2. `tasks note wali-<new> "moved from dots-<id>"` and
   `tasks drop dots-<id> "moved to wali-<new>"`.

Then:

- `wali-<59c279'>`: `--spec docs/specs/2026-09-07-wallpaper-management-redesign-design.md --plan docs/plans/2026-09-07-wallpaper-management-redesign.md`.
- `wali-<2aa60c'>` depends on `wali-<59c279'>` (was `dots-2aa60c → dots-59c279`).
- `dots-b9ba7c`'s dependency on `dots-ba0168` is not carried over: `ba0168` is done.
- `tasks feedback "no way to move a task between registered projects" --category gap`.

`dots-3a1770` is scoped from `idea` to `todo` (P2, size l) with this spec
attached, and closes when the dotfiles change merges.

## Order of operations

The dotfiles tree is live on titan and europa and `~/bin` is `dotfiles/bin`,
so no intermediate state may leave walictl, the timer, or the panel broken.

1. **wali repo first.** Legacy branch and tag; replacement commit with the
   full layout above; `just setup && just verify` green. dotfiles still holds
   its own copies, so nothing running is affected.
2. **dotfiles branch** (`wali-migration` worktree): shim, retargets, removals;
   `just verify` green in the worktree.
3. **Land:** ff-merge into `main` from the main checkout; run `setup.sh`'s
   graphical-config, systemd, and Noctalia-plugin phases; `dotfiles-health`
   green on titan. The `~/.local/share/noctalia/plugins/wali-panel` symlink is
   replaced by `ln_s`, and `noctalia msg plugins enable` is idempotent on an
   already-enabled id. europa picks up both trees over Dropbox and re-runs
   `setup.sh`.
4. **Tasks last**, once both repos are on `main`.

## Verification

- wali: `just verify` — pytest, `tests/wali.zsh`, `plugin_test.lua`, ruff,
  pyright, `tasks check`.
- dotfiles: `just verify` (`check test health`) in the worktree, then
  `dotfiles-health` on `main` after setup.sh.
- Live: `walictl current --json` through the shim; `systemctl --user
  list-timers wali-rotate.timer`; `noctalia msg plugins list` shows
  `khughitt/wali-panel … enabled`; `Super+N` opens the panel; a new zsh has
  `wali_ingest` defined.
- `bin/dotfiles-layout-check` passes: the shim is a file, not a symlink, so no
  absolute target enters git.

## Out of scope

- Any behaviour change to walictl, the panel, or the shell helpers (those are
  the moved tasks' business).
- The old CLI's macOS port: parked on `legacy-click-cli`.
- Publishing walictl as an installable package.
