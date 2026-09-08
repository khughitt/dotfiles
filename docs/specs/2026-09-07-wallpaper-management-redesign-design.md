# Wallpaper management redesign: walictl owns selection, favorites, and history

**Status:** Designed 2026-09-07; implemented on the `wallpaper-redesign`
branch. Live cutover remains pending Task 17. See
`docs/plans/2026-09-07-wallpaper-management-redesign.md`.

## Problem

Wallpaper behaviour is spread over five places with overlapping ownership:

- Noctalia v5 rotates wallpapers on a timer (alphabetical, every 15 minutes),
  derives the Material palette, renders templates, and fires hooks.
- `bin/walictl` reads the current path over IPC, derives the full-resolution
  original from a `PXL_YYYYMMDD_*` stem under `$BACKGROUND_IMG_DIR/YYYY/MM/`,
  appends that original's path to `$WALI_DIR/favorites.txt`, opens it in GIMP,
  and reimplements next/previous by listing directory siblings.
- `shell/wali` duplicates most of that in zsh (`wali_print`, `wali_save`,
  `wali_edit_current`, `wali_edit_fav`) alongside the ingestion functions that
  turn originals into 3440-pixel-wide copies.
- The `wali-panel` Noctalia plugin is a UI over `walictl`.
- `prism` receives every wallpaper change through the `wallpaper_changed` hook
  and activates a per-wallpaper glass context.

Concrete defects:

- `favorites.txt` is append-only: 685 lines, 41 duplicate occurrences, 2
  dangling. No
  command reads it except an fzf helper, and nothing can show whether the
  current wallpaper is already a favorite.
- Everything that resolves an original depends on two environment variables
  exported from the untracked `shell/private` file, so the panel only works on
  this host.
- Random is one-way. Nothing remembers what was shown, so there is no way back
  after a random pick.
- `walictl forward`/`backward` duplicate Noctalia's `wallpaper-next` and
  `wallpaper-previous`.
- The v4 `~/.config/noctalia/settings.json` is still on disk and still being
  rewritten by something, but v5 never reads it. Its `favorites` and
  `useOriginalImages` keys are inert.

## What Noctalia v5 provides (verified against the local source checkout)

- IPC: `wallpaper-get`, `wallpaper-set [connector] <path>`, `wallpaper-random`
  (a persisted non-repeating shuffle), `wallpaper-next`, `wallpaper-previous`,
  `panel-toggle wallpaper`.
- Native favorites as `[[wallpaper.favorite]]` in its state file, with a star
  per tile and a toolbar star in the built-in panel. Favorites pin to the top
  of the grid and may snapshot a theme preset. There is no IPC or plugin API to
  toggle them, and rotation never restricts itself to favorites.
- Hooks: `wallpaper_changed` (env `NOCTALIA_WALLPAPER_PATH`,
  `NOCTALIA_WALLPAPER_CONNECTOR`, fired once per changed connector) and
  `colors_changed` (no env).
- Plugin API 22+: `noctalia.wallpaperPath()`, `noctalia.setWallpaper()`,
  `noctalia.getSetting()`, `noctalia.pluginDataDir()`, file I/O, `ui.image`,
  `ui.slider`. No wallpaper-change callback, no way to extend the native
  wallpaper panel, no way to write shell config.
- No per-image adjustments and no processed-versus-original concept.

## Decisions

These were settled in the design conversation and are not open:

1. **Favorites are a signal, not just a bookmark.** They will nudge sampling
   weights toward liked time periods and feed mind6 (`dots-cdb659`). A later
   pipeline will compare Google Photos against the local library and pull
   photos from liked periods into the rotation.
2. **walictl owns timed rotation.** Noctalia's automation is disabled. A
   weighted sampler runs from a systemd user timer.
3. **Originals are optional.** Photos are keyed by stem. An optional
   `archive_root` resolves the original for Edit only; without it Edit opens
   the displayed file.
4. **Quick-edit (`dots-2aa60c`) is a follow-up.** This design reserves one
   optional edited-variant file per photo that the sampler prefers over the raw
   copy. Sliders, image processing, and variant garbage collection are out of
   scope.
