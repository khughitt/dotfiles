-- ---------------------------------------------------------------------------
--
-- Neovim Configuration
-- KH (Aug 2023)
--
-- ---------------------------------------------------------------------------
--
-- Useful commands:
--
-- :verbose set <var>?    find where a setting was made
-- :scriptnames           list vimscripts loaded
--

-- ---------------------------------------------------------------------------
-- General
-- ---------------------------------------------------------------------------
vim.opt.complete:append({'i'})        -- complete filenames
vim.opt.cursorline = true             -- highlight current line
vim.opt.foldenable = false            -- disable folding
vim.opt.hidden = true                 -- easy buffer switching
vim.opt.isk:append({'%', '#', '-'})   -- additional vim word characters
vim.opt.modeline = true               -- make sure modeline support is enabled
vim.opt.showmode = false              -- hide <INSERT>

-- reduce keycode mapping timeout delay
vim.opt.ttimeoutlen = 5
vim.opt.timeoutlen = 500

-- Remap leader / localleader
vim.g.mapleader      = ";"
vim.g.maplocalleader = ","

-- Fast save/quit
vim.keymap.set('n', '<leader>w', ':update<cr>')
vim.keymap.set('n', '<leader>q', ':q<cr>')
vim.keymap.set('n', '<leader>z', ':wq<cr>')

-- remap macro recording to Q
vim.keymap.set('n', 'Q', 'q')
vim.keymap.set('n', 'q', '<nop>')

-- enable mouse wheel in terminal, etc.
vim.opt.mouse = 'a'

-- enable syntax highlighting by default
vim.opt.syntax = "on"

-- refresh syntax when saving new files
vim.api.nvim_create_autocmd('BufWritePost', {
  pattern = {'*'},
  command = 'if &syntax == "" | :filetype detect | endif'
})

-- faster command execution
vim.keymap.set('n', '!', ':!')

-- ----------------------------------------------------------------------------
--  Backup and undo
-- ----------------------------------------------------------------------------
vim.opt.backupdir = (os.getenv('XDG_STATE_HOME') or  (os.getenv('HOME') .. ".local")) .. 'nvim/backup'
vim.opt.undodir = (os.getenv('XDG_STATE_HOME') or  (os.getenv('HOME') .. ".local")) .. 'nvim/undo'
vim.opt.backup = true
vim.opt.history = 5000
vim.opt.undofile = true
vim.opt.undolevels = 200

-- enable undo using c-u in insert mode
-- http://vim.wikia.com/wiki/Recover_from_accidental_Ctrl-U
vim.keymap.set('i', '<c-u>', '<c-g>u<c-u>')

-- ----------------------------------------------------------------------------
--  UI
-- ----------------------------------------------------------------------------
vim.opt.number = true                         -- line numbers
vim.opt.report = 0                            -- tell us about changes
vim.opt.scrolloff = 5                         -- keep cursor at least this far away from top/bottom
vim.opt.sidescrolloff = 1                     -- keep cursor this far from sides of screen
vim.opt.signcolumn = 'yes'                    -- always show signcolumn
vim.opt.wildignore = {'*.o', '*~', '*.pyc'}   -- ignore compiled files
vim.opt.wildmode = {'longest', 'list'}        -- for filename completion, fill longest and list others

-- Enable cursor shape support
vim.opt.guicursor = {'n-v-c:block-Cursor/lCursor-blinkon0',
                     'i-ci:ver25-Cursor/lCursor',
                     'r-cr:hor20-Cursor/lCursor'}

-- ----------------------------------------------------------------------------
-- Visual Cues
-- ----------------------------------------------------------------------------
vim.opt.colorcolumn = {100}   -- show right margin
vim.opt.showmatch = true    -- show matching braces when being added

-- ----------------------------------------------------------------------------
-- Navigation
-- ----------------------------------------------------------------------------

-- quick navigation in insert mode using "alt" key
vim.keymap.set('i', '<m-h>', '<c-o>h')
vim.keymap.set('i', '<m-j>', '<c-o>j')
vim.keymap.set('i', '<m-k>', '<c-o>k')
vim.keymap.set('i', '<m-l>', '<c-o>l')

-- treat long lines as break lines (useful when moving around in them)
vim.keymap.set('', 'j', 'gj', {silent = true})
vim.keymap.set('', 'k', 'gk', {silent = true})

