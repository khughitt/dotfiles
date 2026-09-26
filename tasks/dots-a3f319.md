---
id: dots-a3f319
title: "work-link: --dry-run skips worktree checks, so --migrate exits 1 on problems the preview never showed"
status: todo
priority: 2
size: s
complexity: mid
process: direct
created: 2026-09-24T09:07:30Z
updated: 2026-09-24T09:07:30Z
depends: []
tags: [work-link]
source: ops-d099f0
agent: "claude-code/claude-opus-5-5[1m]"
---

Found on europa 2026-09-24 during the needs-migration cleanup. `work-link --migrate --dry-run` listed 19 moves and nothing else. The real `--migrate` moved all 19 and then exited 1 on 10 reports it had not previewed: 3 broken, 6 unowned, 1 prunable. None came from the migration: they were stale worktree admin entries and orphaned worktree directories that had existed for months.

Two causes in work_link_run (around line 650):
1. `[[ "$mode" == plan ]] || work_link_lock_worktrees "$intree"`: plan mode skips the worktree checks altogether, so a dry run cannot show the report lines a real run would print.
2. The checks run only when `.worktrees` is already a symlink. A real `.worktrees` directory, which is every needs-migration case, is never checked, so the move is what first exposes that repository's worktree problems. The checks also cover the whole repository's `git worktree list`, including worktrees outside `.worktrees` such as `.claude/worktrees/agent-*`.

Result: a successful migration looks like a failed one.

Likely fix: run the read-only half of work_link_lock_worktrees (the broken/prunable/unowned reports, without restamping locks) in plan mode, and for a real `.worktrees` directory too. Optionally make --migrate's exit status distinguish failed moves from standing reports, as converge already does for needs-migration/conflict.
