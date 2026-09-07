# Noctalia

Noctalia v5 owns stable shell behavior and the app-theme registry so wallpaper
changes have one tracked, reproducible source of truth. `noctalia/config.toml`
and `noctalia/templates.toml` are the tracked inputs; `setup.sh` links them,
the template sources, and the custom palette files into Noctalia's config.

## Templates

`noctalia/templates.toml` is the only registry. It selects eight user
templates: Glow, Nvim/glass synchronization, Claude Code, Codex, LSD, Fzf,
Fastfetch, and Ohai. It also selects eight built-ins: Hyprland, GTK 3, GTK 4,
Qt, Niri, Ghostty, Kitty, and Btop, and selects the Zathura, Bat, and Yazi
community templates.

The built-in Kitty template renders the wallpaper palette and keeps its theme
include in `kitty.conf`. Keeping the built-in selected prevents Noctalia's
startup reconciliation from invoking its undo hook against the tracked Kitty
configuration. The following Nvim template invokes `noctalia-glass-sync`, which
promotes Nvim, Kitty glass, and OpenCode artifacts and reloads Kitty after both
Kitty files are ready.

Validate the linked configuration and inspect the active registry with:

```bash
noctalia config validate
noctalia theme --list-templates
```

## Application themes

Noctalia renders the Claude Code semantic theme and Codex syntax theme from
the tracked registry.

Noctalia also renders LSD's native metadata, permission, date, size, tree, and
Git-status colors to `$XDG_CONFIG_HOME/lsd/colors.yaml`. LSD filename colors
remain owned by `LS_COLORS`. The LSD config directory is writable so Noctalia
can replace the generated theme, while its tracked `config.yaml` remains
linked from this repository.

Fzf reads `$XDG_CACHE_HOME/noctalia/fzf.conf` on every invocation through
`FZF_DEFAULT_OPTS_FILE`, so an existing shell sees later wallpaper updates.
Fastfetch reads its complete generated config from
`$XDG_CONFIG_HOME/fastfetch/config.jsonc`. Bat and Yazi use Noctalia's
community templates; their generated themes and selector files live in real
application config directories rather than in this repository. Yazi's tracked
`yazi.toml` remains linked into that writable directory.

`LS_COLORS`, Bash, Julia, and R prompt and syntax colors, VisiData, and the
man-page colors use terminal ANSI slots. Kitty and Ghostty already replace
those slots from the wallpaper palette, so these consumers follow Noctalia
without another rendered file or a shell restart. Semantic assignments such as
"directory uses blue" remain tracked while Noctalia owns what blue actually is.

Select `Noctalia` in Claude Code's `/theme` picker. Set Codex's syntax theme in
`~/.codex/config.toml`:

```toml
[tui]
theme = "noctalia"
```

The window background itself is at opacity 0 (Prism owns `background_opacity`
and niri's glass material is the surface behind the text), so every registered
tone carries its own opacity: the four chrome tones sit at 30-40% as a denser
smoke on the same glass. (Revised 2026-09-06, dots-a00088.)

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

## Local v5 plugins

Wali Panel and Prism are local Noctalia v5 plugins. Memory Pressure Alert
remains deferred.

Bootstrap them in two stages:

```bash
./setup.sh
# Start or reload Noctalia v5, then:
./setup.sh --only noctalia-plugins
```

Ordinary setup remains usable before the shell starts. The explicit plugin
phase links Wali from dotfiles and Prism from `~/d/prism`, then enables both
through Noctalia IPC. It requires the `~/d/prism` checkout and fails if the
Noctalia IPC endpoint is unavailable.

Dotfiles owns Wali, the Noctalia configuration, and installation; Prism owns
its plugin source. Wali depends on `walictl`; Prism depends on `prism` alone.

Prism's panel drives niri's native glass material through its `niri` sink,
which generates `prism.kdl` and reloads the compositor. There is no separate
preview surface: the open Kitty and Ghostty windows are what the panel
previews, and material sliders write once on release.

The `wallpaper_changed` hook in `noctalia/config.toml` hands every wallpaper
change to `prism context wallpaper` with `NOCTALIA_WALLPAPER_PATH`. Prism
activates that wallpaper's context: an untuned wallpaper is an empty overlay
and reloads nothing, a tuned one reapplies its delta. The wallpaper never
captures panel edits on its own; `prism context pin wallpaper` makes it the
write target for as long as it is on screen. Wallpapers are set on all
monitors at once, so the hook firing once per connector is idempotent. The v4
`wallpaperChange` feh command was X11-only and is not read by v5.
