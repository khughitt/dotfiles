---
id: dots-cb89b3
title: Reconcile the noctalia-plugins phase with what dotfiles-health requires
status: done
priority: 2
size: s
owner: main
created: 2026-09-08T15:13:04Z
updated: 2026-09-09T09:24:09Z
depends: []
tags: [setup, health, noctalia]
---

Found bringing europa (laptop) up to date on 2026-09-08 after ~3 weeks. setup.sh:656 only runs noctalia-plugins under --only, so a normal full run never installs them, yet dotfiles-health fails unconditionally when they are absent - 6 of 10 health failures on europa. Outcome: one policy. Either the phase runs in a full pass when Noctalia is up, or health treats it as conditional.

## Notes

- 2026-09-08T22:15:54Z (main): Overlaps a new surface: setup.sh --check (dots-0ba19b) now also answers 'is this machine ok', so dotfiles-health and preflight duplicate each other and nothing runs --check automatically. Reconcile the two, not just the noctalia-plugins phase.
- 2026-09-09T09:24:09Z (main): Decision: the phase runs in every pass. Links need nothing running and are what health requires, so they are always made; only 'plugins enable' talks to Noctalia, and when it is down setup names the two commands. A running Noctalia that refuses the enable stays a failure. The wider setup.sh --check vs dotfiles-health duplication the note raised is not settled here.
- 2026-09-09T09:24:09Z (main): setup.sh runs noctalia-plugins in a full pass, linking always and enabling when Noctalia answers, so dotfiles-health's unconditional check is now met by a normal run.
