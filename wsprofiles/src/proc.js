// Parse the fields we need from /proc/<pid>/stat. `comm` (field 2) is wrapped in
// parentheses and may itself contain spaces and parens, so split after the LAST
// ')'. Field order after comm: state(3) ppid(4) pgrp(5) session(6) tty_nr(7) tpgid(8).
export function parseStat(text) {
  if (!text) return null;
  const open = text.indexOf('(');
  const close = text.lastIndexOf(')');
  if (open < 0 || close < 0 || close < open) return null;
  const pid = Number.parseInt(text.slice(0, open).trim(), 10);
  const after = text.slice(close + 1).trim().split(/\s+/);
  // after[0]=state after[1]=ppid after[2]=pgrp after[3]=session after[4]=tty_nr after[5]=tpgid
  const ppid = Number.parseInt(after[1], 10);
  const pgrp = Number.parseInt(after[2], 10);
  const ttyNr = Number.parseInt(after[4], 10);
  const tpgid = Number.parseInt(after[5], 10);
  if ([pid, ppid, pgrp, ttyNr, tpgid].some((n) => !Number.isInteger(n))) return null;
  return { pid, ppid, pgrp, ttyNr, tpgid };
}

// Resolve the foreground cwd of a terminal whose OS-window process is `pid`.
// Returns { cwd, ambiguous }:
//   - { cwd: <path>, ambiguous: false }   resolved
//   - { cwd: null,   ambiguous: true  }   >1 tty shells (tabs/splits) — the
//                                          caller may fall back to the title
//   - { cwd: null,   ambiguous: false }   unavailable (no shell / proc race /
//                                          unreadable cwd) — caller: no name
// Only the genuinely ambiguous case permits a title fallback; a transient
// /proc failure must NOT rename the workspace to the shell's title.
// The foreground process-group leader's pid equals the shell's tpgid.
export function foregroundCwd(pid, { readChildren, readStat, readCwd }) {
  const shells = [];
  for (const child of readChildren(pid) ?? []) {
    const st = parseStat(readStat(child));
    if (st && st.ttyNr !== 0) shells.push(st);
  }
  if (shells.length > 1) return { cwd: null, ambiguous: true };   // tabs/splits
  if (shells.length === 0) return { cwd: null, ambiguous: false }; // unavailable
  const shell = shells[0];
  const target = shell.tpgid > 0 ? shell.tpgid : shell.pid;
  const cwd = readCwd(target);
  if (!cwd) return { cwd: null, ambiguous: false };               // proc race
  return { cwd, ambiguous: false };
}
