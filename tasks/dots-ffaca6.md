---
id: dots-ffaca6
title: Complete icat filenames by substring like other commands
status: todo
priority: 3
size: xs
complexity: low
process: direct
created: 2026-10-22T23:17:46Z
updated: 2026-10-22T23:17:46Z
depends: []
tags: [kitty]
agent: claude-code/claude-opus-5-5
---

The icat alias expands to 'kitty +kitten icat' during completion, so it uses kitty's _kitty completer. kitten __complete__ filters by prefix itself (compadd -U) and refuses anchor matchers ('r:|=*', 'l:|=* r:|=*') from matcher-list, so 'icat den<TAB>' finds nothing while 'ls den<TAB>' completes. Fix: make icat a shell function with its own zsh completer over image files, so matcher-list applies.
