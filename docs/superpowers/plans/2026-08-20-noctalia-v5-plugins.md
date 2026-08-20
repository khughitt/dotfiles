# Noctalia v5 Wali and Prism Plugins Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore full Wali Panel and Prism behavior as native Noctalia v5 Luau plugins, install them safely from dotfiles, and make their presence and enablement observable.

**Architecture:** Keep `walictl`, `prism`, and niri-glass as the only domain backends. Each plugin is a two-entry v5 package (`widget.luau` and `panel.luau`); Prism additionally keeps its existing presentation and FIFO logic in standard-Lua-compatible modules so `/usr/bin/lua` can test the production code. Dotfiles owns the bar configuration, an explicit post-shell plugin setup phase, and health checks; Prism lands first so dotfiles never points at a missing v5 source.

**Tech Stack:** Bash, Zsh, TOML, Luau restricted to the Lua 5.5-compatible subset, Python `tomllib`, Node's built-in test runner, Noctalia v5 plugin API, `walictl`, `prism`, and Quickshell IPC.

**Spec:** `docs/specs/2026-08-20-noctalia-v5-plugin-ports-design.md`

## Global Constraints

- The installed Noctalia version is `5.0.0_beta.8` and accepts plugin API levels 3 through 23.
- Wali and Prism target `plugin_api = 22`; static tests must also assert both values are at most 23 because `noctalia plugins lint` does not.
- Each manifest has exactly one `[[widget]]` and one `[[panel]]`; neither declares any setting table.
- Both panels use `width = 588`, `height = 798`, `placement = "attached"`, and `position = "auto"`. Prism's manifest records that 588 by 798 preserves the v4 560 by 760 footprint at the tracked 1.05 UI scale.
- API 24 argv-table subprocesses are unavailable. Every subprocess command is built from an argument array by one POSIX single-quote helper; no dynamic value is interpolated into a command string.
- Production Prism modules use no Luau type annotations, `continue`, or other Luau-only syntax so `/usr/bin/lua` executes their tests directly.
- Do not add dependencies, a v4 compatibility layer, API-version branches, a standalone Quickshell wrapper, or duplicated wallpaper/Prism domain logic.
- Tracked Noctalia config must not declare `[plugins] enabled`; the state layer replaces it. Setup enables both plugins through IPC after linking them.
- The plugin activation phase is explicit and opt-in. A fresh machine runs ordinary setup, starts Noctalia, then runs `./setup.sh --only noctalia-plugins`; unavailable IPC fails that phase loudly.
- Automated tests must intercept every Noctalia plugin IPC call. The stub may forward only `config validate` and `theme --list-templates`; every other unrecognized command fails with exit 64.
- Linux health checks require a live Noctalia instance unless the caller passes the explicit `--skip-noctalia-ipc` flag; static plugin link and manifest checks always run.
- Use `~/d/prism` in documentation and commands; do not add machine-specific physical paths.
- Use conventional commits without attribution trailers.

---

## File Map

### Dotfiles repository

- Modify `setup.sh`: add the explicit `noctalia-plugins` phase, link both source directories under `$XDG_DATA_HOME/noctalia/plugins`, then issue the two exact enable calls.
- Modify `tests/setup_and_health.zsh`: install shared deny-by-default test commands for both setup and health; cover phase selection, exact IPC, source failures, manifests, bar configuration, links, and health failures.
- Modify `justfile`: include Wali's direct Lua contract in the normal dotfiles test suite.
- Modify `bin/dotfiles-health`: validate both local plugin links, reject v4 manifests, and require both IDs to be reported enabled unless `--skip-noctalia-ipc` is set.
- Modify `noctalia/config.toml`: replace the built-in `wallpaper` widget with the two fully qualified plugin widget IDs and omit widget aliases and tracked enablement.
- Replace `noctalia/plugins/wali-panel/{manifest.json,Main.qml,BarWidget.qml,Panel.qml}` with `plugin.toml`, `shell.luau`, `logic.luau`, `widget.luau`, `panel.luau`, `plugin_test.lua`, and `README.md`.
- Modify `noctalia/noctalia.md` and `noctalia/noctalia-wallpaper-switcher.md`: document the restored plugins and activation flow.
- Modify `docs/specs/2026-08-20-noctalia-v5-plugin-ports-design.md`: mark implementation complete only after both repositories and all acceptance gates are verified.

### Prism repository

- Replace `integrations/noctalia-plugin/{manifest.json,Main.qml,BarWidget.qml,Panel.qml,ParamControl.qml,PrismClient.qml,presentation.mjs,queue.mjs}` with `plugin.toml`, `shell.luau`, `presentation.luau`, `queue.luau`, `widget.luau`, `panel.luau`, and `plugin_test.lua`.
- Rewrite `integrations/noctalia-plugin/contract.test.mjs`: assert the real v5 manifest and entry contract.
- Modify `test/plugin-presentation.test.js`: keep shipped-definition coverage; move production presentation calculations to the Lua test.
- Remove `test/plugin-queue.test.js`: its cases move unchanged to the test that loads production `queue.luau`.
- Rewrite `test/plugin-client.test.js`: assert the v5 lifecycle, frame-tick, preview, and error contract instead of QML syntax.
- Modify `package.json`: expose the Lua contract as `test:plugin-lua` and run it after the existing Node suite.
- Modify `README.md`: list `lua` as a development prerequisite for the Noctalia plugin test.
- Rewrite `docs/notes/noctalia-plugin-contract.md`: describe v5 Luau entries and remove v4 QML loader claims.

---

## Execution Preflight

- [ ] **Step 1: Read the approved design and confirm the UI-scale fix is in history**

```bash
git merge-base --is-ancestor 49bb0a4 HEAD
```

Run from the existing dotfiles plugin worktree. Expected: exit 0. If it exits 1, merge `fix/noctalia-ui-scale` into main and rebase this branch on main before touching plugin code. Do not duplicate the fix in this branch.

- [ ] **Step 2: Verify clean starting trees**

```bash
git status --short
git -C ~/d/prism status --short
```

Expected: only the already-approved design/plan changes in dotfiles; no Prism changes. Stop if either tree has unrelated edits.

- [ ] **Step 3: Create the Prism worktree**

Use `superpowers:using-git-worktrees`, then create the branch beside the repository:

```bash
git -C ~/d/prism worktree add ~/d/prism/.worktrees/noctalia-v5-plugin \
  -b feat/noctalia-v5-plugin main
```

All Prism commands below run in `~/d/prism/.worktrees/noctalia-v5-plugin`.

