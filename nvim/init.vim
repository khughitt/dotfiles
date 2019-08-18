" ---------------------------------------------------------------------------
"
" Neovim Configuration
"
" ---------------------------------------------------------------------------

" ---------------------------------------------------------------------------
" General
" ---------------------------------------------------------------------------
set hidden           " easy buffer switching
set history=5000     " number of command history
set isk+=_,$,@,%,#,- " none word dividers
set cursorline       " highlight current line
set modeline         " make sure modeline support is enabled
set noerrorbells     " quiet, please
set nofoldenable     " disable folding
set complete+=i      " complete filenames
set noshowmode       " hide <INSERT>
filetype indent on   " indent based on filetype

" reduce keycode mapping timeout delay
set ttimeoutlen=5

" reduce mapping delays
set timeoutlen=500

" Mouse support
" https://github.com/neovim/neovim/wiki/Following-HEAD#20170403
set mouse=a

" Omnicompletion
" set omnifunc=syntaxcomplete#Complete

" Use Ctrl+Space to do omnicompletion
if has("gui_running")
    inoremap <C-Space> <C-x><C-o>
else
    inoremap <Nul> <C-x><C-o>
endif

" With a map leader it's possible to do extra key combinations
" like <leader>w saves the current file
let mapleader      = ";"
let g:mapleader    = ";"
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

" ---------------------------------------------------------------------------
" vim-plug
" ---------------------------------------------------------------------------
call plug#begin()
    " plugins
    Plug 'airblade/vim-gitgutter'
    Plug 'https://github.com/Alok/notational-fzf-vim'
    Plug 'bioSyntax/bioSyntax-vim'
    Plug 'chrisbra/csv.vim'
    Plug 'deoplete-plugins/deoplete-jedi'
    Plug 'guns/xterm-color-table.vim'
    Plug 'henrik/vim-indexed-search'
    Plug 'honza/vim-snippets'
    Plug 'bfredl/nvim-ipy'
    Plug 'editorconfig/editorconfig-vim'
    Plug 'godlygeek/tabular'
    Plug 'davidoc/taskpaper.vim'
    Plug 'freitass/todo.txt-vim'
    Plug 'jalvesaq/Nvim-R'
    Plug 'kshenoy/vim-signature'
    Plug 'lilydjwg/colorizer'
    Plug 'MarcWeber/vim-addon-mw-utils'
    Plug 'machakann/vim-textobj-delimited'
    Plug 'majutsushi/tagbar'
    Plug 'mboughaba/i3config.vim'
    Plug 'mllg/vim-devtools-plugin'
    Plug 'nathanaelkane/vim-indent-guides'
    Plug 'ncm2/float-preview.nvim'
    Plug 'qpkorr/vim-bufkill'
    Plug 'raimon49/requirements.txt.vim'
    Plug 'scrooloose/nerdcommenter'
    Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }
    Plug 'Shougo/denite.nvim'
    Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
    Plug 'Shougo/deoplete-terminal'
    Plug 'Shougo/neomru.vim'
    "Plug 'Shougo/neosnippet.vim'
    "Plug 'Shougo/neosnippet-snippets'
    Plug 'troydm/zoomwintab.vim'
    Plug 'tmux-plugins/vim-tmux-focus-events'
    Plug 'tomtom/tlib_vim'
    Plug 'tpope/vim-surround'
    Plug 'tyrannicaltoucan/vim-quantum'
    Plug 'manabuishii/vim-cwl'
    Plug 'itchyny/lightline.vim'
    Plug 'mengelbrecht/lightline-bufferline'
    Plug 'vim-scripts/argtextobj.vim'
    Plug 'vim-syntastic/syntastic'
    Plug 'stephpy/vim-yaml'
    Plug 'mrk21/yaml-vim'
    Plug 'xolox/vim-misc'
    Plug 'xolox/vim-colorscheme-switcher'
    Plug 'ryanoasis/vim-devicons'
    Plug 'wellle/targets.vim'
    Plug '/usr/share/vim/vimfiles'
    Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
    Plug 'junegunn/fzf.vim'
    Plug 'severin-lemaignan/vim-minimap'

    "Plug 'vim-airline/vim-airline'
    "Plug 'vim-airline/vim-airline-themes'
    "Plug 'yuttie/comfortable-motion.vim'
    "Plug 'hkupty/iron.nvim'
    "Plug 'plasticboy/vim-markdown'
    "Plug 'tpope/vim-repeat'
    "Plug 'ervandew/supertab'
    "Plug 'hyiltiz/vim-plugins-profile'
    "Plug 'liuchengxu/vim-which-key', { 'on': ['WhichKey', 'WhichKey!'] }
    "Plug 'python/black'

    " themes
    Plug 'challenger-deep-theme/vim'
    Plug 'cseelus/vim-colors-lucid'
    Plug 'dracula/vim', { 'as': 'dracula' }
    Plug 'fcpg/vim-orbital'
    Plug 'fmoralesc/molokayo'
    Plug 'jacoborus/tender.vim'
    Plug 'joshdick/onedark.vim'
    Plug 'whatyouhide/vim-gotham'
    Plug 'zanloy/vim-colors-grb256'
    Plug 'agreco/vim-citylights'
    Plug 'Dru89/vim-adventurous'
    Plug 'yuttie/hydrangea-vim'
    Plug 'liuchengxu/space-vim-dark'
    Plug 'lu-ren/SerialExperimentsLain'
    Plug 'danilo-augusto/vim-afterglow'
    Plug 'davidklsn/vim-sialoquent'
    Plug 'dikiaap/minimalist'
    Plug 'cseelus/vim-colors-tone'
    Plug 'connorholyday/vim-snazzy'
    Plug 'sheerun/vim-wombat-scheme'
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
set colorcolumn=89         " show right margin
set novisualbell           " no thank you

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
set textwidth=88            " stick to 88 characters or less, when possible
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
map <localleader>gf :e <cfile><cr>

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
"colorscheme dracula
colorscheme ThemerVim

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
" unnamed        CLIPBOARD (shift-control v)
" unnamedplus    PRIMARY   (middlemouse)
" autoselect    Automatically save visual selections
"set clipboard=unnamed,autoselect
"set clipboard=unnamed

