-- ---------------------------------------------------------------------------
-- Kitty glass palette
--
-- kitty decides transparency per *cell background color*: only cells painted
-- in the default background, or in one of the (max 7) colors listed under
-- transparent_background_colors in kitty.conf, are translucent. Everything
-- else paints a solid rectangle over the wallpaper.
--
-- Two consequences drive this whole module:
--   1. Slots are scarce (6 of 7 used), so UI that paints its own background is
--      *recolored here to reuse an already-registered color* rather than
--      spending a slot on it.
--   2. Glyphs are always opaque -- kitty has no per-cell text alpha. Anything
--      drawn as a character (window separators, barbar's dividers, lualine's
--      powerline chevrons) can only be recolored or removed, never softened.
--
-- Keep `palette` in sync with transparent_background_colors in kitty.conf.
-- ---------------------------------------------------------------------------

local M = {}

M.palette = {
  chrome     = '#1e2030',  -- StatusLine / lualine_c / TabLine
  cursorline = '#2f334d',
  tab_on     = '#222436',  -- barbar current buffer
  tab_off    = '#272a3f',  -- barbar inactive buffer
  tab_fill   = '#2c3048',  -- barbar tabpage fill
  raised     = '#3b4261',  -- lualine_b / Folded
}

-- Reverse index, so code can ask "is this color one kitty will make
-- translucent?" without hardcoding the list a second time.
M.registered = {}
for _, color in pairs(M.palette) do
  M.registered[color] = true
end

-- Popups must stay solid: tokyonight paints NormalFloat/Pmenu/FloatBorder in
-- #1e2030, the same color as the statusline, so registering that color would
-- drag completion menus and LSP hovers along with it -- over the text they
-- exist to occlude. Repaint them in a color that is NOT on kitty's list.
local float_bg = '#16161e'

-- group -> registered color. These paint their own background and would
-- otherwise punch an opaque rectangle through the glass.
local recolor = {
  ColorColumn = M.palette.tab_off,  -- the colorcolumn=100 right margin
  ScrollView  = M.palette.raised,   -- nvim-scrollview's bar
}

local function repaint(group, bg)
  vim.api.nvim_set_hl(0, group, vim.tbl_extend('force',
    vim.api.nvim_get_hl(0, { name = group, link = false }), { bg = bg }))
end

function M.apply()
  for _, group in ipairs({ 'NormalFloat', 'FloatBorder', 'Pmenu' }) do
    repaint(group, float_bg)
  end
  for group, bg in pairs(recolor) do
    repaint(group, bg)
  end
end

-- Apply now and re-apply on every colorscheme change, since loading a
-- colorscheme clears highlight groups.
function M.setup()
  M.apply()
  vim.api.nvim_create_autocmd('ColorScheme', { callback = M.apply })
end

-- lualine's mode badge (section a, mirrored by z) paints a different background
-- per mode -- blue/green/purple/red/yellow/teal, six colors against one free
-- kitty slot -- so they cannot all be registered. Instead move the mode color
-- to the *text* and put the badge itself on registered glass: every mode goes
-- translucent and no slot is spent. Sections b and c already use registered
-- colors, so they are left alone.
--
-- The badge background must differ from section b (raised) and section c
-- (chrome), or the badge merges into its neighbour and the separator between
-- them vanishes. cursorline lands a/b/c on mid / light / dark.
function M.lualine_theme()
  local theme = vim.deepcopy(require('lualine.themes.tokyonight'))
  for _, sections in pairs(theme) do
    for _, key in ipairs({ 'a', 'b', 'c', 'x', 'y', 'z' }) do
      local section = sections[key]
      if type(section) == 'table' and section.bg
         and not M.registered[section.bg:lower()] then
        section.fg, section.bg = section.bg, M.palette.cursorline
      end
    end
  end
  return theme
end

return M
