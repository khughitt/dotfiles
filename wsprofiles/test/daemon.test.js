import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Daemon, parseControlLine } from '../src/daemon.js';
import { OccupancyTracker } from '../src/occupancy.js';

function makeDaemon() {
  const focused = [];
  const themed = [];
  const niri = { focusWorkspace: (n) => { focused.push(n); return Promise.resolve(); } };
  const noctalia = { runCommands: (c) => { themed.push(c); return Promise.resolve(); } };
  const catalog = { profiles: [
    { id: 'ember', instances: 1, ring: '#f00',
      theme: { colorscheme: 'X', wallpaper: null, mode: 'dark' } },
    { id: 'tide', instances: 2, ring: '#00f',
      theme: { colorscheme: 'Y', wallpaper: null, mode: 'dark' } },
  ] };
  const occupancy = new OccupancyTracker();
  return { d: new Daemon({ catalog, niri, noctalia, occupancy }), focused, themed, occupancy };
}

test('onFocus applies the resolved profile theme; unknown names are ignored', async () => {
  const { d, themed } = makeDaemon();
  await d.onFocus('tide-2');
  assert.deepEqual(themed.at(-1), [['colorScheme', 'set', 'Y'], ['darkMode', 'setDark']]);
  await d.onFocus('scratchpad');
  assert.equal(themed.length, 1);
});

test('a newer focus supersedes an older queued one (no stale apply)', async () => {
  const { d, themed } = makeDaemon();
  const p1 = d.onFocus('ember');
  const p2 = d.onFocus('tide');
  await Promise.all([p1, p2]);
  assert.equal(themed.length, 1);
  assert.deepEqual(themed[0], [['colorScheme', 'set', 'Y'], ['darkMode', 'setDark']]);
});

test('open focuses the primary slot', async () => {
  const { d, focused } = makeDaemon();
  await d.open('tide');
  assert.deepEqual(focused, ['tide']);
});

test('parseControlLine accepts exact open and new requests', () => {
  assert.deepEqual(parseControlLine('open ember'), { cmd: 'open', id: 'ember' });
  assert.deepEqual(parseControlLine('new tide'), { cmd: 'new', id: 'tide' });
});

test('parseControlLine rejects malformed requests', () => {
  assert.throws(() => parseControlLine('open ember extra'), /usage: open\|new <profile-id>/);
  assert.throws(() => parseControlLine('open ember tide'), /usage: open\|new <profile-id>/);
  assert.throws(() => parseControlLine('open'), /usage: open\|new <profile-id>/);
  assert.throws(() => parseControlLine('open ember\t'), /usage: open\|new <profile-id>/);
  assert.throws(() => parseControlLine('open ember\ntide'), /usage: open\|new <profile-id>/);
  assert.throws(() => parseControlLine('open ember-2'), /usage: open\|new <profile-id>/);
  assert.throws(() => parseControlLine('frob ember'), /usage: open\|new <profile-id>/);
});

test('open rejects an unknown profile id', async () => {
  const { d, focused } = makeDaemon();
  await assert.rejects(() => d.open('missing'), /unknown profile id: missing/);
  assert.deepEqual(focused, []);
});

test('new focuses a free extra slot, falling back to primary when full', async () => {
  const { d, focused, occupancy } = makeDaemon();
  await d.new('tide');
  assert.equal(focused.at(-1), 'tide-2');
  occupancy.apply({ WorkspacesChanged: { workspaces: [{ id: 1, name: 'tide-2' }] } });
  occupancy.apply({ WindowsChanged: { windows: [{ id: 9, workspace_id: 1 }] } });
  await d.new('tide');
  assert.equal(focused.at(-1), 'tide');
});

test('new rejects an unknown profile id', async () => {
  const { d, focused } = makeDaemon();
  await assert.rejects(() => d.new('missing'), /unknown profile id: missing/);
  assert.deepEqual(focused, []);
});

test('updateCatalog refreshes mappings without replacing the apply chain', async () => {
  const { d, focused, themed } = makeDaemon();
  const chain = d._applyChain;
  const nextCatalog = { profiles: [
    { id: 'fern', instances: 2, ring: '#0f0',
      theme: { colorscheme: 'Z', wallpaper: null, mode: 'light' } },
  ] };

  d.updateCatalog(nextCatalog);

  assert.equal(d.catalog, nextCatalog);
  assert.equal(d._applyChain, chain);
  await d.open('fern');
  assert.deepEqual(focused, ['fern']);
  await d.onFocus('fern-2');
  assert.deepEqual(themed.at(-1), [['colorScheme', 'set', 'Z'], ['darkMode', 'setLight']]);
  await assert.rejects(() => d.open('tide'), /unknown profile id: tide/);
});
