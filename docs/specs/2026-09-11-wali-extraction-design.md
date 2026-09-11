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
- `check`: `just --fmt --check`, `uv run ruff check`, `zsh -n` over the zsh
  files, `tasks check`. ruff and pyright are run once at extraction; a tool
  that reports findings on the inherited code is left out of `check` and its
  findings filed as a `wali` task, since behaviour changes are out of scope.
  pyright is not added either way: dotfiles never ran it, so its state is
  unknown.
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
- `tests/wali.zsh` gains the `plugin.toml` manifest assertions (id, plugin_api,
  dependencies, widget and panel entries) that `tests/setup_and_health.zsh`
  makes today; they are the plugin's contract with Noctalia, not dotfiles'.

The 2026-09-07 redesign spec and plan **stay in dotfiles**: eighteen task
records there (`dots-59c279`'s subtree) carry them as `spec:`/`plan:` paths and
`tasks check` validates those. The wali README links to them as the design
record; wali's own docs start with the switcher doc.

## What dotfiles keeps

| Item | Change |
|---|---|
| `wali/<host>/config.toml` | Unchanged. Per-host config, linked to `$XDG_CONFIG_HOME/wali/config.toml` by setup.sh as today. |
| `bin/walictl` | Becomes a wrapper: `exec "$HOME/d/wali/bin/walictl" "$@"`, modelled on `bin/prism`. |
| `setup.sh` | `WALI_ROOT="${HOME}/d/wali"` beside `PRISM_ROOT`. `setup_noctalia_plugins` links `${WALI_ROOT}/integrations/noctalia-plugin`; the systemd phase links `${WALI_ROOT}/systemd/wali-rotate.{service,timer}`. Preflight reports `${WALI_ROOT}/bin/walictl` with the clone command as its fix — advisory, like every preflight finding (only `--check` turns findings into an exit code). The hard gate is `ln_s`: it exits 1 when a link source is missing, so the systemd and Noctalia-plugin phases stop on a missing checkout whether or not preflight ran, including under phase selection. The shim itself has no gate, exactly like `bin/prism`: a missing checkout surfaces as `exec` failing at call time. |
| `bin/dotfiles-health` | Plugin link check expects `${HOME}/d/wali/integrations/noctalia-plugin`; systemd link checks expect `${HOME}/d/wali/systemd/…`. A new `check_link` on `${XDG_CONFIG_HOME}/systemd/user/timers.target.wants/wali-rotate.timer` expects the same unit source: `systemctl --user enable` writes that link with the unit's resolved path, so `is-enabled` keeps reporting success after the source moves while the link points at a deleted file. Plugin-enabled and timer-schedule checks unchanged. |
| `zshrc` | `wali` leaves `shell_fragments`; after the loop, `[[ -r "${HOME}/d/wali/shell/wali.zsh" ]] && source "${HOME}/d/wali/shell/wali.zsh"`. |
| `bin/dotfiles-check` | `shell/wali` and `tests/wali.zsh` leave the zsh file list. |
| `justfile` | `test` drops `zsh tests/wali.zsh`, the `lua` guard, and the `lua … plugin_test.lua` line. |
| `pyproject.toml` | Renamed `dotfiles`; `bin/walictl` and `tests/bin/test_walictl.py` leave pyright/ruff includes. Other pytest suites still use it, so it stays. `uv.lock` regenerated. |
| `tests/setup_and_health.zsh` | The `run_setup` harness gains a wali fixture beside the prism one: `${tmp}/home/d/wali/integrations/noctalia-plugin/plugin.toml`, `${tmp}/home/d/wali/systemd/wali-rotate.{service,timer}`, and an executable `${tmp}/home/d/wali/bin/walictl` stub. Link-target assertions retarget to `${tmp}/home/d/wali/…`; the wrong-link tests keep working against the fixture. `test_active_noctalia_code_has_no_v4_ipc` and its scan-error twin drop `bin/walictl` and `shell/wali`. The plugin.toml manifest assertions move to wali's `tests/wali.zsh` (above); the `noctalia/config.toml` assertions (widget list, `wallpaper_changed` hook) stay. |
| `tests/justfile.zsh` | Assertions that the `test` recipe includes the wali and lua lines are removed; the ordering assertion goes with them. |
| `tests/dotfiles_check.zsh` | `shell/wali` leaves its expected file list. |
| `niri/config.kdl`, `noctalia/config.toml`, `cheatsheets/niri` | Unchanged. |
| `noctalia/noctalia.md`, `docs/plans/2026-08-19-noctalia-v5-migration.md`, `docs/specs/2026-08-20-noctalia-v5-plugin-ports-design.md` | References to `noctalia/plugins/wali-panel` and `noctalia/noctalia-wallpaper-switcher.md` that describe the live layout are updated to the new location. Historical narrative is left alone. |

Removed from dotfiles: `bin/walictl` (content), `shell/wali`,
`noctalia/plugins/wali-panel/`, `systemd/user/wali-rotate.{service,timer}`,
`tests/bin/test_walictl.py`, `tests/wali.zsh`,
`noctalia/noctalia-wallpaper-switcher.md`. `noctalia/plugins/` and `/docs/*`
are gitignored and these files were force-added, so the removal is an explicit
`git rm`, not a sweep.

With the fixture, `just check test` in dotfiles does not need a real `~/d/wali`;
only `dotfiles-health` on a live machine does.

## Task migration

Inventory of what references wallpaper work in dots today:

- `dots-59c279`, the redesign goal: 17 children under `--plan
  docs/plans/2026-09-07-wallpaper-management-redesign.md`, 16 done and
  `dots-fa9cc0` (Task 17, cutover) still `doing`. `tasks drop` refuses a goal
  with an open descendant, and the 18 records pin the plan path.
- `dots-cdb659` (idea, mind6 integration) depends on `dots-59c279`.
- `dots-2aa60c` (idea) depends on `dots-59c279`; `dots-b9ba7c` (idea) depends
  on the done `dots-ba0168`.
- `dots-5760ef`, `dots-9bfdc0`, `dots-b3e5ae`: no relations.

**The redesign goal and its subtree stay in dots.** It is the record of work
done in dotfiles, its docs stay there, and it closes there when `fa9cc0` does.
`dots-cdb659` stays too: it is mind6-facing and keeps its dependency.

**Five forward-looking tasks move.** `tasks` has no cross-project move, so for
each of `dots-5760ef`, `dots-9bfdc0`, `dots-b9ba7c`, `dots-2aa60c`,
`dots-b3e5ae`:

1. `tasks add "<title>" --project wali --source dots-<id>` with the same
   status, priority, size, tags, and body.
2. `tasks note wali-<new> "moved from dots-<id>"` and
   `tasks drop dots-<id> "moved to wali-<new>"`.

Then:

- `tasks dep wali-<2aa60c'> --on dots-59c279`: the cross-project form keeps the
  ordering it had.
- `dots-b9ba7c`'s dependency on `dots-ba0168` is not carried over: `ba0168` is done.
- `tasks feedback "no way to move a task between registered projects" --category gap`.

`dots-3a1770` is scoped from `idea` to `todo` (P2, size l) with this spec
attached, and closes when the dotfiles change merges.

## Order of operations

The dotfiles tree is live on titan and europa and `~/bin` is `dotfiles/bin`,
so no intermediate state may leave walictl, the timer, or the panel broken.

Today's live links on titan resolve into the dotfiles tree
(`~/d/dotfiles/noctalia/plugins/wali-panel`,
`~/d/dotfiles/systemd/user/wali-rotate.*`), and europa's do the same. Deleting
the originals in the commit that retargets setup.sh would dangle those links on
both hosts until setup.sh reruns — and on europa Dropbox may deliver the
dotfiles change before `~/d/wali` has finished syncing. So the dotfiles side
lands in **two merges** — retarget, then removal — and the originals are
deleted only after both hosts are verified on the new targets.

1. **wali repo lands and syncs.** Legacy branch and tag; replacement commit
   with the full layout above; `just setup && just verify` green on titan.
   Confirm on europa that `~/d/wali/bin/walictl` and
   `~/d/wali/integrations/noctalia-plugin/plugin.toml` have arrived. dotfiles
   still holds its own copies; nothing running is affected.
2. **dotfiles retarget merge** (`wali-migration` worktree, several commits): the shim,
   `WALI_ROOT`, setup.sh/health/test retargets, zshrc sourcing, the moved
   manifest assertions, and the justfile/pyproject/dotfiles-check trims. The
   files live consumers still link to stay in place
   (`noctalia/plugins/wali-panel/`, `systemd/user/wali-rotate.*`,
   `shell/wali`). The two test suites go in this commit, not the removal one:
   pytest has no `testpaths` and would discover `tests/bin/test_walictl.py`,
   whose `SourceFileLoader` would import the bash shim as Python; `tests/wali.zsh`
   likewise leaves with its justfile line. `just check test` green in the
   worktree.
3. **Cut over titan:** ff-merge into `main` from the main checkout; run
   `setup.sh --enable-user-timers` for the graphical-config, systemd, and
   Noctalia-plugin phases. `ln_s` replaces the three symlinks (each currently
   points elsewhere, so none is skipped), and `--enable-user-timers` is what
   makes the systemd phase run `daemon-reload` and `enable --now`: `enable`
   rewrites `timers.target.wants/wali-rotate.timer`, a fourth link that today
   points directly at the dotfiles unit and that the phase's `ln_s` calls do
   not touch. Without the flag the timer would keep firing from a link into
   the soon-deleted file. `noctalia msg plugins enable` is idempotent on an
   already-enabled id. `dotfiles-health` green on `main`, including the new
   wants-link check.
4. **Cut over europa:** once Dropbox has delivered both trees, run the same
   `setup.sh --enable-user-timers` phases and `dotfiles-health` there. On
   both hosts, `readlink` of the plugin link, the two unit links, and the
   wants link now resolve into `~/d/wali`; nothing resolves into
   `dotfiles/noctalia/plugins/wali-panel` or
   `dotfiles/systemd/user/wali-rotate.*` any more.
5. **dotfiles removal merge:** `git rm` the originals; `just check test`
   green; ff-merge; `dotfiles-health` green on titan. europa needs no action —
   nothing it links to is touched.
6. **Tasks last**, once both repos are on `main`.

## Verification

- wali: `just verify` — pytest, `tests/wali.zsh`, `plugin_test.lua`, ruff,
  pyright, `tasks check`.
- dotfiles: `just check test` in the worktree — not `just verify`, whose
  `health` recipe derives `DOTS_HOME` from the executing checkout and would
  compare live links (which point into `main`) against the worktree.
  `just health` runs on `main` after each cutover step.
- Live: `walictl current --json` through the shim; `systemctl --user
  list-timers wali-rotate.timer` and `readlink
  ~/.config/systemd/user/timers.target.wants/wali-rotate.timer` into
  `~/d/wali` (`is-enabled` alone cannot tell a stale wants link from a fresh
  one); `noctalia msg plugins list` shows
  `khughitt/wali-panel … enabled`; `Super+N` opens the panel; a new zsh has
  `wali_ingest` defined.
- `bin/dotfiles-layout-check` passes: the shim is a file, not a symlink, so no
  absolute target enters git.

## Out of scope

- Any behaviour change to walictl, the panel, or the shell helpers (those are
  the moved tasks' business).
- The old CLI's macOS port: parked on `legacy-click-cli`.
- Publishing walictl as an installable package.
