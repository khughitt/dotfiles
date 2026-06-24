# Niri Workspace Profiles — Phase 1 (Engine) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `wsprofiled`, a Node daemon that gives each niri workspace a visual identity by generating per-workspace ring/border colors and switching noctalia's colorscheme + wallpaper when a profile's workspace gains focus.

**Architecture:** A YAML catalog (`profiles.yaml`) is the single source of truth. Pure modules turn it into a niri KDL include and a workspace-name→profile map. The daemon predeclares all workspace slots, subscribes to niri's JSON event stream, tracks window occupancy, and on a focus change runs noctalia IPC commands to apply the focused profile's theme. Phase 1 is driven by manually-added named-slot keybinds; there is no selector UI yet.

**Tech Stack:** Node ≥ 20 (ESM), built-in `node:test` + `node:assert` for tests, the `yaml` npm package for catalog parsing, niri IPC (`niri msg`), noctalia native IPC (`noctalia msg`).

## Global Constraints

- **Target shell:** native (C++) noctalia (`noctalia-origin`) only. Not the Quickshell/QML build. noctalia IPC command names (`wallpaper-set`, `color-scheme-set`, `theme-mode-set`) are taken from the `noctalia-origin` source and **must be verified against the installed build** before the live-verification steps; the native shell is in active flux.
- **`id` grammar:** a profile `id` must match `^[a-z][a-z0-9-]*$` and must **not** end in `-<digits>` (e.g. `api-2` is rejected). This prevents collisions between an instance slot (`api-2`) and a literal profile id.
- **Name→profile resolution:** never parse the `-n` suffix to recover a profile. Resolve via the authoritative map built at slot generation.
- **Reload-free hot path:** niri config is reloaded only when the catalog changes, never on a focus switch.
- **No per-workspace wallpaper/colorscheme:** noctalia colorscheme + wallpaper are global to the shell. The per-workspace cue is niri's ring/border color.
- **Border:** the global niri default is `border { off }`. A generated workspace block emits a `border { on; ... }` block **only** when the profile sets a `border` color; the focus-ring is globally `on` so its color renders with `active-color` alone.
- **Paths in committed files/docs:** use `~/d/...`, never `/home/keith/...` or `/mnt/ssd/...`.
- **No compatibility/legacy layers.**

## File Structure

All paths under `~/d/dotfiles/wsprofiles/` unless noted.

- `profiles.yaml` — the catalog (data; user-edited).
- `package.json` — ESM Node project; `test` script runs `node --test`.
- `src/catalog.js` — load + validate the YAML catalog; apply defaults. Pure.
- `src/slots.js` — slot naming + name→profile map + slot list. Pure.
- `src/kdl.js` — render `profiles.kdl` text from the catalog. Pure.
- `src/theme.js` — map a profile to an ordered list of noctalia IPC argv arrays. Pure.
- `src/occupancy.js` — `OccupancyTracker`: fold niri window/workspace events into per-workspace window counts; find a free instance slot. Pure (driven by event objects).
- `src/niri.js` — niri IPC adapter: parse the event stream, `focusWorkspace`, `loadConfig`. Thin.
- `src/noctalia.js` — noctalia IPC adapter: run the argv arrays from `theme.js`. Thin.
- `src/daemon.js` — wire everything; control socket for `wsprofilectl`.
- `bin/wsprofiled` — daemon entry point.
- `bin/wsprofilectl` — control client (`open <id>`, `new <id>`).
- `test/*.test.js` — unit tests.
- niri integration (in the dotfiles `niri/` dir, symlinked to `~/.config/niri/`):
  - `niri/profiles.kdl` — generated include (tracked so the `include` resolves on boot).
  - `niri/config.kdl` — add the `include`, the named-slot binds, and the `spawn-at-startup`.

**Live-verification note:** any step that runs `niri msg` or `noctalia msg` against the real shell can only be fully verified **after** the noctalia migration. Those steps are marked **[live, post-migration]**. All pure-logic tasks are fully testable now.

---

### Task 1: Project scaffold + catalog loader/validator

**Files:**
- Create: `wsprofiles/package.json`
- Create: `wsprofiles/profiles.yaml`
- Create: `wsprofiles/src/catalog.js`
- Test: `wsprofiles/test/catalog.test.js`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `loadCatalog(path: string) -> Catalog` (reads + parses + validates).
  - `parseCatalog(text: string) -> Catalog` (parse + validate a YAML string).
  - Types: `Profile = { id, label, instances:number, ring:string, border:string|null, icon:string, theme:{ source:'wallpaper'|'builtin'|'custom', wallpaper:string|null, scheme:string|null, builtin:string|null, custom:string|null, mode:'dark'|'light' } }`; `Catalog = { profiles: Profile[] }`.
  - `ID_RE = /^[a-z][a-z0-9-]*$/` and rejection of `/-\d+$/`.

- [ ] **Step 1: Write `package.json`**

```json
{
  "name": "wsprofiles",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "bin": { "wsprofiled": "bin/wsprofiled", "wsprofilectl": "bin/wsprofilectl" },
  "scripts": { "test": "node --test" },
  "dependencies": { "yaml": "^2.4.0" }
}
```

Run: `cd ~/d/dotfiles/wsprofiles && npm install`
Expected: `node_modules/` created, `yaml` installed.

- [ ] **Step 2: Write a starter `profiles.yaml`**

```yaml
profiles:
  - id: ember
    label: "Ember - client-api"
    instances: 1
    ring: "#ff7a45"
    border: "#ff7a45"
    icon: ""
    theme:
      source: wallpaper
      wallpaper: ~/Pictures/Walls/ember.jpg
      scheme: m3-content
      mode: dark
  - id: tide
    label: "Tide - infra"
    instances: 2
    ring: "#3aa6ff"
    icon: ""
    theme:
      source: builtin
      builtin: "Catppuccin"
      mode: dark
```