- [ ] **Step 4: Record green baselines**

```bash
just test
npm test --prefix ~/d/prism/.worktrees/noctalia-v5-plugin
```

Expected: both suites pass before the first RED test.

---

### Task 1: Make Setup IPC-Safe and Add the Explicit Plugin Phase

**Files:**
- Modify: `tests/setup_and_health.zsh:71-106,807-850,1045-1100`
- Modify: `setup.sh:14-40,491-535,579-595`

**Interfaces:**
- Consumes: existing `run`, `ln_s`, `run_phase`, `ONLY_PHASES`, `XDG_DATA_HOME`, and `HEADLESS` behavior.
- Produces: `setup_noctalia_plugins()` and an opt-in `noctalia-plugins` phase that links both plugin directories and enables `khughitt/wali-panel` followed by `khughitt/prism`.
- Produces for later tests: `install_test_stubs(tmp)`, called by both `run_setup` and `run_health`, plus `NOCTALIA_TEST_LOG`, `NOCTALIA_ENABLE_STATUS`, and `NOCTALIA_PLUGIN_LIST` controls.

- [ ] **Step 1: Install shared deny-by-default stubs before writing any production IPC call**

Move the existing Prism stub and the new Noctalia stub into `install_test_stubs()`. The helper creates a command only when the test has not supplied its own override, then both `run_setup` and `run_health` call it before invoking repository code:

```bash
install_test_stubs() {
  local tmp="$1"
  mkdir -p "${tmp}/bin"

  if [[ ! -e "${tmp}/bin/noctalia" ]]; then
    cat > "${tmp}/bin/noctalia" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 4 && "$1" == msg && "$2" == plugins && "$3" == enable ]]; then
  [[ -n "${NOCTALIA_TEST_LOG:-}" ]] && printf '%s\n' "$*" >> "$NOCTALIA_TEST_LOG"
  exit "${NOCTALIA_ENABLE_STATUS:-0}"
fi
if [[ $# -eq 3 && "$1" == msg && "$2" == plugins && "$3" == list ]]; then
  printf '%s\n' "${NOCTALIA_PLUGIN_LIST:-khughitt/wali-panel [local] 1.0.0 enabled
khughitt/prism [local] 1.0.0 enabled}"
  exit 0
fi
if [[ $# -ge 2 && "$1" == config && "$2" == validate ]]; then
  exec /usr/bin/noctalia "$@"
fi
if [[ $# -eq 2 && "$1" == theme && "$2" == --list-templates ]]; then
  exec /usr/bin/noctalia "$@"
fi
printf 'unexpected Noctalia test command:' >&2
printf ' %q' "$@" >&2
printf '\n' >&2
exit 64
EOF
    chmod +x "${tmp}/bin/noctalia"
  fi

  if [[ ! -e "${tmp}/bin/prism" ]]; then
    cat > "${tmp}/bin/prism" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ "$*" == doctor ]] || exit 64
[[ -n "${PRISM_DOCTOR_LOG:-}" ]] && printf '%s\n' "$*" >> "$PRISM_DOCTOR_LOG"
if [[ "${PRISM_DOCTOR_STATUS:-0}" -ne 0 ]]; then
  printf '%s\n' "doctor: niri: generated file missing: prism.kdl" >&2
  exit "$PRISM_DOCTOR_STATUS"
fi
printf '%s\n' "doctor: ok"
EOF
    chmod +x "${tmp}/bin/prism"
  fi
}
```

The only pass-through commands are the two existing read-only probes. `msg plugins disable`, unknown plugin verbs, malformed enable/list calls, and every other command exit 64 without reaching `/usr/bin/noctalia`. Keep the custom-stub guard because the existing macOS health test deliberately installs a sentinel Noctalia executable.

- [ ] **Step 2: Prove both wrappers install the stub and unknown IPC cannot escape**

Use separate temporary trees so `run_health` cannot inherit a stub installed by `run_setup`:

```zsh
test_setup_and_health_install_safe_noctalia_stubs() {
  local setup_tmp health_tmp log status
  setup_tmp=$(make_tmpdir)
  health_tmp=$(make_tmpdir)
  register_tmp_cleanup "$setup_tmp"
  register_tmp_cleanup "$health_tmp"
  log="${setup_tmp}/noctalia.log"

  NOCTALIA_TEST_LOG="$log" run_setup "$setup_tmp" --help >/dev/null
  NOCTALIA_TEST_LOG="$log" PATH="${setup_tmp}/bin:$PATH" \
    noctalia msg plugins enable test/never-live
  [[ "$(<"$log")" == "msg plugins enable test/never-live" ]] || \
    fail "Noctalia enable stub did not capture the exact IPC call"

  set +e
  PATH="${setup_tmp}/bin:$PATH" noctalia msg plugins disable test/never-live
  status=$?
  set -e
  (( status == 64 )) || fail "Noctalia test stub forwarded an unknown mutating command"

  run_health "$health_tmp" --help >/dev/null
  [[ -x "${health_tmp}/bin/noctalia" ]] || \
    fail "run_health did not install its own Noctalia stub"
}
```

- [ ] **Step 3: Write the failing setup-phase tests**

Add these assertions:

```zsh
test_noctalia_plugin_phase_links_and_enables_exact_ids() {
  local tmp log
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  log="${tmp}/noctalia.log"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  NOCTALIA_TEST_LOG="$log" run_setup "$tmp" --link-only \
    --only noctalia-plugins >/dev/null

  [[ -L "${tmp}/data/noctalia/plugins/wali-panel" ]]
  [[ -L "${tmp}/data/noctalia/plugins/prism" ]]
  [[ "$(<"$log")" == $'msg plugins enable khughitt/wali-panel\nmsg plugins enable khughitt/prism' ]] || \
    fail "plugin phase did not issue the two exact enable calls"
}

test_default_setup_does_not_require_live_noctalia() {
  local tmp
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"
  NOCTALIA_ENABLE_STATUS=69 run_setup "$tmp" --link-only >/dev/null
}

test_noctalia_plugin_phase_fails_when_ipc_is_unavailable() {
  local tmp status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"
  set +e
  NOCTALIA_ENABLE_STATUS=69 run_setup "$tmp" --link-only \
    --only noctalia-plugins >/dev/null 2>&1
  status=$?
  set -e
  (( status != 0 )) || fail "plugin setup accepted unavailable Noctalia IPC"
}
```

Remove the Prism path from `run_setup`'s unconditional `mkdir`, then make its creation conditional:

