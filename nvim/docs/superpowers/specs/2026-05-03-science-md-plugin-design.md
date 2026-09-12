# science-md.nvim — design spec

**Date:** 2026-05-03
**Status:** approved (brainstorm complete, implementation plan requested)
**Target install path:** `~/.config/nvim/plugins/science-md.nvim/`
**Motivating use case:** scanning dense Science-project synthesis docs like `~/d/natural-systems/doc/reports/synthesis.md`, where entity references (`task:t406`, `question:q100-...`, `[@Smith2024]`, `[UNVERIFIED]`) appear throughout frontmatter, prose, and link targets.

## Goal

Add a thin semantic-color overlay on top of existing markdown highlighting (vim-markdown + treesitter) so a small set of Science-project entity kinds and status markers stand out at a glance. The plugin must not fight the existing highlighters — it composes above them via Neovim's extmark API.

## Scope

**In scope (v1):**

- Highlighting 8 entity kinds and 2 status markers (table below) anywhere they appear in a markdown buffer: YAML frontmatter, prose, link labels, link targets.
- Project-aware activation (only fires inside Science projects via a `science.yaml` marker walk).
- Configurable per-kind highlights via a `setup()` table.
- Visible-window scanning with true debounced refresh on edits.

**Out of scope (v1, easy to add later):**

- Virtual text (e.g., showing task status next to `task:t001`).
- `gf`-style jump-to-definition on entity refs.
- Statusline integration.
- Completion source for entity refs.

## Entity table

| Kind | Pattern | Default highlight spec | Notes |
|---|---|---|---|
| `question:` | `\<question:[A-Za-z0-9][A-Za-z0-9._-]*` | `{ link = "@constant" }` | Inquiry / analytical |
| `task:` | `\<task:[A-Za-z0-9][A-Za-z0-9._-]*` | `{ link = "@function" }` | Action item |
| `hypothesis:` | `\<hypothesis:[A-Za-z0-9][A-Za-z0-9._-]*` | `{ link = "@type" }` | Theoretical claim |
| `interpretation:` | `\<interpretation:[A-Za-z0-9][A-Za-z0-9._-]*` | `{ link = "@string.special" }` | Analytical artifact |
| `discussion:` | `\<discussion:[A-Za-z0-9][A-Za-z0-9._-]*` | `{ link = "Comment", italic = true }` | Deliberately recedes |
| `topic:` | `\<topic:[A-Za-z0-9][A-Za-z0-9._-]*` | `{ link = "Number" }` | Broad theme |
| `report:` | `\<report:[A-Za-z0-9][A-Za-z0-9._-]*` | `{ link = "Constant" }` | Output / finding |
| `[@Cite]` | `\[-\=@[A-Za-z][A-Za-z0-9_-]*\%(\s*;\s*@\=[A-Za-z][A-Za-z0-9_-]*\)*\]` | `{ link = "Underlined", italic = true }` | Subtle, reference-like. Handles `[@A]`, `[-@A]`, and simple multi-cites. |
| `[UNVERIFIED]` | `\[UNVERIFIED\]` | `{ link = "DiagnosticWarn", bold = true }` | Caution flag |
| `[NEEDS CITATION]` | `\[NEEDS CITATION\]` | `{ link = "DiagnosticError", bold = true }` | Blocker flag |

**Pattern engine:** patterns above are written in Vim regex syntax and consumed via `vim.regex()` in `scanner.lua`. Use Vim word-boundary atoms such as `\<`; do not use PCRE-style `\b`, which is not a word-boundary assertion in Vim regex.

**Pattern design choice:** patterns are kind-prefix-agnostic about the id shape — they accept a word-like identifier after the colon (`[A-Za-z0-9][A-Za-z0-9._-]*`). This catches all current id schemes (`q01-foo`, `t400`, `2026-04-30-slug`) and is robust to new ones. False positives are essentially impossible because nothing else uses `kind:identifier` in markdown prose.

**Color philosophy:** defaults link to colorscheme highlight groups (not literal hex colors), so colors track tokyonight or any future colorscheme swap automatically. Users can override per kind with either `link = "@function"`, literal attributes such as `fg = "#abc123"`, or style attributes such as `bold = true` and `italic = true`.

