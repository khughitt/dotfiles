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

" ---------------------------------------------------------------------------
"  markdown link helper
"  https://benjamincongdon.me/blog/2020/06/27/Vim-Tip-Paste-Markdown-Link-with-Automatic-Title-Fetching/
"
"  modified to include support for downloading/inserting image links (kh feb2021)
" ---------------------------------------------------------------------------
function GetURLTitle(url)
    " Use Python/BeautifulSoup to get link's page title.
    let title = system("python3 -c \"import bs4, requests; print(bs4.BeautifulSoup(requests.get('" . a:url . "').content, 'lxml').title.text.strip())\"")

    " Echo the error if getting title failed.
    if v:shell_error != 0
        echom title
        return ""
    endif

    " Strip trailing newline
    return substitute(title, '\n', '', 'g')
endfunction

function DownloadImg(url)
    " create a .img/ directory in dir of markdown file, if not already present
    let mddir = expand('%:p:h')
    let imgdir = mddir . "/.img"
    call mkdir(imgdir, "p", 0755)

    let oldfname = split(a:url, "/")[-1]

    " prompt user for filename
    let fname = input("Filename? ", oldfname)
    let fpath = imgdir . "/" . fname

    " attempt to download the image
    let result = system(printf("curl \"%s\" -s -o %s", a:url, fpath))

    " check to see if command succeeded
    if v:shell_error != 0
        echom result
        return ""
    endif

    " return relative path to image
    return ".img/" . fname
endfunction

function PasteMDLink()
    " generate markdown url
    let url = getreg("+")

    " store here if not a url
    if url !~ '^https\?://'
        return ""
    endif

    " check to see if url points to an image
    let ext = split(url, "\\.")[-1]

    " strip any url query string following image extension, if present
    let ext = substitute(ext, "?.*", "", "")

    let imgexts = ['gif', 'jpg', 'jpeg', 'png', 'webp', 'svg']

    " choose appropriate action based on url type
    if (index(imgexts, ext) >= 0)
        let relpath = DownloadImg(url)
        let mdLink = printf("![](%s)", relpath)
    else
        let title = GetURLTitle(url)
        let mdLink = printf("[%s](%s)", title, url)
    endif      

    " temporarily disable line length limit, if specified
    if &textwidth != 0
        let b:oldtextwidth = &textwidth
        set textwidth=0
    endif

    " add link to document
    execute "normal! a" . mdLink . "\<Esc>"

    " restore line length limit
    if exists("b:oldtextwidth")
        let &textwidth = b:oldtextwidth
    endif
endfunction

" Make a keybinding (mnemonic: "mark down paste")
map <Leader>f <ESC>:call PasteMDLink()<CR>
nmap <Leader>f :call PasteMDLink()<CR>

" ----------------------------------------------------------------------------
" uuid generator
" ----------------------------------------------------------------------------
function UUIDgen()
    let uuid = system("python -c 'import shortuuid; print(shortuuid.ShortUUID().random(length=8))'")
    let uuid = substitute(uuid, '\n', '', 'g')

    execute "normal! i" . uuid . "\<Esc>"
endfunction

