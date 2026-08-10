-- Loads the noctalia-generated raw palette (JSON), validating shape and the
-- glass invariants (six distinct registered tones; float solid and
-- unregistered). bin/noctalia-glass-sync enforces the same invariants before
-- promoting, so a hard error here means the promoted file was hand-edited or
-- corrupted. Only a MISSING file falls back (fresh machine).

local M = {}

-- Keep in sync with REQUIRED in bin/noctalia-glass-sync.
local REQUIRED = {
  'primary', 'primary_fixed_dim', 'on_primary',
  'secondary', 'secondary_fixed_dim',
  'tertiary', 'tertiary_fixed_dim',
  'error', 'error_container',
  'surface', 'on_surface', 'on_surface_variant', 'on_background',
  'outline', 'outline_variant', 'surface_variant',
}
local REGISTERED_ROLES = { 'chrome', 'cursorline', 'tab_on', 'tab_off', 'tab_fill', 'raised' }

local function is_hex(v) return type(v) == 'string' and v:match('^#%x%x%x%x%x%x$') ~= nil end

function M.validate(raw)
  if type(raw) ~= 'table' then return nil, 'not a table' end
  for _, key in ipairs(REQUIRED) do
    if not is_hex(raw[key]) then return nil, ('missing/invalid key %q'):format(key) end
  end
  if type(raw.glass) ~= 'table' then return nil, 'missing glass table' end
  local seen = {}
  for _, role in ipairs(REGISTERED_ROLES) do
    local v = raw.glass[role]
    if not is_hex(v) then return nil, ('glass.%s missing/invalid'):format(role) end
    v = v:lower()
    if seen[v] then return nil, ('glass tones collide on %s'):format(v) end
    seen[v] = true
  end
  if not is_hex(raw.glass.float) then return nil, 'glass.float missing/invalid' end
  if raw.glass.float:lower() == raw.surface:lower() then
    return nil, 'glass.float equals surface (floats would go translucent)'
  end
  if seen[raw.glass.float:lower()] then return nil, 'glass.float is a registered tone' end
  return raw
end

M.path = vim.fn.expand('~/.cache/noctalia/nvim-glass/current/nvim-palette.json')

local warned = false

function M.load()
  -- Only a genuinely ABSENT file may fall back (fresh machine). Any other
  -- failure -- permission denied, I/O error, present-but-unopenable -- must
  -- surface, or a broken install silently themes with stale colors.
  local stat, stat_err = vim.uv.fs_stat(M.path)
  if not stat then
    if stat_err and not stat_err:match('^ENOENT') then
      error(('noctalia palette %s: %s'):format(M.path, stat_err))
    end
    if not warned then
      warned = true
      vim.schedule(function()
        vim.notify('noctalia palette missing; using built-in default (apply a noctalia color scheme once)',
          vim.log.levels.WARN)
      end)
    end
    return require('user.noctalia.default_palette')
  end
  local fh, open_err = io.open(M.path)
  if not fh then
    error(('noctalia palette %s exists but cannot be read: %s'):format(
      M.path, tostring(open_err)))
  end
  local text = fh:read('*a')
  fh:close()
  local ok, raw = pcall(vim.json.decode, text)
  if not ok then
    error(('noctalia palette %s is not valid JSON: %s'):format(M.path, raw))
  end
  local valid, err = M.validate(raw)
  if not valid then
    error(('noctalia palette %s invalid: %s'):format(M.path, err))
  end
  return valid
end

return M
