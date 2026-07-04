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
  for (const text of [
    '',
    '{ not json',
    '{}',
    JSON.stringify([{ id: 'ember' }]),
    JSON.stringify([{ id: 'bad', label: 'Bad', ring: 'nothex' }]),
  ]) {
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
  assert.deepEqual(plain(result.map(ws => ws.name)), ['ember', 'tide-2', 'scratchpad']);
});

test('filterWorkspaces: follows current screen with case-insensitive output matching', () => {
  const result = Logic.filterWorkspaces(workspaces, {
    screenName: 'dp-1',
    focusedOutput: 'HDMI-A-1',
    globalWorkspaces: false,
    followFocusedScreen: false,
    hideUnoccupied: false,
  });
  assert.deepEqual(plain(result.map(ws => ws.name)), ['ember', 'tide-2']);
});

test('filterWorkspaces: follows focused screen and can hide unoccupied workspaces', () => {
  const result = Logic.filterWorkspaces(workspaces, {
    screenName: 'DP-1',
    focusedOutput: 'dp-1',
    globalWorkspaces: false,
    followFocusedScreen: true,
    hideUnoccupied: true,
  });
  assert.deepEqual(plain(result.map(ws => ws.name)), ['ember']);
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
  assert.deepEqual(plain(result.map(ws => ws.name)), ['empty-focused']);
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
  assert.equal(Logic.pickForeground('#777777'), '#000000');
  assert.equal(Logic.pickForeground('#808080'), '#000000');
  assert.equal(Logic.pickForeground(''), '#ffffff');
  assert.equal(Logic.pickForeground('nothex'), '#ffffff');
  assert.equal(Logic.pickForeground(undefined), '#ffffff');
});

test('parseHexColor: parses shorthand and long hex colors', () => {
  assert.deepEqual(plain(Logic.parseHexColor('#fff')), { r: 255, g: 255, b: 255 });
  assert.deepEqual(plain(Logic.parseHexColor('#112233')), { r: 17, g: 34, b: 51 });
});

test('parseHexColor: invalid values return null', () => {
  assert.equal(Logic.parseHexColor(''), null);
  assert.equal(Logic.parseHexColor('nothex'), null);
  assert.equal(Logic.parseHexColor('#12'), null);
  assert.equal(Logic.parseHexColor(undefined), null);
});

test('channelLuminance: maps black and white endpoints', () => {
  assert.equal(Logic.channelLuminance(0), 0);
  assert.equal(Logic.channelLuminance(255), 1);
});

test('parseAgents: keeps valid records and reports no error', () => {
  const text = JSON.stringify({
    s1: { windowId: 42, state: 'waiting', project: 'ohai' },
    s2: { windowId: 57, state: 'working', project: 'dotfiles', reason: null },
  });
  const result = Logic.parseAgents(text);
  assert.equal(result.error, null);
  assert.deepEqual(plain(result.agents), {
    s1: { windowId: 42, state: 'waiting', project: 'ohai', reason: null },
    s2: { windowId: 57, state: 'working', project: 'dotfiles', reason: null },
  });
});

test('parseAgents: drops one malformed record but keeps its valid siblings', () => {
  const text = JSON.stringify({
    good: { windowId: 42, state: 'waiting', project: 'ohai' },
    badState: { windowId: 5, state: 'idle' },
    badWindow: { windowId: 'x', state: 'working' },
    notObject: 7,
  });
  const result = Logic.parseAgents(text);
  assert.equal(result.error, null);
  assert.deepEqual(Object.keys(plain(result.agents)), ['good']);
});

test('parseAgents: unparseable or non-object top level yields empty map with error', () => {
  for (const text of ['', '{ not json', '[1,2,3]', 'null', '42']) {
    const result = Logic.parseAgents(text);
    assert.deepEqual(plain(result.agents), {});
    assert.equal(typeof result.error, 'string');
    assert.ok(result.error.length > 0);
  }
});

const rollupCells = [
  { id: 1, idx: 1, name: 'ember', ring: '#ff7a45', label: 'Ember' },
  { id: 2, idx: 2, name: 'tide', ring: '#3aa6ff', label: 'Tide' },
  { id: 3, idx: 3, name: 'scratch', ring: null, label: 'scratch' },
];
// window 42 -> ws 1, window 57 -> ws 1, window 60 -> ws 2, window 99 -> ws 2
const windowIndex = { 42: 1, 57: 1, 60: 2, 99: 2 };

test('rollupAgents: a single waiting agent marks its workspace waiting', () => {
  const agents = { s1: { windowId: 60, state: 'waiting', project: 'x', reason: null } };
  const out = Logic.rollupAgents(rollupCells, agents, windowIndex);
  assert.deepEqual(plain(out.map((c) => c.agentStatus)), [null, 'waiting', null]);
});

test('rollupAgents: waiting beats working on the same workspace', () => {
  const agents = {
    a: { windowId: 42, state: 'working', project: 'x', reason: null },
    b: { windowId: 57, state: 'waiting', project: 'y', reason: null },
  };
  const out = Logic.rollupAgents(rollupCells, agents, windowIndex);
  assert.equal(out[0].agentStatus, 'waiting'); // ws 1
});

test('rollupAgents: only-working workspace reads working; empty reads null', () => {
  const agents = { a: { windowId: 99, state: 'working', project: 'x', reason: null } };
  const out = Logic.rollupAgents(rollupCells, agents, windowIndex);
  assert.deepEqual(plain(out.map((c) => c.agentStatus)), [null, 'working', null]);
});

test('rollupAgents: a record whose window is not in the index contributes nothing', () => {
  const agents = { a: { windowId: 12345, state: 'waiting', project: 'x', reason: null } };
  const out = Logic.rollupAgents(rollupCells, agents, windowIndex);
  assert.deepEqual(plain(out.map((c) => c.agentStatus)), [null, null, null]);
});

test('rollupAgents: a record on an off-screen workspace does not leak onto another cell', () => {
  // window 88 maps to workspace 9, which is not present in cells.
  const agents = { a: { windowId: 88, state: 'waiting', project: 'x', reason: null } };
  const out = Logic.rollupAgents(rollupCells, agents, { 88: 9 });
  assert.deepEqual(plain(out.map((c) => c.agentStatus)), [null, null, null]);
});

test('rollupAgents: preserves order and passes existing cell fields through', () => {
  const out = Logic.rollupAgents(rollupCells, {}, windowIndex);
  assert.deepEqual(plain(out.map((c) => c.id)), [1, 2, 3]);
  assert.equal(out[0].ring, '#ff7a45');
  assert.equal(out[0].label, 'Ember');
  assert.equal(out[0].agentStatus, null);
});
