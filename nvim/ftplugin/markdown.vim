" underline current line; useful for markdown headings
function CreateHeading(char)
    let size = strwidth(getline('.'))
    execute "normal! o\<ESC>"
    execute "normal!" . size . "I" . a:char . "\<ESC>"
    call feedkeys('A', 'n')
endfunction

" helper function to add a simple markdown timestamp heading
function! AddTimeStamp ()
    call append(line("."), [strftime('_%b %d %Y %H:%M:%S_'), ""])
    normal! 3j
    call feedkeys('A', 'n')
endfunction

" helper function to add an commonly-used header sections
function! AddMarkdownHeader (text)
    let under = repeat("-", strlen(a:text))
    call append(line(".") - 1, [a:text, under, ""])
    call feedkeys('A', 'n')
endfunction

"
" toggle mindful thoughts view
"
function! ToggleThoughts ()
    let path = expand("%p")
    let path = substitute(path, '.md', '.mnd', '')
    exec ":edit " . path
endfunction

nnoremap <F5> :call CreateHeading("-")<CR>
inoremap <F5> <Esc>:call CreateHeading("-")<CR>
nnoremap <leader><F5> :call CreateHeading("=")<CR>
inoremap <leader><F5> <Esc>:call CreateHeading("=")<CR>
map <silent><leader>s :call AddTimeStamp()<CR>
map <silent><leader>o :call AddMarkdownHeader("Overview")<CR>
map <silent><leader>r :call AddMarkdownHeader("References")<CR>
noremap <silent><leader>h :call ToggleThoughts()<CR>
inoremap <silent><leader>h <Esc>:call ToggleThoughts()<CR>

