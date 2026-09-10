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

Before giving the systemd timer ownership, remove `enabled` from
`[wallpaper.automation]` in
`${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/settings.toml` if present, then run
`noctalia msg config-reload`. Noctalia state settings override tracked config, so
verify the exported effective config has wallpaper automation disabled.

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
walictl earlier             # previous photo by capture time
walictl later               # next photo by capture time
walictl random              # a weighted sample
walictl favorite            # toggle the current photo; --add/--remove [<id>]
walictl favorites --json
walictl neighbors --json    # capture-time neighbours, for mind6; --count must be non-negative
walictl edit                # GIMP on the original, else on the display file
walictl observe             # hook entry point
walictl import-favorites <favorites.txt>
```

`Super+N` toggles the Wali Panel. Inside it, `h/l` or Left/Right walks history;
`k/j` or Up/Down selects the earlier/later photo by capture time. `f` toggles
favorite, `e` edits, `y` copies the source path (display path if no source exists),
`r` samples, `?` or `F1` toggles help, and Escape closes the panel.

Without opening the panel, `Super+Alt+Left/Right` runs previous/next,
`Super+Alt+R` samples, and `Super+Alt+F` toggles favorite. Each reports the photo
or command error through `notify-send` (provided by `libnotify`).

`earlier` and `later` share the ordering used by `neighbors`: capture date,
then photo id to order shots within the day. They prefer variants, append a
history entry after Noctalia accepts the selection, and discard forward history.
They fail at either end of the library or when the current photo is undated or
absent from the library; they do not wrap or sample.

Sampling weights: favorites weigh `1 + favorite_boost`, months weigh
`1 + period_boost * favorite density`, and the last `exclude_recent` shown
photos weigh 0. `exclude_recent` must be a non-negative integer; both boosts
must be finite non-negative numbers, and an overflowing total weight is an
error. History records selections Noctalia accepted; only the default
(all-monitor) wallpaper is tracked.

Design: `docs/specs/2026-09-07-wallpaper-management-redesign-design.md`.
