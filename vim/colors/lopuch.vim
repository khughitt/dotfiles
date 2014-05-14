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
let g:colors_name="lopuch"

hi Normal       ctermfg=44
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
hi CursorLine     ctermbg=233 cterm=none
hi CursorIM	     ctermbg=60 ctermfg=84  cterm=none
hi Directory	  ctermfg=57  cterm=none
hi DiffAdd		  ctermfg=43  cterm=none
hi DiffChange	  ctermfg=128 cterm=none
hi DiffDelete	  ctermfg=209 cterm=none
hi DiffText	      ctermfg=252 cterm=none
hi ErrorMsg	      ctermfg=160 cterm=none
hi VertSplit	  ctermfg=238 cterm=none
hi Folded		 ctermbg=17  ctermfg=75  cterm=none
hi FoldColumn	  ctermfg=252 cterm=none
hi IncSearch      cterm=inverse
hi LineNr		 ctermbg=233 ctermfg=245 cterm=none
hi ModeMsg		  ctermfg=252 cterm=none
hi MoreMsg		  ctermfg=252 cterm=none
hi NonText		 ctermbg=16 ctermfg=252 cterm=none
hi Question	      ctermfg=252 cterm=none
hi Search		  ctermfg=252 cterm=none
hi SpecialKey	  ctermfg=252 cterm=none
hi StatusLine	 ctermbg=244 ctermfg=0 cterm=none
hi StatusLineNC	  ctermfg=252 cterm=none
hi Title		  ctermfg=252 cterm=none
hi Visual		  ctermfg=252 cterm=inverse
hi VisualNOS	  ctermfg=252 cterm=none
hi WarningMsg	  ctermfg=252 cterm=none
hi WildMenu	      ctermfg=252 cterm=none
hi Menu		      ctermfg=252 cterm=none
hi Scrollbar	 ctermbg=16  ctermfg=241 cterm=none
hi Tooltip		  ctermfg=252 cterm=none
hi CursorColumn   ctermbg=233 cterm=none

" syntax highlighting groups
hi Comment        ctermfg=243 term=none
hi Constant	      ctermfg=84 cterm=none
hi Identifier     ctermfg=254 cterm=none   "prom
hi Statement	  ctermfg=154 cterm=none   "if
hi PreProc	      ctermfg=77 cterm=bold
hi Type		      ctermfg=79 cterm=none   "->
hi Special	      ctermfg=69 cterm=none   "<?
hi Underlined     ctermfg=252 cterm=underline
hi Error		  ctermfg=196 cterm=underline
hi Todo		      ctermfg=220 cterm=none
hi String           ctermfg=67   cterm=none
hi Function         ctermfg=36   cterm=none
hi Ignore           ctermfg=252   cterm=none
hi MatchParen     ctermbg=11  ctermfg=0   cterm=bold 
hi Operator         ctermfg=84  cterm=none    "$
hi Delimiter        ctermfg=40   cterm=none  "(
hi Exception        ctermfg=196   cterm=none 

	" -> HTML-specific
	hi htmlBold                   ctermfg=252   cterm=bold
	hi htmlBoldItalic             ctermfg=252   cterm=bold,italic
	hi htmlBoldUnderline          ctermfg=252   cterm=bold,underline
	hi htmlBoldUnderlineItalic    ctermfg=252   cterm=bold,underline,italic
	hi htmlItalic                 ctermfg=252   cterm=italic
	hi htmlUnderline              ctermfg=252   cterm=underline
	hi htmlUnderlineItalic        ctermfg=252   cterm=underline,italic
