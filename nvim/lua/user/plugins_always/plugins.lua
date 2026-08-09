return {
  -- colorschemes
  -- transparent = true makes Normal/NormalNC use the terminal's default
  -- background instead of painting their own. That is what lets kitty's
  -- background_opacity (and the focus-driven dim in kitty/focus-opacity.py)
  -- reach nvim at all: kitty decides transparency per cell by comparing the
  -- cell's background *color* against the default bg, so an opaque colorscheme
  -- background stays opaque no matter what the compositor or kitty do.
  -- Floats, cursorline and visual selection keep their own backgrounds and so
  -- stay solid, which reads as intended.
  {'folke/tokyonight.nvim', lazy = false, priority = 1000, opts = { transparent = true }, },

  -- plugins
  {'leap.nvim', url = "https://codeberg.org/andyg/leap.nvim" },
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
  { 'nvim-treesitter/nvim-treesitter', branch = 'main', lazy = false, build = ':TSUpdate',
    opts = {
      ensure_installed = {
        "bash", "c", "cmake", "cpp", "css", "csv", "dockerfile", "go", "hcl", "javascript",
        "json", "lua", "markdown", "markdown_inline", "python",
        "query", "r", "rnoweb", "rust", "sql", "terraform", "toml", "tsx", "typescript", "vimdoc", "yaml",
      },
      install_dir = vim.fn.stdpath('data') .. '/site',
    },
    config = function(_, opts)
      local treesitter = require('nvim-treesitter')
      treesitter.setup({ install_dir = opts.install_dir })
      treesitter.install(opts.ensure_installed)

      vim.api.nvim_create_autocmd('FileType', {
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
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
