---
id: dots-e4570d
title: Per-machine symlinks must not live in the Dropbox-synced tree
status: done
priority: 1
size: s
owner: main
created: 2026-09-08T21:32:19Z
updated: 2026-09-08T21:38:18Z
depends: []
tags: [robustness, multi-machine, niri]
---

Found on titan 2026-09-08. The dotfiles checkout is inside Dropbox and ~/.config/niri links into it, so both machines share one working tree. setup.sh:453 runs host_specific.sh with NIRI_DIR=$DOTS_HOME/niri, writing niri/host.kdl into that shared tree; whichever machine ran setup last wins and Dropbox pushes it to the other. titan was live-including host-europa.kdl. hypr/host.conf has the identical bug and is gitignored, so it fights silently. niri/host.kdl was also committed by accident in a6b8452. Invariant: a symlink inside the synced tree may only point at a path identical on every machine (niri/prism.kdl obeys it). Outcome: host selection resolves through ~/.local/state, no per-machine symlink remains in the tree, and dotfiles-health checks the invariant.

## Notes

- 2026-09-08T21:38:18Z (main): Host selection resolves through XDG_STATE_HOME for both niri and hypr; niri/host.kdl untracked and removed, hypr/host.conf removed and unignored; setup.sh now runs the hypr selector too; dotfiles-health fails on any machine-specific symlink in the shared tree; titan cut over live and reloaded.
