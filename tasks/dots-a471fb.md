---
id: dots-a471fb
title: The public dotfiles repository names the work gh account in two 2026-08-12 design docs
status: todo
priority: 2
size: xs
complexity: low
process: direct
created: 2026-10-18T22:46:05Z
updated: 2026-10-18T22:46:05Z
depends: []
tags: [git]
agent: claude-code/claude-opus-5-5
---

Found 2026-10-18 while publishing relay v0.1.0 (relay-c19c0a), which rewrote the same login out of relay's history first (relay-06b733). In khughitt/dotfiles (PUBLIC), the login of the gh account that gh auth status lists besides khughitt appears at HEAD in docs/plans/2026-08-12-noctalia-opencode-crush-kitty.md and docs/specs/2026-08-12-noctalia-opencode-crush-kitty-design.md (2 history lines). It is already public, so a rewrite cannot recall it. The user decides: (a) accept; (b) redact it at HEAD only (say 'the work account'); (c) redact and rewrite history, then force-push, which leaves the old commits fetchable by sha on GitHub unless the repository is recreated. Never write the login itself in a record or commit.
