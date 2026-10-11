---
id: dots-119cde
title: "work-link: deferred minors from the host-neutral links review"
status: doing
priority: 3
size: s
complexity: low
process: direct
owner: main
created: 2026-09-23T12:19:08Z
updated: 2026-10-11T14:48:56Z
started: 2026-10-11T14:48:56Z
depends: []
tags: [work-link]
agent: "claude-code/claude-opus-5-5[1m]"
---

From ops-d099f0's final review (2026-09-23): (1) a killed rewrite can leave a .<name>.work-link.<pid> temporary link in the synced tree; (2) --dry-run prints only 'rewrite' for a dangling legacy link, the real run also materializes; (3) no flock around converge, so the timer and a manual run or just setup can collide and report a spurious failed; (4) test gaps: two hosts at different parent paths, the rewrite test's open-file check runs after the swap, the thin-PATH test pins WORK_LINK_HOST and has no mv; (5) work-link.timer Description still says WORK_ROOT and the new service comment line is long.

## Notes

- 2026-10-11T14:48:56Z (main): started
  provenance: {"harness_session":"codex:01a12b6f-62a6-76e3-8346-f660fc1cec3d","harness_session_source":"CODEX_THREAD_ID"}
