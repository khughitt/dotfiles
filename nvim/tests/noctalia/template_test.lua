package.path = 'nvim/lua/?.lua;nvim/lua/?/init.lua;' .. package.path
local p = require('user.noctalia.palette')

local fh = assert(io.open('nvim/lua/user/noctalia/palette-template.json'),
  'template file missing')
local text = fh:read('*a'); fh:close()

-- every placeholder must be a well-formed noctalia color reference
for ph in text:gmatch('{{(.-)}}') do
  assert(ph:match('^colors%.[%w_]+%.default%.hex$'), 'bad placeholder: ' .. ph)
end

-- substitute each DISTINCT token with a distinct hex, then decode + validate
local tokens, n = {}, 0
local rendered = text:gsub('{{colors%.([%w_]+)%.default%.hex}}', function(tok)
  if not tokens[tok] then n = n + 1; tokens[tok] = string.format('#%06x', n * 1111) end
  return tokens[tok]
end)
assert(not rendered:find('{{', 1, true), 'unsubstituted placeholder left')

local ok, raw = pcall(vim.json.decode, rendered)
assert(ok, 'rendered template must be valid JSON: ' .. tostring(raw))
assert(p.validate(raw), 'rendered template must satisfy palette.validate')
assert(raw.glass.selection == tokens.primary_container,
  'selection must use primary_container')

print('OK template')
