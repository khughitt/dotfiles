---
id: dots-344b5a
title: "setup.sh: run phases independently and summarise failures instead of aborting"
status: done
priority: 1
size: m
owner: main
created: 2026-09-08T15:13:04Z
updated: 2026-09-08T21:44:25Z
depends: []
tags: [robustness, setup]
---

Found bringing europa (laptop) up to date on 2026-09-08 after ~3 weeks. The graphical-config phase failed on prism, and set -e took the whole run with it: common-config, systemd, kitty, home, app-config, mime and tmux never ran, so the laptop got none of its links for a reason unrelated to any of them. Outcome: a failing phase is recorded and the remaining phases still run; the script prints a per-phase summary at the end and exits non-zero if any failed.

## Notes

- 2026-09-08T21:44:25Z (main): run_phase runs each phase in its own subshell, records pass/fail, and continues; setup.sh prints a per-phase summary and exits non-zero if any failed. Regression test asserts a later phase still runs and does work after an earlier one fails.
