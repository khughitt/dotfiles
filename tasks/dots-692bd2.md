---
id: dots-692bd2
title: "Prepare Mindful v6 systemd runtime, stable release, backups, and v3 retirement"
status: todo
priority: 1
size: l
complexity: high
created: 2026-09-12T18:19:33Z
updated: 2026-09-12T18:31:30Z
depends: [mind6-8de715]
tags: [cross-project]
---

Prepare the dots-owned mindful-web.service with explicit PORT=3331 and MINDFUL_HOME, a stable self-contained Node release and aligned CLI launcher, consistent scheduled backups with restore tests, and the retirement procedure for mindful-docker.service. Modify setup/health checks so retired v3 is not restored by setup. Stage and test against temporary data/ports; do not install/enable production units or stop v3 until the separately approved live cutover. See mind6 docs/plans/2026-09-12-mindful-v6-local-cutover-plan.md, Task 4. Execution awaits plan approval.

## Notes

- 2026-09-12T18:29:43Z (main): parked (waiting on user, review): Wait for review of the mind6 local-cutover implementation plan; runtime/backup scope is Task 4.
