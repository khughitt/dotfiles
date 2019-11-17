" ---------------------------------------------------------------------------
"
" Neovim Configuration
"
" ---------------------------------------------------------------------------

"
" Useful commands:
"
" :verbose set <var>?    find where a setting was made
"

" ---------------------------------------------------------------------------
" General
" ---------------------------------------------------------------------------
set hidden           " easy buffer switching
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
set timeoutlen=500

" Mouse support
" https://github.com/neovim/neovim/wiki/Following-HEAD#20170403
set mouse=a

" Remap leader / localleader
let mapleader      = ";"
let g:mapleader    = ";"
let maplocalleader = ","

" Fast save/quit
nmap <leader>w :update<cr>
nmap <leader>q :q<cr>
nmap <leader>z :wq<cr>

" remap macro recording to Q
nnoremap Q q
nnoremap q <nop>

" home/end key tmux work-around
" https://github.com/neovim/neovim/issues/9012
inoremap <C-a> <Home>
inoremap <C-e> <End>
noremap  <C-a> <Home>
noremap  <C-e> <End>

" ---------------------------------------------------------------------------
" vim-plug
" ---------------------------------------------------------------------------
call plug#begin()
    " plugins
    " Plug 'airblade/vim-gitgutter'
    Plug 'andymass/vim-matchup'
    Plug 'bfredl/nvim-ipy'
    Plug 'chrisbra/csv.vim'
    Plug 'dense-analysis/ale'
    Plug 'ervandew/supertab'
    Plug 'godlygeek/tabular'
    Plug 'guns/xterm-color-table.vim'
    Plug 'henrik/vim-indexed-search'
    Plug 'honza/vim-snippets'
    Plug 'jalvesaq/Nvim-R'
    Plug 'JuliaEditorSupport/julia-vim'
    Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
    Plug 'junegunn/fzf.vim'
    Plug 'kshenoy/vim-signature'
    Plug 'kana/vim-operator-user'
    Plug 'lilydjwg/colorizer'
    Plug 'MarcWeber/vim-addon-mw-utils'
    Plug 'majutsushi/tagbar'
    Plug 'manabuishii/vim-cwl'
    Plug 'mboughaba/i3config.vim'
    Plug 'mllg/vim-devtools-plugin'
    Plug 'mrk21/yaml-vim'
    Plug 'nathanaelkane/vim-indent-guides'
    Plug 'ncm2/float-preview.nvim'
    " Plug 'plasticboy/vim-markdown'
    Plug 'psf/black'
    Plug 'qpkorr/vim-bufkill'
    Plug 'raimon49/requirements.txt.vim'
    Plug 'scrooloose/nerdcommenter'
    Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }
    Plug 'Shougo/denite.nvim'
    Plug 'Shougo/neomru.vim'
    Plug 'stephpy/vim-yaml'
    Plug 'tmux-plugins/vim-tmux-focus-events'
    Plug 'tomtom/tlib_vim'
    Plug 'tpope/vim-surround'
    Plug 'terryma/vim-expand-region'
    Plug 'wellle/targets.vim'
    Plug 'wincent/terminus'
    Plug 'xolox/vim-colorscheme-switcher'
    Plug 'xolox/vim-misc'
    Plug 'gcavallanti/vim-noscrollbar'
    Plug '/usr/share/vim/vimfiles'

    Plug 'glts/vim-textobj-comment'
    Plug 'kana/vim-textobj-user'
    Plug 'vimtaku/vim-textobj-keyvalue'
    " Plug 'vim-scripts/argtextobj.vim'
    " Plug 'tyru/vim-textobj-underscore', { 'branch': 'support-3-cases' }

    Plug 'agreco/vim-citylights'
    Plug 'ayu-theme/ayu-vim'
    Plug 'challenger-deep-theme/vim'
    Plug 'connorholyday/vim-snazzy'
    Plug 'cseelus/vim-colors-lucid'
    Plug 'cseelus/vim-colors-tone'
    Plug 'danilo-augusto/vim-afterglow'
    Plug 'davidklsn/vim-sialoquent'
    Plug 'dikiaap/minimalist'
    Plug 'dracula/vim', { 'as': 'dracula' }
    Plug 'drewtempelmeyer/palenight.vim'
    Plug 'Dru89/vim-adventurous'
    Plug 'fcpg/vim-orbital'
    Plug 'fenetikm/falcon'
    Plug 'fmoralesc/molokayo'
    Plug 'jacoborus/tender.vim'
    Plug 'joshdick/onedark.vim'
    Plug 'KeitaNakamura/neodark.vim'
    Plug 'liuchengxu/space-vim-dark'
    Plug 'lu-ren/SerialExperimentsLain'
    Plug 'NLKNguyen/papercolor-theme'
    Plug 'rakr/vim-one'
    Plug 'reedes/vim-colors-pencil'
    Plug 'Rigellute/rigel'
    Plug 'sheerun/vim-wombat-scheme'
    Plug 'tyrannicaltoucan/vim-quantum'
    Plug 'tyrannicaltoucan/vim-deep-space'
    Plug 'vim-scripts/pyte'
    Plug 'vim-scripts/summerfruit256.vim'
    Plug 'whatyouhide/vim-gotham'
    Plug 'wimstefan/Lightning'
    Plug 'yuttie/hydrangea-vim'
    Plug 'zanloy/vim-colors-grb256'

    Plug 'vim-airline/vim-airline'
    Plug 'vim-airline/vim-airline-themes'

    "Plug 'bioSyntax/bioSyntax-vim'
    "Plug 'chriskempson/base16-vim'
    "Plug 'severin-lemaignan/vim-minimap'
    "Plug 'yuttie/comfortable-motion.vim'
    "Plug 'hkupty/iron.nvim'
    "Plug 'tpope/vim-repeat'
    "Plug 'hyiltiz/vim-plugins-profile'
    "Plug 'troydm/zoomwintab.vim'
    "Plug 'liuchengxu/vim-which-key', { 'on': ['WhichKey', 'WhichKey!'] }
    "Plug 'davidoc/taskpaper.vim'
    "Plug 'Shougo/neosnippet.vim'
    "Plug 'Shougo/neosnippet-snippets'
    "Plug 'freitass/todo.txt-vim'
    "Plug 'Alok/notational-fzf-vim'
    "Plug 'itchyny/lightline.vim'
    "Plug 'mengelbrecht/lightline-bufferline'
    "Plug 'deoplete-plugins/deoplete-jedi'
    "Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
    "Plug 'Shougo/deoplete-terminal'
    "Plug 'vim-syntastic/syntastic'
    "Plug 'vimwiki/vimwiki'
    "
    " overrides filetype tabstop, etc. options
    "Plug 'editorconfig/editorconfig-vim'

    " conflicts with lightline-bufferline
    "Plug 'nightsense/night-and-day'

    " Requires +conceal feature not compiled in Arch
    " Plug 'vim-pandoc/vim-pandoc'
    " Plug 'vim-pandoc/vim-pandoc-syntax'

    " devicons should always be loaded last
    Plug 'ryanoasis/vim-devicons'
