---
id: dots-e54d10
title: Follow retired proto-science paths in pet identities and alias
status: done
priority: 2
size: xs
complexity: low
process: direct
owner: chore/proto-science-paths
created: 2026-09-14T10:22:17Z
updated: 2026-09-14T10:24:22Z
started: 2026-09-14T10:22:57Z
completed: 2026-09-14T10:24:22Z
depends: []
tags: []
source: ops-ae5870
agent: codex
---

Approved ops-1a981e plan Task 6: update four familiar identity paths and the clp plugin directory, validate and land on main; preserve unrelated live edits.

## Notes

- 2026-09-14T10:24:22Z (chore/proto-science-paths): identities.yaml is intentionally gitignored local state, absent from a fresh worktree. Prepared its four path changes in the worktree, validated YAML and path existence, then installed after preserving ~/.local/share/ops/project-move/proto-science-retirement/identities.yaml.before. It remains ignored; only the tracked alias change is committed. The current justfile has no setup recipe.
- 2026-09-14T10:24:22Z (chore/proto-science-paths): Four local identity paths updated with backup; clp alias follows proto/science; just check passed
