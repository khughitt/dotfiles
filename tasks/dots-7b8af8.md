---
id: dots-7b8af8
title: "tests/setup_and_health.zsh fails on main: an inline Python assertion (stdin line 27) after the Noctalia stub checks"
status: done
priority: 2
size: s
complexity: mid
process: direct
owner: dots-7b8af8
created: 2026-10-08T14:31:59Z
updated: 2026-10-11T11:22:34Z
started: 2026-10-11T11:09:33Z
completed: 2026-10-11T11:17:40Z
depends: []
tags: []
agent: claude-code
---

Seen 2026-10-08 on titan while gating dots-b9fff3: just test stops at zsh tests/setup_and_health.zsh with 'AssertionError' from '<stdin>', line 27 (after the expected 'unexpected Noctalia test command: msg plugins disable test/never-live' stderr line). Main without the dots-b9fff3 change fails identically, so it is pre-existing; the later test files (dotfiles_check, layout_check, justfile, console_keymap) pass. Done: the failing assertion is identified and fixed or its premise updated; just test passes on titan.

## Notes

- 2026-10-11T11:09:33Z (main): process: direct — bounded regression investigation in setup/health; reproduce the existing assertion, trace its premise, and verify the focused check plus full suite required by acceptance.
- 2026-10-11T11:09:33Z (main): started
  provenance: {"harness_session":"codex:01a12aa6-8bbc-7a72-a346-1ff761573875","harness_session_source":"CODEX_THREAD_ID"}
- 2026-10-11T11:09:48Z (dots-7b8af8): resumed
  provenance: {"harness_session":"codex:01a12aa6-8bbc-7a72-a346-1ff761573875","harness_session_source":"CODEX_THREAD_ID"}
- 2026-10-11T11:10:07Z (dots-7b8af8): root cause: reproduced AssertionError at inline Python line 27; commit 52764b3 added theme.templates.user.prism without updating the exact registry assertion, two CLI listing checks, or documentation count. The preceding Noctalia disable stderr is expected by the safe-stub test, which passes.
- 2026-10-11T11:11:59Z (dots-7b8af8): review: impl round 1 — verdict: accept; findings: none; reviewer: codex
- 2026-10-11T11:11:59Z (dots-7b8af8): review disposition: full-suite success retained as controller verification via running just test; live template rendering not required for this expectation-only fix. No deferred minor findings. Focused setup_and_health.zsh is GREEN after baseline RED at inline Python line 27; full suite Python portion passed 103 tests.
- 2026-10-11T11:17:40Z (dots-7b8af8): verification: on titan, focused zsh tests/setup_and_health.zsh exited 0; just test exited 0 (103 Python tests and all shell scripts). Expected safe-stub/preflight negative-case diagnostics do not indicate failures. git diff --check and tasks check passed.
- 2026-10-11T11:17:40Z (dots-7b8af8): done
  provenance: {"harness_session":"codex:01a12aa6-8bbc-7a72-a346-1ff761573875","harness_session_source":"CODEX_THREAD_ID"}
- 2026-10-11T11:17:40Z (dots-7b8af8): Updated the stale eight-template premise to include the existing Prism template in the exact registry assertion and both real Noctalia listing checks; corrected the documentation to nine. Focused regression and full just test passed on titan; independent review accepted with no findings.
  provenance: {"harness_session":"codex:01a12aa6-8bbc-7a72-a346-1ff761573875","harness_session_source":"CODEX_THREAD_ID"}
- 2026-10-11T11:22:34Z (dots-7b8af8): integration verification: merged concurrent main changes (XDG root fix) cleanly; just test on the combined tree exited 0, with 103 Python tests and every shell script passing.