**Highlight composition:** Neovim links do not merge cleanly with extra attributes, so `highlights.lua` must resolve configured links with `nvim_get_hl(0, { name = link, link = false })`, merge any explicit attributes, and define concrete `ScienceMd*` groups with `nvim_set_hl`. Plain link-only definitions may be used when there are no extra attributes.

**Visual weighting:** `discussion:` (based on `Comment`) and citations (based on `Underlined`) are deliberately quieter than the others — these are reference-like and shouldn't pull the eye away from the active research vocabulary.

## Activation

On `FileType markdown`, walk upward from the buffer's directory looking for a `science.yaml` marker. If found, activate for that buffer; cache the result per directory to avoid re-stat on every event.

```lua
local root = vim.fs.find('science.yaml', { upward = true, path = vim.fn.expand('%:p:h') })[1]
if root then activate(buf) end
```

**Why a marker file rather than a path allowlist:** path lists rot when projects move; the marker travels with the project. Symlinked checkouts (e.g., `~/d/natural-systems` → `/mnt/ssd/Dropbox/natural-systems`) work transparently because we resolve from whichever physical path nvim has open.

**Override knobs in `setup()`:**

- `enabled = "auto" | true | false` — `auto` is the marker walk; `true` forces on for every markdown buffer; `false` disables.
- `marker = "science.yaml"` — swap to a different sentinel for non-Science use.

## Architecture

**Strategy:** Lua module that scans buffer lines for entity-ref patterns and applies highlights via `nvim_buf_set_extmark`. Extmarks layer above both vim-syntax and treesitter, so this composes cleanly with vim-markdown and nvim-treesitter without ordering surprises.

### File layout

```
~/.config/nvim/plugins/science-md.nvim/
├── lua/
│   └── science-md/
│       ├── init.lua        -- public API: setup(opts), enable(buf), disable(buf)
│       ├── config.lua      -- default config table (entities, patterns, highlight specs)
│       ├── highlights.lua  -- defines ScienceMdQuestion, ScienceMdTask, ... groups
│       ├── scanner.lua     -- pattern matching -> list of {row, col_start, col_end, kind}
│       ├── render.lua      -- extmark application + namespace management
│       ├── project.lua     -- science.yaml marker walk + per-dir cache
│       └── scheduler.lua   -- per-buffer timers, visible range calculation, refresh lifecycle
├── tests/
│   ├── minimal_init.lua
│   ├── scanner_spec.lua
│   └── scheduler_spec.lua
└── README.md
```

**Lazy spec** (added to `~/.config/nvim/lua/user/plugins_always/plugins.lua`):

```lua
{ dir = vim.fn.stdpath('config') .. '/plugins/science-md.nvim',
  ft = 'markdown',
  config = function() require('science-md').setup() end },
```

### Module responsibilities

- **`init.lua`** — public surface. `setup(opts)` merges user config with defaults, registers highlight groups, and installs the `FileType markdown` autocmd. `enable(buf)` / `disable(buf)` are escape hatches for manual control.
- **`config.lua`** — default config table only. No logic. Holds entity definitions, debounce timing, and viewport flag.
- **`highlights.lua`** — defines `ScienceMdQuestion`, `ScienceMdTask`, … as named highlight groups. Link-only configs may be defined as links; configs with extra attrs resolve the linked group, merge attrs, and define concrete groups. Re-runs on `ColorScheme` autocmd so links survive theme swaps.
- **`scanner.lua`** — pure function: takes a list of lines + line offset, returns a list of `{row, col_start, col_end, kind}` matches. No nvim API calls, so it's unit-testable in isolation.
- **`render.lua`** — owns the extmark namespace. `apply(buf, matches)` clears the buffer's marks in the namespace and re-sets them. `clear(buf)` for teardown.
- **`project.lua`** — `is_science_project(path)` with per-directory cache. Cache keyed by directory, value is the resolved root path or `false`.
- **`scheduler.lua`** — owns refresh scheduling. Keeps per-buffer timer/generation state, computes all visible ranges for windows showing the buffer, merges overlapping ranges, and calls scanner/render.

