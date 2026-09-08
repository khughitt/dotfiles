---
id: dots-0ba19b
title: "setup.sh: preflight every per-machine prerequisite before mutating state"
status: todo
priority: 1
size: m
created: 2026-09-08T15:13:04Z
updated: 2026-09-08T15:13:04Z
depends: []
tags: [robustness, setup, bootstrap]
---

Found bringing europa (laptop) up to date on 2026-09-08 after ~3 weeks. Three prerequisites were discovered one crash at a time across a whole session. Outcome: a preflight (its own phase or --check) verifies and reports together: npm plus prism's node_modules, that the installed niri accepts the config prism will emit, that qs/quickshell exists for the debug-backdrop sink, that Noctalia is running for the plugins phase, and that the tasks registry is populated. Report all findings, mutate nothing.
