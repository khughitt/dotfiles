---
id: dots-b9fff3
title: work-link --migrate refuses every entry while a docker container runs
status: doing
priority: 2
size: s
complexity: mid
process: direct
owner: main
created: 2026-09-23T10:23:15Z
updated: 2026-10-08T14:35:24Z
started: 2026-10-08T14:24:00Z
depends: []
tags: [work-link]
agent: "claude-code/claude-opus-5-5[1m]"
---

Found during ops-d099f0 on 2026-09-23: with nexcode containers up, lsof +D prints 'WARNING: can't stat() overlay file system .../mindful-docker/data/overlay2/<id>/merged' for every call; work_link_open_handles treats any lsof warning as an inspection failure, so --migrate and tests/work_link.zsh refuse every entry (baseline main fails the same way). Likely fix: exempt overlay mounts (lsof -e per findmnt -t overlay target) or match only warnings about paths under the inspected directory. ops-d099f0 verified its runs with a PATH wrapper doing the former.

## Notes

- 2026-09-23T10:24:11Z (main): Also nsfs mounts (/run/docker/netns/*) produce the same warning.
- 2026-10-08T14:24:00Z (main): started
  provenance: {"harness_session":"claude-code:cd13df6e-7206-46e3-bd3f-30be99c37559","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-08T14:35:23Z (main): Fixed on fix/work-link-lsof-foreign-mounts (cd6e245) in .worktrees/dots-b9fff3: lsof 'can't stat() <type> file system <path>' warnings about a file system that neither holds the inspected directory nor sits inside it are skipped with their 'may be incomplete' line; any other warning still refuses. New test test_foreign_mount_warning_does_not_block_migration RED->GREEN; tests/work_link.zsh passes on titan with docker up (baseline failed). just test: work_link and every other file pass except setup_and_health.zsh, which fails identically on main (filed dots-7b8af8). Used live by explicit path to migrate three venvs for ops-3566ce.
- 2026-10-08T14:35:23Z (main): parked (waiting on user, review): Merge fix/work-link-lsof-foreign-mounts into main: ~/bin/work-link and work-link.service run from dotfiles main, so the merge changes a live host tool; the user approves it, then the agent merges, removes .worktrees/dots-b9fff3 (tt-report first) and closes
  provenance: {"harness_session":"claude-code:cd13df6e-7206-46e3-bd3f-30be99c37559","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
