" General
set nocompatible    " disable vi compatibility enchancements
set showmatch       " highlight correspods character
set cursorline      " highlight current line
set nomodeline      "
filetype indent on  " indent based on filetype
set ruler           " show the cursor position all the time
set backspace=indent,eol,start " more powerful backspacing

" Indentation
set tabstop=4 shiftwidth=4 softtabstop=4 " set tab width
set expandtab   " use space instead of tab
set smartindent " use smart indent
set history=100 " number of command history

" Appearance
set t_Co=256
if has("gui_running")
    " theme
    set background=dark
    colorscheme torte
    " Make shift-insert work like in Xterm
    map <S-Insert> <MiddleMouse>
    map! <S-Insert> <MiddleMouse>

else
    colorscheme delek
endif

" We know xterm-debian is a color terminal
"if &term =~ "xterm-debian" || &term =~ "xterm-xfree86"
"  set t_Co=16
"  set t_Sf=[3%dm
"  set t_Sb=[4%dm
"endif

if has("syntax")
  syntax on
endif

" Search
set wrapscan   " search wrap around the end of the file
set ignorecase " ignore case search
set smartcase  " override 'ignorecase' if the search pattern contains upper case
set incsearch  " incremental search
set hlsearch   " highlight searched words
nohlsearch     " avoid highlighting when reloading vimrc

" Python
autocmd BufRead,BufNewFile *.py syntax on
autocmd BufRead,BufNewFile *.py set ai

" Ruby
autocmd FileType ruby,eruby,yaml setlocal softtabstop=2 shiftwidth=2 tabstop=2

