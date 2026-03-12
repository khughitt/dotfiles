# Wali Noctalia Plugin Design

## Goal

Add a small Noctalia shell plugin that exposes the current wallpaper workflow from `shell/wali` in the top bar.

The plugin should:

- show a wallpaper icon in the bar
- open an anchored panel when clicked
- display a preview of the current wallpaper at roughly 512px
- display a parsed image date when the filename contains one
- provide actions to save the current wallpaper to favorites and open it in GIMP

The plugin is intentionally a thin UI layer. Wallpaper discovery and actions should live in a reusable helper CLI rather than in QML.

## Scope

### Included in v1

- current wallpaper metadata lookup
- preview of the current wallpaper
- parsed date display when available
- `Save to favorites`
- `Edit in GIMP`
- local plugin installation from this dotfiles repo

### Explicitly excluded from v1

- favorites browser or picker
- re-implementing `wali_edit_fav`
- refactoring existing `shell/wali` functions to call the new helper
- managing all of `~/.config/noctalia` from the dotfiles repo

## Main Decisions

### 1. Thin plugin over a reusable helper

The Noctalia plugin will not parse wallpaper paths or mutate favorites directly. It will call a standalone helper script named `walictl`.

Why:

- Noctalia QML stays focused on presentation
- wallpaper logic remains testable outside the shell
- the helper can later be reused by shell functions if desired
- failures stay explicit instead of being hidden in panel bindings

### 2. Store only the plugin subtree in dotfiles

The plugin files should live in this repo, but only the plugin directory should be symlinked into `~/.config/noctalia/plugins/`.

Why:

- Noctalia stores machine-local state in `~/.config/noctalia/plugins.json`
- symlinking the entire Noctalia config directory would risk clobbering local settings
- a single plugin symlink fits the existing dotfiles install model without taking ownership of unrelated Noctalia files

### 3. Keep existing shell helpers unchanged in v1

`wali_print`, `wali_save`, and the rest remain as they are for now. The plugin uses `walictl`; the shell layer is not refactored in the first pass.

Why:

- avoids a cross-cutting behavior change during the initial plugin build
- keeps the implementation narrowly scoped
- preserves the current shell workflow exactly

## Proposed File Layout

```text
bin/
  walictl

noctalia/
  plugins/
    wali-panel/
      manifest.json
      BarWidget.qml
      Panel.qml

docs/
  plans/
    2026-03-12-wali-noctalia-plugin-design.md
    2026-03-12-wali-noctalia-plugin.md
```

If the helper is implemented in Python, tests and minimal `uv` metadata should also be added:

```text
tests/
  bin/
    test_walictl.py

pyproject.toml
```

## Architecture

### Helper CLI: `walictl`

`walictl` is the stable boundary between wallpaper logic and the UI.

Initial subcommands:

- `walictl current --json`
- `walictl save-current`
- `walictl edit-current`

`current --json` should return:

```json
{
  "ok": true,
  "backend": "noctalia",
  "current_wallpaper_path": "/path/to/processed/or/current/image.jpg",
  "source_wallpaper_path": "/path/to/original/source.jpg",
  "filename": "PXL_20240520_023703962.jpg",
  "parsed_date": "2024-05-20",
  "display_date": "May 20, 2024"
}
```

On failure it should return a non-zero exit code and a concise error message on stderr. It should not silently guess alternate locations beyond the explicitly supported resolution flow.

#### Resolution flow

For Noctalia-backed sessions, the helper should query:

`qs -c noctalia-shell ipc call wallpaper get all`

The helper should then derive the source image path from the filename and the existing wallpaper storage convention already assumed by `shell/wali`:

`$BACKGROUND_IMG_DIR/<year>/<month>/<stem>.jpg`

The date shown in the UI should be extracted from filenames like `PXL_20240520_023703962.jpg`. If parsing fails, the helper should return `null` for the parsed date instead of inventing a fallback.

### Noctalia plugin

The plugin should provide:

- a bar widget entrypoint with an icon button
- a panel entrypoint anchored near the button

The bar widget behavior:

- render a wallpaper-style icon
- call `pluginApi.togglePanel(screen, root)` on click

The panel behavior:

- run `walictl current --json` when opened
- render the current image preview using the returned source path
- show the formatted date when present
- render `Save to favorites` and `Edit in GIMP` buttons
- call `walictl save-current` and `walictl edit-current` for those actions

The panel should be read-mostly. It does not need its own long-lived wallpaper cache.

## UX Details

### Panel content

The panel should stay simple:

- preview image centered and scaled to about 512px
- one or two compact metadata rows
- two action buttons

Recommended metadata:

- formatted date
- source path, truncated in the middle if long

### Success and failure states

Success:

- `save-current` shows a lightweight success message or toast
- `edit-current` launches GIMP and keeps the panel open or unchanged

Failure:

- if wallpaper resolution fails, show an explicit empty/error panel state
- if date parsing fails, omit the date row or show a neutral placeholder
- if save or edit fails, show the stderr message or a concise plugin-side error string

The UI must fail loudly enough for the problem to be obvious. No hidden fallback logic should be embedded in QML.

## Installation Model

The repo should own the plugin source directory:

- `noctalia/plugins/wali-panel`

`setup.sh` should be updated to:

- create `~/.config/noctalia/plugins` if needed
- symlink `noctalia/plugins/wali-panel` into `~/.config/noctalia/plugins/wali-panel`

Noctalia's plugin registry should then discover the plugin from disk. The plugin will appear installed; if it has no prior state, Noctalia will create a disabled entry automatically. Enabling the plugin through Noctalia should then add its bar widget.

## Testing Strategy

### Helper tests

The helper is the main unit-test target.

Test cases:

- successful JSON output for a valid Noctalia wallpaper path
- date parsing from `PXL_YYYYMMDD_*`
- filenames without parseable dates
- failure when the wallpaper query returns nothing
- `save-current` appends exactly one line to the favorites file
- `edit-current` launches the configured command with the resolved source path

These tests should mock subprocess calls and environment variables rather than depending on a live Noctalia session.

### Plugin verification

The QML side can be verified manually:

- plugin is discovered by Noctalia
- enabling the plugin adds the bar widget
- clicking the widget opens the panel
- preview and metadata render for a real wallpaper
- both actions call the helper successfully
- failure state is visible when the helper returns an error

## Risks

### Helper path assumptions

The source path reconstruction assumes the current filename still maps cleanly to the original photo archive. If your processing pipeline starts producing names that no longer preserve the original `PXL_*` stem, `walictl current` will need an explicit mapping layer.

### External command availability

The plugin depends on:

- `qs`
- `gimp`

`walictl` should fail clearly if either command is unavailable.

### Plugin enablement is still local state

The plugin files can be managed by dotfiles, but whether the plugin is enabled in Noctalia remains local machine state in `plugins.json`. That is expected and should not be versioned.
