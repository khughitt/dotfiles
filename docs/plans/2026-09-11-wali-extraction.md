# Wali Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move walictl, its shell helpers, Noctalia plugin, systemd units, and tests out of dotfiles into the existing `khughitt/wali` repo at `~/d/wali`, with dotfiles reaching them the way it reaches prism.

**Architecture:** Two repos, four landings. (1) `~/d/wali` gets the files first, on top of the old CLI's history, and passes its own `just verify`. (2) dotfiles retargets setup/health/tests at `~/d/wali` and replaces `bin/walictl` with an exec shim, leaving the originals that live symlinks still point at. (3) Each host runs `setup.sh --enable-user-timers` so every live link — including `timers.target.wants/wali-rotate.timer` — resolves into `~/d/wali`. (4) Only then are the originals removed and the tasks moved.

**Tech Stack:** bash (setup.sh, dotfiles-health), zsh test suites, Python 3.11+ stdlib (walictl) with uv/pytest, Luau (Noctalia plugin), `just`, `tasks`.

**Spec:** `docs/specs/2026-09-11-wali-extraction-design.md` — read it first; the plan argues from it.

## Global Constraints

- Two working trees: the dotfiles worktree at `.worktrees/wali-migration` (branch `wali-migration`) and the wali checkout at `~/d/wali` (`/mnt/ssd/Dropbox/wali`; `~/d` → `/mnt/ssd/Dropbox`). Every command below says which one it runs in.
- Both trees are Dropbox-shared and live on titan and europa. Never leave a state where `~/bin/walictl`, the `wali-rotate` timer, or the `khughitt/wali-panel` plugin resolves to a missing file on either host.
- Paths written into git use `~/d/wali` or `${HOME}/d/wali`, never `/mnt/ssd/Dropbox` or `/home/keith`. `bin/dotfiles-layout-check` rejects tracked symlinks with absolute targets; the shim is a file, not a link.
- In dotfiles, `docs/*` and `noctalia/plugins/` are gitignored: `git add -f` new docs, `git rm` (not a sweep) the plugin files.
- Verification in the dotfiles worktree is `just check test`, never `just verify` — `health` derives `DOTS_HOME` from the executing checkout and the live links point into `main`. `just health` runs from the main checkout after a cutover.
- No behaviour changes to walictl, `shell/wali`, or the plugin. If a lint or type check turns something up, file a `wali` task; do not fix it here.
- Conventional commits, no attribution trailers.
- Task-tracker discipline: `tasks start <id>` before a task, `tasks done <id> "<what landed>"` in the commit that lands it. Ids for the children of `dots-3a1770` are printed by `tasks tree dots-3a1770 --pretty`.

---

## Part A — the wali repo lands (`~/d/wali`)

### Task 1: Park the old CLI on a legacy branch

**Files:**
- Modify (commit, no edits): `~/d/wali/README.md`, `~/d/wali/wali/cli.py`, `~/d/wali/wali/wali.py`, `~/d/wali/docs/macos-feasibility.md`

**Interfaces:**
- Produces: branch `legacy-click-cli` holding the macOS-port WIP; tag `v0.1-legacy` on `df850fc` (the last old-CLI commit on `main`); `main` clean at `df850fc`.

- [ ] **Step 1: Confirm the starting state**

Run (in `~/d/wali`):
```bash
git -C ~/d/wali status --short
git -C ~/d/wali log --oneline -1
```
Expected: ` M README.md`, ` M wali/cli.py`, ` M wali/wali.py`, `?? docs/`, and `df850fc poetry -> uv; wayland support`. Any other state means someone else touched the repo: stop and ask.

- [ ] **Step 2: Commit the WIP on the legacy branch**

```bash
cd ~/d/wali
git switch -c legacy-click-cli
git add README.md wali/cli.py wali/wali.py docs/macos-feasibility.md
git commit -m "feat: macOS support via desktoppr and pywal16 (WIP)

Parked here when main was replaced by walictl; see the v0.1-legacy tag
for the last release of this CLI."
```

- [ ] **Step 3: Tag the last old-CLI commit and return to main**

```bash
cd ~/d/wali
git tag -a v0.1-legacy df850fc -m "Last release of the click + sqlite wali CLI, superseded by walictl"
git switch main
git status --short
```
Expected: `git status --short` prints nothing.

- [ ] **Step 4: Verify**

Run: `git -C ~/d/wali log --oneline --all --decorate | head -3`
Expected: `legacy-click-cli` one commit ahead of `main`; `(HEAD -> main, tag: v0.1-legacy)` on `df850fc`.

### Task 2: Replace main with walictl and its pytest suite

**Files:**
- Delete: `~/d/wali/wali/` (old package), `~/d/wali/uv.lock`, `~/d/wali/.pytest_cache/` (untracked)
- Create: `~/d/wali/bin/walictl` (copy of dotfiles `bin/walictl`), `~/d/wali/tests/test_walictl.py` (copy of dotfiles `tests/bin/test_walictl.py`), `~/d/wali/justfile`, `~/d/wali/uv.lock` (regenerated)
- Modify: `~/d/wali/pyproject.toml`, `~/d/wali/.gitignore`

**Interfaces:**
- Consumes: dotfiles `bin/walictl` (stdlib-only Python, `#!/usr/bin/env python3`), dotfiles `tests/bin/test_walictl.py` (`SCRIPT = Path(__file__).resolve().parents[2] / "bin" / "walictl"`).
- Produces: `~/d/wali/bin/walictl` executable at the path the dotfiles shim (Task 6) execs; `just setup`, `just test`, `just check`, `just verify` recipes that Tasks 3–5 extend.

- [ ] **Step 1: Remove the old package**

```bash
cd ~/d/wali
git rm -r -q wali uv.lock
rm -rf .pytest_cache
```

- [ ] **Step 2: Copy walictl and its tests from the dotfiles worktree**

```bash
DOTS=/mnt/ssd/Dropbox/dotfiles/.worktrees/wali-migration
cd ~/d/wali
mkdir -p bin tests
cp "$DOTS/bin/walictl" bin/walictl
cp "$DOTS/tests/bin/test_walictl.py" tests/test_walictl.py
chmod +x bin/walictl
```

- [ ] **Step 3: Fix the test's path to the script**

In `~/d/wali/tests/test_walictl.py` line 18, change:
```python
SCRIPT = Path(__file__).resolve().parents[2] / "bin" / "walictl"
```
to:
```python
SCRIPT = Path(__file__).resolve().parents[1] / "bin" / "walictl"
```

- [ ] **Step 4: Write pyproject.toml**

