import { test } from 'node:test';
import assert from 'node:assert/strict';
import { chmodSync, mkdtempSync, writeFileSync, readFileSync, existsSync, rmSync } from 'node:fs';
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

test('rollback restore errors preserve primary loadConfig rejection and continue rollback', async () => {
  const t = tmp();
  try {
    writeFileSync(t.kdl, 'PREV_KDL');
    writeFileSync(t.json, 'PREV_JSON');
    let caught;
    await applyCatalog({ catalog: catalogB, kdlPath: t.kdl, jsonPath: t.json,
      loadConfig: async () => {
        chmodSync(t.kdl, 0o400);
        throw new Error('niri rejected');
      } }).catch((error) => { caught = error; });

    assert.equal(caught?.message, 'niri rejected');
    assert.equal(readFileSync(t.json, 'utf8'), 'PREV_JSON');
    assert.equal(Array.isArray(caught.rollbackErrors), true);
    assert.ok(caught.rollbackErrors.length >= 1);
  } finally {
    if (existsSync(t.kdl)) chmodSync(t.kdl, 0o600);
    rmSync(t.dir, { recursive: true, force: true });
  }
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
