# Wallpaper selection with walictl

Noctalia v5 displays wallpapers and derives colors. `bin/walictl` decides which
photo is shown, remembers what was shown, and keeps favorites. The Wali Panel
plugin (`khughitt/wali-panel`) is a view over `walictl current --json`.

## Ownership

| Concern | Owner |
|---|---|
| Display, palette, templates, hooks | Noctalia |
| Next photo, history, favorites, config | `walictl` |
| Timed rotation | `systemd/user/wali-rotate.timer` running `walictl next` |
| Changes made in Noctalia's own panel | `wallpaper_changed` hook running `walictl observe` |
| Per-wallpaper glass deltas | prism |

## Files

| Path | Purpose |
|---|---|
| `$XDG_CONFIG_HOME/wali/config.toml` | Per-host config, linked from `wali/<hostname>/config.toml` |
| `<favorites_file>` | Favorites keyed by photo id, synced with the backgrounds directory |
| `$XDG_STATE_HOME/wali/history.json` | Per-host history with a cursor |
| `bin/walictl` | The CLI |
| `tests/bin/test_walictl.py` | Tests |

## Commands

```
walictl current --json      # id, date, path, source_path, variant_path, favorite, history
walictl next                # forward in history, else a weighted sample
walictl previous            # back in history
walictl random              # a weighted sample
walictl favorite            # toggle the current photo; --add/--remove [<id>]
walictl favorites --json
walictl neighbors --json    # capture-time neighbours, for mind6; --count must be non-negative
walictl edit                # GIMP on the original, else on the display file
walictl observe             # hook entry point
walictl import-favorites <favorites.txt>
```

Sampling weights: favorites weigh `1 + favorite_boost`, months weigh
`1 + period_boost * favorite density`, and the last `exclude_recent` shown
photos weigh 0. `exclude_recent` must be a non-negative integer; both boosts
must be finite non-negative numbers, and an overflowing total weight is an
error. History records selections Noctalia accepted; only the default
(all-monitor) wallpaper is tracked.

Design: `docs/specs/2026-09-07-wallpaper-management-redesign-design.md`.
