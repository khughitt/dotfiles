---
id: dots-c3a650
title: Restore git identity and drop protocol.file.allow in git/config
status: done
priority: 0
size: xs
complexity: low
process: direct
owner: dots-c3a650
created: 2026-10-16T16:29:42Z
updated: 2026-10-16T16:30:22Z
started: 2026-10-16T16:29:42Z
completed: 2026-10-16T16:30:22Z
depends: []
tags: []
agent: claude-code/claude-opus-5-5
---

A sandboxed test script (HOME overridden, XDG_CONFIG_HOME not) ran git config --global on 2026-10-07 and wrote user.name=t, user.email=t@t and [protocol "file"] allow = always into git/config through ~/.config/git; be55b00 committed it. Restore the real identity and remove the protocol.file override (it disables git's CVE-2022-39253 mitigation).

## Notes

- 2026-10-16T16:29:42Z (main): started
  provenance: {"harness_session":"claude-code:9c070e8d-dc83-4336-8ab8-fa5eb8b20204","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-16T16:29:48Z (dots-c3a650): resumed
  provenance: {"harness_session":"claude-code:9c070e8d-dc83-4336-8ab8-fa5eb8b20204","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-16T16:30:22Z (dots-c3a650): done
  provenance: {"harness_session":"claude-code:9c070e8d-dc83-4336-8ab8-fa5eb8b20204","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-16T16:30:22Z (dots-c3a650): Restored user.name/user.email and removed [protocol "file"] allow = always; the file matches its pre-be55b00 blob (bb44efc).
  provenance: {"harness_session":"claude-code:9c070e8d-dc83-4336-8ab8-fa5eb8b20204","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
