-- ---------------------------------------------------------------------------
-- R buffer setup
--
-- Ported from ftplugin/{r,rmd}.vim, which were byte-identical copies of each
-- other written for Nvim-R. R.nvim replaced Nvim-R, and none of the old
-- `R_*` / `vimrplugin_*` globals do anything any more -- the equivalents are
-- options on require('r').setup() (see lua/user/plugins/lang.lua).
--
-- Mappings are buffer-local. The old files set them globally, so opening a
-- single R file rebound <Space> away from "toggle comment" everywhere for the
-- rest of the session.
-- ---------------------------------------------------------------------------

local M = {}

-- Show the source of the R function under the cursor in a scratch buffer.
local function show_r_source()
  local fn = vim.fn.expand('<cword>')
  if fn == '' then
    return
  end
  vim.cmd('enew')
  vim.bo.buftype = 'nofile'
  vim.bo.bufhidden = 'wipe'
  vim.bo.swapfile = false
  vim.bo.syntax = 'r'
  vim.cmd('RInsert ' .. fn)
end

function M.setup_buffer()
  local buf = vim.api.nvim_get_current_buf()

  -- The bundled r ftplugin sets iskeyword in a way that breaks `.`-separated
  -- object names; put it back.
  vim.bo[buf].iskeyword = '@,48-57,_,192-255'

  -- rmarkdown highlighting drifts when jumping around a long file
  vim.cmd('syntax sync minlines=300')

  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = buf, silent = true, desc = 'R: ' .. desc })
  end

  -- Send code to the R console. In R buffers this displaces the global
  -- <Space> "toggle comment" mapping on purpose.
  map('n', '<space>', '<Plug>RDSendLine',      'send line')
  map('x', '<space>', '<Plug>RDSendSelection', 'send selection')
  map('n', '<cr>',    '<Plug>RDSendLine',      'send line')
  map('x', '<cr>',    '<Plug>RDSendSelection', 'send selection')

  map('n', '<localleader>h', function()
    require('r.run').action('head')
  end, 'head() of object under cursor')

  map('n', '<localleader>sc', show_r_source, 'show source of function under cursor')

  -- devtools::load_all(), which used to come from vim-devtools-plugin. That
  -- plugin drives the console through Nvim-R's g:SendCmdToR, which R.nvim
  -- does not provide, so every one of its commands errored out.
  map('n', '<localleader>dl', function()
    require('r.send').cmd('devtools::load_all()')
  end, 'devtools::load_all()')

  -- wipe knitr cache and output
  map('n', '<localleader>kc', function()
    require('r.send').cmd(
      'rm(list=ls(all.names=TRUE)); unlink("*_cache/*", recursive=TRUE)')
  end, 'wipe knitr cache')

  -- render to a github_document
  map('n', '<localleader>km', function()
    require('r.rmd').make('github_document')
  end, 'knit to github_document')
end

return M
