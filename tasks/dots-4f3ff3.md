---
id: dots-4f3ff3
title: dotfiles_check builds the pre-runtime mindful layout and fails the wrapper test
status: done
priority: 3
size: xs
complexity: low
process: direct
owner: main
created: 2026-09-14T11:13:07Z
updated: 2026-09-17T11:25:42Z
started: 2026-09-17T11:19:42Z
completed: 2026-09-17T11:25:42Z
depends: []
tags: [configuration]
agent: claude-code/claude-opus-5
---

tests/dotfiles_check.zsh creates $HOME/d/mindful/v6/packages/mindful/dist/bin.js in a temp home, but bin/mindful (since 0c75052, docs/mindful-runtime.md) execs $HOME/.local/share/mindful/current/bin/node, so the test dies with 'No such file or directory' after printing 'dotfiles checks passed' and just test stops before layout_check and justfile. Seen on main on 2026-09-14. Fix the fixture to lay out the runtime the wrapper now expects (a node stub under .local/share/mindful/current/bin plus the dist) and make the test fail loudly rather than after its own pass message.

## Notes

- 2026-09-17T11:25:42Z (dots-4f3ff3): dotfiles_check now stubs the runtime layout bin/mindful execs (node under ~/.local/share/mindful/current plus packages/mindful/dist) and fails loudly on wrapper errors instead of dying after its own pass message
