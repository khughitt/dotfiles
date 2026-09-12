# science-md.nvim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local Neovim plugin that highlights Science-project markdown entity references and status markers without replacing existing markdown highlighting.

**Architecture:** Package the plugin as a real local lazy.nvim plugin rooted at `~/.config/nvim/plugins/science-md.nvim/`, with runtime Lua modules under `lua/science-md/`. Keep scanning pure and testable, keep rendering isolated to one extmark namespace, and keep activation/scheduling separate from pattern logic.

**Tech Stack:** Neovim Lua, lazy.nvim local plugin loading, Vim regex via `vim.regex()`, extmarks via `nvim_buf_set_extmark`, headless Neovim test scripts.

---

## File Structure

- Create: `~/.config/nvim/plugins/science-md.nvim/lua/science-md/config.lua`
  Default options, entity regexes, and highlight specs.
- Create: `~/.config/nvim/plugins/science-md.nvim/lua/science-md/scanner.lua`
  Pure line scanner returning `{ row, col_start, col_end, kind }` matches.
- Create: `~/.config/nvim/plugins/science-md.nvim/lua/science-md/render.lua`
  Extmark namespace owner with `apply(buf, matches)` and `clear(buf)`.
- Create: `~/.config/nvim/plugins/science-md.nvim/lua/science-md/highlights.lua`
  Highlight group definitions with link resolution plus merged style attrs.
- Create: `~/.config/nvim/plugins/science-md.nvim/lua/science-md/project.lua`
  Marker walk and per-directory project cache.
- Create: `~/.config/nvim/plugins/science-md.nvim/lua/science-md/scheduler.lua`
  Per-buffer refresh state, timer debounce, visible range collection, range merging.
- Create: `~/.config/nvim/plugins/science-md.nvim/lua/science-md/init.lua`
  Public API and autocmd wiring.
- Create: `~/.config/nvim/plugins/science-md.nvim/tests/minimal_init.lua`
  Adds plugin root to `runtimepath` for headless tests.
- Create: `~/.config/nvim/plugins/science-md.nvim/tests/scanner_spec.lua`
  Scanner coverage for all entity kinds, markers, citations, and offsets.
- Create: `~/.config/nvim/plugins/science-md.nvim/tests/scheduler_spec.lua`
  Scheduler coverage for range merging and debounce behavior.
- Create: `~/.config/nvim/plugins/science-md.nvim/README.md`
  Usage, config, test commands, and design constraints.
- Modify: `~/.config/nvim/lua/user/plugins_always/plugins.lua`
  Add the lazy.nvim local plugin spec.

## Task 1: Scaffold Plugin and Scanner Tests

**Files:**
- Create: `~/.config/nvim/plugins/science-md.nvim/tests/minimal_init.lua`
- Create: `~/.config/nvim/plugins/science-md.nvim/tests/scanner_spec.lua`
- Create: `~/.config/nvim/plugins/science-md.nvim/lua/science-md/config.lua`

- [ ] **Step 1: Create plugin directories**

Run:

```bash
mkdir -p ~/.config/nvim/plugins/science-md.nvim/lua/science-md ~/.config/nvim/plugins/science-md.nvim/tests
```

Expected: directories exist with no output.

- [ ] **Step 2: Add the headless test bootstrap**

Write `~/.config/nvim/plugins/science-md.nvim/tests/minimal_init.lua`:

```lua
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.runtimepath:prepend(plugin_root)
```

- [ ] **Step 3: Add scanner tests before implementation**

Write `~/.config/nvim/plugins/science-md.nvim/tests/scanner_spec.lua`:

```lua
local scanner = require('science-md.scanner')
local config = require('science-md.config')

local function assert_eq(actual, expected, label)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', label, vim.inspect(expected), vim.inspect(actual)))
  end
end

local function compact(matches)
  local out = {}
  for _, match in ipairs(matches) do
    table.insert(out, {
      kind = match.kind,
      text = match.text,
      row = match.row,
      col_start = match.col_start,
      col_end = match.col_end,
    })
  end
  return out
end

local lines = {
  '---',
  'questions: [question:q01-model-granularity, task:t406]',
  'Inline hypothesis:h01-growth and interpretation:2026-04-30-slug.',
  '[task label task:t001](question:q02-links) plus topic:lichen and report:r01',
  'discussion:2026-05-03-science-md-plugin-design [@Smith2024] [-@Jones2025] [@A2024; @B-2025]',
  '[UNVERIFIED] and [NEEDS CITATION]',
  'notquestion:q01 should not match as a standalone question ref',
}

local matches = compact(scanner.scan_lines(lines, config.defaults.entities, 10))

assert_eq(#matches, 14, 'match count')
assert_eq(matches[1].kind, 'question', 'first kind')
assert_eq(matches[1].text, 'question:q01-model-granularity', 'first text')
assert_eq(matches[1].row, 11, 'line offset is zero-based row')
assert_eq(matches[2].kind, 'task', 'frontmatter task kind')
assert_eq(matches[3].kind, 'hypothesis', 'hypothesis kind')
assert_eq(matches[4].kind, 'interpretation', 'interpretation kind')
assert_eq(matches[5].kind, 'task', 'link-label task kind')
assert_eq(matches[6].kind, 'question', 'link-target question kind')
assert_eq(matches[7].kind, 'topic', 'topic kind')
assert_eq(matches[8].kind, 'report', 'report kind')
assert_eq(matches[9].kind, 'discussion', 'discussion kind')
assert_eq(matches[10].text, '[@Smith2024]', 'single citation')
assert_eq(matches[11].text, '[-@Jones2025]', 'negative citation')
assert_eq(matches[12].text, '[@A2024; @B-2025]', 'multi citation')
assert_eq(matches[13].kind, 'unverified', 'unverified marker kind')
assert_eq(matches[14].kind, 'needs_citation', 'needs citation marker kind')

print('scanner_spec passed')
```

- [ ] **Step 4: Add default config needed by the test**

Write `~/.config/nvim/plugins/science-md.nvim/lua/science-md/config.lua`:

```lua
local M = {}

M.defaults = {
  enabled = 'auto',
  marker = 'science.yaml',
  debounce_ms = 150,
  viewport_only = true,
  viewport_margin = 10,
  entities = {
    question = {
      pattern = [[\<question:[A-Za-z0-9][A-Za-z0-9._-]*]],
      link = '@constant',
    },
    task = {
      pattern = [[\<task:[A-Za-z0-9][A-Za-z0-9._-]*]],
      link = '@function',
    },
    hypothesis = {
      pattern = [[\<hypothesis:[A-Za-z0-9][A-Za-z0-9._-]*]],
      link = '@type',
    },
    interpretation = {
      pattern = [[\<interpretation:[A-Za-z0-9][A-Za-z0-9._-]*]],
      link = '@string.special',
    },
    discussion = {
      pattern = [[\<discussion:[A-Za-z0-9][A-Za-z0-9._-]*]],
      link = 'Comment',
      italic = true,
    },
    topic = {
      pattern = [[\<topic:[A-Za-z0-9][A-Za-z0-9._-]*]],
      link = 'Number',
    },
    report = {
      pattern = [[\<report:[A-Za-z0-9][A-Za-z0-9._-]*]],
      link = 'Constant',
    },
    cite = {
      pattern = [[\[-\=@[A-Za-z][A-Za-z0-9_-]*\%(\s*;\s*@\=[A-Za-z][A-Za-z0-9_-]*\)*\]]],
      link = 'Underlined',
      italic = true,
    },
    unverified = {
      pattern = [[\[UNVERIFIED\]]],
      link = 'DiagnosticWarn',
      bold = true,
    },
    needs_citation = {
      pattern = [[\[NEEDS CITATION\]]],
      link = 'DiagnosticError',
      bold = true,
    },
  },
}

local function merge_entity(default_entity, override)
  return vim.tbl_deep_extend('force', default_entity or {}, override or {})
end

function M.merge(opts)
  opts = opts or {}
  local merged = vim.tbl_deep_extend('force', M.defaults, opts)
  merged.entities = vim.deepcopy(M.defaults.entities)
  for kind, entity in pairs(opts.entities or {}) do
    merged.entities[kind] = merge_entity(merged.entities[kind], entity)
  end
  return merged
end

return M
```

- [ ] **Step 5: Run scanner test and verify it fails because scanner is missing**

