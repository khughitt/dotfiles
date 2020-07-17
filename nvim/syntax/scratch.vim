" Vim syntax file
" Language: Scratchpad
" Maintainer: Keith Hughitt
" Latest Revision: July 10, 2020
if exists("b:current_syntax")
  finish
endif

" Date heading
" syn region scrDateHeading matchgroup=scrSection start="\%(\*\|%\)"    end="\%(\*\|%\)"
" syn region scrDateHeading start="~" end="~"
" syn region
syn match scrDateHeading "^\~.*\~$"

" Markdown headings
syn match  scrHead1       /^.\+\n=\+$/ contains=@Spell
syn match  scrHead2       /^.\+\n-\+$/ contains=@Spell

" syn keyword scrTodo contained TODO

" Annotations (!, ?, *)
syn match scrImportant "^\!.*$"
syn match scrQuestion "^?.*$"
syn match scrHighlight "\*.*$"

" Separator
syn match scrSeparator "^---$"

" Highlighting
let b:current_syntax = "scratch"

hi def link scrComment     Comment
hi def link scrDateHeading Todo
hi def link scrImportant   Special
hi def link scrQuestion    Statement
hi def link scrHighlight   Type
hi def link scrHead1       htmlH1
hi def link scrHead2       htmlH3
hi def link scrSeparator   Statement

