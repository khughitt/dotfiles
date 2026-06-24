import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync, symlinkSync } from 'node:fs';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { classifyReply, formatCommand } from '../bin/wsprofilectl';

test('formats open/new into the line protocol', () => {
  assert.equal(formatCommand(['open', 'ember']), 'open ember\n');
  assert.equal(formatCommand(['new', 'tide']), 'new tide\n');
  assert.equal(formatCommand(['open', 'ember-work']), 'open ember-work\n');
});

test('rejects unknown verbs, missing id, and extra args', () => {
  assert.throws(() => formatCommand(['frob', 'ember']), /usage: wsprofilectl/);
  assert.throws(() => formatCommand(['open']), /usage: wsprofilectl/);
  assert.throws(() => formatCommand(['open', 'ember', 'extra']), /usage: wsprofilectl/);
});

test('rejects invalid profile id tokens', () => {
  assert.throws(() => formatCommand(['open', '']), /usage: wsprofilectl/);
  assert.throws(() => formatCommand(['open', 'ember tide']), /usage: wsprofilectl/);
  assert.throws(() => formatCommand(['open', 'ember\ntide']), /usage: wsprofilectl/);
  assert.throws(() => formatCommand(['open', 'ember-2']), /usage: wsprofilectl/);
});

test('classifies ok and error replies', () => {
  assert.deepEqual(classifyReply('ok\n'), { ok: true });
  assert.deepEqual(classifyReply('error unknown profile\n'), {
    ok: false,
    message: 'error unknown profile',
  });
});

test('rejects unexpected replies', () => {
  assert.deepEqual(classifyReply('okay\n'), {
    ok: false,
    message: 'unexpected reply: okay',
  });
  assert.deepEqual(classifyReply('error\n'), {
    ok: false,
    message: 'unexpected reply: error',
  });
  assert.deepEqual(classifyReply('ok\nextra'), {
    ok: false,
    message: 'unexpected reply: ok\nextra',
  });
  assert.deepEqual(classifyReply('ok\nextra\n'), {
    ok: false,
    message: 'unexpected reply: ok\nextra\n',
  });
  assert.deepEqual(classifyReply('error nope\nextra'), {
    ok: false,
    message: 'unexpected reply: error nope\nextra',
  });
});

test('rejects incomplete replies', () => {
  assert.deepEqual(classifyReply('ok'), {
    ok: false,
    message: 'incomplete reply: ok',
  });
  assert.deepEqual(classifyReply(''), {
    ok: false,
    message: 'incomplete reply: ',
  });
});

test('cli runs when invoked through a symlink', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'wsprofilectl-'));
  const linkPath = join(dir, 'wsprofilectl');

  try {
    symlinkSync(join(process.cwd(), 'bin/wsprofilectl'), linkPath);

    const child = spawn(process.execPath, [linkPath, 'invalid'], {
      cwd: process.cwd(),
      stdio: ['ignore', 'ignore', 'pipe'],
    });
    let stderr = '';
    child.stderr.on('data', (d) => { stderr += d; });

    const code = await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('wsprofilectl timed out')), 2000);
      child.once('error', reject);
      child.once('close', (c) => {
        clearTimeout(timer);
        resolve(c);
      });
    });

    assert.equal(code, 1);
    assert.match(stderr, /wsprofilectl: usage: wsprofilectl <open\|new> <profile-id>/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('cli rejects extra data sent after an ok line', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'wsprofilectl-'));
  const sockets = new Set();
  const server = createServer((sock) => {
    sockets.add(sock);
    sock.on('close', () => sockets.delete(sock));
    sock.on('error', () => {});
    sock.write('ok\n');
    setTimeout(() => sock.end('extra'), 20);
  });

  try {
    await new Promise((resolve, reject) => {
      server
        .once('listening', resolve)
        .once('error', reject)
        .listen(join(dir, 'wsprofiled.sock'));
    });

    const child = spawn(process.execPath, ['bin/wsprofilectl', 'open', 'ember'], {
      cwd: process.cwd(),
      env: { ...process.env, XDG_RUNTIME_DIR: dir },
      stdio: ['ignore', 'ignore', 'pipe'],
    });
    let stderr = '';
    child.stderr.on('data', (d) => { stderr += d; });

    const code = await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('wsprofilectl timed out')), 2000);
      child.once('error', reject);
      child.once('close', (c) => {
        clearTimeout(timer);
        resolve(c);
      });
    });

    assert.equal(code, 1);
    assert.match(stderr, /wsprofilectl: unexpected reply: ok\nextra/);
  } finally {
    for (const sock of sockets) sock.destroy();
    await new Promise((resolve) => server.close(resolve));
    rmSync(dir, { recursive: true, force: true });
  }
});
