---
id: dots-8cf055
title: "niri: mindful scratchpad dropdown on Alt+M"
status: done
priority: 2
size: xs
owner: main
created: 2026-09-22T01:59:47Z
updated: 2026-09-22T10:36:52Z
started: 2026-09-22T09:29:24Z
completed: 2026-09-22T10:36:52Z
depends: [ops-1c1edd, ops-f91c55]
tags: [quick-add, cross-project, niri, dropdown]
source: "mindful:thought:becb975d687b4b8d8d2e3ff8eef11180"
model: "claude-opus-5[1m]"
agent: "claude-code/claude-opus-5[1m]"
---

A fourth niri/scripts/dropdown case, 'mindful', following the ghci pattern (dots-464460): hidden pre-spawn at startup, Alt+M bind with a hotkey-overlay title, cheatsheet row, test. The case runs a small loop script: nvim on a fresh temp buffer; on exit, a non-empty buffer is posted to the running mindful web through ops bin/mindful-op (first line = title, rest = body) in the background, then a new empty buffer is ready for the next toggle. Capture on the daily driver takes ~8 s (mind6-9d3a1c), so the post must never block the editor: hide first, save behind.

Depends on the ops mindful-op human-actor mode unless the script posts the JSON itself.

## Notes

- 2026-09-22T09:29:24Z (main): started
  provenance: {"harness_session":"claude-code:dcc44e12-901d-40db-8745-8f5b88c96ed9","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-09-22T10:36:52Z (dots-8cf055): Live-verified on titan: capture as human with no via, tag line, bad-tag reopen, on-demand focus, opacity 0.98, opaque cursorline via a sentinel transparent_background_colors override. The worktree-backed instance is killed at merge; the bind and pre-spawn run the main checkout's copy.
- 2026-09-22T10:36:52Z (dots-8cf055): done
  provenance: {"harness_session":"claude-code:dcc44e12-901d-40db-8745-8f5b88c96ed9","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-09-22T10:36:52Z (dots-8cf055): niri mindful scratchpad on Alt+M: dropdown case + mindful-scratch loop + mindful-scratch-op parser (title / body / #tags line); on-demand focus, 0.98 opacity, opaque nvim chrome
  provenance: {"harness_session":"claude-code:dcc44e12-901d-40db-8745-8f5b88c96ed9","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