```zsh
mkdir -p "${tmp}/home/d/niri-glass" "${tmp}/bin"
if [[ "${PRISM_PLUGIN_SOURCE_PRESENT:-true}" == true ]]; then
  mkdir -p "${tmp}/home/d/prism/integrations/noctalia-plugin"
fi
```

Then add a disposable-topology test that runs the explicit phase with `PRISM_PLUGIN_SOURCE_PRESENT=false` and requires a non-zero exit containing `Link source does not exist`.

- [ ] **Step 4: Run the setup tests and confirm RED**

```bash
zsh tests/setup_and_health.zsh
```

Expected: failure because `noctalia-plugins` is not a valid phase. The deny-by-default stub makes a live mutation impossible during this RED run.

- [ ] **Step 5: Implement the opt-in phase**

Add `noctalia-plugins` to `VALID_PHASES` and this function:

```bash
function setup_noctalia_plugins() {
    [[ "$HEADLESS" == "false" ]] || return 0

    phase "Noctalia local plugins"
    local plugin_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/noctalia/plugins"

    ensure_dir "$plugin_dir"
    ln_s "${DOTS_HOME}/noctalia/plugins/wali-panel" "${plugin_dir}/wali-panel"
    ln_s "${HOME}/d/prism/integrations/noctalia-plugin" "${plugin_dir}/prism"
    run noctalia msg plugins enable khughitt/wali-panel
    run noctalia msg plugins enable khughitt/prism
}
```

Do not call this phase during ordinary setup. Invoke it only when an explicit `--only` list selects it:

```bash
if [[ "${#ONLY_PHASES[@]}" -gt 0 ]]; then
    run_phase noctalia-plugins setup_noctalia_plugins
fi
```

Place that guarded call after `app-config`. Update `--help` to identify `noctalia-plugins` as a post-shell phase requiring a running Noctalia v5 instance.

- [ ] **Step 6: Run the focused setup suite**

```bash
zsh tests/setup_and_health.zsh
```

Expected: all setup and health tests pass. In particular, headless/default setup never writes the IPC log, explicit plugin setup writes exactly two lines, and non-zero IPC fails.

- [ ] **Step 7: Commit the safe phase**

```bash
git add setup.sh tests/setup_and_health.zsh
git commit -m "feat(setup): add Noctalia plugin phase"
```

---

### Task 2: Port Prism's Tested Presentation, Queue, and Shell Core

**Files:**
- Create: `~/d/prism/.worktrees/noctalia-v5-plugin/integrations/noctalia-plugin/presentation.luau`
- Create: `~/d/prism/.worktrees/noctalia-v5-plugin/integrations/noctalia-plugin/queue.luau`
- Create: `~/d/prism/.worktrees/noctalia-v5-plugin/integrations/noctalia-plugin/shell.luau`
- Create: `~/d/prism/.worktrees/noctalia-v5-plugin/integrations/noctalia-plugin/plugin_test.lua`
- Modify: `~/d/prism/.worktrees/noctalia-v5-plugin/test/plugin-presentation.test.js`
- Delete: `~/d/prism/.worktrees/noctalia-v5-plugin/test/plugin-queue.test.js`
- Modify: `~/d/prism/.worktrees/noctalia-v5-plugin/package.json`

**Interfaces:**
- `presentation.luau` produces `stepPrecision`, `snapValue`, `sliderFrom`, `sliderTo`, `sliderStep`, `toSliderValue`, `canonicalFromSlider`, `stepCanonicalValue`, `canonicalFromSliderStep`, `formatValue`, `titleParam`, `groupParams`, and `modifiedCount`.
- `queue.luau` produces `new`, `enqueue`, `finish`, `isSample`, `affectsParams`, `shouldRefresh`, and `argvFor`.
- Queue items are `{verb="set", key=string, value=scalar, sample=boolean}`, `{verb="unset", key=string}`, `{verb="preview-show", output=string, side="left", diagnosticBackground=boolean}`, or `{verb="preview-hide"}`.
- `shell.luau` produces `quote(value) -> string` and `command(argv) -> string`.
- `panel.luau` in Task 3 consumes all three modules unchanged.

- [ ] **Step 1: Write a direct Lua test for the shipped production modules**

`plugin_test.lua` must load `.luau` files with `dofile`, use a tiny local equality helper, and carry the existing golden vectors from `test/plugin-presentation.test.js` and `test/plugin-queue.test.js`. Include these boundary assertions:

```lua
local here = (arg[0]:match("(.*/)") or "")
local Presentation = dofile(here .. "presentation.luau")
local Queue = dofile(here .. "queue.luau")
local Shell = dofile(here .. "shell.luau")

assert(Presentation.snapValue(100.04, {0.1, 200}, 0.1) == 100)
assert(Presentation.snapValue(100.06, {0.1, 200}, 0.1) == 100.1)
assert(Presentation.canonicalFromSlider(0.5, {
  range = {1, 10000},
  ui = {control = "slider", step = 1, display = "normalized", scale = "logarithmic"},
}) == 100)
assert(Shell.quote("a'b") == "'a'\"'\"'b'")
assert(Shell.command({"prism", "set", "name with space", "a'b"}) ==
  "'prism' 'set' 'name with space' 'a'\"'\"'b'")
```

Port every queue case: immediate launch, same-key sample coalescing, cross-key FIFO, final-write ordering, preview ordering, exact argv arrays, parameter-affecting classification, and drain refresh decisions. Assert preview-show always emits side `left`; delete the old `oppositeSide` case.

- [ ] **Step 2: Add a named Lua test gate after the Node suite and confirm RED**

Change the scripts to:

```json
"test": "node --test test/*.test.js integrations/noctalia-plugin/contract.test.mjs && npm run test:plugin-lua",
"test:plugin-lua": "command -v lua >/dev/null || { echo 'lua is required for the Noctalia plugin tests' >&2; exit 127; }; lua integrations/noctalia-plugin/plugin_test.lua"
```

Run:

```bash
npm test
```

Expected: the existing Node tests run first, then `test:plugin-lua` fails because the `.luau` modules do not exist. On a machine without Lua, the named subtest prints the explicit prerequisite instead of hiding why the suite stopped.

- [ ] **Step 3: Translate the existing modules without changing their algorithms**

Move the function bodies from `presentation.mjs` and `queue.mjs` into Lua tables. Preserve every name in the Interfaces block and return the module table at EOF:

```lua
local M = {}
return M
```

This is a syntax port, not a redesign: arrays become 1-indexed tables, object spreads become explicit table copies, `Math.*` becomes `math.*`, and JavaScript `null` checks become Lua `nil` checks. Delete `oppositeSide`; use literal `"left"` in preview argv generation. Do not add type annotations or `continue`.

