# Kitty Per-Window Project Colors

Dynamically assign terminal colors per-window based on the active project directory, with manual overrides via keybindings.

## Problem

Multiple terminal windows open side-by-side all look identical, making it hard to find the right one — especially when running multiple Claude Code / Codex CLI sessions across different projects.

## Solution

Two complementary color systems operating on individual kitty windows:

1. **Automatic** — dark themes assigned deterministically by project git root
2. **Manual** — light themes applied via `alt+1-9`, with `alt+0` to reset

Shell commands use `kitten @ set-colors -m "id:$KITTY_WINDOW_ID"`. Kitty keybindings use the `remote_control set-colors` action. Neither modifies config files nor affects other windows.

## Automatic System

### Detection

A zsh function `_kitty_project_colors` that:

1. Guards: exits early if not running inside kitty (`$KITTY_WINDOW_ID` unset)
2. Walks up from `$PWD` to find the nearest directory containing `.git`
3. If no git root found, applies default theme (noctalia) and returns
4. Checks pin file for an explicit project→theme mapping
5. If no pin, hashes the git root path to select a dark theme deterministically
6. Skips the `kitten @ set-colors` call if the theme is unchanged from the last application (cached in `$_KITTY_CURRENT_THEME`)
7. Calls `kitten @ set-colors -m "id:$KITTY_WINDOW_ID" <theme_path>`

Theme paths resolve to `$DOTFILES/kitty/themes/<filename>`. Some filenames contain spaces (e.g. `1984 Dark.conf`) and must be properly quoted in the implementation.

### Trigger Points

- `chpwd` hook — fires on every directory change
- Once at shell init (end of `shell/kitty`) — colors the window on first open

### Pin File

Located at `~/.config/kitty/project-themes.conf` (outside the dotfiles repo, since project paths are machine-specific). Format:

```
# Maps project git roots to theme filenames from kitty/themes/
# Lines starting with # are comments. Blank lines are ignored.
# Format: <absolute-path-to-git-root> = <theme-filename>
#
# Example:
# /mnt/ssd/Dropbox/mindful/natural-systems = Dracula.conf
# /mnt/ssd/Dropbox/seq-feats = Nord.conf
```

### Dark Theme Pool (automatic)

Defined as an explicit ordered array in `shell/kitty` (not by globbing the directory). Adding or removing themes will shift existing project→theme assignments; use the pin file to stabilize important projects.

| Index | Theme |
|-------|-------|
| 0 | 1984 Dark |
| 1 | Ayu Mirage |
| 2 | Dracula |
| 3 | Nord |
| 4 | One Dark |
| 5 | Pencil Dark |
| 6 | Tomorrow Night Eighties |

Excluded from the pool:
- `noctalia.conf` — serves as the default/fallback when not in a git project
- `wal.conf` — pywal-generated, contents change dynamically
- `color.conf` — One Dark variant, redundant with `One Dark.conf`

### Hashing

```
hash = md5sum of git root absolute path
index = hash (first 8 hex chars, interpreted as integer) mod theme_count
```

Deterministic: the same project always gets the same theme across sessions and machines (assuming the same theme pool ordering).

## Manual System

### Keybindings

Defined in `kitty/kitty.conf` using the `remote_control` action:

```conf
# project color manual overrides (light themes)
map alt+0 remote_control set-colors themes/noctalia.conf
map alt+1 remote_control set-colors themes/manual/solarized-light.conf
map alt+2 remote_control set-colors themes/manual/catppuccin-latte.conf
...
```

Paths are relative to the kitty config directory (`~/.config/kitty/`, which symlinks to the dotfiles `kitty/` dir). The `remote_control` action in keybindings targets the active window by default — no `--match` flag needed.

| Key | Theme | Background |
|-----|-------|------------|
| `alt+0` | Reset to noctalia default | #14140f |
| `alt+1` | Solarized Light | #fdf6e3 |
| `alt+2` | Catppuccin Latte | #eff1f5 |
| `alt+3` | Rosé Pine Dawn | #faf4ed |
| `alt+4` | GitHub Light | #ffffff |
| `alt+5` | Gruvbox Light | #fbf1c7 |
| `alt+6` | Everforest Light | #fdf6e3 |
| `alt+7` | Atom One Light | #f8f8f8 |
| `alt+8` | Ayu Light | #fafafa |
| `alt+9` | PaperColor Light | #eeeeee |

### alt+0 Behavior

`alt+0` applies noctalia as a safe default via `remote_control set-colors`. If the user then `cd`s anywhere, the `chpwd` hook re-applies the project theme. Main use case: "undo manual override."

### Relationship with `kit()`

The existing `kit()` function in `shell/functions` applies themes globally (no `--match` flag). It is left as-is — it serves a different purpose (global theme switch for all windows). The new system is per-window only.

## Files

| File | Action | Description |
|------|--------|-------------|
| `shell/kitty` | Create | Project color detection function, chpwd hook, init call |
| `zshrc` | Modify | Add `kitty` to the existing shell source loop (line ~181) |
| `kitty/kitty.conf` | Modify | Add `alt+0-9` keybindings |
| `kitty/themes/manual/*.conf` | Create | 9 light themes (already extracted) |
| `~/.config/kitty/project-themes.conf` | Create | Empty pin file with usage comments |

## Edge Cases

- **Not in kitty**: `$KITTY_WINDOW_ID` check, function is a no-op
- **No git root**: Applies noctalia default
- **Nested git repos**: Uses nearest `.git` ancestor (walks up from `$PWD`)
- **SSH sessions**: No `KITTY_WINDOW_ID`, function is a no-op
- **Inside a TUI (not at shell prompt)**: `chpwd` won't fire, but the last-applied theme persists. Manual overrides (`alt+1-9`) work regardless since they're kitty-level keybindings
- **New terminal in same project dir**: Init call at end of `shell/kitty` handles this
- **Pin file missing**: Treated as empty (no pins), auto-hash is used
- **cd within same project**: Cache check (`$_KITTY_CURRENT_THEME`) skips redundant `set-colors` calls
