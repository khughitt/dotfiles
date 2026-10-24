---
id: dots-c33e2b
title: Correct the README configuration-directory variable
status: todo
priority: 1
size: xs
complexity: low
process: direct
created: 2026-10-24T13:48:52Z
updated: 2026-10-24T18:57:44Z
depends: []
tags: [docs]
source: dots-245e25
agent: codex
---

Why: README.md:44 says setup links major configuration files under XDG_CONFIG_DIR; setup.sh:208 defaults and uses XDG_CONFIG_HOME, with no XDG_CONFIG_DIR use.

Done: replace $XDG_CONFIG_DIR with $XDG_CONFIG_HOME in that setup sentence, confirm it matches setup source and run the documentation checks. No setup execution or host change is needed.