Replace `~/d/wali/pyproject.toml` entirely with:
```toml
[project]
name = "wali"
version = "1.0.0"
description = "Wallpaper selection, history, and favorites on top of Noctalia v5"
authors = [{ name = "Keith Hughitt" }]
license = { text = "MIT" }
readme = "README.md"
requires-python = ">=3.11"
dependencies = []

[dependency-groups]
dev = [
  "pytest>=8.0",
  "ruff>=0.11.0",
  "pyright>=1.1.0",
]

[tool.pyright]
include = [
  "bin/walictl",
  "tests/test_walictl.py",
]

[tool.ruff]
line-length = 120
respect-gitignore = false
include = ["pyproject.toml", "tests/**/*.py"]
extend-include = ["bin/walictl"]
```
`dependencies = []` is deliberate: walictl imports only the standard library (`grep -E '^(import|from) (numpy|rich|click)' bin/walictl` prints nothing). `requires-python >= 3.11` is for `tomllib`.

- [ ] **Step 5: Write .gitignore**

Replace `~/d/wali/.gitignore` with:
```
__pycache__/
.pytest_cache/
.venv/
.ruff_cache/
```

- [ ] **Step 6: Write the justfile**

Create `~/d/wali/justfile`:
```just
set dotenv-load := false

default:
    @just --list

# Install the dev venv and keep it out of Dropbox: the checkout is under ~/d.
setup:
    uv sync
    attr -s com.dropbox.ignored -V 1 .venv

check:
    just --fmt --check --justfile justfile
    uv run --frozen ruff check
    tasks check

test:
    uv run --frozen pytest -q

verify: check test
```
Tasks 3–5 add lines to `check` and `test`. `tasks check` fails until Task 5 runs `tasks init`; that is expected until then — run the other lines by hand where a step says so.

- [ ] **Step 7: Lock, sync, and run the suite**

```bash
cd ~/d/wali
uv lock
just setup
uv run --frozen pytest -q
```
Expected: `uv lock` writes `uv.lock`; `attr` succeeds; pytest reports the same count of passes as `uv run --frozen pytest -q tests/bin/test_walictl.py` does in the dotfiles worktree (run that too and compare the numbers).

- [ ] **Step 8: Run ruff and pyright once**

```bash
cd ~/d/wali
uv run --frozen ruff check; echo "ruff rc=$?"
uv run --frozen pyright; echo "pyright rc=$?"
just --fmt --check --justfile justfile
```
If `ruff check` is clean, leave it in `check`. If it reports findings, remove the `uv run --frozen ruff check` line from `check` and add a note to the README section written in Task 5 ("ruff findings pending: run `uv run ruff check`"). Pyright is *not* added to `check` in either case: dotfiles never ran it in CI, so its state is unknown and out of scope; record its result in the Task 5 README note the same way.

- [ ] **Step 9: Commit**

```bash
cd ~/d/wali
DOTS_COMMIT=$(git -C /mnt/ssd/Dropbox/dotfiles/.worktrees/wali-migration rev-parse --short main)
git add -A
git commit -m "feat!: replace the click CLI with walictl

walictl and its pytest suite move here from khughitt/dotfiles@${DOTS_COMMIT}
(bin/walictl, tests/bin/test_walictl.py). The old CLI is on the
legacy-click-cli branch and the v0.1-legacy tag."
```

### Task 3: Add the Noctalia plugin

**Files:**
- Create: `~/d/wali/integrations/noctalia-plugin/{plugin.toml,logic.luau,panel.luau,shell.luau,widget.luau,plugin_test.lua,README.md}` (copies of dotfiles `noctalia/plugins/wali-panel/*`)
- Modify: `~/d/wali/justfile` (`test` recipe)

**Interfaces:**
- Produces: `~/d/wali/integrations/noctalia-plugin/` — the directory dotfiles' `setup_noctalia_plugins` links as `${XDG_DATA_HOME}/noctalia/plugins/wali-panel` (Task 6). Plugin id stays `khughitt/wali-panel`.

- [ ] **Step 1: Copy the plugin**

```bash
DOTS=/mnt/ssd/Dropbox/dotfiles/.worktrees/wali-migration
mkdir -p ~/d/wali/integrations
cp -r "$DOTS/noctalia/plugins/wali-panel" ~/d/wali/integrations/noctalia-plugin
ls ~/d/wali/integrations/noctalia-plugin
```
Expected: `README.md logic.luau panel.luau plugin.toml plugin_test.lua shell.luau widget.luau`.

- [ ] **Step 2: Run the Lua test from the new location**

Run: `lua ~/d/wali/integrations/noctalia-plugin/plugin_test.lua`
Expected: passes exactly as `lua noctalia/plugins/wali-panel/plugin_test.lua` does in the dotfiles worktree (the test resolves its siblings via `arg[0]`, so no edit is needed).

- [ ] **Step 3: Add it to `just test`**

In `~/d/wali/justfile`, replace the `test` recipe with:
```just
test:
    uv run --frozen pytest -q
    @command -v lua >/dev/null || { echo 'lua is required for the Noctalia plugin tests' >&2; exit 127; }
    lua integrations/noctalia-plugin/plugin_test.lua
```

- [ ] **Step 4: Run and commit**

```bash
cd ~/d/wali && just test
git add integrations justfile
git commit -m "feat: add the Noctalia wali-panel plugin

Moved from dotfiles noctalia/plugins/wali-panel; the id khughitt/wali-panel
and plugin.toml are unchanged so Noctalia's enabled state survives."
```

### Task 4: Add the shell helpers and their zsh suite, with the manifest contract

**Files:**
- Create: `~/d/wali/shell/wali.zsh` (copy of dotfiles `shell/wali`), `~/d/wali/tests/wali.zsh` (copy of dotfiles `tests/wali.zsh`), `~/d/wali/tests/tmp_cleanup.zsh` (copy of dotfiles `tests/tmp_cleanup.zsh`)
- Modify: `~/d/wali/justfile` (`check` and `test`)

**Interfaces:**
- Consumes: `walictl` on `$PATH` (the dotfiles shim; the fragment never spells a path).
- Produces: `~/d/wali/shell/wali.zsh`, sourced by dotfiles `zshrc` (Task 8). `tests/wali.zsh` now owns the plugin.toml manifest assertions that leave `tests/setup_and_health.zsh` in Task 8.

- [ ] **Step 1: Copy the files**

```bash
DOTS=/mnt/ssd/Dropbox/dotfiles/.worktrees/wali-migration
cd ~/d/wali
mkdir -p shell
cp "$DOTS/shell/wali" shell/wali.zsh
cp "$DOTS/tests/wali.zsh" tests/wali.zsh
cp "$DOTS/tests/tmp_cleanup.zsh" tests/tmp_cleanup.zsh
```

