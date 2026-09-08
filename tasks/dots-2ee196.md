---
id: dots-2ee196
title: A fresh machine never generates its Noctalia theme output
status: todo
priority: 2
size: s
created: 2026-09-08T22:44:17Z
updated: 2026-09-08T22:44:17Z
depends: []
tags: [noctalia, bootstrap, multi-machine]
---

Found on titan 2026-09-08 while fixing dots-708876. setup.sh creates the four DOTFILES_NOCTALIA_GENERATED state files with touch, and nothing in the repo ever triggers a theme regeneration: 'noctalia msg templates-apply' was verified to be a no-op when nothing changed, even against a state file holding deliberately wrong content. So a machine set up from scratch has empty noctalia includes - niri/noctalia.kdl, hypr/noctalia.conf, kitty/themes/noctalia.conf, zathura/noctaliarc - and stays unthemed until a wali wallpaper rotation or a manual theme toggle happens to fire. Forcing a real regeneration needs an actual theme change, e.g. 'noctalia msg theme-mode-toggle' twice. Outcome: setup.sh leaves a newly set up machine themed, or names the single command that does it.
