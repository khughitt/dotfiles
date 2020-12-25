
" ---------------------------------------------------------------------------
"  Nvim-R
" ---------------------------------------------------------------------------
let vimrplugin_objbr_place = "console,right"

" fix issue relating to setwidth
" https://github.com/jalvesaq/Nvim-R/issues/81#issuecomment-262651872
let R_setwidth = 0

" split editor and console top/bottom
let R_rconsole_width = 0

" disable syntax highlighting in console output
let R_hl_term = 0

" TEST set background color for terminal
let rout_color_normal = 'guibg=#191919'

" use colorscheme for R output
let g:rout_follow_colorscheme = 1
let g:Rout_more_colors = 1

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
" vmap <Space> <Plug>RDSendSelection
" nmap <Space> <Plug>RDSendLine
" vmap <CR> <Plug>RDSendSelection
" nmap <CR> <Plug>RDSendLine
vmap <Space> <Plug>RDSendSelection
nmap <Space> <Plug>RDSendLine
vmap <CR> <Plug>RDSendSelection
nmap <CR> <Plug>RDSendLine

" nmap <C-Space> ,rp
" disabled; conflicts with coc.nvim
" autocmd FileType r,rmd    nmap <buffer> <C-Space> ,rp

" autostart term
" au FileType r   if string(g:SendCmdToR) == "function('SendCmdToR_fake')" | call StartR("R") | endif
" au FileType rmd if string(g:SendCmdToR) == "function('SendCmdToR_fake')" | call StartR("R") | endif

" preview data
nmap <silent> <LocalLeader>h :call RAction("hh", "@,48-57,_,.")<CR>

" wipe knitr cache and output
nmap <localleader>kc :call g:SendCmdToR('rm(list=ls(all.names=TRUE)); unlink("*_cache/*", recursive=TRUE)')<CR>

" render markdown
nmap <localleader>km :call RMakeRmd("github_document")<CR>

" show source code for function under cursor
function! ShowRSource()
    let g:function_name = expand("<cword>")
    echom "Showing source code for function: \"" . g:function_name . "\""
    enew
    set syntax=r
    execute ":Rinsert " . g:function_name
endfunction

" loads a saved image associated with the file, if one exists
function! LoadRDA()
    " determine expected path of rda file
    let cwd = expand("%:p")
    let code_base_dir = resolve(expand($RESEARCH))
    let rda_base_dir  = "/rda"
    let rda_path = substitute(cwd, code_base_dir, rda_base_dir, "e")
    let rda_path = substitute(rda_path, printf("%s$", expand("%:e")), "rda", "e")

    " if rda image exists, load it
    if filereadable(rda_path)
        echom printf("Loading %s...", rda_path)
        call g:SendCmdToR(printf("load('%s')", rda_path))
    else
        echom printf("%s does not exist!", rda_path)
    endif
endfunction

" au FileType r,rmd nmap <localleader>sc :call ShowRSource()<CR>
nmap <localleader>sc :call ShowRSource()<CR>

" fix keyword separators
set iskeyword=@,48-57,_,192-255

" Work-around for failing rmarkdown syntax highlighting when jumping around in files
" https://vim.fandom.com/wiki/Fix_syntax_highlighting
" https://github.com/vim/vim/issues/2790
" set redrawtime=10000
au BufEnter * :syntax sync fromstart
syntax sync minlines=300
