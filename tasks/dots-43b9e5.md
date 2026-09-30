---
id: dots-43b9e5
title: opencode_theme_fallback_test flakes on TemporaryDirectory cleanup under suite load
status: done
priority: 3
size: xs
complexity: mid
process: direct
owner: dots-43b9e5
created: 2026-09-23T10:46:21Z
updated: 2026-09-30T18:39:16Z
started: 2026-09-30T18:20:09Z
completed: 2026-09-30T18:39:16Z
depends: []
tags: [testing]
agent: "claude-code/claude-opus-5-5[1m]"
---

Seen 2026-09-23 during ops-d099f0: just check and just test each failed once with OSError Directory not empty on the probe's tempdir (home/.local/state, or the tmp root), passing on rerun and 5/5 standalone in both main and a worktree. Something the probe spawns likely still writes into the temp HOME when the context manager exits.

## Notes

- 2026-09-30T18:20:09Z (main): started
- 2026-09-30T18:20:44Z (dots-43b9e5): resumed
- 2026-09-30T18:20:44Z (dots-43b9e5): took over session sid:1810269 (owner main, stale)
- 2026-09-30T18:38:58Z (dots-43b9e5): Root cause confirmed: kill-server only signals the pane process and returns in ~8ms; opencode keeps running exit writes (db checkpoint, log) into the temp tree for ~0.5s past it, so TemporaryDirectory rmtree races a live writer (Errno 39 under suite load). Fix: capture the pane pid via list-panes and wait for process exit (gone/Z) in the finally block before the context exits.
- 2026-09-30T18:39:16Z (dots-43b9e5): done
- 2026-09-30T18:39:16Z (dots-43b9e5): The theme fallback probe waits for the opencode pane process to exit (gone or zombie) in its finally block before leaving the TemporaryDirectory, so rmtree no longer races the process's ~0.5s of post-kill-server exit writes into the temp tree.
