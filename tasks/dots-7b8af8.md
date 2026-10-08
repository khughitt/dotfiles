---
id: dots-7b8af8
title: "tests/setup_and_health.zsh fails on main: an inline Python assertion (stdin line 27) after the Noctalia stub checks"
status: todo
priority: 2
size: s
created: 2026-10-08T14:31:59Z
updated: 2026-10-08T14:31:59Z
depends: []
tags: []
agent: claude-code
---

Seen 2026-10-08 on titan while gating dots-b9fff3: just test stops at zsh tests/setup_and_health.zsh with 'AssertionError' from '<stdin>', line 27 (after the expected 'unexpected Noctalia test command: msg plugins disable test/never-live' stderr line). Main without the dots-b9fff3 change fails identically, so it is pre-existing; the later test files (dotfiles_check, layout_check, justfile, console_keymap) pass. Done: the failing assertion is identified and fixed or its premise updated; just test passes on titan.
