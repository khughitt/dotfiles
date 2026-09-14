---
id: dots-1fed32
title: Bound the Noctalia large-wallpaper cache
status: idea
priority: 2
created: 2026-09-14T11:13:07Z
updated: 2026-09-14T11:13:07Z
depends: []
tags: [noctalia, wallpaper]
agent: claude-code/claude-opus-5
---

~/.cache/noctalia/images/wallpapers/large held 1390 PNGs (12G, ~9MB each) on 2026-09-14: one rendered copy per wallpaper ever shown, so wali's rotation grows it toward a full render of the backgrounds collection. It is symlinked onto /mnt/ssd2/cache for now (dots-8257db). Worth checking whether Noctalia needs the large cache at all with the v5 wallpaper pipeline, whether it can be capped or aged, or whether wali should own the rendered copies. Related: dots-cdb659, docs/specs/2026-09-07-wallpaper-management-redesign-design.md.
