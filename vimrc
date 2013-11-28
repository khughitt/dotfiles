" ---------------------------------------------------------------------------
" Vim Configuration
" 
" Much of the awesome functionality and settings in this file has come from
" other dotfile on Github, and also from http://amix.dk/vim/vimrc.html.
"
" ---------------------------------------------------------------------------

" ---------------------------------------------------------------------------
" General
" ---------------------------------------------------------------------------
set nocompatible     " disable vi compatibility enchancements
set hidden           " easy buffer switching
set history=5000     " number of command history
set isk+=_,$,@,%,#,- " none word dividers
set showmatch        " highlight correspods character
set cursorline       " highlight current line
set modeline         " make sure modeline support is enabled
set noerrorbells     " quiet, please
set nofoldenable     " disable folding
filetype indent on   " indent based on filetype
filetype plugin on   " enable filetype-specific plugin loading

" Omnicompletion
set ofu=syntaxcomplete#Complete

" With a map leader it's possible to do extra key combinations
" like <leader>w saves the current file
let maplocalleader = ","
let mapleader = ";"
let g:mapleader = ";"

" Fast save
nmap <leader>w :w!<cr>

" Pathogen
execute pathogen#infect()

" ----------------------------------------------------------------------------
" Practice time
" ----------------------------------------------------------------------------
map <Left> <Nop>
map <Right> <Nop>
map <Up> <Nop>
map <Down> <Nop>

" ----------------------------------------------------------------------------
"   Highlight Trailing Whitespace
" ----------------------------------------------------------------------------

set list listchars=trail:.,tab:>.
highlight SpecialKey ctermfg=DarkGray ctermbg=Black

" ----------------------------------------------------------------------------
"  Backups
" ----------------------------------------------------------------------------

