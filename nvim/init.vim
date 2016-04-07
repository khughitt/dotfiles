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

" Syntax highlighting
syntax on

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

" Disable macro recording
map q <nop>

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
    Plug 'airblade/vim-gitgutter'
    Plug 'bkad/CamelCaseMotion'
    Plug 'chrisbra/csv.vim'
    Plug 'ervandew/supertab'
    Plug 'garbas/vim-snipmate'
    Plug 'henrik/vim-indexed-search'
    Plug 'honza/vim-snippets'
    Plug 'jalvesaq/Nvim-R'
    Plug 'junegunn/goyo.vim'
    Plug 'junegunn/limelight.vim'
    Plug 'kshenoy/vim-signature'
    Plug 'machakann/vim-textobj-delimited'
    Plug 'MarcWeber/vim-addon-mw-utils'
    Plug 'mhartington/oceanic-next'
    Plug 'nathanaelkane/vim-indent-guides'
    Plug 'qpkorr/vim-bufkill'
    Plug 'scrooloose/nerdcommenter'
    Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }
    Plug 'Shougo/neomru.vim'
    Plug 'Shougo/unite.vim'
    Plug 'Shougo/vimproc.vim', { 'do': 'make' }
    Plug 'tomtom/tlib_vim'
    Plug 'tpope/vim-surround'
    Plug 'vim-airline/vim-airline'
    Plug 'vim-airline/vim-airline-themes'
    Plug 'vim-scripts/argtextobj.vim'
    Plug 'whatyouhide/vim-gotham'
    Plug 'xolox/vim-misc'
    Plug 'xolox/vim-colorscheme-switcher'
call plug#end()

" ----------------------------------------------------------------------------
"   Highlight Trailing Whitespace
" ----------------------------------------------------------------------------

"set listchars=tab:>\ ,trail:-,extends:>,precedes:<,nbsp:+
highlight SpecialKey ctermfg=DarkGray ctermbg=Black

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
set colorcolumn=80         " show right margin

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
set shiftwidth=4            "
set shiftround              " round indents to multiple of shift width
set tabstop=4
set expandtab               " expand tabs to spaces
"set nosmarttab              " no tabs
set textwidth=79            " stick to less than 80 chars per line when possible
set formatoptions+=n        " support for numbered/bullet lists
set virtualedit=block       " allow virtual edit in visual block ..
set pastetoggle=<F6>        " paste-mode toggle

" Shortuct to toggle textwidth wrapping
"nmap <silent><localleader>r :call ToggleTextWidth()<CR>
function! ToggleTextWidth()
  if &textwidth != 0
    let b:oldtextwidth = &textwidth
    set textwidth=0
  elseif exists("b:oldtextwidth")
    let &textwidth = b:oldtextwidth
  else
    set textwidth=79
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

" Return to last edit position when opening files
autocmd BufReadPost *
    \ if line("'\"") > 0 && line("'\"") <= line("$") |
    \   exe "normal! g`\"" |
    \ endif

" Remember info about open buffers on close
set viminfo^=%

" Enable cursor shape support
let $NVIM_TUI_ENABLE_CURSOR_SHAPE=1

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
set background=dark
colorscheme hemisu
highlight ColorColumn ctermbg=234 guibg=#666666

" terminal color scheme
" https://github.com/metalelf0/oceanic-next
let g:terminal_color_0="#1b2b34"
let g:terminal_color_1="#ed5f67"
let g:terminal_color_2="#9ac895"
let g:terminal_color_3="#fbc963"
let g:terminal_color_4="#669acd"
let g:terminal_color_5="#c695c6"
let g:terminal_color_6="#5fb4b4"
let g:terminal_color_7="#c1c6cf"
let g:terminal_color_8="#65737e"
let g:terminal_color_9="#fa9257"
let g:terminal_color_10="#343d46"
let g:terminal_color_11="#4f5b66"
let g:terminal_color_12="#a8aebb"
let g:terminal_color_13="#ced4df"
let g:terminal_color_14="#ac7967"
let g:terminal_color_15="#d9dfea"
"let g:terminal_color_background="#1b2b34"
let g:terminal_color_background="#525252"
let g:terminal_color_foreground="#c1c6cf"

" Matching parens style
hi MatchParen cterm=bold ctermbg=none ctermfg=red

" Highlight color
hi Search ctermbg=197 ctermfg=233

" ---------------------------------------------------------------------------
"  Copy and Paste
" ---------------------------------------------------------------------------

" Remap vim register to CLIPBOARD selection
" unamed        PRIMARY   (middlemouse)
" unamedplus    CLIPBOARD (control v)
" autoselect    Automatically save visual selections
"set clipboard=unnamed,autoselect
set clipboard=unnamed

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

" automatically enter insert mode
autocmd BufWinEnter,WinEnter term://* startinsert

" Exclude from buffer list
autocmd TermOpen * set nobuflisted

" ---------------------------------------------------------------------------
"  airline
" ---------------------------------------------------------------------------
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
"let g:airline_theme = 'hybrid'
"let g:airline_theme = 'bubblegum'
"let g:airline_theme = 'zenburn'

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
"  goyo.vim
" ---------------------------------------------------------------------------
function! GoyoBefore()
  Limelight
endfunction

function! GoyoAfter()
  Limelight!
  set background=dark
  colorscheme hemisu
endfunction

let g:goyo_callbacks = [function('GoyoBefore'), function('GoyoAfter')]

