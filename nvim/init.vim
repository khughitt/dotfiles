" ---------------------------------------------------------------------------
"
" Neovim Configuration
" KH (Aug 2021)
"
" ---------------------------------------------------------------------------
"
" Useful commands:
"
" :verbose set <var>?    find where a setting was made
" :scriptnames           list vimscripts loaded
"

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

" enable mouse wheel in terminal, etc.
set mouse=a

" ---------------------------------------------------------------------------
" vim-plug
" ---------------------------------------------------------------------------
call plug#begin()
    " general
    Plug 'andymass/vim-matchup'
    Plug 'ggandor/lightspeed.nvim'
    Plug 'dstein64/nvim-scrollview', { 'branch': 'main' }
    Plug 'dylanaraps/wal.vim'
    Plug 'editorconfig/editorconfig-vim'
    Plug 'ervandew/supertab'
    Plug 'godlygeek/tabular'
    Plug 'JoosepAlviste/nvim-ts-context-commentstring'
    Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
    Plug 'junegunn/fzf.vim'
    Plug 'junegunn/vim-emoji'
    Plug 'KabbAmine/vCoolor.vim'
    Plug 'kshenoy/vim-signature'
    Plug 'kana/vim-operator-user'
    Plug 'nathanaelkane/vim-indent-guides'
    Plug 'ncm2/float-preview.nvim'
    Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
    Plug 'rrethy/vim-hexokinase', { 'do': 'make hexokinase' }
    " slow with multiple mnd tabs open?..
    Plug 'romgrk/barbar.nvim'
    Plug 'scrooloose/nerdcommenter'
    Plug 'tomtom/tlib_vim'
    Plug 'tpope/vim-repeat'
    Plug 'tpope/vim-surround'
    Plug 'vim-airline/vim-airline'
    Plug 'vim-airline/vim-airline-themes'
    Plug 'wellle/targets.vim'
    Plug 'xolox/vim-colorscheme-switcher'
    Plug 'xolox/vim-misc'
    Plug 'Yggdroot/LeaderF', { 'do': ':LeaderfInstallCExtension' }
    Plug '/usr/share/vim/vimfiles'

    " language support
    Plug 'bioSyntax/bioSyntax-vim'
    Plug 'ibab/vim-snakemake'
    Plug 'chrisbra/csv.vim'
    Plug 'glench/vim-jinja2-syntax'
    Plug 'jalvesaq/Nvim-R'
    Plug 'JuliaEditorSupport/julia-vim'
    Plug 'fatih/vim-go'
    Plug 'pangloss/vim-javascript'
    Plug 'mllg/vim-devtools-plugin'
    Plug 'mzlogin/vim-markdown-toc'
    Plug 'maxmellon/vim-jsx-pretty'
    Plug 'mboughaba/i3config.vim'
    Plug 'raimon49/requirements.txt.vim'
    Plug 'stephpy/vim-yaml'
    Plug 'tikhomirov/vim-glsl'
    Plug 'udalov/kotlin-vim'
    Plug 'yuezk/vim-js'

    " textobjs
    Plug 'glts/vim-textobj-comment'
    Plug 'kana/vim-textobj-user'
    Plug 'tyru/vim-textobj-underscore', { 'branch': 'support-3-cases' }

    " colorschemes
    Plug 'agreco/vim-citylights'
    Plug 'ayu-theme/ayu-vim'
    Plug 'christianchiarulli/nvcode-color-schemes.vim'
    Plug 'cseelus/vim-colors-lucid'
    Plug 'cseelus/vim-colors-tone'
    Plug 'danilo-augusto/vim-afterglow'
    Plug 'dense-analysis/ale'
    Plug 'dikiaap/minimalist'
    Plug 'dracula/vim', { 'as': 'dracula' }
    Plug 'drewtempelmeyer/palenight.vim'
    Plug 'Dru89/vim-adventurous'
    Plug 'embark-theme/vim', { 'as': 'embark' }
    Plug 'fcpg/vim-orbital'
    Plug 'fenetikm/falcon'
    Plug 'jacoborus/tender.vim'
    Plug 'navarasu/onedark.nvim'
    Plug 'KeitaNakamura/neodark.vim'
    Plug 'nikolvs/vim-sunbather'
    Plug 'NLKNguyen/papercolor-theme'
    Plug 'owickstrom/vim-colors-paramount'
    Plug 'rakr/vim-one'
    Plug 'rakr/vim-two-firewatch'
    Plug 'reedes/vim-colors-pencil'
    Plug 'rockerBOO/boo-colorscheme-nvim'
    Plug 'sainnhe/sonokai'
    Plug 'tyrannicaltoucan/vim-quantum'
    Plug 'tyrannicaltoucan/vim-deep-space'
    Plug 'vim-scripts/pyte'
    Plug 'whatyouhide/vim-gotham'
    Plug 'wimstefan/Lightning'
    Plug 'wlemuel/vim-tldr'

    " mindful
    Plug '~/.config/nvim/plugged/mindful.vim'

    " disabled plugins
    "Plug 'airblade/vim-gitgutter'
    "Plug 'qpkorr/vim-bufkill'
    "Plug 'manabuishii/vim-cwl'
    "Plug 'mrk21/yaml-vim'
    "Plug 'plasticboy/vim-markdown'
    "Plug 'MarcWeber/vim-addon-mw-utils'
    "Plug 'zhaozg/vim-diagram'
    "Plug 'ekiim/vim-mathpix'
    "Plug 'yuttie/comfortable-motion.vim'
    "Plug 'troydm/zoomwintab.vim'
    "Plug 'liuchengxu/vim-which-key', { 'on': ['WhichKey', 'WhichKey!'] }
    "Plug 'Shougo/neomru.vim'
    "Plug 'Shougo/neosnippet.vim'
    "Plug 'Shougo/neosnippet-snippets'
    "Plug 'neoclide/coc.nvim', {'branch': 'release'}
    "Plug 'vim-pandoc/vim-pandoc'
    "Plug 'vim-pandoc/vim-pandoc-syntax'
    "Plug 'bfredl/nvim-ipy'
    "Plug 'drzel/vim-line-no-indicator'
    "Plug 'junegunn/goyo.vim'
    "Plug 'guns/xterm-color-table.vim'
    "Plug 'honza/vim-snippets'
    "Plug 'junegunn/limelight.vim'
    "Plug 'wincent/terminus'
    " Plug 'psf/black', { 'branch': 'stable', 'for': 'python' }
    
    "Plug 'challenger-deep-theme/vim'
    "Plug 'cocopon/iceberg.vim'
    "Plug 'davidklsn/vim-sialoquent'
    "Plug 'haishanh/night-owl.vim'
    "Plug 'liuchengxu/space-vim-dark'
    "Plug 'lu-ren/SerialExperimentsLain'
    "Plug 'Rigellute/rigel'
    
    " devicons should always be loaded last
    Plug 'kyazdani42/nvim-web-devicons'
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
" set shortmess=aF                " shorten messages
set shortmess+=F                " shorten messages
set cmdheight=1                 " default cmdline height
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
set softtabstop=2     " tab width
set shiftwidth=2
set shiftround        " round indents to multiple of shift width
set tabstop=2
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
" nnoremap ss i<space><esc>

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