5. **Noctalia's native favorites stay unused.** Mirroring the store into
   `[[wallpaper.favorite]]` so stars show in the native grid is a possible
   later spike, not part of this design.

## Architecture

One owner per concern:

| Concern | Owner |
|---|---|
| Display, palette, templates, hooks | Noctalia |
| Which photo is shown next, history, favorites, config | `walictl` |
| Timed rotation trigger | systemd user timer running `walictl next` |
| Recording changes made outside walictl | `wallpaper_changed` hook running `walictl observe` |
| Per-wallpaper glass deltas | prism (unchanged) |
| UI | `wali-panel` plugin, a thin view over `walictl` JSON |
| Consumer of favorites and current-photo metadata | mind6 (interface chosen in `dots-cdb659`) |

Data flow on a timer tick:

1. The timer runs `walictl next`.
2. `walictl` takes the history lock, reconciles history with what Noctalia
   reports as displayed, rescans the wallpaper directory, computes weights,
   samples a photo, calls `noctalia msg wallpaper-set <path>`, and on success
   records the new entry and releases the lock.
3. Noctalia displays it, regenerates the palette, renders templates, and fires
   `wallpaper_changed` once per connector.
4. The hook runs `prism context wallpaper "$NOCTALIA_WALLPAPER_PATH"` (as
   today) and `walictl observe`. Observe waits for the lock, asks Noctalia
   what is displayed, finds it already at the history cursor, and does
   nothing.

Data flow on a change made through Noctalia's own panel or IPC: steps 3 and 4
only. Observe finds that the default wallpaper path differs from the cursor entry and
appends an `observed` entry.

## Photo identity

A photo's id is its filename stem, for example `PXL_20210608_111152739`. The id
is the key everywhere: favorites, history, variants, and the mind6 interface.
Paths are derived from ids and the config, never stored as the primary key.

A stem matching `PXL_YYYYMMDD_*` yields a capture date. Any other stem is a
valid id with no date. Undated photos take part in sampling at base weight and
report `date: null`.

The library is the set of unique stems in the wallpaper directory, not the set
of files. The directory holds three stems with two extensions each (two
JPG/WebP pairs, one JPG/PNG pair), so sampling files would double-weight those
photos and make id-to-path resolution ambiguous. When a stem has several
files, the first of `.jpg`, `.jpeg`, `.png`, `.webp` wins. The same precedence
applies to variants.

## Files

### Config: `$XDG_CONFIG_HOME/wali/config.toml`

Per host. Tracked as `wali/<hostname>/config.toml` in the dotfiles and linked
by `setup.sh` in the graphical-config phase, the same way `prism/<hostname>/`
is linked to `$XDG_CONFIG_HOME/prism`.

```toml
wallpaper_dir = "~/d/linux/backgrounds/3440"
favorites_file = "~/d/linux/backgrounds/favorites.json"
archive_root = "/mnt/storage/backgrounds"   # optional
variants_dir = "~/d/linux/backgrounds/edits" # optional, reserved

[sampling]
exclude_recent = 200
favorite_boost = 1.0   # favorites weigh 1 + favorite_boost; 0 is neutral
period_boost = 3.0     # months weigh 1 + period_boost * favorite density
```

`wallpaper_dir` and `favorites_file` are required. A missing config file or a
missing required key is an error on every command. `~` is expanded; nothing
else is interpolated. The rotation interval lives in the systemd timer, not
here, so there is one place that defines it.

`exclude_recent` must be a non-negative integer. `favorite_boost` and
`period_boost` must be finite non-negative numbers. A computed total weight
that overflows to a non-finite value is an error.

This replaces `WALI_DIR` and `BACKGROUND_IMG_DIR` for everything at runtime.
The zsh ingestion functions (`wali_ingest`, `wali_reprocess`, `wali_rotate`,
`_wali_process_image`) keep reading those variables for now; moving them onto
the config is a follow-up.

Europa gets a config with `archive_root` omitted. Its wallpaper directory is
assumed to be the same synced path; confirm when linking.

### Favorites: `favorites.json` in the synced backgrounds directory

Shared across hosts through Dropbox and readable by mind6.

```json
{
  "version": 1,
  "favorites": {
    "PXL_20210608_111152739": { "added": "2026-09-07T15:54:36Z" }
  }
}
```

