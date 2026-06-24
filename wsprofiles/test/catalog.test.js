import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseCatalog } from '../src/catalog.js';

test('applies defaults and normalizes a minimal profile', () => {
  const cat = parseCatalog(`
profiles:
  - id: ember
    label: "Ember"
    ring: "#ff7a45"
    theme: { colorscheme: "Catppuccin" }
`);
  const p = cat.profiles[0];
  assert.equal(p.instances, 1);
  assert.equal(p.border, null);
  assert.equal(p.icon, '');
  assert.equal(p.theme.colorscheme, 'Catppuccin');
  assert.equal(p.theme.wallpaper, null);
  assert.equal(p.theme.mode, null);
});

test('rejects an invalid theme.mode', () => {
  assert.throws(() => parseCatalog(`
profiles:
  - id: ember
    label: "Ember"
    ring: "#fff"
    theme: { colorscheme: "X", mode: sideways }
`), /theme.mode must be dark\|light/);
});

test('rejects a ring that is not a hex color', () => {
  assert.throws(() => parseCatalog(`
profiles:
  - id: ember
    label: "Ember"
    ring: "red"
    theme: { colorscheme: "X" }
`), /ring must be a hex color/);
});

test('rejects a non-hex border', () => {
  assert.throws(() => parseCatalog(`
profiles:
  - id: ember
    label: "Ember"
    ring: "#ffffff"
    border: "blue"
    theme: { colorscheme: "X" }
`), /border must be a hex color/);
});

test('rejects an id ending in -<digits>', () => {
  assert.throws(() => parseCatalog(`
profiles:
  - id: api-2
    label: "Api"
    ring: "#fff"
    theme: { colorscheme: "X" }
`), /id .* must not end in -<digits>/);
});

test('rejects an id with illegal characters', () => {
  assert.throws(() => parseCatalog(`
profiles:
  - id: "Ember!"
    label: "Ember"
    ring: "#fff"
    theme: { colorscheme: "X" }
`), /id .* must match/);
});

test('rejects duplicate ids', () => {
  assert.throws(() => parseCatalog(`
profiles:
  - id: a
    label: "A"
    ring: "#fff"
    theme: { colorscheme: "X" }
  - id: a
    label: "A2"
    ring: "#000"
    theme: { colorscheme: "Y" }
`), /duplicate id/);
});
