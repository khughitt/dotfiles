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

function plain(value) {
  return value === null ? null : JSON.parse(JSON.stringify(value));
}

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
  assert.deepEqual(plain(r.profiles), []);
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
  assert.deepEqual(plain(Logic.keyToAction('1', { shift: false }, state(P, 0))), { type: 'open', id: 'ember' });
  assert.deepEqual(plain(Logic.keyToAction('2', { shift: true }, state(P, 0))), { type: 'new', id: 'tide' });
});

test('digit beyond profile count and digit 0 are no-ops', () => {
  assert.equal(Logic.keyToAction('3', { shift: false }, state(P, 0)), null);
  assert.equal(Logic.keyToAction('0', { shift: false }, state(P, 0)), null);
});

test('multi-character digit-like keys are unmapped', () => {
  const manyProfiles = Array.from({ length: 10 }, (_, i) => ({ id: 'p' + i }));
  assert.equal(Logic.keyToAction('10', { shift: false }, state(manyProfiles, 0)), null);
  assert.equal(Logic.keyToAction('1a', { shift: false }, state(manyProfiles, 0)), null);
});

test('Enter on a profile row opens it; Shift+Enter opens a new instance', () => {
  assert.deepEqual(plain(Logic.keyToAction('Enter', { shift: false }, state(P, 1))), { type: 'open', id: 'tide' });
  assert.deepEqual(plain(Logic.keyToAction('Enter', { shift: true }, state(P, 0))), { type: 'new', id: 'ember' });
});

test('Enter on the +new row, and + from anywhere, open the editor', () => {
  assert.deepEqual(plain(Logic.keyToAction('Enter', { shift: false }, state(P, 2))), { type: 'editor' });
  assert.deepEqual(plain(Logic.keyToAction('+', { shift: false }, state(P, 0))), { type: 'editor' });
});

test('Down/Tab advance highlight and wrap past the +new row to the top', () => {
  assert.deepEqual(plain(Logic.keyToAction('Down', { shift: false }, state(P, 1))), { type: 'move', highlight: 2 });
  assert.deepEqual(plain(Logic.keyToAction('Tab', { shift: false }, state(P, 2))), { type: 'move', highlight: 0 });
});

test('Up and Shift+Tab move back and wrap', () => {
  assert.deepEqual(plain(Logic.keyToAction('Up', { shift: false }, state(P, 0))), { type: 'move', highlight: 2 });
  assert.deepEqual(plain(Logic.keyToAction('Tab', { shift: true }, state(P, 0))), { type: 'move', highlight: 2 });
});

test('Escape hides; unmapped key is null', () => {
  assert.deepEqual(plain(Logic.keyToAction('Escape', { shift: false }, state(P, 0))), { type: 'hide' });
  assert.equal(Logic.keyToAction('x', { shift: false }, state(P, 0)), null);
});
