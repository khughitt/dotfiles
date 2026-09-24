---
id: dots-7cb69d
title: "Noctalia: show drift as a notice, never an alert; clear by sources.drift freshness"
status: todo
priority: 3
size: s
complexity: mid
process: direct
created: 2026-09-24T17:34:33Z
updated: 2026-09-24T17:34:33Z
depends: []
tags: []
source: obs-4bd5bc
agent: claude-code
---

obs findings.json gains kind "drift" and a sources block (obs docs/findings.md: Drift findings, Consumer requirements). Render drift findings as notices, never alerts, and clear one only when sources.drift is fresh and complete and the finding is absent; a stale, missing or unreadable drift source leaves existing drift notices as they were and marks them stale.