### Update lifecycle

- One dedicated namespace (`vim.api.nvim_create_namespace('science_md')`) so we clear our marks atomically without touching anyone else's.
- Per-buffer autocmd group (`science_md_<bufnr>`) installed on activation, removed on `BufWipeout`.
- Triggers: `BufEnter`, `BufWritePost`, `TextChanged`, `TextChangedI`, `WinScrolled`.
- `TextChanged*` and `WinScrolled` are debounced with a real per-buffer `vim.loop.new_timer()` (or an equivalent generation-token guard) so repeated events coalesce into one refresh instead of queuing many delayed scans.
- Visible-window scan by default: find every window currently displaying the buffer, collect `w0` to `w$` plus a small margin (10 lines each side), merge overlapping ranges, scan those lines, and then clear/reapply the namespace for the buffer. This preserves highlights when the same buffer is visible in multiple split windows at different scroll positions.
- Full-file scan is available via `viewport_only = false` in opts.

## Public API

```lua
require('science-md').setup({
  enabled = "auto",            -- "auto" | true | false
  marker  = "science.yaml",
  debounce_ms = 150,
  viewport_only = true,       -- true = visible windows + margin
  viewport_margin = 10,
  entities = {                 -- override or add kinds
    task = { link = "@function" },
    -- custom_kind = { pattern = "\\<custom:[A-Za-z0-9_-]+", link = "Special" },
  },
})

require('science-md').enable(bufnr)   -- force-on for a buffer
require('science-md').disable(bufnr)  -- force-off for a buffer
```

**Config merge semantics:** user-provided `entities` keys merge into the defaults at the kind level. Setting `entities.task = { link = "Special" }` overrides only the link for tasks; everything else stays default. Adding a new key (e.g., `entities.synthesis`) requires the full `{ pattern = ..., link = ... }` shape.

## Testing

- Unit tests for `scanner.lua` over a small fixture buffer covering: frontmatter list items, inline prose refs, refs inside link targets `[label](task:t001)`, refs inside link labels, citations, both markers, and a deliberately tricky line with multiple kinds.
- Unit tests for citation variants: `[@Smith2024]`, `[-@Smith2024]`, and `[@Smith2024; @Jones2025]`.
- Unit tests for scheduler debounce behavior using two rapid refresh requests and verifying only the latest scan applies.
- Integration smoke test for split windows: open the same markdown buffer in two windows at different scroll positions and verify refresh preserves extmarks for both visible ranges.
- Manual smoke test: open `~/d/natural-systems/doc/reports/synthesis.md`, verify all 10 kinds highlight correctly and that scrolling stays smooth.
- Regression check: open a non-Science markdown file (e.g., a README outside any Science project), verify zero extmarks are applied.

## Risks and mitigations

- **Extmark performance on huge files.** Mitigated by visible-window scanning. If even that lags, fall back to incremental scanning (only the changed line range on `TextChanged`).
- **Split-window correctness.** Mitigated by scanning all visible windows for the buffer, not only the current window.
- **Debounce queue buildup.** Mitigated by one timer/generation state per buffer so stale scheduled refreshes cannot apply.
- **Pattern false positives in code blocks.** A markdown fenced code block could legitimately contain `task:t001` as illustrative text. v1 accepts this — code blocks are rare in research docs and the highlight would be informative rather than misleading. If it becomes a problem, add a treesitter-node check to skip captures inside `fenced_code_block` nodes.
- **Colorscheme swap races.** Mitigated by re-binding highlight links on the `ColorScheme` autocmd.

## Future extensions (informational)

- **Virtual text for task status:** read `tasks/active.md`, surface `[done]` / `[deferred]` next to `task:t001`.
- **`gf` jump-to-definition:** map kind prefix to file location convention (e.g., `question:q01-...` → `doc/questions/q01-....md`).
- **Hover preview:** floating window showing the title from the target file's frontmatter.
- **Completion source:** offer entity refs as nvim-cmp completions inside Science projects.

These are deliberately deferred from v1 to keep the plugin small and reviewable.