Keyed by id, so a duplicate is impossible by construction. Writes are atomic
(write to a sibling temp file, rename). On one host, `favorite` and
`import-favorites` hold an `fcntl` lock on
`$XDG_STATE_HOME/wali/favorites.lock` across the whole read-modify-write, so
two concurrent additions cannot overwrite each other. The lock file lives in
state, not next to `favorites.json`, so Dropbox never syncs it. Concurrent
favoriting from two hosts at the same moment can still produce a Dropbox
conflict copy; that is accepted.

### History: `$XDG_STATE_HOME/wali/history.json`

Per host, never synced.

```json
{
  "version": 1,
  "cursor": 0,
  "entries": [
    { "ts": "2026-09-07T15:00:00Z", "id": "PXL_20210608_111152739",
      "path": "/…/3440/PXL_20210608_111152739.jpg", "origin": "next" }
  ]
}
```

`origin` is one of `next`, `random`, `observed`. Cursor moves (`previous`, and
`next` while behind the end) create no entry. Entries are capped at 1000; the
oldest are dropped from the front and the cursor shifts with them. Every
read-modify-write holds an `fcntl` lock on a sibling lock file, because the
timer, the panel, and the hook can run at the same time.
Waiting for the lock is bounded at 10 seconds, after which the command fails.

A missing history file or directory is the empty state and is created on
first write. A file that exists but does not parse, or carries an unknown
`version`, is an error; nothing overwrites it.

### Variants (reserved): `<variants_dir>/<id>.<ext>`

If `variants_dir` is set and a file named by the id exists there, every set
uses that file instead of the raw copy. `current --json` reports
`variant_path`. Which extension wins when several exist is defined as: the
first of `.jpg`, `.jpeg`, `.png`, `.webp`. Nothing in this design creates
variants.

## Sampling

`walictl next` (when sampling) and `walictl random`:

1. List the wallpaper directory, non-recursively, filtering to `.jpg`,
   `.jpeg`, `.png`, `.webp`, and collapse to unique stems by the extension
   precedence above. No index file; the scan is a few milliseconds for 7.5k
   entries and cannot go stale.
2. Weight each photo:
   - base weight 1;
   - multiply by `1 + favorite_boost` if the id is a favorite;
   - bucket dated photos by capture month; a bucket's density is favorites in
     the bucket divided by photos in the bucket; multiply by
     `1 + period_boost * density`; undated photos skip this step;
   - set weight 0 for any id among the `exclude_recent` history entries at or
     before the cursor.
3. Sample one photo proportionally to weight. If every weight is 0 (library
   smaller than `exclude_recent`), fall back to uniform over the whole library
   and say so on stderr; that is the one designed fallback in the sampler.
4. Resolve the path (variant if present, else the raw copy) and hand it to the
   navigation step below.

With `favorite_boost = 0` and `period_boost = 0` this reduces to non-repeating
uniform random. The RNG is injectable so tests are deterministic.

## History semantics

History behaves like a browser:

- `next` with the cursor at the last entry samples and appends. With the
  cursor behind the end it moves the cursor forward one and sets that entry.
- `previous` moves the cursor back one and sets that entry. At the front it
  fails with a message.
- `random` always samples and appends, even mid-history. Entries after the
  cursor are discarded first, as a browser discards forward history on a new
  navigation.

Every mutating command (`next`, `previous`, `random`, `observe`) runs the same
sequence under the history lock:

1. **Reconcile.** Ask Noctalia for the configured default wallpaper with a
   bare `noctalia msg wallpaper-get` and compare its real path with the entry
   at the cursor. If history is empty or the paths differ, discard entries
   after the cursor and append an `observed` entry for that wallpaper. This
   is what makes a fresh history usable (the wallpaper already on screen
   becomes the first entry, so `previous` after the first `random` restores
   it) and what records changes made through Noctalia's own panel or IPC.
2. **Navigate.** For `observe`, stop here. Otherwise pick the target entry or
   sample a new photo, then call `wallpaper-set` with no connector.
3. **Commit.** Only after `wallpaper-set` returns ok, write the new entry and
   cursor. A rejected set leaves the file exactly as reconcile left it, and
   the command exits non-zero with Noctalia's error.

