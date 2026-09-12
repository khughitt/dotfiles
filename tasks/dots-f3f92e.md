---
id: dots-f3f92e
title: setup_preflight reads prism's declared sink requirements
status: done
priority: 2
size: s
created: 2026-09-09T00:32:21Z
updated: 2026-09-12T10:47:23Z
completed: 2026-09-12T10:47:23Z
depends: []
tags: [prism, setup]
---

setup.sh hardcodes 'quickshell (qs) — the debug-backdrop sink needs it' and a niri-accepts-the-generated-config check, restating knowledge the sink now declares in its manifest (prism docs/specs/2026-09-08-sink-requirements-design.md). Replace both with a call that reads prism's declaration, behind the node_modules check already above them — preflight runs on machines where npm ci has never run. Outcome: one statement of each prerequisite, in the sink that needs it.

## Notes

- 2026-09-12T10:47:23Z (preflight-prism): preflight runs prism requirements when node_modules exists and relays each unmet line and fix; the qs and niri-validate checks are gone
