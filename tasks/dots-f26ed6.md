---
id: dots-f26ed6
title: Stop SIGUSR2-signaling opencode on glass promotion (aborts in-flight sessions)
status: done
priority: 2
process: direct
owner: main
created: 2026-09-14T12:41:34Z
updated: 2026-09-14T13:16:36Z
started: 2026-09-14T12:42:10Z
completed: 2026-09-14T13:16:36Z
depends: []
tags: [noctalia, opencode]
---

## Notes

- 2026-09-14T13:16:36Z (dots-f26ed6-opencode-signal): noctalia-glass-sync no longer SIGUSR2-signals opencode (its theme refresh disposes instances, aborting sessions); spec + signal test updated
