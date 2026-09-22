---
id: dots-8cf055
title: "niri: mindful scratchpad dropdown on Alt+M"
status: todo
priority: 2
size: xs
created: 2026-09-22T01:59:47Z
updated: 2026-09-22T01:59:56Z
depends: [ops-1c1edd]
tags: [quick-add, cross-project, niri, dropdown]
source: "mindful:thought:becb975d687b4b8d8d2e3ff8eef11180"
agent: "claude-code/claude-opus-5[1m]"
---

A fourth niri/scripts/dropdown case, 'mindful', following the ghci pattern (dots-464460): hidden pre-spawn at startup, Alt+M bind with a hotkey-overlay title, cheatsheet row, test. The case runs a small loop script: nvim on a fresh temp buffer; on exit, a non-empty buffer is posted to the running mindful web through ops bin/mindful-op (first line = title, rest = body) in the background, then a new empty buffer is ready for the next toggle. Capture on the daily driver takes ~8 s (mind6-9d3a1c), so the post must never block the editor: hide first, save behind.

Depends on the ops mindful-op human-actor mode unless the script posts the JSON itself.
