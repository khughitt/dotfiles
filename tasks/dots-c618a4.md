---
id: dots-c618a4
title: Decide whether Hyprland is still a live target
status: todo
priority: 2
size: s
created: 2026-09-08T22:15:45Z
updated: 2026-09-08T22:15:45Z
depends: []
tags: [hypr, cleanup, multi-machine]
---

Found on titan 2026-09-08 while fixing dots-e4570d. hypr/host.conf had been stale since 2026-05-01 and setup.sh never called hypr/host_specific.sh at all until that fix wired it in; the selector had been dead code for months without anyone noticing. Hyprland is installed and hypr/ is still maintained in the tree, but niri is the daily driver and every recent change (prism niri sink, niri-material, noctalia.kdl) targets niri only. Outcome: a decision, not a fix - either hypr is a supported second compositor and its config is verified like niri's, or it is vestigial and leaves the tree.
