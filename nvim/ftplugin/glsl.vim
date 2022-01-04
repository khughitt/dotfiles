" add helper function to run file in glslviewer
" kh (dec21)
if executable("glslviewer")
  function RunShader()
    let path = expand("%:p")
    :call system(printf("glslviewer %s", path))
  endfunction

  noremap <silent><leader>r :call RunShader()<CR>
  inoremap <silent><leader>r <Esc>:call RunShader()<CR>
endif
