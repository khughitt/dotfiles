---
id: dots-7b24fa
title: "niri: dropdown scratchpad terminals via kitty quick-access-terminal"
status: done
priority: 2
size: s
owner: main
created: 2026-09-06T17:27:07Z
updated: 2026-09-06T17:43:47Z
depends: []
tags: [niri, kitty]
---

Guake-style toggled terminals (shell on Alt+Return, ipython on Alt+P) drawn as layer-shell surfaces so they never occupy a workspace. Spike verified toggling, focus handoff, per-instance-group isolation on niri 26.04 fork.

## Notes

- 2026-09-06T17:29:39Z (main): Landed: niri/scripts/dropdown (term, ipython), Alt+Return / Alt+P binds, hidden pre-spawn at startup, layer-rule for ^dropdown-. Verified live on titan.
- 2026-09-06T17:43:47Z (main): niri/scripts/dropdown (term, ipython) as kitty quick-access layer surfaces at 80% width; Alt+Return / Alt+P binds; hidden pre-spawn at startup; layer-rule; pytest coverage.