- [ ] **Step 3: Write the failing test**

```js
// wsprofiles/test/catalog.test.js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseCatalog } from '../src/catalog.js';

test('applies defaults and normalizes a minimal profile', () => {
  const cat = parseCatalog(`
profiles:
  - id: ember
    label: "Ember"
    ring: "#ff7a45"
    theme: { source: builtin, builtin: "Catppuccin", mode: dark }
`);
  const p = cat.profiles[0];
  assert.equal(p.instances, 1);
  assert.equal(p.border, null);
  assert.equal(p.icon, '');
  assert.equal(p.theme.wallpaper, null);
  assert.equal(p.theme.scheme, null);
});

test('rejects an id ending in -<digits>', () => {
  assert.throws(() => parseCatalog(`
profiles:
  - id: api-2
    label: "Api"
    ring: "#fff"
    theme: { source: builtin, builtin: "X", mode: dark }
`), /id .* must not end in -<digits>/);
});

test('rejects an id with illegal characters', () => {
  assert.throws(() => parseCatalog(`
profiles:
  - id: "Ember!"
    label: "Ember"
    ring: "#fff"
    theme: { source: builtin, builtin: "X", mode: dark }
`), /id .* must match/);
});

test('rejects duplicate ids', () => {
  assert.throws(() => parseCatalog(`
profiles:
  - id: a
    label: "A"
    ring: "#fff"
    theme: { source: builtin, builtin: "X", mode: dark }
  - id: a
    label: "A2"
    ring: "#000"
    theme: { source: builtin, builtin: "Y", mode: dark }
`), /duplicate id/);
});
```

- [ ] **Step 4: Run test to verify it fails**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/catalog.test.js`
Expected: FAIL — `Cannot find module '../src/catalog.js'`.

- [ ] **Step 5: Implement `src/catalog.js`**

```js
// wsprofiles/src/catalog.js
import { readFileSync } from 'node:fs';
import { parse as parseYaml } from 'yaml';

export const ID_RE = /^[a-z][a-z0-9-]*$/;

function validateProfile(raw, seen) {
  if (typeof raw.id !== 'string') throw new Error('profile is missing a string id');
  if (!ID_RE.test(raw.id)) throw new Error(`id "${raw.id}" must match ${ID_RE}`);
  if (/-\d+$/.test(raw.id)) throw new Error(`id "${raw.id}" must not end in -<digits>`);
  if (seen.has(raw.id)) throw new Error(`duplicate id "${raw.id}"`);
  seen.add(raw.id);
  if (typeof raw.ring !== 'string') throw new Error(`profile "${raw.id}" is missing ring`);
  const t = raw.theme ?? {};
  if (!['wallpaper', 'builtin', 'custom'].includes(t.source))
    throw new Error(`profile "${raw.id}" theme.source must be wallpaper|builtin|custom`);
  if (!['dark', 'light'].includes(t.mode))
    throw new Error(`profile "${raw.id}" theme.mode must be dark|light`);
  const instances = raw.instances ?? 1;
  if (!Number.isInteger(instances) || instances < 1)
    throw new Error(`profile "${raw.id}" instances must be a positive integer`);
  return {
    id: raw.id,
    label: raw.label ?? raw.id,
    instances,
    ring: raw.ring,
    border: raw.border ?? null,
    icon: raw.icon ?? '',
    theme: {
      source: t.source,
      wallpaper: t.wallpaper ?? null,
      scheme: t.scheme ?? null,
      builtin: t.builtin ?? null,
      custom: t.custom ?? null,
      mode: t.mode,
    },
  };
}

export function parseCatalog(text) {
  const doc = parseYaml(text);
  if (!doc || !Array.isArray(doc.profiles))
    throw new Error('catalog must have a top-level "profiles" list');
  const seen = new Set();
  return { profiles: doc.profiles.map((p) => validateProfile(p, seen)) };
}