Implement the sole shell boundary as:

```lua
local M = {}

function M.quote(value)
  return "'" .. tostring(value):gsub("'", "'\"'\"'") .. "'"
end

function M.command(argv)
  local quoted = {}
  for i, value in ipairs(argv) do quoted[i] = M.quote(value) end
  return table.concat(quoted, " ")
end

return M
```

- [ ] **Step 4: Move duplicate Node coverage to the production Lua test**

Delete `test/plugin-queue.test.js`. In `test/plugin-presentation.test.js`, remove imports from `presentation.mjs` and the numeric mapping tests now executed by Lua. Keep the two tests that load real Prism definitions and assert the exact visible groups, 32 rendered definitions, presentation metadata, and preview scope.

- [ ] **Step 5: Run Prism tests**

```bash
cd ~/d/prism/.worktrees/noctalia-v5-plugin
npm test
```

Expected: the Lua golden vectors and the remaining Node definition tests pass.

- [ ] **Step 6: Commit the tested core**

```bash
git add package.json integrations/noctalia-plugin/presentation.luau \
  integrations/noctalia-plugin/queue.luau integrations/noctalia-plugin/shell.luau \
  integrations/noctalia-plugin/plugin_test.lua test/plugin-presentation.test.js \
  test/plugin-queue.test.js
git commit -m "refactor(noctalia): port Prism plugin core to Luau"
```

---

### Task 3: Replace Prism's v4 Entries with the Native v5 Plugin

**Files:**
- Create: `~/d/prism/.worktrees/noctalia-v5-plugin/integrations/noctalia-plugin/plugin.toml`
- Create: `~/d/prism/.worktrees/noctalia-v5-plugin/integrations/noctalia-plugin/widget.luau`
- Create: `~/d/prism/.worktrees/noctalia-v5-plugin/integrations/noctalia-plugin/panel.luau`
- Rewrite: `~/d/prism/.worktrees/noctalia-v5-plugin/integrations/noctalia-plugin/contract.test.mjs`
- Rewrite: `~/d/prism/.worktrees/noctalia-v5-plugin/test/plugin-client.test.js`
- Delete: `~/d/prism/.worktrees/noctalia-v5-plugin/integrations/noctalia-plugin/manifest.json`
- Delete: `~/d/prism/.worktrees/noctalia-v5-plugin/integrations/noctalia-plugin/Main.qml`
- Delete: `~/d/prism/.worktrees/noctalia-v5-plugin/integrations/noctalia-plugin/BarWidget.qml`
- Delete: `~/d/prism/.worktrees/noctalia-v5-plugin/integrations/noctalia-plugin/Panel.qml`
- Delete: `~/d/prism/.worktrees/noctalia-v5-plugin/integrations/noctalia-plugin/ParamControl.qml`
- Delete: `~/d/prism/.worktrees/noctalia-v5-plugin/integrations/noctalia-plugin/PrismClient.qml`
- Delete: `~/d/prism/.worktrees/noctalia-v5-plugin/integrations/noctalia-plugin/presentation.mjs`
- Delete: `~/d/prism/.worktrees/noctalia-v5-plugin/integrations/noctalia-plugin/queue.mjs`

**Interfaces:**
- Widget `onClick` writes `barWidget.outputName()` through `noctalia.state.set("originOutput", output)` and calls `noctalia.togglePanel("khughitt/prism:panel")`.
- Panel reads `noctalia.state.get("originOutput")`, falling back to `noctalia.focusedOutputName()` only when absent.
- `run(argv, callback)` converts argv through `Shell.command` and calls `noctalia.runAsync(command, callback, 10000)`.
- `onOpen(context)`, `onClose()`, and `onFrameTick(deltaMs)` own panel lifecycle. Frame ticks are requested only during an active live drag.
- The queue module from Task 2 remains the sole serialization point for `prism set`, `prism unset`, preview show, and preview hide.

- [ ] **Step 1: Rewrite the manifest contract test for v5 and confirm RED**

From the Node test, spawn `python3 -c` to parse `plugin.toml` with standard-library `tomllib` and print JSON, then parse that stdout in Node. Assert:

```js
assert.equal(manifest.id, 'khughitt/prism');
assert.equal(manifest.plugin_api, 22);
assert.ok(manifest.plugin_api <= 23);
assert.deepEqual(manifest.dependencies, ['prism', 'qs']);
assert.deepEqual(manifest.widget, [{ id: 'widget', entry: 'widget.luau' }]);
assert.deepEqual(manifest.panel, [{
  id: 'panel', entry: 'panel.luau', width: 588, height: 798,
  placement: 'attached', position: 'auto',
}]);
assert.equal(manifest.setting, undefined);
```

Also assert both entry files exist and `manifest.json` and all six QML files do not.

Run:

```bash
node --test integrations/noctalia-plugin/contract.test.mjs
```

Expected: failure because only the v4 manifest exists.

- [ ] **Step 2: Add the v5 manifest and minimal widget**

Use this manifest shape, retaining the geometry provenance comment:

```toml
id = "khughitt/prism"
name = "Prism"
description = "Control Prism appearance and glass preview from Noctalia"
version = "1.0.0"
author = "Keith Hughitt"
plugin_api = 22
dependencies = ["prism", "qs"]

[[widget]]
id = "widget"
entry = "widget.luau"

[[panel]]
id = "panel"
entry = "panel.luau"
# Preserve the v4 560x760 preferred size at dotfiles' tracked 1.05 UI scale.
width = 588
height = 798
placement = "attached"
position = "auto"
```

The widget renders the existing monochrome `wand` glyph, stores the originating output, and toggles the fully qualified panel ID. It contains no screen-coordinate or opposite-side logic.

- [ ] **Step 3: Rewrite the lifecycle contract test before the panel**

Replace QML regexes with assertions against `widget.luau` and `panel.luau`. Require the source contract to contain:

- `barWidget.outputName()` and `noctalia.state.set("originOutput", output)` before `togglePanel("khughitt/prism:panel")`;
- `noctalia.state.get("originOutput")` in the panel;
- `noctalia.focusedOutputName()` fallback;
- `require("presentation")`, `require("queue")`, and `require("shell")`;
- string-form `noctalia.runAsync` only through `Shell.command`;
- `panel.setNeedsFrameTick(true)` only when a live drag begins and `false` at release/close;
- `onFrameTick` plus a 100 ms threshold;
- `onDragEnd` enqueueing a non-sample final write;
- `onClose` enqueueing preview hide;
- literal preview side `left`;
- `noctalia.openColorPicker` and visible `errorText` handling;
- no `oppositeSide`, `manifest.json`, `.qml`, or direct string interpolation into subprocess commands.

