" ---------------------------------------------------------------------------
"  Python
" ---------------------------------------------------------------------------
map <silent> <leader>b obreakpoint()<esc>

" ---------------------------------------------------------------------------
"  nvim-ipy
" ---------------------------------------------------------------------------
let g:nvim_ipy_perform_mappings = 0

" note: <c-w> <c-r> swaps two vertical buffers
vmap <silent> <Space> <Plug>(IPy-Run)
nmap <silent><space> <Plug>(IPy-Run)
vmap <silent> <C-M> <Plug>(IPy-Run)
nmap <silent> <C-M> <Plug>(IPy-Run)
nmap <silent> <localleader>p <Plug>(IPy-WordObjInfo)
nmap <silent> <localleader>cc <Plug>(IPy-RunAll)

nmap <localleader>rf :IPython<CR>
