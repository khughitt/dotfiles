---
id: dots-cb89b3
title: Reconcile the noctalia-plugins phase with what dotfiles-health requires
status: todo
priority: 2
size: s
created: 2026-09-08T15:13:04Z
updated: 2026-09-08T15:13:04Z
depends: []
tags: [setup, health, noctalia]
---

Found bringing europa (laptop) up to date on 2026-09-08 after ~3 weeks. setup.sh:656 only runs noctalia-plugins under --only, so a normal full run never installs them, yet dotfiles-health fails unconditionally when they are absent - 6 of 10 health failures on europa. Outcome: one policy. Either the phase runs in a full pass when Noctalia is up, or health treats it as conditional.