- [ ] **Step 2: Retarget the suite's source line**

In `~/d/wali/tests/wali.zsh` line 44, change:
```zsh
source "${repo_root}/shell/wali"
```
to:
```zsh
source "${repo_root}/shell/wali.zsh"
```
`repo_root=${0:A:h:h}` on line 4 already resolves to `~/d/wali`; leave it.

- [ ] **Step 3: Run the suite before adding anything**

Run: `zsh ~/d/wali/tests/wali.zsh`
Expected: `wali tests passed`.

- [ ] **Step 4: Add the manifest contract assertions**

In `~/d/wali/tests/wali.zsh`, immediately before the final line `print -- 'wali tests passed'`, insert:
```zsh
# The plugin's contract with Noctalia v5. It lived in dotfiles' setup suite
# while the plugin did; it belongs beside the plugin.
python3 - "${repo_root}/integrations/noctalia-plugin/plugin.toml" <<'PY'
import sys, tomllib

wali = tomllib.load(open(sys.argv[1], "rb"))
assert wali["id"] == "khughitt/wali-panel"
assert wali["plugin_api"] == 22
assert wali["plugin_api"] <= 23
assert wali["dependencies"] == ["walictl"]
assert wali["widget"] == [{"id": "widget", "entry": "widget.luau"}]
assert wali["panel"] == [{
    "id": "panel", "entry": "panel.luau", "width": 588, "height": 520,
    "placement": "attached", "position": "auto",
    "keyboard_focus": "exclusive",
    "capture_keys": ["h", "Left", "l", "Right", "k", "Up", "j", "Down", "r", "f", "e", "y", "shift+question", "F1"],
}]
assert "setting" not in wali
PY
```

- [ ] **Step 5: Prove the assertions bite, then restore**

```bash
cd ~/d/wali
sed -i 's/^plugin_api = 22$/plugin_api = 21/' integrations/noctalia-plugin/plugin.toml
zsh tests/wali.zsh; echo "rc=$?"
git checkout -- integrations/noctalia-plugin/plugin.toml
zsh tests/wali.zsh
```
Expected: first run prints an `AssertionError` and `rc=1`; second run prints `wali tests passed`.

- [ ] **Step 6: Add to the justfile**

Replace the `check` and `test` recipes in `~/d/wali/justfile` with:
```just
check:
    just --fmt --check --justfile justfile
    uv run --frozen ruff check
    zsh -n shell/wali.zsh tests/wali.zsh tests/tmp_cleanup.zsh
    tasks check

test:
    uv run --frozen pytest -q
    zsh tests/wali.zsh
    @command -v lua >/dev/null || { echo 'lua is required for the Noctalia plugin tests' >&2; exit 127; }
    lua integrations/noctalia-plugin/plugin_test.lua
```
(Keep the `ruff` line out if Task 2 Step 8 removed it.)

- [ ] **Step 7: Run and commit**

```bash
cd ~/d/wali && just test && zsh -n shell/wali.zsh tests/wali.zsh tests/tmp_cleanup.zsh
git add shell tests justfile
git commit -m "feat: add the wali shell helpers and their suite

shell/wali and tests/wali.zsh from dotfiles, plus the plugin.toml manifest
assertions that dotfiles' setup suite made on the plugin's behalf."
```

### Task 5: Add the systemd units, docs, README, and register the tasks project

**Files:**
- Create: `~/d/wali/systemd/wali-rotate.service`, `~/d/wali/systemd/wali-rotate.timer` (copies of dotfiles `systemd/user/wali-rotate.*`), `~/d/wali/docs/noctalia-wallpaper-switcher.md` (copy of dotfiles `noctalia/noctalia-wallpaper-switcher.md`), `~/d/wali/tasks/.config.toml` (via `tasks init`)
- Modify: `~/d/wali/README.md` (rewrite), `~/d/wali/docs/noctalia-wallpaper-switcher.md` (path table)

**Interfaces:**
- Produces: `~/d/wali/systemd/wali-rotate.{service,timer}` — the sources dotfiles' systemd phase links (Task 6); the `wali` tasks prefix used by Task 12.

- [ ] **Step 1: Copy units and the switcher doc**

```bash
DOTS=/mnt/ssd/Dropbox/dotfiles/.worktrees/wali-migration
cd ~/d/wali
mkdir -p systemd docs
cp "$DOTS/systemd/user/wali-rotate.service" "$DOTS/systemd/user/wali-rotate.timer" systemd/
cp "$DOTS/noctalia/noctalia-wallpaper-switcher.md" docs/noctalia-wallpaper-switcher.md
cat systemd/wali-rotate.service
```
Expected: `ExecStart=%h/bin/walictl next` — unchanged on purpose; `~/bin` is dotfiles' `bin`, where the shim lives.

- [ ] **Step 2: Fix the switcher doc's path table**

In `~/d/wali/docs/noctalia-wallpaper-switcher.md`:
- Line 13: `| Timed rotation | \`systemd/user/wali-rotate.timer\` running \`walictl next\` |` → `| Timed rotation | \`systemd/wali-rotate.timer\` running \`walictl next\` |`
- Line 26: `| \`$XDG_CONFIG_HOME/wali/config.toml\` | Per-host config, linked from \`wali/<hostname>/config.toml\` |` → `| \`$XDG_CONFIG_HOME/wali/config.toml\` | Per-host config, linked by dotfiles' setup.sh from its \`wali/<hostname>/config.toml\` |`
- Line 31: `| \`tests/bin/test_walictl.py\` | Tests |` → `| \`tests/test_walictl.py\` | Tests |`
- Line 72: `Design: \`docs/specs/2026-09-07-wallpaper-management-redesign-design.md\`.` → `Design: \`docs/specs/2026-09-07-wallpaper-management-redesign-design.md\` in the dotfiles repo, where the redesign was done.`

- [ ] **Step 3: Rewrite the README**

Replace `~/d/wali/README.md` with:
````markdown
# wali

Wallpaper selection, history, and favorites on top of Noctalia v5.

Noctalia displays wallpapers and derives colors. `walictl` decides which photo
is shown, remembers what was shown, and keeps favorites. The Wali Panel plugin
(`khughitt/wali-panel`) is a view over `walictl current --json`, and the shell
helpers in `shell/wali.zsh` ingest and edit photos. Ownership, commands, keys,
and the config format are in `docs/noctalia-wallpaper-switcher.md`.

## Layout

