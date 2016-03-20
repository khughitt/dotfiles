syntax on
filetype plugin indent on

"------------------------------------
" Behavior
"------------------------------------
let maplocalleader = ","
let mapleader = ";"

"------------------------------------
" Search
"------------------------------------
set infercase
set hlsearch
set incsearch

"------------------------------------
" Nvim-R
"------------------------------------
if has("gui_running")
    inoremap <C-Space> <C-x><C-o>
else
    inoremap <Nul> <C-x><C-o>
endif
vmap <Space> <Plug>RDSendSelection
nmap <Space> <Plug>RDSendLine


call plug#begin()
    Plug 'jalvesaq/Nvim-R'
call plug#end()
