---
id: dots-dbf616
title: Track Prism's context files per host in dotfiles
status: todo
priority: 2
size: xs
created: 2026-09-07T08:21:16Z
updated: 2026-09-07T08:21:16Z
depends: []
tags: [prism, setup]
---

The context-layers spec (prism docs/specs/2026-09-05-prism-context-layers-design.md) says dotfiles tracks ~/.config/prism/contexts/ per host, and values.yaml is already a hardlink into prism/<host>/. Nothing links the contexts directory, so the first 'prism context pin wallpaper' plus a slider edit creates untracked state. Outcome: setup.sh links ~/.config/prism/contexts to prism/<host>/contexts (create the directory, keep values.yaml as it is), a health check confirms the link, and a pinned-wallpaper edit lands in the tracked tree. Verify on titan and note what europa needs.
