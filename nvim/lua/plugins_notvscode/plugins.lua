return {
  -- general
  {'romgrk/barbar.nvim'},

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