Run `node --test test/plugin-client.test.js` and expect RED because the panel has not been written.

- [ ] **Step 4: Implement the single panel runtime**

Keep the state in `panel.luau`; do not add a client class or service entry. The state table contains:

```lua
local state = {
  model = nil,
  errorText = nil,
  queue = Queue.new(),
  batchAffectsParams = false,
  refreshPending = false,
  describeInvalidated = false,
  refreshAfterDrag = false,
  drag = nil,
  sampleElapsedMs = 0,
  previewVisible = false,
  diagnosticBackground = false,
  expandedGroups = {},
}
```

Implement these exact lifecycle functions:

```lua
function onOpen(context) refresh() end

function onClose()
  state.drag = nil
  state.sampleElapsedMs = 0
  panel.setNeedsFrameTick(false)
  enqueue({verb = "preview-hide"})
end

function onFrameTick(deltaMs)
  if not state.drag or not state.drag.pendingSample then return end
  state.sampleElapsedMs = state.sampleElapsedMs + deltaMs
  if state.sampleElapsedMs < 100 then return end
  state.sampleElapsedMs = 0
  enqueue(state.drag.pendingSample)
  state.drag.pendingSample = nil
end
```

`refresh()` runs `prism describe --json`, validates a top-level parameter array and each visible parameter's `key`, `value`, `default`, `modified`, `ui.control`, and `ui.group`, and preserves the last valid model on error. If a describe began before/during a drag, discard its result, set `refreshAfterDrag`, and replay after release.

`enqueue(item)` and the run callback use `Queue.enqueue`/`Queue.finish`. Treat launch rejection, timeout, non-zero exit, invalid JSON, and invalid shape as `errorText`; never dequeue the next item until the callback completes. Refresh after a drained parameter batch unless the tail is an active sample.

- [ ] **Step 5: Render every presentation control**

Build one scrollable declarative tree from `Presentation.titleParam(model.params)` and `Presentation.groupParams(model.params)`:

| Model value | Native control | Write boundary |
| --- | --- | --- |
| `ui.control = "toggle"` | toggle | non-sample `prism set` on change |
| `ui.control = "select"` | select | selected key through non-sample `prism set` |
| `ui.control = "slider"`, `effectiveDrag = "live"` | slider | local update on change, sampled write at most every 100 ms, final non-sample write on drag end |
| `ui.control = "slider"`, `effectiveDrag = "release"` | slider | local update on change, one non-sample write on drag end |
| `ui.control = "color"` | color button | `openColorPicker`, then non-sample `prism set` |

Each slider row renders `Presentation.formatValue(param.value, param)` beside
the native control. For normalized and logarithmic sliders, preserve the zero
presentation step and recognize Noctalia's exact 5%-of-range discrete delta at
release; route that direction through `Presentation.stepCanonicalValue` before
the final write. Other slider values retain the pointer mapping.

Title is the sole header toggle. Quick renders first and always expanded. Other groups persist expansion in `state.expandedGroups`, show modified counts, and enqueue one `unset` per modified parameter on group reset. Each modified row has its own `unset`. Controls with `effectiveDrag == nil` remain visible but disabled.

When preview is active, controls without `ui.affectsPreview == true` remain usable at reduced opacity with `Not in preview`. Diagnostics contains Preview and Diagnostic background toggles. Preview show argv is exactly:

```lua
{"qs", "-c", "niri-glass", "ipc", "call", "prismGlass",
 "showPreview", originOutput(), "left", tostring(state.diagnosticBackground)}
```

Preview hide argv is exactly:

```lua
{"qs", "-c", "niri-glass", "ipc", "call", "prismGlass", "hidePreview"}
```

- [ ] **Step 6: Remove v4 files and run all static/plugin gates**

```bash
cd ~/d/prism/.worktrees/noctalia-v5-plugin
noctalia plugins lint integrations/noctalia-plugin
npm test
```

Expected: lint reports zero errors/warnings, direct Lua tests pass, and all Node tests pass. The static manifest test—not lint—proves API 22, exact entry count, and absence of settings/v4 files.

- [ ] **Step 7: Commit the v5 Prism plugin**

```bash
git add integrations/noctalia-plugin test/plugin-client.test.js package.json
git commit -m "feat(noctalia): port Prism plugin to v5"
```

---

### Task 4: Document and Verify the Prism Contract

**Files:**
- Modify: `~/d/prism/.worktrees/noctalia-v5-plugin/README.md`
- Modify: `~/d/prism/.worktrees/noctalia-v5-plugin/docs/notes/noctalia-plugin-contract.md`

**Interfaces:**
- Consumes: the complete v5 plugin from Task 3.
- Produces: public documentation for canonical ID, entry names, API 22, standard-Lua module tests, queue ownership, preview placement, and runtime-close acceptance.

- [ ] **Step 1: Rewrite the contract document from the implemented files**

Replace v4 claims about `manifest.json`, QML injection, SmartPanel destruction, `plugins.json`, and `plugin:<key>`. Document:

```text
canonical id: khughitt/prism
widget entry: khughitt/prism:widget
panel entry: khughitt/prism:panel
plugin API: 22
backends: prism, qs -c niri-glass
preview side: left
production core tests: npm run test:plugin-lua
```

State that panel-runtime survival after close is verified live before cutover, not promised by lint or manifest metadata.

Add `lua` to Prism's development prerequisites in `README.md` and name `npm run test:plugin-lua` as the direct Noctalia plugin contract check. Do not add a package dependency; the production plugin still runs inside Noctalia.

- [ ] **Step 2: Scan Prism docs for stale v4 claims**

```bash
rg -n 'manifest\.json|Main\.qml|BarWidget\.qml|Panel\.qml|plugin:<|plugins\.json|Noctalia v4' \
  README.md docs integrations --glob '*.md'
```

Expected: no user-facing stale claim. References in git history do not count.

- [ ] **Step 3: Run the full Prism suite and commit docs**

```bash
npm test
git add README.md docs/notes/noctalia-plugin-contract.md
git commit -m "docs(noctalia): document Prism v5 plugin"
```

---

### Task 5: Replace Wali Panel with a Native v5 Plugin

