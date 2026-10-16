---
id: dots-721ed9
title: Rewrite t@t commit authorship in this repository
status: doing
priority: 2
size: s
complexity: low
process: direct
owner: main
created: 2026-10-16T16:32:09Z
updated: 2026-10-16T20:58:11Z
started: 2026-10-16T20:55:17Z
depends: [ops-e5b39c]
tags: []
source: git-identity-leak-2026-10-07
agent: claude-code/claude-opus-5-5
---

Rewrite this repository's t <t@t> commits (from the 2026-10-07 global-config leak; see ops-5749d9) to Keith Hughitt <keith.hughitt@gmail.com>, following the runbook ops-e5b39c. Inventory on titan 2026-10-16: 57 t@t commits on all refs, 13 unpushed on main, 1 worktree(s); remote: khughitt/dotfiles. Includes 81bd664, a record commit made in the worktree of the fix itself.

## Notes

- 2026-10-16T20:55:17Z (main): started
  provenance: {"harness_session":"claude-code:e5db3073-3856-4b19-b95e-ec56f6a50202","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-16T20:56:29Z (main): Direct history maintenance under ops-e5b39c's pilot procedure (as hq/mind6/beliefs). User confirmed Europa online and quiet. Inventory: 58 t@t commits (first 8cc8f11, 2026-10-07), all on main; of 7 local branches only dots-0e0cc5 (merged, task done, locked clean worktree on Titan) descends from the window and is rewritten in the same pass; backup/pre-glass-split, chore/mindful-headless-web (locked clean worktree), dots-953131, feat/kernel-update-gate, fix/health-link predate it and must stay unchanged. No tags, stashes, signed commits or extra headers; Europa: no worktrees, no agent sessions, stale index (preserve). Remote khughitt/dotfiles: main 09daff8 (lease), unprotected, no open PRs; no pre-push hook installed. Steps: bundle --all; mirror clone outside Dropbox; filter-repo --mailmap; verify objects differ only in mapped parents and identity; guarded update-ref --stdin transaction; attach changed-entry SHA map; push --force-with-lease=main:09daff8.
- 2026-10-16T20:58:11Z (main): attached: 2026-10-16-identity-commit-map.txt (5330 bytes): Authorship rewrite map: 65 changed commit IDs (old new); resolves historical SHA references in task notes without editing append-only text