Run:

```bash
nvim --headless -u ~/.config/nvim/plugins/science-md.nvim/tests/minimal_init.lua -l ~/.config/nvim/plugins/science-md.nvim/tests/scanner_spec.lua
```

Expected: FAIL with a message containing `module 'science-md.scanner' not found`.

- [ ] **Step 6: Commit scaffold and failing test**

Run:

```bash
git -C ~/.config/nvim status --short
git -C ~/.config/nvim add plugins/science-md.nvim/tests/minimal_init.lua plugins/science-md.nvim/tests/scanner_spec.lua plugins/science-md.nvim/lua/science-md/config.lua
git -C ~/.config/nvim commit -m "test: add science-md scanner coverage"
```

Expected: commit succeeds if `~/.config/nvim` is a git repo. If it is not a git repo, record the status output in the implementation notes and continue without committing.

## Task 2: Implement Pure Scanner

**Files:**
- Create: `~/.config/nvim/plugins/science-md.nvim/lua/science-md/scanner.lua`
- Modify: `~/.config/nvim/plugins/science-md.nvim/tests/scanner_spec.lua`

- [ ] **Step 1: Implement the scanner**

Write `~/.config/nvim/plugins/science-md.nvim/lua/science-md/scanner.lua`:

```lua
local M = {}

local compiled_cache = setmetatable({}, { __mode = 'k' })

local function compiled_entities(entities)
  if compiled_cache[entities] then
    return compiled_cache[entities]
  end

  local compiled = {}
  for kind, entity in pairs(entities) do
    table.insert(compiled, {
      kind = kind,
      regex = vim.regex(entity.pattern),
    })
  end
  table.sort(compiled, function(a, b)
    return a.kind < b.kind
  end)

  compiled_cache[entities] = compiled
  return compiled
end

function M.scan_lines(lines, entities, row_offset)
  row_offset = row_offset or 0
  local matches = {}

  for index, line in ipairs(lines) do
    local row = row_offset + index - 1
    for _, entity in ipairs(compiled_entities(entities)) do
      local start_at = 0
      while start_at < #line do
        local col_start, col_end = entity.regex:match_str(line:sub(start_at + 1))
        if not col_start then
          break
        end

        col_start = col_start + start_at
        col_end = col_end + start_at
        table.insert(matches, {
          row = row,
          col_start = col_start,
          col_end = col_end,
          kind = entity.kind,
          text = line:sub(col_start + 1, col_end),
        })
        start_at = math.max(col_end, start_at + 1)
      end
    end
  end

  table.sort(matches, function(a, b)
    if a.row ~= b.row then
      return a.row < b.row
    end
    if a.col_start ~= b.col_start then
      return a.col_start < b.col_start
    end
    return a.kind < b.kind
  end)

  return matches
end

return M
```

- [ ] **Step 2: Run scanner test and verify the first real failure**

Run:

```bash
nvim --headless -u ~/.config/nvim/plugins/science-md.nvim/tests/minimal_init.lua -l ~/.config/nvim/plugins/science-md.nvim/tests/scanner_spec.lua
```

Expected: either PASS or a precise assertion failure. If the count is wrong because the citation regex does not match a fixture, fix only the relevant pattern in `config.lua` and rerun this same command.

- [ ] **Step 3: Add a regression assertion for the word boundary**

Append to `~/.config/nvim/plugins/science-md.nvim/tests/scanner_spec.lua` before the final `print`:

```lua
local boundary = compact(scanner.scan_lines({ 'xquestion:q01 question:q02' }, config.defaults.entities, 0))
assert_eq(#boundary, 1, 'boundary count')
assert_eq(boundary[1].text, 'question:q02', 'boundary text')
```

- [ ] **Step 4: Run scanner test to verify it passes**

Run:

```bash
nvim --headless -u ~/.config/nvim/plugins/science-md.nvim/tests/minimal_init.lua -l ~/.config/nvim/plugins/science-md.nvim/tests/scanner_spec.lua
```

Expected: PASS with `scanner_spec passed`.

- [ ] **Step 5: Commit scanner**

Run:

```bash
git -C ~/.config/nvim add plugins/science-md.nvim/lua/science-md/scanner.lua plugins/science-md.nvim/tests/scanner_spec.lua plugins/science-md.nvim/lua/science-md/config.lua
git -C ~/.config/nvim commit -m "feat: scan natural markdown references"
```

Expected: commit succeeds if `~/.config/nvim` is a git repo.

## Task 3: Add Highlight and Render Layers

**Files:**
- Create: `~/.config/nvim/plugins/science-md.nvim/lua/science-md/highlights.lua`
- Create: `~/.config/nvim/plugins/science-md.nvim/lua/science-md/render.lua`

- [ ] **Step 1: Implement highlight group definitions**

Write `~/.config/nvim/plugins/science-md.nvim/lua/science-md/highlights.lua`:

```lua
local M = {}

local function group_name(kind)
  return 'ScienceMd' .. kind:gsub('^%l', string.upper):gsub('_(%l)', function(char)
    return char:upper()
  end)
end

local function concrete_hl(spec)
  local hl = vim.deepcopy(spec)
  hl.pattern = nil
  local link = hl.link
  hl.link = nil

  if link and next(hl) then
    local ok, base = pcall(vim.api.nvim_get_hl, 0, { name = link, link = false })
    if ok then
      return vim.tbl_extend('force', base, hl)
    end
  end

  if link then
    hl.link = link
  end
  return hl
end

function M.define(config)
  for kind, entity in pairs(config.entities) do
    vim.api.nvim_set_hl(0, group_name(kind), concrete_hl(entity))
  end
end

function M.group_name(kind)
  return group_name(kind)
end

return M
```

- [ ] **Step 2: Implement extmark rendering**

Write `~/.config/nvim/plugins/science-md.nvim/lua/science-md/render.lua`:

```lua
local highlights = require('science-md.highlights')

local M = {}

M.ns = vim.api.nvim_create_namespace('science_md')

function M.apply(buf, matches)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)

  for _, match in ipairs(matches) do
    vim.api.nvim_buf_set_extmark(buf, M.ns, match.row, match.col_start, {
      end_col = match.col_end,
      hl_group = highlights.group_name(match.kind),
      priority = 150,
    })
  end
end

function M.clear(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
  end
end

return M
```

- [ ] **Step 3: Run scanner test to verify existing behavior still passes**

Run:

```bash
nvim --headless -u ~/.config/nvim/plugins/science-md.nvim/tests/minimal_init.lua -l ~/.config/nvim/plugins/science-md.nvim/tests/scanner_spec.lua
```

Expected: PASS with `scanner_spec passed`.

- [ ] **Step 4: Commit render and highlights**

Run:

```bash
git -C ~/.config/nvim add plugins/science-md.nvim/lua/science-md/highlights.lua plugins/science-md.nvim/lua/science-md/render.lua
git -C ~/.config/nvim commit -m "feat: render natural markdown highlights"
```

Expected: commit succeeds if `~/.config/nvim` is a git repo.

## Task 4: Add Project Detection and Scheduler

**Files:**
- Create: `~/.config/nvim/plugins/science-md.nvim/lua/science-md/project.lua`
- Create: `~/.config/nvim/plugins/science-md.nvim/lua/science-md/scheduler.lua`
- Create: `~/.config/nvim/plugins/science-md.nvim/tests/scheduler_spec.lua`

- [ ] **Step 1: Implement project marker detection**

Write `~/.config/nvim/plugins/science-md.nvim/lua/science-md/project.lua`:

```lua
local M = {}

local cache = {}

function M.is_project(path, marker)
  marker = marker or 'science.yaml'
  path = vim.fs.normalize(path)

  if cache[path] ~= nil then
    return cache[path]
  end

  local found = vim.fs.find(marker, { upward = true, path = path })[1]
  cache[path] = found and vim.fs.dirname(found) or false
  return cache[path]
end

function M.clear_cache()
  cache = {}
end

return M
```

- [ ] **Step 2: Add scheduler tests**

Write `~/.config/nvim/plugins/science-md.nvim/tests/scheduler_spec.lua`:

