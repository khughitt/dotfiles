 local M = {}

function M.setup()
  require('base16-colorscheme').setup({
    base00 = '#131315',
    base01 = '#1f1f21',
    base02 = '#292a2c',
    base03 = '#8e9197',
    base04 = '#c5c6cd',
    base05 = '#e4e2e4',
    base06 = '#e4e2e4',
    base07 = '#e4e2e4',
    base08 = '#ffb4ab',
    base09 = '#ddbdd8',
    base0A = '#c2c6d2',
    base0B = '#b8c7e2',
    base0C = '#ddbdd8',
    base0D = '#b8c7e2',
    base0E = '#c2c6d2',
    base0F = '#dee2ef',
  })

  local hi = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  hi('TelescopeNormal',         { fg = '#e4e2e4',          bg = '#131315' })
  hi('TelescopeBorder',         { fg = '#8e9197',             bg = '#131315' })
  hi('TelescopePromptNormal',   { fg = '#e4e2e4',          bg = '#131315' })
  hi('TelescopePromptBorder',   { fg = '#8e9197',             bg = '#131315' })
  hi('TelescopePromptPrefix',   { fg = '#b8c7e2',             bg = '#131315' })
  hi('TelescopePromptCounter',  { fg = '#c5c6cd',  bg = '#131315' })
  hi('TelescopePromptTitle',    { fg = '#131315',             bg = '#b8c7e2' })
  hi('TelescopePreviewTitle',   { fg = '#131315',             bg = '#c2c6d2' })
  hi('TelescopeResultsTitle',   { fg = '#131315',             bg = '#ddbdd8' })
  hi('TelescopeSelection',      { fg = '#e4e2e4',          bg = '#292a2c' })
  hi('TelescopeSelectionCaret', { fg = '#b8c7e2',             bg = '#292a2c' })
  hi('TelescopeMatching',       { fg = '#b8c7e2',             bold = true })
end

-- Register a signal handler for SIGUSR1 (matugen updates).
-- The handler re-requires this module, which re-runs the code below, so the
-- previous handle is stopped first; otherwise handlers double on every signal.
if _G.__matugen_signal then
  _G.__matugen_signal:stop()
  _G.__matugen_signal:close()
end

local signal = vim.uv.new_signal()
_G.__matugen_signal = signal
signal:start(
  'sigusr1',
  vim.schedule_wrap(function()
    package.loaded['matugen'] = nil
    require('matugen').setup()
  end)
)

return M
