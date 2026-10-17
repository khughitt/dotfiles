---
id: dots-9b6a65
title: Run git-identity-check by name from the global identity-check hook
status: todo
priority: 2
size: xs
complexity: low
process: direct
created: 2026-10-17T11:24:06Z
updated: 2026-10-17T11:24:06Z
depends: []
tags: [git]
agent: claude-code/claude-opus-5-5
---

Why: `git/config`'s `[hook "identity-check"]` runs `/usr/bin/python3 $HOME/.local/bin/git-identity-check`. A test that sandboxes HOME but inherits XDG_CONFIG_HOME still loads this file through `~/.config/git`, `$HOME` names the sandbox, and every fixture commit fails (ops-b06c52 has the reproduction).

Done: the entry reads `command = git-identity-check`, and its comment says the script's `#!/usr/bin/python3` shebang makes the system interpreter decide; `HOME=<scratch> git commit` in a scratch repository passes, and a real commit in a claimed checkout is still judged (`git commit --allow-empty` with a wrong `-c user.email` is refused).

Order: only after ops-b06c52 lands the shebang and `just install`'s link points at it; before that, the name would run under the `python3` first on PATH.

Where: `git/config`, the hook block and its comment.
