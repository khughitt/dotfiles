---
id: dots-8dc596
title: Launch opencode and crush under a TASKS_MAX_COMPLEXITY envelope
status: done
priority: 2
size: xs
complexity: low
owner: main
created: 2026-09-12T15:05:34Z
updated: 2026-09-12T15:05:45Z
started: 2026-09-12T15:05:34Z
completed: 2026-09-12T15:05:45Z
depends: []
tags: [shell]
---

The tasks tracker now hides work above a complexity cutoff from ready/next/prime when TASKS_MAX_COMPLEXITY is set (tasks docs/specs/2026-09-12-task-complexity-design.md §4.2: the variable is the harness form). opencode and crush run the mid-tier models, so wrap both in shell functions that default the variable to mid when it is unset, leaving an explicit level or an explicit empty value alone.

## Notes

- 2026-09-12T15:05:45Z (main): opencode and crush wrapped in shell/functions.d/dev.zsh: TASKS_MAX_COMPLEXITY defaults to mid when unset; explicit level or empty respected
