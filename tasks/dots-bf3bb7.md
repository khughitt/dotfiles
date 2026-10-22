---
id: dots-bf3bb7
title: Open on-screen image paths in imv or a kitty overlay from the keyboard
status: doing
priority: 3
size: xs
complexity: low
process: direct
owner: feat/kitty-image-open
created: 2026-10-22T00:00:12Z
updated: 2026-10-22T00:58:44Z
started: 2026-10-22T00:00:17Z
depends: []
tags: [kitty]
agent: claude-code/claude-opus-5-5
---

Kitty bindings: a hints chord that labels image paths on screen and opens the picked one in imv (background) or inline via an icat overlay, plus a selection-based variant (@selection). Removes the select/open-terminal/run-imv round trip when an agent prints an image path.

## Notes

- 2026-10-22T00:00:17Z (main): started
  provenance: {"harness_session":"claude-code:248c1efe-744b-4ff1-b230-32979cb65f4a","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-22T00:00:17Z (feat/kitty-image-open): resumed
  provenance: {"harness_session":"claude-code:248c1efe-744b-4ff1-b230-32979cb65f4a","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-22T00:08:06Z (feat/kitty-image-open): parked (waiting on user, review): User tests the four bindings in a kitty opened with the worktree's os-linux.conf layered on the live config; on success ff-merge feat/kitty-image-open into main, tasks done, remove worktree
  provenance: {"harness_session":"claude-code:248c1efe-744b-4ff1-b230-32979cb65f4a","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-22T00:58:34Z (feat/kitty-image-open): resumed
  provenance: {"harness_session":"claude-code:248c1efe-744b-4ff1-b230-32979cb65f4a","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-22T00:58:34Z (feat/kitty-image-open): Widened to relative and bare names (regexp2 lookbehind excludes URLs and ~/ paths); launches use --cwd=oldest so relative paths resolve against the shell or agent in the window
- 2026-10-22T00:58:44Z (feat/kitty-image-open): parked (waiting on user, review): User tests the four bindings (absolute, relative, bare paths) in a kitty opened with the worktree's os-linux.conf layered on the live config; on success ff-merge feat/kitty-image-open into main, tasks done, remove worktree
  provenance: {"harness_session":"claude-code:248c1efe-744b-4ff1-b230-32979cb65f4a","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
