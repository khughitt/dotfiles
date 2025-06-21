return {
  -- colorschemes
  {'reedes/vim-colors-pencil'},
  {'Shatur/neovim-ayu'},
  -- {'navarasu/onedark.nvim'},
  -- {'drewtempelmeyer/palenight.vim'},
  -- {'rakr/vim-one'},
  -- {'tyrannicaltoucan/vim-quantum'},
  -- {'dracula/vim', name = 'dracula'},
  -- {"scottmckendry/cyberdream.nvim", lazy = false},

  -- general
  {'romgrk/barbar.nvim'},
  {'chentoast/marks.nvim'},
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

  -- language support
  {'nvimtools/none-ls.nvim'},
  {"williamboman/mason.nvim"},
  {"williamboman/mason-lspconfig.nvim"},
  {"neovim/nvim-lspconfig"},
  {'JuliaEditorSupport/julia-vim', lazy=true},
  {'bioSyntax/bioSyntax-vim', lazy=true},
  {'chrisbra/csv.vim', lazy=true},
  {'fatih/vim-go', lazy=true},
  {'glench/vim-jinja2-syntax', lazy=true},
  {'ibab/vim-snakemake', lazy=true},
  {"R-nvim/R.nvim", lazy = false},
  {'mboughaba/i3config.vim', lazy=true},
  {'mllg/vim-devtools-plugin', lazy=true},
  {'mzlogin/vim-markdown-toc', lazy=true},
  {'raimon49/requirements.txt.vim', lazy=true},
  {'snakemake/snakemake', 
    ft='snakemake', 
    config = function(plugin)
        vim.opt.rtp:append(plugin.dir .. "/misc/vim")
    end
  }
}
