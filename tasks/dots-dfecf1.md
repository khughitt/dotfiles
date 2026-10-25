---
id: dots-dfecf1
title: Prepare Noctalia attention widget and supervised familiar startup rollout
status: todo
priority: 2
size: m
complexity: mid
process: direct
created: 2026-10-24T14:13:28Z
updated: 2026-10-25T02:10:39Z
depends: [fam-9c8dd1, hq-4c954d]
tags: []
agent: codex
---

Prepare the desktop activation for fam-9c8dd1: install/link the local khughitt/familiar Noctalia v5 plugin from the familiar integration source, replace the built-in workspaces bar entry with khughitt/familiar:workspaces, preserve output/orientation/navigation behavior and existing settings gestures, replace the unsupervised familiar-niri watch startup with one transient user service using restart-on-failure, and retain the familiar popup renderer. Record source-resolved familiar commands and previous bar/startup/native-setting images with exact restore commands. Check systemctl user readiness and actual PATH resolution; no shared launcher may point into a task worktree. Validate with the headless pilot first. All live activation, desktop effects and source-pointer-changing integration require user approval at that moment; this task prepares the reviewable diffs/runbook and does not authorize activation.

## Notes

- 2026-10-24T21:32:40Z (main): fam-9c8dd1 code is reviewed (branch feat/desktop-attention, unmerged); familiar's runbook docs/runbooks/desktop-attention-rollout.md (on that branch) gives the exact pieces: plugin link ~/.local/share/noctalia/plugins/familiar -> <familiar>/integrations/noctalia-plugin, bar entry 'khughitt/familiar:workspaces' in place of 'workspaces' (no [widget.x] table needed, as with khughitt/prism:widget), supervised unit via systemd-run --user --unit=familiar-attention with Restart=on-failure and StartLimitIntervalSec=60/StartLimitBurst=5, NIRI_SOCKET/PATH passed through, and a check that 'familiar' resolves on Noctalia's and the popup's PATH (today it is an nvm npm link). Merging familiar into main is itself activation (niri config starts the watcher and popup from the main checkout).
- 2026-10-25T02:10:39Z (main): from fam-8c5e1c (merged in familiar 7143e04): under the new coordinator a SIGTERM (systemctl stop/restart, or a plain systemctl kill) is a clean stop that Restart=on-failure does not restart and the crash history does not count; keep Restart=on-failure with RestartSec=2 in the persistent unit; the runbook's kill check is now systemctl --user kill --kill-whom=main --signal=SIGKILL familiar-attention. Until this unit lands, Niri still starts the watcher via spawn-sh-at-startup.
