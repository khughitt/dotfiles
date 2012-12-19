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
set history=1000     " number of command history
set isk+=_,$,@,%,#,- " none word dividers
set showmatch        " highlight correspods character
set cursorline       " highlight current line
set modeline         " make sure modeline support is enabled
set noerrorbells     " quiet, please
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
set ruler                   " show the cursor position all the time
set noshowcmd               " don't display incomplete commands
set nolazyredraw            " turn off lazy redraw
set number                  " line numbers
set ch=2                    " command line height
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
set colorcolumn=80         " show right margin

let marksCloseWhenSelected = 0
let showmarks_include="abcdefghijklmnopqrstuvwxyz"

" ----------------------------------------------------------------------------
" Text Formatting
" ----------------------------------------------------------------------------

set autoindent             " automatic indent new lines
set smartindent            " be smart about it
set nowrap                 " do not wrap lines
set softtabstop=4          " tab width
set shiftwidth=4           " 
set tabstop=4
set expandtab              " use space instead of tab
set expandtab              " expand tabs to spaces
set nosmarttab             " no tabs
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
map <space> /
map <c-space> ?

" Smart way to move between windows
map <C-j> <C-W>j
map <C-k> <C-W>k
map <C-h> <C-W>h
map <C-l> <C-W>l

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

" ---------------------------------------------------------------------------
"  Appearance
" ---------------------------------------------------------------------------
set t_Co=256
if has("gui_running")
    " theme
    set background=dark
    colorscheme jellybeans
    " Make shift-insert work like in Xterm
    map <S-Insert> <MiddleMouse>
    map! <S-Insert> <MiddleMouse>

else
    colorscheme jellybeans
endif

if has("syntax")
  syntax on
endif

" Obvious-mode colors
" http://vim.wikia.com/wiki/Xterm256_color_names_for_console_Vim
let g:obviousModeInsertHi = 'term=reverse ctermbg=167 guibg=#d75f5f'         " IndianRed
let g:obviousModeCmdWinHi = 'term=reverse ctermbg=33 guibg=#0087ff'          " DodgerBlue1
let g:obviousModeModifiedCurrentHi = 'term=reverse ctermbg=35 guibg=#00af5f' " SpringGreen3
let g:obviousModeModifiedNonCurrentHi = 'term=reverse ctermbg=35 guibg=#00af5f'
let g:obviousModeModifiedVertSplitHi = 'term=reverse ctermfg=33 ctermbg=35 guifg=darkblue guibg=#00af5f'

" Matching parens style
hi MatchParen cterm=bold ctermbg=none ctermfg=red

"SpringGreen3 ctermfg=35 guifg=#00af5f

" Format the status line
" set statusline=\ %{HasPaste()}%F%m%r%h\ %w\ \ CWD:\ %r%{getcwd()}%h\ \ \ Line:\ %l

" Returns true if paste mode is enabled
function! HasPaste()
    if &paste
            return 'PASTE MODE  '
    en
    return ''
endfunction

" ---------------------------------------------------------------------------
"  Strip all trailing whitespace in file
" ---------------------------------------------------------------------------

"function! StripWhitespace ()
"    exec ':%s/ \+$//gc'
"endfunction
"map ,s :call StripWhitespace ()<CR>
autocmd FileType py,php,js,rb autocmd BufWritePre <buffer> :%s/\s\+$//e

" ---------------------------------------------------------------------------
"  Tab completion
" ---------------------------------------------------------------------------
"function! Smart_TabComplete()
"  let line = getline('.')                         " current line
"
"  let substr = strpart(line, -1, col('.')+1)      " from the start of the current
"                                                  " line to one character right
"                                                  " of the cursor
"  let substr = matchstr(substr, "[^ \t]*$")       " word till cursor
"  if (strlen(substr)==0)                          " nothing to match on empty string
"    return "\<tab>"
"  endif
"  let has_period = match(substr, '\.') != -1      " position of period, if any
"  let has_slash = match(substr, '\/') != -1       " position of slash, if any
"  if (!has_period && !has_slash)
"    return "\<C-X>\<C-P>"                         " existing text matching
"  elseif ( has_slash )
"    return "\<C-X>\<C-F>"                         " file matching
"  else
"    return "\<C-X>\<C-O>"                         " plugin matching
"  endif
"endfunction
"
"inoremap <tab> <c-r>=Smart_TabComplete()<CR>

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
autocmd BufRead,BufNewFile *.py syntax on
autocmd BufRead,BufNewFile *.py set ai
map <F8> :w\|!python %<CR>

" R
let vimrplugin_objbr_place = "console,right"
if $DISPLAY != ""
    let vimrplugin_openpdf = 1
    let vimrplugin_openhtml = 1
endif
if has("gui_running")
    inoremap <C-Space> <C-x><C-o>
else
    inoremap <Nul> <C-x><C-o>
endif
vmap <Space> <Plug>RDSendSelection
nmap <Space> <Plug>RDSendLine

" Ruby
autocmd FileType ruby,eruby,yaml setlocal softtabstop=2 shiftwidth=2 tabstop=2

