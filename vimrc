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
set autoread         " automatically load changes made outside of vim
filetype indent on   " indent based on filetype
filetype plugin on   " enable filetype-specific plugin loading

" Omnicompletion
set ofu=syntaxcomplete#Complete

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

"nnoremap ; :
"nnoremap : ;

" Pathogen
execute pathogen#infect()

" ----------------------------------------------------------------------------
" Practice time
" ----------------------------------------------------------------------------
"map <Left> <Nop>
"map <Right> <Nop>
"map <Up> <Nop>
"map <Down> <Nop>

" ----------------------------------------------------------------------------
"   Highlight Trailing Whitespace
" ----------------------------------------------------------------------------

"set list listchars=trail:.,tab:>.
set listchars=tab:>\ ,trail:-,extends:>,precedes:<,nbsp:+
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
set wildmenu                    " enable wildmenu (easy buffer switching, etc)
"set wildmode=longest,list,full  " filepath completion
set wildignore=*.o,*~,*.pyc     " ignore compiled files
set ruler                       " show the cursor position all the time
"set noshowcmd                  " don't display incomplete commands
set showcmd                     " show incomplete commands and selection info
set nolazyredraw                " turn off lazy redraw
set number                      " line numbers
"set ch=2                       " command line height
set backspace=2                 " allow backspacing over everything in insert mode
set whichwrap+=<,>,h,l,[,]      " backspace and cursor keys wrap to
set shortmess=filtIoOA          " shorten messages
set report=0                    " tell us about changes
set nostartofline               " don't jump to the start of line when scrolling
set display+=lastline           " don't hide long lines

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

set autoindent              " automatic indent new lines
"disablign smart-indent: may be preventing comments from indenting?
"http://stackoverflow.com/questions/191201/indenting-comments-to-match-code-in-vim
"set smartindent            " be smart about it
set nowrap                  " do not wrap lines
set softtabstop=4           " tab width
set shiftwidth=4            "
set shiftround              " round indents to multiple of shift width
set tabstop=4
set expandtab               " expand tabs to spaces
set nosmarttab              " no tabs
set textwidth=79            " stick to less than 80 chars per line when possible
set formatoptions+=n        " support for numbered/bullet lists
set virtualedit=block       " allow virtual edit in visual block ..
set encoding=utf8           " UTF-8 by default
set pastetoggle=<F6>        " paste-mode toggle
set sessionoptions-=options " don't preserve configuration across sessions

" Shortuct to toggle textwidth.
nmap <silent><localleader>w :call ToggleTextWidth()<CR>
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
map j gj
map k gk

" Map <Space> to / (search) and Ctrl-<Space> to ? (backwards search)
" map <space> /
" map <c-space> ?

" Quick word navigation
map <c-h> <C-Left>
map <c-l> <C-Right>

" Smart way to move between windows
" map <C-j> <C-W>j
" map <C-k> <C-W>k
" map <C-h> <C-W>h
" map <C-l> <C-W>l

" Quick buffer switching
noremap <s-left>  <esc> :bprev<cr>
noremap <s-right> <esc> :bnext<cr>

" Close the current buffer
map <leader>bd :Bclose<cr>

" Close all the buffers
map <leader>ba :1,1000 bd!<cr>

" Buffer switching using control-tab
nnoremap <C-S-tab> :bprevious<CR>
nnoremap <C-tab>   :bnext<CR>

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
" http://snk.tuxfamily.org/log/vim-256color-bce.html
" http://sunaku.github.io/vim-256color-bce.html
set t_ut=""

" fix control/shift + arrow keys in screen
" http://superuser.com/questions/401926/how-to-get-shiftarrows-and-ctrlarrows-working-in-vim-in-tmux
if &term =~ '^screen'
    " tmux will send xterm-style keys when its xterm-keys option is on
    execute "set <xUp>=\e[1;*A"
    execute "set <xDown>=\e[1;*B"
    execute "set <xRight>=\e[1;*C"
    execute "set <xLeft>=\e[1;*D"
