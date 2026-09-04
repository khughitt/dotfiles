assert(vim.opt.fillchars:get().eob == ' ', 'end-of-buffer markers should be hidden')
assert(vim.g.colors_name == 'tokyonight-moon', 'tokyonight-moon should be active')

print('OK theme')
