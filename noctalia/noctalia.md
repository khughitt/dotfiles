# Noctalia

## Local plugins

Running `setup.sh` in graphical mode installs the local `wali-panel` plugin by symlinking:

`noctalia/plugins/wali-panel` -> `~/.config/noctalia/plugins/wali-panel`

Noctalia will discover the plugin from disk on startup or plugin refresh. If the widget does not appear yet, open Plugins settings in Noctalia and enable `wali-panel`.

The plugin expects `~/bin/walictl` to exist, which is provided by the existing top-level `bin` symlink created by `setup.sh`.

## Neovim theming

Noctalia renders a palette template to candidate JSON; `~/bin/noctalia-glass-sync`
validates it, writes both generated files to a version directory, flips the
`~/.cache/noctalia/nvim-glass/current/` symlink, then signals kitty and nvim.
Register the template in `~/.config/noctalia/user-templates.toml`:

```toml
[templates.nvim]
input_path = "~/.config/nvim/lua/user/noctalia/palette-template.json"
output_path = "~/.cache/noctalia/nvim-palette.candidate.json"
post_hook = "~/bin/noctalia-glass-sync"
```

Use `:NoctaliaMood <name>` to switch syntax mood variants. See
`docs/specs/2026-08-09-noctalia-nvim-theme-design.md` for the full pipeline.

## Agent themes

Noctalia directly renders the Claude Code semantic theme and Codex syntax
theme. Register both templates in `~/.config/noctalia/user-templates.toml`:

```toml
[templates.claude]
input_path = "~/d/dotfiles/noctalia/templates/claude.json"
output_path = "~/.claude/themes/noctalia.json"

[templates.codex]
input_path = "~/d/dotfiles/noctalia/templates/codex.tmTheme"
output_path = "~/.codex/themes/noctalia.tmTheme"
```

Select `Noctalia` in Claude Code's `/theme` picker. Set Codex's syntax theme in
`~/.codex/config.toml`:

```toml
[tui]
theme = "noctalia"
```

Claude Code reloads theme-file changes live. If its themes directory did not
exist when Claude started, restart once after the first render. Codex applies
its syntax theme in new sessions; the rest of its interface continues to use
the terminal palette.

## Persistent memory-pressure alerts

The memory-pressure-alert plugin is installed through this managed link:

```text
~/.config/noctalia/plugins/memory-pressure-alert
  -> ~/d/dotfiles/noctalia/plugins/memory-pressure-alert
```

Enable it from Noctalia's Plugins settings. It is headless and does not add a
bar widget.

The plugin inherits the existing System Monitor memory thresholds. Installation
keeps the current/default 80% warning and 90% critical values, so it does not
silently retune the bar gauge. For earlier notification, explicitly choose 70%
warning and 85% critical in Settings → System Monitor → Thresholds; the gauge
and persistent banner will then change together.

Warning recovery is plugin-specific and defaults to 65%. Alerts are replicated
on every screen. Polling pauses on Noctalia's lock screen and refreshes after
unlock. Open btop launches ghostty -e btop.
