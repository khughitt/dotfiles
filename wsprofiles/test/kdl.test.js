import { test } from 'node:test';
import assert from 'node:assert/strict';
import { generateKdl } from '../src/kdl.js';

const catalog = { profiles: [
  { id: 'ember', instances: 1, ring: '#ff7a45', border: '#ff7a45',
    theme: {} },
  { id: 'tide', instances: 2, ring: '#3aa6ff', border: null,
    theme: {} },
] };

test('emits focus-ring active-color for every slot', () => {
  const kdl = generateKdl(catalog);
  assert.match(kdl, /workspace "ember" \{/);
  assert.match(kdl, /workspace "tide" \{/);
  assert.match(kdl, /workspace "tide-2" \{/);
  assert.match(kdl, /focus-ring \{\s*active-color "#3aa6ff"/);
});

test('emits a border block only when border color is set', () => {
  const kdl = generateKdl(catalog);
  const emberBlock = kdl.slice(kdl.indexOf('workspace "ember"'), kdl.indexOf('workspace "tide"'));
  const tideBlock = kdl.slice(kdl.indexOf('workspace "tide" '));
  assert.match(emberBlock, /border \{\s*on\s*active-color "#ff7a45"/);
  assert.doesNotMatch(tideBlock, /border \{/);
});

test('is deterministic (stable ordering)', () => {
  assert.equal(generateKdl(catalog), generateKdl(catalog));
});
