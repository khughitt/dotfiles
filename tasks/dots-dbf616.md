---
id: dots-dbf616
title: Track Prism's context files per host in dotfiles
status: done
priority: 2
size: xs
owner: feat/prism-contexts-glass
created: 2026-09-07T08:21:16Z
updated: 2026-09-07T10:03:10Z
depends: []
tags: [prism, setup]
---

The context-layers spec (prism docs/specs/2026-09-05-prism-context-layers-design.md) says dotfiles tracks ~/.config/prism/contexts/ per host, and values.yaml is already a hardlink into prism/<host>/. Nothing links the contexts directory, so the first 'prism context pin wallpaper' plus a slider edit creates untracked state. Outcome: setup.sh links ~/.config/prism/contexts to prism/<host>/contexts (create the directory, keep values.yaml as it is), a health check confirms the link, and a pinned-wallpaper edit lands in the tracked tree. Verify on titan and note what europa needs.

## Notes

- 2026-09-07T09:56:37Z (feat/prism-contexts-glass): Current setup already symlinks the whole Prism host directory, including contexts; scope is tracked context directories, health coverage, and a pinned-write verification, without adding a redundant nested symlink.
- 2026-09-07T10:02:43Z (feat/prism-contexts-glass): Verified on titan: a real prism context pin + set using the live config link, isolated active state and disabled sinks created a Git-visible context under prism/titan/contexts; base values unchanged and probe removed. Setup/health suite and shellcheck -x pass; Europa bootstrap documented.
- 2026-09-07T10:03:10Z (feat/prism-contexts-glass): Kept contexts under the existing per-host Prism directory link; tracked empty Titan/Europa directories, setup creation, and health validation. Verified real pinned writes reach Titan Git storage without changing base values; Europa bootstrap documented.
