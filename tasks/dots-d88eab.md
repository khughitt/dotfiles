---
id: dots-d88eab
title: work-link --ensure writes the bare name to .git/info/exclude when the repository's rules would not ignore the link
status: done
priority: 2
size: s
complexity: low
process: direct
owner: main
created: 2026-09-15T11:33:58Z
updated: 2026-09-15T11:38:32Z
started: 2026-09-15T11:34:08Z
completed: 2026-09-15T11:38:32Z
depends: []
tags: [git]
agent: claude-code
---

A fresh clone of a shared repository (cainex/nexcode, cainex-web) on a WORK_ROOT host would show the links as untracked until someone adds the bare names to .git/info/exclude by hand. --ensure runs there first (just setup), so it adds the name to the clone's info/exclude when the verdict is not ok, reports it as excluded, re-checks, and only then links; a repository whose own rules already cover the link is left alone. Nothing is committed to the project.

## Notes

- 2026-09-15T11:38:32Z (main): --ensure writes the local exclude rule when the repository's rules would not ignore the link; 30 tests.
