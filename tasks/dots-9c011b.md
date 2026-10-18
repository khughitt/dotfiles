---
id: dots-9c011b
title: gpu-fan-curve treats a stale Wayland socket as a live session
status: todo
priority: 2
size: s
complexity: low
process: direct
created: 2026-10-18T03:52:22Z
updated: 2026-10-18T09:08:23Z
depends: []
tags: []
source: material-04818d
agent: claude-code/claude-opus-5-5
---

When the desktop stops, its compositor leaves $XDG_RUNTIME_DIR/wayland-1 behind as a dead socket file. find_session() accepts any path that passes [ -S ], so through a whole TTY session the daemon keeps 'finding' the session. Every 15 s it runs nvidia-smi and two nvidia-settings calls that fail ('could not engage manual control (need root?); retrying', ~4 lines a minute in the journal since 2026-10-01, every TTY night).

Consequences:
- The card stays in the manual mode the desktop set, pinned at the last commanded speed (45%, ~640 RPM at 35 C on 2026-10-17). The curve no longer follows temperature.
- The MAXTEMP handoff (set_auto) and ExecStopPost --revert both go through the same dead socket, so neither can return the card to automatic control during a TTY session. A long GPU load from a TTY (nested captures, a DRM niri session) runs with the fans fixed at 45%.
- The polling adds a GPU query plus two nvidia-settings start-ups every 15 s to every idle-host capture. They are run from the TTY with the desktop stopped precisely to keep the GPU quiet.

Fix direction: treat a socket as live only when something listens on it (e.g. its path appears in ss -xl, or a short wayland client handshake succeeds). Prefer the newest live socket over the first glob match. When no live session exists, keep a way to hand the card back to automatic control (NVML as root does not need a display) so MAXTEMP and --revert still work.

Found while investigating material-04818d (idle GPU floor). Evidence: journalctl -u gpu-fan-curve on 2026-10-17 from 22:42, and a stale wayland-1 from 2026-10-16 10:12 still present at 23:10.

## Notes

- 2026-10-18T09:08:23Z (main): Fix direction now available: dots-0e5d83's gpu-ctl drives fan control through NVML (ctypes on libnvidia-ml.so.1) with no display, so the daemon (already root) could drop nvidia-settings and the Wayland-session discovery entirely; MAXTEMP and --revert would then work in TTY sessions too.
