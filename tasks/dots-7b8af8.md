---
id: dots-7b8af8
title: "tests/setup_and_health.zsh fails on main: an inline Python assertion (stdin line 27) after the Noctalia stub checks"
status: doing
priority: 2
size: s
complexity: mid
process: direct
owner: main
created: 2026-10-08T14:31:59Z
updated: 2026-10-11T11:09:35Z
started: 2026-10-11T11:09:33Z
depends: []
tags: []
agent: claude-code
---

Seen 2026-10-08 on titan while gating dots-b9fff3: just test stops at zsh tests/setup_and_health.zsh with 'AssertionError' from '<stdin>', line 27 (after the expected 'unexpected Noctalia test command: msg plugins disable test/never-live' stderr line). Main without the dots-b9fff3 change fails identically, so it is pre-existing; the later test files (dotfiles_check, layout_check, justfile, console_keymap) pass. Done: the failing assertion is identified and fixed or its premise updated; just test passes on titan.

## Notes

- 2026-10-11T11:09:33Z (main): process: direct — bounded regression investigation in setup/health; reproduce the existing assertion, trace its premise, and verify the focused check plus full suite required by acceptance.
- 2026-10-11T11:09:33Z (main): started
  provenance: {"harness_session":"codex:01a12aa6-8bbc-7a72-a346-1ff761573875","harness_session_source":"CODEX_THREAD_ID"}
