---
id: dots-a417c7
title: "dropdown terminals: a distinct prism x niri-material profile"
status: idea
priority: 2
reviewed: true
awaiting_user: true
reviewed_at: 2026-10-17T21:20:01Z
created: 2026-09-06T17:43:16Z
updated: 2026-10-17T21:20:02Z
depends: []
tags: [niri, dropdown, prism]
---

Follow-up to dots-7b24fa: theme the dropdown layer surfaces (kitty colours via kitty_conf/kitty_override, niri layer-rule shadow/blur/corner radius) as their own prism profile rather than the default terminal look.

## Evidence (scope 2026-10-17)

- Two hand-set places hold today's dropdown look. niri/config.kdl's `^dropdown-` layer-rule sets corner radius 0 0 12 12 and a shadow, with no background-effect. niri/scripts/dropdown sets kitty options per case: background_opacity 0.85, and for the mindful scratchpad 0.98 plus an opaque transparent_background_colors sentinel.
- Prism does not reach either. Its niri sink emits the glass only as window-rules matched on `terminal.apps` (kitty, ghostty), and the dropdowns are layer surfaces, which window-rules never match. Its kitty sink writes one kitty.conf (background_opacity from terminal.background.opacity.active), and every dropdown overrides that on its command line.
- In prism, a "profile" is a whole named look, with one active at a time (prism-aec90f's compositional profiles, prism-2f0b4b's contexts). A dropdown look beside the window look would be new keys, such as a dropdown.* group, rather than a profile.
- niri-material cannot draw the glass on a layer surface. Its layer-rules accept background-effect (blur, xray, noise, saturation) and surface-remap. surface-remap recolours an opaque shell's surfaces to a material's face and the workspace's project hue (material-62347d, landed 2026-10-17 for Noctalia). Material rendering for layer surfaces is alternative 2 of niri-material's docs/notes/2026-10-14-noctalia-material-brief.md: unbuilt, and it would need its own design (surface footprint, client composition, lifecycle).
- kitty's quick-access-terminal reads its own quick-access-terminal.conf (or `-c <path>`), which can carry kitty_conf and kitty_override. A generated file there is where a prism kitty output would write.

## Open questions

1. Which look do you want for the dropdowns? (a) A distinct non-glass look from existing pieces (layer-rule background-effect blur plus kitty colours and opacity), in dotfiles only. (b) The same look owned by prism as dropdown.* keys you can tune from the panel: the niri sink emits the `^dropdown-` layer-rule and the kitty sink a quick-access-terminal.conf. This is prism work. (c) niri-material glass on the dropdowns, which first needs layer-surface material rendering designed in niri-material. Lean: (a) if they only need to read differently from windows; (b) if you expect to tune them alongside the glass; (c) only if the glass itself is the point.
2. Should the mindful scratchpad share that look? It sits over other windows' text at 0.98 opacity, so it may need to keep its readability-first override.

## Notes

- 2026-10-17T21:20:01Z (main): scope: question; body gains the evidence (prism reaches only window-rules and one kitty.conf; niri-material layer-rules take no glass material; quick-access-terminal.conf is the kitty seam) and two open questions: which look, (a) static blur and colours, (b) prism-owned dropdown.* keys, or (c) layer-surface glass in niri-material, and whether the scratchpad shares it; checked at 69e226c
