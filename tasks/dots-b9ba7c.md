---
id: dots-b9ba7c
title: "Wali panel: heart-only favorite and subtle click animations"
status: dropped
priority: 2
created: 2026-09-09T01:32:07Z
updated: 2026-09-12T09:35:41Z
depends: [dots-ba0168]
tags: [quick-add, noctalia, wallpaper]
source: "mindful:thought:a1a5726e2ff44a0586a4e56dea0e5d86"
---

For fun, after the polish pass (dots-ba0168). Replace the 'Favorite' label with just a heart, plus one other small, subtle touch. On click, a short, pretty, colorful and subtle animation for both the on and off transitions: a light sweep or a soft pulse, with slight organic variation so no two clicks look identical.

## Notes

- 2026-09-09T02:28:45Z (main): Seed mindful:thought:1784d44106a5411bb28a90796f46acf4 adds: light up / subtle glow when a button is activated, alongside the heart click animation.
- 2026-09-09T02:47:54Z (main): Accepted: hover as the glow trigger. Buttons and rows expose onHover; use panel.setNeedsFrameTick + onFrameTick for a short fade in and out, plus a brief flash on press. No persistent color.
- 2026-09-12T09:35:41Z (wali-migration): moved to wali-3bcef2
