-- ---------------------------------------------------------------------------
-- markdown.lua
-- ---------------------------------------------------------------------------

local buf = vim.api.nvim_get_current_buf()

vim.opt_local.conceallevel = 0

local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { buffer = buf, silent = true, desc = 'md: ' .. desc })
end

-- ---------------------------------------------------------------------------
-- Headings
-- ---------------------------------------------------------------------------

-- underline the current line, setext style
local function underline(char)
  local line = vim.api.nvim_get_current_line()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(buf, row, row, false, { char:rep(vim.fn.strwidth(line)) })
  vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
end

map('n', '<F5>', function() underline('-') end, 'underline heading with -')
map('i', '<F5>', function() underline('-') end, 'underline heading with -')
map('n', '<leader><F5>', function() underline('=') end, 'underline heading with =')
map('i', '<leader><F5>', function() underline('=') end, 'underline heading with =')

-- insert a "<text>\n-----\n" section above the current line
local function add_header(text)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(buf, row - 1, row - 1, false,
    { text, ('-'):rep(#text), '' })
  vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
end

map('n', '<leader>o', function() add_header('Overview') end,   'insert Overview heading')
map('n', '<leader>r', function() add_header('References') end, 'insert References heading')

-- timestamp at the top of the file
map('n', '<leader>s', function()
  vim.api.nvim_buf_set_lines(buf, 1, 1, false, { os.date('_%b %d %Y %H:%M:%S_'), '' })
end, 'insert timestamp')

-- wrap the word under the cursor in underscores (vim-surround)
map('n', '<c-g>', 'ysiw_', 'italicise word')

-- ---------------------------------------------------------------------------
-- Paste a markdown link for the URL on the clipboard
--
-- Image URLs are downloaded into ./.img/ and linked relatively; everything
-- else gets its <title> fetched so the link has a readable label.
-- https://benjamincongdon.me/blog/2020/06/27/Vim-Tip-Paste-Markdown-Link-with-Automatic-Title-Fetching/
--
-- Commands are run as argv lists rather than through a shell, so a URL
-- containing shell metacharacters cannot be executed.
--
-- Bound to <localleader>f rather than <leader>f: the latter is a prefix of
-- telescope's <leader>ff/fg/fb/fh/fr, so in a markdown buffer every one of
-- those either stalled for timeoutlen or fired this instead.
-- ---------------------------------------------------------------------------

local IMAGE_EXTENSIONS = { gif = true, jpg = true, jpeg = true, png = true,
                           webp = true, svg = true }

local function url_title(url)
  local script = table.concat({
    'import sys, warnings, bs4, requests',
    "warnings.filterwarnings('ignore')",
    "print(bs4.BeautifulSoup(requests.get(sys.argv[1]).content, 'lxml').title.text.strip())",
  }, '\n')
  local out = vim.fn.system({ 'python3', '-c', script, url })
  if vim.v.shell_error ~= 0 then
    vim.notify(out, vim.log.levels.WARN)
    return nil
  end
  return (out:gsub('%s+$', ''))
end

local function download_image(url)
  local imgdir = vim.fn.expand('%:p:h') .. '/.img'
  vim.fn.mkdir(imgdir, 'p', 493)  -- 0755

  local suggested = url:gsub('%?.*$', ''):match('([^/]+)$') or 'image'
  local name = vim.fn.input('Filename? ', suggested)
  if name == '' then
    return nil
  end

  local out = vim.fn.system({ 'curl', '-sSL', '-o', imgdir .. '/' .. name, url })
  if vim.v.shell_error ~= 0 then
    vim.notify(out, vim.log.levels.WARN)
    return nil
  end
  return '.img/' .. name
end

map('n', '<localleader>f', function()
  local url = vim.fn.getreg('+'):gsub('%s+$', '')
  if not url:match('^https?://') then
    vim.notify('clipboard does not hold a URL', vim.log.levels.WARN)
    return
  end

  local ext = (url:gsub('%?.*$', ''):match('%.([%a]+)$') or ''):lower()

  local link
  if IMAGE_EXTENSIONS[ext] then
    local path = download_image(url)
    link = path and ('![](' .. path .. ')')
  else
    local title = url_title(url)
    link = title and ('[' .. title .. '](' .. url .. ')')
  end
  if not link then
    return
  end

  -- textwidth would break a long link across lines
  local saved = vim.bo.textwidth
  vim.bo.textwidth = 0
  vim.api.nvim_put({ link }, 'c', true, true)
  vim.bo.textwidth = saved
end, 'paste URL as a markdown link')

-- ---------------------------------------------------------------------------
-- Inline math, so $...$ and $$...$$ do not read as prose
-- ---------------------------------------------------------------------------
vim.cmd([[
  syn region mdMath start=/\$\$/ end=/\$\$/
  syn match  mdMath '\$[^$].\{-}\$'
  hi def link mdMath Statement
]])
