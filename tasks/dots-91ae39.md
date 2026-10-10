---
id: dots-91ae39
title: Restore SIGUSR2 theme refresh of opencode TUIs on glass promotion (safe on v2)
status: doing
priority: 2
process: direct
owner: main
created: 2026-10-10T19:15:07Z
updated: 2026-10-10T19:15:14Z
started: 2026-10-10T19:15:12Z
depends: []
tags: [noctalia, opencode]
agent: claude-code/claude-opus-5-5
---

## Notes

- 2026-10-10T19:15:12Z (main): concerns: dots-f26ed6 change — opencode v2 no longer disposes instances on SIGUSR2 (only the TUI catches it and just repaints), so live theme refresh is wanted again
- 2026-10-10T19:15:12Z (main): evidence: opencode v2.0.26 isolated repro (background-serve and --standalone TUIs): old signal_opencode() selection signalled only the TUI, skipped serve processes (no SIGUSR2 in SigCgt); in-flight '!sleep 20' completed, server stayed up. v2 serve dies on SIGUSR2 if signalled directly, so the SigCgt guard is load-bearing.
- 2026-10-10T19:15:12Z (main): started
  provenance: {"harness_session":"claude-code:3a0f4a7c-f0de-47bd-b0d4-e27095a6e11a","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
