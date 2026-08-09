return {
  -- ---------------------------------------------------------------------
  -- Motions and text objects
  -- ---------------------------------------------------------------------

  -- Codeberg, not GitHub -- see the git.filter note in config/lazy.lua.
  {
    'leap.nvim',
    url = 'https://codeberg.org/andyg/leap.nvim',
    keys = {
      { 's', '<Plug>(leap)',             mode = { 'n', 'x', 'o' }, desc = 'leap' },
      { 'S', '<Plug>(leap-from-window)', mode = 'n',               desc = 'leap from window' },
    },
  },

  { 'tpope/vim-surround', event = 'VeryLazy', dependencies = { 'tpope/vim-repeat' } },
  { 'tpope/vim-repeat',   lazy = true },
  { 'wellle/targets.vim', event = 'VeryLazy' },

  -- cid/cad/did/dad operate on _underscore_ segments
  {
    'tyru/vim-textobj-underscore',
    branch = 'support-3-cases',
    dependencies = { 'kana/vim-textobj-user' },
    event = 'VeryLazy',
  },
  { 'kana/vim-textobj-user', lazy = true },

  -- :Tabularize /=
  { 'godlygeek/tabular', cmd = 'Tabularize' },

  -- ---------------------------------------------------------------------
  -- Pickers
  -- ---------------------------------------------------------------------
  {
    'nvim-telescope/telescope.nvim',
    cmd = 'Telescope',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-frecency.nvim',
        config = function()
          require('telescope').load_extension('frecency')
        end,
      },
    },
    keys = {
      { '<leader>ff', '<cmd>Telescope find_files<cr>', desc = 'find files' },
      { '<leader>fg', '<cmd>Telescope live_grep<cr>',  desc = 'live grep' },
      { '<leader>fr', '<cmd>Telescope frecency<cr>',   desc = 'recent files' },
      { '<leader>fb', '<cmd>Telescope buffers<cr>',    desc = 'buffers' },
      { '<leader>fh', '<cmd>Telescope help_tags<cr>',  desc = 'help tags' },
    },
    opts = function()
      local actions = require('telescope.actions')
      return {
        defaults = {
          mappings = {
            i = {
              ['<C-h>'] = 'which_key',   -- show keyboard shortcuts ("help")
              ['<C-u>'] = false,         -- leave c-u as "clear line"
              ['<esc>'] = actions.close, -- exit picker without going normal first
            },
          },
        },
      }
    end,
  },
}
