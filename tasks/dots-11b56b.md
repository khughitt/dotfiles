---
id: dots-11b56b
title: Enable tailnet-only SSH into titan with key-only auth
status: done
priority: 2
size: s
complexity: low
process: direct
owner: feat/tailnet-ssh
created: 2026-10-04T17:01:48Z
updated: 2026-10-04T17:02:58Z
started: 2026-10-04T17:01:51Z
completed: 2026-10-04T17:02:57Z
depends: []
tags: [configuration]
model: claude-opus-5-5
agent: claude-code/claude-opus-5-5
---

Enable sshd on titan, reachable only from the tailnet (europa is the one planned client). Key-only auth, no root login, AllowUsers restricted to Tailscale address ranges. Capture the sshd drop-in in the repo and document install in docs/fresh-install-hardening.md. Root-only steps are run by the user.

## Notes

- 2026-10-04T17:01:51Z (main): started
  provenance: {"harness_session":"claude-code:ae4f4889-2ce4-497e-ad7e-4b7fc3ece1f8","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-04T17:01:56Z (feat/tailnet-ssh): resumed
  provenance: {"harness_session":"claude-code:ae4f4889-2ce4-497e-ad7e-4b7fc3ece1f8","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-04T17:02:57Z (feat/tailnet-ssh): Verified with an unprivileged sshd on :2222 using the drop-in: key from 100.72.125.0 accepted; same key from 192.168.1.105 refused (not listed in AllowUsers); password-only refused (publickey). Root install + europa key are user steps.
- 2026-10-04T17:02:57Z (feat/tailnet-ssh): done
  provenance: {"harness_session":"claude-code:ae4f4889-2ce4-497e-ad7e-4b7fc3ece1f8","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-04T17:02:57Z (feat/tailnet-ssh): Added ssh/sshd_config.d/10-tailnet.conf (key-only, no root, AllowUsers tailnet ranges) and the SSH section of docs/fresh-install-hardening.md; install and europa key are user-run root steps
  provenance: {"harness_session":"claude-code:ae4f4889-2ce4-497e-ad7e-4b7fc3ece1f8","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