**Files:**
- Create: `noctalia/plugins/wali-panel/plugin.toml`
- Create: `noctalia/plugins/wali-panel/shell.luau`
- Create: `noctalia/plugins/wali-panel/logic.luau`
- Create: `noctalia/plugins/wali-panel/widget.luau`
- Create: `noctalia/plugins/wali-panel/panel.luau`
- Create: `noctalia/plugins/wali-panel/plugin_test.lua`
- Create: `noctalia/plugins/wali-panel/README.md`
- Delete: `noctalia/plugins/wali-panel/manifest.json`
- Delete: `noctalia/plugins/wali-panel/Main.qml`
- Delete: `noctalia/plugins/wali-panel/BarWidget.qml`
- Delete: `noctalia/plugins/wali-panel/Panel.qml`
- Modify: `tests/setup_and_health.zsh`
- Modify: `justfile`

**Interfaces:**
- Widget toggles `khughitt/wali-panel:panel`.
- Panel calls `walictl current --json`, `backward`, `forward`, `random`, `save-current`, and `edit-current` only.
- `shell.luau` exposes the same `quote` and `command` contract as Prism's repository-local helper; cross-repository sharing is deliberately avoided.
- `logic.luau` exposes `commandFor(action)`, `decodeCurrent(text, decoder)`, `validateCurrent(payload)`, `refreshAfter(action)`, `canStart(busy)`, and `canCopy(sourcePath)` for direct Lua tests.
- `current --json` accepts only an object containing boolean `ok` and string-or-null `current_wallpaper_path`, `source_wallpaper_path`, `parsed_date`, and `display_date`.

- [ ] **Step 1: Write failing manifest and behavior tests**

Extend the embedded Python contract in `tests/setup_and_health.zsh` to parse `plugin.toml` and assert:

```python
wali = tomllib.load(open(wali_manifest, "rb"))
assert wali["id"] == "khughitt/wali-panel"
assert wali["plugin_api"] == 22
assert wali["plugin_api"] <= 23
assert wali["dependencies"] == ["walictl"]
assert wali["widget"] == [{"id": "widget", "entry": "widget.luau"}]
assert wali["panel"] == [{
    "id": "panel", "entry": "panel.luau", "width": 588, "height": 798,
    "placement": "attached", "position": "auto",
}]
assert "setting" not in wali
```

Add `plugin_test.lua` that loads `shell.luau` and `logic.luau` with `dofile` and asserts:

- all six walictl argv arrays are exact;
- a source path containing spaces and `'` is safely quoted;
- missing `ok`, non-string path/date fields, and invalid JSON become errors;
- successful navigation schedules a second `current --json` call;
- only one action can run at a time;
- copy calls `copyToClipboard(sourcePath, "text/plain")` only when a source exists.

- [ ] **Step 2: Run the focused tests and confirm RED**

```bash
lua noctalia/plugins/wali-panel/plugin_test.lua
zsh tests/setup_and_health.zsh
```

Expected: missing `.luau`/`plugin.toml` failures.

- [ ] **Step 3: Add the v5 manifest and shared shell helper**

Use:

```toml
id = "khughitt/wali-panel"
name = "Wali Panel"
description = "Browse and manage the current Noctalia wallpaper"
version = "1.0.0"
author = "Keith Hughitt"
plugin_api = 22
dependencies = ["walictl"]

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

Copy the eight-line POSIX quote/command implementation from Prism's `shell.luau`; do not introduce a shared external module or dependency. Implement `logic.luau` as one table containing the six fixed command arrays, protected JSON decoding through the injected decoder, strict current-payload field checks, the navigation refresh predicate, and the two boolean guards named in the Interfaces block. Production calls `Logic.decodeCurrent(result.stdout, json.decode)`; the Lua test passes one decoder that returns a table and one that raises an error.

- [ ] **Step 4: Implement the widget and panel**

The widget renders a wallpaper glyph and calls:

```lua
noctalia.togglePanel("khughitt/wali-panel:panel")
```

The panel state is deliberately small:

```lua
local state = {
  busy = false,
  loading = false,
  errorText = nil,
  currentPath = nil,
  sourcePath = nil,
  parsedDate = nil,
  displayDate = nil,
}
```

Every command uses `noctalia.runAsync(Shell.command(argv), callback, 10000)`. Reject `false` launch results, `timedOut`, non-zero `exitCode`, JSON errors, and wrong field types with visible `errorText`. Clear `busy` on every callback path.

Map controls exactly:

| Action | argv | Success behavior |
| --- | --- | --- |
| Refresh/open | `{"walictl","current","--json"}` | validate and render metadata |
| Previous | `{"walictl","backward"}` | refresh current metadata |
| Next | `{"walictl","forward"}` | refresh current metadata |
| Random | `{"walictl","random"}` | refresh current metadata |
| Save | `{"walictl","save-current"}` | native success notification |
| Edit | `{"walictl","edit-current"}` | native success notification |
| Copy | no subprocess | `copyToClipboard(sourcePath, "text/plain")` |

Render the best available image (`currentPath`, then `sourcePath`), source path, parsed/display date, error row, and seven controls. Disable all subprocess actions while `busy`; disable copy when `sourcePath == nil`. A new panel open calls refresh and can recover from a prior error.

- [ ] **Step 5: Remove v4 sources and document runtime requirements**

Delete the four v4 files. In `README.md`, document API 22, canonical entries, the `walictl` dependency, `BACKGROUND_IMG_DIR`, `WALI_DIR`, and the GIMP requirement for `edit-current`. Append the prerequisite check and production contract after the existing Python and Zsh lines in the `just test` recipe:

```just
@command -v lua >/dev/null || { echo 'lua is required for the Noctalia plugin tests' >&2; exit 127; }
lua noctalia/plugins/wali-panel/plugin_test.lua
```

Extend `tests/justfile.zsh` to assert both lines occur after `zsh tests/justfile.zsh` in the dry-run output:

```zsh
test_lines=("${(@f)test_dry_run}")
existing_tests_at=${test_lines[(i)*zsh tests/justfile.zsh*]}
lua_guard_at=${test_lines[(i)*command -v lua*]}
lua_test_at=${test_lines[(i)*lua noctalia/plugins/wali-panel/plugin_test.lua*]}
(( existing_tests_at < lua_guard_at && lua_guard_at < lua_test_at )) || \
  fail "Wali Lua test must run after the existing dotfiles suite"
