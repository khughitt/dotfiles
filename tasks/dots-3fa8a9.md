---
id: dots-3fa8a9
title: opencode theme fallback test fails against opencode 2.0.3
status: done
priority: 2
size: xs
complexity: low
process: direct
owner: main
created: 2026-09-17T11:26:18Z
updated: 2026-09-21T09:50:50Z
started: 2026-09-21T09:50:07Z
completed: 2026-09-21T09:50:50Z
depends: []
tags: []
model: "claude-opus-5[1m]"
agent: crush
---

tests/opencode_theme_fallback_test.py asserts the 1.18.18 TUI rendering (Ask anything prompt plus the 48;2;10;10;10 background escape); the host now has /usr/bin/opencode v2.0.3 and the probe fails on both dangling and malformed themes, which blocks bin/dotfiles-check and everything after it in just test. Seen on clean main on 2026-09-17 while fixing dots-4f3ff3.

## Notes

- 2026-09-21T09:50:07Z (main): Root cause: opencode 2.x removed --pure (2.0.11 prints usage and exits 1, so the pane capture is empty). --standalone is the 2.x analogue (private server); with it both the dangling and malformed theme probes render 'Ask anything' with the 48;2;10;10;10 fallback background.
- 2026-09-21T09:50:07Z (main): started
  provenance: {"harness_session":"claude-code:c0f271e1-a69e-447e-854e-5127749f824c","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-09-21T09:50:50Z (fix/agent-theme-tests): done
  provenance: {"harness_session":"claude-code:c0f271e1-a69e-447e-854e-5127749f824c","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-09-21T09:50:50Z (fix/agent-theme-tests): Probe runs opencode --standalone (2.x removed --pure) and reports stderr when no frame renders; both theme probes pass on 2.0.11
  provenance: {"harness_session":"claude-code:c0f271e1-a69e-447e-854e-5127749f824c","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
