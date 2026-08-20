# Wali Panel

A native Noctalia v5 plugin for previewing and managing Wali's current wallpaper.

## Entries

- Plugin API: `22`
- Widget: `khughitt/wali-panel:widget`
- Panel: `khughitt/wali-panel:panel`

Add the widget to a Noctalia bar and click its wallpaper glyph, or open the panel with:

```sh
noctalia msg panel-toggle khughitt/wali-panel:panel
```

## Requirements

- `walictl` must be available on `PATH`.
- `BACKGROUND_IMG_DIR` must name the photo archive root used to derive source paths.
- `WALI_DIR` must name Wali's state directory containing `favorites.txt`.
- GIMP is required by `walictl edit-current`.

The panel has no plugin settings. Wali and `walictl` own wallpaper discovery, navigation, saving, and editing.
