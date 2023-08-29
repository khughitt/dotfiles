" Shortuct to toggle textwidth wrapping
nmap <silent><localleader>r :call ToggleTextWidth()<CR>
function! ToggleTextWidth()
  if &textwidth != 0
    let b:oldtextwidth = &textwidth
    set textwidth=0
  elseif exists("b:oldtextwidth")
    let &textwidth = b:oldtextwidth
  else
    set textwidth=100
  endif
endfunction

function! AutoSaveWinView()
    if !exists("w:SavedBufView")
        let w:SavedBufView = {}
    endif
    let w:SavedBufView[bufnr("%")] = winsaveview()
endfunction

" Restore current view settings.
function! AutoRestoreWinView()
    let buf = bufnr("%")
    if exists("w:SavedBufView") && has_key(w:SavedBufView, buf)
        let v = winsaveview()
        let atStartOfFile = v.lnum == 1 && v.col == 0
        if atStartOfFile && !&diff
            call winrestview(w:SavedBufView[buf])
        endif
        unlet w:SavedBufView[buf]
    endif
endfunction

" When switching buffers, preserve window view.
autocmd BufLeave * call AutoSaveWinView()
autocmd BufEnter * call AutoRestoreWinView()


" ---------------------------------------------------------------------------
"
" CriticMarkup highlight
"
" ---------------------------------------------------------------------------
vmap <leader>l c<C-R>=substitute(@", '\v(.*)', '\{==\1==\}\{>><<\}', '')<ESC>

" ---------------------------------------------------------------------------
"
" Scriptnames helper function
" https://vim.fandom.com/wiki/List_loaded_scripts
"
" ---------------------------------------------------------------------------
function! s:Scratch (command, ...)
   redir => lines
   let saveMore = &more
   set nomore
   execute a:command
   redir END
   let &more = saveMore
   call feedkeys("\<cr>")
   new | setlocal buftype=nofile bufhidden=hide noswapfile
   put=lines
   if a:0 > 0
      execute 'vglobal/'.a:1.'/delete'
   endif
   if a:command == 'scriptnames'
      %substitute#^[[:space:]]*[[:digit:]]\+:[[:space:]]*##e
   endif
   silent %substitute/\%^\_s*\n\|\_s*\%$
   let height = line('$') + 3
   execute 'normal! z'.height."\<cr>"
   0
endfunction

command! -nargs=? Scriptnames call <sid>Scratch('scriptnames', <f-args>)
command! -nargs=+ Scratch call <sid>Scratch(<f-args>)


" ---------------------------------------------------------------------------
" indent guides
" ---------------------------------------------------------------------------
let g:indent_guides_auto_colors = 0
let g:indent_guides_auto_colors = 1
let g:indent_guides_start_level = 2
let g:indent_guides_guide_size  = 1
" ---------------------------------------------------------------------------
"   nvcode-color-schemes
" ---------------------------------------------------------------------------
let g:nvcode_termcolors=256

" ---------------------------------------------------------------------------
"  onedark.nvim
" ---------------------------------------------------------------------------
"lua <<EOF
"require('onedark').setup()
"EOF