| Path | Purpose |
|---|---|
| `bin/walictl` | The CLI (Python 3.11+, standard library only) |
| `shell/wali.zsh` | zsh helpers: `wali_ingest`, `wali_set`, `wali_search`, `wali_rotate`, … |
| `integrations/noctalia-plugin/` | The `khughitt/wali-panel` Noctalia v5 plugin |
| `systemd/` | `wali-rotate.timer` and its service |
| `tests/` | pytest suite for walictl, zsh suite for the helpers and the plugin manifest |
| `docs/` | Usage and ownership |

## Install

This checkout is reached as `~/d/wali` by the dotfiles repo, which owns the
wiring: `bin/walictl` there is a shim that execs `~/d/wali/bin/walictl`,
`setup.sh` links the plugin and the units, `zshrc` sources
`shell/wali.zsh`, and `wali/<host>/config.toml` there is linked to
`$XDG_CONFIG_HOME/wali/config.toml`. Run dotfiles' `setup.sh` after cloning.

Development:

```bash
just setup    # uv sync; marks .venv com.dropbox.ignored
just verify   # check + test
```

## History

The design behind walictl is `docs/specs/2026-09-07-wallpaper-management-redesign-design.md`
in the dotfiles repo, where it was written and carried out. The previous
click + sqlite CLI is on the `legacy-click-cli` branch and the `v0.1-legacy` tag.
````
Then, if Task 2 Step 8 recorded findings, append a `## Pending` section naming them ("ruff findings pending: run `uv run ruff check`" and/or "pyright not yet clean: run `uv run pyright`").

- [ ] **Step 4: Register the tasks project**

```bash
cd ~/d/wali
tasks init --prefix wali
tasks projects --pretty | grep '^wali'
```
Expected: `wali` appears with path `/mnt/ssd/Dropbox/wali`. This writes `tasks/.config.toml` and registers the prefix in `~/.config/tasks/projects.toml` (per-machine; europa registers when it next runs `tasks init` there — note that in Task 10).

- [ ] **Step 5: File any lint findings as tasks**

Only if Task 2 Step 8 left ruff or pyright findings:
```bash
cd ~/d/wali
tasks add "Clear ruff findings in bin/walictl" -p 3 --size s --tag lint -b "Findings inherited from dotfiles; ruff check was left out of just check until they are cleared."
```
(and the same for pyright). Skip this step otherwise.

- [ ] **Step 6: Verify and commit**

```bash
cd ~/d/wali && just verify
git add -A
git commit -m "feat: add systemd units, docs, README, and the tasks project

wali-rotate.{service,timer} and the switcher doc from dotfiles; README
describes the layout and how dotfiles wires the checkout in; tasks init
registers the wali prefix."
```
Expected: `just verify` green (`tasks check` now passes).

- [ ] **Step 7: Confirm the checkout has synced to europa**

This step needs the user: ask them to run on europa
```bash
ls -l ~/d/wali/bin/walictl ~/d/wali/integrations/noctalia-plugin/plugin.toml ~/d/wali/systemd/wali-rotate.timer
```
and report. Do not start Part B's cutover (Task 9) until all three exist there. Parts B's Tasks 6–8 may proceed in the meantime: they touch only the worktree.

---

## Part B — dotfiles retargets (worktree `.worktrees/wali-migration`)

All paths in Part B are relative to the worktree. Every task ends with `just check test` green in the worktree.

### Task 6: Shim, `WALI_ROOT`, setup.sh retargets, and the test fixture

**Files:**
- Modify: `bin/walictl` (replace content), `setup.sh:11-13`, `setup.sh:455-461` (preflight), `setup.sh:745-746` (systemd links), `setup.sh:841` (plugin link), `tests/setup_and_health.zsh:144-149` (fixture), `tests/setup_and_health.zsh:598-605` (unit link assertions), `tests/setup_and_health.zsh:1486-1516` (preflight test), `tests/setup_and_health.zsh:415-450` (v4 IPC scans)

**Interfaces:**
- Consumes: `~/d/wali/bin/walictl`, `~/d/wali/integrations/noctalia-plugin`, `~/d/wali/systemd/wali-rotate.*` (Tasks 2, 3, 5).
- Produces: `WALI_ROOT` in setup.sh; the `WALI_SOURCE_PRESENT` fixture switch in `run_setup`, which Tasks 7–8 rely on.

- [ ] **Step 1: Add the wali fixture to `run_setup` and watch the systemd assertions fail**

In `tests/setup_and_health.zsh`, after the prism fixture block (lines 146–149) inside `run_setup`, add:
```zsh
  if [[ "${WALI_SOURCE_PRESENT:-true}" == true ]]; then
    mkdir -p "${tmp}/home/d/wali/integrations/noctalia-plugin" \
      "${tmp}/home/d/wali/systemd" "${tmp}/home/d/wali/bin"
    touch "${tmp}/home/d/wali/integrations/noctalia-plugin/plugin.toml"
    touch "${tmp}/home/d/wali/systemd/wali-rotate.service" \
      "${tmp}/home/d/wali/systemd/wali-rotate.timer"
    printf '#!/usr/bin/env bash\nexit 0\n' > "${tmp}/home/d/wali/bin/walictl"
    chmod +x "${tmp}/home/d/wali/bin/walictl"
  fi
```
Then in `test_setup_link_only_creates_expected_links_without_external_clones` (line ~598), split the unit loop so the wali units expect the checkout:
```zsh
  for unit in familiar-reap.service familiar-reap.timer mindful-docker.service; do
    [[ -L "${tmp}/config/systemd/user/${unit}" ]] || \
      fail "expected linked ${unit}"
    [[ "$(readlink "${tmp}/config/systemd/user/${unit}")" == \
        "${repo_root}/systemd/user/${unit}" ]] || \
      fail "expected ${unit} to point into the repository"
  done
  for unit in wali-rotate.service wali-rotate.timer; do
    [[ -L "${tmp}/config/systemd/user/${unit}" ]] || \
      fail "expected linked ${unit}"
    [[ "$(readlink "${tmp}/config/systemd/user/${unit}")" == \
        "${tmp}/home/d/wali/systemd/${unit}" ]] || \
      fail "expected ${unit} to point into the wali checkout"
  done
```

- [ ] **Step 2: Run the suite to see the new expectation fail**

Run: `zsh tests/setup_and_health.zsh`
Expected: `FAIL: expected wali-rotate.service to point into the wali checkout`.

- [ ] **Step 3: Add `WALI_ROOT` and retarget setup.sh**

