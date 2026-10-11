---
id: dots-119cde
title: "work-link: deferred minors from the host-neutral links review"
status: doing
priority: 3
size: s
complexity: low
process: direct
owner: fix/dots-119cde
created: 2026-09-23T12:19:08Z
updated: 2026-10-11T15:10:55Z
started: 2026-10-11T14:48:56Z
depends: []
tags: [work-link]
agent: "claude-code/claude-opus-5-5[1m]"
---

From ops-d099f0's final review (2026-09-23): (1) a killed rewrite can leave a .<name>.work-link.<pid> temporary link in the synced tree; (2) --dry-run prints only 'rewrite' for a dangling legacy link, the real run also materializes; (3) no flock around converge, so the timer and a manual run or just setup can collide and report a spurious failed; (4) test gaps: two hosts at different parent paths, the rewrite test's open-file check runs after the swap, the thin-PATH test pins WORK_LINK_HOST and has no mv; (5) work-link.timer Description still says WORK_ROOT and the new service comment line is long.

## Notes

- 2026-10-11T14:48:56Z (main): started
  provenance: {"harness_session":"codex:01a12b6f-62a6-76e3-8346-f660fc1cec3d","harness_session_source":"CODEX_THREAD_ID"}
- 2026-10-11T14:49:21Z (fix/dots-119cde): resumed
  provenance: {"harness_session":"codex:01a12b6f-62a6-76e3-8346-f660fc1cec3d","harness_session_source":"CODEX_THREAD_ID"}
- 2026-10-11T14:51:30Z (fix/dots-119cde): Scope confirmed: shared rewrite helper, legacy dry-run branch, anchor preparation used by all writing modes, work-link tests, and timer/service wording. No test-fast/test-one recipes or installed test hooks; use the existing focused Zsh suite and run just test for final coverage. Lore feedback lore-72a32a records the missing fallback recipe conflict.
- 2026-10-11T14:57:12Z (fix/dots-119cde): RED: legacy dry-run omitted materialize; TERM left the temporary symlink; paused converge held no writer lock. GREEN: focused rewrite/interruption/concurrency/two-path-host/thin-PATH/check regressions pass, as does just check. SIGKILL debris is recovered on the next rewrite; locks live beside the host-local anchor. Full suite rerun uses a stable tree after an earlier run read a test file during editing.
- 2026-10-11T15:01:44Z (fix/dots-119cde): review: impl round 1 — verdict: revise; findings: Important 1; reviewer: codex
- 2026-10-11T15:01:44Z (fix/dots-119cde): Full just test passed: 118 Python tests and all Zsh suites, including the work-link suite. Review reproduced parent-PID TERM releasing the fcntl lock while the rewrite subshell remained alive; fix the ownership split. Ruling: distributed locking across different physical hosts is outside this host-local convergence task; no minor findings.
- 2026-10-11T15:03:29Z (fix/dots-119cde): Corrective round 1: parent-PID TERM regression was RED with the rewrite subshell. Keep rewrite in the lock-owning shell with function-local Zsh options/traps; focused parent termination, TERM/KILL recovery, concurrency, legacy dry-run, host-path, and thin-PATH regressions pass. Independent scoped re-review dispatched.
- 2026-10-11T15:04:17Z (fix/dots-119cde): Correction to prior corrective-round note: just check passed, but focused tests were still running; parent-PID TERM regression paused at mv and revealed that Zsh defers scoped signal traps until that external command returns. The writer retains its lock while waiting, so verify retained locking before releasing mv, then verify exit/cleanup. The test watchdog must kill the writer group to prevent a deferred-TERM deadlock.
- 2026-10-11T15:06:09Z (fix/dots-119cde): Corrective round 1 final focused run exited 0: actual parent TERM retains writer lock through the paused rename and cleans on completion; TERM/KILL retry, concurrent ensure/converge, legacy plan, differing host paths, and thin-PATH tests pass. Zsh function EXIT traps execute after locals restore, so traps capture the quoted temporary path when defined; signal traps clean explicitly before exit. Rerun full just test on this stable final tree.
- 2026-10-11T15:06:48Z (fix/dots-119cde): review: impl round 2 — verdict: accept; findings: none; reviewer: codex
- 2026-10-11T15:06:48Z (fix/dots-119cde): Ruling: accepted fresh scoped re-review after corrective round 1; no Critical, Important, or minor (deferred) findings remain. Reviewer checked both rewrite callers, lock lifetime, scoped traps, literal path quoting, and regression sequencing. Distributed locking is outside this host-local task; TERM cleanup waits for foreground rename completion while holding the writer lock.
- 2026-10-11T15:10:54Z (fix/dots-119cde): Final verification: just test exited 0 after corrective round 1 (118 Python tests and all 11 Zsh suites); just check, Zsh syntax, git diff --check, and tasks check exited 0. The setup/health suite prints its known Noctalia fixture diagnostic and expected missing-generated-theme warnings but exits 0. Installed service/timer and work-link launcher resolve to main; no host pointer was repointed and no live service operation was run.
- 2026-10-11T15:10:54Z (fix/dots-119cde): parked (waiting on user, approval): User approves merging the reviewed fix/dots-119cde branch; then agent resumes in .worktrees/dots-119cde, closes dots-119cde on the branch, merges into main, and performs required worktree cleanup checks. Approval is required because installed work-link service/timer files resolve to main, a live service surface.
  provenance: {"harness_session":"codex:01a12b6f-62a6-76e3-8346-f660fc1cec3d","harness_session_source":"CODEX_THREAD_ID"}
