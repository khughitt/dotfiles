---
id: dots-ba0168
title: "Wali panel UI polish pass: buttons, spacing, typography, color"
status: done
priority: 2
size: m
owner: wali-panel-polish
created: 2026-09-09T01:31:26Z
updated: 2026-09-09T02:07:51Z
depends: [dots-fa9cc0]
tags: [quick-add, noctalia, wallpaper]
source: "mindful:thought:a1a5726e2ff44a0586a4e56dea0e5d86"
---

Design and polish pass over the wali panel (noctalia/plugins/wali-panel). Current state, from a 2026-09-08 screenshot: flat grey pill buttons in two rows (Refresh / Previous / Next / Random, Favorite / Edit / Copy), uneven vertical gaps between the title, image, metadata block and button rows, plain 'Taken: / Favorite: / Source:' metadata labels, and no color anywhere.

Scope: layout and spacing rhythm, typography hierarchy for title and metadata, button shape and grouping, and a color pass that draws from the wallpaper or the material palette rather than staying monochrome. Functional behaviour stays as is.

Follow-up for fun (separate idea): heart-only favorite and click animations.

## Notes

- 2026-09-09T02:05:23Z (wali-panel-polish): Landed photo-first layout; ui.button ignores color (host warns), so the favorite highlight uses selected. plugin.toml changes need plugins disable/enable; .luau hot-reloads. just test fails on tests/setup_and_health.zsh (noctalia msg plugins disable) on main before this branch; unrelated, see dots-cb89b3.
- 2026-09-09T02:07:51Z (wali-panel-polish): Photo-first wali panel landed: bordered 16:9 frame, date and id caption with a selected-state heart, outline nav strip with primary Random, ghost Refresh/Edit/Copy, panel 588x520. Forced past dots-fa9cc0: its only open item is deleting the legacy favorites.txt, which does not affect the panel.
