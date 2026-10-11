---
id: dots-fc33f3
title: "Install the capture-host sudoers rules reproducibly: 50-chvt and 50-fb-blank"
status: doing
priority: 2
size: s
complexity: low
process: direct
owner: main
created: 2026-10-07T08:08:02Z
updated: 2026-10-11T12:18:22Z
started: 2026-10-11T12:18:22Z
depends: []
tags: []
agent: claude-code/claude-opus-5-5
---

Two narrow sudoers rules are hand-installed on the capture host and not managed anywhere: /etc/sudoers.d/50-chvt ('<user> ALL=(root) NOPASSWD: /usr/bin/chvt', documented in niri-material docs/materials/capture-host-setup.md) and /etc/sudoers.d/50-fb-blank ('<user> ALL=(root) NOPASSWD: /usr/bin/tee /sys/class/graphics/fb0/blank', installed 2026-10-06, verified 2026-10-07: writing 4 powers the display down to standby with no compositor running, 0 restores). Manage both from dots: check each with 'visudo -cf' before an 'install -m 0440 -o root -g root', idempotent, user substituted. Related: ops-20c8a8 (display-dim uses the fb0 rule).

## Notes

- 2026-10-11T12:18:22Z (main): started
  provenance: {"harness_session":"codex:01a12ae5-c5a4-7a42-9db0-ffa3e1e286bf","harness_session_source":"CODEX_THREAD_ID"}