-- ---------------------------------------------------------------------------
--  Search Options
-- ---------------------------------------------------------------------------
vim.opt.ignorecase = true -- ignore case
vim.opt.smartcase = true  -- enforce case when pattern contains uppercase chars

-- stop highlighting matches
vim.keymap.set('n', '<leader>n', ':nohlsearch<cr>')

-- ----------------------------------------------------------------------------
-- Tabs, windows and buffers
-- ----------------------------------------------------------------------------
vim.opt.switchbuf = {'useopen', 'usetab', 'newtab'} -- behavior when switching between buffers
vim.opt.showtabline = 2 			    -- always show tabline

vim.keymap.set('', '<leader>cd', ':cd %:p:h<cr>:pwd<cr>') -- cd to directory of current file
vim.keymap.set('', '<localleader>gf', ':e <cfile><cr>')   -- create file under cursor
vim.keymap.set('', '<leader>ba', ':1,1000 bd!<cr>')       -- close all the buffers


-- ---------------------------------------------------------------------------
--  Tab completion
-- ---------------------------------------------------------------------------
vim.opt.infercase = true  -- case insensitive tab completion

-- enable completion of filenames following '='
-- vim.opt.isfname.remove({'='})

-- ---------------------------------------------------------------------------
--  Terminal
-- ---------------------------------------------------------------------------

-- h/j/k/l
vim.keymap.set('t', '<c-h>', [[ <c-\><c-n><c-w>h ]])
vim.keymap.set('t', '<c-j>', [[ <c-\><c-n><c-w>j ]])
vim.keymap.set('t', '<c-k>', [[ <c-\><c-n><c-w>k ]])
vim.keymap.set('t', '<c-l>', [[ <c-\><c-n><c-w>l ]])
vim.keymap.set('n', '<c-h>', [[ <c-w>h ]])
vim.keymap.set('n', '<c-j>', [[ <c-w>j ]])
vim.keymap.set('n', '<c-k>', [[ <c-w>k ]])
vim.keymap.set('n', '<c-l>', [[ <c-w>l ]])

-- cntl + arrow keys
vim.keymap.set('t', '<c-left>', '<m-b>')
vim.keymap.set('t', '<c-right>', '<m-f>')

-- automatically enter insert mode
vim.api.nvim_create_autocmd({'BufWinEnter', 'WinEnter'}, {
  pattern = {'term://*'},
  command = 'startinsert'
})

-- exclude terminal from buffer list
vim.api.nvim_create_autocmd('TermOpen', {
  pattern = {'*'},
  command = 'set nobuflisted'
})

vim.api.nvim_create_autocmd('TermOpen', {
  pattern = {'*'},
  command = 'noremap <buffer> <tab> <nop>'
})

vim.api.nvim_create_autocmd('TermOpen', {
  pattern = {'*'},
  command = 'noremap <buffer> <s-tab> <nop>'
})

-- disable terminal line numbers
vim.api.nvim_create_autocmd('TermOpen', {
  pattern = {'*'},
  command = 'setlocal nonumber norelativenumber'
})

-- ----------------------------------------------------------------------------
-- Text Formatting
-- ----------------------------------------------------------------------------

vim.opt.expandtab = true              -- expand tabs to spaces
vim.opt.formatoptions:append({'n'})   -- support for numbered/bulleted lists
vim.opt.shiftround = true             -- round indents to multiple of shift width
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2               -- tab width
vim.opt.tabstop = 2
vim.opt.textwidth = 100               -- wrap lines at 100 characters, when asked
vim.opt.virtualedit = {"block"}       -- allow virtual edit in visual block ..
vim.opt.wrap = false                  -- do not wrap lines

-- when wrapping is on, wrap backspace, cursor keys, etc.
vim.opt.whichwrap:append ({
  ['<'] = true,
  ['>'] = true,
  ['['] = true,
  [']'] = true,
  h = true,
  l = true,
})

-- copy and comment current line
vim.keymap.set('n', 'zz', 'yy<leader>ccp', { remap = true })
vim.keymap.set('v', 'zz', 'ygv<leader>cc`.jP', { remap = true })

