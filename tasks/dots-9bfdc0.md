---
id: dots-9bfdc0
title: "Wali panel polish pass 2: borderless buttons, subtle color, drop Refresh"
status: todo
priority: 2
size: s
created: 2026-09-09T02:28:45Z
updated: 2026-09-09T02:47:54Z
depends: []
tags: [quick-add, noctalia, wallpaper]
source: "mindful:thought:1784d44106a5411bb28a90796f46acf4"
---

Second design pass on noctalia/plugins/wali-panel after pass 1 (dots-ba0168). Try the nav buttons without discrete borders: ghost variant or a quieter indication of the pressable area. Explore subtle color or effects beyond Random in primary. Remove the Refresh button: onOpen already refreshes and the button is usually a no-op. Keep the 16:9 frame and the date-and-id caption.

## Accepted suggestions (2026-09-08 review)

- History position hint: walictl current returns history.cursor and history.length; show "65 / 66" or a dot beside Next so it is clear whether Next replays history or samples a fresh photo.
- Palette swatches under the frame: four small dots in primary, secondary, tertiary, and surface so the photo-to-palette relationship is visible (ties to prism and the glass material).
- Move Edit and Copy behind a right-click context menu on the photo (panel.openContextMenu), leaving nav plus heart as the visible chrome. Needs plugin_api 28+; check the installed Noctalia's supported range first (5.0.1 today).
- Click the photo for Random (ui.image accepts onClick), so the Random button can drop to the same weight as its neighbors.
