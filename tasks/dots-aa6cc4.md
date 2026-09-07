---
id: dots-aa6cc4
title: Verify TUI surfaces over pure glass and retune the seven-slot alphas once
status: todo
priority: 2
size: s
created: 2026-09-07T08:21:16Z
updated: 2026-09-07T08:21:16Z
depends: []
tags: [glass, kitty, noctalia]
---

The seven transparent_background_colors alphas were tuned against a 0.93 kitty body. dots-a00088 (2026-09-06) put the body at 0 and gave the chrome tones 0.35/0.30/0.30/0.40; chrome is also OpenCode's root background, Crush and Claude Code reuse the same tones, and the diff tones at 0.72 and selection at 0.55 may now read heavier than the chrome around them. Outcome: one pass through nvim, opencode, crush, codex, and claude over a bright and a dark wallpaper with nested screenshots, then a single adjustment of the OPACITY table in bin/noctalia-glass-sync and bin/noctalia-glass-check, the kitty.conf fallback line, and the pinned tests. Record the chosen alphas and why in noctalia/noctalia.md.
