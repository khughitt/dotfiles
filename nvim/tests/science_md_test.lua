-- science-md.nvim must be installable on any host, pinned, and loadable.
-- Run with -l, which exits non-zero on error (+lua followed by +qa! does not).
local plugin = assert(require('lazy.core.config').plugins['science-md.nvim'], 'missing science-md.nvim spec')
assert(not plugin._.is_local, 'science-md.nvim must be managed by lazy.nvim, not local dir')
assert(
  plugin.url == 'https://github.com/khughitt/science-md.nvim.git',
  'science-md.nvim must be cloneable on any host, got ' .. tostring(plugin.url)
)

local lock = require('lazy.manage.lock').get(plugin)
assert(
  lock and lock.branch == 'main' and type(lock.commit) == 'string' and #lock.commit >= 7,
  'missing science-md.nvim lock entry'
)

require('lazy').load({ plugins = { 'science-md.nvim' } })
assert(type(require('science-md').setup) == 'function', 'science-md.nvim did not load')
