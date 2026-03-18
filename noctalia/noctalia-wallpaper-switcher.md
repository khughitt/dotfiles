# Noctalia Wallpaper Switcher

A Noctalia bar plugin + CLI helper for previewing and managing the current wallpaper.

## How It Works

The Noctalia plugin (`wali-panel`) adds a wallpaper icon to the bar. Clicking it opens a panel that shows a preview of the current wallpaper, its date, and action buttons. All logic lives in `bin/walictl`; the QML plugin is a thin presentation layer that calls it via `Process`.

Wallpaper paths are resolved by querying the Noctalia/Quickshell IPC (`qs -c noctalia-shell ipc call wallpaper get all`). Source images are derived from `PXL_YYYYMMDD_*` filenames mapped to `$BACKGROUND_IMG_DIR/<year>/<month>/<stem>.jpg`.

## Files

| Path | Purpose |
|---|---|
| `bin/walictl` | CLI helper (argparse) — current, save, edit, navigate |
| `noctalia/plugins/wali-panel/manifest.json` | Plugin manifest |
| `noctalia/plugins/wali-panel/BarWidget.qml` | Bar icon button |
| `noctalia/plugins/wali-panel/Panel.qml` | Panel UI (preview, metadata, actions) |
| `tests/bin/test_walictl.py` | Tests |

## CLI Commands

```
walictl current --json     # wallpaper metadata (path, source, date)
walictl save-current       # append source path to $WALI_DIR/favorites.txt
walictl edit-current       # open source image in GIMP
walictl forward            # next wallpaper in directory
walictl backward           # previous wallpaper in directory
walictl random             # random wallpaper via IPC
```

## Panel Actions

| Button | Action |
|---|---|
| Previous / Next | Navigate wallpapers in the current directory |
| Random | Set a random wallpaper |
| Save | Save to favorites |
| Edit | Open in GIMP |
| Copy | Copy source path to clipboard (via `wl-copy`) |

## Environment Variables

- **`BACKGROUND_IMG_DIR`** — photo archive root (required for source path resolution)
- **`WALI_DIR`** — wali state directory (required for `save-current`)

## Installation

The plugin directory is symlinked into `~/.config/noctalia/plugins/wali-panel`. Enable the plugin in Noctalia's plugin settings if not already active.