```lua
local scheduler = require('science-md.scheduler')

local function assert_eq(actual, expected, label)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', label, vim.inspect(expected), vim.inspect(actual)))
  end
end

local merged = scheduler.merge_ranges({
  { start_row = 10, end_row = 20 },
  { start_row = 18, end_row = 30 },
  { start_row = 50, end_row = 60 },
})

assert_eq(#merged, 2, 'merged range count')
assert_eq(merged[1].start_row, 10, 'first range start')
assert_eq(merged[1].end_row, 30, 'first range end')
assert_eq(merged[2].start_row, 50, 'second range start')

local calls = 0
scheduler._test_with_refresh(function()
  calls = calls + 1
end)

scheduler._test_debounce(1, 5)
scheduler._test_debounce(1, 5)
vim.wait(100)
assert_eq(calls, 1, 'debounce coalesces repeated calls')

print('scheduler_spec passed')
```

- [ ] **Step 3: Implement scheduler**

Write `~/.config/nvim/plugins/science-md.nvim/lua/science-md/scheduler.lua`:

```lua
local scanner = require('science-md.scanner')
local render = require('science-md.render')

local M = {}

local state = {}
local refresh_impl

local function buf_state(buf)
  state[buf] = state[buf] or { generation = 0 }
  return state[buf]
end

function M.merge_ranges(ranges)
  table.sort(ranges, function(a, b)
    return a.start_row < b.start_row
  end)

  local merged = {}
  for _, range in ipairs(ranges) do
    local last = merged[#merged]
    if last and range.start_row <= last.end_row + 1 then
      last.end_row = math.max(last.end_row, range.end_row)
    else
      table.insert(merged, {
        start_row = range.start_row,
        end_row = range.end_row,
      })
    end
  end
  return merged
end

local function visible_ranges(buf, margin)
  local ranges = {}
  local line_count = vim.api.nvim_buf_line_count(buf)

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
      local top = vim.fn.line('w0', win) - 1
      local bottom = vim.fn.line('w$', win) - 1
      table.insert(ranges, {
        start_row = math.max(0, top - margin),
        end_row = math.min(line_count - 1, bottom + margin),
      })
    end
  end

  return M.merge_ranges(ranges)
end

local function refresh(buf, config)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local ranges
  if config.viewport_only then
    ranges = visible_ranges(buf, config.viewport_margin)
  else
    ranges = { { start_row = 0, end_row = vim.api.nvim_buf_line_count(buf) - 1 } }
  end

  local matches = {}
  for _, range in ipairs(ranges) do
    local lines = vim.api.nvim_buf_get_lines(buf, range.start_row, range.end_row + 1, false)
    vim.list_extend(matches, scanner.scan_lines(lines, config.entities, range.start_row))
  end

  render.apply(buf, matches)
end

refresh_impl = refresh

function M.schedule(buf, config, immediate)
  local current = buf_state(buf)
  current.generation = current.generation + 1
  local generation = current.generation

  if current.timer then
    current.timer:stop()
    current.timer:close()
  end

  local delay = immediate and 0 or config.debounce_ms
  current.timer = vim.loop.new_timer()
  current.timer:start(delay, 0, function()
    vim.schedule(function()
      if state[buf] and state[buf].generation == generation then
        refresh_impl(buf, config)
      end
    end)
  end)
end

function M.clear(buf)
  local current = state[buf]
  if current and current.timer then
    current.timer:stop()
    current.timer:close()
  end
  state[buf] = nil
end

function M._test_with_refresh(fn)
  refresh_impl = fn
end

function M._test_debounce(buf, debounce_ms)
  M.schedule(buf, { debounce_ms = debounce_ms, viewport_only = false, entities = {} }, false)
end

return M
```

- [ ] **Step 4: Run scheduler test**

Run:

```bash
nvim --headless -u ~/.config/nvim/plugins/science-md.nvim/tests/minimal_init.lua -l ~/.config/nvim/plugins/science-md.nvim/tests/scheduler_spec.lua
```

Expected: PASS with `scheduler_spec passed`.

- [ ] **Step 5: Commit scheduler and project detection**

Run:

```bash
git -C ~/.config/nvim add plugins/science-md.nvim/lua/science-md/project.lua plugins/science-md.nvim/lua/science-md/scheduler.lua plugins/science-md.nvim/tests/scheduler_spec.lua
git -C ~/.config/nvim commit -m "feat: schedule natural markdown refreshes"
```

