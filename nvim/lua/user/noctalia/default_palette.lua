-- Fallback raw palette for machines where noctalia has not generated
-- ~/.cache/noctalia/nvim-glass/current/nvim-palette.json yet.
-- Tokyonight-moon flavored. Its registered glass colors and opacity suffixes
-- MUST match the hardcoded transparent_background_colors fallback line in
-- kitty/kitty.conf (asserted by nvim/tests/noctalia/palette_test.lua).
return {
  primary = '#82aaff',
  primary_fixed_dim = '#65bcff',
  on_primary = '#1e2030',
  secondary = '#86e1fc',
  secondary_fixed_dim = '#4fd6be',
  tertiary = '#c099ff',
  tertiary_fixed_dim = '#fca7ea',
  error = '#ff757f',
  error_container = '#c53b53',
  surface = '#222436',
  on_surface = '#c8d3f5',
  on_surface_variant = '#828bb8',
  on_background = '#c8d3f5',
  outline = '#636da6',
  outline_variant = '#545c7e',
  surface_variant = '#2f334d',
  glass = {
    chrome = '#1e2030',
    cursorline = '#2f334d',
    tab_on = '#1e2030',
    tab_off = '#272a3f',
    tab_fill = '#272a3f',
    raised = '#3b4261',
    diff_added = '#022800',
    diff_removed = '#3d0100',
    selection = '#003dbe',
    float = '#16161e',
  },
}
