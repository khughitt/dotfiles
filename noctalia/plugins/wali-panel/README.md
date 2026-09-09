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

- `walictl` on `PATH`, configured through `$XDG_CONFIG_HOME/wali/config.toml`.
- GIMP for the Edit button.

The panel is photo-first: the image sits in a bordered frame, the caption shows
the capture date and photo id with the favorite heart beside them, and the
action strip has Previous, Next, and Random on the left with Refresh, Edit, and
Copy as quiet ghost buttons on the right. Colors come from Noctalia's palette,
which it derives from the wallpaper.

Noctalia hot-reloads the `.luau` files. A change to `plugin.toml` (for example the
panel size) needs `noctalia msg plugins disable khughitt/wali-panel` followed by
`enable`.

The panel holds no state and derives nothing from paths. Navigation and Favorite
run a `walictl` command and then re-read `walictl current --json`. Refresh reads
the metadata directly, Copy copies the source path when present (otherwise the
current path), and Edit runs without a metadata refresh.
