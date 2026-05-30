local config_mod = require('science-md.config')
local highlights = require('science-md.highlights')
local project = require('science-md.project')
local render = require('science-md.render')
local scheduler = require('science-md.scheduler')

local M = {}

local active = {}
local config = config_mod.merge()

local function augroup_name(buf)
  return 'science_md_' .. tostring(buf)
end

function M.enable(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if active[buf] then
    scheduler.schedule(buf, config, true)
    return
  end

  active[buf] = true
  local group = vim.api.nvim_create_augroup(augroup_name(buf), { clear = true })

  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost' }, {
    group = group,
    buffer = buf,
    callback = function()
      scheduler.schedule(buf, config, true)
    end,
  })

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = group,
    buffer = buf,
    callback = function()
      scheduler.schedule(buf, config, false)
    end,
  })

  vim.api.nvim_create_autocmd('WinScrolled', {
    group = group,
    callback = function(args)
      local win = tonumber(args.match)
      if win and vim.api.nvim_win_is_valid(win) then
        if vim.api.nvim_win_get_buf(win) == buf then
          scheduler.schedule(buf, config, false)
        end
      elseif vim.api.nvim_get_current_buf() == buf then
        scheduler.schedule(buf, config, false)
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufWipeout', {
    group = group,
    buffer = buf,
    callback = function()
      M.disable(buf)
    end,
  })

  scheduler.schedule(buf, config, true)
end

function M.disable(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  active[buf] = nil
  pcall(vim.api.nvim_del_augroup_by_name, augroup_name(buf))
  scheduler.clear(buf)
  render.clear(buf)
end

local function maybe_enable(buf)
  if config.enabled == false then
    return
  end

  if config.enabled == true then
    M.enable(buf)
    return
  end

  local name = vim.api.nvim_buf_get_name(buf)
  if name == '' then
    return
  end

  local dir = vim.fs.dirname(name)
  if project.is_project(dir, config.marker) then
    M.enable(buf)
  end
end

function M.setup(opts)
  config = config_mod.merge(opts)
  highlights.define(config)

  local setup_group = vim.api.nvim_create_augroup('science_md_setup', { clear = true })
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = setup_group,
    callback = function()
      highlights.define(config)
    end,
  })

  vim.api.nvim_create_autocmd('FileType', {
    group = setup_group,
    pattern = 'markdown',
    callback = function(args)
      maybe_enable(args.buf)
    end,
  })

  local current = vim.api.nvim_get_current_buf()
  if vim.bo[current].filetype == 'markdown' then
    maybe_enable(current)
  end
end

return M
