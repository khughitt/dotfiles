"
" neovim config / fzf
" KH
"

"
" some useful functions and mappings from
" https://vim.fandom.com/wiki/Fuzzy_mappings_of_everything!
"
nnoremap <silent> <C-a>c :call fzf#run({'source': GetCommands(),'sink': function('HandleCommand'),'options': '-m'} )<CR>

"search only for the mapping key
nnoremap <silent> <C-a>m :call fzf#run({'source': GetMappings(),'options': '-m -n 2'} )<CR>

"search in mapping description as well
nnoremap <silent> <C-a>M :call fzf#run({'source': GetMappings(),'options': '-m'} )<CR>
nnoremap <leader><bar> <bar>

nnoremap <silent> <bar> :Leaderf --popup buffer<CR>
nnoremap <silent> <C-a>b :call FZFOpen(':Buffers')<CR>

nnoremap <silent> <C-a>g :LeaderfRgInteractive<CR>
"nnoremap <silent> <C-a>g :call FZFOpen(':FzfRg!')<CR>
"
nnoremap <silent> <C-a>G :LeaderfRgInteractive<CR><CR><CR>

"for exact
"nnoremap <silent> <C-a>G :call FZFOpen(':FzfRg! -e')<CR>
nnoremap <silent> <C-a>C :call FZFOpen(':Commands')<CR>

"nnoremap <silent> <C-a>l :call FZFOpen(':BLines')<CR>
"c-l is lines in insert mode
nnoremap <silent> <C-a>L :call fzf#vim#buffer_lines(sink=function('PInsert'))<CR>
nnoremap <silent> <C-a>l m':LeaderfLineAll<CR>

"files current dir
"nnoremap <silent> <C-a>f :call FZFOpen(':Files')<CR>
nnoremap <c-a>f :CtrlPCurWD<CR>

"nnoremap <silent> <C-a>f :exe ":LeaderfFile ".getcwd()<CR>
"files current file
nnoremap <silent> <C-a>F :exe ":LeaderfFile " . expand('%:p:h')<CR>
nnoremap <silent> <C-a>h :call FZFOpen(':History')<CR>
nmap <silent> <C-a>H :call fzf#run({'source':"cat ~/.bash_history \<bar> sort \<bar> uniq",'sink': function('BH')})<CR>
nnoremap <silent> <C-a>a :call FZFOpen(':Ag')<CR>
nnoremap <silent> <C-a>d :call fzf#run({'source': uniq(sort(g:dirs)),'sink':function('CdDir'),'options': '-m'})<CR>
nnoremap <silent> <C-a>w :call FZFOpen(':Windows')<CR>
nnoremap <silent> <M-Bslash> :call FZFOpen(':Windows')<CR>
nnoremap <silent> <C-a>s :call FZFOpen(':Snippets')<CR>

"use it to increase
nnoremap <silent> <C-a><C-a> <C-a>

function! MinExec(cmd)
	redir @a
	exec printf('silent %s',a:cmd)
	redir END
	return @a
endfunction

function! GetMappings()
	let lines=MinExec('map')
	let lines=split(lines,'\n')
	return lines
endfunction

function! GetCommands()
	let lines=[]
	let nu=histnr("cmd")
	for i in range(1,nu)
		let lines+=[histget("cmd",i)]
	endfor
	return lines
endfunction

function! CdDir(item)
	:exe "cd ".a:item
endfunction

function! HandleCommand(item)
	call feedkeys("q:")
	call feedkeys("G?\\V".escape(a:item,'\/?')."\<CR>")
endfunction

function! BH(item)
	exe ":T " . a:item
endfunction


function! PInsert2(item)
	let @z=a:item
	norm "zp
	call feedkeys('a')
endfunction

function! PInsert(item)
	let @z=a:item
	norm "zp
endfunction