In `setup.sh`, after line 13 (`PRISM_ROOT="${HOME}/d/prism"`), add:
```bash
# The wali checkout, reached the same way: bin/walictl execs into it and the
# systemd and Noctalia-plugin phases link out of it.
WALI_ROOT="${HOME}/d/wali"
```
Replace lines 745–746:
```bash
    ln_s "${WALI_ROOT}/systemd/wali-rotate.service" "${XDG_CONFIG_HOME}/systemd/user/wali-rotate.service"
    ln_s "${WALI_ROOT}/systemd/wali-rotate.timer" "${XDG_CONFIG_HOME}/systemd/user/wali-rotate.timer"
```
Replace line 841:
```bash
    ln_s "${WALI_ROOT}/integrations/noctalia-plugin" "${plugin_dir}/wali-panel"
```
In `setup_preflight`, after the `prism node dependencies` block (line 467, before the familiar comment), add:
```bash
    # ln_s stops the systemd and plugin phases on a missing checkout; this names
    # the fix up front, with the rest of the per-machine prerequisites.
    preflight_check "wali checkout" "git clone git@github.com:khughitt/wali.git ${WALI_ROOT}" \
        test -x "${WALI_ROOT}/bin/walictl" || missing=1
```

- [ ] **Step 4: Replace the shim**

Replace the content of `bin/walictl` with:
```bash
#!/usr/bin/env bash
# A wrapper rather than a symlink, like bin/prism: a relative link assumes
# dotfiles and wali are siblings, which a worktree checkout breaks, and an
# absolute link writes this machine's layout into git. `~/d` is the one layout
# the tree assumes.
exec "$HOME/d/wali/bin/walictl" "$@"
```
Then `chmod +x bin/walictl` (it already is; confirm with `ls -l bin/walictl`).

- [ ] **Step 5: Drop the moved files from the v4-IPC scans**

In `test_active_noctalia_code_has_no_v4_ipc` (line ~420), the `files=(` array loses `"${repo_root}/bin/walictl"` and `"${repo_root}/shell/wali"`, leaving `niri/config.kdl`, `setup.sh`, and `bin/dotfiles-health`. In `test_active_noctalia_code_has_no_v4_ipc_fails_on_scan_error` (line ~445), change `mkdir -p "$tmp/repo/bin" "$tmp/repo/shell" "$tmp/repo/niri"` to `mkdir -p "$tmp/repo/niri"` and delete the two lines `cp "${repo_root}/bin/walictl" "$tmp/repo/bin/walictl"` and `cp "${repo_root}/shell/wali" "$tmp/repo/shell/wali"`. The test still fails the scan on purpose: it never copies `bin/dotfiles-health`.

- [ ] **Step 6: Extend the preflight test**

