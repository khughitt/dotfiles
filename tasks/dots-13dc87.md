---
id: dots-13dc87
title: Enable rust_analyzer in the Neovim LSP server list
status: todo
priority: 2
size: xs
process: direct
created: 2026-10-19T09:05:46Z
updated: 2026-10-19T09:05:55Z
depends: []
tags: [nvim]
agent: claude-code
---

Neovim starts no Rust language server: nvim/lua/user/lsp.lua leaves rust_analyzer out of its server list. Add it, and add rust-analyzer to the header's pacman install hint. The binary is the Arch package rust-analyzer (the ~/.cargo/bin entry is only a rustup proxy; the active toolchain is the linked 'system' one at /usr, which has none). Needed for the learn-rust course (session 0.1 onward).
