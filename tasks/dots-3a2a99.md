---
id: dots-3a2a99
title: Describe the v alias as a file picker in the README
status: todo
priority: 3
size: xs
complexity: low
process: direct
created: 2026-10-24T13:48:53Z
updated: 2026-10-24T13:48:53Z
depends: []
tags: [docs]
source: dots-245e25
agent: codex
---

Why: README.md:204 labels v as nvim recent. shell/zoxide:9 defines v as nvim with fd piped through fzf, selecting a file from the current directory tree with no recency operation; zshrc loads that fragment.

Done: change the README label to nvim file picker and confirm it matches the alias source. Use normal documentation checks; do not change the alias behavior.
