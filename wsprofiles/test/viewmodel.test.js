import { test } from 'node:test';
import assert from 'node:assert/strict';
import { viewModel } from '../src/viewmodel.js';

const catalog = { profiles: [
  { id: 'ember', label: 'Ember — client-api', instances: 1,
    ring: '#ff7a45', border: '#ff7a45', icon: '',
    theme: { colorscheme: 'Tokyo Night', wallpaper: null, mode: 'dark' } },
  { id: 'tide', label: 'Tide — infra', instances: 2,
    ring: '#3aa6ff', border: null, icon: '',
    theme: { colorscheme: 'Catppuccin', wallpaper: null, mode: 'dark' } },
] };

test('maps id/label/icon/ring/instances in catalog order', () => {
  const vm = viewModel(catalog);
  assert.equal(vm.length, 2);
  assert.deepEqual(vm[0], {
    id: 'ember', label: 'Ember — client-api', icon: '',
    ring: '#ff7a45', border: '#ff7a45', instances: 1,
  });
  assert.equal(vm[1].id, 'tide');
});

test('emits border null when absent, hex when present', () => {
  const vm = viewModel(catalog);
  assert.equal(vm[0].border, '#ff7a45');
  assert.equal(vm[1].border, null);
});

test('omits theme and other internal fields', () => {
  const vm = viewModel(catalog);
  assert.equal('theme' in vm[0], false);
});

test('empty catalog yields empty array', () => {
  assert.deepEqual(viewModel({ profiles: [] }), []);
});