```

This preserves the existing suite's diagnostics on machines without Lua and then fails with the same explicit prerequisite used by Prism.

- [ ] **Step 6: Run Wali's focused gates**

```bash
noctalia plugins lint noctalia/plugins/wali-panel
just test
```

Expected: direct Lua test, manifest contract, linter, existing walictl backend suite, and setup suite all pass.

- [ ] **Step 7: Commit Wali v5**

```bash
git add noctalia/plugins/wali-panel tests/setup_and_health.zsh justfile
git commit -m "feat(noctalia): port Wali panel to v5"
```

---

### Task 6: Integrate the Plugin Widgets and Health Contract

**Files:**
- Modify: `noctalia/config.toml:22-29`
- Modify: `tests/setup_and_health.zsh:184-238,807-850,998-1020`
- Modify: `tests/justfile.zsh`
- Modify: `justfile`
- Modify: `bin/dotfiles-health:1-30,185-230`

**Interfaces:**
- Consumes: local source directories and setup links from Tasks 1, 3, and 5.
- Produces: exact default bar order and health failure for missing/wrong/v4 links or either plugin not enabled.
- Health recognizes only lines matching `^khughitt/wali-panel .* enabled$` and `^khughitt/prism .* enabled$` from `noctalia msg plugins list`.
- `dotfiles-health --skip-noctalia-ipc` skips only the live enabled-state query; link, manifest, config-validation, and template checks still run.
- `just health` and `just verify` remain safe without a running shell; `just health-live` and `just health-systemd` retain runtime checks.

- [ ] **Step 1: Tighten the tracked configuration contract and confirm RED**

Change the Python assertion to:

```python
assert config["bar"]["default"]["end"] == [
    "tray", "battery", "notifications", "output_volume",
    "khughitt/prism:widget", "khughitt/wali-panel:widget", "clock",
]
assert "plugins" not in config
assert not any(name.startswith("khughitt/") for name in config.get("widget", {}))
```

Run `zsh tests/setup_and_health.zsh`; expect RED because the built-in `wallpaper` remains.

- [ ] **Step 2: Update the bar list only**

Use the exact end list above. Do not add `[widget.*]` aliases and do not add `[plugins] enabled`.

- [ ] **Step 3: Add failing installed-topology and health tests**

Extend the setup test to assert:

```zsh
[[ -L "${tmp}/data/noctalia/plugins/wali-panel" ]]
[[ -L "${tmp}/data/noctalia/plugins/prism" ]]
[[ -f "${tmp}/data/noctalia/plugins/wali-panel/plugin.toml" ]]
[[ -f "${tmp}/data/noctalia/plugins/prism/plugin.toml" ]]
[[ ! -e "${tmp}/data/noctalia/plugins/wali-panel/manifest.json" ]]
[[ ! -e "${tmp}/data/noctalia/plugins/prism/manifest.json" ]]
```

For health, add separate tests that replace one symlink with a wrong target, substitute a fixture containing only `manifest.json`, omit Wali's enabled line, and omit Prism's enabled line. Each must return non-zero and name the failing plugin. Add one offline test where `NOCTALIA_PLUGIN_LIST='other/plugin [local] 1.0.0 disabled'` fails normally but the same static fixture passes with `--skip-noctalia-ipc`; repeat the wrong-link case with the flag to prove it skips no static check.

- [ ] **Step 4: Run the focused tests and confirm RED**

```bash
zsh tests/setup_and_health.zsh
```

Expected: failures because health does not inspect the data directory or enabled list.

- [ ] **Step 5: Add the explicit offline-health option**

Initialize and parse the flag beside `SKIP_SYSTEMD`:

```bash
SKIP_NOCTALIA_IPC=false

case "$1" in
    --skip-noctalia-ipc)
        SKIP_NOCTALIA_IPC=true
        shift
        ;;
esac
```

Update usage to `dotfiles-health [--skip-systemd] [--skip-noctalia-ipc]` and describe it as skipping live Noctalia plugin enablement only. Do not infer this state from SSH, TTY, `DISPLAY`, or `WAYLAND_DISPLAY`.

Update and test the recipes explicitly:

```just
health:
    bin/dotfiles-health --skip-systemd --skip-noctalia-ipc

health-live:
    bin/dotfiles-health --skip-systemd

health-systemd:
    bin/dotfiles-health
```

`verify: check test health` remains unchanged and therefore uses the offline-safe recipe. Add `health-live` and `health-systemd` to the recipe-list assertion in `tests/justfile.zsh`, and assert all three command lines exactly rather than by substring.

- [ ] **Step 6: Implement the static and live health checks**

Add `XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"` near existing XDG defaults. In the Linux Noctalia block:

```bash
noctalia_plugin_dir="${XDG_DATA_HOME}/noctalia/plugins"
check_link "${noctalia_plugin_dir}/wali-panel" \
    "${DOTS_HOME}/noctalia/plugins/wali-panel"
check_link "${noctalia_plugin_dir}/prism" \
    "${HOME}/d/prism/integrations/noctalia-plugin"

for plugin_name in wali-panel prism; do
    if [[ -f "${noctalia_plugin_dir}/${plugin_name}/plugin.toml" && \
          ! -e "${noctalia_plugin_dir}/${plugin_name}/manifest.json" ]]; then
        pass "Noctalia v5 plugin manifest: ${plugin_name}"
    else
        fail "missing or stale Noctalia plugin manifest: ${plugin_name}"
    fi
done
```

Unless `SKIP_NOCTALIA_IPC` is true, run `noctalia msg plugins list` once. Require:

```bash
printf '%s\n' "$plugins" | rg -q '^khughitt/wali-panel .* enabled$'
printf '%s\n' "$plugins" | rg -q '^khughitt/prism .* enabled$'
```

Report a distinct failure for each missing enabled line. A command failure is a health failure, not a warning. With the flag, print one `[OK]` line stating that the live plugin check was explicitly skipped.

- [ ] **Step 7: Run all dotfiles automated gates**

```bash
noctalia config validate noctalia
noctalia plugins lint noctalia/plugins/wali-panel
zsh tests/setup_and_health.zsh
just test
```

Expected: config validation contains no `WARN`/`ERROR`, plugin lint is clean, and the full suite passes. Remember that config validation does not validate the bar widget IDs; the Python assertions do.

- [ ] **Step 8: Commit integration**

```bash
git add noctalia/config.toml bin/dotfiles-health justfile \
  tests/setup_and_health.zsh tests/justfile.zsh
git commit -m "feat(noctalia): install local v5 plugins"
```

---

### Task 7: Correct User Documentation and Design Status

**Files:**
- Modify: `noctalia/noctalia.md`
- Modify: `noctalia/noctalia-wallpaper-switcher.md`
- Modify: `docs/specs/2026-08-20-noctalia-v5-plugin-ports-design.md`

**Interfaces:**
- Consumes: verified implementations in both repositories.
- Produces: accurate activation, ownership, dependency, and status claims.

