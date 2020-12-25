"
" scratch tag highlighting
" kh (nov 2020)
"

" counter to keep track of current tag number
let i = 1

let cmap = split(system('stag'), '\n')

for mapping in cmap
    let parts = split(mapping, ', ')
    let tag = parts[0]
    let color = parts[1]

    execute('highlight SenTag' . i . ' guifg=' . color)

    " matchadd()
    " Defines a pattern to be highlighted in the current window (a   
    " match").  It will be highlighted with {group}
    " see :help matchadd()

    " \< and \> match the begining and end of a word
    " see :help /\<
    call matchadd("SenTag" . i, '\<' . tag . '\>')

    let i += 1
endfor

"
" create entry
"
function! AddScratchpadEntry ()
    " find entries heading and move cursor to following line
    exec ":normal /Entries/\<CR>"
    normal! 2j

    " add timestamp
    exec ":put=strftime('### %b %d %Y %H:%M:%S')"

    " add new lines
    call append(line("."), ["", "", ""])

    " go down two lines
    call cursor(line('.') + 2, 1)

    " enter insert mode
    call feedkeys('A', 'n')
endfunction

noremap <silent><leader>s :call AddScratchpadEntry ()<CR>

"
" block navigation and selection
" 
let dateRegEx = "^### \\(Jan\\|Feb\\|Mar\\|Apr\\|May\\|Jun\\|Jul\\|Aug\\|Sep\\|Oct\\|Nov\\|Dec\\)[0-9 :,]\\+\\n"

function! NextBlock ()
    echo g:dateRegEx
    exec ":normal /" . g:dateRegEx . "/\<CR>"
    normal! 2j
endfunction

function! PrevBlock ()
    exec ":normal ?" . g:dateRegEx . "?\<CR>"
    exec ":normal n<CR>"
    normal! 2j
endfunction

function! YankBlock ()
    exec ":normal ?" . g:dateRegEx . "?\<CR>"
    normal! V
    exec ":normal /" . g:dateRegEx . "/\<CR>"
    normal! k
    exec ":normal d<CR>"
endfunction

noremap <silent><c-j> :call NextBlock()<CR>
noremap <silent><c-k> :call PrevBlock()<CR>
noremap <silent><leader>y :call YankBlock()<CR>
inoremap <silent><c-j> <Esc>:call NextBlock()<CR>
inoremap <silent><c-k> <Esc>:call PrevBlock()<CR>
inoremap <silent><leader>y <Esc>:call YankBlock()<CR>
