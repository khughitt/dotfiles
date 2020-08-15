" Vim syntax file
" Language: Scratchpad
" Maintainer: Keith Hughitt
" Latest Revision: Aug 15, 2020
"
if exists("b:current_syntax")
  finish
endif

" inherit vim-markdown syntax
runtime! syntax/markdown.vim

" Date heading
syn match DateHeading "^\-.*\-$"

" questions & important
syn match Question "^?.*$"
syn match Important "^\!.*$"

" #hashtags
syn match HashTag /#[a-zA-Z0-9.-]\+/

" Highlighting
let b:current_syntax = "scratch"

" Mapping
hi     link HashTag     Label
hi def link DateHeading Todo
hi def link Important   Special
hi def link Question    Type

