"
" scratch tag highlighting
" kh (nov 2020)
"
" let cmap = system('stag')

" counter to keep track of current tag number
let i = 1

let cmap = split(system('stag'), '\n')

for mapping in cmap
    let parts = split(mapping, ', ')
    let tag = parts[0]
    let color = parts[1]

    execute('highlight SenTag' . i . ' guifg=' . color)
    call matchadd("SenTag" . i, '\<' . tag . '\>')

    let i += 1
endfor


