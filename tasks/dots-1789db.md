---
id: dots-1789db
title: "setup.sh: generate before linking so an abort never leaves a dangling include"
status: done
priority: 1
size: s
owner: main
created: 2026-09-08T15:13:04Z
updated: 2026-09-08T21:47:12Z
depends: []
tags: [robustness, setup, prism]
---

Found bringing europa (laptop) up to date on 2026-09-08 after ~3 weeks. setup.sh:419 links niri/prism.kdl at the generated path before :427 generates it, so aborting in between left niri with an unresolvable include and an invalid config on a live machine. kitty/prism-generated.conf (setup.sh:418) has the same shape and was still dangling because nothing ever runs 'prism apply kitty'. Outcome: generated targets exist before the link is made, and every prism sink setup.sh links for is also applied.

## Notes

- 2026-09-08T21:47:12Z (main): Generated prism targets are created before the links point at them, so an abort never leaves niri with an unresolvable include; prism apply kitty now runs, so the kitty link setup.sh makes is no longer dangling. Regression tests assert both links resolve after a fresh graphical-config.
