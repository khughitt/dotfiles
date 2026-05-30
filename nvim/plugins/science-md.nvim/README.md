# science-md.nvim

Local Neovim plugin for highlighting Science-project markdown references.

It recognizes project references such as `task:t001` and
`question:q01-model-granularity`, citation keys, and Science review markers
such as `[UNVERIFIED]` and `[NEEDS CITATION]`.

## Activation

By default, science-md activates for markdown buffers inside projects that
contain a `science.yaml` marker file. Highlighting is applied as an extmark
overlay, so it does not replace or disable Vim syntax highlighting or
Tree-sitter.

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

`enabled = 'auto'` uses the marker-based behavior described above.
`enabled = true` forces highlighting in every markdown buffer.
`enabled = false` disables the plugin.

Entity highlight groups are configured directly on each entity, as shown with
`task = { link = '@function' }`.

## Tests

Run the scanner spec:

```bash
nvim --headless -u ~/.config/nvim/plugins/science-md.nvim/tests/minimal_init.lua -l ~/.config/nvim/plugins/science-md.nvim/tests/scanner_spec.lua
```

Run the scheduler spec:

```bash
nvim --headless -u ~/.config/nvim/plugins/science-md.nvim/tests/minimal_init.lua -l ~/.config/nvim/plugins/science-md.nvim/tests/scheduler_spec.lua
```

Check that the lazy configuration parses:

```bash
nvim --headless -c 'lua require("config.lazy")' -c 'qa'
```
