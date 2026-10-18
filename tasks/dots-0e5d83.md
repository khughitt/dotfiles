---
id: dots-0e5d83
title: "gpu-ctl: a narrow root helper for GPU fan and persistence control, granted by install-capture-sudoers"
status: done
priority: 2
size: s
complexity: mid
process: direct
owner: dots-0e5d83
created: 2026-10-18T08:41:34Z
updated: 2026-10-18T09:17:43Z
started: 2026-10-18T08:41:45Z
completed: 2026-10-18T09:17:41Z
closed: 2026-10-18T09:17:41Z
depends: []
tags: []
source: material-04818d
model: claude-opus-5-5
agent: claude-code/claude-opus-5-5
---

Owner request (2026-10-18, material-04818d): let the capture agent toggle GPU persistence mode and fan control without the owner typing sudo. NVML does both without a display (nvidia-settings needs a live Wayland/X session, the fragility behind dots-9c011b).

Scope: bin/gpu-ctl (Python, ctypes on libnvidia-ml.so.1, GPU 0, every fan) accepting exactly: status; persistence on|off; fan auto (nvmlDeviceSetDefaultFanSpeed_v2); fan <45-100> (nvmlDeviceSetFanSpeed_v2; 45 is gpu-fan-curve's measured floor above the stall edge). Anything else exits 2 before NVML is loaded. install-capture-sudoers installs it root-owned 0755 to /usr/local/sbin/gpu-ctl and adds 50-gpu-ctl granting exactly those argument forms, validated with visudo before any install, helper before its rule. Tests for the helper's argv contract and NVML calls (fake library object), installer tests extended; docs/capture-host-setup.md updated. In a desktop session gpu-fan-curve re-asserts manual control within its 60 s verify, so fan changes there are transient.

## Notes

- 2026-10-18T08:41:45Z (main): started
  provenance: {"harness_session":"claude-code:5449fcbc-f1d5-4050-872d-855f55483679","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-18T08:41:47Z (dots-0e5d83): resumed
  provenance: {"harness_session":"claude-code:5449fcbc-f1d5-4050-872d-855f55483679","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-18T09:03:06Z (dots-0e5d83): review: impl round 1 — verdict: revise; findings: Important 1, Minor 8; reviewer: claude-code
- 2026-10-18T09:03:06Z (dots-0e5d83): Round 1 ruling: fix I1 (fake-library tests for the ctypes layer). Also fix four Minors now because this is a root grant: M1 (the rule admitted fan 40-44; tighten to 4[5-9]/[5-9][0-9]/100 and test that the rule patterns admit exactly what the helper accepts); M2 (clear the environment before NVML loads, since libnvidia-ml getenv()s __NVML_DBG_FILE, and pin env_reset in 50-gpu-ctl); M4 (a failed fan N falls back to auto on every fan); M6 (sudo examples by absolute path; ~/bin's copy shadows the root one). minor (deferred): M3 no thermal refusal on fan N (callers restore in an EXIT trap; documented); M5 a readback failure after a successful write exits 1; M7 the installer copies whatever bin/gpu-ctl holds (same trust as running the installer); nit: num_fans read before a persistence write.
- 2026-10-18T09:17:41Z (dots-0e5d83): review: impl round 2 — verdict: accept; findings: Minor 5; reviewer: claude-code
- 2026-10-18T09:17:41Z (dots-0e5d83): Round 2 ruling: accept. Fixes verified (62 tests; reviewer mutation run caught 24 of 26, the two survivors edit the expected rule text in both installer and test). minor (deferred): fan auto is not best-effort across fans (the EXIT-trap restore path stops at the first failing fan); the grant test does not assert every entry names /usr/local/sbin/gpu-ctl or that env_reset is pinned (exact-content test covers both today); a dead fail= value in test_a_failed_fallback_is_reported_too; docs overstate 'sudo -n refuses' a bare gpu-ctl (true only without secure_path); unprivileged fan N reports a failed fallback. Earlier deferred: M3 no thermal refusal, M5 readback failure exits 1, M7 installer copies whatever bin/gpu-ctl holds, num_fans before a persistence write.
- 2026-10-18T09:17:41Z (dots-0e5d83): done
  provenance: {"harness_session":"claude-code:5449fcbc-f1d5-4050-872d-855f55483679","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-18T09:17:41Z (dots-0e5d83): gpu-ctl (NVML via ctypes: status, persistence on|off, fan auto, fan 45-100) and install-capture-sudoers installing it root-owned at /usr/local/sbin/gpu-ctl with 50-gpu-ctl granting exactly those writes (env_reset pinned, environment cleared before NVML loads). 172 pytest + shell suites, two review rounds (accept). Live install is the owner's: sudo bin/install-capture-sudoers "$(id -un)".
  provenance: {"harness_session":"claude-code:5449fcbc-f1d5-4050-872d-855f55483679","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
