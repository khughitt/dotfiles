---
id: dots-2aa60c
title: Wallpaper quick-edit controls in the wali panel
status: idea
priority: 2
created: 2026-09-07T10:25:11Z
updated: 2026-09-07T10:39:15Z
depends: []
tags: [quick-add, noctalia, wallpaper]
source: "mindful:thought:ec1726a8595c47f78ddaad57f65eb89e"
---

Add quick tweaks for the loaded wallpaper to the wali panel, alongside the existing "open in gimp": brightness, contrast, noise, bloom, blur, saturation, chroma, hue.

Persistence idea: write the result as a modified copy of the original and prefer that copy over the raw wallpaper from then on, so the edit survives a wallpaper cycle and the original is never destroyed.

The panel is noctalia/plugins/wali-panel/ in this repo. Related: dots-cdb659 (exposing the current wallpaper to mind6).

## Notes

- 2026-09-07T10:39:15Z (main): Persistence fork, decide per effect: brightness/contrast/saturation/chroma/hue may belong in a prism wallpaper context (contexts/wallpaper/<id>.yaml, cf. prism-648e0f) applied at display time — reversible, composes with the glass, no second file to garbage-collect; noise/bloom/blur probably need a baked copy of the image.
