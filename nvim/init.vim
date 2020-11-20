" ---------------------------------------------------------------------------
"
" Neovim Configuration
"
" ---------------------------------------------------------------------------

"
" Useful commands:
"
" :verbose set <var>?    find where a setting was made
" :scriptnames           list vimscripts loaded

" ---------------------------------------------------------------------------
" General
" ---------------------------------------------------------------------------
set hidden           " easy buffer switching
set isk+=%,#,-       " additional vim word characters
set cursorline       " highlight current line
set modeline         " make sure modeline support is enabled
set noerrorbells     " quiet, please
set nofoldenable     " disable folding
set complete+=i      " complete filenames
set noshowmode       " hide <INSERT>
filetype indent on   " indent based on filetype

"set isk-=(,)         " characters to remove from word list

" reduce keycode mapping timeout delay
set ttimeoutlen=5
set timeoutlen=500

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

" specify python installation to use
let g:python3_host_prog = '~/conda/bin/python3'

" ---------------------------------------------------------------------------
" vim-plug
" ---------------------------------------------------------------------------
call plug#begin()
    " plugins
    " Plug 'airblade/vim-gitgutter'
    Plug 'andymass/vim-matchup'
    Plug 'bfredl/nvim-ipy'
    Plug 'bioSyntax/bioSyntax-vim'
    Plug 'burneyy/vim-snakemake'
    Plug 'chrisbra/csv.vim'
    Plug 'dense-analysis/ale'
    Plug 'dylanaraps/wal.vim'
    Plug 'drzel/vim-line-no-indicator'
    Plug 'embark-theme/vim', { 'as': 'embark' }
    Plug 'ervandew/supertab'
    Plug 'guns/xterm-color-table.vim'
    Plug 'henrik/vim-indexed-search'
    Plug 'honza/vim-snippets'
    Plug 'jalvesaq/Nvim-R'
    Plug 'JuliaEditorSupport/julia-vim'
    Plug 'fatih/vim-go'
    Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
    Plug 'junegunn/fzf.vim'
    Plug 'kshenoy/vim-signature'
    Plug 'kana/vim-operator-user'
    Plug 'MarcWeber/vim-addon-mw-utils'
    Plug 'mboughaba/i3config.vim'
    Plug 'mllg/vim-devtools-plugin'
    Plug 'mzlogin/vim-markdown-toc'
    Plug 'nathanaelkane/vim-indent-guides'
    Plug 'ncm2/float-preview.nvim'
    Plug 'psf/black', { 'branch': 'stable' }
    Plug 'raimon49/requirements.txt.vim'
    Plug 'rrethy/vim-hexokinase', { 'do': 'make hexokinase' }
    Plug 'romgrk/barbar.nvim'
    Plug 'Shougo/denite.nvim', { 'do': ':UpdateRemotePlugins' }
    Plug 'Shougo/neomru.vim'
    Plug 'scrooloose/nerdcommenter'
    Plug 'sslivkoff/vim-scroll-barnacle'
    Plug 'stephpy/vim-yaml'
    Plug 'tmux-plugins/vim-tmux-focus-events'
    Plug 'tomtom/tlib_vim'
    Plug 'tpope/vim-repeat'
    Plug 'tpope/vim-surround'
    Plug 'wellle/targets.vim'
    Plug 'wincent/terminus'
    Plug 'xolox/vim-colorscheme-switcher'
    Plug 'xolox/vim-misc'
    Plug '/usr/share/vim/vimfiles'

    " Plug 'qpkorr/vim-bufkill'
    "Plug 'manabuishii/vim-cwl'
    "Plug 'mrk21/yaml-vim'
    "Plug 'plasticboy/vim-markdown'
    " Plug 'majutsushi/tagbar'

    "Plug 'zhaozg/vim-diagram'
    "Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }
    "Plug 'tikhomirov/vim-glsl'
    "Plug 'terryma/vim-expand-region'
    "Plug 'gcavallanti/vim-noscrollbar'
    "Plug 'ekiim/vim-mathpix'

    Plug 'glts/vim-textobj-comment'
    Plug 'kana/vim-textobj-user'
    Plug 'tyru/vim-textobj-underscore', { 'branch': 'support-3-cases' }
    "Plug 'vim-scripts/argtextobj.vim'
    "Plug 'vimtaku/vim-textobj-keyvalue'

    Plug 'agreco/vim-citylights'
    Plug 'ayu-theme/ayu-vim'
    Plug 'challenger-deep-theme/vim'
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
    Plug 'jacoborus/tender.vim'
    Plug 'joshdick/onedark.vim'
    Plug 'KeitaNakamura/neodark.vim'
    Plug 'liuchengxu/space-vim-dark'
    Plug 'lu-ren/SerialExperimentsLain'
    Plug 'NLKNguyen/papercolor-theme'
    Plug 'rakr/vim-one'
    Plug 'reedes/vim-colors-pencil'
    Plug 'Rigellute/rigel'
    Plug 'tyrannicaltoucan/vim-quantum'
    Plug 'tyrannicaltoucan/vim-deep-space'
    Plug 'vim-scripts/pyte'
    Plug 'whatyouhide/vim-gotham'
    Plug 'wimstefan/Lightning'
    " Plug 'sonph/onehalf', {'rtp': 'vim/'}
    " Plug 'connorholyday/vim-snazzy'
    " Plug 'fmoralesc/molokayo'
    " Plug 'mhartington/oceanic-next'
    " Plug 'morhetz/gruvbox'
    " Plug 'sheerun/vim-wombat-scheme'
    " Plug 'vim-scripts/summerfruit256.vim'
    " Plug 'yuttie/hydrangea-vim'
    " Plug 'zanloy/vim-colors-grb256'


    Plug 'vim-airline/vim-airline'
    Plug 'vim-airline/vim-airline-themes'

    "Plug 'bioSyntax/bioSyntax-vim'
    "Plug 'chriskempson/base16-vim'
    "Plug 'severin-lemaignan/vim-minimap'
    "Plug 'yuttie/comfortable-motion.vim'
    "Plug 'hkupty/iron.nvim'
    "Plug 'hyiltiz/vim-plugins-profile'
    "Plug 'troydm/zoomwintab.vim'
    "Plug 'liuchengxu/vim-which-key', { 'on': ['WhichKey', 'WhichKey!'] }
    "Plug 'davidoc/taskpaper.vim'
    "Plug 'Shougo/neosnippet.vim'
    "Plug 'Shougo/neosnippet-snippets'
    "Plug 'freitass/todo.txt-vim'
    "Plug 'Alok/notational-fzf-vim'
    "Plug 'deoplete-plugins/deoplete-jedi'
    "Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
    "Plug 'Shougo/deoplete-terminal'
    "Plug 'vimwiki/vimwiki'
    "Plug 'godlygeek/tabular'
    "Plug 'neoclide/coc.nvim', {'branch': 'release'}
    "
    " overrides filetype tabstop, etc. options
    "Plug 'editorconfig/editorconfig-vim'

    " conflicts with lightline-bufferline
    "Plug 'nightsense/night-and-day'

    " Requires +conceal feature not compiled in Arch
    " Plug 'vim-pandoc/vim-pandoc'
    " Plug 'vim-pandoc/vim-pandoc-syntax'
    " Plug 'vim-pandoc/vim-rmarkdown'

    " devicons should always be loaded last
    Plug 'kyazdani42/nvim-web-devicons'
    Plug 'ryanoasis/vim-devicons'
