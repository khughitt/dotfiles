-- ---------------------------------------------------------------------------
--
-- Neovim Configuration
-- KH (Aug 2023)
--
-- Layout:
--   init.lua                 options, global keymaps, autocmds  (this file)
--   lua/config/lazy.lua      plugin manager bootstrap
--   lua/user/plugins/*.lua   plugin specs; each plugin configures itself
--   lua/user/lsp.lua         language servers, diagnostics, completion
--   lua/user/glass.lua       highlight fixups for kitty's translucency
--
-- Useful commands:
--   :verbose set <var>?    find where a setting was made
--   :Lazy                  plugin status / update
--   :checkhealth           diagnose provider and plugin problems
--
-- ---------------------------------------------------------------------------

-- Leader keys must be set before lazy.nvim loads, or plugin keymaps bind to
-- the wrong prefix.
vim.g.mapleader      = ";"
vim.g.maplocalleader = ","

-- ---------------------------------------------------------------------------
-- General
-- ---------------------------------------------------------------------------
vim.opt.complete:append({ 'i' })      -- complete from included files
vim.opt.cursorline = true             -- highlight current line
vim.opt.foldenable = false            -- disable folding
vim.opt.isk:append({ '%', '#', '-' }) -- additional vim word characters
vim.opt.mouse = 'a'                   -- mouse wheel in terminal, etc.
vim.opt.showmode = false              -- hide <INSERT>; lualine shows the mode

-- reduce keycode mapping timeout delay
vim.opt.ttimeoutlen = 5
vim.opt.timeoutlen = 300

-- Fast save/quit
vim.keymap.set('n', '<leader>w', '<cmd>update<cr>',  { desc = 'save' })
vim.keymap.set('n', '<leader>q', '<cmd>q<cr>',       { desc = 'quit' })
vim.keymap.set('n', '<leader>z', '<cmd>wq<cr>',      { desc = 'save and quit' })

-- remap macro recording to Q, so a stray q does not start recording
vim.keymap.set('n', 'Q', 'q')
vim.keymap.set('n', 'q', '<nop>')

-- faster command execution
vim.keymap.set('n', '!', ':!')

-- ---------------------------------------------------------------------------
--  Backup and undo
-- ---------------------------------------------------------------------------
-- stdpath('state') is $XDG_STATE_HOME/nvim, and already correct on macOS.
-- (These were hand-assembled until Aug 2026 and were missing a path
-- separator, quietly filling ~/.local/statenvim/ with 100+ MB.)
local state = vim.fn.stdpath('state')
vim.opt.backupdir = state .. '/backup//'
vim.opt.undodir   = state .. '/undo//'
vim.opt.backup = true
vim.opt.undofile = true
vim.opt.history = 5000
vim.opt.undolevels = 200

vim.fn.mkdir(state .. '/backup', 'p')
vim.fn.mkdir(state .. '/undo', 'p')

-- break undo before c-u, so an accidental line-kill is recoverable
-- http://vim.wikia.com/wiki/Recover_from_accidental_Ctrl-U
vim.keymap.set('i', '<c-u>', '<c-g>u<c-u>')

-- ---------------------------------------------------------------------------
--  UI
-- ---------------------------------------------------------------------------
vim.opt.number = true                           -- line numbers
vim.opt.report = 0                              -- tell us about changes
vim.opt.scrolloff = 5                           -- keep cursor away from top/bottom
vim.opt.sidescrolloff = 1                       -- ... and from the sides
vim.opt.signcolumn = 'yes'                      -- always show signcolumn
vim.opt.showtabline = 2                         -- always show tabline (barbar)
vim.opt.wildignore = { '*.o', '*~', '*.pyc' }   -- ignore compiled files
vim.opt.wildmode = { 'longest', 'list' }        -- fill longest, then list

-- cursor shape per mode
vim.opt.guicursor = { 'n-v-c:block-Cursor/lCursor-blinkon0',
                      'i-ci:ver25-Cursor/lCursor',
                      'r-cr:hor20-Cursor/lCursor' }

-- ---------------------------------------------------------------------------
-- Visual Cues
-- ---------------------------------------------------------------------------
vim.opt.colorcolumn = { 100 }  -- show right margin

-- ---------------------------------------------------------------------------
-- Navigation
-- ---------------------------------------------------------------------------

-- quick navigation in insert mode using "alt" key
vim.keymap.set('i', '<m-h>', '<c-o>h')
vim.keymap.set('i', '<m-j>', '<c-o>j')
vim.keymap.set('i', '<m-k>', '<c-o>k')
vim.keymap.set('i', '<m-l>', '<c-o>l')

-- treat long lines as break lines (useful when moving around in them)
vim.keymap.set('', 'j', 'gj', { silent = true })
vim.keymap.set('', 'k', 'gk', { silent = true })

-- ---------------------------------------------------------------------------
--  Search
-- ---------------------------------------------------------------------------
vim.opt.ignorecase = true  -- ignore case
vim.opt.smartcase = true   -- ... unless the pattern contains uppercase

vim.keymap.set('n', '<leader>n', '<cmd>nohlsearch<cr>', { desc = 'clear search highlight' })

-- ---------------------------------------------------------------------------
-- Tabs, windows and buffers
-- ---------------------------------------------------------------------------
vim.opt.switchbuf = { 'useopen', 'usetab', 'newtab' }

vim.keymap.set('n', '<leader>cd', '<cmd>cd %:p:h<cr><cmd>pwd<cr>', { desc = 'cd to file directory' })
vim.keymap.set('n', '<localleader>gf', '<cmd>e <cfile><cr>',       { desc = 'create file under cursor' })
vim.keymap.set('n', '<leader>ba', '<cmd>%bdelete!<cr>',            { desc = 'close all buffers' })

-- window navigation, matching the terminal-mode maps below
vim.keymap.set('n', '<c-h>', '<c-w>h')
vim.keymap.set('n', '<c-j>', '<c-w>j')
vim.keymap.set('n', '<c-k>', '<c-w>k')
vim.keymap.set('n', '<c-l>', '<c-w>l')

-- zoom the current window into its own tab, tmux ^az style. (This used to be
-- defined in the R ftplugin, where it leaked into every buffer anyway.)
vim.keymap.set('n', 'gz', function()
  local pos = vim.api.nvim_win_get_cursor(0)
  vim.cmd('tabnew %')
  pcall(vim.api.nvim_win_set_cursor, 0, pos)
  vim.cmd('normal! zz')
end, { desc = 'zoom window into a new tab' })

-- ---------------------------------------------------------------------------
--  Completion
--
--  There is no completion plugin: Neovim's own LSP completion is enabled per
--  buffer in lua/user/lsp.lua. `popup` shows the documentation window that
--  float-preview.nvim used to provide, and `noselect` keeps the first entry
--  from being inserted as you type.
-- ---------------------------------------------------------------------------
vim.opt.infercase = true
vim.opt.completeopt = { 'menuone', 'noselect', 'popup' }

-- ---------------------------------------------------------------------------
--  Terminal
-- ---------------------------------------------------------------------------

-- escape to the window under h/j/k/l without leaving terminal mode first
vim.keymap.set('t', '<c-h>', [[<c-\><c-n><c-w>h]])
vim.keymap.set('t', '<c-j>', [[<c-\><c-n><c-w>j]])
vim.keymap.set('t', '<c-k>', [[<c-\><c-n><c-w>k]])
vim.keymap.set('t', '<c-l>', [[<c-\><c-n><c-w>l]])

-- word-wise movement, as in a normal shell
vim.keymap.set('t', '<c-left>',  '<m-b>')
vim.keymap.set('t', '<c-right>', '<m-f>')

local term_group = vim.api.nvim_create_augroup('user.terminal', { clear = true })

vim.api.nvim_create_autocmd('TermOpen', {
  group = term_group,
  callback = function(args)
    vim.bo[args.buf].buflisted = false
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.signcolumn = 'no'
    -- <tab>/<s-tab> are buffer switching; in a terminal they belong to the
    -- program running inside it.
    vim.keymap.set('n', '<tab>',   '<nop>', { buffer = args.buf })
    vim.keymap.set('n', '<s-tab>', '<nop>', { buffer = args.buf })
  end,
})

-- automatically enter insert mode when focusing a terminal
vim.api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter' }, {
  group = term_group,
  pattern = 'term://*',
  command = 'startinsert',
})

-- ---------------------------------------------------------------------------
-- Text Formatting
-- ---------------------------------------------------------------------------
vim.opt.expandtab = true                -- expand tabs to spaces
vim.opt.formatoptions:append({ 'n' })   -- support for numbered/bulleted lists
vim.opt.shiftround = true               -- round indents to multiple of shiftwidth
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.tabstop = 2
vim.opt.textwidth = 100                 -- wrap at 100 characters, when asked
vim.opt.virtualedit = { 'block' }       -- allow virtual edit in visual block
vim.opt.wrap = false                    -- do not wrap lines
vim.opt.linebreak = true                -- when wrapping, respect word boundaries

-- when wrapping is on, wrap backspace, cursor keys, etc.
vim.opt.whichwrap:append({ ['<'] = true, ['>'] = true, ['['] = true, [']'] = true,
                           h = true, l = true })

-- strip all trailing whitespace in file
vim.keymap.set('n', '<localleader>s', [[<cmd>%s/ \+$//gc<cr>]], { desc = 'strip trailing whitespace' })

-- split paragraph into one sentence per line
vim.keymap.set('n', '<localleader>p', [[:s/[!\?\.] /.\r\r/g]], { desc = 'split into sentences' })

-- toggle the textwidth wrap limit, remembering the previous value
vim.keymap.set('n', '<localleader>r', function()
  if vim.bo.textwidth ~= 0 then
    vim.b.saved_textwidth = vim.bo.textwidth
    vim.bo.textwidth = 0
  else
    vim.bo.textwidth = vim.b.saved_textwidth or 100
  end
  vim.notify('textwidth=' .. vim.bo.textwidth)
end, { desc = 'toggle textwidth' })

-- ---------------------------------------------------------------------------
--  Commenting
--
--  Neovim has built-in gc/gcc since 0.10, so nerdcommenter is gone. Embedded
--  languages are handled by nvim-ts-context-commentstring, which hooks
--  vim.filetype.get_option (see lua/user/plugins/lang.lua).
-- ---------------------------------------------------------------------------
vim.keymap.set('n', '<space>', 'gcc', { remap = true, desc = 'toggle comment' })
vim.keymap.set('x', '<space>', 'gc',  { remap = true, desc = 'toggle comment' })

-- copy the current line/selection and comment out the original
vim.keymap.set('n', 'zz', 'yygccp',       { remap = true, desc = 'duplicate line, comment original' })
vim.keymap.set('x', 'zz', 'ygvgc`.jP',    { remap = true, desc = 'duplicate selection, comment original' })

-- ---------------------------------------------------------------------------
--  Copy and Paste
--
-- Use "+ and "* explicitly for CLIPBOARD and PRIMARY. Keeping 'clipboard'
-- unset prevents ordinary yanks, deletes, and changes from spawning providers.
-- ---------------------------------------------------------------------------
-- Neovim auto-detects a clipboard provider, but pin wl-clipboard explicitly on
-- Wayland so PRIMARY (*) is wired up as well as CLIPBOARD (+). Left unset
-- elsewhere on purpose: over ssh/tmux with no clipboard tool available,
-- Neovim falls back to OSC 52 and yanks reach the local machine.
if vim.env.WAYLAND_DISPLAY then
  vim.g.clipboard = {
    name = 'wl-clipboard',
    copy = {
      ['+'] = 'wl-copy',
      ['*'] = 'wl-copy --primary',
    },
    paste = {
      ['+'] = 'wl-paste --no-newline',
      ['*'] = 'wl-paste --no-newline --primary',
    },
    cache_enabled = 0,
  }
end

-- paste from primary in normal mode
vim.keymap.set('n', '<leader>p', '"*p')
vim.keymap.set('n', '<leader>P', '"*P')

-- X11 hands the selection back when the owning process exits, so a yank is
-- lost on :q. Hand it to a longer-lived owner first. Wayland does not need
-- this -- wl-copy forks a helper that keeps serving the selection.
if not vim.env.WAYLAND_DISPLAY and vim.fn.executable('xsel') == 1 then
  vim.api.nvim_create_autocmd('VimLeave', {
    group = vim.api.nvim_create_augroup('user.clipboard', { clear = true }),
    callback = function()
      if #vim.api.nvim_list_uis() > 0 then
        vim.fn.system('xsel -ip', vim.fn.getreg('+'))
      end
    end,
  })
end

-- ---------------------------------------------------------------------------
--  Filetypes
-- ---------------------------------------------------------------------------
vim.filetype.add({
  extension = {
    har = 'json',
  },
})

local ft_group = vim.api.nvim_create_augroup('user.filetype', { clear = true })

-- javascript's bundled indent script fights with treesitter indentation
vim.api.nvim_create_autocmd('FileType', {
  group = ft_group,
  pattern = 'javascript',
  callback = function() vim.b.did_indent = 1 end,
})

vim.api.nvim_create_autocmd('FileType', {
  group = ft_group,
  pattern = 'vim',
  callback = function()
    vim.bo.softtabstop, vim.bo.shiftwidth, vim.bo.tabstop = 4, 4, 4
  end,
})

-- re-detect the filetype of a new file the first time it is written, so a
-- buffer started as "untitled" picks up highlighting from its new name
vim.api.nvim_create_autocmd('BufWritePost', {
  group = ft_group,
  callback = function()
    if vim.bo.syntax == '' and vim.bo.filetype == '' then
      vim.cmd('filetype detect')
    end
  end,
})

-- ---------------------------------------------------------------------------
--  Restore cursor position when reopening a file
--
--  (Replaces remember.nvim; Neovim still has no built-in for this.)
-- ---------------------------------------------------------------------------
vim.api.nvim_create_autocmd('BufReadPost', {
  group = vim.api.nvim_create_augroup('user.lastplace', { clear = true }),
  callback = function(args)
    -- skip commit messages and the like, where the top of the file is right
    if vim.tbl_contains({ 'gitcommit', 'gitrebase', 'help' }, vim.bo[args.buf].filetype) then
      return
    end
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(args.buf) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
      vim.cmd('normal! zvzz')
    end
  end,
})

-- ---------------------------------------------------------------------------
--  Plugins
-- ---------------------------------------------------------------------------
require('config.lazy')

-- Noctalia-derived colors: :NoctaliaMood + SIGUSR1 live-reload. Must be set
-- up before the colorscheme loads so the first load already uses on_colors.
require('user.noctalia').setup()

vim.cmd.colorscheme('tokyonight-moon')

-- Recolor the chrome that would otherwise punch opaque rectangles through
-- kitty's translucent background. Must run after the colorscheme.
require('user.glass').setup()

require('user.lsp')

-- ---------------------------------------------------------------------------
--  Appearance (post-colorscheme)
--
--  ColorColumn's gui background is set in user/glass.lua -- it has to be a
--  color kitty renders translucent, and it must survive a ColorScheme event.
--  Only the 256-color fallback lives here.
-- ---------------------------------------------------------------------------
vim.cmd('highlight ColorColumn ctermbg=234')
vim.cmd('highlight Conceal guibg=background guifg=foreground')
vim.cmd('highlight MatchParen cterm=bold ctermbg=none ctermfg=red')
vim.cmd('highlight SpecialKey ctermfg=DarkGray ctermbg=Black')
