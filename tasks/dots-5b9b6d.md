---
id: dots-5b9b6d
title: Recolor the Dropbox tray icon with Noctalia's app icon colorization
status: todo
priority: 3
size: xs
complexity: low
process: direct
created: 2026-10-09T14:58:40Z
updated: 2026-10-18T10:16:54Z
depends: []
tags: [quick-add]
source: "mindful:thought:831df9055e45b067f2ed480991d90d04"
agent: claude-code/claude-opus-5-5
---

Why: the Dropbox tray icon, a full-color pixmap, clashes with the Noctalia bar. (The source thought also lists "drop nm-applet? (niri has its own)" and "prism: replace icon (gem? other options?)"; neither is filed here.)

Established 2026-10-18: Noctalia v5 already recolors application bitmap icons. `[shell] app_icon_colorize = true`, with `app_icon_color` as a color role or hex (default on_surface_variant in dark mode), tints the bar tray and its drawer (v5 source docs/user/configuration/shell.mdx, "App icon colorization"; both keys are in the installed 5.3.0 binary). The switch is shell-wide: dock, taskbar, the active-window widget icon and launcher result icons recolor too; there is no tray-only switch. Symbolic tray icons are left alone.

Done: noctalia/config.toml sets app_icon_colorize under [shell]; after a config reload the Dropbox icon renders in the palette's color; the owner accepts the shell-wide recolor of the active-window icon and launcher results. If they do not, revert it and fall back to an icon-theme override of Dropbox's tray icon name alone.

Where: noctalia/config.toml (live through the link from the main checkout: a branch is not live until merged), noctalia/noctalia.md for the config notes. Reloading the live bar is host-use: ask at the time. Related: dots-6bfb8d (bar restyle), docs/notes/2026-10-18-noctalia-shell-restyle-brief.md.

## Notes

- 2026-10-18T10:16:52Z (main): scope: scoped; v5's [shell] app_icon_colorize/app_icon_color recolors tray pixmaps (shell.mdx, present in installed 5.3.0), shell-wide; owner judges the recolor; P3 xs low direct