Expected: commit succeeds if `~/.config/nvim` is a git repo.

## Task 5: Wire Public API and lazy.nvim Loading

**Files:**
- Create: `~/.config/nvim/plugins/science-md.nvim/lua/science-md/init.lua`
- Modify: `~/.config/nvim/lua/user/plugins_always/plugins.lua`

- [ ] **Step 1: Implement public API and autocmds**

Write `~/.config/nvim/plugins/science-md.nvim/lua/science-md/init.lua`:

```lua
local config_mod = require('science-md.config')
local highlights = require('science-md.highlights')
local project = require('science-md.project')
local render = require('science-md.render')
local scheduler = require('science-md.scheduler')

local M = {}

local active = {}
local config = config_mod.merge()

local function augroup_name(buf)
  return 'science_md_' .. tostring(buf)
end

function M.enable(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if active[buf] then
    scheduler.schedule(buf, config, true)
    return
  end

  active[buf] = true
  local group = vim.api.nvim_create_augroup(augroup_name(buf), { clear = true })

  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost' }, {
    group = group,
    buffer = buf,
    callback = function()
      scheduler.schedule(buf, config, true)
    end,
  })

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'WinScrolled' }, {
    group = group,
    buffer = buf,
    callback = function()
      scheduler.schedule(buf, config, false)
    end,
  })

  vim.api.nvim_create_autocmd('BufWipeout', {
    group = group,
    buffer = buf,
    callback = function()
      M.disable(buf)
    end,
  })

  scheduler.schedule(buf, config, true)
end

function M.disable(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  active[buf] = nil
  pcall(vim.api.nvim_del_augroup_by_name, augroup_name(buf))
  scheduler.clear(buf)
  render.clear(buf)
end

local function maybe_enable(buf)
  if config.enabled == false then
    return
  end

  if config.enabled == true then
    M.enable(buf)
    return
  end

  local name = vim.api.nvim_buf_get_name(buf)
  if name == '' then
    return
  end

  local dir = vim.fs.dirname(name)
  if project.is_project(dir, config.marker) then
    M.enable(buf)
  end
end

function M.setup(opts)
  config = config_mod.merge(opts)
  highlights.define(config)

  local setup_group = vim.api.nvim_create_augroup('science_md_setup', { clear = true })
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = setup_group,
    callback = function()
      highlights.define(config)
    end,
  })

  vim.api.nvim_create_autocmd('FileType', {
    group = setup_group,
    pattern = 'markdown',
    callback = function(args)
      maybe_enable(args.buf)
    end,
  })
end

return M
```

- [ ] **Step 2: Add lazy.nvim local plugin spec**

Insert this table in `~/.config/nvim/lua/user/plugins_always/plugins.lua` near the other plugin entries:

```lua
  {
    dir = vim.fn.stdpath('config') .. '/plugins/science-md.nvim',
    ft = 'markdown',
    config = function()
      require('science-md').setup()
    end,
  },
```

- [ ] **Step 3: Run all headless plugin tests**

Run:

```bash
nvim --headless -u ~/.config/nvim/plugins/science-md.nvim/tests/minimal_init.lua -l ~/.config/nvim/plugins/science-md.nvim/tests/scanner_spec.lua
nvim --headless -u ~/.config/nvim/plugins/science-md.nvim/tests/minimal_init.lua -l ~/.config/nvim/plugins/science-md.nvim/tests/scheduler_spec.lua
```

Expected: PASS with `scanner_spec passed` and `scheduler_spec passed`.

- [ ] **Step 4: Verify lazy spec parses**

Run:

```bash
nvim --headless -c 'lua require("config.lazy")' -c 'qa'
```

Expected: exits 0 with no Lua error.

- [ ] **Step 5: Commit public API and lazy loading**

Run:

```bash
git -C ~/.config/nvim add plugins/science-md.nvim/lua/science-md/init.lua lua/user/plugins_always/plugins.lua
git -C ~/.config/nvim commit -m "feat: load science-md for markdown"
```

Expected: commit succeeds if `~/.config/nvim` is a git repo.

## Task 6: Add Documentation and Manual Smoke Checks

**Files:**
- Create: `~/.config/nvim/plugins/science-md.nvim/README.md`

