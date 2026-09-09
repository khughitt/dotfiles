---
id: dots-0ba19b
title: "setup.sh: preflight every per-machine prerequisite before mutating state"
status: done
priority: 1
size: m
owner: main
created: 2026-09-08T15:13:04Z
updated: 2026-09-09T09:43:50Z
depends: []
tags: [robustness, setup, bootstrap]
---

Found bringing europa (laptop) up to date on 2026-09-08 after ~3 weeks. Three prerequisites were discovered one crash at a time across a whole session. Outcome: a preflight (its own phase or --check) verifies and reports together: npm plus prism's node_modules, that the installed niri accepts the config prism will emit, that qs/quickshell exists for the debug-backdrop sink, that Noctalia is running for the plugins phase, and that the tasks registry is populated. Report all findings, mutate nothing.

## Notes

- 2026-09-08T21:52:29Z (main): Added a preflight phase that runs first and reports npm, prism node_modules, the tasks binary and registry, niri, quickshell, noctalia, whether the installed niri accepts the generated config, and noctalia IPC when the plugins phase is requested - each with its own fix line, mutating nothing. --check (just preflight) runs it alone and exits non-zero on findings; in a normal run findings are reported without gating, since the phase that needs the prerequisite fails on its own.
- 2026-09-09T09:43:50Z (main): Two of the six artifacts the goal names were still not preflighted: familiar's node_modules (the one that broke every agent hook on europa) and ~/.config/mindful.env. Both are checks now, so --check names all six at once.
