---
id: dots-c618a4
title: Decide whether Hyprland is still a live target
status: done
priority: 2
size: s
owner: main
created: 2026-09-08T22:15:45Z
updated: 2026-09-09T09:29:38Z
depends: []
tags: [hypr, cleanup, multi-machine]
---

Found on titan 2026-09-08 while fixing dots-e4570d. hypr/host.conf had been stale since 2026-05-01 and setup.sh never called hypr/host_specific.sh at all until that fix wired it in; the selector had been dead code for months without anyone noticing. Hyprland is installed and hypr/ is still maintained in the tree, but niri is the daily driver and every recent change (prism niri sink, niri-material, noctalia.kdl) targets niri only. Outcome: a decision, not a fix - either hypr is a supported second compositor and its config is verified like niri's, or it is vestigial and leaves the tree.

## Notes

- 2026-09-09T09:29:38Z (main): Verdict: vestigial, removed. hypr/ leaves the tree, along with the Hyprland entry in GRAPHICAL_CONFIGS and DOTFILES_NOCTALIA_GENERATED, the hyprland Noctalia builtin, the host_specific.sh call, the shellcheck entries, and every test that asserted Hyprland theming. dotfiles-health gains check_absent_stale_config_link hypr, the retired-config mechanism snakemake and tealdeer already use. On titan the dangling ~/.config/hypr link and the orphaned state directory were removed; health passes and Noctalia's config still validates with seven builtins.
- 2026-09-09T09:29:38Z (main): Hyprland is not a live target: hypr/ removed from the tree and from setup, health, the Noctalia registry, and the tests; health now checks the link stays absent.