-- strip all trailing whitespace in file
vim.keymap.set('', '<localleader>s', [[ <cmd>%s/ \+$//gc<cr> ]])

-- split paragraph into sentences
vim.keymap.set('', '<localleader>p', [[ :s/[!\?\.] /.\r\r/g ]])

-- Shortuct to toggle textwidth wrapping
vim.cmd([[
function! ToggleTextWidth()
  if &textwidth != 0
    let b:oldtextwidth = &textwidth
    set textwidth=0
  elseif exists("b:oldtextwidth")
    let &textwidth = b:oldtextwidth
  else
    set textwidth=100
  endif
endfunction
]])
vim.keymap.set('n', '<localleader>r', ':call ToggleTextWidth()<cr>', { silent = true })

-- ---------------------------------------------------------------------------
--  Copy and Paste
-- ---------------------------------------------------------------------------

-- Some useful clipboard options:
-- unnamed        CLIPBOARD (shift-control v)
-- unnamedplus    PRIMARY   (middlemouse)
-- autoselect     Automatically save visual selections

-- switching to unnamedplus to allow pasting to chromium, etc. in wayland
vim.opt.clipboard:prepend({'unnamed', 'unnamedplus'})

-- paste from primary in normal mode
vim.keymap.set('', '<leader>p', '"*p')
vim.keymap.set('', '<leader>P', '"*P')

-- preserve primary buffer on exit
-- https://stackoverflow.com/questions/6453595/prevent-vim-from-clearing-the-clipboard-on-exit
vim.api.nvim_create_autocmd('VimLeave', {
  pattern = {'*'},
  command = [[ call system("xsel -ip", getreg('+')) ]]
})

-----------------------------------------------------------------------------
-- lazy
-----------------------------------------------------------------------------
require("config.lazy")

-----------------------------------------------------------------------------
-- mason
-----------------------------------------------------------------------------
if not vim.g.vscode then
  require("mason").setup()
  require("mason-lspconfig").setup()
end

-----------------------------------------------------------------------------
-- nvim-lspconfig
-----------------------------------------------------------------------------
if not vim.g.vscode then
  local lspconfig = require'lspconfig'

  lspconfig.quick_lint_js.setup({
      filetypes = {"javascript", "javascriptreact", "typescript", "typescriptreact"}
  })

  lspconfig.r_language_server.setup {
    cmd = {"R", "--slave", "-e", "languageserver::run()"},
    filetypes = {"r", "rmd"},
    root_dir = function(fname)
      return lspconfig.util.find_git_ancestor(fname)
    end,
    settings = {},
  }
end

-----------------------------------------------------------------------------
-- lualine
-----------------------------------------------------------------------------
require('lualine').setup {
  options = { theme  = 'tokyonight' },
  sections = {
    lualine_y = {'searchcount', 'progress'}
  }
}

-----------------------------------------------------------------------------
-- marks.nvim
-----------------------------------------------------------------------------
require'marks'.setup {
  refresh_interval = 350
}

-----------------------------------------------------------------------------
-- nvim-colorizer
-----------------------------------------------------------------------------
vim.cmd('set termguicolors')
require('colorizer').setup {}

-----------------------------------------------------------------------------
-- R.nvim
-----------------------------------------------------------------------------
if not vim.g.vscode then
  require'r'.setup {
    -- show term on bottom
    rconsole_width = 0,
    source_args = "echo = TRUE"

    -- show term on left side (jan25: not working..)
    -- nosplitright = true
  }
end

-----------------------------------------------------------------------------
-- which-key (testing)
-----------------------------------------------------------------------------
-- require("which-key").setup {}

-----------------------------------------------------------------------------
-- barbar.nvim
-----------------------------------------------------------------------------
if not vim.g.vscode then
  local map = vim.api.nvim_set_keymap
  local opts = { silent = true }

  map('n', '<leader>bd', '<cmd>BufferClose<cr>', opts)
  map('n', '<s-tab>', '<cmd>BufferPrevious<cr>', opts)
  map('n', '<tab>', '<cmd>BufferNext<cr>', opts)
  map('n', '<s-left>', '<cmd>BufferPrevious<cr>', opts)
  map('n', '<s-right>', '<cmd>BufferNext<cr>', opts)
end

-- ---------------------------------------------------------------------------
-- csv.vim
-- ---------------------------------------------------------------------------
-- vim.g.csv_no_conceal = 1

-- ---------------------------------------------------------------------------
--  Colorscheme
-- ---------------------------------------------------------------------------
-- require('onedark').load()
-- require("cyberdream").setup({
--   transparent = true,
--   italic_comments = true,
--   hide_fillchars = true,
-- })
-- vim.cmd("colorscheme cyberdream")
vim.cmd[[colorscheme tokyonight]]

-- ---------------------------------------------------------------------------
-- float-preview.nvim
-- ---------------------------------------------------------------------------
vim.cmd('let g:float_preview#docked = 1')

-- ---------------------------------------------------------------------------
-- Telescope
-- ---------------------------------------------------------------------------
local actions = require("telescope.actions")
local builtin = require('telescope.builtin')
local extensions = require('telescope').extensions

require('telescope').setup{
  defaults = {
    mappings = {
      i = {
        ["<C-h>"] = "which_key",   -- show keyboard shortcuts ("help")
        ["<C-u>"] = false,         -- clear line
        ["<esc>"] = actions.close  -- exit picker
      }
    }
  },
  pickers = {},
  extensions = {}
}

require('telescope').load_extension('fzf')

vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>fr', extensions.frecency.frecency, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})

-- ---------------------------------------------------------------------------
--  gitgutter
-- ---------------------------------------------------------------------------
vim.g.gitgutter_diff_args = '--ignore-all-space'


-- ----------------------------------------------------------------------------
--  leap
-- ----------------------------------------------------------------------------
require('leap').add_default_mappings()

-- ---------------------------------------------------------------------------
--  NERDcommenter
-- ---------------------------------------------------------------------------
vim.g.NERDDefaultAlign = 'left'
vim.g.NERDSpaceDelims = 1
vim.g.NERDCommentEmptyLines = 1
vim.g.NERDTrimTrailingWhitespace = 1

vim.g.NERDCustomDelimiters = {
  snakemake = { left = '#' },
  rmd = { left = '#' }}

-- may cause problems with nvim-ipy..
-- { remap=true? }
vim.keymap.set('n', '<space>', '<leader>c<space>')
vim.keymap.set('v', '<space>', '<leader>c<space>')

-- ---------------------------------------------------------------------------
-- supertab.vim
-- ---------------------------------------------------------------------------
-- vim.g.SuperTabCrMapping=1
-- vim.g.SuperTabDefaultCompletionType = "context"

-- ---------------------------------------------------------------------------
--  treesitter
-- ---------------------------------------------------------------------------
require'nvim-treesitter.configs'.setup {
  ensure_installed = { "bash", "c", "cmake", "cpp", "css", "csv", "dockerfile", "go", "javascript",
                       "json", "julia", "latex", "lua", "markdown", "markdown_inline", "python",
                       "query", "r", "rust", "sql", "toml", "tsx", "typescript", "vimdoc", "yaml"},
  auto_install = true,
  sync_install = false,
  highlight = { enable = true, },
}

-- ---------------------------------------------------------------------------
--  vim-textobj-underscore
-- ---------------------------------------------------------------------------
vim.keymap.set('n', 'cid', 'ci_', { remap = true })
vim.keymap.set('n', 'cad', 'ca_', { remap = true })
vim.keymap.set('n', 'did', 'di_', { remap = true })
vim.keymap.set('n', 'dad', 'da_', { remap = true })

-- ---------------------------------------------------------------------------
--  Language-specific Options
-- ---------------------------------------------------------------------------
vim.api.nvim_create_autocmd({'BufNewFile', 'BufRead'}, { pattern = '*.jl', command = 'set syntax=julia' })
vim.api.nvim_create_autocmd({'BufNewFile', 'BufRead'}, { pattern = '*.md', command = 'set syntax=markdown' })
vim.api.nvim_create_autocmd({'BufNewFile', 'BufRead'}, { pattern = '*.har', command = 'set ft=json' })
vim.api.nvim_create_autocmd('FileType', { pattern = 'javascript', command = 'let b:did_indent = 1' })
vim.api.nvim_create_autocmd('FileType', { pattern = 'vimscript', command = 'setlocal softtabstop=4 shiftwidth=4 tabstop=4' })

-- ---------------------------------------------------------------------------
--  Appearance (post-colorscheme)
-- ---------------------------------------------------------------------------
vim.cmd('highlight ColorColumn ctermbg=234 guibg=#222222')
vim.cmd('highlight Conceal guibg=background guifg=foreground')
vim.cmd('highlight MatchParen cterm=bold ctermbg=none ctermfg=red')
vim.cmd('highlight SpecialKey ctermfg=DarkGray ctermbg=Black')