endif

" tmux navigation in insert mode
inoremap <silent> <c-j> <esc> :TmuxNavigateDown<cr>
inoremap <silent> <c-k> <esc> :TmuxNavigateUp<cr>


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

if has("syntax")
    syntax on
endif

" colorscheme
set background=dark
colorscheme hemisu

" Matching parens style
hi MatchParen cterm=bold ctermbg=none ctermfg=red

" ---------------------------------------------------------------------------
"  Copy and Paste
" ---------------------------------------------------------------------------

" Remap vim register to CLIPBOARD selection
" unamed        PRIMARY   (middlemouse)
" unamedplusi   CLIPBOARD (control v)
" autoselect    Automatically save visual selections
"set clipboard=unnamed,autoselect
set clipboard=unnamed

" ---------------------------------------------------------------------------
"  Backup and undo
" ---------------------------------------------------------------------------
set undofile
set history=200
set undolevels=200
set undodir=~/.vim/tmp/undo

" enable undo of c-u and c-w in insert mode
" http://vim.wikia.com/wiki/Recover_from_accidental_Ctrl-U
inoremap <c-u> <c-g>u<c-u>
inoremap <c-w> <c-g>u<c-w>

" ---------------------------------------------------------------------------
"  airline
" ---------------------------------------------------------------------------
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1

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
endfunction

let g:goyo_callbacks = [function('GoyoBefore'), function('GoyoAfter')]

nnoremap <leader><space> :Goyo<CR>

" ---------------------------------------------------------------------------
"  gundo.vim
" ---------------------------------------------------------------------------
nnoremap <F5> :GundoToggle<CR>

" ---------------------------------------------------------------------------
"  incsearch.vim
" ---------------------------------------------------------------------------
map /  <Plug>(incsearch-forward)
map ?  <Plug>(incsearch-backward)
map g/ <Plug>(incsearch-stay)

" Compatibility with vim-indexed-search
let g:indexed_search_mappings = 0
augroup incsearch-indexed
    autocmd!
    autocmd User IncSearchLeave ShowSearchIndex
augroup END

" ---------------------------------------------------------------------------
"  NERDTree
" ---------------------------------------------------------------------------
map <C-n> :NERDTreeToggle<CR>

" ---------------------------------------------------------------------------
"  NERDcommenter
" ---------------------------------------------------------------------------
let g:NERDDefaultAlign = 'left'

" ---------------------------------------------------------------------------
"  vpaste
" ---------------------------------------------------------------------------
map vp :exec "w !vpaste ft=".&ft<CR>
vmap vp <ESC>:exec "'<,'>w !vpaste ft=".&ft<CR>


" ---------------------------------------------------------------------------
"  snipmate.vim
" ---------------------------------------------------------------------------
let g:snips_author = "Keith Hughitt"
let g:snips_email  = "user@email.com"
let g:snips_github = "https://github.com/khughitt"

" ---------------------------------------------------------------------------
"  snipmate.vim
" ---------------------------------------------------------------------------
let g:SuperTabDefaultCompletionType = "context"
highlight Pmenu ctermbg=234 ctermfg=198

" ---------------------------------------------------------------------------
"  Supertab
" ---------------------------------------------------------------------------
let g:SuperTabNoCompleteAfter  = ['^', ',', '\s', '"', "'"]
let g:SuperTabNoCompleteBefore = ['\S']

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
let g:unite_data_directory='~/.vim/tmp/unite'
let g:unite_enable_start_insert=1
let g:unite_source_history_yank_enable=1
let g:unite_source_rec_max_cache_files=5000
let g:unite_prompt='» '
let g:unite_split_rule = 'botright'

nmap <space> [unite]
nnoremap [unite] <nop>

