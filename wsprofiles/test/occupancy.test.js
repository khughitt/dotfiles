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
