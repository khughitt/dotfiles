#!/usr/bin/env node
// Whole-store backups use the same writer lock as web and maintenance CLI writes.
import { execFile } from 'node:child_process';
import { createHash, randomUUID } from 'node:crypto';
import { createReadStream } from 'node:fs';
import { chmod, mkdir, mkdtemp, readFile, realpath, rename, rm, stat, writeFile } from 'node:fs/promises';
import { isAbsolute, join, resolve, sep } from 'node:path';
import { pathToFileURL } from 'node:url';
import { parseArgs, promisify } from 'node:util';

process.umask(0o077);
const exec = promisify(execFile);
const cancellation = new AbortController();
for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => cancellation.abort(new Error(`backup interrupted by ${signal}`)));
}
async function command(program, args, cancellable = true) {
  const signal = cancellable ? cancellation.signal : undefined;
  signal?.throwIfAborted();
  const operation = exec(program, args, { maxBuffer: 1024 * 1024 });
  let killTimer;
  const kill = signalName => operation.child.kill(signalName);
  const cancel = () => {
    kill('SIGTERM');
    killTimer = setTimeout(() => kill('SIGKILL'), 5000);
    killTimer.unref();
  };
  signal?.addEventListener('abort', cancel, { once: true });
  try {
    // execFile settles after child exit and closed pipes; keep the writer lock until then.
    const result = await operation;
    signal?.throwIfAborted();
    return result.stdout.trim();
  } catch (error) {
    throw new Error(`${program} failed: ${signal?.aborted ? signal.reason.message : error.stderr?.trim() || error.message}`,
      { cause: error });
  } finally {
    signal?.removeEventListener('abort', cancel);
    clearTimeout(killTimer);
  }
}
const systemctl = (...args) => command('systemctl', ['--user', ...args], args[0] !== 'start');
const within = (parent, child) => child === parent || child.startsWith(parent + sep);

async function backup(values) {
  for (const name of ['release', 'root', 'output', 'service']) {
    if (!values[name]) throw new Error(`--${name} is required`);
  }
  if (!/^[A-Za-z0-9_.@-]+\.service$/.test(values.service) || values.service.startsWith('-')) {
    throw new Error('expected a service unit name');
  }
  const release = await realpath(values.release);
  const root = await realpath(values.root);
  if (!(await stat(root)).isDirectory()) throw new Error('root must be an existing store directory');
  const attachments = values.attachments ? JSON.parse(await readFile(values.attachments, 'utf8')) : [];
  if (!Array.isArray(attachments)) throw new Error('attachments must be an array of {path, name}');
  const names = new Set();
  for (const item of attachments) {
    if (!item || typeof item.path !== 'string' || !isAbsolute(item.path) || item.path.split(sep).includes('..') ||
        typeof item.name !== 'string' || !/^[A-Za-z0-9_-][A-Za-z0-9_.-]*$/.test(item.name) ||
        names.has(item.name)) throw new Error('attachment paths must be absolute, with unique simple archive names');
    names.add(item.name);
    item.path = await realpath(item.path);
    if (!(await stat(item.path)).isDirectory()) throw new Error('attachment roots must be directories');
  }
  await mkdir(resolve(values.output), { recursive: true });
  const output = await realpath(values.output);
  for (const source of [root, ...attachments.map(item => item.path)]) {
    if (within(source, output)) throw new Error('backup output must be outside every archived root');
  }
  const { acquireWriterLock } = await import(pathToFileURL(join(release, 'packages/mindful/dist/index.js')).href);
  const state = await systemctl('show', '--property=ActiveState', '--value', '--', values.service);
  if (!['active', 'inactive', 'failed'].includes(state)) throw new Error(`unstable or unknown service state: ${state}`);
  const wasActive = state === 'active';
  const failures = [];
  let lock, temporary, checksumPath, archive;
  try {
    if (wasActive) await systemctl('stop', '--', values.service);
    lock = acquireWriterLock(root, 'cli');
    temporary = await mkdtemp(join(output, '.mindful-backup-'));
    const tar = join(temporary, 'backup.tar');
    await command('tar', ['--create', '--file', tar, '--exclude=./.nodes-index', '--exclude=./.mindful-index',
      '--transform=flags=rh;s,^\\.,store,', '--directory', root, '.']);
    for (const item of attachments) {
      await command('tar', ['--append', '--file', tar, `--transform=flags=rh;s,^\\.,attachments/${item.name},`,
        '--directory', item.path, '.']);
    }
    await writeFile(join(temporary, 'backup.json'), JSON.stringify({
      created_at: new Date().toISOString(), release, root, service: values.service, was_active: wasActive, attachments,
    }, null, 2) + '\n', { mode: 0o600 });
    await command('tar', ['--append', '--file', tar, '--directory', temporary, 'backup.json']);
    await command('gzip', ['--', tar]);
    const compressed = tar + '.gz';
    await command('gzip', ['--test', '--', compressed]);
    await command('tar', ['--list', '--gzip', '--file', compressed, '--index-file=/dev/null']);
    await chmod(compressed, 0o600);
    const hash = createHash('sha256');
    for await (const chunk of createReadStream(compressed)) hash.update(chunk);
    cancellation.signal.throwIfAborted();
    const digest = hash.digest('hex');
    const filename = `mindful-${new Date().toISOString().replaceAll(':', '-')}-${randomUUID()}.tar.gz`;
    archive = join(output, filename);
    checksumPath = archive + '.sha256';
    await writeFile(checksumPath, `${digest}  ${filename}\n`, { flag: 'wx', mode: 0o600 });
    await rename(compressed, archive);
    checksumPath = undefined;
  } catch (error) {
    failures.push(error);
  } finally {
    for (const cleanup of [
      () => checksumPath && rm(checksumPath),
      () => temporary && rm(temporary, { recursive: true, force: true }),
      () => lock?.release(),
      () => wasActive && systemctl('start', '--', values.service),
    ]) {
      try { await cleanup(); } catch (error) { failures.push(error); }
    }
  }
  if (failures.length) throw new AggregateError(failures, 'backup failed');
  return { archive };
}

try {
  const { values } = parseArgs({ options: Object.fromEntries(
    ['release', 'root', 'output', 'service', 'attachments'].map(name => [name, { type: 'string' }]),
  ) });
  console.log(JSON.stringify(await backup(values)));
} catch (error) {
  console.error(`mindful-backup: ${error.message}`);
  for (const failure of error.errors ?? []) console.error(failure.message);
  process.exitCode = 1;
}
