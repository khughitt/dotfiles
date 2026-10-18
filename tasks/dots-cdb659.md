---
id: dots-cdb659
title: Expose the current wallpaper and its time-neighbors to mind6
status: dropped
priority: 2
created: 2026-09-06T22:07:49Z
updated: 2026-10-18T10:24:30Z
closed: 2026-10-18T10:24:30Z
depends: [dots-59c279]
tags: [noctalia, wallpaper, mind6]
source: "mindful:thought:fee58ae2c54b4072ad2b0ba02a2cf1d1"
---

dotfiles half of the wallpaper/background sync with mind6 (hub in the mind6 project). walictl already resolves the current Noctalia wallpaper to its PXL_YYYYMMDD_* source under BACKGROUND_IMG_DIR and walks siblings for forward/backward. Decide how mind6 learns the current photo and its neighbors in time: a walictl subcommand (current --json plus neighbors), a file written by the wallpaper_changed hook (dots-88dc34 already wires that hook toward Prism), or a Prism context verb. Same underlying photo store either way.

## Notes

- 2026-09-07T21:16:21Z (wallpaper-redesign): dots-59c279 gives mind6 favorites.json keyed by photo stem plus walictl current --json and neighbors --json; pick the interface there.
- 2026-10-18T10:17:33Z (main): scope: drop; no body change; proposal: drop — the interface it was to choose landed in dots-59c279 (walictl current --json and neighbors --json, now in the wali repo), and the pull-vs-push transport choice is mind6-29b4b3's design; any push-side hook is filed in wali from that design. Before dropping, run tasks dep mind6-ed7695 --on mind6-29b4b3 (from the mind6 checkout) so mind6-ed7695 keeps a recorded wait
- 2026-10-18T10:24:30Z (main): dropped
  provenance: {"harness_session":"claude-code:128450af-f7ee-4450-a2b3-f84acd5dda93","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-18T10:24:30Z (main): Dropped (approved 2026-10-18): the interface landed in dots-59c279 (walictl current/neighbors --json, now in wali); the transport choice is mind6-29b4b3's, and mind6-ed7695 now depends on it directly
  provenance: {"harness_session":"claude-code:128450af-f7ee-4450-a2b3-f84acd5dda93","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