call plug#end()

" ----------------------------------------------------------------------------
" Vim Shortcut Helper
"
" TODO: create func to open markdown cheatsheet in sidepane / close
" the buffer if it is already open/visible..
" ----------------------------------------------------------------------------
" if bufwinnr("~/d/notes/linux/vim/cheatsheet.md") > 0
"   echo "Already open"
" endif

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
set relativenumber              " enable relative line numbers
set number                      " line numbers
set whichwrap+=<,>,h,l,[,]      " backspace and cursor keys wrap to
set shortmess=filtIoOA          " shorten messages
set report=0                    " tell us about changes
set nostartofline               " don't jump to the start of line when scrolling

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

"disabling smart-indent: may be preventing comments from indenting?
"http://stackoverflow.com/questions/191201/indenting-comments-to-match-code-in-vim

set smartindent       " wise indentation
set nowrap            " do not wrap lines
set softtabstop=4     " tab width
set shiftwidth=4
set shiftround        " round indents to multiple of shift width
set tabstop=4
set expandtab         " expand tabs to spaces
set smarttab
set textwidth=88      " stick to 88 characters or less, when possible
set formatoptions+=n  " support for numbered/bullet lists
set virtualedit=block " allow virtual edit in visual block ..
set pastetoggle=<F6>  " paste-mode toggle

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
autocmd BufLeave * call AutoSaveWinView()
autocmd BufEnter * call AutoRestoreWinView()

