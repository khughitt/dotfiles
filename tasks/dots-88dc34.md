---
id: dots-88dc34
title: "Noctalia: wire the wallpaper_changed hook to Prism's wallpaper context verb"
status: done
priority: 2
size: xs
owner: main
created: 2026-09-05T18:50:52Z
updated: 2026-09-07T02:04:11Z
depends: [prism-fc8491]
tags: [noctalia, prism]
---

Outcome: the dotfiles-owned Noctalia config gains a wallpaper_changed hook that calls the Prism verb from prism-2f0b4b's wallpaper piece with NOCTALIA_WALLPAPER_PATH, and the existing wallpaperChange feh command in the legacy settings.json is reconciled with the v5 [hooks] table so only one hook definition remains. Verify the hook fires on both manual and automated wallpaper changes and that the feh behaviour is either kept as a second command in the array or confirmed obsolete under v5.

## Notes

- 2026-09-07T01:23:45Z (main): 2026-09-06: verb exists since prism-6fd864; hook waits on prism-fc8491 so an unpinned wallpaper stays inert (does not capture panel edits). Legacy settings.json wallpaperChange feh is v4 state v5 does not read; migration spec already retired fehbg as X11-only.
- 2026-09-07T02:04:11Z (main): wallpaper_changed hook in config.toml calls prism context wallpaper with NOCTALIA_WALLPAPER_PATH; verified on titan for a manual walictl change and the 15-minute automation; v4 feh wallpaperChange blanked in local settings.json (unread by v5).
