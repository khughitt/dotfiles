---
id: dots-c0c9fd
title: Surface obs findings through the Noctalia alert path
status: todo
priority: 2
size: m
complexity: mid
process: planned
created: 2026-09-17T17:02:07Z
updated: 2026-09-17T17:10:33Z
depends: [obs-1ad448, dots-d957b1]
tags: []
source: obs-fabc63
agent: codex
---

Consumer follow-up to obs-045db1 and obs-fabc63. Extend the Noctalia alert path targeted by disk-report/dots-d957b1 to consume reviewed obs findings; retain task/session identity, next action/owner, evidence class and current/resolved state. Keep disk-report focused on resource measurements. The current memory-pressure-alert plugin does not yet consume disk-report, so coordinate the shared alert design rather than assume that integration exists. Review the consumer design and attended rendering before enabling; no desktop mutation during obs planning.
