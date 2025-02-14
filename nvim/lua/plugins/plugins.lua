return {
  -- colorschemes
  -- {'navarasu/onedark.nvim'},
  {'folke/tokyonight.nvim', lazy = false, priority = 1000, opts = {}, },
  --'drewtempelmeyer/palenight.vim'
  --'rakr/vim-one'
  --'reedes/vim-colors-pencil'
  --'tyrannicaltoucan/vim-quantum'
  --{'dracula/vim', name = 'dracula'}
  --{"scottmckendry/cyberdream.nvim", lazy = false}

  -- plugins
  {'JoosepAlviste/nvim-ts-context-commentstring'},
  {'chentoast/marks.nvim'},
  {'ervandew/supertab'},
  {'ggandor/leap.nvim'},
  {'godlygeek/tabular'},
  {'junegunn/vim-emoji', lazy=true},
  {'lewis6991/gitsigns.nvim'},
  {'ncm2/float-preview.nvim'},
  {'norcalli/nvim-colorizer.lua', lazy=true},
  {'nvim-telescope/telescope.nvim', tag = '0.1.8', dependencies = { 'nvim-lua/plenary.nvim' }},
  {'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
  {'nvim-telescope/telescope-frecency.nvim',
    config = function()
      require("telescope").load_extension "frecency"
    end,
  },
  {'romgrk/barbar.nvim'},
  {'scrooloose/nerdcommenter'},
  {'tomtom/tlib_vim'},
  {'tpope/vim-surround'},
  {'tpope/vim-repeat'},
  {'wellle/targets.vim'},
  { 'dstein64/nvim-scrollview', branch = 'main' },
  { 'nvim-lualine/lualine.nvim', dependencies = { 'nvim-tree/nvim-web-devicons', lazy=true }},
  { 'nvim-treesitter/nvim-treesitter', build = ':TSUpdate' },
  { 'vladdoster/remember.nvim', config = [[ require('remember') ]] },

  -- language support
  {'JuliaEditorSupport/julia-vim', lazy=true},
  {'bioSyntax/bioSyntax-vim', lazy=true},
  {'chrisbra/csv.vim', lazy=true},
  {'fatih/vim-go', lazy=true},
  {'glench/vim-jinja2-syntax', lazy=true},
  {'ibab/vim-snakemake', lazy=true},
  {'jalvesaq/Nvim-R'},
  {'leafgarland/typescript-vim', lazy=true},
  {'maxmellon/vim-jsx-pretty', lazy=true},
  {'mboughaba/i3config.vim', lazy=true},
  {'mllg/vim-devtools-plugin', lazy=true},
  {'mzlogin/vim-markdown-toc', lazy=true},
  {'pangloss/vim-javascript', lazy=true},
  {'raimon49/requirements.txt.vim', lazy=true},
  {'stephpy/vim-yaml', lazy=true},
  {'tikhomirov/vim-glsl', lazy=true},
  {'udalov/kotlin-vim', lazy=true},
  {'yuezk/vim-js', lazy=true},
  { 'neoclide/coc.nvim', branch = 'release', lazy=true},
  {'snakemake/snakemake', 
    ft='snakemake', 
    config = function(plugin)
        vim.opt.rtp:append(plugin.dir .. "/misc/vim")
    end
  },

  -- textobjs
  {'tyru/vim-textobj-underscore', branch = 'support-3-cases', dependencies = {'kana/vim-textobj-user'}},
  -- {'glts/vim-textobj-comment'}

  -- devicons should come last..
  {'nvim-tree/nvim-web-devicons'},
  {'ryanoasis/vim-devicons'},

  -- use '~/.config/nvim/user/mindful.vim'

  -- maybe..
  -- use 'nathanaelkane/vim-indent-guides'
  -- https://github.com/brenoprata10/nvim-highlight-colors

  -- archived
  -- use 'folke/which-key.nvim'
  -- use {'andymass/vim-matchup', event = 'VimEnter'}
  -- use 'ggandor/lightspeed.nvim'
  -- use 'rrethy/vim-hexokinase', { 'build': 'make hexokinase' }
  -- use 'kana/vim-operator-user'
}