call plug#end()

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
set wildmode=longest,list       " for filename completion, fill longest and list others
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
inoremap <M-h> <C-o>h
inoremap <M-j> <C-o>j
inoremap <M-k> <C-o>k
inoremap <M-l> <C-o>l

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

" shortcut to insert a space in normal mode
nnoremap ss i<space><esc>

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

" Copy and comment current line
nmap zz yy<leader>ccp
vmap zz ygv<leader>cc`.jP

" Specify the behavior when switching between buffers
try
set switchbuf=useopen,usetab,newtab
    set stal=2
catch
endtry

" create file under cursor
map <localleader>gf :e <cfile><cr>

" Return to last edit position when opening files
au BufReadPost *
    \ if line("'\"") > 0 && line("'\"") <= line("$") |
    \   exe "normal! g`\"" |
    \ endif

" Save current view settings on a per-window, per-buffer basis.
function! AutoSaveWinView()
    if !exists("w:SavedBufView")
        let w:SavedBufView = {}
    endif
    let w:SavedBufView[bufnr("%")] = winsaveview()
endfunction

" Restore current view settings.
function! AutoRestoreWinView()
    let buf = bufnr("%")
    if exists("w:SavedBufView") && has_key(w:SavedBufView, buf)
        let v = winsaveview()
        let atStartOfFile = v.lnum == 1 && v.col == 0
        if atStartOfFile && !&diff
            call winrestview(w:SavedBufView[buf])
        endif
        unlet w:SavedBufView[buf]
    endif
