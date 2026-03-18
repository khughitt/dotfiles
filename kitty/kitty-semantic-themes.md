# Kitty Semantic Themes

Automatic per-project terminal color themes based on semantic similarity between git projects.

## How It Works

Projects listed in `kitty/semantic-projects.txt` are analyzed offline: docs, metadata, and sampled code are embedded via TF-IDF + SVD, then clustered (agglomerative, ~7 groups). Each cluster maps to a curated attractor theme chosen from `kitty/themes/` for readability and visual diversity. The result is cached in `kitty/semantic-themes.json`.

At runtime, `shell/kitty` hooks into `chpwd` to detect the nearest git root and delegates to `bin/kitty-theme apply`, which looks up the cached theme and animates a short palette fade (~240ms, 12 steps, cubic ease) via kitty remote control.

## Files

| Path | Purpose |
|---|---|
| `bin/kitty-theme` | CLI (click) — recompute, apply, override, explain |
| `shell/kitty` | Zsh chpwd hook — detects git root, calls `kitty-theme apply` |
| `kitty/semantic-projects.txt` | Project registry (one root per line) |
| `kitty/semantic-themes.json` | Precomputed cache (embeddings, clusters, theme assignments) |
| `kitty/themes/` | Theme conf files (attractors + manual overrides) |
| `kitty/theme-candidates/` | Candidate themes for attractor selection |
| `kitty/kitty.conf` | Keybindings for manual overrides |
| `tests/bin/test_kitty_theme.py` | Tests (53 cases) |

## CLI Commands

```
kitty-theme projects validate          # validate registry paths
kitty-theme projects list              # show cached assignments
kitty-theme projects diagnose          # confidence diagnostics

kitty-theme apply <path>               # resolve + animate theme for a project
kitty-theme themes diagnose            # score/rank candidate themes

kitty-theme override set --theme=X     # manual override (--mode=temporary|sticky)
kitty-theme override reset             # clear override, return to semantic assignment

kitty-theme recompute                  # rebuild semantic cache
kitty-theme resolve <path>             # print resolved theme name
kitty-theme explain                    # show effective assignment + cluster details
```

## Manual Overrides

Keybindings in `kitty.conf`:

- **alt+1..9** — temporary override (clears on next project change)
- **ctrl+alt+1..9** — sticky override (persists until `alt+0` reset)
- **alt+0** — reset to semantic assignment

## Adding Projects

1. Add the project root to `kitty/semantic-projects.txt`
2. Run `kitty-theme recompute` to rebuild the cache

## Fallback Behavior

- Unknown git roots or low-confidence projects get the neutral fallback theme (`noctalia.conf`)
- If the cache is missing or corrupt, the fallback theme is applied directly
- If animation fails, the final target theme is applied without transition
