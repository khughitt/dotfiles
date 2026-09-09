---
id: dots-2ee196
title: A fresh machine never generates its Noctalia theme output
status: done
priority: 2
size: s
owner: main
created: 2026-09-08T22:44:17Z
updated: 2026-09-09T09:15:07Z
depends: []
tags: [noctalia, bootstrap, multi-machine]
---

Found on titan 2026-09-08 while fixing dots-708876. setup.sh creates the four DOTFILES_NOCTALIA_GENERATED state files with touch, and nothing in the repo ever triggers a theme regeneration: 'noctalia msg templates-apply' was verified to be a no-op when nothing changed, even against a state file holding deliberately wrong content. So a machine set up from scratch has empty noctalia includes - niri/noctalia.kdl, hypr/noctalia.conf, kitty/themes/noctalia.conf, zathura/noctaliarc - and stays unthemed until a wali wallpaper rotation or a manual theme toggle happens to fire. Forcing a real regeneration needs an actual theme change, e.g. 'noctalia msg theme-mode-toggle' twice. Outcome: setup.sh leaves a newly set up machine themed, or names the single command that does it.

## Notes

- 2026-09-09T09:15:07Z (main): The premise did not hold on 2026-09-09: 'noctalia msg templates-apply' rewrote a state file emptied to zero bytes and one holding deliberately wrong content, both back to the correct 1090-byte render, against the live instance. No theme-mode flip is needed. What setup.sh was missing was the call itself.
- 2026-09-09T09:15:07Z (main): setup.sh renders the theme when any generated output is empty: probe Noctalia, run templates-apply, and report any output still empty; when Noctalia is down it names the command instead.
