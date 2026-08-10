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
-- `palette` stays in sync automatically through the shared artifact;
-- kitty.conf's hardcoded line is only the fresh-machine fallback.
-- ---------------------------------------------------------------------------

local M = {}

-- Filled by refresh(); role -> hex (incl. float). Exposed because
-- lualine_theme() and plugins/ui.lua read roles from it.
M.palette = {}
-- hex -> true for the six tones kitty will render translucent.
M.registered = {}

local ROLE_KEYS = { 'chrome', 'cursorline', 'tab_on', 'tab_off', 'tab_fill', 'raised' }

local function refresh()
  local glass = require('user.noctalia.palette').load().glass
  M.palette = {}
  M.registered = {}
  for _, role in ipairs(ROLE_KEYS) do
    M.palette[role] = glass[role]
    M.registered[glass[role]:lower()] = true
  end
  M.palette.float = glass.float
end

local function repaint(group, bg)
  vim.api.nvim_set_hl(0, group, vim.tbl_extend('force',
    vim.api.nvim_get_hl(0, { name = group, link = false }), { bg = bg }))
end

function M.apply()
  refresh()
  -- Popups must stay solid: paint them in a color that is NOT on kitty's
  -- transparent list (and differs from the default background).
  for _, group in ipairs({ 'NormalFloat', 'FloatBorder', 'Pmenu' }) do
    repaint(group, M.palette.float)
  end
  -- Groups that paint their own background and would otherwise punch an
  -- opaque rectangle through the glass: reuse already-registered tones.
  repaint('ColorColumn', M.palette.tab_off)
  repaint('ScrollView', M.palette.raised)
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
  refresh()
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
