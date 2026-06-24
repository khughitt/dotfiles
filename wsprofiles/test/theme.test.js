import { test } from 'node:test';
import assert from 'node:assert/strict';
import { themeCommands } from '../src/theme.js';

test('full theme: wallpaper (all screens), colorscheme, then mode', () => {
  const cmds = themeCommands({
    theme: { colorscheme: 'Tokyo Night', wallpaper: '/w/ember.jpg', mode: 'dark' },
  });
  assert.deepEqual(cmds, [
    ['wallpaper', 'set', '/w/ember.jpg', 'all'],
    ['colorScheme', 'set', 'Tokyo Night'],
    ['darkMode', 'setDark'],
  ]);
});

test('colorscheme + light mode, no wallpaper', () => {
  const cmds = themeCommands({
    theme: { colorscheme: 'Catppuccin', wallpaper: null, mode: 'light' },
  });
  assert.deepEqual(cmds, [
    ['colorScheme', 'set', 'Catppuccin'],
    ['darkMode', 'setLight'],
  ]);
});

test('omits commands for absent fields (ring-only profile)', () => {
  assert.deepEqual(themeCommands({ theme: { colorscheme: null, wallpaper: null, mode: null } }), []);
});

test('expands ~ in the wallpaper path', () => {
  const cmds = themeCommands({ theme: { colorscheme: null, wallpaper: '~/w.jpg', mode: null } });
  assert.match(cmds[0][2], /^\/.*\/w\.jpg$/);
});
