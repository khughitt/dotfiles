---
id: dots-fc33f3
title: "Install the capture-host sudoers rules reproducibly: 50-chvt and 50-fb-blank"
status: done
priority: 2
size: s
complexity: low
process: direct
owner: dots-fc33f3
created: 2026-10-07T08:08:02Z
updated: 2026-10-11T12:30:35Z
started: 2026-10-11T12:18:22Z
completed: 2026-10-11T12:30:33Z
depends: []
tags: []
agent: claude-code/claude-opus-5-5
---

Two narrow sudoers rules are hand-installed on the capture host and not managed anywhere: /etc/sudoers.d/50-chvt ('<user> ALL=(root) NOPASSWD: /usr/bin/chvt', documented in niri-material docs/materials/capture-host-setup.md) and /etc/sudoers.d/50-fb-blank ('<user> ALL=(root) NOPASSWD: /usr/bin/tee /sys/class/graphics/fb0/blank', installed 2026-10-06, verified 2026-10-07: writing 4 powers the display down to standby with no compositor running, 0 restores). Manage both from dots: check each with 'visudo -cf' before an 'install -m 0440 -o root -g root', idempotent, user substituted. Related: ops-20c8a8 (display-dim uses the fb0 rule).

## Notes

- 2026-10-11T12:18:22Z (main): started
  provenance: {"harness_session":"codex:01a12ae5-c5a4-7a42-9db0-ffa3e1e286bf","harness_session_source":"CODEX_THREAD_ID"}
- 2026-10-11T12:18:41Z (dots-fc33f3): resumed
  provenance: {"harness_session":"codex:01a12ae5-c5a4-7a42-9db0-ffa3e1e286bf","harness_session_source":"CODEX_THREAD_ID"}
- 2026-10-11T12:19:22Z (dots-fc33f3): Scope: explicit bin/install-capture-sudoers command with a required local username; preserve the two exact grants, validate both before any install, use root-owned 0440 copies and GNU install -C for repeatability. Add focused tests, check registration, and capture-host documentation; no default setup grants or live desktop actions.
- 2026-10-11T12:25:58Z (dots-fc33f3): Verification: baseline just test exited 0 (103 Python tests plus shell suite); focused installer tests proved RED with missing command, then GREEN (14 passed). just check and focused Ruff check passed. Tests use real visudo/GNU install with scratch destinations; live root installation and display changes are not part of verification.
- 2026-10-11T12:28:08Z (dots-fc33f3): review: impl round 1 — verdict: revise; findings: Important 1; reviewer: codex
- 2026-10-11T12:28:08Z (dots-fc33f3): Review ruling: accept the Ubuntu visudo test-path finding; resolve the actual executable through PATH. Two-file atomic rollback is outside scope: both files are validated before either install, and each install fails loudly. Also test/refuse a directory at a live rule destination using GNU install -T.
- 2026-10-11T12:30:33Z (dots-fc33f3): review: impl round 2 — verdict: accept; findings: none; reviewer: codex
- 2026-10-11T12:30:33Z (dots-fc33f3): Ruling: corrective review accepts the visudo PATH resolution and install -T directory refusal. Keep the exact requested command grants and explicit host installation; no rollback transaction, automatic setup grants, extra abstractions, or dependencies. No deferred findings. Final verification: 15 focused tests and 118 full Python tests pass; just test shell suite, just check, Ruff and diff checks pass. Existing setup/health Noctalia stub diagnostic still prints but the suite exits 0.
- 2026-10-11T12:30:33Z (dots-fc33f3): done
  provenance: {"harness_session":"codex:01a12ae5-c5a4-7a42-9db0-ffa3e1e286bf","harness_session_source":"CODEX_THREAD_ID"}
- 2026-10-11T12:30:33Z (dots-fc33f3): Added bin/install-capture-sudoers with explicit username validation, both visudo checks before root-owned 0440 installs, idempotence and destination-directory refusal; documented the command and added 15 tests. Reviewed and verified; live host installation was not run.
  provenance: {"harness_session":"codex:01a12ae5-c5a4-7a42-9db0-ffa3e1e286bf","harness_session_source":"CODEX_THREAD_ID"}
