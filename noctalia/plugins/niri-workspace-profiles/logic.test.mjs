import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

function loadLogic() {
  const path = fileURLToPath(new URL('./logic.js', import.meta.url));
  const src = readFileSync(path, 'utf8').replace(/^\s*\.pragma\s+library\s*$/m, '');
  const context = {};
  vm.runInNewContext(src, context);
  return context;
}

const Logic = loadLogic();

function plain(value) {
  return value === null ? null : JSON.parse(JSON.stringify(value));
}

const profiles = [
  { id: 'ember', label: 'Ember - client-api', icon: '', ring: '#ff7a45' },
  { id: 'tide', label: 'Tide - infra', icon: 'T', ring: '#3aa6ff' },
  { id: 'api2', label: 'API Two', icon: 'A', ring: '#222222' },
];

const workspaces = [
  { id: 1, idx: 1, name: 'ember', output: 'DP-1', isFocused: true, isOccupied: true, isUrgent: false },
  { id: 2, idx: 2, name: 'tide-2', output: 'DP-1', isFocused: false, isOccupied: false, isUrgent: true },
  { id: 3, idx: 3, name: 'scratchpad', output: 'HDMI-A-1', isFocused: false, isOccupied: true, isUrgent: false },
];

test('parseProfiles: valid profile array returns profiles and no error', () => {
  const result = Logic.parseProfiles(JSON.stringify(profiles));
  assert.equal(result.error, null);
  assert.deepEqual(plain(result.profiles), profiles);
});

test('parseProfiles: invalid inputs return empty profiles and an error', () => {
  for (const text of ['', '{ not json', '{}', JSON.stringify([{ id: 'ember' }])]) {
    const result = Logic.parseProfiles(text);
    assert.deepEqual(plain(result.profiles), []);
    assert.equal(typeof result.error, 'string');
    assert.ok(result.error.length > 0);
  }
});

test('resolveProfile: exact id and instance suffix resolution', () => {
  assert.equal(Logic.resolveProfile('ember', profiles).id, 'ember');
  assert.equal(Logic.resolveProfile('tide-2', profiles).id, 'tide');
  assert.equal(Logic.resolveProfile('tide-3', profiles).id, 'tide');
  assert.equal(Logic.resolveProfile('api2', profiles).id, 'api2');
  assert.equal(Logic.resolveProfile('scratchpad', profiles), null);
});

test('filterWorkspaces: globalWorkspaces keeps all outputs', () => {
  const result = Logic.filterWorkspaces(workspaces, {
    screenName: 'DP-1',
    focusedOutput: 'DP-1',
    globalWorkspaces: true,
    followFocusedScreen: false,
    hideUnoccupied: false,
  });
  assert.deepEqual(result.map(ws => ws.name), ['ember', 'tide-2', 'scratchpad']);
});

test('filterWorkspaces: follows current screen with case-insensitive output matching', () => {
  const result = Logic.filterWorkspaces(workspaces, {
    screenName: 'dp-1',
    focusedOutput: 'HDMI-A-1',
    globalWorkspaces: false,
    followFocusedScreen: false,
    hideUnoccupied: false,
  });
  assert.deepEqual(result.map(ws => ws.name), ['ember', 'tide-2']);
});

test('filterWorkspaces: follows focused screen and can hide unoccupied workspaces', () => {
  const result = Logic.filterWorkspaces(workspaces, {
    screenName: 'DP-1',
    focusedOutput: 'dp-1',
    globalWorkspaces: false,
    followFocusedScreen: true,
    hideUnoccupied: true,
  });
  assert.deepEqual(result.map(ws => ws.name), ['ember']);
});

test('filterWorkspaces: hideUnoccupied keeps the focused workspace even when empty', () => {
  const result = Logic.filterWorkspaces([
    { id: 4, idx: 4, name: 'empty-focused', output: 'DP-1', isFocused: true, isOccupied: false },
    { id: 5, idx: 5, name: 'empty-other', output: 'DP-1', isFocused: false, isOccupied: false },
  ], {
    screenName: 'DP-1',
    focusedOutput: 'DP-1',
    globalWorkspaces: false,
    followFocusedScreen: false,
    hideUnoccupied: true,
  });
  assert.deepEqual(result.map(ws => ws.name), ['empty-focused']);
});

test('buildCells: maps profiled and unprofiled workspaces in order', () => {
  const result = Logic.buildCells(workspaces, profiles);
  assert.deepEqual(plain(result), [
    {
      id: 1,
      idx: 1,
      name: 'ember',
      output: 'DP-1',
      hasProfile: true,
      ring: '#ff7a45',
      glyph: 'E',
      label: 'Ember - client-api',
      isFocused: true,
      isOccupied: true,
      isUrgent: false,
    },
    {
      id: 2,
      idx: 2,
      name: 'tide-2',
      output: 'DP-1',
      hasProfile: true,
      ring: '#3aa6ff',
      glyph: 'T',
      label: 'Tide - infra',
      isFocused: false,
      isOccupied: false,
      isUrgent: true,
    },
    {
      id: 3,
      idx: 3,
      name: 'scratchpad',
      output: 'HDMI-A-1',
      hasProfile: false,
      ring: null,
      glyph: '3',
      label: 'scratchpad',
      isFocused: false,
      isOccupied: true,
      isUrgent: false,
    },
  ]);
});

test('buildCells: unprofiled workspace without idx uses dot glyph', () => {
  const result = Logic.buildCells([{ id: 9, name: 'scratchpad', output: 'DP-1' }], []);
  assert.equal(result[0].glyph, '.');
  assert.equal(result[0].hasProfile, false);
});

test('buildCells: empty workspaces returns empty cells', () => {
  assert.deepEqual(plain(Logic.buildCells([], profiles)), []);
});

test('pickForeground: returns readable black or white foreground', () => {
  assert.equal(Logic.pickForeground('#ffffff'), '#000000');
  assert.equal(Logic.pickForeground('#ff7a45'), '#000000');
  assert.equal(Logic.pickForeground('#000000'), '#ffffff');
  assert.equal(Logic.pickForeground('#1e1e2e'), '#ffffff');
  assert.equal(Logic.pickForeground('#fff'), '#000000');
  assert.equal(Logic.pickForeground(''), '#ffffff');
  assert.equal(Logic.pickForeground('nothex'), '#ffffff');
  assert.equal(Logic.pickForeground(undefined), '#ffffff');
});