History records selections Noctalia accepted, not confirmed displays.
Noctalia's set handler answers ok once the path is validated and applied to
its configuration; if the image then fails to decode it logs a warning and
keeps the previous texture, and `wallpaper-get` still reports the new path.
No IPC exposes what is on screen, so walictl cannot tell those apart and does
not try.

Only all-monitor wallpapers are supported. Both walictl and the reconcile
query address the default wallpaper, which is what a connector-less
`wallpaper-set` writes and what Noctalia's automation and the existing setup
use. A wallpaper chosen for a single monitor in Noctalia's own panel changes
that monitor's override, not the default, so reconcile does not see it and
history does not record it. `NOCTALIA_WALLPAPER_CONNECTOR` is ignored for the
same reason.

`observe` takes no argument. The hook's `NOCTALIA_WALLPAPER_PATH` is ignored
on purpose: Noctalia's answer to `wallpaper-get` at the moment observe runs is
the truth, so a hook firing late (after a `previous` has already moved on)
finds the cursor already matching the display and does nothing, and firing
once per connector is idempotent for the same reason. Because the lock is
held across `wallpaper-set`, the hook fired by walictl's own set blocks until
the commit is written and then sees a matching cursor.

## CLI

`walictl` stays a single Python file in `bin/`, argparse, standard library
only, tested with pytest. Commands:

```
walictl current --json
walictl next
walictl previous
walictl random
walictl favorite [--add | --remove] [<id>]
walictl favorites --json
walictl neighbors --json [--count N]
walictl edit
walictl observe
walictl import-favorites <favorites.txt>
```

`current --json` returns:

```json
{
  "ok": true,
  "id": "PXL_20210608_111152739",
  "date": "2021-06-08",
  "display_date": "June 8, 2021",
  "path": "/…/3440/PXL_20210608_111152739.jpg",
  "source_path": "/…/backgrounds/2021/06/PXL_20210608_111152739.jpg",
  "variant_path": null,
  "favorite": true,
  "history": { "cursor": 41, "length": 42 }
}
```

`source_path` is null when `archive_root` is unset or the original does not
exist. `date` and `display_date` are null for undated photos.

`favorite` with no flag toggles the current photo and prints the new state.
`--add` and `--remove` are idempotent and take an optional id. `favorites
--json` lists every favorite with its resolved display path, source path, and
whether the display file exists. `neighbors --json` lists the `N` photos on
each side of the current one ordered by capture date, for mind6; `--count`
must be non-negative.

`edit` opens GIMP on `source_path` when present, else on `path`, and prints
which it used. `import-favorites` maps every line of the old file to an id,
counts duplicates, lists dangling entries, and writes `favorites.json`; it
refuses to overwrite an existing `favorites.json` unless `--force`.

Runtime failures exit non-zero with one line on stderr; argparse retains its
standard usage output for invalid command lines. There are exactly two designed
fallbacks: Edit degrading to the display file, and the all-zero-weight uniform
fallback above. Missing config, unreadable state, an unknown id, or a Noctalia
IPC failure are errors.

## Panel

Plugin id, entry ids, and `plugin_api` stay the same, so Noctalia's bar config
is untouched. Layout stays: preview, metadata, two button rows.

- Metadata: capture date, favorite state, source path when present, variant
  path when present.
- Row one: Refresh, Previous, Next, Random.
- Row two: Favorite (filled heart when favorited, hollow otherwise; toggles),
  Edit, Copy (copies `source_path` if present, else `path`).
- Every action runs a `walictl` command through `noctalia.runAsync`. After
  Previous, Next, Random, and Favorite the panel re-runs `current --json`.
  Edit and Copy do not.
- `logic.luau` keeps its command table and JSON validation, extended to the new
  fields. `shell.luau` is unchanged.

The panel holds no state beyond the last `current --json` payload and a busy
flag.

## Noctalia config

In `noctalia/config.toml`:

- `[wallpaper.automation] enabled = false`. `interval_seconds` and `order` are
  removed; the timer defines the interval.
- `wallpaper_changed` becomes a two-element array: the existing prism command
  and `~/bin/walictl observe`.

