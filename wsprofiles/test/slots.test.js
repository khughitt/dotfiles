import { test } from 'node:test';
import assert from 'node:assert/strict';
import { slotName, listSlots, buildSlotMap } from '../src/slots.js';

test('slotName: instance 1 is the bare id, >=2 is suffixed', () => {
  assert.equal(slotName('ember', 1), 'ember');
  assert.equal(slotName('ember', 2), 'ember-2');
  assert.equal(slotName('ember', 3), 'ember-3');
});

test('listSlots returns one entry per instance', () => {
  const slots = listSlots({ id: 'tide', instances: 2 });
  assert.deepEqual(slots, [
    { name: 'tide', instance: 1 },
    { name: 'tide-2', instance: 2 },
  ]);
});

test('buildSlotMap resolves every generated name back to its profile', () => {
  const map = buildSlotMap({ profiles: [
    { id: 'ember', instances: 1 },
    { id: 'tide', instances: 2 },
  ] });
  assert.deepEqual(map.get('ember'), { profileId: 'ember', instance: 1 });
  assert.deepEqual(map.get('tide'), { profileId: 'tide', instance: 1 });
  assert.deepEqual(map.get('tide-2'), { profileId: 'tide', instance: 2 });
  assert.equal(map.has('ember-2'), false);
});
