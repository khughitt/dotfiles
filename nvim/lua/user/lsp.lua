-- ---------------------------------------------------------------------------
-- LSP
--
-- Servers come from the system package manager (pacman/brew/apt), not from
-- mason: they are ordinary CLI tools and the rest of these dotfiles already
-- installs software that way.
--
-- nvim-lspconfig is still a dependency, but only as a *data* package -- since
-- Neovim 0.11 it ships one `lsp/<name>.lua` per server on the runtimepath, and
-- vim.lsp.config/enable read those directly. Nothing here calls
-- require('lspconfig').
--
-- Enabling a server whose binary is missing is a no-op: Neovim resolves cmd[1]
-- at attach time and silently skips it. That is what keeps this list safe to
-- share between the Arch desktop, macOS, and an Ubuntu box over ssh -- each
-- machine lights up whatever it happens to have.
--
--   arch:   pacman -S pyright ruff typescript-language-server \
--                     bash-language-server lua-language-server gopls marksman
--   R:      install.packages("languageserver")
-- ---------------------------------------------------------------------------

-- R is deliberately absent: R.nvim ships its own language server ("r_ls") and
-- starts it for r/rmd/quarto buffers automatically. Enabling lspconfig's
-- r_language_server on top attaches a *second* server to every R buffer, and
-- r_ls is the better of the two -- it talks to the live R session, so it knows
-- about objects that are actually loaded.
local servers = {
  'bashls',
  'gopls',
  'lua_ls',
  'marksman',
  'pyright',
  'ruff',
  'ts_ls',
}

-- Python is split across two servers, which is the supported arrangement:
-- pyright does types/hover/completion, ruff does linting and import sorting.
-- Ruff's hover only ever returns the rule docs, so let pyright own hover to
-- avoid two popups fighting over the same keypress.
vim.lsp.config('ruff', {
  on_attach = function(client)
    client.server_capabilities.hoverProvider = false
  end,
})

-- Teach lua_ls about the Neovim runtime, so editing these very files gets
-- completion for `vim.*` instead of an undefined-global warning on every line.
vim.lsp.config('lua_ls', {
  settings = {
    Lua = {
      runtime = { version = 'LuaJIT' },
      workspace = { checkThirdParty = false },
      telemetry = { enable = false },
    },
  },
})

vim.lsp.enable(servers)

-- ---------------------------------------------------------------------------
-- Diagnostics
--
-- Neovim 0.11 turned virtual_text off by default. Turn it back on but keep it
-- to the current line, so a screenful of warnings does not shove the code
-- sideways.
-- ---------------------------------------------------------------------------
vim.diagnostic.config({
  virtual_text = { current_line = true, source = 'if_many' },
  severity_sort = true,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = '',
      [vim.diagnostic.severity.WARN]  = '',
      [vim.diagnostic.severity.INFO]  = '',
      [vim.diagnostic.severity.HINT]  = '',
    },
  },
  float = { border = 'rounded', source = 'if_many' },
})

-- ---------------------------------------------------------------------------
-- Per-buffer setup
--
-- Most LSP keymaps are built in since 0.11 and are NOT repeated here:
--   K    hover              grn  rename           grr  references
--   gra  code action        gri  implementation   grt  type definition
--   gO   document symbols   ]d / [d  next/prev diagnostic
-- ---------------------------------------------------------------------------
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('user.lsp', { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then
      return
    end

    -- Native LSP completion (0.11+), in place of a completion plugin.
    -- completeopt is set in init.lua; `popup` is what float-preview.nvim used
    -- to approximate.
    if client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
    end

    local function map(lhs, rhs, desc)
      vim.keymap.set('n', lhs, rhs, { buffer = args.buf, desc = 'LSP: ' .. desc })
    end

    -- gd is a plain "search for the local declaration" by default; point it at
    -- the language server, which actually knows.
    map('gd', vim.lsp.buf.definition, 'go to definition')
    map('gD', vim.lsp.buf.declaration, 'go to declaration')
    map('<leader>lf', function() vim.lsp.buf.format({ async = true }) end, 'format buffer')
    map('<leader>le', vim.diagnostic.open_float, 'show diagnostics for line')
    map('<leader>lq', vim.diagnostic.setloclist, 'diagnostics to loclist')
  end,
})