endfunction

" When switching buffers, preserve window view.
if v:version >= 700
    autocmd BufLeave * call AutoSaveWinView()
    autocmd BufEnter * call AutoRestoreWinView()
endif

" Remember info about open buffers on close
set viminfo^=%

" Enable cursor shape support
set guicursor=n-v-c:block-Cursor/lCursor-blinkon0,
            \i-ci:ver25-Cursor/lCursor,
            \r-cr:hor20-Cursor/lCursor

" Easier switching to normal mode
inoremap jk <Esc>

" Faster command execution
nnoremap ! :!

" Sloppyness is okay
cabbrev qw :wq

" ---------------------------------------------------------------------------
"  Appearance
" ---------------------------------------------------------------------------
if $TERM != 'linux'
    set t_Co=256
endif

" fix background bleeding in screen
" http://sunaku.github.io/vim-256color-bce.html
set t_ut=""

" enable true colors
set termguicolors

" use colorscheme for R output
let g:rout_follow_colorscheme = 1
let g:Rout_more_colors = 1

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

" colorscheme settings
let g:quantum_black=1
let g:quantum_italics=1
let g:onedark_terminal_italics=1

" set background=dark
"colorscheme hemisu
"colorscheme sweyla721647
"colorscheme sweyla939829
"colorscheme sweyla708971
"colorscheme gotham
"colorscheme SerialExperimentsLain
"colorscheme dracula
"colorscheme minimalist
"colorscheme quantum
" colorscheme citylights
colorscheme onedark

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