In the `--check` test around line 1512, after the `MISSING  mindful environment` assertion, add:
```zsh
  [[ "$output" == *"MISSING  wali checkout"* ]] || \
    fail "preflight did not report the missing wali checkout"
  [[ "$output" == *"git clone git@github.com:khughitt/wali.git"* ]] || \
    fail "preflight reported the wali finding without naming its fix"
```
(That test's fixture builds `${tmp}/home/d/prism` by hand and no `wali`, so the finding is expected.)

- [ ] **Step 7: Add a negative test for the plugin phase**

After `test_noctalia_plugin_phase_requires_prism_source` (line ~795), add:
```zsh
test_noctalia_plugin_phase_requires_wali_source() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"
  set +e
  output=$(WALI_SOURCE_PRESENT=false run_setup "$tmp" --link-only \
    --only noctalia-plugins 2>&1)
  exit_status=$?
  set -e
  (( exit_status != 0 )) || fail "plugin setup accepted a missing wali plugin source"
  [[ "$output" == *"Link source does not exist"* && "$output" == *"d/wali/integrations"* ]] || \
    fail "plugin setup did not explain the missing wali plugin source: ${output}"
}
```
and register it in the call list at the bottom of the file, directly after `test_noctalia_plugin_phase_requires_prism_source`.

- [ ] **Step 8: Run the suites**

```bash
zsh tests/setup_and_health.zsh
just check
```
Expected: `setup and health tests passed` (or the file's final success line); `just check` green — `bin/dotfiles-layout-check` accepts the shim because it is a regular file, and shellcheck does not cover `bin/walictl` (it is not in `bash_files`).

- [ ] **Step 9: Commit**

```bash
git add bin/walictl setup.sh tests/setup_and_health.zsh
git commit -m "feat(wali): reach walictl, its plugin, and its units through ~/d/wali

bin/walictl becomes an exec shim like bin/prism; setup.sh links the
Noctalia plugin and wali-rotate units out of WALI_ROOT and preflight names
the checkout. The setup suite fakes ~/d/wali beside its prism fixture.
The originals stay until every host's links are retargeted."
```

### Task 7: dotfiles-health retargets and the `timers.target.wants` check

**Files:**
- Modify: `bin/dotfiles-health:322-323`, `bin/dotfiles-health:413-418`, `bin/dotfiles-health:420-435` (wants-link check), `tests/setup_and_health.zsh:1220-1275` (timer health test), `tests/setup_and_health.zsh:859-878` (wrong plugin link test)

**Interfaces:**
- Consumes: the `run_setup` fixture from Task 6 (units and plugin under `${tmp}/home/d/wali`).
- Produces: `dotfiles-health` passes on a host whose links resolve into `~/d/wali`, and fails when `timers.target.wants/wali-rotate.timer` points elsewhere.

- [ ] **Step 1: Write the failing wants-link test**

In `tests/setup_and_health.zsh`, inside `test_dotfiles_health_checks_enabled_user_timer` right after `prepare_health_fixture "$tmp"` (line ~1229), add:
```zsh
  # systemctl enable writes this link with the unit's resolved path; the
  # fixture stands in for a host whose timer was enabled from ~/d/wali.
  mkdir -p "${tmp}/config/systemd/user/timers.target.wants"
  ln -s "${tmp}/home/d/wali/systemd/wali-rotate.timer" \
    "${tmp}/config/systemd/user/timers.target.wants/wali-rotate.timer"
```
Then add a new test after it:
```zsh
test_dotfiles_health_fails_stale_wali_timer_wants_link() {
  local tmp mockbin output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mockbin="${tmp}/bin"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data" "$mockbin" "${tmp}/stale"
  prepare_health_fixture "$tmp"
  # is-enabled says yes even when the wants link still points at a unit file
  # that moved; only the link target tells the two apart.
  cat > "${mockbin}/systemctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "--user is-enabled "*) printf 'enabled\n'; exit 0 ;;
  "--user list-timers "*) printf 'NEXT LEFT LAST PASSED UNIT ACTIVATES\n'; exit 0 ;;
esac
exit 64
EOF
  chmod +x "${mockbin}/systemctl"
  touch "${tmp}/stale/wali-rotate.timer"
  mkdir -p "${tmp}/config/systemd/user/timers.target.wants"
  ln -s "${tmp}/stale/wali-rotate.timer" \
    "${tmp}/config/systemd/user/timers.target.wants/wali-rotate.timer"

  set +e
  output=$(PATH="${mockbin}:$PATH" run_health "$tmp" 2>&1)
  exit_status=$?
  set -e
  (( exit_status != 0 )) || fail "health accepted a stale wali timer wants link"
  [[ "$output" == *"wrong link target"* && "$output" == *"timers.target.wants/wali-rotate.timer"* ]] || \
    fail "health did not identify the stale wants link: ${output}"
}
```
Register it in the call list directly after `test_dotfiles_health_checks_enabled_user_timer`.

- [ ] **Step 2: Run to see both fail**

Run: `zsh tests/setup_and_health.zsh`
Expected: the first failure is from `test_dotfiles_health_checks_enabled_user_timer` — health reports `wrong link target` for `wali-rotate.service` (it still expects `${DOTS_HOME}/systemd/user/…`).

- [ ] **Step 3: Retarget dotfiles-health**

In `bin/dotfiles-health` replace lines 322–323:
```bash
    check_link "${noctalia_plugin_dir}/wali-panel" \
        "${HOME}/d/wali/integrations/noctalia-plugin"
```
Replace lines 413–418:
```bash
    check_link \
        "${XDG_CONFIG_HOME}/systemd/user/wali-rotate.service" \
        "${HOME}/d/wali/systemd/wali-rotate.service"
    check_link \
        "${XDG_CONFIG_HOME}/systemd/user/wali-rotate.timer" \
        "${HOME}/d/wali/systemd/wali-rotate.timer"
```
Inside the `if [[ "$SKIP_SYSTEMD" != "true" ]]; then` / `if command -v systemctl` block, after the `for timer in …; do … done` loop (line ~434), add:
```bash
            # systemctl enable resolved the unit's symlink when it wrote this
            # link, so is-enabled keeps saying yes after the unit source moves.
            # realpath in check_link accepts either spelling of the live path.
            check_link \
                "${XDG_CONFIG_HOME}/systemd/user/timers.target.wants/wali-rotate.timer" \
                "${HOME}/d/wali/systemd/wali-rotate.timer"
```

- [ ] **Step 4: Run the suite**

Run: `zsh tests/setup_and_health.zsh`
Expected: passes, including `test_dotfiles_health_fails_wrong_noctalia_plugin_link` (its `${tmp}/wrong-wali` link is still wrong against the new target) and the two timer tests.

- [ ] **Step 5: Check and commit**

```bash
just check
git add bin/dotfiles-health tests/setup_and_health.zsh
git commit -m "feat(health): expect wali links into ~/d/wali and check the timer wants link

systemctl enable writes timers.target.wants/wali-rotate.timer with the
unit's resolved path, so is-enabled cannot tell a link into a moved file
from a fresh one; check_link can."
```

### Task 8: Shell sourcing, test/lint trims, and the moved suites

**Files:**
- Modify: `zshrc:128-132`, `bin/dotfiles-check:35,44`, `tests/dotfiles_check.zsh:58`, `justfile:31-42`, `tests/justfile.zsh:73-88`, `pyproject.toml`, `tests/setup_and_health.zsh:340-342,385-396` (manifest assertions), `noctalia/noctalia.md:149-156`
- Delete: `tests/bin/test_walictl.py`, `tests/wali.zsh`

**Interfaces:**
- Consumes: `~/d/wali/shell/wali.zsh` (Task 4).
- Produces: a dotfiles tree whose `just check test` no longer touches walictl, its tests, or the plugin test — while `shell/wali`, `noctalia/plugins/wali-panel/`, and `systemd/user/wali-rotate.*` remain for the live links.

- [ ] **Step 1: Trim the justfile test assertions first, and see them fail**

In `tests/justfile.zsh` delete lines 73–74 (`zsh tests/wali.zsh` assertion), 77–80 (`command -v lua` and `lua noctalia/plugins/wali-panel/plugin_test.lua` assertions), and 82–87 (`test_lines`, the three `_at` lookups, and the ordering check). Keep the `uv run --frozen pytest -q` assertion. Then:

Run: `zsh tests/justfile.zsh`
Expected: still passes (assertions only got fewer). Now edit the `justfile`: in the `test` recipe, delete the lines `zsh tests/wali.zsh`, the `@command -v lua …` guard, and `lua noctalia/plugins/wali-panel/plugin_test.lua`.

Run: `zsh tests/justfile.zsh`
Expected: `justfile tests passed`.

- [ ] **Step 2: Remove the moved suites and the walictl lint entries**

```bash
git rm -q tests/bin/test_walictl.py tests/wali.zsh
```
In `pyproject.toml`: change `name = "dotfiles-wali-tools"` to `name = "dotfiles"`; delete the whole `[tool.pyright]` table (its only entries were the two walictl paths); delete the line `extend-include = ["bin/walictl"]`. Leave `dependencies` alone — other suites may use them and that is not this change's question. Then:
```bash
uv lock
uv run --frozen pytest -q
```
Expected: the lock updates only the project name; pytest runs the remaining `tests/*.py` and `tests/niri/*.py` suites and passes. (Without removing `test_walictl.py` first, this step would fail with a `SyntaxError` from importing the bash shim.)

- [ ] **Step 3: Move the manifest assertions out of the Noctalia contract test**

In `tests/setup_and_health.zsh` `test_noctalia_v5_config_contract`: change the python invocation (lines ~340–342) to pass only two files:
```zsh
  python3 - "${repo_root}/noctalia/config.toml" \
    "${repo_root}/noctalia/templates.toml" <<'PY'
```
delete the line `wali = tomllib.load(open(sys.argv[3], "rb"))`, and delete the block from `assert wali["id"] == "khughitt/wali-panel"` through `assert "setting" not in wali` (Task 4 put those in `~/d/wali/tests/wali.zsh`). The `config["hooks"]["wallpaper_changed"]` and `bar…end` assertions naming `walictl` and `khughitt/wali-panel:widget` stay: those are dotfiles' Noctalia config.

- [ ] **Step 4: Source the fragment from the checkout**

In `zshrc`, change line 128 to:
```zsh
shell_fragments=(aliases audio functions fzf macos ubuntu vconsole zoxide)
```
and after the `unset file shell_fragments` line (132) add:
```zsh
# wali's helpers live in their own checkout, reached the way bin/walictl is.
[[ -r "${HOME}/d/wali/shell/wali.zsh" ]] && source "${HOME}/d/wali/shell/wali.zsh"
```
In `bin/dotfiles-check` delete the lines `    shell/wali` (35) and `    tests/wali.zsh` (44). In `tests/dotfiles_check.zsh` delete the line `  shell/wali` (58).

- [ ] **Step 5: Update the live-layout prose**

In `noctalia/noctalia.md` lines 149–156, replace:
```
Ordinary setup remains usable before the shell starts. The explicit plugin
phase links Wali from dotfiles and Prism from `~/d/prism`, then enables both
through Noctalia IPC. It requires the `~/d/prism` checkout and fails if the
Noctalia IPC endpoint is unavailable.

Dotfiles owns Wali, the Noctalia configuration, and installation; Prism owns
its plugin source. Wali depends on `walictl` and its config link; Prism depends
on `prism` alone.
```
with:
```
Ordinary setup remains usable before the shell starts. The explicit plugin
phase links Wali from `~/d/wali` and Prism from `~/d/prism`, then enables both
through Noctalia IPC. It requires both checkouts and fails if the Noctalia IPC
endpoint is unavailable.

Dotfiles owns the Noctalia configuration and installation; Wali and Prism each
own their plugin source. Wali depends on `walictl` (a shim into `~/d/wali`) and
its config link; Prism depends on `prism` alone.
```

- [ ] **Step 6: Run everything**

```bash
just check test
```
Expected: green. `zsh -n` in `dotfiles-check` no longer lists `shell/wali`; `tests/dotfiles_check.zsh` no longer expects its modeline; the setup suite passes with the fixture. Open a new zsh (`zsh -ic 'type wali_ingest'`) — expected `wali_ingest is a shell function`, because `~/.shell/wali` (the link into main's `shell/wali`) is still sourced by the live zshrc; the worktree's zshrc is not live yet, so this only confirms nothing broke.

- [ ] **Step 7: Commit**

```bash
git add zshrc bin/dotfiles-check tests/dotfiles_check.zsh justfile tests/justfile.zsh pyproject.toml uv.lock tests/setup_and_health.zsh noctalia/noctalia.md
git commit -m "refactor(wali): source the shell helpers from ~/d/wali and drop the moved suites

The walictl pytest suite and tests/wali.zsh now run in the wali repo; the
plugin manifest assertions went with them. pytest has no testpaths and
would otherwise import the bash shim as Python."
```

---

## Part C — cutover, one host at a time

### Task 9: Cut over titan

**Files:** none edited. Runs from the **main checkout** `/mnt/ssd/Dropbox/dotfiles`, because `~/bin`, `~/.shell`, and every live link resolve there.

**Interfaces:**
- Consumes: branch `wali-migration` (Tasks 6–8) and `~/d/wali` on `main` (Task 5).
- Produces: every wali link on titan resolves into `~/d/wali`.

- [ ] **Step 1: Confirm nothing else is pending on main and merge**

```bash
cd /mnt/ssd/Dropbox/dotfiles
git status --short
```
Expected: only the pre-existing ` M prism/titan/values.yaml` and `?? prism/titan/contexts/profile/` (not ours; leave them). Then:
```bash
git merge --ff-only wali-migration
git log --oneline -1
```
Expected: fast-forward; HEAD is Task 8's commit.

- [ ] **Step 2: Record the link targets before**

```bash
readlink ~/.local/share/noctalia/plugins/wali-panel \
  ~/.config/systemd/user/wali-rotate.service \
  ~/.config/systemd/user/wali-rotate.timer \
  ~/.config/systemd/user/timers.target.wants/wali-rotate.timer
```
Expected: all four into `…/dotfiles/…`.

- [ ] **Step 3: Run the three phases with timers enabled**

```bash
cd /mnt/ssd/Dropbox/dotfiles
bash setup.sh --link-only --enable-user-timers --only graphical-config,systemd,noctalia-plugins
```
Expected in the output: `ln -s` lines for the two units and the plugin (none `[SKIPPING]`, since each currently points elsewhere), `systemctl --user daemon-reload`, `systemctl --user enable --now wali-rotate.timer`, `noctalia msg plugins enable khughitt/wali-panel`. If Noctalia is not running the phase says so; run `noctalia msg plugins enable khughitt/wali-panel` once it is.

- [ ] **Step 4: Verify the links and the live behaviour**

```bash
readlink ~/.local/share/noctalia/plugins/wali-panel \
  ~/.config/systemd/user/wali-rotate.service \
  ~/.config/systemd/user/wali-rotate.timer
realpath ~/.config/systemd/user/timers.target.wants/wali-rotate.timer
walictl current --json | head -c 200; echo
systemctl --user list-timers wali-rotate.timer --no-pager
noctalia msg plugins list | grep wali-panel
just health-systemd
```
Expected: the three `readlink`s print `/home/keith/d/wali/…`; `realpath` of the wants link is `/mnt/ssd/Dropbox/wali/systemd/wali-rotate.timer`; `walictl current --json` prints JSON through the shim; the timer is listed with a NEXT time; the plugin line ends `enabled`; `dotfiles-health` (full, including systemd) passes. Then `Super+N` opens the panel (ask the user to confirm; it is the one check that needs eyes).

- [ ] **Step 5: Confirm the shell fragment**

Run: `zsh -ic 'type wali_ingest; whence -v wali_ingest'`
Expected: a shell function defined from `/home/keith/d/wali/shell/wali.zsh`.

### Task 10: Cut over europa

**Files:** none. This task is executed by the user on europa; the agent supplies the commands and waits for the report. `tasks park` this step `--waiting-on user --reason environment` while waiting.

- [ ] **Step 1: Ask the user to run, on europa**

```bash
cd ~/d/dotfiles && git log --oneline -1          # must show Task 8's commit (Dropbox delivered main)
ls ~/d/wali/bin/walictl ~/d/wali/systemd/wali-rotate.timer ~/d/wali/integrations/noctalia-plugin/plugin.toml
cd ~/d/wali && tasks init --prefix wali          # tasks/.config.toml already synced; this registers the prefix in europa's ~/.config/tasks/projects.toml
cd ~/d/dotfiles && bash setup.sh --link-only --enable-user-timers --only graphical-config,systemd,noctalia-plugins
readlink ~/.local/share/noctalia/plugins/wali-panel ~/.config/systemd/user/wali-rotate.service ~/.config/systemd/user/wali-rotate.timer
realpath ~/.config/systemd/user/timers.target.wants/wali-rotate.timer
just health-systemd
```
Expected: the same outcomes as Task 9 Step 4, with `/home/keith/d/wali/…` targets.

- [ ] **Step 2: Do not continue to Part D until the user reports `just health-systemd` green on europa.**

---

## Part D — remove the originals

### Task 11: Delete the moved files from dotfiles

**Files:**
- Delete: `shell/wali`, `noctalia/plugins/wali-panel/` (7 files), `systemd/user/wali-rotate.service`, `systemd/user/wali-rotate.timer`, `noctalia/noctalia-wallpaper-switcher.md`
- Modify: `docs/specs/2026-08-20-noctalia-v5-plugin-ports-design.md:133-134`, `docs/specs/2026-09-11-wali-extraction-design.md:3` (status)

Runs in the worktree, which is at the same commit as `main` after Task 9's fast-forward.

- [ ] **Step 1: Confirm nothing live still points at the originals**

On titan (and per the user's report, europa):
```bash
readlink ~/.local/share/noctalia/plugins/wali-panel ~/.config/systemd/user/wali-rotate.service ~/.config/systemd/user/wali-rotate.timer | grep -c dotfiles
realpath ~/.config/systemd/user/timers.target.wants/wali-rotate.timer | grep -c dotfiles
ls -l ~/.shell/wali
```
Expected: `0`, `0`, and `~/.shell/wali` → `…/dotfiles/shell/wali` (that link becomes dangling when the file goes; the live zshrc from Task 8 no longer names it, and `~/.shell` is a directory link, so nothing else reads it).

- [ ] **Step 2: Remove the files**

```bash
cd /mnt/ssd/Dropbox/dotfiles/.worktrees/wali-migration
git rm -q shell/wali systemd/user/wali-rotate.service systemd/user/wali-rotate.timer noctalia/noctalia-wallpaper-switcher.md
git rm -r -q noctalia/plugins/wali-panel
git status --short
```
Expected: 11 `D` lines. (`noctalia/plugins/` and `docs/` are gitignored, which is why this is `git rm` and not a sweep.)

- [ ] **Step 3: Update the live-layout diagram and the spec status**

In `docs/specs/2026-08-20-noctalia-v5-plugin-ports-design.md` lines 133–134, change:
```
$XDG_DATA_HOME/noctalia/plugins/wali-panel
  -> dotfiles/noctalia/plugins/wali-panel
```
to:
```
$XDG_DATA_HOME/noctalia/plugins/wali-panel
  -> ~/d/wali/integrations/noctalia-plugin   (moved out of dotfiles 2026-09; see 2026-09-11-wali-extraction-design.md)
```
In `docs/specs/2026-09-11-wali-extraction-design.md` line 3, change `**Status:** Designed 2026-09-11; not yet implemented. Task \`dots-3a1770\`.` to `**Status:** Designed 2026-09-11; landed on titan and europa <today's date>. Task \`dots-3a1770\`.`

- [ ] **Step 4: Verify in the worktree**

```bash
just check test
git grep -n -E 'noctalia/plugins/wali-panel|shell/wali\b|tests/wali\.zsh|tests/bin/test_walictl' -- . ':!docs' ':!tasks'
```
Expected: green; the grep prints nothing (historical docs and task records are the only remaining mentions, and they are excluded on purpose).

- [ ] **Step 5: Commit, merge, verify live**

```bash
git add -f docs/specs/2026-08-20-noctalia-v5-plugin-ports-design.md docs/specs/2026-09-11-wali-extraction-design.md
git commit -m "refactor(wali): remove the files that now live in khughitt/wali

Both hosts link the plugin and units out of ~/d/wali and source
shell/wali.zsh from there; nothing resolves into these paths any more."
cd /mnt/ssd/Dropbox/dotfiles
git merge --ff-only wali-migration
just health-systemd
walictl current --json | head -c 80; echo
```
Expected: fast-forward; health green on titan; walictl still answers. europa needs no action.

---

## Part E — tasks

### Task 12: Move the five wali tasks and close the migration

**Files:**
- Modify: `tasks/dots-{5760ef,9bfdc0,b9ba7c,2aa60c,b3e5ae}.md` (dropped, via the CLI), `~/d/wali/tasks/*.md` (created), `tasks/dots-3a1770.md` (done)

Runs after both repos are on `main`. Use the CLI only; never edit `tasks/*.md` by hand.

- [ ] **Step 1: Read each task in full**

```bash
for t in dots-5760ef dots-9bfdc0 dots-b9ba7c dots-2aa60c dots-b3e5ae; do tasks show $t --pretty; echo ======; done
```
Note each one's `status`, `priority`, `size`, `tags`, and body verbatim.

- [ ] **Step 2: Re-add each in wali**

For each task, from `~/d/wali`, with the values read in Step 1 (ideas keep `--status idea` and take no size):
```bash
cd ~/d/wali
tasks add "<title verbatim>" --status <status> -p <priority> [--size <size>] --tag <each tag> --source dots-<id> -b "<body verbatim>"
```
The command prints the new id; keep the mapping `dots-<id> → wali-<new>`. Then for each:
```bash
tasks note wali-<new> "moved from dots-<id>"
tasks drop dots-<id> "moved to wali-<new>"
```

- [ ] **Step 3: Restore the one dependency that still matters**

```bash
tasks dep wali-<2aa60c's new id> --on dots-59c279
```
(`dots-b9ba7c`'s dependency on `dots-ba0168` is not carried: `ba0168` is done.)

- [ ] **Step 4: Record the tool gap**

```bash
tasks feedback "no way to move a task between registered projects" --category gap -b "Moving five open tasks to a new project meant re-adding each with --source and dropping the original by hand; a move that keeps id history, notes, and cross-project deps would replace that."
```

- [ ] **Step 5: Check both projects and close the migration**

```bash
cd ~/d/wali && tasks check && tasks list --pretty
cd /mnt/ssd/Dropbox/dotfiles && tasks check
tasks done dots-3a1770 "walictl, shell helpers, plugin, units, tests, and five tasks moved to khughitt/wali; dotfiles reaches them through ~/d/wali; both hosts cut over"
git add tasks
git commit -m "chore(tasks): move the wali tasks to the wali project and close the extraction"
cd ~/d/wali && git add tasks && git commit -m "chore(tasks): take over the five wallpaper tasks from dotfiles"
```
Expected: `tasks check` clean in both; `tasks list` in wali shows five tasks with `source: dots-…`; `dots-3a1770` closes without `--force` (it has no children — the plan-step children created for this plan are done by then, one per task above).

- [ ] **Step 6: Clean up the worktree**

```bash
cd /mnt/ssd/Dropbox/dotfiles
git worktree remove .worktrees/wali-migration
git branch -d wali-migration
```
