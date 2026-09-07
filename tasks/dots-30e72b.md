---
id: dots-30e72b
title: Find what still rewrites the dead v4 noctalia settings.json
status: idea
priority: 2
created: 2026-09-07T21:16:21Z
updated: 2026-09-07T21:16:21Z
depends: []
tags: [noctalia]
---

v5 never reads ~/.config/noctalia/settings.json, yet its mtime keeps advancing (2026-09-06 last). Identify the writer and stop it or delete the file. Surfaced by the wallpaper redesign spec.
