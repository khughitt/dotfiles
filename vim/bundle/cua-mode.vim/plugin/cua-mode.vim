"|
"| File    : ~/.vim/plugin/cua-mode.vim
"| Source  : https://github.com/fabi1cazenave/cua-mode
"| Licence : WTFPL
"|
"| This file brings Notepad-like CTRL-ZXCV shortcuts to Vim, while preserving
"| all other Vim shortcuts -- like the CUA-mode does on Emacs:
"|           http://www.emacswiki.org/CuaMode
"|
"| It is based on Bram Molenaar's mswin.vim, g:cua_mode sets the behavior:
"|   0. raw
"|   1. CUA mode     =   (default)  CTRL-ZXCV -- subset of mswin.vim
"|   2. mswin mode   =   CUA mode + CTRL-ASY  -- strict equivalent of mswin.vim
"|   3. Notepad mode = mswin mode + CTRL-QOF  -- superset of mswin.vim
"|

" don't load $VIMRUNTIME/mswin.vim
let g:skip_loading_mswin=1

" bail out if this isn't wanted (i.e. when g:cua_mode is defined to 0).
if !exists('g:cua_mode')
  let g:cua_mode = 1
elseif g:cua_mode == 0
  finish
endif

" recommended settings:
" set nocompatible   " required for a multi-level undo/redo stack
" set mouse=a        " enables mouse selection

" set the 'cpoptions' to its Vim default
let s:save_cpo = &cpoptions
set cpo&vim

" behave like xterm when not in GUI mode
behave xterm
if has('gui_running')
  set mousemodel=popup_setpos   " right-click displays a popup menu
  set keymodel=startsel,stopsel " shift+arrows triggers the select mode
endif

" backspace and cursor keys wrap to previous/next line
set backspace=indent,eol,start whichwrap+=<,>,[,]

" backspace in Visual mode deletes selection
vnoremap <BS> d

" don't mess with CTRL-* shortcuts on MacOSX
if has('unix') && (system('uname') =~ '^Darwin')
  finish
endif

"|    Common PC shortcuts: CTRL-ZXCV <=> Undo|Cut|Copy|Paste                <<<
"|-----------------------------------------------------------------------------

" CTRL-Z is Undo
noremap  <C-Z> u
inoremap <C-Z> <C-O>u

" CTRL-X and SHIFT-Del are Cut
vnoremap <C-X>   "+x
vnoremap <S-Del> "+x

" CTRL-C and CTRL-Insert are Copy
vnoremap <C-C>      "+y
vnoremap <C-Insert> "+y

" CTRL-V and SHIFT-Insert are Paste
map <C-V>      "+gP
map <S-Insert> "+gP

cmap <C-V>      <C-R>+
cmap <S-Insert> <C-R>+

" Pasting blockwise and linewise selections is not possible in Insert and
" Visual mode without the +virtualedit feature.  They are pasted as if they
" were characterwise instead.
" Uses the paste.vim autoload script.

exe 'inoremap <script> <C-V>' paste#paste_cmd['i']
exe 'vnoremap <script> <C-V>' paste#paste_cmd['v']

imap <S-Insert> <C-V>
vmap <S-Insert> <C-V>

" XXX For CTRL-V to work autoselect must be off.
" On Unix we have two selections, autoselect can be used.
if !has("unix")
  set guioptions-=a
endif
" >>>

" Note: some shells may eat CTRL-S and CTRL-Q (= XOFF/XON) to suspend/resume
" the display.  This can be avoided by adding this to ~/.bashrc or ~/.zshrc:
"     stty -ixon

"|    #1 Use CTRL-S and CTRL-Q to do what CTRL-Z and CTRL-V used to do      <<<
"|-----------------------------------------------------------------------------
" XXX: not working in gVim

" CTRL-Q <=> rectangular selection or special character insertion
noremap <C-Q> <C-V>

" CTRL-S <=> suspend Vim (resume with fg)
noremap <C-S> <C-Z>
" >>>

"|    #2 Alternative: mswin-like behavior for CTRL-SAY                      <<<
"|-----------------------------------------------------------------------------
" This should be strictly equivalent to the $VIMRUNTIME/mswin.vim behavior.

if g:cua_mode < 2
  finish
endif

" CTRL-S is Save
noremap  <C-S>      :update<CR>
vnoremap <C-S> <C-C>:update<CR>
inoremap <C-S> <C-O>:update<CR>

" CTRL-A is Select All
noremap  <C-A> gggH<C-O>G
inoremap <C-A> <C-O>gg<C-O>gH<C-O>G
cnoremap <C-A> <C-C>gggH<C-O>G
onoremap <C-A> <C-C>gggH<C-O>G
snoremap <C-A> <C-C>gggH<C-O>G
xnoremap <C-A> <C-C>ggVG

