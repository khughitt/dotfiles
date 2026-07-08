import { test } from 'node:test';
import assert from 'node:assert/strict';
import { reconcile } from '../src/reconcile.js';

const S = (id, idx, currentName, desiredBase, empty = false) => ({ id, idx, currentName, empty, desiredBase });

// NOTE (finding 1): reconcile does NOT record ownership for set/unset actions —
// the daemon does that only after the niri call succeeds. So after a reconcile
// that emits a `set`, ownedNames does not yet contain the wsId; after an
// `unset`, ownedNames still contains it. Only validation drops and confirmed
// matches change ownedNames inside reconcile.

test('names an unnamed workspace by index; ownership deferred to the caller', () => {
  const r = reconcile([S(1, 3, '', 'dotfiles')], new Map());
  assert.deepEqual(r.actions, [{ type: 'set', ref: 3, name: 'dotfiles', wsId: 1 }]);
  assert.equal(r.ownedNames.has(1), false); // recorded by daemon on success, not here
});

test('renames an owned workspace by its old name; ownership unchanged until success', () => {
  const r = reconcile([S(1, 3, 'pais', 'labnote')], new Map([[1, 'pais']]));
  assert.deepEqual(r.actions, [{ type: 'set', ref: 'pais', name: 'labnote', wsId: 1 }]);
  assert.equal(r.ownedNames.get(1), 'pais'); // still the old name until the set lands
});

test('never touches a foreign (non-owned) name', () => {
  const r = reconcile([S(1, 3, 'ember', 'infra')], new Map());
  assert.deepEqual(r.actions, []);
  assert.equal(r.ownedNames.has(1), false);
});

test('confirmed match: adopts ownership when current name already equals target', () => {
  const r = reconcile([S(1, 3, 'pais', 'pais')], new Map([[1, 'pais']]));
  assert.deepEqual(r.actions, []);
  assert.equal(r.ownedNames.get(1), 'pais'); // observation-based, applied in reconcile
});

test('unsets our name when the workspace empties; ownership held until unset lands', () => {
  const empt = reconcile([S(1, 3, 'pais', null, true)], new Map([[1, 'pais']]));
  assert.deepEqual(empt.actions, [{ type: 'unset', ref: 'pais', wsId: 1 }]);
  assert.equal(empt.ownedNames.get(1), 'pais'); // deleted by daemon on success, not here

  const occ = reconcile([S(1, 3, 'pais', null, false)], new Map([[1, 'pais']]));
  assert.deepEqual(occ.actions, []); // occupied but underivable → leave name
  assert.equal(occ.ownedNames.get(1), 'pais');
});

// FINDING 1 regression: external rename then empty must NOT unset the foreign name.
test('ownership validation: after external rename, empty does not unset', () => {
  // We owned 'infra'; wsprofiles renamed it to 'tide'; now it empties.
  const r = reconcile([S(1, 14, 'tide', null, true)], new Map([[1, 'infra']]));
  assert.deepEqual(r.actions, []);            // tide left alone
  assert.equal(r.ownedNames.has(1), false);   // ownership dropped by validation
});

// FINDING 2: duplicate derived names get unique -2/-3 slots, stable across passes.
test('allocates unique suffixes for duplicate base names', () => {
  const r = reconcile([S(1, 3, '', 'dotfiles'), S(2, 7, '', 'dotfiles')], new Map());
  assert.deepEqual(r.actions, [
    { type: 'set', ref: 3, name: 'dotfiles', wsId: 1 },
    { type: 'set', ref: 7, name: 'dotfiles-2', wsId: 2 },
  ]);
});

// FINDING 2: a foreign named workspace that derives a base name must NOT reserve it.
test('a foreign workspace does not reserve a base name it will never receive', () => {
  // ws9 is foreign-named 'ember' but its focused cwd derives 'dotfiles'. The real
  // unnamed 'dotfiles' workspace must still get 'dotfiles', not 'dotfiles-2'.
  const r = reconcile(
    [S(9, 2, 'ember', 'dotfiles', false), S(1, 3, '', 'dotfiles')],
    new Map()
  );
  assert.deepEqual(r.actions, [{ type: 'set', ref: 3, name: 'dotfiles', wsId: 1 }]);
});

test('a foreign name occupying a slot pushes the allocator past it', () => {
  // ws9 is a foreign 'dotfiles-2'; two wanters must land on dotfiles + dotfiles-3.
  const r = reconcile(
    [S(1, 3, '', 'dotfiles'), S(2, 7, '', 'dotfiles'), S(9, 9, 'dotfiles-2', 'x-unused', false)],
    new Map()
  );
  const names = r.actions.filter((a) => a.type === 'set' && (a.ref === 3 || a.ref === 7)).map((a) => a.name);
  assert.deepEqual(names, ['dotfiles', 'dotfiles-3']);
});

test('duplicate allocation is stable once owned', () => {
  const owned = new Map([[1, 'dotfiles'], [2, 'dotfiles-2']]);
  const r = reconcile([S(1, 3, 'dotfiles', 'dotfiles'), S(2, 7, 'dotfiles-2', 'dotfiles')], owned);
  assert.deepEqual(r.actions, []); // both already correct, no churn
  assert.equal(r.ownedNames.get(2), 'dotfiles-2');
});
