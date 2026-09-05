---
id: dot-88dc34
title: "Noctalia: wire the wallpaper_changed hook to Prism's wallpaper context verb"
status: todo
priority: 2
size: xs
created: 2026-09-05T18:50:52Z
updated: 2026-09-05T18:51:01Z
depends: [prism-648e0f]
tags: [noctalia, prism]
---

Outcome: the dotfiles-owned Noctalia config gains a wallpaper_changed hook that calls the Prism verb from prism-2f0b4b's wallpaper piece with NOCTALIA_WALLPAPER_PATH, and the existing wallpaperChange feh command in the legacy settings.json is reconciled with the v5 [hooks] table so only one hook definition remains. Verify the hook fires on both manual and automated wallpaper changes and that the feh behaviour is either kept as a second command in the array or confirmed obsolete under v5.
