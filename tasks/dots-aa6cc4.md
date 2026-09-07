---
id: dots-aa6cc4
title: Verify TUI surfaces over pure glass and retune the seven-slot alphas once
status: done
priority: 2
size: s
owner: feat/prism-contexts-glass
created: 2026-09-07T08:21:16Z
updated: 2026-09-07T10:23:44Z
depends: []
tags: [glass, kitty, noctalia]
---

The seven transparent_background_colors alphas were tuned against a 0.93 kitty body. dots-a00088 (2026-09-06) put the body at 0 and gave the chrome tones 0.35/0.30/0.30/0.40; chrome is also OpenCode's root background, Crush and Claude Code reuse the same tones, and the diff tones at 0.72 and selection at 0.55 may now read heavier than the chrome around them. Outcome: one pass through nvim, opencode, crush, codex, and claude over a bright and a dark wallpaper with nested screenshots, then a single adjustment of the OPACITY table in bin/noctalia-glass-sync and bin/noctalia-glass-check, the kitty.conf fallback line, and the pinned tests. Record the chosen alphas and why in noctalia/noctalia.md.

## Notes

- 2026-09-07T10:18:03Z (feat/prism-contexts-glass): Nested Weston/niri captures cover all five installed TUIs over snow and forest wallpapers. Claude truecolor preview supports diff alphas 0.55 (was 0.72); retain chrome 0.35/0.30/0.30/0.40 and selection 0.55. Found harness NO_COLOR=1 and repeated captures without it. Crush 0.92 menu is transparent but selected row and low-contrast hints are app-owned; documented current behavior.
- 2026-09-07T10:23:44Z (feat/prism-contexts-glass): Captured all five TUIs over bright/dark wallpapers in nested Weston/niri; lowered diff alphas from 0.72 to 0.55, retained chrome and selection, synchronized generator/checker/fallback/tests, and documented the choice and current app limitations. Four glass/palette checks, six theme tests, and static checks pass; local screenshots saved in .superpowers/evidence/dots-aa6cc4.
