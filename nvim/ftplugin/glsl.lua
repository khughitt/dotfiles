-- Run the current shader in glslviewer.
--
-- (Was ftplugin/glsl.vim, whose mappings were global -- opening one shader
-- rebound <leader>r everywhere, including over markdown's "insert References
-- heading".)
if vim.fn.executable('glslviewer') == 0 then
  return
end

local function run_shader()
  vim.system({ 'glslviewer', vim.fn.expand('%:p') }, { detach = true })
end

vim.keymap.set('n', '<leader>r', run_shader,
  { buffer = true, silent = true, desc = 'glsl: run in glslviewer' })
vim.keymap.set('i', '<leader>r', function() vim.cmd('stopinsert'); run_shader() end,
  { buffer = true, silent = true, desc = 'glsl: run in glslviewer' })
