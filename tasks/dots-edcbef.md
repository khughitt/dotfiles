---
id: dots-edcbef
title: "Link wali-phone-sync units, add titan's [phone] table"
status: todo
priority: 2
size: xs
complexity: low
process: direct
created: 2026-09-19T12:42:18Z
updated: 2026-09-19T12:42:18Z
depends: []
tags: []
agent: claude-code/claude-opus-5
---

Wali's phone sync (goal wali-51adcc, spec docs/specs/2026-09-19-phone-sync-design.md in the wali checkout) ships systemd/wali-phone-sync.service and .timer. In setup.sh setup_systemd_user_units, add two ln_s lines for them beside the wali-rotate links (setup.sh:763), NOT in the ENABLE_USER_TIMERS block: only titan has a [phone] table, so the timer is enabled by hand there. Extend the wali unit fixture and link assertions in tests/setup_and_health.zsh (:154, :599). Add to wali/titan/config.toml: [phone] dir = "~/d/linux/backgrounds/amalthea", output = "1344x2992". Done when setup links the units on a fresh host and the tests pass.
