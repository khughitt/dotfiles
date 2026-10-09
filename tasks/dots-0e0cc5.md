---
id: dots-0e0cc5
title: "zshenv: keep inherited XDG_CONFIG_HOME and XDG_STATE_HOME instead of overwriting them"
status: todo
priority: 2
size: xs
complexity: low
process: direct
created: 2026-10-09T01:29:21Z
updated: 2026-10-09T01:29:21Z
depends: []
tags: []
source: hq-c19b34
agent: claude-code/claude-opus-5-5
---

zshenv exports XDG_CONFIG_HOME=$HOME/.config and XDG_STATE_HOME=$HOME/.local/state unconditionally. zsh reads zshenv on every start, so a harness hook run through zsh replaces an isolated root the run inherited (XDG_CONFIG_HOME=$(mktemp -d) for a scratch tasks registry, for example), and the hook then reads a different claim inventory from the session's own tools. Use the default-preserving form, export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}" (same for XDG_STATE_HOME), and check that an isolated root survives zsh -c and zsh -lc.
