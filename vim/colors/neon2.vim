" vim:set ts=8 sts=2 sw=2 tw=0 noet:
"=============================================================================
" File: neon2.vim
" Author: yuratomo
" Last Modified: 2012.11.16
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
let g:colors_name="neon2"

hi Normal	guifg=#BBBBBB	guibg=#000000	gui=none
hi NonText	guifg=DarkBlue	guibg=black	gui=none
hi Statement	guifg=#2080F0	guibg=#101050	gui=none
hi Special	guifg=#ff075d	guibg=#20000b	gui=none
hi Constant	guifg=#85ff9d	guibg=#102013	gui=none
hi Comment	guifg=#40D090	guibg=#002010	gui=none
hi Preproc	guifg=#a885cd	guibg=#280d5d	gui=none
hi Type		guifg=#00B0F0	guibg=#001015	gui=none
hi Identifier	guifg=#CCCCCC	guibg=#000510	gui=none
hi StatusLine	guifg=#07297f	guibg=#b3c5ef	gui=bold,underline
hi StatusLineNC	guifg=#7b7bd0	guibg=#000000	gui=underline
hi Visual	guifg=fg	guibg=#071e90	gui=none
hi Search	guifg=#ff370b	guibg=#200601	gui=bold
hi IncSearch	guifg=black	guibg=#ff370b	gui=none
hi VertSplit	guifg=#0b2fff	guibg=#000050	gui=none
hi Directory	guifg=#40A0FF	guibg=#001030	gui=none
hi WarningMsg	guifg=Red	guibg=DarkBlue	gui=standout
hi Error	guifg=Red	guibg=black	gui=none
hi LineNr	guifg=#2060A0	guibg=#000030	gui=none
hi Cursor	guifg=white	guibg=Red	gui=none
hi Cursor	guifg=white	guibg=Red	gui=none
hi CursorIM	guifg=white	guibg=#1dc4a2	gui=bold
hi CursorLine	                guibg=NONE   	gui=bold
hi CursorLineNr	guifg=white	guibg=#002f9f	gui=none
hi CursorColumn			guibg=#000000	gui=bold
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

hi Number	guifg=#e04690	guibg=#200a14	gui=none
hi Boolean	guifg=#ffa866	guibg=#301f13	gui=none
hi String	guifg=#ff4c4d	guibg=#100000	gui=none
hi Identifier	guifg=#00A0A0	guibg=bg	gui=none
hi Function	guifg=#ff1e91	guibg=#200006   gui=none
hi Conditional	guifg=#60B0D0	guibg=#003030	gui=none
hi Repeat	guifg=#A040F0	guibg=#201030	gui=none
hi Operator	guifg=#888888	guibg=#001010	gui=none
hi Keyword	guifg=#00A0A0	guibg=bg	gui=bold
hi Exception	guifg=#00A0A0	guibg=bg	gui=bold
hi Include	guifg=#e6f589	guibg=#202000	gui=none
hi Define	guifg=#9ebf5c	guibg=#201000	gui=none
hi Macro	guifg=#bf9674	guibg=#201000	gui=none
hi StorageClass	guifg=LightBlue	guibg=bg	gui=none
hi Structure	guifg=#be2380	guibg=#240015	gui=none
hi Typedef	guifg=#df0000	guibg=#200000	gui=none
hi Underlined	guifg=honeydew4	guibg=bg	gui=underline
hi Ignore	guifg=#204050	guibg=bg	gui=none
hi Todo		guifg=white	guibg=#f51d1d	gui=bold

hi CFunction	guifg=#88AACC	guibg=#000030	gui=none
hi SpecialKey	guifg=#202060	guibg=#000005	gui=none	guisp=#000070
hi Pmenu	guifg=#DDDDDD	guibg=#333333	gui=none
hi PmenuSel	guifg=#FFFFFF	guibg=#204080	gui=none
hi PmenuSbar	guifg=fg	guibg=#666666	gui=none
hi PmenuThumb	guifg=#CCCCCC	guibg=bg	gui=none
hi TabLine	guifg=#b3c5f2	guibg=#204080	gui=none
hi TabLineSel	guifg=#576def	guibg=#000000	gui=bold
hi TabLineFill	guifg=#90C0FF	guibg=#8888c0	gui=none
hi MatchParen	guifg=#33FF33	guibg=#000000	gui=bold

hi ZenkakuSpace	guibg=#444444	guifg=#888888	gui=underline
hi ClassName	guibg=#01181b	guifg=#0ebbcb	gui=none
hi Arrow	guibg=#20131a	guifg=#c0739f	gui=none
hi And		guibg=#20131a	guifg=#c0739f	gui=none
hi Dot		guibg=#20131a	guifg=#c0739f	gui=none

hi TagListTagName guifg=bg	guibg=#40A060	gui=underline

hi S6		guifg=#607dff	guibg=#000000   gui=none
hi S5		guifg=#708aff	guibg=#10102f   gui=none
hi S4		guifg=#8097ff	guibg=#1f1f4f   gui=none
hi S3		guifg=#90a4ff	guibg=#27274f   gui=none
hi S2		guifg=#a0b1ff	guibg=#2e2e5f   gui=none
hi S1		guifg=#b0c0ff	guibg=#34348f   gui=none