" switching to unnamedplus to allow pasting to chromium, etc. in wayland
set clipboard^=unnamed,unnamedplus

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
"  paste bug work-around
"  https://github.com/neovim/neovim/issues/7994#issuecomment-388296360
" ---------------------------------------------------------------------------
nnoremap p p`]<Esc>

" insert blank line without entering insert mode
nmap <A-CR> O<Esc>
nmap <CR> o<Esc>

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
"  deoplete
" ---------------------------------------------------------------------------

"
" key bindings:
"
" tab next
" c-n next
" c-p prev
" c-y select
"

"
" abbreviations:
"
" [↑]  after cursor
" [↓]  before cursor
" [*]  in changes
" [F]  file
" [T]  tag
" [ns] neosnippet
"

"
" TODO: normalize behavior between zsh + fzf and deoplete
"
" 1. autocomplete expressions upon <tab> when only a single match exists
" 2. include relative filepaths without having to include prefix "./"
" 3. don't include typed expression at all (currently cycles through it, even though
"    it's not displayed..)
" 4. automatically insert first match upon opening deoplete menu; currently
"    insertion only occurs upon cycling of completion choices.

" enable at start-up
let g:deoplete#enable_at_startup = 1

" only show popup upon request
let g:deoplete#disable_auto_complete = 1

call deoplete#custom#var('around', {
    \   'range_above': 25,
    \   'range_below': 25,
    \   'mark_above': '[↑]',
    \   'mark_below': '[↓]',
    \   'mark_changes': '[*]',
    \})

" number of results to show
call deoplete#custom#option({'max_list': 10})

" use <tab> to cycle through completions
function! s:check_back_space() abort "{{{
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~ '\s'
endfunction"}}}

inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ deoplete#manual_complete()

inoremap <silent><expr><S-TAB> pumvisible() ? "\<C-p>" : "\<S-TAB>"

" automatically select the first match
set completeopt+=noinsert

" don't ever insert a newline when selecting with <Enter>
inoremap <expr> <CR> (pumvisible() ? "\<c-y>" : "\<CR>")

" matchers
" head   - exact matches
" length - don't show typed word
call deoplete#custom#source('_', 'matchers', ['matcher_head', 'terminal', 'matcher_length'])

" sort results alphabetically
call deoplete#custom#source('_', 'sorters', ['sorter_word'])

" disable the candidates in Comment/String syntaxes.
call deoplete#custom#source('_', 'disabled_syntaxes', ['Comment', 'String'])

" shortcuts
call deoplete#custom#option('candidate_marks', ['A', 'S', 'D', 'F', 'G'])
inoremap <expr><m-a>  deoplete#insert_candidate(0)
inoremap <expr><m-s>  deoplete#insert_candidate(1)
inoremap <expr><m-d>  deoplete#insert_candidate(2)
inoremap <expr><m-f>  deoplete#insert_candidate(3)
inoremap <expr><m-g>  deoplete#insert_candidate(4)

" ---------------------------------------------------------------------------
" float-preview.nvim
" ---------------------------------------------------------------------------
let g:float_preview#docked = 1

" ---------------------------------------------------------------------------
"  gitgutter
" ---------------------------------------------------------------------------
let g:gitgutter_async = 1
let g:gitgutter_eager = 0
let g:gitgutter_enabled = 1
let g:gItgutter_highlight_lines = 0
let g:gitgutter_map_keys = 0
let g:gitgutter_max_signs = 1000
let g:gitgutter_diff_args = '--ignore-all-space'

" ---------------------------------------------------------------------------
"  gundo.vim
" ---------------------------------------------------------------------------
nnoremap <F5> :GundoToggle<CR>

" ---------------------------------------------------------------------------
" indent guides
" ---------------------------------------------------------------------------
let g:indent_guides_auto_colors = 0
let g:indent_guides_auto_colors = 1
let g:indent_guides_start_level = 2
let g:indent_guides_guide_size  = 1

autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd  guibg=black   ctermbg=black
autocmd VimEnter,Colorscheme * :hi IndentGuidesEven guibg=darkgrey ctermbg=darkgrey

" ---------------------------------------------------------------------------
"  neosnippet.vim
" ---------------------------------------------------------------------------
" mapping
"imap <C-k> <Plug>(neosnippet_expand_or_jump)
"smap <C-k> <Plug>(neosnippet_expand_or_jump)
"xmap <C-k> <Plug>(neosnippet_expand_target)

" SuperTab like snippets behavior.
"imap <expr><TAB>
" \ pumvisible() ? "\<C-n>" :
" \ neosnippet#expandable_or_jumpable() ?
" \    "\<Plug>(neosnippet_expand_or_jump)" : "\<TAB>"
"smap <expr><TAB> neosnippet#expandable_or_jumpable() ?
" \ "\<Plug>(neosnippet_expand_or_jump)" : "\<TAB>"

" For conceal markers (disabling; also conceals asterisks in markdown docs...)
"if has('conceal')
"  set conceallevel=2 concealcursor=niv
"endif

"let g:neosnippet#enable_completed_snippet = 1
"let g:neosnippet#snippets_directory='~/.config/nvim/plugged/vim-snippets/snippets'

" ---------------------------------------------------------------------------
"  NERDTree
" ---------------------------------------------------------------------------
map <C-n> :NERDTreeToggle<CR>

" ---------------------------------------------------------------------------
"  NERDcommenter
" ---------------------------------------------------------------------------
let g:NERDDefaultAlign = 'left'


" ---------------------------------------------------------------------------
"  notational-fzf-vim
" ---------------------------------------------------------------------------
"let g:nv_use_short_pathnames = 1
let g:nv_search_paths = ['~/d/notes', './doc']
let g:nv_ignore_pattern = ['personal', 'meetings']
let g:nv_default_extension = '.md'

nnoremap <silent> <c-y> :NV<CR>

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
"  denite
" ---------------------------------------------------------------------------

" general
call denite#custom#option('default', {
            \ 'prompt': '❯',
            \ 'auto_resize': 1,
            \ })

" key bindings
nnoremap <silent> <C-p> :<C-u>Denite file/rec file_mru<CR>
nnoremap <silent> <leader>/ :<C-u>Denite grep:.<CR>
nnoremap <silent> <leader>g :<C-u>DeniteCursorWord grep:.<CR>
nnoremap <silent> <leader>r :<C-u>Denite -resume -cursor-pos=+1<CR>

" navigation
autocmd FileType denite call s:denite_my_settings()
function! s:denite_my_settings() abort
    nnoremap <silent><buffer><expr> <CR> denite#do_map('do_action')
    nnoremap <silent><buffer><expr> d    denite#do_map('do_action', 'delete')
    nnoremap <silent><buffer><expr> p    denite#do_map('do_action', 'preview')
    nnoremap <silent><buffer><expr> q    denite#do_map('quit')
    nnoremap <silent><buffer><expr> i    denite#do_map('open_filter_buffer')
    nnoremap <silent><buffer><expr> <Space> denite#do_map('toggle_select').'j'
endfunction

" no longer supported
"call denite#custom#map('insert', '<Esc>', '<denite:enter_mode:normal>',       'noremap')
"call denite#custom#map('normal', '<Esc>', '<NOP>',                            'noremap')
"call denite#custom#map('normal', 'dw',    '<denite:delete_word_after_caret>', 'noremap')

autocmd FileType denite-filter call s:denite_filter_my_settings()
function! s:denite_filter_my_settings() abort
    imap <silent><buffer> <C-o> <Plug>(denite_filter_quit)
endfunction

" file/rec
call denite#custom#var('file/rec', 'command',
  \ ['ag', '--follow', '--nocolor', '--nogroup', '--ignore', '*.pyc', '-g', ''])

"\ ['ag', '--follow', '--nocolor', '--nogroup', '--ignore', '*.pyc', '*.png', '*.RData', '-g', ''])

call denite#custom#var('grep', 'command', ['ag'])
call denite#custom#var('grep', 'default_opts', ['-i', '--vimgrep'])
call denite#custom#var('grep', 'recursive_opts', [])
call denite#custom#var('grep', 'pattern_opt', [])
call denite#custom#var('grep', 'separator', ['--'])
call denite#custom#var('grep', 'final_opts', [])

call denite#custom#filter('matcher/ignore_globs', 'ignore_globs',
        \ [ '.git/', '.snakemake/', '__pycache__/',
        \   'venv/', 'images/', '*.rda', '*.min.*', 'img/', 'fonts/', '*cache/', '*_files/'])

" find
call denite#custom#var('file_rec/fd', 'command',
  \ ['fd', '--type=f', '--follow', '--hidden', '--full-path', '--color=never', '--exclude=.git', ''])

" sorters
call denite#custom#source('file/rec', 'sorters', ['sorter/sublime'])

" default action.
" call denite#custom#kind('file', 'default_action', 'split')

" ---------------------------------------------------------------------------
"  fzf.vim
" ---------------------------------------------------------------------------
let g:fzf_layout = { 'window': 'enew' }
let g:fzf_layout = { 'window': '-tabnew' }
let g:fzf_layout = { 'window': '10split enew' }
let g:fzf_layout = { 'down': '~40%' }

cmap <C-r> :History:<CR>

"nmap <leader><tab> <plug>(fzf-maps-n)
"xmap <leader><tab> <plug>(fzf-maps-x)
"omap <leader><tab> <plug>(fzf-maps-o)

"imap <c-x><c-k> <plug>(fzf-complete-word)
"imap <c-x><c-f> <plug>(fzf-complete-path)
"imap <c-x><c-j> <plug>(fzf-complete-file-ag)
"imap <c-x><c-l> <plug>(fzf-complete-line)

"let g:fzf_colors =
"\ { 'fg':      ['fg', 'Normal'],
"  \ 'bg':      ['bg', 'Normal'],
"  \ 'hl':      ['fg', 'Comment'],
"  \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
"  \ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],
"  \ 'hl+':     ['fg', 'Statement'],
"  \ 'info':    ['fg', 'PreProc'],
"  \ 'border':  ['fg', 'Ignore'],
"  \ 'prompt':  ['fg', 'Conditional'],
"  \ 'pointer': ['fg', 'Exception'],
"  \ 'marker':  ['fg', 'Keyword'],
"  \ 'spinner': ['fg', 'Label'],
"  \ 'header':  ['fg', 'Comment'] }

" ---------------------------------------------------------------------------
"  lightline
" ---------------------------------------------------------------------------
let g:lightline = { 'colorscheme': 'ThemerVimLightline' }
let g:lightline.tabline          = {'left': [['buffers']], 'right': [['close']]}
let g:lightline.component_expand = {'buffers': 'lightline#bufferline#buffers'}
let g:lightline.component_type   = {'buffers': 'tabsel'}
let g:lightline#bufferline#shorten_path = 1
let g:lightline#bufferline#enable_devicons = 1

" ---------------------------------------------------------------------------
"  notational-fzf-vim
" ---------------------------------------------------------------------------
let g:nv_search_paths = ['~/d/notes']

" ---------------------------------------------------------------------------
" supertab.vim 
" ---------------------------------------------------------------------------
" let g:SuperTabDefaultCompletionType = "<c-n>"

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

nnoremap <F10> :SyntasticCheck<CR>

" r
let g:syntastic_enable_r_lintr_checker = 1
let g:syntastic_r_checkers = ['lintr']
let g:syntastic_rmd_checkers = ['lintr']
let g:syntastic_r_lintr_linters = "with_defaults(line_length_linter(120),object_camel_case_linter=NULL,single_quotes_linter=NULL,commented_code_linter=NULL,object_name_linter=NULL)"

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
set incsearch  " do incremental searching
set wrapscan   " search wrap around the end of the file
nohlsearch     " avoid highlighting when reloading vimrc

" turn off highlighting
nnoremap <leader>n :nohl<CR>

" ---------------------------------------------------------------------------
"  Tab completion
" ---------------------------------------------------------------------------
set infercase " case insensitive tab completion
set ignorecase " ignore case search
set smartcase  " override 'ignorecase' if the search pattern contains upper case

" enable completion of filenames following '='
set isfname-==

" ---------------------------------------------------------------------------
"  Language-specific Options
" ---------------------------------------------------------------------------

" Language-specific options
autocmd FileType ruby,eruby,yaml,r,rmd,jinja,yaml setlocal softtabstop=2 shiftwidth=2 tabstop=2
autocmd BufRead,BufNewFile *.md set filetype=markdown nofoldenable
autocmd BufRead,BufNewFile *.py set autoindent

" Languge-specific color schemes
"autocmd FileType yaml colorscheme sweyla907357
"autocmd FileType jinja colorscheme SerialExperimentsLain
"autocmd FileType snakemake colorscheme gotham
"autocmd FileType rmd colorscheme grb256

" Markdown
"let g:vim_markdown_frontmatter = 1
"let g:vim_markdown_strikethrough = 1

" R
let vimrplugin_objbr_place = "console,right"

" Fix issue relating to setwidth
" https://github.com/jalvesaq/Nvim-R/issues/81#issuecomment-262651872
let R_setwidth = 0

" split editor and console top/bottom
let R_rconsole_width = 0

" syntax highlighting in console output
let R_hl_term = 0

" Nvim-R / radian
"let R_app = "radian"
"let R_bracketed_paste = 1
let R_cmd = "R"

" devtools load all shortcut
map ;dl :RLoadPackage<CR>

" Emulate Tmux ^az
function! ZoomWindow()
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
    let R_pdfviewer = 'zathura'
    let vimrplugin_openpdf = 1
    let vimrplugin_openhtml = 1
endif

" highlight chunk headers
let rrst_syn_hl_chunk = 1
let rmd_syn_hl_chunk = 1

" libraries to always include for autocompletion
let vimrplugin_start_libs = "base,stats,graphics,grDevices,utils,methods,Biobase,parallel,tidyverse"

" press enter and space bar to send lines and selection to R
vmap <Space> <Plug>RDSendSelection
nmap <Space> <Plug>RDSendLine
vmap <C-M> <Plug>RDSendSelection
nmap <C-M> <Plug>RDSendLine

" preview data
nmap <silent> <LocalLeader>h :call RAction("hh", "@,48-57,_,.")<CR>

" wipe knitr cache and output
nmap <localleader>kc :call g:SendCmdToR('rm(list=ls(all.names=TRUE)); unlink("*_cache/*", recursive=TRUE)')<CR>

" render markdown
nmap <localleader>km :call RMakeRmd("github_document")<CR>

" show source code for function under cursor
function! ShowRSource()
    let g:function_name = expand("<cword>")
    echom "Showing source code for function: \"" . g:function_name . "\""
    enew
    set syntax=r
    execute ":Rinsert " . g:function_name
endfunction

nmap <localleader>sc :call ShowRSource()<CR>

" nvim-ipy
let g:nvim_ipy_perform_mappings = 0

" note: <c-w> <c-r> swaps two vertical buffers
vmap <Silent><Space> <Plug>(IPy-Run)
nmap <Silent><Space> <Plug>(IPy-Run)
vmap <Silent><C-M> <Plug>(IPy-Run)
nmap <Silent><C-M> <Plug>(IPy-Run)

autocmd Filetype python nmap <localleader>rf :IPython<cr>

"autocmd BufWritePre *.py execute ':Black'

au FileType python map <silent> <leader>b obreakpoint()<esc>

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

" Work-around for failing rmarkdown syntax highlighting when jumping around in files
" https://vim.fandom.com/wiki/Fix_syntax_highlighting
autocmd BufEnter * :syntax sync fromstart
syntax sync minlines=300