" CTRL-Y is Redo (although not repeat); not in cmdline though
noremap  <C-Y>      <C-R>
inoremap <C-Y> <C-O><C-R>

" ALT-Space is System menu
if has('gui_running')
  noremap  <M-Space>      :simalt ~<CR>
  inoremap <M-Space> <C-O>:simalt ~<CR>
  cnoremap <M-Space> <C-C>:simalt ~<CR>
endif

" CTRL-Tab is Next window
noremap  <C-Tab>      <C-W>w
inoremap <C-Tab> <C-O><C-W>w
cnoremap <C-Tab> <C-C><C-W>w
onoremap <C-Tab> <C-C><C-W>w

" CTRL-F4 is Close window
noremap  <C-F4>      <C-W>c
inoremap <C-F4> <C-O><C-W>c
cnoremap <C-F4> <C-C><C-W>c
onoremap <C-F4> <C-C><C-W>c
" >>>

"|    #3 Alternative: Notepad-like behavior for CTRL-QSOAYF                 <<<
"|-----------------------------------------------------------------------------
" This should be close to the Notepad behavior, though not equivalent.
" If you're looking for a more Notepad-like experience, try `vim -e` (Cream).

if g:cua_mode < 3
  finish
endif

" CTRL-B is Block selection
noremap <C-B> <C-V>

" CTRL-Q is Quit (unlike mswin)
noremap  <C-Q>      :quit<CR>
vnoremap <C-Q> <C-O>:quit<CR>
inoremap <C-Q> <C-O>:quit<CR>

" Next/previous with F3/Shift-F3
noremap    <F3>      n
vnoremap   <F3> <C-c>n
inoremap   <F3> <C-o>n
noremap  <S-F3>      N
vnoremap <S-F3> <C-c>N
inoremap <S-F3> <C-o>N

" Easy open/find/replace
if has('gui_running')
  " CTRL-O is Open
  noremap  <C-O>      :browse open<CR>
  vnoremap <C-O> <C-C>:browse open<CR>
  " CTRL-F is Find
  noremap  <C-F>      :promptfind<CR>
  vnoremap <C-F> <C-C>:promptfind<CR>
  inoremap <C-F> <C-O>:promptfind<CR>
  " CTRL-H is Replace
  noremap  <C-H>      :promptrepl<CR>
  vnoremap <C-H> <C-C>:promptrepl<CR>
  inoremap <C-H> <C-O>:promptrepl<CR>
else
  " CTRL-O is Open
  noremap  <C-O>      :edit .<CR>
  vnoremap <C-O> <C-C>:edit .<CR>
  " CTRL-F is Find
  noremap  <C-F>      /
  vnoremap <C-F> <C-C>/
  inoremap <C-F> <C-O>/
endif

" Bonus: word-by-word caret movements

" CTRL+arrow/backspace/delete
inoremap <C-BackSpace> <C-o>db
vnoremap <C-BackSpace> <C-c>db
inoremap <C-Delete>    <C-o>dw
vnoremap <C-Delete>    <C-c>dw
inoremap <C-Left>      <C-o>b
vnoremap <C-Left>      <C-c>b
inoremap <C-Right>     <C-o>w
vnoremap <C-Right>     <C-c>w
inoremap <C-Up>        <C-o>{
vnoremap <C-Up>        <C-c>{
inoremap <C-Down>      <C-o>}
vnoremap <C-Down>      <C-c>}

" ALT+arrow/backspace/delete -- meta sets the 8th bit
inoremap <M-BackSpace> <C-o>db
inoremap <M-Delete>    <C-o>dw
inoremap <M-Left>      <C-o>b
inoremap <M-Right>     <C-o>w
inoremap <M-Up>        <C-o>{
inoremap <M-Down>      <C-o>}

map <M-Left>  B
map <M-Right> W
map <M-Up>    {
map <M-Down>  }

" ALT+arrow/backspace/delete -- meta sends escape
inoremap <Esc><BackSpace> <C-o>db
inoremap <Esc><Delete>    <C-o>dw
inoremap <Esc><Left>      <C-o>b
inoremap <Esc><Right>     <C-o>w
inoremap <Esc><Up>        <C-o>{
inoremap <Esc><Down>      <C-o>}

map <Esc><Left>  B
map <Esc><Right> W
map <Esc><Up>    {
map <Esc><Down>  }
" >>>

" restore 'cpoptions'
set cpo&
let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: set fdm=marker fmr=<<<,>>> fdl=0:
