# Niri Workspace Profiles — Phase 2 (Selector) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `Mod+P` Quickshell popup that lists workspace profiles and switches to them (or opens a new instance), driven by a JSON view model the daemon emits.

**Architecture:** The Phase 1 daemon (`wsprofiled`) gains a second generated artifact — `~/.config/niri/wsprofiles.json` — written transactionally alongside `profiles.kdl`. A standalone resident Quickshell config (`wsprofile-menu`) reads that JSON, renders a centered vertical list, and routes every selection through the existing `wsprofilectl open|new <id>` control client, so menu/keyboard/modifier switches all share Phase 1's one tested code path. All non-trivial logic is pure JS (node-tested); QML is thin rendering + a key-event adapter.

**Tech Stack:** Node ≥20 ESM + `node:test` (daemon side, no new npm deps — JSON is built-in); Quickshell/QML (Qt6) for the popup; niri KDL config.

## Global Constraints

- Node ≥20, ESM (`"type": "module"`), tests via `node --test` using `node:test` + `node:assert/strict`. Copy the Phase 1 test style exactly.
- **No new npm dependencies.** The view model serializes with built-in `JSON`.
- Daemon-side pure modules live in `~/d/dotfiles/wsprofiles/src/` as ESM; menu-side pure logic lives in `~/d/dotfiles/wsprofiles/menu/menu-logic.js` as a **classic QML JS library** (`.pragma library` + top-level `function` declarations, **no** `export`), node-tested via a `node:vm` loader.
- The view-model file is `~/.config/niri/wsprofiles.json` (beside `profiles.kdl` at `~/.config/niri/profiles.kdl`).
- Quickshell `Process` runs **no shell**: argv[0] (`node`, `kitty`) resolves on `PATH`, but every path argument must be absolute (resolve `~` via `Quickshell.env("HOME")`). No `~` in argv.
- Keyboard focus: `WlrLayershell.keyboardFocus` is `WlrKeyboardFocus.OnDemand` while shown, `WlrKeyboardFocus.None` while hidden.
- Digits come from `event.key` (`Qt.Key_1..Qt.Key_9`), never `event.text`; `Shift` only selects `new` vs `open`. `'+'` comes from `event.text`.
- Profile `id` grammar and color rules are inherited from Phase 1 (`ID_RE = /^[a-z][a-z0-9-]*$/`, no `-<digits>` suffix); the selector never re-validates — it trusts the daemon-emitted JSON.
- Use `~/d/...` (not `/home/keith/...` or `/mnt/ssd/...`) in any committed paths/docs.
- Phase 1 catalog/profile shape (from `src/catalog.js`): each profile is
  `{ id, label, instances, ring, border|null, icon, theme: { colorscheme|null, wallpaper|null, mode|null } }`.

---

## File Structure

**Daemon side (`~/d/dotfiles/wsprofiles/`):**
- Create `src/viewmodel.js` — `viewModel(catalog)` → array of `{id,label,icon,ring,border,instances}`.
- Create `src/artifacts.js` — `serializeViewModel(catalog)` and `applyCatalog({catalog,kdlPath,jsonPath,loadConfig})` (transactional write+reload+rollback of both KDL and JSON).
- Modify `bin/wsprofiled` — emit JSON via `applyCatalog` at startup and on catalog reload; add `JSON_OUT`.
- Tests: `test/viewmodel.test.js`, `test/artifacts.test.js`.

**Menu side (`~/d/dotfiles/wsprofiles/menu/`):**
- Create `menu/menu-logic.js` — `parseProfiles`, `keyToAction`, `clampHighlight` (classic QML JS library).
- Create `menu/menu-logic.test.js` — node:test via `vm` loader.
- Create `menu/shell.qml` — the popup (IPC toggle, FileView, render, key adapter, spawns).

**Integration:**
- Symlink `~/.config/quickshell/wsprofile-menu` → `~/d/dotfiles/wsprofiles/menu` (Task 5).
- Modify `~/d/dotfiles/niri/config.kdl` — `spawn-at-startup` the menu + `Mod+P` toggle bind (Task 7).

---

## Task 1: View-model emitter

**Files:**
- Create: `~/d/dotfiles/wsprofiles/src/viewmodel.js`
- Test: `~/d/dotfiles/wsprofiles/test/viewmodel.test.js`

**Interfaces:**
- Consumes: a Phase 1 catalog object `{ profiles: [{id,label,instances,ring,border,icon,theme}] }`.
- Produces: `viewModel(catalog) -> Array<{ id:string, label:string, icon:string, ring:string, border:string|null, instances:number }>`, in catalog order.

- [ ] **Step 1: Write the failing test**

Create `~/d/dotfiles/wsprofiles/test/viewmodel.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { viewModel } from '../src/viewmodel.js';

const catalog = { profiles: [
  { id: 'ember', label: 'Ember — client-api', instances: 1,
    ring: '#ff7a45', border: '#ff7a45', icon: '',
    theme: { colorscheme: 'Tokyo Night', wallpaper: null, mode: 'dark' } },
  { id: 'tide', label: 'Tide — infra', instances: 2,
    ring: '#3aa6ff', border: null, icon: '',
    theme: { colorscheme: 'Catppuccin', wallpaper: null, mode: 'dark' } },
] };

test('maps id/label/icon/ring/instances in catalog order', () => {
  const vm = viewModel(catalog);
  assert.equal(vm.length, 2);
  assert.deepEqual(vm[0], {
    id: 'ember', label: 'Ember — client-api', icon: '',
    ring: '#ff7a45', border: '#ff7a45', instances: 1,
  });
  assert.equal(vm[1].id, 'tide');
});

test('emits border null when absent, hex when present', () => {
  const vm = viewModel(catalog);
  assert.equal(vm[0].border, '#ff7a45');
  assert.equal(vm[1].border, null);
});

test('omits theme and other internal fields', () => {
  const vm = viewModel(catalog);
  assert.equal('theme' in vm[0], false);
});

test('empty catalog yields empty array', () => {
  assert.deepEqual(viewModel({ profiles: [] }), []);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/viewmodel.test.js`
Expected: FAIL — `Cannot find module '../src/viewmodel.js'`.

- [ ] **Step 3: Write the minimal implementation**

Create `~/d/dotfiles/wsprofiles/src/viewmodel.js`:

```js
// Pure projection of a validated catalog into the menu's view model.
// Mirrors src/kdl.js: shell-agnostic, no I/O.
export function viewModel(catalog) {
  return catalog.profiles.map((p) => ({
    id: p.id,
    label: p.label,
    icon: p.icon,
    ring: p.ring,
    border: p.border,
    instances: p.instances,
  }));
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/viewmodel.test.js`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
cd ~/d/dotfiles
git add wsprofiles/src/viewmodel.js wsprofiles/test/viewmodel.test.js
git commit -m "feat(wsprofiles): catalog -> menu view model"
```

---

## Task 2: Artifact transaction

**Files:**
- Create: `~/d/dotfiles/wsprofiles/src/artifacts.js`
- Test: `~/d/dotfiles/wsprofiles/test/artifacts.test.js`

**Interfaces:**
- Consumes: `generateKdl(catalog)` from `src/kdl.js`; `viewModel(catalog)` from `src/viewmodel.js`.
- Produces:
  - `serializeViewModel(catalog) -> string` (pretty JSON + trailing newline).
  - `applyCatalog({ catalog, kdlPath, jsonPath, loadConfig }) -> Promise<void>` — captures both files' prior contents, writes both, awaits `loadConfig()`; on **any** failure restores both to prior contents (removing a file that did not exist before) and rethrows. It best-effort re-reloads **only if `loadConfig()` had already been attempted** — a write failure before the reload leaves niri on the still-current previous config, so no reload is needed. `loadConfig` is an injected `() => Promise<void>`.

- [ ] **Step 1: Write the failing test**

Create `~/d/dotfiles/wsprofiles/test/artifacts.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, existsSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { serializeViewModel, applyCatalog } from '../src/artifacts.js';

const catalogA = { profiles: [
  { id: 'ember', label: 'Ember', instances: 1, ring: '#ff7a45', border: '#ff7a45', icon: '', theme: {} },
] };
const catalogB = { profiles: [
  { id: 'ember', label: 'Ember', instances: 1, ring: '#ff7a45', border: '#ff7a45', icon: '', theme: {} },
  { id: 'tide', label: 'Tide', instances: 1, ring: '#3aa6ff', border: null, icon: '', theme: {} },
] };

function tmp() {
  const dir = mkdtempSync(join(tmpdir(), 'wsprofiles-'));
  return { dir, kdl: join(dir, 'profiles.kdl'), json: join(dir, 'wsprofiles.json') };
}

test('serializeViewModel is valid JSON ending in newline', () => {
  const text = serializeViewModel(catalogA);
  assert.equal(text.endsWith('\n'), true);
  assert.deepEqual(JSON.parse(text), [
    { id: 'ember', label: 'Ember', icon: '', ring: '#ff7a45', border: '#ff7a45', instances: 1 },
  ]);
});

