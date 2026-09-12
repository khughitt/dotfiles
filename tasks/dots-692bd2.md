---
id: dots-692bd2
title: "Prepare Mindful v6 systemd runtime, stable release, backups, and v3 retirement"
status: done
priority: 1
size: l
complexity: high
owner: feat/mindful-runtime
created: 2026-09-12T18:19:33Z
updated: 2026-09-12T20:33:46Z
started: 2026-09-12T20:19:59Z
completed: 2026-09-12T20:33:46Z
depends: [mind6-8de715]
tags: [cross-project]
---

Prepare the dots-owned mindful-web.service with explicit PORT=3331 and MINDFUL_HOME, a stable self-contained Node release and aligned CLI launcher, consistent scheduled backups with restore tests, and the retirement procedure for mindful-docker.service. Modify setup/health checks so retired v3 is not restored by setup. Stage and test against temporary data/ports; do not install/enable production units or stop v3 until the separately approved live cutover. See mind6 docs/plans/2026-09-12-mindful-v6-local-cutover-plan.md, Task 4. Plan approved; preparation remains staged until the separately approved cutover.

## Notes

- 2026-09-12T18:29:43Z (main): parked (waiting on user, review): Wait for review of the mind6 local-cutover implementation plan; runtime/backup scope is Task 4.
- 2026-09-12T20:19:59Z (feat/mindful-runtime): Approved execution of ~/d/mindful/v6/docs/plans/2026-09-12-mindful-v6-local-cutover-plan.md Task 4 in .worktrees/mindful-runtime; preparation and synthetic tests only, no activation.
- 2026-09-12T20:33:46Z (feat/mindful-runtime): Prepared release/backup/units/runbook in .worktrees/mindful-runtime. 23 runtime pytest cases pass, including dependency independence, exact restore, service/lock/archive failure recovery and SIGINT/SIGTERM. Setup/health zsh suite, ruff, just check, and tasks check pass (zero warnings). Rendered temporary-home units pass systemd-analyze --user verify; source units only report intentionally absent current/bin/node before activation. Independent runtime review clean. Main launcher, services, credentials and live data untouched.
- 2026-09-12T20:33:46Z (feat/mindful-runtime): Prepared immutable releases, lock-safe private backups, v6 units/launcher and retirement runbook; 23 runtime tests and setup/health/check pass, activation deferred.