" preserve primary buffer on exit
" https://stackoverflow.com/questions/6453595/prevent-vim-from-clearing-the-clipboard-on-exit
autocmd VimLeave * call system("xsel -ip", getreg('+'))

" ----------------------------------------------------------------------------
"  Refresh syntax when saving new files
" ----------------------------------------------------------------------------
au BufWritePost * if &syntax == '' | :filetype detect | endif

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
"  Strip all trailing whitespace in file
" ---------------------------------------------------------------------------
function! StripWhitespace ()
    exec ':%s/ \+$//gc'
endfunction
map <localleader>s :call StripWhitespace ()<CR>

" ---------------------------------------------------------------------------
"  Split paragraph into sentences
" ---------------------------------------------------------------------------
function! SplitParagraph ()
    "todo: extend to perform vis selection on spread text and call 'gq'
    "let line = getline('.')
    exec ':s/[!\?\.] /.\r\r/g'
endfunction
map <localleader>p :call SplitParagraph ()<CR>

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
"  Terminal
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
let g:ale_fixers = {
  \ 'r': ['styler', 'trim_whitespace'], 
  \ 'rmd': ['styler', 'trim_whitespace'],
  \ 'python': ['pyright']
\}

let g:ale_r_lintr_options = "with_defaults(line_length_linter(100),single_quotes_linter=NULL,commented_code_linter=NULL,object_name_linter=NULL,object_usage_linter=NULL)"

