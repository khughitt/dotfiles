---
id: dots-cdb659
title: Expose the current wallpaper and its time-neighbors to mind6
status: idea
priority: 2
created: 2026-09-06T22:07:49Z
updated: 2026-09-06T22:07:49Z
depends: []
tags: [noctalia, wallpaper, mind6]
---

dotfiles half of the wallpaper/background sync with mind6 (hub in the mind6 project). walictl already resolves the current Noctalia wallpaper to its PXL_YYYYMMDD_* source under BACKGROUND_IMG_DIR and walks siblings for forward/backward. Decide how mind6 learns the current photo and its neighbors in time: a walictl subcommand (current --json plus neighbors), a file written by the wallpaper_changed hook (dots-88dc34 already wires that hook toward Prism), or a Prism context verb. Same underlying photo store either way.
