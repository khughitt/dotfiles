---
id: dots-11b56b
title: Enable tailnet-only SSH into titan with key-only auth
status: doing
priority: 2
size: s
complexity: low
process: direct
owner: main
created: 2026-10-04T17:01:48Z
updated: 2026-10-04T17:01:51Z
started: 2026-10-04T17:01:51Z
depends: []
tags: [configuration]
agent: claude-code/claude-opus-5-5
---

Enable sshd on titan, reachable only from the tailnet (europa is the one planned client). Key-only auth, no root login, AllowUsers restricted to Tailscale address ranges. Capture the sshd drop-in in the repo and document install in docs/fresh-install-hardening.md. Root-only steps are run by the user.

## Notes

- 2026-10-04T17:01:51Z (main): started
  provenance: {"harness_session":"claude-code:ae4f4889-2ce4-497e-ad7e-4b7fc3ece1f8","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
