---
id: dots-0e5d83
title: "gpu-ctl: a narrow root helper for GPU fan and persistence control, granted by install-capture-sudoers"
status: doing
priority: 2
size: s
complexity: mid
process: direct
owner: main
created: 2026-10-18T08:41:34Z
updated: 2026-10-18T08:41:45Z
started: 2026-10-18T08:41:45Z
depends: []
tags: []
source: material-04818d
agent: claude-code/claude-opus-5-5
---

Owner request (2026-10-18, material-04818d): let the capture agent toggle GPU persistence mode and fan control without the owner typing sudo. NVML does both without a display (nvidia-settings needs a live Wayland/X session, the fragility behind dots-9c011b).

Scope: bin/gpu-ctl (Python, ctypes on libnvidia-ml.so.1, GPU 0, every fan) accepting exactly: status; persistence on|off; fan auto (nvmlDeviceSetDefaultFanSpeed_v2); fan <45-100> (nvmlDeviceSetFanSpeed_v2; 45 is gpu-fan-curve's measured floor above the stall edge). Anything else exits 2 before NVML is loaded. install-capture-sudoers installs it root-owned 0755 to /usr/local/sbin/gpu-ctl and adds 50-gpu-ctl granting exactly those argument forms, validated with visudo before any install, helper before its rule. Tests for the helper's argv contract and NVML calls (fake library object), installer tests extended; docs/capture-host-setup.md updated. In a desktop session gpu-fan-curve re-asserts manual control within its 60 s verify, so fan changes there are transient.

## Notes

- 2026-10-18T08:41:45Z (main): started
  provenance: {"harness_session":"claude-code:5449fcbc-f1d5-4050-872d-855f55483679","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
