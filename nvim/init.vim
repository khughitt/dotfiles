" ---------------------------------------------------------------------------
" Neovim Configuration
"
" TODO:
"
"  1. Restore cntl-left and right word navigation behavior when inside terminal
"  2. Fix behavior when using :bd with a terminal open
"  3. Fix Nerd commenter behavior within code blocks
"
" ---------------------------------------------------------------------------

" ---------------------------------------------------------------------------
" General
" ---------------------------------------------------------------------------
set hidden           " easy buffer switching
set history=5000     " number of command history
set isk+=_,$,@,%,#,- " none word dividers
set showmatch        " highlight correspods character
set cursorline       " highlight current line
set modeline         " make sure modeline support is enabled
set noerrorbells     " quiet, please
set nofoldenable     " disable folding
set complete+=i      " complete filenames
filetype indent on   " indent based on filetype

" Mouse support
" https://github.com/neovim/neovim/wiki/Following-HEAD#20170403
set mouse=a

" Omnicompletion
set omnifunc=syntaxcomplete#Complete

" Use Ctrl+Space to do omnicompletion
if has("gui_running")
    inoremap <C-Space> <C-x><C-o>
else
    inoremap <Nul> <C-x><C-o>
endif

" With a map leader it's possible to do extra key combinations
" like <leader>w saves the current file
let mapleader = ";"
let g:mapleader = ";"

let maplocalleader = ","

" Fast save/quit
nmap <leader>w :update<cr>
nmap <leader>q :q<cr>
nmap <leader>z :wq<cr>

" Fast save (alt. method)
inoremap <c-s> <c-o>:w<cr>
nnoremap <c-s> :w<cr>

" remap macro recording to Q
nnoremap Q q
nnoremap q <nop>

" home/end key tmux work-around
" https://github.com/neovim/neovim/issues/9012
inoremap <C-a> <Home>
inoremap <C-e> <End>
noremap <C-a> <Home>
noremap <C-e> <End>

" Autosave on leaving insert mode
" http://stackoverflow.com/questions/9087582/how-to-autosave-in-vim-7-when-focus-is-lost-from-the-window
autocmd InsertLeave * if expand('%') != '' | update | endif

" ---------------------------------------------------------------------------
" CamelCaseMotion
" ---------------------------------------------------------------------------
map <s-w> <Plug>CamelCaseMotion_w
map <s-b> <Plug>CamelCaseMotion_b
map <s-e> <Plug>CamelCaseMotion_e

" ---------------------------------------------------------------------------
" vim-plug
" ---------------------------------------------------------------------------
call plug#begin()
    " plugins
    Plug 'airblade/vim-gitgutter'
    Plug 'chrisbra/csv.vim'
    Plug 'ervandew/supertab'
    Plug 'guns/xterm-color-table.vim'
    Plug 'henrik/vim-indexed-search'
    Plug 'bfredl/nvim-ipy'
    Plug 'jalvesaq/Nvim-R'
    Plug 'kshenoy/vim-signature'
    Plug 'lilydjwg/colorizer'
    Plug 'machakann/vim-textobj-delimited'
    Plug 'majutsushi/tagbar'
    Plug 'MarcWeber/vim-addon-mw-utils'
    Plug 'mllg/vim-devtools-plugin'
    Plug 'nathanaelkane/vim-indent-guides'
    Plug 'qpkorr/vim-bufkill'
    Plug 'scrooloose/nerdcommenter'
    Plug 'Shougo/denite.nvim'
    Plug 'tmux-plugins/vim-tmux-focus-events'
    Plug 'tomtom/tlib_vim'
    Plug 'tpope/vim-surround'
    Plug 'tyrannicaltoucan/vim-quantum'
    Plug 'manabuishii/vim-cwl'
    Plug 'vim-airline/vim-airline'
    Plug 'vim-airline/vim-airline-themes'
    Plug 'vim-scripts/argtextobj.vim'
    Plug 'vim-syntastic/syntastic'
    Plug 'xolox/vim-misc'
    Plug 'xolox/vim-colorscheme-switcher'
    Plug 'ryanoasis/vim-devicons'
    Plug 'wellle/targets.vim'
    Plug '/usr/share/vim/vimfiles'
    Plug 'junegunn/fzf.vim'
    "Plug 'yuttie/comfortable-motion.vim'
    Plug 'severin-lemaignan/vim-minimap'

    "Plug 'hkupty/iron.nvim'
    "Plug 'garbas/vim-snipmate'
    "Plug 'haya14busa/incsearch.vim'
    "Plug 'honza/vim-snippets'
    "Plug 'ludovicchabant/vim-gutentags'
    "Plug 'plasticboy/vim-markdown'
    "Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }
    "Plug 'tpope/vim-repeat'

    " themes
    Plug 'dracula/vim', { 'as': 'dracula' }
    Plug 'jacoborus/tender.vim'
    Plug 'joshdick/onedark.vim'
    Plug 'whatyouhide/vim-gotham'
    Plug 'zanloy/vim-colors-grb256'
    Plug 'agreco/vim-citylights'
    Plug 'Dru89/vim-adventurous'
    Plug 'yuttie/hydrangea-vim'
    Plug 'lu-ren/SerialExperimentsLain'
    Plug 'danilo-augusto/vim-afterglow'
    Plug 'davidklsn/vim-sialoquent'
    Plug 'dikiaap/minimalist'
    Plug 'cseelus/vim-colors-tone'
    Plug 'connorholyday/vim-snazzy'
    Plug 'fenetikm/falcon'
