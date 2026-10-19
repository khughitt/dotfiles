---
id: dots-13dc87
title: Enable rust_analyzer in the Neovim LSP server list
status: done
priority: 2
size: xs
process: direct
owner: dots-13dc87
created: 2026-10-19T09:05:46Z
updated: 2026-10-19T09:09:37Z
started: 2026-10-19T09:06:09Z
completed: 2026-10-19T09:09:37Z
closed: 2026-10-19T09:09:37Z
depends: []
tags: [nvim]
agent: claude-code
---

Neovim starts no Rust language server: nvim/lua/user/lsp.lua leaves rust_analyzer out of its server list. Add it, and add rust-analyzer to the header's pacman install hint. The binary is the Arch package rust-analyzer: the rust-analyzer on PATH is only a rustup proxy, and the active toolchain is the linked system one, which ships none. Needed for the learn-rust course (session 0.1 onward).

## Notes

- 2026-10-19T09:06:09Z (dots-13dc87): started
  provenance: {"harness_session":"claude-code:d476761e-334c-49bd-a3eb-d3ec877cde24","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-19T09:09:37Z (dots-13dc87): done
  provenance: {"harness_session":"claude-code:d476761e-334c-49bd-a3eb-d3ec877cde24","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-19T09:09:37Z (dots-13dc87): rust_analyzer is in the Neovim LSP server list; the header names the pacman package and the rustup component, and why a missing component fails at start rather than being skipped. Verified: headless load of the worktree config reports it enabled; just check and just test pass.
  provenance: {"harness_session":"claude-code:d476761e-334c-49bd-a3eb-d3ec877cde24","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