- [ ] **Step 1: Add README**

Write `~/.config/nvim/plugins/science-md.nvim/README.md`:

````markdown
# science-md.nvim

Local Neovim plugin for highlighting Science-project markdown references such as `task:t001`, `question:q01-model-granularity`, `[@Smith2024]`, `[UNVERIFIED]`, and `[NEEDS CITATION]`.

The plugin activates on markdown buffers inside a project containing `science.yaml`. It overlays highlights with extmarks and does not replace vim syntax or Tree-sitter markdown highlighting.

## Configuration

```lua
require('science-md').setup({
  enabled = 'auto',
  marker = 'science.yaml',
  debounce_ms = 150,
  viewport_only = true,
  viewport_margin = 10,
  entities = {
    task = { link = '@function' },
  },
})
```

Use `enabled = true` to force highlighting for every markdown buffer, or `enabled = false` to disable it.

## Tests

```bash
nvim --headless -u ~/.config/nvim/plugins/science-md.nvim/tests/minimal_init.lua -l ~/.config/nvim/plugins/science-md.nvim/tests/scanner_spec.lua
nvim --headless -u ~/.config/nvim/plugins/science-md.nvim/tests/minimal_init.lua -l ~/.config/nvim/plugins/science-md.nvim/tests/scheduler_spec.lua
```
````

- [ ] **Step 2: Run automated verification**

Run:

```bash
nvim --headless -u ~/.config/nvim/plugins/science-md.nvim/tests/minimal_init.lua -l ~/.config/nvim/plugins/science-md.nvim/tests/scanner_spec.lua
nvim --headless -u ~/.config/nvim/plugins/science-md.nvim/tests/minimal_init.lua -l ~/.config/nvim/plugins/science-md.nvim/tests/scheduler_spec.lua
nvim --headless -c 'lua require("config.lazy")' -c 'qa'
```

Expected: all commands exit 0.

- [ ] **Step 3: Manual Science-project smoke test**

Run:

```bash
nvim ~/d/natural-systems/doc/reports/synthesis.md
```

Expected: markdown opens normally, Science refs and markers are highlighted, scrolling stays responsive, and `:lua print(vim.inspect(vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_create_namespace('science_md'), 0, -1, {})))` shows extmarks.

- [ ] **Step 4: Manual non-Science regression check**

Run:

```bash
tmpdir=$(mktemp -d)
printf '# no marker\n\n task:t001 [UNVERIFIED]\n' > "$tmpdir/README.md"
nvim "$tmpdir/README.md"
```

Expected: buffer opens normally and the plugin does not apply `science_md` extmarks because no `science.yaml` marker exists above the file.

- [ ] **Step 5: Commit docs**

Run:

```bash
git -C ~/.config/nvim add plugins/science-md.nvim/README.md
git -C ~/.config/nvim commit -m "doc: document science-md plugin"
```

Expected: commit succeeds if `~/.config/nvim` is a git repo.

## Final Verification

- [ ] **Step 1: Run test suite**

Run:

```bash
nvim --headless -u ~/.config/nvim/plugins/science-md.nvim/tests/minimal_init.lua -l ~/.config/nvim/plugins/science-md.nvim/tests/scanner_spec.lua
nvim --headless -u ~/.config/nvim/plugins/science-md.nvim/tests/minimal_init.lua -l ~/.config/nvim/plugins/science-md.nvim/tests/scheduler_spec.lua
nvim --headless -c 'lua require("config.lazy")' -c 'qa'
```

Expected: all commands exit 0.

- [ ] **Step 2: Inspect git state**

Run:

```bash
git -C ~/.config/nvim status --short
```

Expected: only intentional plugin, plan, spec, and lazy spec changes are present.

- [ ] **Step 3: Confirm scope**

Check these constraints manually:

- The plugin only highlights markdown buffers.
- `enabled = "auto"` requires a marker walk to `science.yaml`.
- Pattern matching uses Vim regex and `\<`, not `\b`.
- Debounce uses a cancellable timer or equivalent generation guard.
- Split windows preserve highlights in all visible ranges for the same buffer.
- The implementation does not add virtual text, jump-to-definition, statusline integration, or completion.
