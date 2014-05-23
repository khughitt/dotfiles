" vim:set ts=8 sts=2 sw=2 tw=0:
"=============================================================================
" File: neon.vim
" Author: yuratomo
" Last Modified: 2011.11.28
" Version: 0.0.1
"=============================================================================
if !has('gui')
  finish
endif
set background=dark
hi clear
if exists("syntax_on")
    syntax reset
endif
let g:colors_name="neon"

hi Normal	guifg=#BBBBBB	guibg=#000505	gui=none
hi NonText	guifg=DarkBlue	guibg=black	gui=none
hi Statement	guifg=#2080F0	guibg=#101050	gui=none
hi Special	guifg=#ffbfb3	guibg=#001530	gui=none
hi Constant	guifg=#99CCFF	guibg=#001030	gui=none
hi Comment	guifg=#40D090	guibg=#002010	gui=none
hi Preproc	guifg=#a885cd	guibg=#280d5d	gui=none
hi Type		guifg=#0090F0	guibg=#102030	gui=none
hi Identifier	guifg=#CCCCCC	guibg=#000510	gui=none
hi StatusLine	guifg=#a9c2d0	guibg=#3939d0	gui=none
hi StatusLineNC	guifg=#7b7bd0	guibg=#0a0a50	gui=underline
hi Visual	guifg=fg	guibg=#7f1222	gui=none
hi Search	guifg=#d4fc37	guibg=#29470f	gui=bold
hi IncSearch	guifg=black	guibg=#FFFF00	gui=none
hi VertSplit	guifg=#0070D0	guibg=#000050	gui=none
hi Directory	guifg=#4080FF	guibg=#001030	gui=none
hi WarningMsg	guifg=Red	guibg=DarkBlue	gui=standout
hi Error	guifg=Red	guibg=black	gui=none
hi LineNr	guifg=#2060A0	guibg=#000030	gui=none
hi Cursor	guifg=white	guibg=Red	gui=none
hi CursorIM	guifg=white	guibg=#1dc4a2	gui=bold
hi CursorLine	                guibg=#101030	gui=none
hi CursorColumn	guifg=fg	guibg=#202020	gui=bold
hi DiffAdd	guifg=fg	guibg=#0039ad	gui=none
hi DiffChange	guifg=fg	guibg=#00297d	gui=none
hi DiffDelete	guifg=#00297d	guibg=black	gui=none
hi DiffText	guifg=fg	guibg=#0039ad	gui=underline
hi ErrorMsg	guifg=yellow	guibg=FireBrick	gui=none
hi FillColumn	guifg=black	guibg=grey60	gui=none
hi Folded	guifg=#00A0C0	guibg=black	gui=none
hi FoldColumn	guifg=#c4301d	guibg=black	gui=none
hi ModeMsg	guifg=#1dc465	guibg=#142f14	gui=none
hi MoreMsg	guifg=SeaGreen4	guibg=bg	gui=bold
hi Question	guifg=SeaGreen2	guibg=bg	gui=bold
hi WarningMsg	guifg=red	guibg=bg	gui=bold
hi WildMenu	guifg=Black	guibg=green	gui=bold

hi Number	guifg=#bdda90	guibg=#103010	gui=none
hi Boolean	guifg=lightblue	guibg=bg	gui=none
hi String	guifg=#F0A0A0	guibg=#100000	gui=none
hi Identifier	guifg=#00A0A0	guibg=bg	gui=none
hi Function	guifg=#FF77AA	guibg=#000040   gui=none
hi Conditional	guifg=#60B0D0	guibg=#003030	gui=none
hi Repeat	guifg=#A040F0	guibg=#201030	gui=none
hi Operator	guifg=#888888	guibg=#001010	gui=none
hi Keyword	guifg=#00A0A0	guibg=bg	gui=bold
hi Exception	guifg=#00A0A0	guibg=bg	gui=bold
hi Include	guifg=#5d7f70	guibg=#202000	gui=none
hi Define	guifg=#9ebf5c	guibg=#201000	gui=none
hi Macro	guifg=#bf9674	guibg=#201000	gui=none
hi StorageClass	guifg=LightBlue	guibg=bg	gui=none
hi Structure	guifg=LightBlue	guibg=bg	gui=none
hi Typedef	guifg=LightBlue	guibg=bg	gui=none
hi Underlined	guifg=honeydew4	guibg=bg	gui=underline
hi Ignore	guifg=#204050	guibg=bg	gui=none
hi Todo		guifg=lightblue	guibg=#507080	gui=none

hi CFunction	guifg=#88AACC	guibg=#000030	gui=none
hi SpecialKey	guifg=#004080	guibg=#000000	gui=none	guisp=#000070
hi Pmenu	guifg=#DDDDDD	guibg=#333333	gui=none
hi PmenuSel	guifg=#FFFFFF	guibg=#204080	gui=none
hi PmenuSbar	guifg=fg	guibg=#666666	gui=none
hi PmenuThumb	guifg=#CCCCCC	guibg=bg	gui=none
hi TabLine	guifg=#EEEEEE	guibg=#606080	gui=none
hi TabLineSel	guifg=#BBAAFF	guibg=#000000	gui=bold
hi TabLineFill	guifg=#90C0FF	guibg=#A0A0C0	gui=none
hi MatchParen	guifg=#33FF33	guibg=#000000	gui=bold

hi ZenkakuSpace	guibg=#444444	guifg=#888888	gui=underline
hi ClassName	guibg=#01181b	guifg=#0ebbcb	gui=none
hi Arrow	guibg=#20131a	guifg=#c0739f	gui=none
hi And		guibg=#20131a	guifg=#c0739f	gui=none
hi Dot		guibg=#20131a	guifg=#c0739f	gui=none

hi TagListTagName guifg=bg	guibg=#40A060	gui=underline