" use quickfix list instead of loclist
let g:ale_set_loclist = 0
let g:ale_set_quickfix = 1

" create shortcut to toggle quickfix visibility
" https://stackoverflow.com/a/63162084/554531
function! ToggleQuickFix()
    if empty(filter(getwininfo(), 'v:val.quickfix'))
        copen
    else
        cclose
    endif
endfunction

nnoremap <silent> <F2> :call ToggleQuickFix()<cr>

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
" au BufWritePre *.py execute ':Black'

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
"let g:Hexokinase_highlighters = ['sign_column']
let g:Hexokinase_highlighters = ['foregroundfull']

" ---------------------------------------------------------------------------
"  colorscheme-switcher.vim
" ---------------------------------------------------------------------------
let g:colorscheme_switcher_exclude = [
            \ 'blue', 'darkblue', 'default', 'delek', 'desert', 'elflord',
            \ 'evening', 'gotham256', 'industry', 'koehler', 'morning',
            \ 'murphy', 'pablo', 'peachpuff', 'ron', 'shine', 'slate',
            \ 'torte', 'zellner']

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
" LeaderF
" ---------------------------------------------------------------------------
let g:Lf_ShortcutF = '<c-f>'
let g:Lf_WindowPosition = 'popup'
let g:Lf_PreviewInPopup = 1

noremap <c-p> :<C-U><C-R>=printf("Leaderf --nowrap mru %s", "")<CR><CR>

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
"  treesitter.nvim
" ---------------------------------------------------------------------------
lua <<EOF
require'nvim-treesitter.configs'.setup {
  ensure_installed = { "bash", "c", "cmake", "cpp", "css", "dockerfile", "go", "json", "julia", "lua", "latex", "r", "toml", "yaml" },
  ignore_install = {  },
  highlight = {
    enable = true,
    disable = { 'rmd' },
  },
  context_commentstring = {
    enable = true
  },
}
EOF

" ---------------------------------------------------------------------------
"   nvcode-color-schemes
" ---------------------------------------------------------------------------
let g:nvcode_termcolors=256

syntax on
colorscheme onedark

" checks if your terminal has 24-bit color support
if (has("termguicolors"))
    set termguicolors
    hi LineNr ctermbg=NONE guibg=NONE
endif

" ---------------------------------------------------------------------------
"  onedark.nvim
" ---------------------------------------------------------------------------
lua <<EOF
require('onedark').setup()
EOF

" ----------------------------------------------------------------------------
"  mindful
" ----------------------------------------------------------------------------
set dictionary+=~/.vim/tmp/mindful/tags.txt

autocmd BufNewFile,BufRead *.mnd set syntax=mindful
autocmd BufNewFile,BufRead *.mnd set filetype=mindful

" ----------------------------------------------------------------------------
"  vim-matchup
" ----------------------------------------------------------------------------
"  temp work-around (sept 1, 2021)
"  https://github.com/vim/vim/issues/2049#issuecomment-829424555
set mmp=30000 

