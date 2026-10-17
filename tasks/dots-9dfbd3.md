---
id: dots-9dfbd3
title: Declare the global git hook that runs git-identity-check (hook.identity-check on pre-commit and pre-merge-commit)
status: doing
priority: 2
size: xs
complexity: low
process: direct
owner: main
created: 2026-10-17T09:56:21Z
updated: 2026-10-17T10:25:25Z
started: 2026-10-17T10:25:25Z
depends: []
tags: []
source: ops-4c9eb4
agent: claude-code/claude-opus-5-5
---

The commit identity guard (ops docs/specs/2026-10-16-commit-identity-guard-design.md §4.4) runs from a hook in global git config. Add to git/config: [hook "identity-check"] event = pre-commit, event = pre-merge-commit, command = /usr/bin/python3 "$HOME/.local/bin/git-identity-check" (the system interpreter, so an older python3 first on PATH, such as an activated environment's, never decides whether commits are judged). Only after ops-4c9eb4's rollout has installed the command and swept clean on every host: the file syncs to every host, and a host without the command refuses every commit. Done: git hook list --show-scope pre-commit names identity-check (global) on every host, and a commit with GIT_COMMITTER_NAME=t in a registered checkout is refused.

## Notes

- 2026-10-17T10:25:25Z (main): started
  provenance: {"harness_session":"claude-code:854dcd72-1ec1-4c31-9036-697c6944b3bc","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
