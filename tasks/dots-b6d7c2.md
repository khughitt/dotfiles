---
id: dots-b6d7c2
title: Run Mindful web outside graphical sessions
status: doing
priority: 2
size: xs
complexity: low
process: direct
owner: chore/mindful-headless-web
created: 2026-09-18T15:46:32Z
updated: 2026-09-18T15:49:18Z
started: 2026-09-18T15:48:40Z
depends: []
tags: [configuration]
source: mind6-103086
agent: codex
---

Move the dots-owned mindful-web user unit to default.target so it stays available from a logged-in TTY. Preserve loopback-only serving and private Tailscale Serve.

## Notes

- 2026-09-18T15:48:40Z (chore/mindful-headless-web): started
  provenance: {"harness_session":"codex:01a0b524-4a54-71a1-926b-c02de59e8293","harness_session_source":"CODEX_SESSION_ID"}
- 2026-09-18T15:49:18Z (chore/mindful-headless-web): Baseline just test fails before the unit change: malformed opencode/opencode.json and an OpenCode fallback assertion.
- 2026-09-18T15:49:18Z (chore/mindful-headless-web): parked (waiting on user, environment): Confirm whether to proceed with the isolated systemd-unit change despite the unrelated failing baseline.
  provenance: {"harness_session":"codex:01a0b524-4a54-71a1-926b-c02de59e8293","harness_session_source":"CODEX_SESSION_ID"}
