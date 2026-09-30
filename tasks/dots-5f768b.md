---
id: dots-5f768b
title: Add a JSON task search shell helper
status: done
priority: 3
size: xs
complexity: low
process: direct
owner: feat/task-json-search
created: 2026-09-30T21:48:54Z
updated: 2026-09-30T21:54:06Z
started: 2026-09-30T21:49:00Z
completed: 2026-09-30T21:54:04Z
depends: []
tags: []
agent: codex/gpt-6.1-sol
---

Add taj PATTERN [tasks list options] beside tag in shell/aliases.d/dev.zsh. Search tasks list JSON with jq, keep the JSON response shape, forward list filters, and verify behavior with a focused runnable check.

## Notes

- 2026-09-30T21:49:00Z (main): started
  provenance: {"harness_session":"codex:01a0f447-00b7-7830-b7d8-10e8ae478171","harness_session_source":"CODEX_SESSION_ID"}
- 2026-09-30T21:49:21Z (feat/task-json-search): resumed
  provenance: {"harness_session":"codex:01a0f447-00b7-7830-b7d8-10e8ae478171","harness_session_source":"CODEX_SESSION_ID"}
- 2026-09-30T21:54:04Z (feat/task-json-search): review: impl round 1 — verdict: accept; findings: none; reviewer: codex/gpt-6.1-sol
- 2026-09-30T21:54:04Z (feat/task-json-search): verification: just check, focused JSON shell check, live CLI query, and tasks check passed; just test stopped at existing fastfetch logo.recache failure (dots-8ca7e7, 96 pytest passed, 1 failed).
- 2026-09-30T21:54:04Z (feat/task-json-search): done
  provenance: {"harness_session":"codex:01a0f447-00b7-7830-b7d8-10e8ae478171","harness_session_source":"CODEX_SESSION_ID"}
- 2026-09-30T21:54:04Z (feat/task-json-search): Added taj JSON search helper and runnable shell check; full suite blocked by existing fastfetch logo.recache failure (dots-8ca7e7).
  provenance: {"harness_session":"codex:01a0f447-00b7-7830-b7d8-10e8ae478171","harness_session_source":"CODEX_SESSION_ID"}