`tests/setup_and_health.zsh` asserts the automation block and is updated to
the new shape.

## systemd

`systemd/user/wali-rotate.timer` and `wali-rotate.service`, linked by
`setup_systemd_user_units` alongside the existing dropbox-ignore-flux units.
The service is `Type=oneshot` running `walictl next`. The timer sets
`OnActiveSec=15min` for the first trigger after the timer starts and
`OnUnitActiveSec=15min` for every later one; `OnUnitActiveSec` alone is
relative to the service's previous run and would never fire the first time.
`AccuracySec=1min`, not `Persistent`, since a missed tick should not fire a
wallpaper change on login. Enabling follows the
existing `--enable-user-timers` flag.

## Migration and cleanup

In order:

1. Land `walictl`, its tests, the config layout, and the setup.sh link.
2. Run `walictl import-favorites` on this host and verify the report against
   the measured state of the file: 685 lines, 644 unique stems, 41 duplicate
   occurrences, 2 dangling original paths. One stem
   (`PXL_20210919_170859013`) has no file in the wallpaper directory; it is
   imported anyway, since favorites are ids, and `favorites --json` reports it
   as missing. Keep `favorites.txt` until the panel shows favorite state
   correctly, then delete it in its own commit.
3. Switch Noctalia automation off, add the observe hook, add the timer.
4. Update the panel.
5. Trim `shell/wali`: the `wali` alias becomes `walictl random`; `wali_print`,
   `wali_save`, `wali_edit_current`, and `wali_edit_fav` (including its dead
   X11 path repair) are removed; `wali_search` becomes an fzf front-end that
   pipes the chosen file's stem into `walictl favorite --add`. `wali_rotate`
   calls `wali_print` today for the source path and `_wali_current_wallpaper`
   for the display path; it is changed in the same commit to read both from
   `walictl current --json` through `jq` (already used by the shell
   functions), and to fail when `source_path` is null. Ingestion, processing,
   `wali_pal`, and `wali_reload` are unchanged. `tests/wali.zsh` is adjusted
   where it references removed functions.
6. Rewrite `noctalia/noctalia-wallpaper-switcher.md` for the new split and add
   the observe line to the hook paragraph in `noctalia/noctalia.md`.

Filed as follow-up tasks, not done here: find what still rewrites the v4
`settings.json`; move the ingestion functions off the environment variables;
the native-star mirror spike; quick-edit on top of the variant slot; the mind6
interface choice.

## Testing

pytest, `tests/bin/test_walictl.py`, with Noctalia IPC and GIMP launching
injected so no test calls the shell:

- config loading: missing file, missing required key, tilde expansion,
  optional keys absent;
- id and date parsing for PXL, partial PXL, and non-PXL stems;
- library scan collapses duplicate stems by extension precedence, for both
  the wallpaper directory and the variants directory;
- favorites store: two concurrent additions both land (lock held across the
  read-modify-write), round-trip, toggle twice returns to the start, `--add`
  twice is one entry, atomic write leaves no temp file;
- sampler: seeded determinism, zero boosts give uniform, favorite and period
  boosts change the weights as specified, `exclude_recent` zeroes the right
  ids, all-zero fallback;
- history: next/previous/random/observe cursor semantics, forward history
  discard, cap and cursor shift, lock acquired, missing file is empty state,
  corrupt file is an error;
- reconcile: empty history is seeded from the displayed wallpaper so
  `previous` after the first `random` restores it; a stale observe (display
  already moved on) is a no-op; a repeated observe is a no-op; an external
  change appends `observed`;
- a failed `wallpaper-set` leaves history and cursor as reconcile left them
  and exits non-zero;
- `current --json` field contract, including nulls;
- `neighbors` ordering across month boundaries;
- edit resolution with and without `archive_root`;
- import: dedupe count, dangling list, refuse-to-overwrite.

`plugin_test.lua` covers the panel command table, JSON validation of the new
payload, and which actions trigger a refresh.

Manual verification on this host, recorded on the task before it is closed:
the timer fires and changes the wallpaper; Previous after Random restores the
prior wallpaper; a change made from Noctalia's own panel appears in history as
`observed`; the panel heart matches `favorites.json`.
