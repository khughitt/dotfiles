import { test } from 'node:test';
import assert from 'node:assert/strict';
import { classifyReply, formatCommand } from '../bin/wsprofilectl';

test('formats open/new into the line protocol', () => {
  assert.equal(formatCommand(['open', 'ember']), 'open ember\n');
  assert.equal(formatCommand(['new', 'tide']), 'new tide\n');
});

test('rejects unknown verbs and missing id', () => {
  assert.throws(() => formatCommand(['frob', 'ember']), /usage: wsprofilectl/);
  assert.throws(() => formatCommand(['open']), /usage: wsprofilectl/);
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
