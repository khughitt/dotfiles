---
id: dots-344b5a
title: "setup.sh: run phases independently and summarise failures instead of aborting"
status: todo
priority: 1
size: m
created: 2026-09-08T15:13:04Z
updated: 2026-09-08T15:13:04Z
depends: []
tags: [robustness, setup]
---

Found bringing europa (laptop) up to date on 2026-09-08 after ~3 weeks. The graphical-config phase failed on prism, and set -e took the whole run with it: common-config, systemd, kitty, home, app-config, mime and tmux never ran, so the laptop got none of its links for a reason unrelated to any of them. Outcome: a failing phase is recorded and the remaining phases still run; the script prints a per-phase summary at the end and exits non-zero if any failed.
