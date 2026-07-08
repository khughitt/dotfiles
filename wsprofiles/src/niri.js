import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const run = promisify(execFile);

export function parseEventLines(chunk, carry) {
  const buf = carry + chunk;
  const parts = buf.split('\n');
  const carryOut = parts.pop();
  const events = [];
  for (const line of parts) {
    if (line.trim()) events.push(JSON.parse(line));
  }
  return { events, carry: carryOut };
}

export function focusedName(event, nameById) {
  if (event.WorkspacesChanged) {
    const ws = event.WorkspacesChanged.workspaces.find((w) => w.is_focused);
    return ws?.name ?? null;
  }
  if (event.WorkspaceActivated && event.WorkspaceActivated.focused) {
    return nameById.get(event.WorkspaceActivated.id) ?? null;
  }
  return null;
}

export function focusWorkspace(name) {
  return run('niri', ['msg', 'action', 'focus-workspace', name]).then(() => {});
}

export function loadConfig() {
  return run('niri', ['msg', 'action', 'load-config-file']).then(() => {});
}

export function setWorkspaceNameArgs(ref, name) {
  return ['msg', 'action', 'set-workspace-name', '--workspace', String(ref), name];
}

export function unsetWorkspaceNameArgs(ref) {
  return ['msg', 'action', 'unset-workspace-name', String(ref)];
}

export function setWorkspaceName(ref, name) {
  return run('niri', setWorkspaceNameArgs(ref, name)).then(() => {});
}

export function unsetWorkspaceName(ref) {
  return run('niri', unsetWorkspaceNameArgs(ref)).then(() => {});
}
