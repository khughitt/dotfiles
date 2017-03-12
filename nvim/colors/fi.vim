" cool help screens
" :he group-name
" :he highlight-groups
" :he cterm-colors

" your pick:
set background=dark	" or light
hi clear
if exists("syntax_on")
    syntax reset
endif
let g:colors_name="fi"

hi Normal       ctermfg=110
"hi Normal

" OR

highlight clear Normal
" set background&
" highlight clear
" if &background == "light"
"   highlight Error ...
"   ...
" else
"   highlight Error ...
"   ...
" endif

" A good way to see what your colorscheme does is to follow this procedure:
" :w 
" :so % 
"
" Then to see what the current setting is use the highlight command.  
" For example,
" 	:hi Cursor
" gives
"	Cursor         xxx guifg=bg guibg=fg 

" Uncomment and complete the commands you want to change from the default.

hi Cursor	     ctermbg=255 ctermfg=16  cterm=none
hi CursorLine     ctermbg=0 cterm=none
hi CursorLineNr     ctermbg=66 ctermfg=0 cterm=none
hi CursorIM	     ctermbg=60 ctermfg=255  cterm=none
hi Directory	  ctermfg=110  cterm=none
hi DiffAdd		  ctermfg=43  cterm=none
hi DiffChange	  ctermfg=128 cterm=none
hi DiffDelete	  ctermfg=209 cterm=none
hi DiffText	      ctermfg=252 cterm=none
hi ErrorMsg	      ctermfg=197 cterm=none
hi VertSplit	  ctermfg=61 cterm=none
hi Folded		 ctermbg=17  ctermfg=75  cterm=none
hi FoldColumn	  ctermfg=252 cterm=none
hi IncSearch       ctermbg=60 ctermfg=231 cterm=none
hi LineNr		 ctermbg=0 ctermfg=67 cterm=none
hi ModeMsg		  ctermfg=252 cterm=none
hi MoreMsg		  ctermfg=252 cterm=none
hi NonText		 ctermbg=0 ctermfg=252 cterm=none
hi Question	      ctermfg=252 cterm=none
hi Search		  ctermfg=252 cterm=none
hi SpecialKey	  ctermfg=252 cterm=none
hi StatusLine	 ctermbg=67 ctermfg=0 cterm=none
hi StatusLineNC	  ctermfg=0 cterm=none
hi Title		  ctermfg=222 cterm=none
hi Visual	     cterm=inverse
hi VisualNOS	  ctermfg=252 cterm=none
hi WarningMsg	  ctermfg=252 cterm=none
hi WildMenu	      ctermfg=252 cterm=none
hi Menu		      ctermfg=252 cterm=none
hi Scrollbar	 ctermbg=16  ctermfg=241 cterm=none
hi Tooltip		  ctermfg=252 cterm=none
hi CursorColumn   ctermbg=233 cterm=none

" syntax highlighting groups
hi PreProc	      ctermfg=185 cterm=none
hi Special	      ctermfg=135 cterm=none   "<?

hi Statement	  ctermfg=15 cterm=none   "if
hi Delimiter        ctermfg=67   cterm=none  "(
hi Function         ctermfg=134   cterm=none
hi Type		      ctermfg=135 cterm=none   "->
hi Operator         ctermfg=215  cterm=none    "$
hi Identifier     ctermfg=168  cterm=none   "prom
hi Constant	      ctermfg=67 cterm=none

hi String           ctermfg=61  cterm=none
hi Comment        ctermfg=25 term=none

hi Underlined     ctermfg=110 cterm=underline
hi Error		  ctermbg=0 ctermfg=196 cterm=underline
hi Todo		      ctermbg=0 ctermfg=220 cterm=none
hi Ignore           ctermfg=252   cterm=none
hi MatchParen     ctermbg=13  ctermfg=0   cterm=bold 
hi Exception      ctermbg=0  ctermfg=196   cterm=none 

" -> HTML-specific
hi htmlBold                   ctermfg=252   cterm=bold
hi htmlBoldItalic             ctermfg=252   cterm=bold,italic
hi htmlBoldUnderline          ctermfg=252   cterm=bold,underline
hi htmlBoldUnderlineItalic    ctermfg=252   cterm=bold,underline,italic
hi htmlItalic                 ctermfg=252   cterm=italic
hi htmlUnderline              ctermfg=252   cterm=underline
hi htmlUnderlineItalic        ctermfg=252   cterm=underline,italic

hi htmlEndTag ctermfg=135 cterm=none
hi htmlTag ctermfg=135 cterm=none
hi htmlTagName ctermfg=141 cterm=none
hi htmlStatement ctermfg=252 cterm=none
