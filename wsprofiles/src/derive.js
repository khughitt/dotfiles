import { basename } from 'node:path';

// Strip a leading run of anything that is not a letter, digit, or path
// separator (spinner glyphs, ✳, punctuation, whitespace), then trim + cap.
const LEADING_JUNK = /^[^\p{L}\p{N}/]+/u;

export function sanitizeName(raw) {
  if (!raw) return null;
  const cleaned = raw.replace(LEADING_JUNK, '').trimEnd();
  if (!cleaned) return null;
  return cleaned.slice(0, 32);
}

export function appName(appId) {
  if (!appId) return null;
  const tail = appId.includes('.') ? appId.slice(appId.lastIndexOf('.') + 1) : appId;
  return sanitizeName(tail.toLowerCase());
}

export function cwdName(cwd, { git, home }) {
  if (!cwd || cwd === home) return null;
  let root = null;
  try {
    root = git(cwd);
  } catch {
    root = null;
  }
  return sanitizeName(basename(root || cwd));
}

// window: { appId, pid, title }
export function deriveName(window, { foregroundCwd, git, home, isTerminal }) {
  if (!window) return null;
  if (isTerminal(window.appId)) {
    const { cwd, ambiguous } = foregroundCwd(window.pid);
    if (cwd) return cwdName(cwd, { git, home }); // may be null (bare home)
    if (ambiguous) return sanitizeName(window.title); // multi-tab → title fallback
    return null; // unavailable (proc race / no shell) → no name this cycle
  }
  return appName(window.appId);
}
