---
id: dots-6faea7
title: "docs/mindful-runtime.md: tailscale serve should target http://localhost:3331, not 127.0.0.1 (the service binds ::1 once IPv6 is on)"
status: doing
priority: 2
size: xs
complexity: low
process: direct
owner: main
created: 2026-10-03T17:36:13Z
updated: 2026-10-11T14:44:28Z
started: 2026-10-11T14:44:27Z
depends: []
tags: [docs]
agent: claude-code/claude-opus-5-5
---

Line 77 documents 'tailscale serve --bg --https=443 http://127.0.0.1:3331'. Since IPv6 was re-enabled (2026-10-02 reboot), the Mindful web unit's HOST=localhost binds [::1] only, so that target refuses connections and the phone app reads as offline. The live serve config was repointed to http://localhost:3331 on 2026-10-03; the doc should match.

## Notes

- 2026-10-11T14:44:26Z (main): Direct documentation correction: replace the single Tailscale Serve IPv4 literal with localhost to match HOST=localhost and the already-corrected live target. No callers, tests, fixtures, exports, or runtime configuration need changes; verify the diff and repository checks.
- 2026-10-11T14:44:27Z (main): started
  provenance: {"harness_session":"codex:01a12b69-9f7f-7d93-a836-6cf561e07bee","harness_session_source":"CODEX_THREAD_ID"}
