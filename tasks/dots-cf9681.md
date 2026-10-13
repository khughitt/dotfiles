---
id: dots-cf9681
title: Re-enable wired autoconnect when an ethernet link returns after a manual disconnect
status: doing
priority: 2
size: s
complexity: mid
process: direct
owner: main
created: 2026-10-13T08:45:18Z
updated: 2026-10-13T08:45:25Z
started: 2026-10-13T08:45:25Z
depends: []
tags: [desktop]
agent: claude-code/claude-opus-5-5
---

NetworkManager blocks autoconnect on a device after a user disconnect (nm-applet / Noctalia 'disconnect'), and the block survives a cable replug; only a reboot or a manual connect clears it. On 2026-10-11 an accidental nm-applet disconnect left titan on Wi-Fi for two days with the cable live. NM has no config knob for this and its dispatcher fires no carrier events. Add a user service that watches 'nmcli device monitor' and, on an ethernet device's unavailable -> disconnected transition (carrier regained), runs 'nmcli device set <dev> autoconnect yes'. A deliberate disconnect still holds until the link drops and returns.

## Notes

- 2026-10-13T08:45:25Z (main): started
  provenance: {"harness_session":"claude-code:5588d70a-e1c7-421c-b52f-6681dc7b6eeb","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
