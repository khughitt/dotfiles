import { test } from 'node:test';
import assert from 'node:assert/strict';
import { runCommands } from '../src/noctalia.js';

test('prefixes each argv with the qs ipc call invocation, in order', async () => {
  const calls = [];
  const exec = (file, args) => {
    calls.push([file, ...args]);
    return Promise.resolve();
  };

  await runCommands([['colorScheme', 'set', 'Catppuccin'], ['darkMode', 'setDark']], { exec });

  assert.deepEqual(calls, [
    ['qs', '-c', 'noctalia-shell', 'ipc', 'call', 'colorScheme', 'set', 'Catppuccin'],
    ['qs', '-c', 'noctalia-shell', 'ipc', 'call', 'darkMode', 'setDark'],
  ]);
});
