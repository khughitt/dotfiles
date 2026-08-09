return {
  -- ---------------------------------------------------------------------
  -- Colorscheme
  --
  -- transparent = true makes Normal/NormalNC use the terminal's default
  -- background instead of painting their own. That is what lets kitty's
  -- background_opacity (and the focus-driven dim in kitty/focus-opacity.py)
  -- reach nvim at all: kitty decides transparency per cell by comparing the
  -- cell's background *color* against the default bg, so an opaque
  -- colorscheme background stays opaque no matter what the compositor does.
  -- See lua/user/glass.lua for the chrome that needs recoloring to match.
  -- ---------------------------------------------------------------------
  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    opts = { transparent = true },
  },

  -- ---------------------------------------------------------------------
  -- Statusline
  --
  -- Separators are thin lines rather than powerline chevrons on purpose:
  -- kitty has no per-cell text alpha, so a glyph is always solid. A filled
  -- chevron renders as an opaque triangle even when both neighbouring
  -- section backgrounds are translucent; a thin line leaves far less
  -- opaque area.
  -- ---------------------------------------------------------------------
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    event = 'VeryLazy',
    opts = function()
      return {
        options = {
          theme = require('user.glass').lualine_theme(),
          section_separators   = { left = '│', right = '│' },
          component_separators = { left = '│', right = '│' },
        },
        sections = {
          lualine_y = { 'searchcount', 'progress' },
        },
      }
    end,
  },

  -- Buffer line
  {
    'romgrk/barbar.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons', 'lewis6991/gitsigns.nvim' },
    event = 'VeryLazy',
    opts = {},
    keys = {
      { '<leader>bd', '<cmd>BufferClose<cr>',    desc = 'close buffer' },
      { '<tab>',      '<cmd>BufferNext<cr>',     desc = 'next buffer' },
      { '<s-tab>',    '<cmd>BufferPrevious<cr>', desc = 'previous buffer' },
      { '<s-right>',  '<cmd>BufferNext<cr>',     desc = 'next buffer' },
      { '<s-left>',   '<cmd>BufferPrevious<cr>', desc = 'previous buffer' },
    },
  },

  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      diff_opts = { ignore_whitespace = true },
    },
  },

  -- Scrollbar. Its ScrollView highlight is recolored in user/glass.lua so it
  -- does not paint an opaque stripe over the wallpaper.
  {
    'dstein64/nvim-scrollview',
    branch = 'main',
    event = 'VeryLazy',
  },

  -- Show a/'/marks in the signcolumn
  {
    'chentoast/marks.nvim',
    event = 'VeryLazy',
    opts = { refresh_interval = 350 },
  },

  -- Inline #rrggbb / rgb() swatches
  {
    'catgoose/nvim-colorizer.lua',
    event = { 'BufReadPost', 'BufNewFile' },
    opts = {},
  },

  { 'nvim-tree/nvim-web-devicons', lazy = true },
}