" stay at last selected character after yanking text in visual mode
vmap y y`]

" paste from primary in normal mode
noremap <Leader>p "*p
noremap <Leader>P "*P

" ----------------------------------------------------------------------------
"   Highlight Trailing Whitespace
" ----------------------------------------------------------------------------

"set listchars=tab:>\ ,trail:-,extends:>,precedes:<,nbsp:+
highlight SpecialKey ctermfg=DarkGray ctermbg=Black

" ---------------------------------------------------------------------------
"  Backup and undo
" ---------------------------------------------------------------------------
set undofile
set history=5000
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
" nmap <c-o> O<Esc> " used to navigate jump list..
" nmap <CR> o<Esc>

" ---------------------------------------------------------------------------
"  Strip all trailing whitespace in file
" ---------------------------------------------------------------------------
function! StripWhitespace ()
    exec ':%s/ \+$//gc'
endfunction
map ,s :call StripWhitespace ()<CR>

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
au BufWinEnter,WinEnter term://* startinsert

" Exclude terminal from buffer list
au TermOpen * set nobuflisted
au TermOpen * noremap <buffer> <tab> <nop>
au TermOpen * noremap <buffer> <s-tab> <nop>

" Disable terminal line numbers
au TermOpen * setlocal nonumber norelativenumber

" ---------------------------------------------------------------------------
"  airline
" ---------------------------------------------------------------------------
let g:airline_powerline_fonts = 1
let g:airline#extensions#ale#enabled = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline_theme = 'onedark'

" ---------------------------------------------------------------------------
"  ale
" ---------------------------------------------------------------------------
" nmap <silent> <C-k> <Plug>(ale_previous_wrap)
" nmap <silent> <C-j> <Plug>(ale_next_wrap)
let g:ale_fixers = {'r': ['styler', 'trim_whitespace'], 'rmd': ['styler', 'trim_whitespace']}   
let g:ale_r_lintr_options = "with_defaults(line_length_linter(100),single_quotes_linter=NULL,commented_code_linter=NULL,object_name_linter=NULL)"


" ---------------------------------------------------------------------------
"  black
" ---------------------------------------------------------------------------
au BufWritePre *.py execute ':Black'

" ---------------------------------------------------------------------------
" csv.vim
" ---------------------------------------------------------------------------
let g:csv_no_conceal = 1

" ---------------------------------------------------------------------------
"  colorizer
" ---------------------------------------------------------------------------
let g:colorizer_startup = 0

" ---------------------------------------------------------------------------
"  colorscheme-switcher.vim
" ---------------------------------------------------------------------------
let g:colorscheme_switcher_exclude = [
            \ 'blue', 'darkblue', 'default', 'delek', 'desert', 'elflord',
            \ 'evening', 'fi', 'gotham256', 'industry', 'koehler', 'morning',
            \ 'murphy', 'pablo', 'peachpuff', 'ron', 'shine', 'slate',
            \ 'torte', 'zellner']

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
" 5. automatically refresh completion candidates after additional characters are typed.
" 6. When entering a filepath, exclude all other completions (can just <tab> expand
"    filepath very quickly that way, esp. if only one sub-dir at each level..)

" enable at start-up
"let g:deoplete#enable_at_startup = 1

" only show popup upon request
"let g:deoplete#disable_auto_complete = 1

" call deoplete#custom#var('around', {
"     \   'range_above': 25,
"     \   'range_below': 25,
"     \   'mark_above': '[↑]',
"     \   'mark_below': '[↓]',
"     \   'mark_changes': '[*]',
"     \})

" number of results to show
" call deoplete#custom#option({'max_list': 10})

" use <tab> / <s-tab> to cycle through completions
" function! s:check_back_space() abort "{{{
"   let col = col('.') - 1
"   return !col || getline('.')[col - 1]  =~ '\s'
" endfunction"}}}

" inoremap <silent><expr> <TAB>
"       \ pumvisible() ? "\<C-n>" :
"       \ <SID>check_back_space() ? "\<TAB>" :
"       \ deoplete#manual_complete()
"
" inoremap <silent><expr><S-TAB> pumvisible() ? "\<C-p>" : "\<S-TAB>"
"
" " automatically select the first match
" set completeopt+=noinsert
"
" " don't insert a newline when selecting with <Enter>
" inoremap <expr> <CR> (pumvisible() ? "\<c-y>" : "\<CR>")
"
" " matchers
" " head   - exact matches
" " length - don't show typed word
" call deoplete#custom#source('_', 'matchers', ['matcher_head', 'terminal', 'matcher_length'])
"
" " sort results alphabetically
" call deoplete#custom#source('_', 'sorters', ['sorter_word'])
"
" " disable the candidates in Comment/String syntaxes.
" call deoplete#custom#source('_', 'disabled_syntaxes', ['Comment', 'String'])
"
" " prioritize file matches when present
" call deoplete#custom#source('file', 'rank', 9999)
"
" " disable buffer source
" let g:deoplete#ignore_sources = {}
" let g:deoplete#ignore_sources._ = ['buffer']
"
" " shortcuts
" call deoplete#custom#option('candidate_marks', ['A', 'S', 'D', 'F', 'G'])
" inoremap <expr><m-a>  deoplete#insert_candidate(0)
" inoremap <expr><m-s>  deoplete#insert_candidate(1)
" inoremap <expr><m-d>  deoplete#insert_candidate(2)
" inoremap <expr><m-f>  deoplete#insert_candidate(3)
" inoremap <expr><m-g>  deoplete#insert_candidate(4)

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
let g:gitgutter_highlight_lines = 0
let g:gitgutter_map_keys = 1
let g:gitgutter_max_signs = 1000
let g:gitgutter_diff_args = '--ignore-all-space'

" ---------------------------------------------------------------------------
"  gundo.vim
" ---------------------------------------------------------------------------
" nnoremap <F5> :GundoToggle<CR>

" ---------------------------------------------------------------------------
" indent guides
" ---------------------------------------------------------------------------
let g:indent_guides_auto_colors = 0
let g:indent_guides_auto_colors = 1
let g:indent_guides_start_level = 2
let g:indent_guides_guide_size  = 1

" au VimEnter,Colorscheme * :hi IndentGuidesOdd  guibg=black    ctermbg=black
" au VimEnter,Colorscheme * :hi IndentGuidesEven guibg=darkgrey ctermbg=darkgrey

" ---------------------------------------------------------------------------
" julia-vim
" ---------------------------------------------------------------------------
" autocmd BufNewFile,BufRead *.jl set syntax=julia

" ---------------------------------------------------------------------------
" vim-minimap
" ---------------------------------------------------------------------------
let g:minimap_highlight='Visual'
let g:minimap_toggle='<leader>mm'

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
let g:NERDSpaceDelims = 1
let g:NERDCommentEmptyLines = 1
let g:NERDTrimTrailingWhitespace = 1

nmap <space> <leader>c<space>
vmap <space> <leader>c<space>

" ---------------------------------------------------------------------------
"  night-and-day
" ---------------------------------------------------------------------------
let g:nd_themes = [
  \ ['04:00', 'PaperColor', 'light' , 'PaperColor' ],
  \ ['11:00', 'quantum',    'dark',   'quantum'],
  \ ]
let g:nd_lightline = 1

" ---------------------------------------------------------------------------
"  notational-fzf-vim
" ---------------------------------------------------------------------------
"let g:nv_use_short_pathnames = 1
" let g:nv_search_paths = ['~/d/notes', './doc']
" let g:nv_search_paths = ['~/d/notes']
" let g:nv_ignore_pattern = ['personal', 'meetings']
" let g:nv_default_extension = '.md'

" nnoremap <silent> <c-y> :NV<CR>

" ---------------------------------------------------------------------------
"  nvim-ipy
" ---------------------------------------------------------------------------
let g:nvim_ipy_perform_mappings = 0

" note: <c-w> <c-r> swaps two vertical buffers
vmap <Silent><Space> <Plug>(IPy-Run)
nmap <Silent><Space> <Plug>(IPy-Run)
vmap <Silent><C-M> <Plug>(IPy-Run)
nmap <Silent><C-M> <Plug>(IPy-Run)

au FileType python nmap <localleader>rf :IPython<CR>

" ---------------------------------------------------------------------------
"  vim-markdown
" ---------------------------------------------------------------------------
let g:vim_markdown_folding_disabled = 1
let g:vim_markdown_frontmatter = 1
let g:vim_markdown_toc_autofit = 1
let g:vim_markdown_strikethrough = 1
let g:vim_markdown_math = 1

" au BufNewFile,BufRead *.md set filetype=markdown nofoldenable
au BufNewFile,BufRead *.md set conceallevel=2

" replace tagbar binding
" au FileType markdown nmap <F9> :Toc<CR>
" au FileType markdown imap <F9> :Toc<CR>

" override default conceal colors
syntax match Normal /\*/ conceal cchar=∗

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
au FileType denite call s:denite_my_settings()
function! s:denite_my_settings() abort
    nnoremap <silent><buffer><expr> <CR> denite#do_map('do_action')
    nnoremap <silent><buffer><expr> d    denite#do_map('do_action', 'delete')
    nnoremap <silent><buffer><expr> p    denite#do_map('do_action', 'preview')
    nnoremap <silent><buffer><expr> q    denite#do_map('quit')
    nnoremap <silent><buffer><expr> i    denite#do_map('open_filter_buffer')
    nnoremap <silent><buffer><expr> <Space> denite#do_map('toggle_select').'j'
endfunction

au FileType denite-filter call s:denite_filter_my_settings()
function! s:denite_filter_my_settings() abort
    imap <silent><buffer> <C-o> <Plug>(denite_filter_quit)
endfunction

" file/rec
call denite#custom#var('file/rec', 'command',
  \ ['ag', '--follow', '--nocolor', '--nogroup', '--ignore', '*.pyc', '-g', ''])

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

" ---------------------------------------------------------------------------
"  lightline
" ---------------------------------------------------------------------------
" let g:lightline = { 'colorscheme': 'onedark' }
" let g:lightline.tabline          = {'left': [['buffers']], 'right': [['close']]}
" let g:lightline.component_function = { 'percent': 'NoScrollbarForLightline' }
" let g:lightline.component_expand = {'buffers': 'lightline#bufferline#buffers'}
" let g:lightline.component_type   = {'buffers': 'tabsel'}
" let g:lightline#bufferline#enable_devicons = 1
" let g:lightline#bufferline#show_number  = 1

" ---------------------------------------------------------------------------
"  noscrollbar
" ---------------------------------------------------------------------------
" Instead of % show NoScrollbar horizontal scrollbar
" function! NoScrollbarForLightline()
"    return noscrollbar#statusline()
" endfunction

" ---------------------------------------------------------------------------
"  Nvim-R
" ---------------------------------------------------------------------------
let vimrplugin_objbr_place = "console,right"

" Fix issue relating to setwidth
" https://github.com/jalvesaq/Nvim-R/issues/81#issuecomment-262651872
let R_setwidth = 0

" split editor and console top/bottom
let R_rconsole_width = 0

" disable syntax highlighting in console output
let R_hl_term = 0

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
au BufEnter Object_Browser set nobuflisted

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

" tell nvim-r to expect same prompt format as defined in .Rprofile
let g:Rout_prompt_str = '> '
let g:Rout_continue_str = '... '

" press enter and space bar to send lines and selection to R
vmap <Space> <Plug>RDSendSelection
nmap <Space> <Plug>RDSendLine
vmap <CR> <Plug>RDSendSelection
nmap <CR> <Plug>RDSendLine
" autocmd FileType rmd    vmap <buffer> <Space> <Plug>RDSendSelection
" autocmd FileType rmd    nmap <buffer> <Space> <Plug>RDSendLine
" autocmd FileType rmd    vmap <buffer> <CR> <Plug>RDSendSelection
" autocmd FileType rmd    nmap <buffer> <CR> <Plug>RDSendLine

" nmap <C-Space> ,rp
autocmd FileType r,rmd    nmap <buffer> <C-Space> ,rp

" autostart term
" au FileType r   if string(g:SendCmdToR) == "function('SendCmdToR_fake')" | call StartR("R") | endif
" au FileType rmd if string(g:SendCmdToR) == "function('SendCmdToR_fake')" | call StartR("R") | endif

" preview data
" au FileType r,rmd nmap <silent> <LocalLeader>h :call RAction("hh", "@,48-57,_,.")<CR>
nmap <silent> <LocalLeader>h :call RAction("hh", "@,48-57,_,.")<CR>

" wipe knitr cache and output
" au FileType r,rmd nmap <localleader>kc :call g:SendCmdToR('rm(list=ls(all.names=TRUE)); unlink("*_cache/*", recursive=TRUE)')<CR>
nmap <localleader>kc :call g:SendCmdToR('rm(list=ls(all.names=TRUE)); unlink("*_cache/*", recursive=TRUE)')<CR>

" render markdown
" au FileType r,rmd nmap <localleader>km :call RMakeRmd("github_document")<CR>
nmap <localleader>km :call RMakeRmd("github_document")<CR>

" show source code for function under cursor
function! ShowRSource()
    let g:function_name = expand("<cword>")
    echom "Showing source code for function: \"" . g:function_name . "\""
    enew
    set syntax=r
    execute ":Rinsert " . g:function_name
endfunction

" au FileType r,rmd nmap <localleader>sc :call ShowRSource()<CR>
nmap <localleader>sc :call ShowRSource()<CR>

" ---------------------------------------------------------------------------
" supertab.vim
" ---------------------------------------------------------------------------
let g:SuperTabDefaultCompletionType = "<c-n>"
let g:SuperTabDefaultCompletionType = "context"

" ---------------------------------------------------------------------------
"  syntastic
" ---------------------------------------------------------------------------
" set statusline+=%#warningmsg#
" set statusline+=%{SyntasticStatuslineFlag()}
" set statusline+=%*
"
" let g:syntastic_mode_map = {'mode': 'passive'}
" let g:syntastic_always_populate_loc_list = 1
" let g:syntastic_auto_loc_list = 1
" let g:syntastic_check_on_open = 0
" let g:syntastic_check_on_wq = 1
"
" " r
" let g:syntastic_r_checkers=['lintr']
" let g:syntastic_rmd_checkers=['lintr']
"
" let g:syntastic_enable_r_lintr_checker = 1
" let g:syntastic_enable_rmd_lintr_checker = 1
"
" " 2019-09-05: new linter in devel version of lintr:
" "  object_name_linter(styles = c('snake_case'))
" let g:syntastic_r_lintr_linters = "with_defaults(line_length_linter(120),single_quotes_linter=NULL,commented_code_linter=NULL,object_name_linter=NULL)"
"
" " python
" let g:syntastic_rst_checkers=['sphinx']
"
" " key bindings
" nnoremap <F10> :SyntasticCheck<CR>

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
"  vim-expand-region
" ---------------------------------------------------------------------------
vmap v <Plug>(expand_region_expand)
vmap <C-v> <Plug>(expand_region_shrink)

" ---------------------------------------------------------------------------
"  vim-textobj-underscore
" ---------------------------------------------------------------------------
" nmap cid ci_
" nmap cad ca_
" nmap did di_
" nmap dad da_

" ---------------------------------------------------------------------------
"  VimWiki
" ---------------------------------------------------------------------------
let g:vimwiki_list = [{'path': '~/d/notes/',
                      \ 'syntax': 'markdown',
                      \ 'ext': '.md'}]

" only set filetype to vimwiki for files in specified vimwiki path
let g:vimwiki_global_ext = 0

" tagbar integration
let g:tagbar_type_vimwiki = {
          \   'ctagstype':'vimwiki'
          \ , 'kinds':['h:header']
          \ , 'sro':'&&&'
          \ , 'kind2scope':{'h':'header'}
          \ , 'sort':0
          \ , 'ctagsbin':'~/bin/vwtags.py'
          \ , 'ctagsargs': 'markdown'
          \ }

" ---------------------------------------------------------------------------
"  Language-specific Options
" ---------------------------------------------------------------------------

" Language-specific options
autocmd FileType html,markdown,ruby,r,rmd,jinja,yaml setlocal softtabstop=2 shiftwidth=2 tabstop=2
autocmd BufRead,BufNewFile *.py set autoindent

" Languge-specific color schemes
"au FileType yaml colorscheme sweyla907357
"au FileType jinja colorscheme SerialExperimentsLain
au FileType snakemake colorscheme adventurous
au FileType r colorscheme dracula
au FileType rmd colorscheme pencil

au FileType python map <silent> <leader>b obreakpoint()<esc>

" Snakemake syntax highlighting
au BufNewFile,BufRead Snakefile set syntax=snakemake
au BufNewFile,BufRead *.snakefile set syntax=snakemake

" Host-specific configuration
" http://effectif.com/vim/host-specific-vim-config
let hostfile=$XDG_CONFIG_HOME . '/nvim/' . substitute(hostname(), "\\..*", "", "") . '-local.vim'
if filereadable(hostfile)
    exe 'source ' . hostfile
endif

"
" more colorscheme changes (keep at end of file to ensure these aren't over-ridden)
"
syntax on

" color column
highlight ColorColumn ctermbg=234 guibg=#222222

" Matching parens style
hi MatchParen cterm=bold ctermbg=none ctermfg=red

" Highlight color
" hi Search ctermbg=197 ctermfg=233
" hi Search guibg=#14D1DE guifg=#2C2C2C
" hi IncSearch guifg=#67E8F1 guibg=#333333

" Conceal characters
hi Conceal guibg=background guifg=foreground

" Work-around for failing rmarkdown syntax highlighting when jumping around in files
" https://vim.fandom.com/wiki/Fix_syntax_highlighting
au BufEnter * :syntax sync fromstart
syntax sync minlines=300

