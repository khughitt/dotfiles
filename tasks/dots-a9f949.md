---
id: dots-a9f949
title: dotfiles-health checks a hardcoded list of leak-prone generated files
status: todo
priority: 2
size: s
created: 2026-09-08T22:44:17Z
updated: 2026-09-08T22:44:17Z
depends: []
tags: [health, multi-machine, robustness]
---

Found on titan 2026-09-08 while fixing dots-708876. check_noctalia_generated_is_not_in_tree walks DOTFILES_NOCTALIA_GENERATED, so it only catches the four files someone already thought of. The leak surface is structural, not enumerable: ~/.config/{niri,hypr,kitty,zathura} are whole-directory symlinks into the shared tree, so any file any app writes into one of them lands in the tree and syncs to the other machine. The six config dirs that are real directories (btop, yazi, bat, lsd, gtk-3.0, fastfetch) cannot leak; the correlation is exact. The general check is the audit run by hand while closing dots-708876: for each whole-directory-symlinked config, list files that are neither tracked in git nor symlinks resolving outside the tree, and flag them. About fifteen lines. Outcome: a new leak is caught the first time it appears, without anyone adding it to a list.