call plug#end()

" TESTING
"noremap <silent> <ScrollWheelDown> :call comfortable_motion#flick(40)<CR>
"noremap <silent> <ScrollWheelUp>   :call comfortable_motion#flick(-40)<CR>

let g:minimap_highlight='Visual'
let g:minimap_toggle='<leader>mm'

" ----------------------------------------------------------------------------
"  Backups
" ----------------------------------------------------------------------------
set backup                             " keep backups after close
set writebackup                        " keep a backup while working
set noswapfile                         " don't keep swp files
set backupdir=$HOME/.vim/tmp/backup    " directory to store backups in
set backupcopy=yes                     " keep attributes of original file
set backupskip=/tmp/*,$TMPDIR/*,$TMP/*,$TEMP/*

" ----------------------------------------------------------------------------
"  UI
" ----------------------------------------------------------------------------
set scrolloff=5                 " keep cursor at least this far away from top/bottom
set sidescrolloff=1             " keep cursor this far from sides of screen
set wildignore=*.o,*~,*.pyc     " ignore compiled files
set ruler                       " show the cursor position all the time
set showcmd                     " show incomplete commands and selection info
set nolazyredraw                " turn off lazy redraw
set number                      " line numbers
set whichwrap+=<,>,h,l,[,]      " backspace and cursor keys wrap to
set shortmess=filtIoOA          " shorten messages
set report=0                    " tell us about changes
set nostartofline               " don't jump to the start of line when scrolling
"set display+=lastline           " don't hide long lines

" ----------------------------------------------------------------------------
" Visual Cues
" ----------------------------------------------------------------------------
set showmatch              " brackets/braces that is
set mat=5                  " duration to show matching brace (1/10 sec)
set incsearch              " do incremental searching
set infercase              " case insensitive tab completion
set ignorecase             " ignore case when searching
set novisualbell           " no thank you
set colorcolumn=100        " show right margin

let marksCloseWhenSelected = 0
let showmarks_include="abcdefghijklmnopqrstuvwxyz"

" ----------------------------------------------------------------------------
" Navigation
" ----------------------------------------------------------------------------
inoremap <M-h> <Esc>h
inoremap <M-j> <Esc>j
inoremap <M-k> <Esc>k
inoremap <M-l> <Esc>l

" ----------------------------------------------------------------------------
" Text Formatting
" ----------------------------------------------------------------------------

"disablign smart-indent: may be preventing comments from indenting?
"http://stackoverflow.com/questions/191201/indenting-comments-to-match-code-in-vim
"set smartindent            " be smart about it
set nowrap                  " do not wrap lines
set softtabstop=4           " tab width
set shiftwidth=4
set shiftround              " round indents to multiple of shift width
set tabstop=4
set expandtab               " expand tabs to spaces
set smarttab
"set nosmarttab             " no tabs
set textwidth=99            " stick to less than 100 chars per line when possible
set formatoptions+=n        " support for numbered/bullet lists
set virtualedit=block       " allow virtual edit in visual block ..
set pastetoggle=<F6>        " paste-mode toggle

" Shortuct to toggle textwidth wrapping
nmap <silent><localleader>r :call ToggleTextWidth()<CR>
function! ToggleTextWidth()
  if &textwidth != 0
    let b:oldtextwidth = &textwidth
    set textwidth=0
  elseif exists("b:oldtextwidth")
    let &textwidth = b:oldtextwidth
  else
    set textwidth=99
  endif
endfunction

" ----------------------------------------------------------------------------
" Moving around, tabs, windows and buffers
" ----------------------------------------------------------------------------

" Treat long lines as break lines (useful when moving around in them)
map <silent> j gj
map <silent> k gk

" Use bufkill to preserve splits when closing buffers
cabbrev bd BD
"map <C-w> :BD<cr>

" Quick buffer switching using tab / shift + arrow keys
nnoremap <Tab> :bnext<CR>
nnoremap <S-Tab> :bprev<CR>
nnoremap <s-left> :bprev<CR>
nnoremap <s-right> :bnext<CR>

" Close the current buffer
map <leader>bd :BD<cr>

" Close all the buffers
map <leader>ba :1,1000 bd!<cr>

" Switch CWD to the directory of the open buffer
map <leader>cd :cd %:p:h<cr>:pwd<cr>

" Specify the behavior when switching between buffers
try
set switchbuf=useopen,usetab,newtab
    set stal=2
catch
endtry

" create file under cursor
map <silent> <leader>cf :!touch <c-r><c-p><cr><cr>

" Return to last edit position when opening files
autocmd BufReadPost *
    \ if line("'\"") > 0 && line("'\"") <= line("$") |
    \   exe "normal! g`\"" |
    \ endif

" Remember info about open buffers on close
set viminfo^=%

" Enable cursor shape support
set guicursor=n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50
            \,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor
            \,sm:block-blinkwait175-blinkoff150-blinkon175

" Easier switching to normal mode
inoremap jk <Esc>

" Faster command execution
nnoremap ! :!

" Sloppyness is okay
cabbrev ew :wq
cabbrev qw :wq

" ---------------------------------------------------------------------------
"  Appearance
" ---------------------------------------------------------------------------
if $TERM != 'linux'
    set t_Co=256
endif

" fix background bleeding in screen
" http://snk.tuxfamily.org/log/vim-256color-bce.html
" http://sunaku.github.io/vim-256color-bce.html
set t_ut=""

" enable true colors
set termguicolors

" use colorscheme for R output
let g:rout_follow_colorscheme = 1
let g:Rout_more_colors = 1

" fix control/shift + arrow keys in screen
" http://superuser.com/questions/401926/how-to-get-shiftarrows-and-ctrlarrows-working-in-vim-in-tmux
"if &term =~ '^screen'
    " tmux will send xterm-style keys when its xterm-keys option is on
    "execute "set <xUp>=\e[1;*A"
    "execute "set <xDown>=\e[1;*B"
    "execute "set <xRight>=\e[1;*C"
    "execute "set <xLeft>=\e[1;*D"
"endif

if has("gui_running")
    set guioptions-=m  " remove menu bar
    set guioptions-=T  " remove toolbar

    nnoremap <F11> :if &go=~#'m'<Bar>set go-=m<Bar>else<Bar>set go+=m<Bar>endif<CR>
    nnoremap <F12> :if &go=~#'T'<Bar>set go-=T<Bar>else<Bar>set go+=T<Bar>endif<CR>

    " font
    set guifont=DejaVu\ Sans\ Mono\ for\ Powerline\ 12

    " Make shift-insert work like in Xterm
    map <S-Insert> <MiddleMouse>
    map! <S-Insert> <MiddleMouse>
endif

" colorscheme
let g:quantum_black=1
let g:quantum_italics=1

set background=dark
"colorscheme hemisu
"colorscheme sweyla721647
"colorscheme sweyla939829
"colorscheme sweyla708971
"colorscheme gotham
"colorscheme SerialExperimentsLain
colorscheme dracula

"not working with recent versions
"highlight ColorColumn ctermbg=234 guibg=#222222

" NeoVim tmux support
" https://github.com/neovim/neovim/issues/2528
"if &term =~ '^screen'
    "hi Normal ctermbg=NONE
    "set noshowcmd
"endif

" terminal color scheme
" https://github.com/metalelf0/oceanic-next
"let g:terminal_color_0="#1b2b34"
"let g:terminal_color_1="#ed5f67"
"let g:terminal_color_2="#9ac895"
"let g:terminal_color_3="#fbc963"
"let g:terminal_color_4="#669acd"
"let g:terminal_color_5="#c695c6"
"let g:terminal_color_6="#5fb4b4"
"let g:terminal_color_7="#c1c6cf"
"let g:terminal_color_8="#65737e"
"let g:terminal_color_9="#fa9257"
"let g:terminal_color_10="#4e5d6b" " #343d46
"let g:terminal_color_11="#4f5b66"
"let g:terminal_color_12="#a8aebb"
"let g:terminal_color_13="#ced4df"
"let g:terminal_color_14="#ac7967"
"let g:terminal_color_15="#d9dfea"
"let g:terminal_color_background="#525252"
"let g:terminal_color_foreground="#c1c6cf"

" Matching parens style
hi MatchParen cterm=bold ctermbg=none ctermfg=red

" Highlight color (not working in recent versions)
"hi Search ctermbg=197 ctermfg=233
"hi Search guibg=#14D1DE guifg=#2C2C2C
"hi IncSearch guifg=#67E8F1 guibg=#333333

" ---------------------------------------------------------------------------
"  Copy and Paste
" ---------------------------------------------------------------------------

" Remap vim register to CLIPBOARD selection
" unamed        PRIMARY   (middlemouse)
" unamedplus    CLIPBOARD (shift-control v)
" autoselect    Automatically save visual selections
"set clipboard=unnamed,autoselect
"set clipboard=unnamed

" switching to unnamedplus to allow pasting to chromium, etc. in wayland
set clipboard=unnamedplus

" work-around to preserve yank buffer when pasting; the solution below first
" deletes selected text to an unused register
xnoremap p "_dP

" ----------------------------------------------------------------------------
"   Highlight Trailing Whitespace
" ----------------------------------------------------------------------------

"set listchars=tab:>\ ,trail:-,extends:>,precedes:<,nbsp:+
highlight SpecialKey ctermfg=DarkGray ctermbg=Black

" ---------------------------------------------------------------------------
"  Backup and undo
" ---------------------------------------------------------------------------
set undofile
set history=1000
set undolevels=200
set undodir=~/.vim/tmp/undo

" enable undo using c-u in insert mode
" http://vim.wikia.com/wiki/Recover_from_accidental_Ctrl-U
inoremap <c-u> <c-g>u<c-u>

" ---------------------------------------------------------------------------
"  terminal
" ---------------------------------------------------------------------------
tnoremap <C-h> <C-\><C-n><C-w>h
tnoremap <C-j> <C-\><C-n><C-w>j
tnoremap <C-k> <C-\><C-n><C-w>k
tnoremap <C-l> <C-\><C-n><C-w>l
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" terminal cntl + arrow keys
tnoremap <C-Left> <m-b>
tnoremap <C-Right> <m-f>

"" disable jumping (e.g. control-i) in terminal
" 2016/12/15 Disabling: prevents terminal tab completion from working properly
"tnoremap <c-i> <nop>

" automatically enter insert mode
autocmd BufWinEnter,WinEnter term://* startinsert

" Exclude terminal from buffer list
autocmd TermOpen * set nobuflisted
autocmd TermOpen * noremap <buffer> <tab> <nop>
autocmd TermOpen * noremap <buffer> <s-tab> <nop>

" Disable terminal line numbers
au TermOpen * setlocal nonumber norelativenumber

" ---------------------------------------------------------------------------
"  airline
" ---------------------------------------------------------------------------
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
"let g:airline_theme = 'hybrid'
"let g:airline_theme = 'bubblegum'
"let g:airline_theme = 'zenburn'
"let g:airline_theme='quantum'
"let g:airline_theme = 'hybridline'
let g:airline_theme = 'tender'

" ---------------------------------------------------------------------------
"  dragvisuals.vim
" ---------------------------------------------------------------------------
"vmap  <expr>  <LEFT>   DVB_Drag('left')
"vmap  <expr>  <RIGHT>  DVB_Drag('right')
"vmap  <expr>  <DOWN>   DVB_Drag('down')
"vmap  <expr>  <UP>     DVB_Drag('up')

" freezes up...
" vmap  <expr>  D        DVB_Duplicate()


" Remove any introduced trailing whitespace after moving...
"let g:DVB_TrimWS = 1


" ---------------------------------------------------------------------------
"  colorizer
" ---------------------------------------------------------------------------
let g:colorizer_startup = 0

" ---------------------------------------------------------------------------
"  colorscheme-switcher.vim
" ---------------------------------------------------------------------------
let g:colorscheme_switcher_exclude = [
            \'blue', 'darkblue', 'default', 'delek', 'desert', 'elflord',
            \'evening', 'fi', 'gotham256', 'hybrid', 'hybrid-light', 'industry', 'koehler',
            \'morning', 'murphy', 'pablo', 'peachpuff', 'ron', 'shine', 'slate', 'torte', 'zellner']

" ---------------------------------------------------------------------------
"  gundo.vim
" ---------------------------------------------------------------------------
nnoremap <F5> :GundoToggle<CR>

" ---------------------------------------------------------------------------
"  incsearch.vim
"  2016/12/17 - disabling for now due to memory leak
" ---------------------------------------------------------------------------
"map /  <Plug>(incsearch-forward)
"map ?  <Plug>(incsearch-backward)
"map g/ <Plug>(incsearch-stay)

"" Compatibility with vim-indexed-search
"let g:indexed_search_mappings = 0
"augroup incsearch-indexed
"    autocmd!
"    autocmd User IncSearchLeave ShowSearchIndex
"augroup END

"nnoremap <silent>n nzv:ShowSearchIndex<CR>
"nnoremap <silent>N Nzv:ShowSearchIndex<CR>

"" Enable automatic :nohlsearch with index-search compatibility
"let g:incsearch#auto_nohlsearch = 1
"map n  <Plug>(incsearch-nohl-n)zv:ShowSearchIndex<CR>
"map N  <Plug>(incsearch-nohl-N)zv:ShowSearchIndex<CR>
"map *  <Plug>(incsearch-nohl-*)
"map #  <Plug>(incsearch-nohl-#)
"map g* <Plug>(incsearch-nohl-g*)
"map g# <Plug>(incsearch-nohl-g#)

" ---------------------------------------------------------------------------
" indent guides
" ---------------------------------------------------------------------------
let g:indent_guides_auto_colors = 0
let g:indent_guides_start_level = 2
let g:indent_guides_guide_size  = 1

autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd  guibg=black   ctermbg=black
autocmd VimEnter,Colorscheme * :hi IndentGuidesEven guibg=darkgrey ctermbg=darkgrey

" ---------------------------------------------------------------------------
"  NERDTree
" ---------------------------------------------------------------------------
map <C-n> :NERDTreeToggle<CR>

" ---------------------------------------------------------------------------
"  NERDcommenter
" ---------------------------------------------------------------------------
let g:NERDDefaultAlign = 'left'

" ---------------------------------------------------------------------------
"  vpaste.net
" ---------------------------------------------------------------------------
map vp :exec "w !vpaste ft=".&ft<CR>
vmap vp <ESC>:exec "'<,'>w !vpaste ft=".&ft<CR>

" ---------------------------------------------------------------------------
"  vim-signature
" ---------------------------------------------------------------------------

" Unmap `] and `[ to allow for navigation to last yanked text, etc.
let g:SignatureMap = {
    \ 'Leader'             :  "m",
    \ 'PlaceNextMark'      :  "m,",
    \ 'ToggleMarkAtLine'   :  "m.",
    \ 'PurgeMarksAtLine'   :  "m-",
    \ 'DeleteMark'         :  "dm",
    \ 'PurgeMarks'         :  "m<Space>",
    \ 'PurgeMarkers'       :  "m<BS>",
    \ 'GotoNextLineAlpha'  :  "']",
    \ 'GotoPrevLineAlpha'  :  "'[",
    \ 'GotoNextSpotAlpha'  :  "",
    \ 'GotoPrevSpotAlpha'  :  "",
    \ 'GotoNextLineByPos'  :  "]'",
    \ 'GotoPrevLineByPos'  :  "['",
    \ 'GotoNextSpotByPos'  :  "]`",
    \ 'GotoPrevSpotByPos'  :  "[`",
    \ 'GotoNextMarker'     :  "[+",
    \ 'GotoPrevMarker'     :  "[-",
    \ 'GotoNextMarkerAny'  :  "]=",
    \ 'GotoPrevMarkerAny'  :  "[=",
    \ 'ListLocalMarks'     :  "m/",
    \ 'ListLocalMarkers'   :  "m?"
    \ }

" ---------------------------------------------------------------------------
"  snipmate.vim
" ---------------------------------------------------------------------------
let g:snips_author = "Keith Hughitt"
let g:snips_email  = "user@email.com"
let g:snips_github = "https://github.com/khughitt"
let g:snipMate = {}
let g:snipMate.scope_aliases = {}
let g:snipMate.scope_aliases['rmd'] = 'r,r-extra,rmd'

" ---------------------------------------------------------------------------
"  Supertab
" ---------------------------------------------------------------------------
let g:SuperTabDefaultCompletionType = "context"
let g:SuperTabNoCompleteAfter  = ['^', ',', '\s', '"', "'"]
let g:SuperTabNoCompleteBefore = ['\S']
highlight Pmenu ctermbg=234 ctermfg=198

" ---------------------------------------------------------------------------
"  denite
" ---------------------------------------------------------------------------

" Ag recursive file list settings    (<C-p>)
call denite#custom#var('file/rec', 'command', 
        \ ['ag', '--follow', '--nocolor', '--nogroup', '--ignore', '*.pyc', '*.png', '*.RData', '-g', ''])

" Ag command on grep source settings (<leader>/)
call denite#custom#var('grep', 'command', ['ag'])
call denite#custom#var('grep', 'default_opts', ['-i', '--vimgrep'])
call denite#custom#var('grep', 'recursive_opts', [])
call denite#custom#var('grep', 'pattern_opt', [])
call denite#custom#var('grep', 'separator', ['--'])
call denite#custom#var('grep', 'final_opts', [])

" Change ignore_globs
call denite#custom#filter('matcher/ignore_globs', 'ignore_globs',
        \ [ '.git/', '.ropeproject/', '__pycache__/',
        \   'venv/', 'images/', '*.min.*', 'img/', 'fonts/', '*cache/', '*_files/'])

" reset 50% winheight on window resize
augroup deniteresize
  autocmd!
  autocmd VimResized,VimEnter * call denite#custom#option('default', 'winheight', winheight(0) / 2)
augroup end

call denite#custom#option('default', { 'prompt': '❯' })

call denite#custom#map('insert', '<Esc>', '<denite:enter_mode:normal>',       'noremap')
call denite#custom#map('normal', '<Esc>', '<NOP>',                            'noremap')
call denite#custom#map('insert', '<C-v>', '<denite:do_action:vsplit>',        'noremap')
call denite#custom#map('normal', '<C-v>', '<denite:do_action:vsplit>',        'noremap')
call denite#custom#map('normal', 'dw',    '<denite:delete_word_after_caret>', 'noremap')

nnoremap <C-p>     :<C-u>Denite file_rec<CR>
nnoremap <leader>d :<C-u>DeniteBufferDir file_rec<CR>
nnoremap <leader>o :<C-u>Denite file_old<CR>
nnoremap <leader>r :<C-u>Denite -resume -cursor-pos=+1<CR>
nnoremap <leader>s :<C-u>Denite buffer<CR>
nnoremap <leader>8 :<C-u>DeniteCursorWord grep:. -mode=normal<CR>
nnoremap <leader>/ :<C-u>Denite grep:. -mode=normal<CR>
nnoremap <leader><Space>s :<C-u>DeniteBufferDir buffer<CR>
nnoremap <leader><Space>/ :<C-u>DeniteBufferDir grep:. -mode=normal<CR>

hi link deniteMatchedChar Special

" ---------------------------------------------------------------------------
"  fzf.vim
" ---------------------------------------------------------------------------
let g:fzf_layout = { 'window': 'enew' }
"let g:fzf_layout = { 'window': '-tabnew' }
"let g:fzf_layout = { 'window': '10split enew' }
"let g:fzf_layout = { 'down': '~40%' }

cmap <C-r> History:<CR>

nmap <leader><tab> <plug>(fzf-maps-n)
xmap <leader><tab> <plug>(fzf-maps-x)
omap <leader><tab> <plug>(fzf-maps-o)

imap <c-x><c-k> <plug>(fzf-complete-word)
imap <c-x><c-f> <plug>(fzf-complete-path)
imap <c-x><c-j> <plug>(fzf-complete-file-ag)
imap <c-x><c-l> <plug>(fzf-complete-line)

let g:fzf_colors =
\ { 'fg':      ['fg', 'Normal'],
  \ 'bg':      ['bg', 'Normal'],
  \ 'hl':      ['fg', 'Comment'],
  \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
  \ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],
  \ 'hl+':     ['fg', 'Statement'],
  \ 'info':    ['fg', 'PreProc'],
  \ 'border':  ['fg', 'Ignore'],
  \ 'prompt':  ['fg', 'Conditional'],
  \ 'pointer': ['fg', 'Exception'],
  \ 'marker':  ['fg', 'Keyword'],
  \ 'spinner': ['fg', 'Label'],
  \ 'header':  ['fg', 'Comment'] }

" ---------------------------------------------------------------------------
"  yankring.vim
" ---------------------------------------------------------------------------
"let g:yankring_replace_n_pkey = '<C-up>'
"let g:yankring_replace_n_nkey = '<C-down>'
"let g:yankring_history_dir = '$HOME/.vim/tmp/yankring'
"

"
"
let g:gutentags_exclude_project_root = ['/usr/local', '/cbcb/sw']

" ---------------------------------------------------------------------------
"  syntastic
" ---------------------------------------------------------------------------
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_mode_map = {'mode': 'passive'}

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 0
let g:syntastic_check_on_wq = 0

"nnoremap <F10> :SyntasticCheck<CR> :SyntasticToggleMode<CR> :w<CR>
nnoremap <F10> :SyntasticCheck<CR>

" r
let g:syntastic_enable_r_lintr_checker = 1
let g:syntastic_r_checkers = ['lintr']
let g:syntastic_rmd_checkers = ['lintr']
let g:syntastic_r_lintr_linters = "with_defaults(line_length_linter(120),single_quotes_linter=NULL,commented_code_linter=NULL,object_name_linter=NULL)"

"let g:syntastic_debug = 33

" python
let g:syntastic_rst_checkers=['sphinx']

" ---------------------------------------------------------------------------
"  tagbar
" ---------------------------------------------------------------------------
nmap <F9> :TagbarToggle<CR>

let g:tagbar_type_r = {
    \ 'ctagstype' : 'r',
    \ 'kinds'     : [
        \ 'f:Functions',
        \ 'g:GlobalVariables',
        \ 'v:FunctionVariables',
    \ ]
\ }

" ---------------------------------------------------------------------------
"  Strip all trailing whitespace in file
" ---------------------------------------------------------------------------

function! StripWhitespace ()
    exec ':%s/ \+$//gc'
endfunction
map ,s :call StripWhitespace ()<CR>
"autocmd FileType python,php,js,rb,r,rmd
"    \ autocmd BufWritePre <buffer> :%s/\s\+$//e

" ---------------------------------------------------------------------------
"  Search Options
" ---------------------------------------------------------------------------
set wrapscan   " search wrap around the end of the file
set ignorecase " ignore case search
set smartcase  " override 'ignorecase' if the search pattern contains upper case
nohlsearch     " avoid highlighting when reloading vimrc

" stop  highlighting
nnoremap <leader>n :nohl<CR>
"nnoremap <silent> <C-l> :nohl<CR><C-l>

" ---------------------------------------------------------------------------
"  Language-specific Options
" ---------------------------------------------------------------------------

" Language-specific options
autocmd FileType ruby,eruby,yaml,r,rmd,jinja setlocal softtabstop=2 shiftwidth=2 tabstop=2
autocmd BufRead,BufNewFile *.md set filetype=markdown nofoldenable
autocmd BufRead,BufNewFile *.py set autoindent

" Languge-specific color schemes
autocmd FileType yaml colorscheme sweyla907357
autocmd FileType jinja colorscheme SerialExperimentsLain
autocmd FileType snakemake colorscheme gotham
"autocmd FileType rmd colorscheme grb256

" R
let vimrplugin_objbr_place = "console,right"

" Fix issue relating to setwidth
" https://github.com/jalvesaq/Nvim-R/issues/81#issuecomment-262651872
let R_setwidth = 0

" split editor and console top/bottom
let R_rconsole_width = 0

" Force use of colorout for highlighting terminal
let R_hl_term = 0

" devtools load all shortcut
map ;dl :RLoadPackage<CR>

" Emulate Tmux ^az
function ZoomWindow()
    let cpos = getpos(".")
    tabnew %
    redraw
    call cursor(cpos[1], cpos[2])
    normal! zz
endfunction
nmap gz :call ZoomWindow()<CR>

" Exclude object browser from buffer list
autocmd BufEnter Object_Browser set nobuflisted

" development
"let R_path = '/usr/local/bin/'
"let R_cmd = 'R-devel'

" disable <- shortcut
let R_assign = 0

" enable PDF/Browser support when available
if $DISPLAY != ""
    let R_pdfviewer = 'evince'
    let vimrplugin_openpdf = 1
    let vimrplugin_openhtml = 1
endif

" highlight chunk headers
let rrst_syn_hl_chunk = 1
let rmd_syn_hl_chunk = 1

" libraries to always include for autocompletion
let vimrplugin_start_libs = "base,stats,graphics,grDevices,utils,methods,Biobase,igraph,tidyverse"

" press enter and space bar to send lines and selection to R
vmap <Space> <Plug>RDSendSelection
nmap <Space> <Plug>RDSendLine
vmap <C-M> <Plug>RDSendSelection
nmap <C-M> <Plug>RDSendLine

nmap <silent> <LocalLeader>h :call RAction("hh", "@,48-57,_,.")<CR>

" wipe knitr cache and output
nmap <localleader>kc :call g:SendCmdToR('rm(list=ls(all.names=TRUE)); unlink("*_cache/*", recursive=TRUE)')<CR>

" render markdown
nmap <localleader>km :call RMakeRmd("md_document")<CR>

" show source code for function under cursor
function ShowRSource()
    let g:function_name = expand("<cword>")
    echom "Showing source code for function: \"" . g:function_name . "\""
    enew
    set syntax=r
    execute ":Rinsert " . g:function_name
endfunction

nmap <localleader>sc :call ShowRSource()<CR>

" https://github.com/plasticboy/vim-markdown/issues/162
"let g:vim_markdown_folding_disabled=1

" nvim-ipy
let g:nvim_ipy_perform_mappings = 0

" note: <c-w> <c-r> swaps two vertical buffers
vmap <Silent><Space> <Plug>(IPy-Run)
nmap <Silent><Space> <Plug>(IPy-Run)
vmap <Silent><C-M> <Plug>(IPy-Run) 
nmap <Silent><C-M> <Plug>(IPy-Run) 

autocmd Filetype python nmap <localleader>rf :IPython<cr>

" Snakemake syntax highlighting
au BufNewFile,BufRead Snakefile set syntax=snakemake
au BufNewFile,BufRead *.snakefile set syntax=snakemake

" iron / ipython
"autocmd Filetype python vmap <Space> <Plug>(iron-send-motion)
"autocmd Filetype python nmap <Space> <Plug>(iron-send-motion)
"autocmd Filetype python vmap <C-M> <Plug>(iron-send-motion)
"autocmd Filetype python nmap <C-M> <Plug>(iron-send-motion)

"autocmd Filetype python nmap <localleader>rf :IronRepl<cr>

" CSV
let g:csv_no_conceal = 1

" Host-specific configuration
" http://effectif.com/vim/host-specific-vim-config
let hostfile=$XDG_CONFIG_HOME . '/nvim/' . substitute(hostname(), "\\..*", "", "") . '-local.vim'
if filereadable(hostfile)
    exe 'source ' . hostfile
endif

" Syntax highlighting
syntax on
