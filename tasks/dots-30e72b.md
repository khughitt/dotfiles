---
id: dots-30e72b
title: Remove the dead v4 Noctalia config files
status: todo
priority: 3
size: xs
complexity: low
process: direct
created: 2026-09-07T21:16:21Z
updated: 2026-10-18T10:16:29Z
depends: []
tags: [noctalia]
---

Why: Noctalia v5 (5.3.0, installed 2026-10-17) reads ~/.config/noctalia/config.toml (linked from noctalia/config.toml) and its settings layer; the v4 files beside it are inert, and their presence led the wallpaper redesign spec (docs/specs/2026-09-07-wallpaper-management-redesign-design.md, "still being rewritten by something") to file this as a hunt for a writer.

Established 2026-10-18, so no session needs to re-derive it: nothing rewrites settings.json any more. Its mtime is 2026-09-06 21:42 and has not moved in six weeks; no tracked file wrote it before the walictl redesign (git grep at ecab164 over bin/walictl, shell/wali and the wali panel finds no writer); no v4 shell config remains (~/.config/quickshell is empty). The last write predates dots-59c279, so the writer is gone and does not need identifying.

Done: settings.json, settings.json.bak, plugins.json, colors.json and user-templates.toml.v4-backup are moved out of ~/.config/noctalia (to a dated backup outside ~/.config, or deleted once confirmed), the next Noctalia restart or config reload logs no new warning in ~/.cache/noctalia/noctalia.log, and none of the files reappears.

Where: ~/.config/noctalia; the v5 source checkout (~/software/noctalia): grep src for each filename before removing it. On 2026-10-18 none of these names is read from ~/.config/noctalia; the colors.json v5 reads is ~/.cache/wal/colors.json (src/theme/firefox_theme/firefox_theme.cpp). dots-1fed32 removes the matching v4 cache. Side: the quickshell package (the v4 runtime) is still explicitly installed and required by nothing; removing it is a separate host decision for the owner.
