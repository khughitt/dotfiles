-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Every file under lua/user/plugins/ returns a plugin spec list.
--
-- git.filter = false disables lazy's blobless partial clone. leap.nvim is
-- hosted on Codeberg, which does not serve --filter=blob:none, so the default
-- makes its install fail.
require("lazy").setup({
  { import = "user.plugins" },
}, {
  git = { filter = false },
  install = { colorscheme = { "tokyonight", "habamax" } },
  change_detection = { notify = false },
})
