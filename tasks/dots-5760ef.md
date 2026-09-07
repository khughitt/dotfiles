---
id: dots-5760ef
title: Move wali ingestion functions off WALI_DIR/BACKGROUND_IMG_DIR env vars
status: idea
priority: 2
created: 2026-09-07T21:16:21Z
updated: 2026-09-07T21:16:21Z
depends: []
tags: [wallpaper]
---

After dots-59c279 the runtime reads ~/.config/wali/config.toml, but wali_ingest/wali_reprocess/wali_rotate in shell/wali still read env vars from shell/private. Have them read the same config (e.g. walictl config --json).