set nobackup                           " do not keep backups after close
set nowritebackup                      " do not keep a backup while working
set noswapfile                         " don't keep swp files either
set backupdir=$HOME/.vim/backup        " store backups under ~/.vim/backup
set backupcopy=yes                     " keep attributes of original file
set backupskip=/tmp/*,$TMPDIR/*,$TMP/*,$TEMP/*
set directory=~/.vim/swap,~/tmp,.      " keep swp files under ~/.vim/swap

" ----------------------------------------------------------------------------
"  UI
" ----------------------------------------------------------------------------
set so=7                    " stop scrolling when we get seven lines within top or bottom
set wildmenu                " enable wildmenu (easy buffer switching, etc)
set wildignore=*.o,*~,*.pyc " ignore compiled files
"set ruler                   " show the cursor position all the time
set noshowcmd               " don't display incomplete commands
set nolazyredraw            " turn off lazy redraw
set number                  " line numbers
"set ch=2                    " command line height
set backspace=2             " allow backspacing over everything in insert mode
set whichwrap+=<,>,h,l,[,]  " backspace and cursor keys wrap to
set shortmess=filtIoOA      " shorten messages
set report=0                " tell us about changes
set nostartofline           " don't jump to the start of line when scrolling

" ----------------------------------------------------------------------------
" Visual Cues
" ----------------------------------------------------------------------------
set showmatch              " brackets/braces that is
set mat=5                  " duration to show matching brace (1/10 sec)
set incsearch              " do incremental searching
set laststatus=2           " always show the status line
set ignorecase             " ignore case when searching
set novisualbell           " no thank you

if exists('+colorcolumn')
    set colorcolumn=80         " show right margin
endif

let marksCloseWhenSelected = 0
let showmarks_include="abcdefghijklmnopqrstuvwxyz"

" ----------------------------------------------------------------------------
" Text Formatting
" ----------------------------------------------------------------------------

set autoindent             " automatic indent new lines
"disablign smart-indent: may be preventing comments from indenting?
"http://stackoverflow.com/questions/191201/indenting-comments-to-match-code-in-vim
"set smartindent            " be smart about it 
set nowrap                 " do not wrap lines
set softtabstop=4          " tab width
set shiftwidth=4           " 
set tabstop=4
set expandtab              " expand tabs to spaces
set nosmarttab             " no tabs
set textwidth=79           " stick to less than 80 chars per line when possible
set formatoptions+=n       " support for numbered/bullet lists
set virtualedit=block      " allow virtual edit in visual block ..
set encoding=utf8          " UTF-8 by default
set pastetoggle=<F2>       " quickly toggle paste mode before pasting text

" ----------------------------------------------------------------------------
" Moving around, tabs, windows and buffers
" ----------------------------------------------------------------------------

" Treat long lines as break lines (useful when moving around in them)
map j gj
map k gk

" Map <Space> to / (search) and Ctrl-<Space> to ? (backwards search)
" map <space> /
" map <c-space> ?

" Smart way to move between windows
" map <C-j> <C-W>j
" map <C-k> <C-W>k
" map <C-h> <C-W>h
" map <C-l> <C-W>l

" Close the current buffer
map <leader>bd :Bclose<cr>

" Close all the buffers
map <leader>ba :1,1000 bd!<cr>

" Useful mappings for managing tabs
map <leader>tn :tabnew<cr>
map <leader>to :tabonly<cr>
map <leader>tc :tabclose<cr>
map <leader>tm :tabmove

" Opens a new tab with the current buffer's path
" Super useful when editing files in the same directory
map <leader>te :tabedit <c-r>=expand("%:p:h")<cr>/

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

" tmux mouse support
set mouse=a

" ---------------------------------------------------------------------------
"  Appearance
" ---------------------------------------------------------------------------
if $TERM != 'linux'
    set t_Co=256
endif

" fix background bleeding in screen
" http://sunaku.github.io/vim-256color-bce.html
:set t_ut=""

" let g:hybrid_use_Xresources = 1

if has("gui_running")
    " theme
    colorscheme jellybeans

    " font
    set guifont=DejaVu\ Sans\ Mono\ for\ Powerline\ 12

    "set background=dark
    " Make shift-insert work like in Xterm
    map <S-Insert> <MiddleMouse>
    map! <S-Insert> <MiddleMouse>
else
    colorscheme jellybeans
    "set background=dark
endif

if has("syntax")
    syntax on
endif

" Matching parens style
hi MatchParen cterm=bold ctermbg=none ctermfg=red

" ---------------------------------------------------------------------------
"  Powerline
" ---------------------------------------------------------------------------
let g:Powerline_symbols = 'fancy'

" ---------------------------------------------------------------------------
"  NERDTree
" ---------------------------------------------------------------------------
map <C-n> :NERDTreeToggle<CR>

" ---------------------------------------------------------------------------
"  vpaste
" ---------------------------------------------------------------------------
map vp :exec "w !vpaste ft=".&ft<CR>
vmap vp <ESC>:exec "'<,'>w !vpaste ft=".&ft<CR>

" ---------------------------------------------------------------------------
"  Strip all trailing whitespace in file
" ---------------------------------------------------------------------------

"function! StripWhitespace ()
"    exec ':%s/ \+$//gc'
"endfunction
"map ,s :call StripWhitespace ()<CR>
autocmd FileType py,php,js,rb,r autocmd BufWritePre <buffer> :%s/\s\+$//e

" ---------------------------------------------------------------------------
"  Search Options
" ---------------------------------------------------------------------------
set wrapscan   " search wrap around the end of the file
set ignorecase " ignore case search
set smartcase  " override 'ignorecase' if the search pattern contains upper case
set incsearch  " incremental search
set hlsearch   " highlight searched words
nohlsearch     " avoid highlighting when reloading vimrc

" ---------------------------------------------------------------------------
"  Language-specific Options
" ---------------------------------------------------------------------------

" Python
let $PYTHONPATH="/usr/lib/python3.3/site-packages"
autocmd BufRead,BufNewFile *.py syntax on
autocmd BufRead,BufNewFile *.py set ai
map <F8> :w\|!python %<CR>

" R
let vimrplugin_objbr_place = "console,right"
let vimrplugin_term = "urxvt"
let vimrplugin_assign = 0

if $DISPLAY != ""
    let vimrplugin_openpdf = 1
    let vimrplugin_openhtml = 1
endif

if has("gui_running")
    inoremap <C-Space> <C-x><C-o>
else
    inoremap <Nul> <C-x><C-o>
endif

" Knitr
vmap <Space> <Plug>RDSendSelection
vmap <C-M> <Plug>RDSendSelection
nmap <C-M> <Plug>RDSendLine
nmap <C-A-c> <Plug>RDSendChunk

" KnitrBootstrap
function! RMakeHTML_2()
  update
  call RSetWD()
  let filename = expand("%:r:t")
  let rcmd = "require('knitrBootstrap');
    \knit_bootstrap(\"" . filename . ".rmd\")"
  if g:vimrplugin_openhtml
    let rcmd = rcmd . '; browseURL("' . filename . '.html")'
  endif
  call g:SendCmdToR(rcmd)
endfunction

nnoremap <silent> <localleader>kk :call RMakeHTML_2()<CR>

" Ruby
autocmd FileType ruby,eruby,yaml setlocal softtabstop=2 shiftwidth=2 tabstop=2

" Markdown
autocmd BufRead,BufNewFile *.md set filetype=markdown background=light nofoldenable
autocmd FileType markdown colorscheme hybrid-light

