---
id: dots-1d2e44
title: niri chords drive walictl without the panel
status: done
priority: 2
size: s
owner: feat/wali-keyboard
created: 2026-09-09T02:47:54Z
updated: 2026-09-10T00:38:58Z
depends: []
tags: [quick-add, noctalia, wallpaper, keyboard, cross-project]
source: "mindful:thought:1784d44106a5411bb28a90796f46acf4"
---

Bind a Super+Alt (or agreed) chord set in niri that calls walictl directly: previous, next, random, favorite. Each fires a small notification confirming the photo so no panel is needed. Retire or repoint the Super+N wali spawn as part of the toggle decision in ops-fcdf59. This is the no-UI mode of the keyboard goal and can land before the in-panel key capture.

## Notes

- 2026-09-10T00:35:40Z (feat/wali-keyboard): Added Super+Alt+Left/Right/R/F direct walictl bindings with result/error notifications. Super+Alt+L remains the lock-screen binding. Super+N now toggles the Wali panel. Verified all four shell commands with success/failure output and quoted photo names.
- 2026-09-10T00:38:58Z (feat/wali-keyboard): Implemented and verified direct niri wallpaper controls with notifications; Super+Alt+Left/Right/R/F avoid the existing lock-screen binding. Activation follows integration.
