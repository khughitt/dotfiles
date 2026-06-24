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

test('new focuses a free extra slot, falling back to primary when full', async () => {
  const { d, focused, occupancy } = makeDaemon();
  await d.new('tide');
  assert.equal(focused.at(-1), 'tide-2');
  occupancy.apply({ WorkspacesChanged: { workspaces: [{ id: 1, name: 'tide-2' }] } });
  occupancy.apply({ WindowsChanged: { windows: [{ id: 9, workspace_id: 1 }] } });
  await d.new('tide');
  assert.equal(focused.at(-1), 'tide');
});
