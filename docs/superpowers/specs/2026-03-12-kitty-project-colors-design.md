# Kitty Per-Window Project Colors

Dynamically assign terminal colors per-window based on the active project directory, with manual overrides via keybindings.

## Problem

Multiple terminal windows open side-by-side all look identical, making it hard to find the right one — especially when running multiple Claude Code / Codex CLI sessions across different projects.

## Solution

Two complementary color systems operating on individual kitty windows:

1. **Automatic** — dark themes assigned deterministically by project git root
2. **Manual** — light themes applied via `alt+1-9`, with `alt+0` to reset

Both use `kitty @ set-colors` scoped to `KITTY_WINDOW_ID`. Neither modifies config files nor affects other windows.

## Automatic System

### Detection

A zsh function `_kitty_project_colors` that:

1. Guards: exits early if not running inside kitty (`$KITTY_WINDOW_ID` unset)
2. Walks up from `$PWD` to find the nearest directory containing `.git`
3. If no git root found, applies default theme (noctalia) and returns
4. Checks pin file for an explicit project→theme mapping
5. If no pin, hashes the git root path to select a dark theme deterministically
6. Calls `kitten @ set-colors -m "id:$KITTY_WINDOW_ID" <theme_path>`

### Trigger Points

- `chpwd` hook — fires on every directory change
- Once at shell init (end of `shell/kitty`) — colors the window on first open

### Pin File

Located at `~/.config/kitty/project-themes.conf`. Format:

```
# Maps project git roots to theme filenames from kitty/themes/
# Lines starting with # are comments. Blank lines are ignored.
# Format: <absolute-path-to-git-root> = <theme-filename>
#
# Example:
# /mnt/ssd/Dropbox/mindful/natural-systems = Dracula.conf
# /mnt/ssd/Dropbox/seq-feats = Nord.conf
```

Theme filenames are resolved relative to the `kitty/themes/` directory in the dotfiles.

### Dark Theme Pool (automatic)

Existing themes in `kitty/themes/`:

| Index | Theme |
|-------|-------|
| 0 | 1984 Dark |
| 1 | Ayu Mirage |
| 2 | Dracula |
| 3 | Nord |
| 4 | One Dark |
| 5 | Pencil Dark |
| 6 | Tomorrow Night Eighties |

Noctalia is excluded from the pool — it serves as the default/fallback when not in a git project.

### Hashing

```
hash = md5sum of git root absolute path
index = hash (first 8 hex chars, interpreted as integer) mod theme_count
```

This is deterministic: the same project always gets the same theme across sessions and machines (assuming the same theme pool ordering).

## Manual System

### Keybindings

Defined in `kitty/kitty.conf`:

| Key | Theme | Background |
|-----|-------|------------|
| `alt+0` | Reset (re-run auto-detection) | — |
| `alt+1` | Solarized Light | #fdf6e3 |
| `alt+2` | Catppuccin Latte | #eff1f5 |
| `alt+3` | Rosé Pine Dawn | #faf4ed |
| `alt+4` | GitHub Light | #ffffff |
| `alt+5` | Gruvbox Light | #fbf1c7 |
| `alt+6` | Everforest Light | #fdf6e3 |
| `alt+7` | Atom One Light | #f8f8f8 |
| `alt+8` | Ayu Light | #fafafa |
| `alt+9` | PaperColor Light | #eeeeee |

Light themes are stored in `kitty/themes/manual/`.

`alt+0` sends an escape sequence or shell command that re-runs `_kitty_project_colors` to restore the auto-detected theme. Implementation: `remote_control set-colors` pointing to a small script/kitten, or a keybinding that sends a shell command.

### alt+0 Implementation

`alt+0` maps to a kitty `remote_control` call that loads the noctalia default, combined with sending a signal or shell command to re-trigger project detection. Simplest approach: map `alt+0` to `send_text` that runs `_kitty_project_colors\n` in the shell. However, this only works when a shell prompt is active, not inside a TUI.

Better approach: `alt+0` applies noctalia as a safe default via `remote_control set-colors`. If the user then `cd`s anywhere, the `chpwd` hook will re-apply the project theme. This is good enough — the main use case is "undo manual override."

## Files

| File | Action | Description |
|------|--------|-------------|
| `shell/kitty` | Create | Project color detection function, chpwd hook, init call |
| `zshrc` | Modify | Add `source "$DOTFILES/shell/kitty"` |
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
