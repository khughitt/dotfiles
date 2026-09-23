---
id: dots-43b9e5
title: opencode_theme_fallback_test flakes on TemporaryDirectory cleanup under suite load
status: todo
priority: 3
size: xs
complexity: mid
process: direct
created: 2026-09-23T10:46:21Z
updated: 2026-09-23T10:46:21Z
depends: []
tags: [testing]
agent: "claude-code/claude-opus-5-5[1m]"
---

Seen 2026-09-23 during ops-d099f0: just check and just test each failed once with OSError Directory not empty on the probe's tempdir (home/.local/state, or the tmp root), passing on rerun and 5/5 standalone in both main and a worktree. Something the probe spawns likely still writes into the temp HOME when the context manager exits.
