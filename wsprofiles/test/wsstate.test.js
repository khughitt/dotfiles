import { test } from 'node:test';
import assert from 'node:assert/strict';
import { WorkspaceState } from '../src/wsstate.js';

const win = (id, wsId, extra = {}) => ({ id, workspace_id: wsId, app_id: 'kitty', pid: id * 10, title: `t${id}`, ...extra });

test('builds workspaces and picks the first window when none is focused', () => {
  const s = new WorkspaceState();
  s.apply({ WorkspacesChanged: { workspaces: [{ id: 1, idx: 3, name: '' }, { id: 2, idx: 4, name: 'ember' }] } });
  s.apply({ WindowsChanged: { windows: [win(20, 1), win(11, 1)] } });
  assert.equal(s.workspaces.get(2).name, 'ember');
  assert.equal(s.namingWindow(1).id, 11); // lowest id
  assert.equal(s.namingWindow(2), null);  // no windows
});

test('focused/active window wins over first', () => {
  const s = new WorkspaceState();
  s.apply({ WorkspacesChanged: { workspaces: [{ id: 1, idx: 3, name: '' }] } });
  s.apply({ WindowsChanged: { windows: [win(11, 1), win(20, 1)] } });
  s.apply({ WorkspaceActiveWindowChanged: { workspace_id: 1, active_window_id: 20 } });
  assert.equal(s.namingWindow(1).id, 20);
  assert.equal(s.namingWindow(1).appId, 'kitty');
});

test('is_focused on a window seeds the active window', () => {
  const s = new WorkspaceState();
  s.apply({ WorkspacesChanged: { workspaces: [{ id: 1, idx: 3, name: '' }] } });
  s.apply({ WindowOpenedOrChanged: { window: win(11, 1) } });
  s.apply({ WindowOpenedOrChanged: { window: win(20, 1, { is_focused: true }) } });
  assert.equal(s.namingWindow(1).id, 20);
});

test('window close and move update membership', () => {
  const s = new WorkspaceState();
  s.apply({ WorkspacesChanged: { workspaces: [{ id: 1, idx: 3, name: '' }, { id: 2, idx: 4, name: '' }] } });
  s.apply({ WindowsChanged: { windows: [win(11, 1)] } });
  s.apply({ WindowOpenedOrChanged: { window: win(11, 2) } }); // moved 1 -> 2
  assert.equal(s.namingWindow(1), null);
  assert.equal(s.namingWindow(2).id, 11);
  s.apply({ WindowClosed: { id: 11 } });
  assert.equal(s.namingWindow(2), null);
});
