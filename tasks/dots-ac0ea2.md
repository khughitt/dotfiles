---
id: dots-ac0ea2
title: kitty/os-local.conf selects by OS from inside the shared tree
status: done
priority: 2
created: 2026-09-08T22:44:17Z
updated: 2026-09-12T10:58:54Z
completed: 2026-09-12T10:58:54Z
depends: []
tags: [kitty, multi-machine]
---

Noticed on titan 2026-09-08 auditing the tree for dots-708876. kitty/os-local.conf is an in-tree symlink to kitty/os-linux.conf, chosen by operating system, with kitty/os-macos.conf sitting beside it - the same shape as the niri/host.kdl bug fixed in dots-e4570d, one class up: it selects by OS rather than by hostname. Harmless while every machine is Linux, which is why the dotfiles-health machine-specific-symlink check does not flag it, but the presence of os-macos.conf means a macOS machine is a supported scenario on paper, and the moment one joins the two would overwrite each other's selection through Dropbox. Unscoped: decide whether macOS is still a real target before spending anything here.

## Notes

- 2026-09-12T10:58:54Z (kitty-os): each host's kitty/<hostname>.conf includes its os-*.conf; the in-tree os-local.conf link, its setup.sh ln_s, and its gitignore entry are gone; a test guards the shape
