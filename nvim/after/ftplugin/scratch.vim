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

function! NextBlock ()
    " find next block heading and set cursor two lines below
    exec ":normal /-[a-zA-Z0-9 :]\\+-\\n/\<CR>"
    normal! 2j
    " enter insert mode
    " call feedkeys('A', 'n')
endfunction

function! PrevBlock ()
    " find previous block
    exec ":normal ?-[a-zA-Z0-9 :]\\+-\\n?\<CR>"
    exec ":normal n<CR>"
    normal! 2j
    " enter insert mode
    " call feedkeys('A', 'n')
endfunction

noremap <silent><c-j> :call NextBlock()<CR>
noremap <silent><c-k> :call PrevBlock()<CR>
inoremap <silent><c-j> <Esc>:call NextBlock()<CR>
inoremap <silent><c-k> <Esc>:call PrevBlock()<CR>