nnoremap <leader><space> :Goyo<CR>

" ---------------------------------------------------------------------------
"  gundo.vim
" ---------------------------------------------------------------------------
nnoremap <F5> :GundoToggle<CR>

" ---------------------------------------------------------------------------
"  incsearch.vim (2016/03/16: not yet compatible with Neovim)
" ---------------------------------------------------------------------------
"map /  <Plug>(incsearch-forward)
"map ?  <Plug>(incsearch-backward)
"map g/ <Plug>(incsearch-stay)

" Compatibility with vim-indexed-search
"let g:indexed_search_mappings = 0
"augroup incsearch-indexed
"    autocmd!
"    autocmd User IncSearchLeave ShowSearchIndex
"augroup END

"nnoremap <silent>n nzv:ShowSearchIndex<CR>
"nnoremap <silent>N Nzv:ShowSearchIndex<CR>

" Enable automatic :nohlsearch with index-search compatibility
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
"  Unite.vim
"  http://bling.github.io/blog/2013/06/02/unite-dot-vim-the-plugin-you-didnt-know-you-need/
" ---------------------------------------------------------------------------
call unite#filters#matcher_default#use(['matcher_fuzzy'])
call unite#filters#sorter_default#use(['sorter_rank'])
"call unite#set_profile('files', 'smartcase', 1)
call unite#custom#profile('files', 'context.smartcase', 1)
call unite#custom#source('file_rec/async','sorters','sorter_rank', )

"let g:unite_data_directory=s:get_cache_dir('unite')
let g:unite_data_directory='~/.config/nvim/tmp/unite'
let g:unite_enable_start_insert=1
let g:unite_source_history_yank_enable=1
let g:unite_source_rec_max_cache_files=5000
let g:unite_prompt='» '
let g:unite_split_rule = 'botright'

if executable('ag')
    " Use ag in unite grep source.
    let g:unite_source_grep_command = 'ag'
    let g:unite_source_grep_default_opts =
    \ "-i --line-numbers --nocolor --nogroup --hidden --ignore '.hg' " .
    \ "--ignore '.svn' --ignore '.git' --ignore '.bzr' " .
    \ "--ignore 'README_cache' --ignore '.html' "
    let g:unite_source_grep_recursive_opt = ''
endif

nmap <space> [unite]
nnoremap [unite] <nop>

" cnrlp
nnoremap <c-p> :Unite file file_mru file_rec/async<cr>

" ack / grep
nnoremap <space>/ :Unite grep:.<cr>

" buffer switching
nnoremap <space>s :Unite -quick-match buffer<cr>

" yank history
nnoremap <space>y :Unite history/yank<cr>

nnoremap <silent> [unite]e :<C-u>Unite -buffer-name=recent file_mru<cr>
nnoremap <silent> [unite]y :<C-u>Unite -buffer-name=yanks history/yank<cr>
nnoremap <silent> [unite]l :<C-u>Unite -auto-resize -buffer-name=line line<cr>
nnoremap <silent> [unite]b :<C-u>Unite -auto-resize -buffer-name=buffers buffer<cr>
nnoremap <silent> [unite]/ :<C-u>Unite -no-quit -buffer-name=search grep:.<cr>
nnoremap <silent> [unite]m :<C-u>Unite -auto-resize -buffer-name=mappings mapping<cr>
nnoremap <silent> [unite]s :<C-u>Unite -quick-match buffer<cr>

" ---------------------------------------------------------------------------
"  yankring.vim
" ---------------------------------------------------------------------------
"let g:yankring_replace_n_pkey = '<C-up>'
"let g:yankring_replace_n_nkey = '<C-down>'
"let g:yankring_history_dir = '$HOME/.vim/tmp/yankring'

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
autocmd FileType ruby,eruby,yaml setlocal softtabstop=2 shiftwidth=2 tabstop=2
autocmd BufRead,BufNewFile *.md set filetype=markdown nofoldenable
autocmd BufRead,BufNewFile *.py set autoindent

" R
let vimrplugin_objbr_place = "console,right"

" Exclude object browser from buffer list
autocmd BufEnter Object_Browser set nobuflisted

" development
"let vimrplugin_r_path='/usr/local/bin/R-devel'

" disable <- shortcut
let R_assign = 0

" enable PDF/Browser support when available
if $DISPLAY != ""
    if executable('zathura')
        let vimrplugin_openpdf = 1
    endif
    let vimrplugin_openhtml = 1
endif

" highlight chunk headers
let rrst_syn_hl_chunk = 1
let rmd_syn_hl_chunk = 1

" libraries to always include for autocompletion
let vimrplugin_start_libs = "base,stats,graphics,grDevices,utils,methods,Biobase,ggplot2,dplyr,igraph,reshape2,preprocessCore,WGCNA"

" press enter and space bar to send lines and selection to R
vmap <Space> <Plug>RDSendSelection
nmap <Space> <Plug>RDSendLine
vmap <C-M> <Plug>RDSendSelection
nmap <C-M> <Plug>RDSendLine

" Knitr
"nmap <C-A-c> <Plug>RDSendChunk

" wipe knitr cache and output
nmap <localleader>kc :call g:SendCmdToR('rm(list=ls(all.names=TRUE)); unlink("README_cache/*", recursive=TRUE)')<CR>

" https://github.com/plasticboy/vim-markdown/issues/162
"let g:vim_markdown_folding_disabled=1

" CSV
let g:csv_no_conceal = 1

