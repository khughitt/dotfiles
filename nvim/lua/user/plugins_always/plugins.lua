return {
  -- colorschemes
  {'folke/tokyonight.nvim', lazy = false, priority = 1000, opts = {}, },

  -- plugins
  {url = "https://codeberg.org/andyg/leap.nvim" },
  {'godlygeek/tabular'},
  {'scrooloose/nerdcommenter'},
  {'tomtom/tlib_vim'},
  {'tpope/vim-surround'},
  {'tpope/vim-repeat'},
  {'wellle/targets.vim'},
  {
    dir = vim.fn.stdpath('config') .. '/plugins/science-md.nvim',
    ft = 'markdown',
    config = function()
      require('science-md').setup()
    end,
  },
  { 'dstein64/nvim-scrollview', branch = 'main' },
  { 'nvim-lualine/lualine.nvim', dependencies = { 'nvim-tree/nvim-web-devicons', lazy=true }},
  { 'nvim-treesitter/nvim-treesitter', lazy = false, build = ':TSUpdate',
    opts = {
      ensure_installed = {
        "bash", "c", "cmake", "cpp", "css", "csv", "dockerfile", "go", "hcl", "javascript",
        "json", "lua", "markdown", "markdown_inline", "python",
        "query", "r", "rnoweb", "rust", "sql", "terraform", "toml", "tsx", "typescript", "vimdoc", "yaml",
      },
      auto_install = true,
      highlight = { enable = true },
    },
  },
  { 'vladdoster/remember.nvim', config = [[ require('remember') ]] },

  -- textobjs
  {'JoosepAlviste/nvim-ts-context-commentstring'},
  {'tyru/vim-textobj-underscore', branch = 'support-3-cases', dependencies = {'kana/vim-textobj-user'}},

  -- devicons should come last..
  {'nvim-tree/nvim-web-devicons'},
  {'ryanoasis/vim-devicons'},


  -- maybe..
  -- {'glts/vim-textobj-comment'}
  -- use 'nathanaelkane/vim-indent-guides'
  -- https://github.com/brenoprata10/nvim-highlight-colors

  -- archived
  -- {'ervandew/supertab'},
  -- use '~/.config/nvim/user/mindful.vim'
  -- use 'folke/which-key.nvim'
  -- use {'andymass/vim-matchup', event = 'VimEnter'}
  -- use 'ggandor/lightspeed.nvim'
  -- use 'rrethy/vim-hexokinase', { 'build': 'make hexokinase' }
  -- use 'kana/vim-operator-user'
}
