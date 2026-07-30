# Kitty Copy Last Command Output Design

## Goal

Copy the previous command's displayed output to the Wayland clipboard with one
keyboard shortcut in a direct Kitty shell session.

## Design

Add one mapping to `kitty/kitty.conf` for `Ctrl+Shift+Y`. The mapping launches
`wl-copy` in the background with Kitty's `@last_cmd_output` stream as standard
input.

Kitty's existing shell integration supplies command boundaries for both Zsh and
Bash. The copied text excludes the command and prompts, contains no terminal
formatting escapes, and is limited by Kitty's configured scrollback history.

## Non-Goals

- No Zsh or Bash hooks.
- No tmux support.
- No new scripts or dependencies.

## Verification

Validate the Kitty configuration, then run a command with recognizable standard
output and standard error and confirm `wl-paste` returns only that output after
pressing `Ctrl+Shift+Y`.
