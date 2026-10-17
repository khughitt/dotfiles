---
id: dots-a417c7
title: "dropdown terminals: take their look from prism (dotfiles side of prism-6a628e)"
status: todo
priority: 2
size: xs
complexity: low
process: direct
created: 2026-09-06T17:43:16Z
updated: 2026-10-17T22:29:30Z
depends: [prism-6a628e]
tags: [niri, dropdown, prism]
---

Why: theme the dropdown layer surfaces (kitty colours via kitty_conf/kitty_override, niri layer-rule shadow/blur/corner radius) as their own prism-owned look rather than the default terminal look. Follow-up to dots-7b24fa. On 2026-10-17 the owner chose option (b): prism owns the look as dropdown.* keys. That work is prism-6a628e. This task is the dotfiles side that follows it.

Established (scope 2026-10-17; evidence in prism-6a628e):
- dotfiles hand-sets the look today: niri/config.kdl's `^dropdown-` layer-rule (geometry-corner-radius 0 0 12 12, shadow on), plus per-case kitty options in niri/scripts/dropdown (background_opacity 0.85; for the mindful scratchpad 0.98 and an opaque transparent_background_colors sentinel).
- Neither prism's render path nor niri-material reaches layer surfaces today. Prism's live kitty push does: it sends `set-background-opacity --all` to every `@dotfiles-kitty-<pid>` socket, and the dropdowns hold such sockets. Fixing that belongs to prism-6a628e.
- Options considered and not chosen now: (a) a static dotfiles look; (c) niri-material glass on the dropdowns, which needs layer-surface material rendering that niri-material has not designed (its docs/notes/2026-10-14-noctalia-material-brief.md, alternative 2). The owner's long-term idea of a material renderer split out from niri is filed in niri-material as an idea.

Done when, after prism-6a628e lands:
- niri/config.kdl drops its `^dropdown-` layer-rule, now emitted in prism.kdl. Check that rule order in the include leaves no stale override.
- niri/scripts/dropdown stops passing background_opacity per case and reads prism's generated quick-access config, by the path prism-6a628e's design names. The scratchpad's readability override stays or moves as that design decides.
- tests/niri/test_dropdown.py follows: `uv run --frozen pytest -q tests/niri/test_dropdown.py`, then `just test`.
- Live check: restart the dropdowns, see prism's values, change one from the prism panel, and confirm the dropdowns follow it (or respawn, if the design says so). Taking the live desktop asks first.

Where: niri/config.kdl, niri/scripts/dropdown, tests/niri/test_dropdown.py; prism-6a628e's spec once written.

## Notes

- 2026-10-17T21:20:01Z (main): scope: question; body gains the evidence (prism reaches only window-rules and one kitty.conf; niri-material layer-rules take no glass material; quick-access-terminal.conf is the kitty seam) and two open questions: which look, (a) static blur and colours, (b) prism-owned dropdown.* keys, or (c) layer-surface glass in niri-material, and whether the scratchpad shares it; checked at 69e226c
- 2026-10-17T22:25:13Z (main): answer (user, 2026-10-17): (b) initially: prism owns the dropdown look as dropdown.* keys (niri sink emits the ^dropdown- layer-rule, kitty sink a quick-access-terminal.conf). Long term the user asks whether (c) could become a standalone material renderer: the material split from niri's logic, niri-material plus a 'material-surface' that can be toggled above a workspace, with kitty shown alongside it and coordinated. Q2 (does the scratchpad share the look) unanswered.
