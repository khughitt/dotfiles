---
id: dots-f2304d
title: Track the console keymap that gives tmux Alt+arrow keys on a TTY
status: doing
priority: 3
size: xs
complexity: low
process: direct
owner: main
created: 2026-09-21T09:39:26Z
updated: 2026-09-21T09:39:31Z
started: 2026-09-21T09:39:31Z
depends: []
tags: [configuration]
agent: claude-code/claude-opus-5
---

The Linux console keymap (KEYMAP=us) replicates cursor keysyms into the Alt column and binds Alt+Left/Right to VT switching, so tmux.conf's M-Up/M-Down/M-Left/M-Right/M-PPage bindings never fire on a VT. A us-tmux keymap that binds the Alt column of those keys to the xterm modifier sequences (ESC[1;3A..D, ESC[5;3~, ESC[6;3~) is installed on titan at /usr/share/kbd/keymaps/i386/qwerty/us-tmux.map with KEYMAP=us-tmux in /etc/vconsole.conf. Keep the map in the repo and document the install so it is reproducible.

## Notes

- 2026-09-21T09:39:31Z (main): started
  provenance: {"harness_session":"claude-code:c0f271e1-a69e-447e-854e-5127749f824c","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
