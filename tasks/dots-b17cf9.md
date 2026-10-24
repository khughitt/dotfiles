---
id: dots-b17cf9
title: Document the supported memory-alert installation and activation route
status: todo
priority: 3
size: s
complexity: mid
process: direct
created: 2026-10-24T13:48:53Z
updated: 2026-10-24T13:48:53Z
depends: []
tags: [docs]
source: dots-245e25
agent: codex
---

Why: noctalia/plugins/memory-pressure-alert/README.md explains behavior, thresholds, dismissal and settings but neither it nor the root README provides an installation/enablement route. setup.sh:903 links/enables only external Wali and Prism plugins, so ordinary setup supplies no implicit route for this local plugin.

Done: establish the intended supported local-plugin deployment route from existing configuration and document the prerequisites, installation/enablement steps and where its settings are opened. Confirm commands against source before prescribing them. This task documents the route without activating or installing anything on a host. The alert-type/integration extensions dots-d957b1 and dots-c0c9fd do not own this guide omission. Use normal documentation checks.
