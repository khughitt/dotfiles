import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const defaultExec = promisify(execFile);
const IPC_PREFIX = ['-c', 'noctalia-shell', 'ipc', 'call'];

export async function runCommands(cmds, opts = {}) {
  const exec = opts.exec ?? defaultExec;

  for (const argv of cmds) {
    await exec('qs', [...IPC_PREFIX, ...argv]);
  }
}
