---
id: dots-9b6a65
title: Run git-identity-check by name from the global identity-check hook
status: doing
priority: 2
size: xs
complexity: low
process: direct
owner: main
created: 2026-10-17T11:24:06Z
updated: 2026-10-17T11:46:55Z
started: 2026-10-17T11:43:26Z
depends: [ops-b06c52]
tags: [git]
agent: claude-code/claude-opus-5-5
---

Why: `git/config`'s `[hook "identity-check"]` runs `/usr/bin/python3 $HOME/.local/bin/git-identity-check`. A test that sandboxes HOME but inherits XDG_CONFIG_HOME still loads this file through `~/.config/git`, `$HOME` names the sandbox, and every fixture commit fails (ops-b06c52 has the reproduction).

Done: the entry is the one in ops's spec §4.4 (`command = command -v git-identity-check >/dev/null && exec git-identity-check || exec \"$HOME/.local/bin/git-identity-check\"`: PATH first, then `$HOME/.local/bin`), and its comment says why and that the script's `#!/usr/bin/python3` shebang makes the system interpreter decide; `HOME=<scratch> git commit` in a scratch repository passes, and a real commit in a claimed checkout is still judged (`git commit --allow-empty` with a wrong `-c user.email` is refused).

Order: only after ops-b06c52 lands the shebang and `just install`'s link points at it; before that, the name would run under the `python3` first on PATH.

Where: `git/config`, the hook block and its comment.

Gate: the global git config is a live global surface: ask the user before merging, as ops's plan Step 6 did.

## Notes

- 2026-10-17T11:24:13Z (main): concerns: dots-9dfbd3 defect — the hook command expands $HOME, so a HOME-only sandbox that inherits XDG_CONFIG_HOME fails every commit
- 2026-10-17T11:43:26Z (main): started
  provenance: {"harness_session":"claude-code:a8e01f86-bfc2-47ab-8483-117fa3a98456","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-17T11:43:26Z (fix/identity-hook-by-name): resumed
  provenance: {"harness_session":"claude-code:a8e01f86-bfc2-47ab-8483-117fa3a98456","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-17T11:44:51Z (fix/identity-hook-by-name): parked (waiting on user, approval): On the user's approval: merge fix/identity-hook-by-name (715af39, verified via GIT_CONFIG_GLOBAL probes) into dotfiles main from ~/d/dotfiles, then on titan and europa check git hook list --show-scope pre-commit names identity-check and a wrong -c user.email commit in a claimed checkout is refused; remove the worktree and tasks done
  provenance: {"harness_session":"claude-code:a8e01f86-bfc2-47ab-8483-117fa3a98456","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-17T11:46:55Z (main): resumed
  provenance: {"harness_session":"claude-code:a8e01f86-bfc2-47ab-8483-117fa3a98456","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