" cnrlp
nnoremap <c-p> :Unite file file_mru file_rec/async<cr>

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
set incsearch  " incremental search
set hlsearch   " highlight searched words
nohlsearch     " avoid highlighting when reloading vimrc

" Make it easier to find current match
"nnoremap <silent> n   n:call HLNext(0.4)<cr>
"nnoremap <silent> N   N:call HLNext(0.4)<cr>

"function! HLNext (blinktime)
"    let [bufnum, lnum, col, off] = getpos('.')
"    let matchlen = strlen(matchstr(strpart(getline('.'),col-1),@/))
"    let target_pat = '\c\%#'.@/
"    let ring = matchadd('WhiteOnRed', target_pat, 101)
"    redraw
"    exec 'sleep ' . float2nr(a:blinktime * 1000) . 'm'
"    call matchdelete(ring)
"    redraw
"endfunction

" stop  highlighting
" Used by tmux navigator
" nnoremap <silent> <C-l> :nohl<CR><C-l>
nnoremap <leader>n :nohl<CR>

" ---------------------------------------------------------------------------
"  Language-specific Options
" ---------------------------------------------------------------------------

" Python
autocmd BufRead,BufNewFile *.py set ai

" R
let vimrplugin_objbr_place = "console,right"
let vimrplugin_term = "xterm"
let vimrplugin_notmuxconf = 1
let vimrplugin_assign = 0
let vimrplugin_tmux_title = "automatic"
"let vimrplugin_vsplit = 1

if $DISPLAY != ""
    let vimrplugin_openpdf = 1
    let vimrplugin_openhtml = 1
endif

" highlight chunk headers
let rrst_syn_hl_chunk = 1
let rmd_syn_hl_chunk = 1

" Use Ctrl+Space to do omnicompletion
if has("gui_running")
    inoremap <C-Space> <C-x><C-o>
else
    inoremap <Nul> <C-x><C-o>
endif

" Press enter and space bar to send lines and selection to R
vmap <Space> <Plug>RDSendSelection
nmap <Space> <Plug>RDSendLine
vmap <C-M> <Plug>RDSendSelection
nmap <C-M> <Plug>RDSendLine

" Knitr
vmap <Space> <Plug>RDSendSelection
nmap <C-A-c> <Plug>RDSendChunk
nmap <localleader>kc :call g:SendCmdToR('rm(list=ls(all.names=TRUE)); unlink("README_cache/*", recursive=TRUE)')<CR>

" KnitrBootstrap
function! RMakeBootstrapHTML()
  update
  call RSetWD()
  "let filename = expand("%:r:t")
  "let rcmd = "require('knitrBootstrap'); require('rmarkdown');
  "  \ render(\"" . filename . ".rmd\", output_format=\"all\", clean=TRUE)"
  let filename = expand("%")
  let rcmd = "require('knitrBootstrap'); require('rmarkdown');
           \  render(\"" . filename . "\", output_format=\"all\", clean=TRUE)"
  if g:vimrplugin_openhtml
    let rcmd = rcmd . ';'
  endif
  call g:SendCmdToR(rcmd)
endfunction

nnoremap <silent> <localleader>kk :call RMakeBootstrapHTML()<CR>

" Ruby
autocmd FileType ruby,eruby,yaml setlocal softtabstop=2 shiftwidth=2 tabstop=2

" Markdown
autocmd BufRead,BufNewFile *.md set filetype=markdown background=light nofoldenable
autocmd FileType markdown colorscheme summerfruit256

" CSV
let g:csv_no_conceal = 1

" ---------------------------------------------------------------------------
"  Host-specific Options
"  Based onhttps://github.com/teranex/dotvim/blob/master/vimrc
" ---------------------------------------------------------------------------
let hostfile=$HOME.'/.vim/vimrc-'.tolower(strpart(hostname(), 0, 4))
if filereadable(hostfile)
    exe 'source ' . hostfile
endif