export function loadCatalog(path) {
  return parseCatalog(readFileSync(path, 'utf8'));
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/catalog.test.js`
Expected: PASS — 4 tests.

- [ ] **Step 7: Commit**

```bash
cd ~/d/dotfiles
git add -f wsprofiles/package.json wsprofiles/profiles.yaml wsprofiles/src/catalog.js wsprofiles/test/catalog.test.js
echo "wsprofiles/node_modules/" >> .gitignore
git add .gitignore
git commit -m "feat(wsprofiles): catalog loader with id grammar + defaults"
```

---

### Task 2: Slot naming + name→profile map

**Files:**
- Create: `wsprofiles/src/slots.js`
- Test: `wsprofiles/test/slots.test.js`

**Interfaces:**
- Consumes: `Catalog`, `Profile` from Task 1.
- Produces:
  - `slotName(id: string, instance: number) -> string` (`instance` 1 → `id`; ≥2 → `id-<instance>`).
  - `listSlots(profile: Profile) -> {name:string, instance:number}[]` (length = `profile.instances`).
  - `buildSlotMap(catalog: Catalog) -> Map<string, {profileId:string, instance:number}>` (workspace-name → profile).

- [ ] **Step 1: Write the failing test**

```js
// wsprofiles/test/slots.test.js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { slotName, listSlots, buildSlotMap } from '../src/slots.js';

test('slotName: instance 1 is the bare id, >=2 is suffixed', () => {
  assert.equal(slotName('ember', 1), 'ember');
  assert.equal(slotName('ember', 2), 'ember-2');
  assert.equal(slotName('ember', 3), 'ember-3');
});

test('listSlots returns one entry per instance', () => {
  const slots = listSlots({ id: 'tide', instances: 2 });
  assert.deepEqual(slots, [
    { name: 'tide', instance: 1 },
    { name: 'tide-2', instance: 2 },
  ]);
});

test('buildSlotMap resolves every generated name back to its profile', () => {
  const map = buildSlotMap({ profiles: [
    { id: 'ember', instances: 1 },
    { id: 'tide', instances: 2 },
  ] });
  assert.deepEqual(map.get('ember'), { profileId: 'ember', instance: 1 });
  assert.deepEqual(map.get('tide'), { profileId: 'tide', instance: 1 });
  assert.deepEqual(map.get('tide-2'), { profileId: 'tide', instance: 2 });
  assert.equal(map.has('ember-2'), false);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/slots.test.js`
Expected: FAIL — `Cannot find module '../src/slots.js'`.

- [ ] **Step 3: Implement `src/slots.js`**

```js
// wsprofiles/src/slots.js
export function slotName(id, instance) {
  return instance === 1 ? id : `${id}-${instance}`;
}

export function listSlots(profile) {
  const slots = [];
  for (let i = 1; i <= profile.instances; i++) {
    slots.push({ name: slotName(profile.id, i), instance: i });
  }
  return slots;
}

export function buildSlotMap(catalog) {
  const map = new Map();
  for (const profile of catalog.profiles) {
    for (const { name, instance } of listSlots(profile)) {
      map.set(name, { profileId: profile.id, instance });
    }
  }
  return map;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/slots.test.js`
Expected: PASS — 3 tests.

- [ ] **Step 5: Commit**

```bash
cd ~/d/dotfiles
git add -f wsprofiles/src/slots.js wsprofiles/test/slots.test.js
git commit -m "feat(wsprofiles): slot naming + name->profile map"
```

---

### Task 3: KDL include generator

**Files:**
- Create: `wsprofiles/src/kdl.js`
- Test: `wsprofiles/test/kdl.test.js`

**Interfaces:**
- Consumes: `Catalog`, `Profile` from Task 1; `listSlots` from Task 2.
- Produces: `generateKdl(catalog: Catalog) -> string` — one `workspace "<name>" { layout { ... } }` block per slot; `focus-ring` always; `border { on; ... }` only when `profile.border` is set.

- [ ] **Step 1: Write the failing test**

```js
// wsprofiles/test/kdl.test.js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { generateKdl } from '../src/kdl.js';

const catalog = { profiles: [
  { id: 'ember', instances: 1, ring: '#ff7a45', border: '#ff7a45',
    theme: {} },
  { id: 'tide', instances: 2, ring: '#3aa6ff', border: null,
    theme: {} },
] };

test('emits focus-ring active-color for every slot', () => {
  const kdl = generateKdl(catalog);
  assert.match(kdl, /workspace "ember" \{/);
  assert.match(kdl, /workspace "tide" \{/);
  assert.match(kdl, /workspace "tide-2" \{/);
  assert.match(kdl, /focus-ring \{\s*active-color "#3aa6ff"/);
});

test('emits a border block only when border color is set', () => {
  const kdl = generateKdl(catalog);
  const emberBlock = kdl.slice(kdl.indexOf('workspace "ember"'), kdl.indexOf('workspace "tide"'));
  const tideBlock = kdl.slice(kdl.indexOf('workspace "tide" '));
  assert.match(emberBlock, /border \{\s*on\s*active-color "#ff7a45"/);
  assert.doesNotMatch(tideBlock, /border \{/);
});

test('is deterministic (stable ordering)', () => {
  assert.equal(generateKdl(catalog), generateKdl(catalog));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/kdl.test.js`
Expected: FAIL — `Cannot find module '../src/kdl.js'`.

- [ ] **Step 3: Implement `src/kdl.js`**

```js
// wsprofiles/src/kdl.js
import { listSlots } from './slots.js';

function block(name, profile) {
  const lines = [];
  lines.push(`workspace "${name}" {`);
  lines.push('    layout {');
  lines.push('        focus-ring {');
  lines.push(`            active-color "${profile.ring}"`);
  lines.push('        }');
  if (profile.border) {
    lines.push('        border {');
    lines.push('            on');
    lines.push(`            active-color "${profile.border}"`);
    lines.push('        }');
  }
  lines.push('    }');
  lines.push('}');
  return lines.join('\n');
}

export function generateKdl(catalog) {
  const header = '// Generated by wsprofiled from profiles.yaml. Do not edit by hand.\n';
  const blocks = [];
  for (const profile of catalog.profiles) {
    for (const { name } of listSlots(profile)) {
      blocks.push(block(name, profile));
    }
  }
  return header + blocks.join('\n\n') + '\n';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/kdl.test.js`
Expected: PASS — 3 tests.

- [ ] **Step 5: Commit**

```bash
cd ~/d/dotfiles
git add -f wsprofiles/src/kdl.js wsprofiles/test/kdl.test.js
git commit -m "feat(wsprofiles): generate per-workspace ring/border KDL"
```

---

### Task 4: Theme → noctalia command mapper

**Files:**
- Create: `wsprofiles/src/theme.js`
- Test: `wsprofiles/test/theme.test.js`

**Interfaces:**
- Consumes: `Profile` from Task 1.
- Produces: `themeCommands(profile: Profile) -> string[][]` — ordered argv arrays (WITHOUT the leading `noctalia msg`), and `expandHome(p:string) -> string`.

- [ ] **Step 1: Write the failing test**

```js
// wsprofiles/test/theme.test.js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { themeCommands } from '../src/theme.js';

test('wallpaper source sets wallpaper, wallpaper scheme, then mode', () => {
  const cmds = themeCommands({
    theme: { source: 'wallpaper', wallpaper: '/w/ember.jpg', scheme: 'm3-content', mode: 'dark' },
  });
  assert.deepEqual(cmds, [
    ['wallpaper-set', '/w/ember.jpg'],
    ['color-scheme-set', 'wallpaper', 'm3-content'],
    ['theme-mode-set', 'dark'],
  ]);
});

test('builtin source with no wallpaper sets builtin scheme then mode', () => {
  const cmds = themeCommands({
    theme: { source: 'builtin', builtin: 'Catppuccin', wallpaper: null, mode: 'light' },
  });
  assert.deepEqual(cmds, [
    ['color-scheme-set', 'builtin', 'Catppuccin'],
    ['theme-mode-set', 'light'],
  ]);
});

test('builtin source WITH a wallpaper also sets the wallpaper first', () => {
  const cmds = themeCommands({
    theme: { source: 'builtin', builtin: 'Catppuccin', wallpaper: '/w/x.jpg', mode: 'dark' },
  });
  assert.deepEqual(cmds[0], ['wallpaper-set', '/w/x.jpg']);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/theme.test.js`
Expected: FAIL — `Cannot find module '../src/theme.js'`.

- [ ] **Step 3: Implement `src/theme.js`**

```js
// wsprofiles/src/theme.js
import { homedir } from 'node:os';

export function expandHome(p) {
  if (!p) return p;
  if (p === '~') return homedir();
  if (p.startsWith('~/')) return homedir() + p.slice(1);
  return p;
}

export function themeCommands(profile) {
  const t = profile.theme;
  const cmds = [];
  if (t.wallpaper) cmds.push(['wallpaper-set', expandHome(t.wallpaper)]);
  if (t.source === 'wallpaper') cmds.push(['color-scheme-set', 'wallpaper', t.scheme]);
  else if (t.source === 'builtin') cmds.push(['color-scheme-set', 'builtin', t.builtin]);
  else if (t.source === 'custom') cmds.push(['color-scheme-set', 'custom', t.custom]);
  cmds.push(['theme-mode-set', t.mode]);
  return cmds;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/theme.test.js`
Expected: PASS — 3 tests.

- [ ] **Step 5: Commit**

```bash
cd ~/d/dotfiles
git add -f wsprofiles/src/theme.js wsprofiles/test/theme.test.js
git commit -m "feat(wsprofiles): map profile theme to noctalia commands"
```

---

### Task 5: Occupancy tracker

**Files:**
- Create: `wsprofiles/src/occupancy.js`
- Test: `wsprofiles/test/occupancy.test.js`

**Interfaces:**
- Consumes: niri event objects (shape below); `slotName` from Task 2.
- Produces: class `OccupancyTracker` with `apply(event)`, `windowCount(workspaceName) -> number`, `freeInstance(profileId, instances) -> string|null` (first instance ≥2 with zero windows; `null` if none free).
- niri event shapes used:
  - `{ WorkspacesChanged: { workspaces: [{ id, name }] } }`
  - `{ WindowsChanged: { windows: [{ id, workspace_id }] } }`
  - `{ WindowOpenedOrChanged: { window: { id, workspace_id } } }`
  - `{ WindowClosed: { id } }`

- [ ] **Step 1: Write the failing test**

```js
// wsprofiles/test/occupancy.test.js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { OccupancyTracker } from '../src/occupancy.js';

function seeded() {
  const t = new OccupancyTracker();
  t.apply({ WorkspacesChanged: { workspaces: [
    { id: 10, name: 'tide' }, { id: 11, name: 'tide-2' }, { id: 12, name: 'tide-3' },
  ] } });
  return t;
}

test('counts windows per workspace from a full snapshot', () => {
  const t = seeded();
  t.apply({ WindowsChanged: { windows: [
    { id: 1, workspace_id: 10 }, { id: 2, workspace_id: 10 },
  ] } });
  assert.equal(t.windowCount('tide'), 2);
  assert.equal(t.windowCount('tide-2'), 0);
});

test('open and close adjust counts and survive a window moving workspace', () => {
  const t = seeded();
  t.apply({ WindowOpenedOrChanged: { window: { id: 1, workspace_id: 10 } } });
  assert.equal(t.windowCount('tide'), 1);
  t.apply({ WindowOpenedOrChanged: { window: { id: 1, workspace_id: 11 } } }); // moved
  assert.equal(t.windowCount('tide'), 0);
  assert.equal(t.windowCount('tide-2'), 1);
  t.apply({ WindowClosed: { id: 1 } });
  assert.equal(t.windowCount('tide-2'), 0);
});

test('freeInstance returns the first empty instance >= 2, else null', () => {
  const t = seeded();
  t.apply({ WindowsChanged: { windows: [{ id: 1, workspace_id: 11 }] } }); // tide-2 busy
  assert.equal(t.freeInstance('tide', 3), 'tide-3');
  t.apply({ WindowOpenedOrChanged: { window: { id: 2, workspace_id: 12 } } }); // tide-3 busy
  assert.equal(t.freeInstance('tide', 3), null);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/occupancy.test.js`
Expected: FAIL — `Cannot find module '../src/occupancy.js'`.

- [ ] **Step 3: Implement `src/occupancy.js`**

```js
// wsprofiles/src/occupancy.js
import { slotName } from './slots.js';

export class OccupancyTracker {
  constructor() {
    this.nameById = new Map();   // workspace id -> name
    this.wsByWindow = new Map(); // window id -> workspace id
  }

  apply(event) {
    if (event.WorkspacesChanged) {
      this.nameById.clear();
      for (const ws of event.WorkspacesChanged.workspaces) {
        if (ws.name) this.nameById.set(ws.id, ws.name);
      }
    } else if (event.WindowsChanged) {
      this.wsByWindow.clear();
      for (const w of event.WindowsChanged.windows) {
        if (w.workspace_id != null) this.wsByWindow.set(w.id, w.workspace_id);
      }
    } else if (event.WindowOpenedOrChanged) {
      const w = event.WindowOpenedOrChanged.window;
      if (w.workspace_id != null) this.wsByWindow.set(w.id, w.workspace_id);
      else this.wsByWindow.delete(w.id);
    } else if (event.WindowClosed) {
      this.wsByWindow.delete(event.WindowClosed.id);
    }
  }

  windowCount(workspaceName) {
    let count = 0;
    for (const wsId of this.wsByWindow.values()) {
      if (this.nameById.get(wsId) === workspaceName) count++;
    }
    return count;
  }

  freeInstance(profileId, instances) {
    for (let i = 2; i <= instances; i++) {
      const name = slotName(profileId, i);
      if (this.windowCount(name) === 0) return name;
    }
    return null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/occupancy.test.js`
Expected: PASS — 3 tests.

- [ ] **Step 5: Commit**

```bash
cd ~/d/dotfiles
git add -f wsprofiles/src/occupancy.js wsprofiles/test/occupancy.test.js
git commit -m "feat(wsprofiles): window occupancy tracker + free-instance finder"
```

---

### Task 6: niri event-stream parser + adapter

**Files:**
- Create: `wsprofiles/src/niri.js`
- Test: `wsprofiles/test/niri.test.js`

**Interfaces:**
- Consumes: nothing from earlier tasks (pure parser + thin spawn wrappers).
- Produces:
  - `parseEventLines(chunk: string, carry: string) -> { events: object[], carry: string }` — split newline-delimited JSON, tolerate partial trailing lines.
  - `focusedWorkspaceName(event) -> string|null` — return the focused workspace name from a `WorkspaceActivated`/`WorkspacesChanged` event, else `null`. (Resolves the focused name using a provided `nameById` map.)
  - `focusWorkspace(name) -> Promise<void>` — runs `niri msg action focus-workspace "<name>"`.
  - `loadConfig() -> Promise<void>` — runs `niri msg action load-config-file`.

- [ ] **Step 1: Write the failing test**

```js
// wsprofiles/test/niri.test.js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseEventLines, focusedName } from '../src/niri.js';

test('parses complete JSON lines and carries a partial line forward', () => {
  const a = parseEventLines('{"A":1}\n{"B":2}\n{"C', '');
  assert.deepEqual(a.events, [{ A: 1 }, { B: 2 }]);
  assert.equal(a.carry, '{"C');
  const b = parseEventLines('":3}\n', a.carry);
  assert.deepEqual(b.events, [{ C: 3 }]);
  assert.equal(b.carry, '');
});

test('focusedName returns the focused workspace name via WorkspacesChanged', () => {
  const nameById = new Map();
  const ev = { WorkspacesChanged: { workspaces: [
    { id: 5, name: 'ember', is_focused: true },
    { id: 6, name: 'tide', is_focused: false },
  ] } };
  assert.equal(focusedName(ev, nameById), 'ember');
});

test('focusedName resolves a WorkspaceActivated focused=true via the id map', () => {
  const nameById = new Map([[7, 'tide-2']]);
  const ev = { WorkspaceActivated: { id: 7, focused: true } };
  assert.equal(focusedName(ev, nameById), 'tide-2');
});

test('focusedName ignores non-focus events', () => {
  assert.equal(focusedName({ WindowClosed: { id: 1 } }, new Map()), null);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/niri.test.js`
Expected: FAIL — `Cannot find module '../src/niri.js'`.

- [ ] **Step 3: Implement `src/niri.js`**

```js
// wsprofiles/src/niri.js
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const run = promisify(execFile);

export function parseEventLines(chunk, carry) {
  const buf = carry + chunk;
  const parts = buf.split('\n');
  const carryOut = parts.pop();
  const events = [];
  for (const line of parts) {
    if (line.trim()) events.push(JSON.parse(line));
  }
  return { events, carry: carryOut };
}

export function focusedName(event, nameById) {
  if (event.WorkspacesChanged) {
    const ws = event.WorkspacesChanged.workspaces.find((w) => w.is_focused);
    return ws?.name ?? null;
  }
  if (event.WorkspaceActivated && event.WorkspaceActivated.focused) {
    return nameById.get(event.WorkspaceActivated.id) ?? null;
  }
  return null;
}

export function focusWorkspace(name) {
  return run('niri', ['msg', 'action', 'focus-workspace', name]).then(() => {});
}

export function loadConfig() {
  return run('niri', ['msg', 'action', 'load-config-file']).then(() => {});
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/niri.test.js`
Expected: PASS — 4 tests.

- [ ] **Step 5: Commit**

```bash
cd ~/d/dotfiles
git add -f wsprofiles/src/niri.js wsprofiles/test/niri.test.js
git commit -m "feat(wsprofiles): niri event parser + focus/reload adapter"
```

---

### Task 7: noctalia command runner

**Files:**
- Create: `wsprofiles/src/noctalia.js`
- Test: `wsprofiles/test/noctalia.test.js`

**Interfaces:**
- Consumes: argv arrays from `themeCommands` (Task 4).
- Produces: `runCommands(cmds: string[][], opts?: { exec? }) -> Promise<void>` — runs `noctalia msg <argv...>` for each, sequentially; `exec` is an injectable runner for testing.

- [ ] **Step 1: Write the failing test**

```js
// wsprofiles/test/noctalia.test.js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { runCommands } from '../src/noctalia.js';

test('prefixes each argv with noctalia msg and runs them in order', async () => {
  const calls = [];
  const exec = (file, args) => { calls.push([file, ...args]); return Promise.resolve(); };
  await runCommands([['wallpaper-set', '/w.jpg'], ['theme-mode-set', 'dark']], { exec });
  assert.deepEqual(calls, [
    ['noctalia', 'msg', 'wallpaper-set', '/w.jpg'],
    ['noctalia', 'msg', 'theme-mode-set', 'dark'],
  ]);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/noctalia.test.js`
Expected: FAIL — `Cannot find module '../src/noctalia.js'`.

- [ ] **Step 3: Implement `src/noctalia.js`**

```js
// wsprofiles/src/noctalia.js
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const defaultExec = promisify(execFile);

export async function runCommands(cmds, opts = {}) {
  const exec = opts.exec ?? defaultExec;
  for (const argv of cmds) {
    await exec('noctalia', ['msg', ...argv]);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/noctalia.test.js`
Expected: PASS — 1 test.

- [ ] **Step 5: [live, post-migration] Verify noctalia IPC names against the installed build**

Run: `noctalia msg --help`
Expected: `wallpaper-set`, `color-scheme-set`, `theme-mode-set` appear with the argument shapes used in `src/theme.js`. If a name/shape differs, update `src/theme.js` + its test and re-run `node --test test/theme.test.js`.

- [ ] **Step 6: Commit**

```bash
cd ~/d/dotfiles
git add -f wsprofiles/src/noctalia.js wsprofiles/test/noctalia.test.js
git commit -m "feat(wsprofiles): sequential noctalia msg runner"
```

---

### Task 8: Daemon wiring + control socket

**Files:**
- Create: `wsprofiles/src/daemon.js`
- Create: `wsprofiles/bin/wsprofiled`
- Test: `wsprofiles/test/daemon.test.js`

**Interfaces:**
- Consumes: all earlier modules.
- Produces:
  - `class Daemon` with:
    - `constructor({ catalog, niri, noctalia, occupancy })` (dependencies injected for testing).
    - `async onFocus(workspaceName)` — resolve name→profile via the slot map; if resolved, run `themeCommands`; ignore unknown names.
    - `async open(id)` — focus the profile's primary slot.
    - `async new(id)` — focus a free extra slot, or fall back to primary if none free.
  - `SOCKET_PATH` constant: `${XDG_RUNTIME_DIR}/wsprofiled.sock`.

- [ ] **Step 1: Write the failing test**

```js
// wsprofiles/test/daemon.test.js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Daemon } from '../src/daemon.js';
import { OccupancyTracker } from '../src/occupancy.js';

function makeDaemon() {
  const focused = [];
  const themed = [];
  const niri = { focusWorkspace: (n) => { focused.push(n); return Promise.resolve(); } };
  const noctalia = { runCommands: (c) => { themed.push(c); return Promise.resolve(); } };
  const catalog = { profiles: [
    { id: 'ember', instances: 1, ring: '#f00',
      theme: { source: 'builtin', builtin: 'X', wallpaper: null, mode: 'dark' } },
    { id: 'tide', instances: 2, ring: '#00f',
      theme: { source: 'builtin', builtin: 'Y', wallpaper: null, mode: 'dark' } },
  ] };
  const occupancy = new OccupancyTracker();
  return { d: new Daemon({ catalog, niri, noctalia, occupancy }), focused, themed, occupancy };
}

test('onFocus applies the resolved profile theme; unknown names are ignored', async () => {
  const { d, themed } = makeDaemon();
  await d.onFocus('tide-2');
  assert.deepEqual(themed.at(-1), [['color-scheme-set', 'builtin', 'Y'], ['theme-mode-set', 'dark']]);
  await d.onFocus('scratchpad'); // not a profile slot
  assert.equal(themed.length, 1);
});

test('open focuses the primary slot', async () => {
  const { d, focused } = makeDaemon();
  await d.open('tide');
  assert.deepEqual(focused, ['tide']);
});

test('new focuses a free extra slot, falling back to primary when full', async () => {
  const { d, focused, occupancy } = makeDaemon();
  await d.new('tide');
  assert.equal(focused.at(-1), 'tide-2');
  occupancy.apply({ WorkspacesChanged: { workspaces: [{ id: 1, name: 'tide-2' }] } });
  occupancy.apply({ WindowsChanged: { windows: [{ id: 9, workspace_id: 1 }] } });
  await d.new('tide');
  assert.equal(focused.at(-1), 'tide'); // tide-2 busy, instances=2 -> no free extra -> primary
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/daemon.test.js`
Expected: FAIL — `Cannot find module '../src/daemon.js'`.

- [ ] **Step 3: Implement `src/daemon.js`**

```js
// wsprofiles/src/daemon.js
import { buildSlotMap } from './slots.js';
import { themeCommands } from './theme.js';

export const SOCKET_PATH = `${process.env.XDG_RUNTIME_DIR ?? '/tmp'}/wsprofiled.sock`;

export class Daemon {
  constructor({ catalog, niri, noctalia, occupancy }) {
    this.catalog = catalog;
    this.niri = niri;
    this.noctalia = noctalia;
    this.occupancy = occupancy;
    this.slotMap = buildSlotMap(catalog);
    this.profileById = new Map(catalog.profiles.map((p) => [p.id, p]));
  }

  async onFocus(workspaceName) {
    const slot = this.slotMap.get(workspaceName);
    if (!slot) return;
    const profile = this.profileById.get(slot.profileId);
    await this.noctalia.runCommands(themeCommands(profile));
  }

  async open(id) {
    if (!this.profileById.has(id)) return;
    await this.niri.focusWorkspace(id);
  }

  async new(id) {
    const profile = this.profileById.get(id);
    if (!profile) return;
    const free = this.occupancy.freeInstance(id, profile.instances);
    await this.niri.focusWorkspace(free ?? id);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/daemon.test.js`
Expected: PASS — 3 tests.

- [ ] **Step 5: Write `bin/wsprofiled` (the runtime entry)**

```js
#!/usr/bin/env node
// wsprofiles/bin/wsprofiled
import { spawn } from 'node:child_process';
import { createServer } from 'node:net';
import { existsSync, unlinkSync, writeFileSync, watchFile } from 'node:fs';
import { homedir } from 'node:os';
import { loadCatalog } from '../src/catalog.js';
import { generateKdl } from '../src/kdl.js';
import { parseEventLines, focusedName, focusWorkspace, loadConfig } from '../src/niri.js';
import { runCommands } from '../src/noctalia.js';
import { OccupancyTracker } from '../src/occupancy.js';
import { Daemon, SOCKET_PATH } from '../src/daemon.js';

const CATALOG = `${homedir()}/d/dotfiles/wsprofiles/profiles.yaml`;
const KDL_OUT = `${homedir()}/.config/niri/profiles.kdl`;

function regenerate() {
  const catalog = loadCatalog(CATALOG);
  writeFileSync(KDL_OUT, generateKdl(catalog));
  return catalog;
}

let catalog = regenerate();
await loadConfig().catch(() => {}); // niri may not be ready on very first boot
const occupancy = new OccupancyTracker();
let daemon = new Daemon({ catalog, niri: { focusWorkspace }, noctalia: { runCommands }, occupancy });
const nameById = new Map();

// Regenerate + rebuild on catalog edits.
watchFile(CATALOG, { interval: 1000 }, () => {
  try {
    catalog = regenerate();
    daemon = new Daemon({ catalog, niri: { focusWorkspace }, noctalia: { runCommands }, occupancy });
    loadConfig().catch(() => {});
  } catch (e) {
    console.error('wsprofiled: catalog reload failed:', e.message);
  }
});

// Control socket for wsprofilectl.
if (existsSync(SOCKET_PATH)) unlinkSync(SOCKET_PATH);
createServer((sock) => {
  let buf = '';
  sock.on('data', (d) => {
    buf += d;
    let nl;
    while ((nl = buf.indexOf('\n')) >= 0) {
      const [cmd, id] = buf.slice(0, nl).trim().split(/\s+/);
      buf = buf.slice(nl + 1);
      if (cmd === 'open') daemon.open(id);
      else if (cmd === 'new') daemon.new(id);
    }
  });
}).listen(SOCKET_PATH);

// Subscribe to the niri event stream.
const stream = spawn('niri', ['msg', '--json', 'event-stream'], { stdio: ['ignore', 'pipe', 'inherit'] });
let carry = '';
stream.stdout.setEncoding('utf8');
stream.stdout.on('data', (chunk) => {
  const { events, carry: c } = parseEventLines(chunk, carry);
  carry = c;
  for (const ev of events) {
    occupancy.apply(ev);
    if (ev.WorkspacesChanged) {
      nameById.clear();
      for (const ws of ev.WorkspacesChanged.workspaces) if (ws.name) nameById.set(ws.id, ws.name);
    }
    const name = focusedName(ev, nameById);
    if (name) daemon.onFocus(name).catch((e) => console.error('wsprofiled: apply failed:', e.message));
  }
});
stream.on('exit', (code) => { console.error(`wsprofiled: niri event-stream exited (${code})`); process.exit(1); });
```

- [ ] **Step 6: Make it executable**

Run: `chmod +x ~/d/dotfiles/wsprofiles/bin/wsprofiled`
Expected: no output; file is executable.

- [ ] **Step 7: Commit**

```bash
cd ~/d/dotfiles
git add -f wsprofiles/src/daemon.js wsprofiles/bin/wsprofiled wsprofiles/test/daemon.test.js
git commit -m "feat(wsprofiles): daemon wiring + control socket + entrypoint"
```

---

### Task 9: `wsprofilectl` control client

**Files:**
- Create: `wsprofiles/bin/wsprofilectl`
- Test: `wsprofiles/test/wsprofilectl.test.js`

**Interfaces:**
- Consumes: `SOCKET_PATH` from Task 8.
- Produces: `formatCommand(argv: string[]) -> string` — turn CLI args into the one-line socket protocol (`open <id>\n` / `new <id>\n`); exported from the bin for unit testing.

- [ ] **Step 1: Write the failing test**

```js
// wsprofiles/test/wsprofilectl.test.js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { formatCommand } from '../bin/wsprofilectl';

test('formats open/new into the line protocol', () => {
  assert.equal(formatCommand(['open', 'ember']), 'open ember\n');
  assert.equal(formatCommand(['new', 'tide']), 'new tide\n');
});

test('rejects unknown verbs and missing id', () => {
  assert.throws(() => formatCommand(['frob', 'ember']), /usage: wsprofilectl/);
  assert.throws(() => formatCommand(['open']), /usage: wsprofilectl/);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/wsprofilectl.test.js`
Expected: FAIL — `Cannot find module '../bin/wsprofilectl'`.

- [ ] **Step 3: Implement `bin/wsprofilectl`**

```js
#!/usr/bin/env node
// wsprofiles/bin/wsprofilectl
import { connect } from 'node:net';
import { SOCKET_PATH } from '../src/daemon.js';

export function formatCommand(argv) {
  const [verb, id] = argv;
  if (!['open', 'new'].includes(verb) || !id) {
    throw new Error('usage: wsprofilectl <open|new> <profile-id>');
  }
  return `${verb} ${id}\n`;
}

// Only act when run directly, so tests can import formatCommand cleanly.
if (import.meta.url === `file://${process.argv[1]}`) {
  const line = formatCommand(process.argv.slice(2));
  const sock = connect(SOCKET_PATH, () => { sock.end(line); });
  sock.on('error', (e) => { console.error('wsprofilectl:', e.message); process.exit(1); });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/d/dotfiles/wsprofiles && node --test test/wsprofilectl.test.js`
Expected: PASS — 2 tests.

- [ ] **Step 5: Make it executable and run the full suite**

Run: `chmod +x ~/d/dotfiles/wsprofiles/bin/wsprofilectl && cd ~/d/dotfiles/wsprofiles && npm test`
Expected: PASS — all suites green.

- [ ] **Step 6: Commit**

```bash
cd ~/d/dotfiles
git add -f wsprofiles/bin/wsprofilectl wsprofiles/test/wsprofilectl.test.js
git commit -m "feat(wsprofiles): wsprofilectl control client"
```

---

### Task 10: niri integration — include, binds, startup, live smoke test

**Files:**
- Modify: `niri/config.kdl` (add include, named-slot binds, spawn-at-startup)
- Create: `niri/profiles.kdl` (generated; tracked so the include resolves on boot)
- Modify: `.gitignore` (keep `wsprofiles/node_modules/` ignored; `niri/profiles.kdl` stays tracked)

**Interfaces:**
- Consumes: `bin/wsprofiled` (Task 8), `generateKdl` (Task 3).

- [ ] **Step 1: Generate the initial `profiles.kdl`**

Run: `cd ~/d/dotfiles/wsprofiles && node -e "import('./src/catalog.js').then(async c => { const {generateKdl}=await import('./src/kdl.js'); process.stdout.write(generateKdl(c.loadCatalog('profiles.yaml'))); })" > ~/d/dotfiles/niri/profiles.kdl`
Expected: `~/d/dotfiles/niri/profiles.kdl` contains `workspace "ember" { ... }`, `workspace "tide" { ... }`, `workspace "tide-2" { ... }` blocks.

- [ ] **Step 2: Add the include to `niri/config.kdl`**

In `niri/config.kdl`, below the existing `include "./host.kdl"` (around line 7), add:

```kdl
include "./profiles.kdl"
```

- [ ] **Step 3: Add a few named-slot test binds**

In the `binds {` block of `niri/config.kdl`, near the existing numeric workspace binds (around line 277), add (these are manual; `profiles.kdl` does NOT own binds):

```kdl
    Super+Alt+1 { focus-workspace "ember"; }
    Super+Alt+2 { focus-workspace "tide"; }
```

- [ ] **Step 4: Add the daemon to startup**

In `niri/config.kdl`, near the other `spawn-at-startup` lines (around line 90), add:

```kdl
spawn-sh-at-startup "node ~/d/dotfiles/wsprofiles/bin/wsprofiled"
```

- [ ] **Step 5: [live, post-migration] Validate niri parses the generated config**

Run: `niri validate`
Expected: no errors. (Confirms `include` resolves and per-workspace `focus-ring`/`border` blocks are accepted by the installed niri.)

- [ ] **Step 6: [live, post-migration] Smoke-test focus + ring color (Risk #2)**

Reload niri (`Super+Shift+C`), then press `Super+Alt+1`.
Expected: focus jumps to the (empty) `ember` workspace and its focus-ring renders in `#ff7a45`; `Super+Alt+2` → `tide`, ring `#3aa6ff`. Confirms focusing an empty predeclared named workspace works.

- [ ] **Step 7: [live, post-migration] Smoke-test the theme switch + control client**

Start the daemon if not already running (`node ~/d/dotfiles/wsprofiles/bin/wsprofiled &`), then:
Run: `~/d/dotfiles/wsprofiles/bin/wsprofilectl open ember`
Expected: focus moves to `ember` and noctalia switches to the ember wallpaper/colorscheme. Run `wsprofilectl new tide` → focus lands on `tide-2`.

- [ ] **Step 8: Commit**

```bash
cd ~/d/dotfiles
git add -f niri/config.kdl niri/profiles.kdl
git commit -m "feat(niri): wire wsprofiled — include, named-slot binds, startup"
```

---

## Self-Review

**Spec coverage:**
- Catalog (YAML, id/label/instances/ring/border/icon/theme) → Task 1. ✓
- Predeclared named slots + name→profile map (no suffix parsing) → Tasks 2, 8. ✓
- Per-workspace ring always, border only when set (global `border { off }`) → Task 3. ✓
- Theme switch via noctalia IPC (wallpaper/builtin/custom + mode) → Tasks 4, 7. ✓
- Free-instance via window occupancy (`Window.workspace_id`, not `WorkspacesChanged`) → Task 5. ✓
- niri event subscription + focus-by-name + reload-on-catalog-change → Tasks 6, 8. ✓
- Control socket + `wsprofilectl open/new` → Tasks 8, 9. ✓
- Phase 1 manual named-slot binds; `profiles.kdl` owns workspace blocks only → Task 10. ✓
- noctalia IPC name verification against installed build → Task 7 Step 5, Task 10 (live). ✓
- **Out of Phase 1 (own plans later):** the `mod-p` selector UI (Phase 2), bar label+icon (Phase 3), ohai avatars. Intentionally excluded.

**Placeholder scan:** no TBD/TODO; every code step contains complete code; every command has an expected result. Live steps that need the migrated shell are explicitly marked rather than faked.

**Type consistency:** `themeCommands` argv shape is identical across Tasks 4/7/8; `slotName`/`buildSlotMap` signatures match across Tasks 2/3/5/8; `OccupancyTracker.apply/windowCount/freeInstance` match across Tasks 5/8; `SOCKET_PATH` shared by Tasks 8/9; niri event field names (`workspace_id`, `is_focused`, `WorkspaceActivated.focused`) consistent across Tasks 5/6/8.