test('success path writes both files', async () => {
  const t = tmp();
  try {
    await applyCatalog({ catalog: catalogB, kdlPath: t.kdl, jsonPath: t.json, loadConfig: async () => {} });
    assert.match(readFileSync(t.kdl, 'utf8'), /workspace "tide" \{/);
    assert.deepEqual(JSON.parse(readFileSync(t.json, 'utf8')).map((p) => p.id), ['ember', 'tide']);
  } finally { rmSync(t.dir, { recursive: true, force: true }); }
});

test('loadConfig rejection restores both files and best-effort reverts', async () => {
  const t = tmp();
  try {
    writeFileSync(t.kdl, 'PREV_KDL');
    writeFileSync(t.json, 'PREV_JSON');
    let reloads = 0;
    await assert.rejects(
      applyCatalog({ catalog: catalogB, kdlPath: t.kdl, jsonPath: t.json,
        loadConfig: async () => { reloads++; throw new Error('niri rejected'); } }),
      /niri rejected/);
    assert.equal(reloads, 2); // initial attempt + best-effort revert reload
    assert.equal(readFileSync(t.kdl, 'utf8'), 'PREV_KDL');
    assert.equal(readFileSync(t.json, 'utf8'), 'PREV_JSON');
  } finally { rmSync(t.dir, { recursive: true, force: true }); }
});

test('write failure before reload restores both and does NOT reload', async () => {
  const t = tmp();
  try {
    writeFileSync(t.kdl, 'PREV_KDL');
    writeFileSync(t.json, 'PREV_JSON');
    let reloads = 0;
    // Parent path component is a file, so writing under it throws ENOTDIR.
    const badJson = join(t.json, 'nope', 'x.json');
    await assert.rejects(
      applyCatalog({ catalog: catalogB, kdlPath: t.kdl, jsonPath: badJson,
        loadConfig: async () => { reloads++; } }));
    assert.equal(reloads, 0); // reload never attempted -> no revert reload
    assert.equal(readFileSync(t.kdl, 'utf8'), 'PREV_KDL'); // KDL restored
    assert.equal(readFileSync(t.json, 'utf8'), 'PREV_JSON'); // original JSON untouched
  } finally { rmSync(t.dir, { recursive: true, force: true }); }
});

test('startup with no prior files: rejection removes both freshly written files', async () => {
  const t = tmp();
  try {
    await assert.rejects(
      applyCatalog({ catalog: catalogB, kdlPath: t.kdl, jsonPath: t.json,
        loadConfig: async () => { throw new Error('reject'); } }),
      /reject/);
    assert.equal(existsSync(t.kdl), false);
    assert.equal(existsSync(t.json), false);
  } finally { rmSync(t.dir, { recursive: true, force: true }); }
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/artifacts.test.js`
Expected: FAIL — `Cannot find module '../src/artifacts.js'`.

- [ ] **Step 3: Write the minimal implementation**

Create `~/d/dotfiles/wsprofiles/src/artifacts.js`:

```js
import { existsSync, readFileSync, writeFileSync, unlinkSync } from 'node:fs';
import { generateKdl } from './kdl.js';
import { viewModel } from './viewmodel.js';

export function serializeViewModel(catalog) {
  return JSON.stringify(viewModel(catalog), null, 2) + '\n';
}

function readOrNull(path) {
  return existsSync(path) ? readFileSync(path, 'utf8') : null;
}

// "Previous contents" includes absence: a file that did not exist before is
// removed on restore, never left holding a never-accepted config.
function restore(path, prev) {
  if (prev === null) {
    if (existsSync(path)) unlinkSync(path);
  } else {
    writeFileSync(path, prev);
  }
}

// The KDL and JSON form one artifact transaction. Capture both prior contents
// before writing either; on any failure (a write throwing, or loadConfig
// rejecting) restore both and rethrow so the caller skips the catalog swap.
export async function applyCatalog({ catalog, kdlPath, jsonPath, loadConfig }) {
  const prevKdl = readOrNull(kdlPath);
  const prevJson = readOrNull(jsonPath);
  let reloadAttempted = false;
  try {
    writeFileSync(kdlPath, generateKdl(catalog));
    writeFileSync(jsonPath, serializeViewModel(catalog));
    reloadAttempted = true;
    await loadConfig();
  } catch (e) {
    restore(kdlPath, prevKdl);
    restore(jsonPath, prevJson);
    // Only re-reload when niri may already have loaded the rejected config. If a
    // write threw before the reload, niri still runs the previous config, which
    // now matches the restored files, so no reload is needed.
    if (reloadAttempted) {
      try { await loadConfig(); } catch { /* caller logs the primary failure */ }
    }
    throw e;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/artifacts.test.js`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
cd ~/d/dotfiles
git add wsprofiles/src/artifacts.js wsprofiles/test/artifacts.test.js
git commit -m "feat(wsprofiles): transactional KDL+JSON artifact write"
```

---

## Task 3: Wire the transaction into the daemon

**Files:**
- Modify: `~/d/dotfiles/wsprofiles/bin/wsprofiled`

**Interfaces:**
- Consumes: `applyCatalog` from `src/artifacts.js`; existing `loadConfig` from `src/niri.js`.
- Produces: at startup and on every catalog edit the daemon now writes `~/.config/niri/wsprofiles.json` alongside `profiles.kdl`, with the rollback guarantees from Task 2. No exported interface changes.

- [ ] **Step 1: Replace the KDL imports/constants**

In `~/d/dotfiles/wsprofiles/bin/wsprofiled`, change the import of `generateKdl` to `applyCatalog`. Find:

```js
import { loadCatalog } from '../src/catalog.js';
import { generateKdl } from '../src/kdl.js';
```

Replace with:

```js
import { loadCatalog } from '../src/catalog.js';
import { applyCatalog } from '../src/artifacts.js';
```

Then find:

```js
const KDL_OUT = `${homedir()}/.config/niri/profiles.kdl`;
```

Replace with:

```js
const KDL_OUT = `${homedir()}/.config/niri/profiles.kdl`;
const JSON_OUT = `${homedir()}/.config/niri/wsprofiles.json`;
```

- [ ] **Step 2: Replace the startup write/reload block**

Find this block (the startup `try`):

```js
try {
  catalog = loadCatalog(CATALOG);
  const prevKdl = existsSync(KDL_OUT) ? readFileSync(KDL_OUT, 'utf8') : null;
  writeFileSync(KDL_OUT, generateKdl(catalog));
  try {
    await loadConfig();
  } catch (e) {
    console.error('wsprofiled: initial niri reload failed:', e.message);
    if (prevKdl !== null) {
      writeFileSync(KDL_OUT, prevKdl);
      await loadConfig().catch((restoreError) =>
        console.error('wsprofiled: restoring previous niri config failed:', restoreError.message));
    }
    controlServer.close();
    process.exit(1);
  }
  daemon = buildDaemon(catalog);
} catch (e) {
  console.error('wsprofiled: startup failed:', e.message);
  controlServer.close();
  process.exit(1);
}
```

Replace with:

```js
try {
  catalog = loadCatalog(CATALOG);
} catch (e) {
  console.error('wsprofiled: startup failed:', e.message);
  controlServer.close();
  process.exit(1);
}
try {
  await applyCatalog({ catalog, kdlPath: KDL_OUT, jsonPath: JSON_OUT, loadConfig });
} catch (e) {
  console.error('wsprofiled: initial niri reload failed:', e.message);
  controlServer.close();
  process.exit(1);
}
daemon = buildDaemon(catalog);
```

- [ ] **Step 3: Replace the reload write/reload block**

Find the body of `reloadCatalog` after the parse guard:

```js
  const prevKdl = existsSync(KDL_OUT) ? readFileSync(KDL_OUT, 'utf8') : null;
  writeFileSync(KDL_OUT, generateKdl(next));
  try {
    await loadConfig();
  } catch (e) {
    console.error('wsprofiled: niri rejected new config, reverting:', e.message);
    if (prevKdl !== null) writeFileSync(KDL_OUT, prevKdl);
    await loadConfig().catch((restoreError) =>
      console.error('wsprofiled: restoring previous niri config failed:', restoreError.message));
    return;
  }
  catalog = next;
  daemon.updateCatalog(catalog);
```

Replace with:

```js
  try {
    await applyCatalog({ catalog: next, kdlPath: KDL_OUT, jsonPath: JSON_OUT, loadConfig });
  } catch (e) {
    console.error('wsprofiled: niri rejected new config, reverting:', e.message);
    return;
  }
  catalog = next;
  daemon.updateCatalog(catalog);
```

- [ ] **Step 4: Verify the full suite still passes**

Run: `cd ~/d/dotfiles/wsprofiles && node --test`
Expected: PASS — all Phase 1 tests plus `viewmodel`/`artifacts` green. (`bin/wsprofiled` has no unit test; its logic now lives in the tested `applyCatalog`.)

- [ ] **Step 5: Manual smoke (live niri session)**

```bash
# Restart the running daemon so the new entrypoint runs.
pkill -f 'wsprofiles/bin/wsprofiled' || true
node ~/d/dotfiles/wsprofiles/bin/wsprofiled &
sleep 1
cat ~/.config/niri/wsprofiles.json
```

Expected: a JSON array with one object per profile (`ember`, `tide`), each with `id/label/icon/ring/border/instances`. niri still reloads cleanly (rings unchanged).

- [ ] **Step 6: Commit**

```bash
cd ~/d/dotfiles
git add wsprofiles/bin/wsprofiled
git commit -m "feat(wsprofiles): daemon emits wsprofiles.json transactionally"
```

---

## Task 4: Menu interaction logic

**Files:**
- Create: `~/d/dotfiles/wsprofiles/menu/menu-logic.js`
- Test: `~/d/dotfiles/wsprofiles/menu/menu-logic.test.js`

**Interfaces:**
- Produces (all consumed by `shell.qml` in Tasks 5–6):
  - `parseProfiles(text) -> { profiles: Array, error: string|null }`.
  - `clampHighlight(highlight, profileCount) -> number` in `0..profileCount` (where `profileCount` is the "+ new" row index).
  - `keyToAction(key, modifiers, state) -> action|null`, where
    `key ∈ {'1'..'9','Enter','Escape','Up','Down','Tab','+'}`,
    `modifiers = { shift:boolean }`,
    `state = { profiles, highlight }`, and `action` is one of
    `{type:'open',id}` · `{type:'new',id}` · `{type:'move',highlight}` ·
    `{type:'editor'}` · `{type:'hide'}` · `null`.

- [ ] **Step 1: Create the menu directory and write the failing test**

```bash
mkdir -p ~/d/dotfiles/wsprofiles/menu
```

Create `~/d/dotfiles/wsprofiles/menu/menu-logic.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

// menu-logic.js is a classic QML JS library (".pragma library" + top-level
// functions, no ESM export) so QML can import it. Load it for node by stripping
// the pragma line and evaluating: top-level function declarations become
// properties of the vm context.
function loadLogic() {
  const path = fileURLToPath(new URL('./menu-logic.js', import.meta.url));
  const src = readFileSync(path, 'utf8').replace(/^\s*\.pragma\s+library\s*$/m, '');
  const context = {};
  vm.runInNewContext(src, context);
  return context;
}
const Logic = loadLogic();

const state = (profiles, highlight) => ({ profiles, highlight });
const P = [{ id: 'ember' }, { id: 'tide' }];

test('parseProfiles: valid array of well-shaped entries', () => {
  const text = JSON.stringify([{ id: 'ember', label: 'E', ring: '#fff' }]);
  const r = Logic.parseProfiles(text);
  assert.equal(r.error, null);
  assert.equal(r.profiles[0].id, 'ember');
});

test('parseProfiles: empty string is an error', () => {
  const r = Logic.parseProfiles('');
  assert.deepEqual(r.profiles, []);
  assert.ok(r.error);
});

test('parseProfiles: malformed JSON is an error', () => {
  const r = Logic.parseProfiles('{ not json');
  assert.ok(r.error);
});

test('parseProfiles: wrong shape is an error', () => {
  assert.ok(Logic.parseProfiles('{}').error);
  assert.ok(Logic.parseProfiles(JSON.stringify([{ id: 'x' }])).error); // missing label/ring
});

test('clampHighlight clamps into 0..profileCount', () => {
  assert.equal(Logic.clampHighlight(1, 2), 1);
  assert.equal(Logic.clampHighlight(5, 2), 2);
  assert.equal(Logic.clampHighlight(-3, 2), 0);
  assert.equal(Logic.clampHighlight(3, 0), 0);
});

test('digit opens the matching profile; shift opens a new instance', () => {
  assert.deepEqual(Logic.keyToAction('1', { shift: false }, state(P, 0)), { type: 'open', id: 'ember' });
  assert.deepEqual(Logic.keyToAction('2', { shift: true }, state(P, 0)), { type: 'new', id: 'tide' });
});

test('digit beyond profile count and digit 0 are no-ops', () => {
  assert.equal(Logic.keyToAction('3', { shift: false }, state(P, 0)), null);
  assert.equal(Logic.keyToAction('0', { shift: false }, state(P, 0)), null);
});

test('Enter on a profile row opens it; Shift+Enter opens a new instance', () => {
  assert.deepEqual(Logic.keyToAction('Enter', { shift: false }, state(P, 1)), { type: 'open', id: 'tide' });
  assert.deepEqual(Logic.keyToAction('Enter', { shift: true }, state(P, 0)), { type: 'new', id: 'ember' });
});

test('Enter on the +new row, and + from anywhere, open the editor', () => {
  assert.deepEqual(Logic.keyToAction('Enter', { shift: false }, state(P, 2)), { type: 'editor' });
  assert.deepEqual(Logic.keyToAction('+', { shift: false }, state(P, 0)), { type: 'editor' });
});

test('Down/Tab advance highlight and wrap past the +new row to the top', () => {
  assert.deepEqual(Logic.keyToAction('Down', { shift: false }, state(P, 1)), { type: 'move', highlight: 2 });
  assert.deepEqual(Logic.keyToAction('Tab', { shift: false }, state(P, 2)), { type: 'move', highlight: 0 });
});

test('Up and Shift+Tab move back and wrap', () => {
  assert.deepEqual(Logic.keyToAction('Up', { shift: false }, state(P, 0)), { type: 'move', highlight: 2 });
  assert.deepEqual(Logic.keyToAction('Tab', { shift: true }, state(P, 0)), { type: 'move', highlight: 2 });
});

test('Escape hides; unmapped key is null', () => {
  assert.deepEqual(Logic.keyToAction('Escape', { shift: false }, state(P, 0)), { type: 'hide' });
  assert.equal(Logic.keyToAction('x', { shift: false }, state(P, 0)), null);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd ~/d/dotfiles/wsprofiles && node --test menu/menu-logic.test.js`
Expected: FAIL — `ENOENT` reading `menu-logic.js`.

- [ ] **Step 3: Write the minimal implementation**

Create `~/d/dotfiles/wsprofiles/menu/menu-logic.js`:

```js
.pragma library

// Pure selector logic, shared by shell.qml (QML import) and node tests.
// Classic QML JS library: top-level function declarations, no ESM export.

function parseProfiles(text) {
  if (typeof text !== 'string' || text.trim() === '') {
    return { profiles: [], error: 'empty' };
  }
  var data;
  try {
    data = JSON.parse(text);
  } catch (e) {
    return { profiles: [], error: 'invalid json' };
  }
  if (!Array.isArray(data)) return { profiles: [], error: 'not an array' };
  for (var i = 0; i < data.length; i++) {
    var p = data[i];
    if (!p || typeof p !== 'object'
        || typeof p.id !== 'string'
        || typeof p.label !== 'string'
        || typeof p.ring !== 'string') {
      return { profiles: [], error: 'bad profile shape at index ' + i };
    }
  }
  return { profiles: data, error: null };
}

function clampHighlight(highlight, profileCount) {
  if (highlight < 0) return 0;
  if (highlight > profileCount) return profileCount; // profileCount == "+ new" index
  return highlight;
}

function keyToAction(key, modifiers, state) {
  var profiles = state.profiles;
  var highlight = state.highlight;
  var shift = !!(modifiers && modifiers.shift);
  var newIndex = profiles.length; // index of the "+ new" row

  if (key === 'Escape') return { type: 'hide' };
  if (key === '+') return { type: 'editor' };

  if (key >= '1' && key <= '9') {
    var idx = Number(key) - 1;
    if (idx >= profiles.length) return null;
    return shift ? { type: 'new', id: profiles[idx].id }
                 : { type: 'open', id: profiles[idx].id };
  }

  if (key === 'Down' || (key === 'Tab' && !shift)) {
    return { type: 'move', highlight: highlight >= newIndex ? 0 : highlight + 1 };
  }
  if (key === 'Up' || (key === 'Tab' && shift)) {
    return { type: 'move', highlight: highlight <= 0 ? newIndex : highlight - 1 };
  }

  if (key === 'Enter') {
    if (highlight === newIndex) return { type: 'editor' };
    var p = profiles[highlight];
    if (!p) return null;
    return shift ? { type: 'new', id: p.id } : { type: 'open', id: p.id };
  }

  return null;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd ~/d/dotfiles/wsprofiles && node --test menu/menu-logic.test.js`
Expected: PASS (12 tests).

- [ ] **Step 5: Commit**

```bash
cd ~/d/dotfiles
git add wsprofiles/menu/menu-logic.js wsprofiles/menu/menu-logic.test.js
git commit -m "feat(wsprofiles): pure selector logic (parse/keys/clamp)"
```

---

## Task 5: Menu shell — window, IPC toggle, model, rendering

**Files:**
- Create: `~/d/dotfiles/wsprofiles/menu/shell.qml`
- Create symlink: `~/.config/quickshell/wsprofile-menu` → `~/d/dotfiles/wsprofiles/menu`

**Interfaces:**
- Consumes: `menu-logic.js` (`parseProfiles`, `clampHighlight`); `~/.config/niri/wsprofiles.json` (Task 3).
- Produces: a resident `qs -c wsprofile-menu` config exposing IPC `menu toggle` / `menu show` / `menu hide`, rendering the profile list with ring swatches + an error state. (Key handling and actions are Task 6.)

This task's deliverable is verified manually (QML is not unit-tested); the manual steps are its test cycle.

- [ ] **Step 1: Create the Quickshell config symlink**

```bash
mkdir -p ~/.config/quickshell
ln -sfn ~/d/dotfiles/wsprofiles/menu ~/.config/quickshell/wsprofile-menu
ls -l ~/.config/quickshell/wsprofile-menu
```

Expected: the symlink points at `~/d/dotfiles/wsprofiles/menu`.

- [ ] **Step 2: Write `shell.qml` (render-only)**

Create `~/d/dotfiles/wsprofiles/menu/shell.qml`:

```qml
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "menu-logic.js" as Logic

ShellRoot {
  id: root
  property bool shown: false
  property var profiles: []
  property string loadError: ""
  property int highlight: 0

  function applyModel() {
    var res = Logic.parseProfiles(catalogView.text());
    root.profiles = res.profiles;
    root.loadError = res.error ? res.error : "";
    root.highlight = Logic.clampHighlight(root.highlight, root.profiles.length);
  }

  IpcHandler {
    target: "menu"
    function toggle(): void { root.shown = !root.shown }
    function show(): void { root.shown = true }
    function hide(): void { root.shown = false }
  }

  FileView {
    id: catalogView
    path: Quickshell.env("HOME") + "/.config/niri/wsprofiles.json"
    blockLoading: true
    watchChanges: true
    onFileChanged: this.reload()
    onLoaded: root.applyModel()
    // On I/O failure (missing file) set the error state directly. Do NOT parse
    // text() here — it can still hold previously-loaded content during a reload,
    // which would render stale profiles instead of the error state.
    onLoadFailed: {
      root.profiles = [];
      root.loadError = "load failed";
      root.highlight = 0;
    }
  }

  // The initial load is driven by FileView's preload firing onLoaded/onLoadFailed;
  // no Component.onCompleted parse is needed (and it would risk a stale read).

  PanelWindow {
    id: win
    visible: root.shown
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "wsprofile-menu"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }

    // Click-outside dismiss.
    MouseArea {
      anchors.fill: parent
      onClicked: root.shown = false
    }

    Rectangle {
      id: card
      anchors.centerIn: parent
      width: 420
      radius: 14
      color: "#1e1e2e"
      border.color: "#45475a"
      border.width: 1
      implicitHeight: content.implicitHeight + 24

      // Swallow clicks inside the card so they don't dismiss.
      MouseArea { anchors.fill: parent }

      Column {
        id: content
        x: 12; y: 12
        width: parent.width - 24
        spacing: 2

        Text {
          text: "Workspace Profiles"
          color: "#9399b2"
          font.pixelSize: 12
          bottomPadding: 6
        }

        // Error state.
        Text {
          visible: root.loadError !== ""
          text: "No profiles — is wsprofiled running?"
          color: "#f38ba8"
          font.pixelSize: 14
          height: 40
          verticalAlignment: Text.AlignVCenter
        }

        // Profile rows.
        Repeater {
          model: root.loadError === "" ? root.profiles : []
          delegate: Rectangle {
            required property var modelData
            required property int index
            width: content.width
            height: 40
            radius: 8
            color: index === root.highlight ? "#313244" : "transparent"

            Row {
              anchors.fill: parent
              anchors.leftMargin: 8
              spacing: 10

              // Accent bar in the ring color when highlighted.
              Rectangle {
                width: 3; height: 24; radius: 2
                anchors.verticalCenter: parent.verticalCenter
                color: modelData.ring
                visible: index === root.highlight
              }
              // Ring-color swatch.
              Rectangle {
                width: 16; height: 16; radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: modelData.ring
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: index < 9 ? (index + 1).toString() : ""
                color: "#bac2de"; font.pixelSize: 14; width: 14
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.icon
                color: modelData.ring; font.pixelSize: 16
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label
                color: "#cdd6f4"; font.pixelSize: 14
              }
            }
          }
        }

        // "+ new" row.
        Rectangle {
          width: content.width
          height: 40
          radius: 8
          color: root.highlight === root.profiles.length ? "#313244" : "transparent"
          Row {
            anchors.fill: parent
            anchors.leftMargin: 8
            spacing: 10
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "+"; color: "#9399b2"; font.pixelSize: 16; leftPadding: 19
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "new profile…"; color: "#9399b2"; font.pixelSize: 14
            }
          }
        }

        // Footer hint.
        Text {
          topPadding: 6
          text: "1-9 switch · ⇧N new instance · + add · Esc close"
          color: "#6c7086"; font.pixelSize: 11
        }
      }
    }
  }
}
```

- [ ] **Step 3: Launch the menu and confirm it renders**

```bash
# Ensure the daemon has written the JSON (Task 3 manual smoke), then:
qs -c wsprofile-menu &
sleep 1
qs -c wsprofile-menu ipc call menu toggle
```

Expected: a centered card appears titled "Workspace Profiles", one row per profile
with a colored swatch, the number, the icon glyph, and the label, then a muted
`+ new profile…` row and the footer hint. Run `ipc call menu toggle` again →
it hides. Click outside the card → it hides.

- [ ] **Step 4: Confirm the error state**

```bash
mv ~/.config/niri/wsprofiles.json ~/.config/niri/wsprofiles.json.bak
qs -c wsprofile-menu ipc call menu toggle
# observe: card shows "No profiles — is wsprofiled running?"
qs -c wsprofile-menu ipc call menu toggle
mv ~/.config/niri/wsprofiles.json.bak ~/.config/niri/wsprofiles.json
```

Expected: with the JSON missing the card shows the error row (and is dismissable);
restoring the file and toggling again shows the rows. Leave the test `qs` instance
running for Task 6, or kill it with `pkill -f 'wsprofile-menu'`.

- [ ] **Step 5: Commit**

```bash
cd ~/d/dotfiles
git add wsprofiles/menu/shell.qml
git commit -m "feat(wsprofiles): selector popup window, IPC toggle, rendering"
```

(The `~/.config/quickshell/wsprofile-menu` symlink is a local machine artifact, not a repo file — nothing to commit for it.)

---

## Task 6: Menu shell — keyboard adapter and actions

**Files:**
- Modify: `~/d/dotfiles/wsprofiles/menu/shell.qml`

**Interfaces:**
- Consumes: `menu-logic.js` `keyToAction`; the Phase 1 control client at `~/d/dotfiles/wsprofiles/bin/wsprofilectl`.
- Produces: full keyboard interaction (digits, Shift+digit, arrows/Tab, Enter, `+`, Escape), mouse selection, `wsprofilectl open|new <id>` spawning, and `$EDITOR` launch for "+ new".

Verified manually (the manual steps are its test cycle).

- [ ] **Step 1: Add the key adapter + dispatch + Process spawns**

In `~/d/dotfiles/wsprofiles/menu/shell.qml`, add these functions and `Process`
elements inside `ShellRoot` (next to `applyModel`):

```qml
  // --- Actions -------------------------------------------------------------

  // A null stderr parser would close the channel, so wsprofilectl failures would
  // vanish. Collect stderr and forward it to the qs log for manual check 9.
  Process {
    id: ctl
    stderr: StdioCollector {
      onStreamFinished: {
        if (this.text.length > 0) console.error("wsprofile-menu: wsprofilectl:", this.text);
      }
    }
  }
  Process { id: editorProc }

  function runCtl(verb, id) {
    ctl.running = false;
    ctl.command = ["node",
      Quickshell.env("HOME") + "/d/dotfiles/wsprofiles/bin/wsprofilectl", verb, id];
    ctl.running = true;
  }

  function openEditor() {
    var editor = Quickshell.env("EDITOR");
    if (!editor || editor.length === 0) editor = "nano";
    var file = Quickshell.env("HOME") + "/d/dotfiles/wsprofiles/profiles.yaml";
    editorProc.running = false;
    // Launch the editor through sh so EDITOR values that carry flags (e.g.
    // "nvim -u NONE") word-split correctly; the file is passed as "$1" so the
    // path itself is never re-split. This shell is intentional, for this path only.
    editorProc.command = ["kitty", "sh", "-c", editor + ' "$1"', "sh", file];
    editorProc.running = true;
  }

  function dispatch(action) {
    if (!action) return;
    if (action.type === "hide") { root.shown = false; return; }
    if (action.type === "move") { root.highlight = action.highlight; return; }
    if (action.type === "editor") { root.openEditor(); root.shown = false; return; }
    if (action.type === "open" || action.type === "new") {
      root.runCtl(action.type, action.id);
      root.shown = false;
    }
  }

  // --- Qt key event -> normalized key --------------------------------------

  function normKey(event) {
    switch (event.key) {
      case Qt.Key_Escape: return "Escape";
      case Qt.Key_Return:
      case Qt.Key_Enter: return "Enter";
      case Qt.Key_Up: return "Up";
      case Qt.Key_Down: return "Down";
      case Qt.Key_Tab:
      case Qt.Key_Backtab: return "Tab";
      case Qt.Key_1: return "1";
      case Qt.Key_2: return "2";
      case Qt.Key_3: return "3";
      case Qt.Key_4: return "4";
      case Qt.Key_5: return "5";
      case Qt.Key_6: return "6";
      case Qt.Key_7: return "7";
      case Qt.Key_8: return "8";
      case Qt.Key_9: return "9";
    }
    if (event.text === "+") return "+";
    return null;
  }

  function handleKey(event) {
    var key = root.normKey(event);
    if (key === null) return;
    event.accepted = true;
    var action = Logic.keyToAction(
      key,
      { shift: (event.modifiers & Qt.ShiftModifier) !== 0 },
      { profiles: root.profiles, highlight: root.highlight });
    root.dispatch(action);
  }
```

- [ ] **Step 2: Re-clamp the highlight whenever the model changes**

Update `applyModel` to clamp (already calls `clampHighlight`, confirm it stays) and
ensure highlight resets to `0` each time the menu opens. Replace the existing
`applyModel` function and add an `onShownChanged` handler:

```qml
  function applyModel() {
    var res = Logic.parseProfiles(catalogView.text());
    root.profiles = res.profiles;
    root.loadError = res.error ? res.error : "";
    root.highlight = Logic.clampHighlight(root.highlight, root.profiles.length);
  }

  onShownChanged: {
    if (root.shown) {
      root.highlight = 0;
      // Re-read fresh from disk; onLoaded/onLoadFailed update the model. Avoid
      // parsing text() directly here, which can be stale mid-reload.
      catalogView.reload();
      keyCatcher.forceActiveFocus();
    }
  }
```

- [ ] **Step 3: Add the focusable key catcher and wire mouse selection**

Inside the `PanelWindow` (`win`), add a focusable `Item` that receives keys, and
wire each row's `MouseArea` to dispatch. Add this `Item` as the first child of
`win` (before the dismiss `MouseArea`):

```qml
    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onPressed: (event) => root.handleKey(event)
    }
```

Then update the profile-row delegate's `Row` to include a hover+click `MouseArea`
(add inside the delegate `Rectangle`, after the `Row`):

```qml
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onEntered: root.highlight = index
              onClicked: root.dispatch({ type: "open", id: modelData.id })
            }
```

And add the same to the `+ new` row `Rectangle` (after its `Row`):

```qml
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.highlight = root.profiles.length
            onClicked: root.dispatch({ type: "editor" })
          }
```

- [ ] **Step 4: Manual verification — switching loop (live niri + noctalia)**

```bash
pkill -f 'wsprofile-menu' || true
qs -c wsprofile-menu &
sleep 1
```

Walk these (each should behave as noted):

1. `ipc call menu toggle` → card appears, highlight on row 1.
2. Press `2` → card hides, focus moves to `tide`, shell recolors to its scheme,
   niri ring shows tide's color.
3. Toggle again, press `Shift+2` → focus moves to a free `tide` instance (`tide-2`).
4. Toggle, press `Down`/`Tab` repeatedly → highlight + accent bar track each row's
   ring color and wrap through `+ new` back to the top; `Up`/`Shift+Tab` reverse.
5. On a highlighted profile, press `Enter` → switches as the number would.
6. Press `+` (or `Enter` on `+ new`) → `kitty` opens the editor on `profiles.yaml`;
   add a third profile, save; reopen the menu → the new row appears (no menu
   restart), with its swatch.
7. Toggle, press `Esc` → hides, focus returns to the underlying window (confirms
   the `OnDemand`→`None` focus release).
8. Toggle twice quickly → show then hide, no stacking.
9. `pkill -f wsprofiled`, toggle, press a number → menu hides; `wsprofilectl`
   error is logged to the `qs` stderr, no crash. (Restart the daemon afterwards.)

- [ ] **Step 5: Commit**

```bash
cd ~/d/dotfiles
git add wsprofiles/menu/shell.qml
git commit -m "feat(wsprofiles): selector keyboard adapter, actions, editor launch"
```

---

## Task 7: niri integration

**Files:**
- Modify: `~/d/dotfiles/niri/config.kdl`

**Interfaces:**
- Consumes: the resident `wsprofile-menu` config (Tasks 5–6).
- Produces: the menu starts with niri and `Mod+P` toggles it.

- [ ] **Step 1: Add the startup spawn**

In `~/d/dotfiles/niri/config.kdl`, find the existing daemon spawn line:

```kdl
spawn-sh-at-startup "node ~/d/dotfiles/wsprofiles/bin/wsprofiled"
```

Add directly beneath it:

```kdl
spawn-at-startup "qs" "-c" "wsprofile-menu"
```

- [ ] **Step 2: Add the toggle bind**

In the `binds { ... }` block, near the other `qs ... ipc call` binds (e.g. after
the `Super+S` controlCenter line), add:

```kdl
    Mod+P repeat=false { spawn "qs" "-c" "wsprofile-menu" "ipc" "call" "menu" "toggle"; }
```

- [ ] **Step 3: Reload niri and verify the bind**

```bash
# Validate the edited config first and fix any reported error before loading.
niri validate
# Only load once validation passes.
niri msg action load-config-file
```

Expected: `niri validate` exits 0 (no diagnostics), then the reload applies cleanly.
If validation reports an error, fix `config.kdl` and re-run before loading. (If
`wsprofile-menu` was not already running from Task 6, start it once:
`qs -c wsprofile-menu &`.)

- [ ] **Step 4: Manual verification — the real keybind**

Press `Mod+P`. Expected: the popup toggles open; pressing a number switches the
workspace profile (full loop from Task 6, now driven by the actual keybind). Press
`Mod+P` again or `Esc` to close.

- [ ] **Step 5: Commit**

```bash
cd ~/d/dotfiles
git add niri/config.kdl
git commit -m "feat(niri): start wsprofile-menu and bind Mod+P to toggle it"
```

---

## Self-Review Notes (for the executor)

- **Spec coverage:** viewModel emitter (Task 1), artifact transaction incl.
  absence-aware restore + write-failure path (Task 2–3), `parseProfiles` /
  `keyToAction` / `clampHighlight` (Task 4), FileView `watchChanges`+reload &
  `WlrKeyboardFocus` visibility binding & rendering & error state (Task 5),
  digit-from-`event.key` adapter, absolute-path spawns, editor launch, highlight
  re-clamp, all nine manual checks + the corrupt-JSON check (Task 6), niri wiring
  (Task 7). Every spec section maps to a task.
- **No new switching logic:** Tasks 6 routes only through `wsprofilectl`; the daemon
  and event-stream are unchanged from Phase 1.
- **Type consistency:** `viewModel` fields `{id,label,icon,ring,border,instances}`
  are produced in Task 1 and consumed by `parseProfiles`/rendering (Tasks 4–5);
  `keyToAction` action shapes in Task 4 match `dispatch` in Task 6;
  `clampHighlight(highlight, profileCount)` signature matches both call sites.
- **QML is the unverified surface:** Tasks 5–6 are confirmed by their manual steps,
  not unit tests, by design — the pure logic underneath (Tasks 1, 2, 4) is fully
  node-tested.
