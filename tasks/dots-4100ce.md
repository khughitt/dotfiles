---
id: dots-4100ce
title: Add shellcheck and just to the Arch package list
status: done
priority: 3
size: s
owner: main
created: 2026-09-08T15:13:04Z
updated: 2026-09-08T21:53:25Z
depends: []
tags: [setup, gates]
---

Found bringing europa (laptop) up to date on 2026-09-08 after ~3 weeks. just check fails on a fresh machine because shellcheck is absent, and just itself had to be installed by hand. Both are gate dependencies of this repo. Outcome: PACKAGES carries them so a machine set up by setup.sh can run its own gates.

## Notes

- 2026-09-08T21:53:25Z (main): just and shellcheck added to the Arch package list, so a machine set up by setup.sh can run its own gates.
