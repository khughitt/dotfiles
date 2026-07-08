import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseStat, foregroundCwd } from '../src/proc.js';

// pid comm state ppid pgrp session tty_nr tpgid ...
const stat = (pid, ppid, pgrp, ttyNr, tpgid, comm = 'zsh') =>
  `${pid} (${comm}) S ${ppid} ${pgrp} ${pgrp} ${ttyNr} ${tpgid} 0 0 0 0 0`;

test('parseStat handles comm containing spaces and parens', () => {
  const p = parseStat('4242 (ki (tt) y) S 4240 4242 4242 34816 4300 rest here');
  assert.deepEqual(p, { pid: 4242, ppid: 4240, pgrp: 4242, ttyNr: 34816, tpgid: 4300 });
});

test('foregroundCwd returns the foreground process-group leader cwd', () => {
  // kitty(100) -> shell(200) on a tty, running a job whose pgrp/leader is 250
  const io = {
    readChildren: (pid) => (pid === 100 ? [200] : []),
    readStat: (pid) => (pid === 200 ? stat(200, 100, 200, 34816, 250) : null),
    readCwd: (pid) => (pid === 250 ? '/home/keith/pais/src' : null),
  };
  assert.deepEqual(foregroundCwd(100, io), { cwd: '/home/keith/pais/src', ambiguous: false });
});

test('foregroundCwd uses the shell itself when no job is foregrounded', () => {
  const io = {
    readChildren: (pid) => (pid === 100 ? [200] : []),
    readStat: (pid) => (pid === 200 ? stat(200, 100, 200, 34816, 200) : null),
    readCwd: (pid) => (pid === 200 ? '/home/keith/labnote' : null),
  };
  assert.deepEqual(foregroundCwd(100, io), { cwd: '/home/keith/labnote', ambiguous: false });
});

test('foregroundCwd flags multi-tab windows as ambiguous (title fallback)', () => {
  const io = {
    readChildren: (pid) => (pid === 100 ? [200, 201] : []),
    readStat: (pid) => stat(pid, 100, pid, 34816, pid),
    readCwd: () => '/x',
  };
  assert.deepEqual(foregroundCwd(100, io), { cwd: null, ambiguous: true });
});

test('foregroundCwd ignores non-tty helper children and resolves the one shell', () => {
  const io = {
    readChildren: (pid) => (pid === 100 ? [200, 201] : []),
    readStat: (pid) =>
      pid === 200 ? stat(200, 100, 200, 0, 200) // tty_nr 0 → helper, ignored
      : pid === 201 ? stat(201, 100, 201, 34816, 260)
      : null,
    readCwd: (pid) => (pid === 260 ? '/home/keith/infra' : null),
  };
  assert.deepEqual(foregroundCwd(100, io), { cwd: '/home/keith/infra', ambiguous: false });
});

test('foregroundCwd: unreadable cwd (process gone) is unavailable, NOT ambiguous', () => {
  const io = {
    readChildren: () => [200],
    readStat: (pid) => (pid === 200 ? stat(200, 100, 200, 34816, 250) : null),
    readCwd: () => null,
  };
  assert.deepEqual(foregroundCwd(100, io), { cwd: null, ambiguous: false });
});

test('foregroundCwd: zero tty shells is unavailable, NOT ambiguous', () => {
  const io = {
    readChildren: (pid) => (pid === 100 ? [200] : []),
    readStat: (pid) => (pid === 200 ? stat(200, 100, 200, 0, 200) : null), // no tty
    readCwd: () => '/x',
  };
  assert.deepEqual(foregroundCwd(100, io), { cwd: null, ambiguous: false });
});
