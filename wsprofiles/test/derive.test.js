import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sanitizeName, appName, cwdName, deriveName } from '../src/derive.js';

const HOME = '/home/keith';
const isTerminal = (a) => a === 'kitty';

test('sanitizeName strips leading spinner/status glyphs and caps length', () => {
  assert.equal(sanitizeName('✳ Review sync'), 'Review sync');
  assert.equal(sanitizeName('⠙ science'), 'science');
  assert.equal(sanitizeName('  natural-systems '), 'natural-systems');
  assert.equal(sanitizeName('✳✳  '), null);
  assert.equal(sanitizeName(''), null);
  assert.equal(sanitizeName('x'.repeat(40)), 'x'.repeat(32));
});

test('appName normalizes reverse-dns and plain ids', () => {
  assert.equal(appName('firefox'), 'firefox');
  assert.equal(appName('org.foo.Bar'), 'bar');
  assert.equal(appName(''), null);
});

test('cwdName uses git root basename, else cwd basename, and skips bare $HOME', () => {
  const git = (cwd) => { if (cwd.startsWith(HOME + '/pais')) return HOME + '/pais'; throw new Error('not a repo'); };
  assert.equal(cwdName(HOME + '/pais/src/models', { git, home: HOME }), 'pais');
  assert.equal(cwdName(HOME + '/scratch/notes', { git, home: HOME }), 'notes'); // no repo → basename
  assert.equal(cwdName(HOME, { git, home: HOME }), null); // bare home → leave numbered
});

test('deriveName: kitty in a repo → repo name', () => {
  const io = {
    foregroundCwd: () => ({ cwd: HOME + '/labnote/app', ambiguous: false }),
    git: () => HOME + '/labnote',
    home: HOME, isTerminal,
  };
  assert.equal(deriveName({ appId: 'kitty', pid: 1, title: '⠴ whatever' }, io), 'labnote');
});

test('deriveName: kitty at bare home → null (leave numbered)', () => {
  const io = { foregroundCwd: () => ({ cwd: HOME, ambiguous: false }), git: () => { throw new Error('x'); }, home: HOME, isTerminal };
  assert.equal(deriveName({ appId: 'kitty', pid: 1, title: 'zsh' }, io), null);
});

test('deriveName: kitty multi-tab (ambiguous) → sanitized title fallback', () => {
  const io = { foregroundCwd: () => ({ cwd: null, ambiguous: true }), git: () => { throw new Error('x'); }, home: HOME, isTerminal };
  assert.equal(deriveName({ appId: 'kitty', pid: 1, title: '✳ mm30' }, io), 'mm30');
});

test('deriveName: kitty with unavailable cwd (proc race) → null, NOT the title', () => {
  const io = { foregroundCwd: () => ({ cwd: null, ambiguous: false }), git: () => { throw new Error('x'); }, home: HOME, isTerminal };
  assert.equal(deriveName({ appId: 'kitty', pid: 1, title: 'zsh' }, io), null);
});

test('deriveName: GUI app → app name (foregroundCwd not consulted)', () => {
  const io = { foregroundCwd: () => ({ cwd: null, ambiguous: false }), git: () => '', home: HOME, isTerminal };
  assert.equal(deriveName({ appId: 'firefox', pid: 1, title: 'Mozilla' }, io), 'firefox');
});