- [ ] **Step 1: Replace the deferred-plugin claims**

In `noctalia/noctalia.md`, state that Wali and Prism are local v5 plugins while Memory Pressure Alert remains deferred. Document the two-stage bootstrap exactly:

```bash
./setup.sh
# Start or reload Noctalia v5, then:
./setup.sh --only noctalia-plugins
```

Explain that ordinary setup stays usable before the shell starts; the explicit phase links both sources, requires `~/d/prism`, and fails when Noctalia IPC is unavailable.

In `noctalia/noctalia-wallpaper-switcher.md`, replace the built-in-widget/no-UI claim with the Wali widget/panel entry IDs and note that `walictl` remains the backend.

- [ ] **Step 2: Scan all user-facing docs for propagated drift**

```bash
rg -n 'Wali Panel.*deferred|Prism.*deferred|no Wali Panel|built-in.*wallpaper|manifest\.json|Noctalia v4' \
  noctalia docs README.md --glob '*.md'
rg -n 'docs\.noctalia\.dev/v5' . --glob '*.md'
```

Expected: no stale claims and no old `/v5/` documentation URLs. Correct every user-facing match in this same task.

- [ ] **Step 3: Mark the design implemented only after fresh verification**

Run:

```bash
just test
npm test --prefix ~/d/prism/.worktrees/noctalia-v5-plugin
```

Only after both exit 0, change the design header to:

```markdown
**Status:** Implemented; automated verification complete, live acceptance pending.
```

Do not check off live acceptance or claim the branches are merged.

- [ ] **Step 4: Commit documentation**

```bash
git add noctalia/noctalia.md noctalia/noctalia-wallpaper-switcher.md \
  docs/specs/2026-08-20-noctalia-v5-plugin-ports-design.md
git commit -m "docs(noctalia): document restored v5 plugins"
```

---

### Task 8: Final Automated Review, Landing, and Live Acceptance

**Files:**
- Verify only; any defect found returns to the task that owns it.

**Interfaces:**
- Consumes: green Prism and dotfiles branches.
- Produces: merge-ready branches, then a verified live cutover.

- [ ] **Step 1: Run a fresh two-repository verification**

Use `superpowers:verification-before-completion`:

```bash
cd ~/d/prism/.worktrees/noctalia-v5-plugin
noctalia plugins lint integrations/noctalia-plugin
npm test
git status --short

cd ~/d/dotfiles/.worktrees/noctalia-v5-plugins
noctalia plugins lint noctalia/plugins/wali-panel
noctalia config validate noctalia
just test
git status --short
```

Expected: all commands exit 0; config validation has no warning/error; both worktrees are clean.

- [ ] **Step 2: Review the diffs for forbidden leftovers**

```bash
git -C ~/d/prism/.worktrees/noctalia-v5-plugin diff main...HEAD --check
git diff main...HEAD --check
rg -n 'manifest\.json|\.qml|oppositeSide|plugin:<|\[plugins\]|\[widget\.' \
  noctalia ~/d/prism/.worktrees/noctalia-v5-plugin/integrations/noctalia-plugin
```

Expected: no whitespace errors. The scan must find no v4 plugin source, `oppositeSide`, tracked plugin enablement, or plugin widget alias. Mentions in historical design rationale are acceptable only when explicitly describing rejection/removal.

- [ ] **Step 3: Request code review**

Use `superpowers:requesting-code-review` on the Prism diff first and the dotfiles diff second. Resolve correctness findings in the owning task and rerun its full suite.

- [ ] **Step 4: Merge in dependency order**

Use `superpowers:finishing-a-development-branch`:

1. Merge `feat/noctalia-v5-plugin` into Prism main.
2. Rebase the dotfiles branch if main advanced, rerun `just test`, then merge dotfiles.
3. Run all live commands from the two main checkouts, never from disposable worktrees.

- [ ] **Step 5: Remove the stale live v4 template registry**

Resolve the exact path first:

```bash
ls -l ~/.config/noctalia/user-templates.toml
```

If present, move it outside the `*.toml` loader pattern to a recoverable backup such as `~/.config/noctalia/user-templates.toml.v4-backup`. Do not delete unrelated state.

- [ ] **Step 6: Install and enable from dotfiles main**

```bash
cd ~/d/dotfiles
./setup.sh --only app-config
# Ensure Noctalia v5 is running.
./setup.sh --only noctalia-plugins
```

Expected: both local links point into main checkouts and both enable calls succeed.

- [ ] **Step 7: Run the enablement preflight**

```bash
noctalia config export merged | sed -n '/\[plugins\]/,/^\[/p'
plugins=$(noctalia msg plugins list)
for id in khughitt/wali-panel khughitt/prism; do
  printf '%s\n' "$plugins" | rg -q "^${id} .* enabled$" || exit 1
  rg -q "loaded plugin '${id}' \(2 entries\)" \
    ~/.cache/noctalia/noctalia.log || exit 1
done
dotfiles-health
```

Expected: merged state contains both IDs, both list lines end in `enabled`, both log lines report exactly two entries, and health exits 0. Stop before UI acceptance if any check fails.

- [ ] **Step 8: Test Prism runtime survival before other parity checks**

Open Prism, start a deliberately observable queued write, close the panel before it completes, and confirm both that write and queued preview-hide finish. If either is lost, stop the cutover; queue ownership must move out of the close-destroyed runtime before acceptance continues.

- [ ] **Step 9: Complete live behavioral acceptance**

Verify:

1. Both widgets render and open attached 588 by 798 panels without clipping or double-scaling.
2. `~/.cache/noctalia/noctalia.log` contains no Luau compile, timeout, or runtime errors for either plugin.
3. Wali refresh, previous, next, random, copy, save, edit, and unavailable-source error all work.
4. Prism renders all visible `prism describe --json` parameters.
5. Toggle, slider, select, and color writes reconcile to authoritative values.
6. Individual and group reset work.
7. Live sliders sample no faster than 100 ms; release-only sliders write only at drag end.
8. Preview uses the originating output, left side, diagnostic background, and hides on close.
9. `noctalia config validate ~/.config/noctalia` is warning-free.

The user will capture any submission screenshots after this acceptance; do not add screenshots to either repository during implementation.

- [ ] **Step 10: Update the design's final status after live acceptance**

Change:

```markdown
**Status:** Implemented and live-verified.
```

Commit that status correction on dotfiles main with:

```bash
git add docs/specs/2026-08-20-noctalia-v5-plugin-ports-design.md
git commit -m "docs(noctalia): record plugin cutover"
```
