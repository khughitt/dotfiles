# Noctalia Wallpaper Switcher

A CLI helper for source-photo wallpaper actions alongside Noctalia v5.

## How It Works

The built-in Noctalia wallpaper widget is the core picker. `bin/walictl` keeps
the source-photo actions: it reads the current path with
`noctalia msg wallpaper-get`, derives photo metadata, saves favorites, and
opens source images for editing.

Source images are derived from `PXL_YYYYMMDD_*` filenames mapped to
`$BACKGROUND_IMG_DIR/<year>/<month>/<stem>.jpg`.

## Files

| Path | Purpose |
|---|---|
| `bin/walictl` | CLI helper (argparse) — current, save, edit, navigate |
| `tests/bin/test_walictl.py` | Tests |

## CLI Commands

```
walictl current --json     # wallpaper metadata (path, source, date)
walictl save-current       # append source path to $WALI_DIR/favorites.txt
walictl edit-current       # open source image in GIMP
walictl forward            # next wallpaper via noctalia msg wallpaper-set
walictl backward           # previous wallpaper via noctalia msg wallpaper-set
walictl random             # random wallpaper via noctalia msg wallpaper-random
```

`walictl random` uses `noctalia msg wallpaper-random`; `walictl forward` and
`walictl backward` use `noctalia msg wallpaper-set` with the selected sibling
path. There is no Wali Panel UI or plugin installation in v5.

## Environment Variables

- **`BACKGROUND_IMG_DIR`** — photo archive root (required for source path resolution)
- **`WALI_DIR`** — wali state directory (required for `save-current`)
