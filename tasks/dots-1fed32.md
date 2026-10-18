---
id: dots-1fed32
title: Delete the dead v4 Noctalia wallpaper render cache
status: todo
priority: 3
size: xs
complexity: low
process: direct
created: 2026-09-14T11:13:07Z
updated: 2026-10-18T10:16:31Z
depends: []
tags: [noctalia, wallpaper]
agent: claude-code/claude-opus-5
---

Why: the 12G large-wallpaper cache (1390 PNGs, ~9MB each, under ~/.cache/noctalia/images/wallpapers/large, symlinked onto /mnt/ssd2/cache/noctalia/images/wallpapers by dots-8257db) was filed as growing toward a full render of the backgrounds collection, with the question whether to cap it, age it, or have wali own the renders.

Established 2026-10-18, so no session needs to re-derive it: the cache is v4's and dead. Its newest file is 2026-08-19 19:58, the v5 migration, and nothing has been added since. v5 renders wallpaper previews only into ~/.cache/noctalia/thumbnails (src/render/core/thumbnail_service.cpp in the v5 source; no v5 source names images/wallpapers): 3259 webp files, 76M, about 700 added in the last month (~16 MB a month), which needs no bound. The cap/age/ownership question has no subject left.

Done: the symlink ~/.cache/noctalia/images/wallpapers and its target tree (large, overview, thumbnails) are removed, with ~/.cache/noctalia/wallpapers.json (v4's index, same 2026-08-19 19:58 mtime); /mnt/ssd2 gains about 12G; after the next Noctalia restart and a wallpaper change the wallpaper panel still shows previews and nothing recreates images/wallpapers.

Where: ~/.cache/noctalia and /mnt/ssd2/cache/noctalia; dots-8257db's notes record the symlink. Other pre-v5 files in ~/.cache/noctalia (theming.dynamic.toml, shell-state.json, notifications.json, github.json, supporters.json, predefined-scheme.json) are candidates only after a grep of the v5 source shows none is read; leave any in doubt. dots-30e72b removes the matching v4 files under ~/.config/noctalia. Related: docs/specs/2026-09-07-wallpaper-management-redesign-design.md.

## Notes

- 2026-10-18T10:16:29Z (main): scope: scoped; premise failed 2026-10-18: newest file in the large cache is 2026-08-19 19:58 (v5 migration), v5 writes only ~/.cache/noctalia/thumbnails (thumbnail_service.cpp, 76M, ~16 MB/month); narrowed from bounding the cache to deleting it; P3 xs low direct
