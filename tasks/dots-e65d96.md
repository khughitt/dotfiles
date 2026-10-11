---
id: dots-e65d96
title: "Claude Code on a Linux console TTY: Shift+Enter inserts a newline"
status: done
priority: 3
size: xs
complexity: low
process: direct
owner: dots-e65d96
created: 2026-10-05T00:22:17Z
updated: 2026-10-11T12:12:56Z
started: 2026-10-11T11:43:23Z
completed: 2026-10-11T11:52:33Z
depends: []
tags: [quick-add]
source: "mindful:thought:8ae1a66caef235aa7fd15eae5ff98b35"
model: claude-opus-5-5
agent: claude-code/claude-opus-5-5
---

In Claude Code's terminal UI, Shift+Enter should insert a newline instead of submitting. Check the terminal's key mapping for Shift+Enter (Claude Code's /terminal-setup covers some terminals).

## Notes

- 2026-10-11T11:43:23Z (main): Scope: kitty already works; the gap is a VT (getty console), where the us-tmux keymap sends plain CR for Shift+Enter. Fix: shift column of keycode 28 sends ESC CR (meta+Enter), which Claude Code reads as newline. Direct: one keymap line, test, doc.
- 2026-10-11T11:43:23Z (main): started
  provenance: {"harness_session":"claude-code:f8130dda-d060-4a8f-aadf-ba110b30d31a","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-11T11:43:27Z (dots-e65d96): resumed
  provenance: {"harness_session":"claude-code:f8130dda-d060-4a8f-aadf-ba110b30d31a","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-11T11:52:33Z (dots-e65d96): done
  provenance: {"harness_session":"claude-code:f8130dda-d060-4a8f-aadf-ba110b30d31a","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-11T11:52:33Z (dots-e65d96): kbd/us-tmux.map: Shift+Enter (keycode 28 shift column) sends ESC CR (\033\015; loadkeys has no \r escape), Claude Code's newline sequence; test in tests/console_keymap.zsh, install doc updated. Live install on titan needs the root install commands in docs/fresh-install-hardening.md.
  provenance: {"harness_session":"claude-code:f8130dda-d060-4a8f-aadf-ba110b30d31a","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-11T12:12:56Z (main): Verified live by the user on a TTY after installing the map: Shift+Enter inserts a newline in Claude Code.
