return {
  -- ---------------------------------------------------------------------
  -- LSP
  --
  -- Data only: since Neovim 0.11 this ships one lsp/<name>.lua per server on
  -- the runtimepath, which vim.lsp.config/enable read directly. The actual
  -- wiring lives in lua/user/lsp.lua; nothing calls require('lspconfig').
  -- ---------------------------------------------------------------------
  { 'neovim/nvim-lspconfig' },

  -- ---------------------------------------------------------------------
  -- Treesitter (main branch: install/start are explicit, no setup shim)
  -- ---------------------------------------------------------------------
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false,
    build = ':TSUpdate',
    opts = {
      ensure_installed = {
        'bash', 'c', 'cmake', 'cpp', 'css', 'csv', 'diff', 'dockerfile',
        'gitcommit', 'go', 'hcl', 'javascript', 'json', 'kdl', 'lua',
        'markdown', 'markdown_inline', 'python', 'query', 'r', 'rnoweb',
        'rust', 'sql', 'terraform', 'toml', 'tsx', 'typescript', 'vimdoc',
        'yaml',
      },
      install_dir = vim.fn.stdpath('data') .. '/site',
    },
    config = function(_, opts)
      local treesitter = require('nvim-treesitter')
      treesitter.setup({ install_dir = opts.install_dir })
      treesitter.install(opts.ensure_installed)

      -- Start highlighting for any filetype that has a parser; pcall because
      -- most filetypes do not.
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('user.treesitter', { clear = true }),
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
  },

  -- Correct commentstring inside embedded languages (JS in HTML, R chunks in
  -- rmd, ...). Neovim's built-in gc reads vim.filetype.get_option, so the
  -- integration is a wrapper around that rather than a plugin mapping.
  {
    'JoosepAlviste/nvim-ts-context-commentstring',
    lazy = true,
    init = function()
      vim.g.skip_ts_context_commentstring_module = true
      local get_option = vim.filetype.get_option
      vim.filetype.get_option = function(filetype, option)
        if option ~= 'commentstring' then
          return get_option(filetype, option)
        end
        -- Falls back to the filetype default when there is no parser, or when
        -- the cursor is not inside an embedded region.
        return require('ts_context_commentstring.internal').calculate_commentstring()
          or get_option(filetype, option)
      end
    end,
    opts = { enable_autocmd = false },
  },

  -- ---------------------------------------------------------------------
  -- R
  --
  -- Buffer-local mappings live in lua/user/r.lua, applied from
  -- after/ftplugin/{r,rmd}.lua.
  --
  -- vim-devtools-plugin used to sit alongside this. It drives the console
  -- through Nvim-R's g:SendCmdToR, which R.nvim does not define, so all of
  -- its :R* commands errored; <localleader>dl replaces the one that was
  -- actually mapped.
  -- ---------------------------------------------------------------------
  {
    'R-nvim/R.nvim',
    lazy = false,
    opts = {
      rconsole_width = 0,               -- console below the editor, not beside it
      source_args = 'echo = TRUE',
      objbr_place = 'console,right',
      hl_term = false,                  -- do not highlight console output
      Rout_more_colors = true,
      setwidth = 0,                     -- do not track the window width
      pdfviewer = 'zathura',
      start_libs = 'base,stats,graphics,grDevices,utils,methods,parallel,tidyverse',
    },
  },

  -- ---------------------------------------------------------------------
  -- Local plugin: highlights Science-project markdown references
  -- ---------------------------------------------------------------------
  {
    dir = vim.fn.stdpath('config') .. '/plugins/science-md.nvim',
    name = 'science-md.nvim',
    ft = 'markdown',
    opts = {},
  },

  -- ---------------------------------------------------------------------
  -- Filetype support
  --
  -- These all need a real trigger (ft/cmd). `lazy = true` on its own means
  -- "load when require'd", and a vimscript plugin is never require'd -- so
  -- the previous specs left every one of these permanently unloaded.
  -- ---------------------------------------------------------------------
  { 'chrisbra/csv.vim',         ft = 'csv' },
  { 'glench/vim-jinja2-syntax', ft = 'jinja' },

  -- vim-go was dropped: it warned "could not find 'gopls'" four times on every
  -- Go buffer, and everything it was still providing now comes from the go
  -- treesitter parser plus gopls itself (enabled in lua/user/lsp.lua).

  -- Not lazy on purpose: its ftdetect runs on every BufReadPost and calls
  -- requirements#shebang, which lives in the plugin's autoload/ -- unreachable
  -- while the plugin is off the runtimepath, so lazy-loading it makes opening
  -- *any* file throw E117. It is one syntax file; eager costs nothing.
  { 'raimon49/requirements.txt.vim', lazy = false },
  {
    'mzlogin/vim-markdown-toc',
    cmd = { 'GenTocGFM', 'GenTocRedcarpet', 'GenTocGitLab', 'GenTocMarked', 'UpdateToc', 'RemoveToc' },
  },
  {
    'snakemake/snakemake',
    ft = 'snakemake',
    config = function(plugin)
      vim.opt.rtp:append(plugin.dir .. '/misc/vim')
    end,
  },
  {
    'tidalcycles/vim-tidal'
  }
}