" ---------------------------------------------------------------------------
"  vim-diagram (mermaid)
" ---------------------------------------------------------------------------
" au BufRead,BufNewFile *.mmd set filetype=sequence

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
"  fzf.vim
" ---------------------------------------------------------------------------
let g:fzf_layout = { 'window': 'enew' }
let g:fzf_layout = { 'window': '-tabnew' }
let g:fzf_layout = { 'window': '10split enew' }
let g:fzf_layout = { 'down': '~40%' }

cmap <C-r> :History:<CR>

" Ag
map <leader>a :Ag<CR>

" create a `Notes` command to search notes
command! -bang Notes call fzf#vim#files('~/notes', <bang>0)
map <leader>j :Notes<CR>

" ---------------------------------------------------------------------------
"  Limelight
" ---------------------------------------------------------------------------
let g:limelight_bop = '^\n-[A-Z]'
let g:limelight_eop = '\ze\n^-[A-Z]'

nmap <localleader>l :Limelight!!<CR>

" ---------------------------------------------------------------------------
" vim-emoji
"
" https://www.webfx.com/tools/emoji-cheat-sheet/
"
" ---------------------------------------------------------------------------
" enable completion (currently not working..)
" set omnifunc=syntaxcomplete#Complete
" set completefunc=emoji#complete

" replace :emoji_name: into emojis
function! AddEmojis ()
    exec ':%s/:\([^:]\+\):/\=emoji#for(submatch(1), submatch(0))/g'
endfunction

map <leader>e :call AddEmojis ()<CR>

" ---------------------------------------------------------------------------
"  vim-pandoc
" ---------------------------------------------------------------------------
" let g:pandoc#modules#disabled = ["spell"]
" let g:pandoc#syntax#conceal#blacklist = ["codeblock_start", "codeblock_delim",
                                       \ "atx", "footnote"]

" make vim-pandoc behave well
" autocmd FileType pandoc setlocal nowrap
" autocmd FileType pandoc setlocal foldcolumn=0

" ---------------------------------------------------------------------------
" supertab.vim
" ---------------------------------------------------------------------------
let g:SuperTabCrMapping=1
let g:SuperTabDefaultCompletionType = "context"

" add support for mindful #tag completion
function MindfulTagContext()
    if filereadable(expand('~/.vim/tmp/mindful/tags.txt'))
        let curline = getline('.')
        let cnum = col('.')
        
        if curline =~ '#\w*\%' . cnum . 'c'
            return "\<c-x>\<c-k>"
        endif
    endif
endfunction

let g:SuperTabCompletionContexts =
    \ ['MindfulTagContext', 's:ContextText', 's:ContextDiscover']

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
"  Host-specific configuration
" ---------------------------------------------------------------------------
let hostfile=$XDG_CONFIG_HOME . '/nvim/' . substitute(hostname(), "\\..*", "", "") . '-local.vim'
if filereadable(hostfile)
    exe 'source ' . hostfile
endif

" ---------------------------------------------------------------------------
"  Language-specific Options
" ---------------------------------------------------------------------------

autocmd FileType vimscript setlocal softtabstop=4 shiftwidth=4 tabstop=4
autocmd BufRead,BufNewFile *.py set autoindent
autocmd BufRead,BufNewFile *.har set ft=json
autocmd FileType markdown,mindful setlocal nonumber
autocmd FileType javascript let b:did_indent = 1

" nvim-ipy
" let g:nvim_ipy_perform_mappings = 0

" ---------------------------------------------------------------------------
"  Coloscheme options
" ---------------------------------------------------------------------------
let g:gruvbox_italic=1
let g:quantum_black=1
let g:quantum_italics=1

syntax on

hi ColorColumn ctermbg=234 guibg=#222222
hi MatchParen cterm=bold ctermbg=none ctermfg=red
hi Conceal guibg=background guifg=foreground
