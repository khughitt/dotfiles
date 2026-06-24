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
