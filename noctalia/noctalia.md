# Noctalia

Noctalia v5 owns stable shell behavior and the app-theme registry so wallpaper
changes have one tracked, reproducible source of truth. `noctalia/config.toml`
and `noctalia/templates.toml` are the tracked inputs; `setup.sh` links them,
the template sources, and the custom palette files into Noctalia's config.

## Templates

`noctalia/templates.toml` is the only registry. It selects five user
templates: Glow, Nvim/glass synchronization, Claude Code, Codex, and Ohai. It
also selects seven built-ins: Hyprland, GTK 3, GTK 4, Qt, Niri, Ghostty, and
Btop, and selects the Zathura community template.

The Nvim template invokes `noctalia-glass-sync`, which remains the sole owner
of generated Nvim, Kitty, and OpenCode artifacts. The built-in Kitty template
is deliberately not selected: `noctalia-glass-sync` is the sole Kitty owner,
so its tracked configuration is not rewritten by a second hook.

Validate the linked configuration and inspect the active registry with:

```bash
noctalia config validate
noctalia theme --list-templates
```

## Application themes

Noctalia renders the Claude Code semantic theme and Codex syntax theme from
the tracked registry.

Select `Noctalia` in Claude Code's `/theme` picker. Set Codex's syntax theme in
`~/.codex/config.toml`:

```toml
[tui]
theme = "noctalia"
```

Claude Code reloads theme-file changes live. If its themes directory did not
exist when Claude started, restart once after the first render. Codex applies
its syntax theme in new sessions. Kitty gives Claude and Codex red/green diff
backgrounds 72% opacity. The registered `primary_container` gives Claude's
painted selection 55% opacity. Kitty's own terminal selection uses the paired
live `glass.selection_fg` (`on_primary_container`) foreground and
`glass.selection` (`primary_container`) background but remains opaque because
Kitty forces selected cells to alpha 1. Codex's input box remains opaque
because Codex owns and caches that background and exposes no theme role for it.

### OpenCode and Crush

`setup.sh` keeps OpenCode's tracked configuration and generated theme separate:

```text
~/.config/opencode -> ~/.config/opencode.local
~/.config/opencode/opencode.json -> ~/d/dotfiles/opencode/opencode.json
~/.config/opencode/tui.json -> ~/d/dotfiles/opencode/tui.json
~/.config/opencode/themes/noctalia.json
  -> ~/.cache/noctalia/nvim-glass/current/opencode-theme.json
```

The Noctalia Nvim template hook generates the OpenCode theme in the same atomic
generation as Nvim and Kitty. OpenCode 1.18.18 reloads a running interactive
TUI or `run` footer after a wallpaper switch; non-TUI modes such as `serve` are
not signalled. Before the first render, the dangling theme link is ignored and
OpenCode uses its built-in theme.

Setup copies existing ignored OpenCode runtime files into the machine-local
directory and atomically activates it. Inactive source copies remain ignored in
the repo because deleting them safely would require stopping every possible
writer; remove them manually only after confirming OpenCode is stopped.

OpenCode's root, panel, element, menu, context, and diff backgrounds reuse
Kitty's registered Noctalia glass colors. Small selected semantic controls and
hard-coded modal dimmers remain opaque because OpenCode exposes no independent
theme roles that Kitty can make translucent without sacrificing foreground
readability.

`crush/crushrc` sets `option ui transparent true` as the reproducible default.
Crush's saved global or workspace preference may override it. Crush 0.88.0 has
no custom-theme interface, so its application-painted blocks remain opaque.

## Glow theming

`setup.sh` links `noctalia/templates/` and the Noctalia v5
`noctalia/templates.toml` overlay into `~/.config/noctalia/`. Noctalia renders
the Glow stylesheet to `$XDG_CACHE_HOME/noctalia/glow.json` whenever the palette
changes, and Glow reads that generated file on each invocation.

## Deferred v4 plugins

Wali Panel, Memory Pressure Alert, and Prism v4 plugin ports are deferred.
Their retained source is not active v5 code and v5 does not install their QML
plugins.
