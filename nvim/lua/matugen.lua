 local M = {}

function M.setup()
  require('base16-colorscheme').setup({
    base00 = '#131315',
    base01 = '#1f1f21',
    base02 = '#2a2a2b',
    base03 = '#909097',
    base04 = '#c6c6cd',
    base05 = '#e4e2e4',
    base06 = '#e4e2e4',
    base07 = '#e4e2e4',
    base08 = '#ffb4ab',
    base09 = '#debdd4',
    base0A = '#c4c6d2',
    base0B = '#bec6e1',
    base0C = '#debdd4',
    base0D = '#bec6e1',
    base0E = '#c4c6d2',
    base0F = '#93000a',
  })

  local hi = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  hi('TelescopeNormal',         { fg = '#e4e2e4',          bg = '#131315' })
  hi('TelescopeBorder',         { fg = '#909097',             bg = '#131315' })
  hi('TelescopePromptNormal',   { fg = '#e4e2e4',          bg = '#131315' })
  hi('TelescopePromptBorder',   { fg = '#909097',             bg = '#131315' })
  hi('TelescopePromptPrefix',   { fg = '#bec6e1',             bg = '#131315' })
  hi('TelescopePromptCounter',  { fg = '#c6c6cd',  bg = '#131315' })
  hi('TelescopePromptTitle',    { fg = '#131315',             bg = '#bec6e1' })
  hi('TelescopePreviewTitle',   { fg = '#131315',             bg = '#c4c6d2' })
  hi('TelescopeResultsTitle',   { fg = '#131315',             bg = '#debdd4' })
  hi('TelescopeSelection',      { fg = '#e4e2e4',          bg = '#2a2a2b' })
  hi('TelescopeSelectionCaret', { fg = '#bec6e1',             bg = '#2a2a2b' })
  hi('TelescopeMatching',       { fg = '#bec6e1',             bold = true })
end

 -- Register a signal handler for SIGUSR1 (matugen updates)
 local signal = vim.uv.new_signal()
 signal:start(
   'sigusr1',
   vim.schedule_wrap(function()
     package.loaded['matugen'] = nil
     require('matugen').setup()
   end)
 )

 return M
