import { test } from 'node:test';
import assert from 'node:assert/strict';
import { formatCommand } from '../bin/wsprofilectl';

test('formats open/new into the line protocol', () => {
  assert.equal(formatCommand(['open', 'ember']), 'open ember\n');
  assert.equal(formatCommand(['new', 'tide']), 'new tide\n');
});

test('rejects unknown verbs and missing id', () => {
  assert.throws(() => formatCommand(['frob', 'ember']), /usage: wsprofilectl/);
  assert.throws(() => formatCommand(['open']), /usage: wsprofilectl/);
});