" Remember info about open buffers on close
set viminfo^=%

" Enable cursor shape support
set guicursor=n-v-c:block-Cursor/lCursor-blinkon0,
            \i-ci:ver25-Cursor/lCursor,
            \r-cr:hor20-Cursor/lCursor

" Faster command execution
nnoremap ! :!

" ---------------------------------------------------------------------------
"  Appearance
" ---------------------------------------------------------------------------
if $TERM != 'linux'
    set t_Co=256
endif

" fix background bleeding in screen
" http://sunaku.github.io/vim-256color-bce.html
set t_ut=""

set background=dark

" enable true colors (disable for pywal support)
set termguicolors

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
highlight SpecialKey ctermfg=DarkGray ctermbg=Black

" ---------------------------------------------------------------------------
"
" CriticMarkup highlight
"
" ---------------------------------------------------------------------------
vmap <leader>l c<C-R>=substitute(@", '\v(.*)', '\{==\1==\}\{>><<\}', '')<ESC>

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
" nnoremap p p`]<Esc>

" insert blank line without entering insert mode
" nmap <c-o> O<Esc> " used to navigate jump list..
" nmap <CR> o<Esc>

" ---------------------------------------------------------------------------
"  Strip all trailing whitespace in file
" ---------------------------------------------------------------------------
function! StripWhitespace ()
    exec ':%s/ \+$//gc'
endfunction
map <localleader>s :call StripWhitespace ()<CR>

" ----------------------------------------------------------------------------
"  Scratchpad
" ----------------------------------------------------------------------------
function! AddScratchpadEntry ()
    " find entries heading and move cursor to following line
    exec ":normal /Entries/\<CR>"
    normal! 2j

    " add timestamp
    " exec ":put=strftime('-%c-')"
    exec ":put=strftime('-%b %d %Y %H:%M:%S-')"

    " add new lines
    call append(line("."), ["", "", ""])

    " go down two lines
    " exec ":normal "
    call cursor(line('.') + 2, 1)

    " enter insert mode
    call feedkeys('A', 'n')
endfunction

" similar to above, but for adding simple timestamps to markdown files
function! AddTimeStamp ()
    " add timestamp
    call append(line("."), [strftime('%b %d %Y'), "-----------", ""])
    normal! 3j

    " enter insert mode
    call feedkeys('A', 'n')
endfunction

autocmd BufNewFile,BufRead titan,io,ganymede set syntax=scratch
autocmd BufNewFile,BufRead titan,io,ganymede set filetype=scratch
autocmd FileType scratch map <silent><leader>s :call AddScratchpadEntry ()<CR>
autocmd FileType markdown map <silent><leader>s :call AddTimeStamp()<CR>

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
set infercase  " case insensitive tab completion
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
"
" Scriptnames helper function
" https://vim.fandom.com/wiki/List_loaded_scripts
"
" ---------------------------------------------------------------------------
function! s:Scratch (command, ...)
   redir => lines
   let saveMore = &more
   set nomore
   execute a:command
   redir END
   let &more = saveMore
   call feedkeys("\<cr>")
   new | setlocal buftype=nofile bufhidden=hide noswapfile
   put=lines
   if a:0 > 0
      execute 'vglobal/'.a:1.'/delete'
   endif
   if a:command == 'scriptnames'
      %substitute#^[[:space:]]*[[:digit:]]\+:[[:space:]]*##e
   endif
   silent %substitute/\%^\_s*\n\|\_s*\%$
   let height = line('$') + 3
   execute 'normal! z'.height."\<cr>"
   0
endfunction

command! -nargs=? Scriptnames call <sid>Scratch('scriptnames', <f-args>)
command! -nargs=+ Scratch call <sid>Scratch(<f-args>)

" ---------------------------------------------------------------------------
"  airline
" ---------------------------------------------------------------------------
let g:airline_powerline_fonts = 1
let g:airline#extensions#ale#enabled = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#wordcount#enabled = 1
let g:airline_theme = 'quantum'

" ---------------------------------------------------------------------------
"  ale
" ---------------------------------------------------------------------------
" nmap <silent> <C-k> <Plug>(ale_previous_wrap)
" nmap <silent> <C-j> <Plug>(ale_next_wrap)
let g:ale_fixers = {'r': ['styler', 'trim_whitespace'], 'rmd': ['styler', 'trim_whitespace']}
let g:ale_r_lintr_options = "with_defaults(line_length_linter(100),single_quotes_linter=NULL,commented_code_linter=NULL,object_name_linter=NULL,object_usage_linter=NULL)"

" ---------------------------------------------------------------------------
"  barbar.nvim
" ---------------------------------------------------------------------------
nnoremap <silent>    <leader>bd :BufferClose<CR>
nnoremap <silent>    <S-Tab> :BufferPrevious<CR>
nnoremap <silent>    <Tab> :BufferNext<CR>
nnoremap <silent>    <S-left> :BufferPrevious<CR>
nnoremap <silent>    <S-right> :BufferNext<CR>

" ---------------------------------------------------------------------------
"  black
" ---------------------------------------------------------------------------
"au BufWritePre *.py execute ':Black'

" ---------------------------------------------------------------------------
" csv.vim
" ---------------------------------------------------------------------------
let g:csv_no_conceal = 1

" ---------------------------------------------------------------------------
" coc.nvim
" ---------------------------------------------------------------------------

" disable backups (may be neccessary...)
" https://github.com/neoclide/coc.nvim/issues/649
" setlocal nobackup
" setlocal nowritebackup

" Better display for messages
" set cmdheight=2
"
" " You will have bad experience for diagnostic messages when it's default 4000.
" set updatetime=300
"
" " don't give |ins-completion-menu| messages.
" set shortmess+=c
"
" " always show signcolumns
" set signcolumn=yes
"
" " if nvm is set to lazy-load via zplugin, path will need to be manually specified
" "let g:coc_node_path="/home/keith/.nvm/versions/node/v12.9.1/bin/node"
"
" " extensions to install
" let g:coc_global_extensions = ['coc-r-lsp']
"
" " Use tab for trigger completion with characters ahead and navigate.
" inoremap <silent><expr> <TAB>
"       \ pumvisible() ? "\<C-n>" :
"       \ <SID>check_back_space() ? "\<TAB>" :
"       \ coc#refresh()
" inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"
"
" function! s:check_back_space() abort
"   let col = col('.') - 1
"   return !col || getline('.')[col - 1]  =~# '\s'
" endfunction
"
" " Use <c-space> to trigger completion.
" inoremap <silent><expr> <c-space> coc#refresh()
"
" " Use <cr> to confirm completion, `<C-g>u` means break undo chain at current position.
" " Coc only does snippet and additional edit on confirm.
" inoremap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"
"
" " Also allow confirmation using <TAB>
" inoremap <expr> <TAB> pumvisible() ? "\<C-y>" : "\<C-g>u\<TAB>"
"
" " Or use `complete_info` if your vim support it, like:
" " inoremap <expr> <cr> complete_info()["selected"] != "-1" ? "\<C-y>" : "\<C-g>u\<CR>"
"
" " Use `[g` and `]g` to navigate diagnostics
" nmap <silent> [g <Plug>(coc-diagnostic-prev)
" nmap <silent> ]g <Plug>(coc-diagnostic-next)
"
" " Remap keys for gotos
" nmap <silent> gd <Plug>(coc-definition)
" nmap <silent> gy <Plug>(coc-type-definition)
" nmap <silent> gi <Plug>(coc-implementation)
" nmap <silent> gr <Plug>(coc-references)
"
" " Use K to show documentation in preview window
" nnoremap <silent> K :call <SID>show_documentation()<CR>
"
" function! s:show_documentation()
"   if (index(['vim','help'], &filetype) >= 0)
"     execute 'h '.expand('<cword>')
"   else
"     call CocAction('doHover')
"   endif
" endfunction
"
" " Highlight symbol under cursor on CursorHold
" " 2020-01-28: disabled for now due to conflict with coc-r-lsp
" " autocmd CursorHold * silent call CocActionAsync('highlight')
"
" " Remap for rename current word
" nmap <leader>rn <Plug>(coc-rename)
"
" " Remap for format selected region
" xmap <leader>f  <Plug>(coc-format-selected)
" nmap <leader>f  <Plug>(coc-format-selected)
"
" augroup mygroup
"   autocmd!
"   " Setup formatexpr specified filetype(s).
"   autocmd FileType typescript,json setl formatexpr=CocAction('formatSelected')
"   " Update signature help on jump placeholder
"   autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
" augroup end
"
" " Remap for do codeAction of selected region, ex: `<leader>aap` for current paragraph
" xmap <leader>a  <Plug>(coc-codeaction-selected)
" nmap <leader>a  <Plug>(coc-codeaction-selected)
"
" " Remap for do codeAction of current line
" nmap <leader>ac  <Plug>(coc-codeaction)
" " Fix autofix problem of current line
" nmap <leader>qf  <Plug>(coc-fix-current)
"
" " Create mappings for function text object, requires document symbols feature of languageserver.
" xmap if <Plug>(coc-funcobj-i)
" xmap af <Plug>(coc-funcobj-a)
" omap if <Plug>(coc-funcobj-i)
" omap af <Plug>(coc-funcobj-a)
"
" " Use <TAB> for select selections ranges, needs server support, like: coc-tsserver, coc-python
" nmap <silent> <TAB> <Plug>(coc-range-select)
" xmap <silent> <TAB> <Plug>(coc-range-select)
"
" " Use `:Format` to format current buffer
" command! -nargs=0 Format :call CocAction('format')
"
" " Use `:Fold` to fold current buffer
" command! -nargs=? Fold :call     CocAction('fold', <f-args>)
"
" " use `:OR` for organize import of current buffer
" command! -nargs=0 OR   :call     CocAction('runCommand', 'editor.action.organizeImport')
"
" " Add status line support, for integration with other plugin, checkout `:h coc-status`
" set statusline^=%{coc#status()}%{get(b:,'coc_current_function','')}
"
" " Using CocList
" " Show all diagnostics
" nnoremap <silent> <space>a  :<C-u>CocList diagnostics<cr>
" " Manage extensions
" nnoremap <silent> <space>e  :<C-u>CocList extensions<cr>
" " Show commands
" nnoremap <silent> <space>c  :<C-u>CocList commands<cr>
" " Find symbol of current document
" nnoremap <silent> <space>o  :<C-u>CocList outline<cr>
" " Search workspace symbols
" nnoremap <silent> <space>s  :<C-u>CocList -I symbols<cr>
" " Do default action for next item.
" nnoremap <silent> <space>j  :<C-u>CocNext<CR>
" " Do default action for previous item.
" nnoremap <silent> <space>k  :<C-u>CocPrev<CR>
" " Resume latest coc list
" nnoremap <silent> <space>p  :<C-u>CocListResume<CR>

" ---------------------------------------------------------------------------
"  vim-hexokinase
" ---------------------------------------------------------------------------
"let g:Hexokinase_highlighters = ['backgroundfull']
let g:Hexokinase_highlighters = ['sign_column']

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
" indent guides
" ---------------------------------------------------------------------------
let g:indent_guides_auto_colors = 0
let g:indent_guides_auto_colors = 1
let g:indent_guides_start_level = 2
let g:indent_guides_guide_size  = 1

" ---------------------------------------------------------------------------
" julia-vim
" ---------------------------------------------------------------------------
" autocmd BufNewFile,BufRead *.jl set syntax=julia

" ---------------------------------------------------------------------------
"  NERDcommenter
" ---------------------------------------------------------------------------
let g:NERDDefaultAlign = 'left'
let g:NERDSpaceDelims = 1
let g:NERDCommentEmptyLines = 1
let g:NERDTrimTrailingWhitespace = 1

let g:NERDCustomDelimiters = {
    \ 'snakemake' : { 'left': '#' },
    \ 'rmd': { 'left': '#' }
    \ }

" disabled sept 7, 2020 (nvim-ipy compat)
" nmap <space> <leader>c<space>
" vmap <space> <leader>c<space>

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

" italic latex work-around
" https://stackoverflow.com/a/34645680/554531
syn region math start=/\$\$/ end=/\$\$/

" inline math
syn match math '\$[^$].\{-}\$'

" actually highlight the region we defined as "math"
hi link math Statement

" underline current line; useful for markdown headings
function CreateHeading(char)
    let size = strwidth(getline('.'))
    execute "normal! o\<ESC>"
    execute "normal!" . size . "I" . a:char . "\<ESC>"
    execute "normal! o\<ESC>"
    execute "normal! o"
    call feedkeys('A', 'n')
endfunction

nnoremap <F5> :call CreateHeading("=")<CR>
inoremap <F5> <Esc> :call CreateHeading("=")<CR>
nnoremap <leader><F5> :call CreateHeading("-")<CR>
inoremap <leader><F5> <Esc>:call CreateHeading("-")<CR>

" ---------------------------------------------------------------------------
"  markdown link helper
"  https://benjamincongdon.me/blog/2020/06/27/Vim-Tip-Paste-Markdown-Link-with-Automatic-Title-Fetching/
" ---------------------------------------------------------------------------
function GetURLTitle(url)
    " Bail early if the url obviously isn't a URL.
    if a:url !~ '^https\?://'
        return ""
    endif

    " Use Python/BeautifulSoup to get link's page title.
    let title = system("python3 -c \"import bs4, requests; print(bs4.BeautifulSoup(requests.get('" . a:url . "').content, 'lxml').title.text.strip())\"")

    " Echo the error if getting title failed.
    if v:shell_error != 0
        echom title
        return ""
    endif

    " Strip trailing newline
    return substitute(title, '\n', '', 'g')
endfunction

function PasteMDLink()
    " generate markdown url
    let url = getreg("+")
    let title = GetURLTitle(url)
    let mdLink = printf("[%s](%s)", title, url)

    " temporarily disable line length limit, if specified
    if &textwidth != 0
        let b:oldtextwidth = &textwidth
        set textwidth=0
    endif

    " add link to document
    execute "normal! a" . mdLink . "\<Esc>"

    " restore line length limit
    if exists("b:oldtextwidth")
        let &textwidth = b:oldtextwidth
    endif
endfunction

" Make a keybinding (mnemonic: "mark down paste")
nmap <Leader>f :call PasteMDLink()<CR>

" ---------------------------------------------------------------------------
"  vim-diagram (mermaid)
" ---------------------------------------------------------------------------
au BufRead,BufNewFile *.mmd set filetype=sequence

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
    nnoremap <silent><buffer><expr> d denite#do_map('do_action', 'delete')
    nnoremap <silent><buffer><expr> p denite#do_map('do_action', 'preview')
    nnoremap <silent><buffer><expr> q denite#do_map('quit')
    nnoremap <silent><buffer><expr> i denite#do_map('open_filter_buffer')
    nnoremap <silent><buffer><expr> <Space> denite#do_map('toggle_select').'j'
endfunction

autocmd FileType denite-filter call s:denite_filter_my_settings()
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

" search notes
command! -bang Notes call fzf#vim#files('~/d/notes', <bang>0)
map <localleader>n :Notes<CR>

"nmap <leader><tab> <plug>(fzf-maps-n)
"xmap <leader><tab> <plug>(fzf-maps-x)
"omap <leader><tab> <plug>(fzf-maps-o)

" ---------------------------------------------------------------------------
"  vim-scroll-barnacle
" ---------------------------------------------------------------------------
highlight link Scrollbar Float
"highlight link Scrollbar TabLineSel

" don't override zz mapping
let g:sb_patch_keys = 0

" ---------------------------------------------------------------------------
" supertab.vim
" ---------------------------------------------------------------------------
let g:SuperTabCrMapping=1
let g:SuperTabDefaultCompletionType = "<c-n>"
let g:SuperTabDefaultCompletionType = "context"

" ---------------------------------------------------------------------------
"  tagbar
" ---------------------------------------------------------------------------
" nmap <F9> :TagbarToggle<CR>

" let g:tagbar_type_r = {
"     \ 'ctagstype' : 'r',
"     \ 'kinds'     : [
"         \ 'f:Functions',
"         \ 'g:GlobalVariables',
"         \ 'v:FunctionVariables',
"     \ ]
" \ }

" Add support for markdown files in tagbar.
" let g:tagbar_type_markdown = {
"     \ 'ctagstype': 'markdown',
"     \ 'ctagsbin' : '~/bin/markdown2ctags.py',
"     \ 'ctagsargs' : '-f - --sort=yes --sro=»',
"     \ 'kinds' : [
"         \ 's:sections',
"         \ 'i:images'
"     \ ],
"     \ 'sro' : '»',
"     \ 'kind2scope' : {
"         \ 's' : 'section',
"     \ },
"     \ 'sort': 0,
" \ }

" ---------------------------------------------------------------------------
"  vim-expand-region
" ---------------------------------------------------------------------------
vmap v <Plug>(expand_region_expand)
vmap <C-v> <Plug>(expand_region_shrink)

" ---------------------------------------------------------------------------
"  vim-textobj-underscore
" ---------------------------------------------------------------------------
nmap cid ci_
nmap cad ca_
nmap did di_
nmap dad da_

" ---------------------------------------------------------------------------
"  VimWiki
" ---------------------------------------------------------------------------
let g:vimwiki_list = [{'path': '~/d/notes/',
                      \ 'syntax': 'markdown',
                      \ 'ext': '.md'}]

" only set filetype to vimwiki for files in specified vimwiki path
let g:vimwiki_global_ext = 0

" tagbar integration
" let g:tagbar_type_vimwiki = {
"           \   'ctagstype':'vimwiki'
"           \ , 'kinds':['h:header']
"           \ , 'sro':'&&&'
"           \ , 'kind2scope':{'h':'header'}
"           \ , 'sort':0
"           \ , 'ctagsbin':'~/bin/vwtags.py'
"           \ , 'ctagsargs': 'markdown'
"           \ }
"

" ---------------------------------------------------------------------------
"  Host-specific configuration
" ---------------------------------------------------------------------------
let hostfile=$XDG_CONFIG_HOME . '/nvim/' . substitute(hostname(), "\\..*", "", "") . '-local.vim'
if filereadable(hostfile)
    exe 'source ' . hostfile
endif

" ---------------------------------------------------------------------------
"  Language-specific Options
" ---------------------------------------------------------------------------

" Language-specific options
autocmd FileType html,css,markdown,ruby,r,rmd,jinja,yaml setlocal softtabstop=2 shiftwidth=2 tabstop=2
autocmd BufRead,BufNewFile *.py set autoindent

" nvim-ipy
let g:nvim_ipy_perform_mappings = 0

" ---------------------------------------------------------------------------
"  Language-specific Options
" ---------------------------------------------------------------------------
let g:onedark_terminal_italics=1
let g:gruvbox_italic=1
let g:quantum_black=1
let g:quantum_italics=1

colorscheme quantum

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

syntax on

hi ColorColumn ctermbg=234 guibg=#222222
hi MatchParen cterm=bold ctermbg=none ctermfg=red
hi Conceal guibg=background guifg=foreground

