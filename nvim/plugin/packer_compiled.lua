-- Automatically generated packer.nvim plugin loader code

if vim.api.nvim_call_function('has', {'nvim-0.5'}) ~= 1 then
  vim.api.nvim_command('echohl WarningMsg | echom "Invalid Neovim version for packer.nvim! | echohl None"')
  return
end

vim.api.nvim_command('packadd packer.nvim')

local no_errors, error_msg = pcall(function()

_G._packer = _G._packer or {}
_G._packer.inside_compile = true

local time
local profile_info
local should_profile = false
if should_profile then
  local hrtime = vim.loop.hrtime
  profile_info = {}
  time = function(chunk, start)
    if start then
      profile_info[chunk] = hrtime()
    else
      profile_info[chunk] = (hrtime() - profile_info[chunk]) / 1e6
    end
  end
else
  time = function(chunk, start) end
end

local function save_profiles(threshold)
  local sorted_times = {}
  for chunk_name, time_taken in pairs(profile_info) do
    sorted_times[#sorted_times + 1] = {chunk_name, time_taken}
  end
  table.sort(sorted_times, function(a, b) return a[2] > b[2] end)
  local results = {}
  for i, elem in ipairs(sorted_times) do
    if not threshold or threshold and elem[2] > threshold then
      results[i] = elem[1] .. ' took ' .. elem[2] .. 'ms'
    end
  end
  if threshold then
    table.insert(results, '(Only showing plugins that took longer than ' .. threshold .. ' ms ' .. 'to load)')
  end

  _G._packer.profile_output = results
end

time([[Luarocks path setup]], true)
local package_path_str = "/home/keith/.cache/nvim/packer_hererocks/2.1.1692616192/share/lua/5.1/?.lua;/home/keith/.cache/nvim/packer_hererocks/2.1.1692616192/share/lua/5.1/?/init.lua;/home/keith/.cache/nvim/packer_hererocks/2.1.1692616192/lib/luarocks/rocks-5.1/?.lua;/home/keith/.cache/nvim/packer_hererocks/2.1.1692616192/lib/luarocks/rocks-5.1/?/init.lua"
local install_cpath_pattern = "/home/keith/.cache/nvim/packer_hererocks/2.1.1692616192/lib/lua/5.1/?.so"
if not string.find(package.path, package_path_str, 1, true) then
  package.path = package.path .. ';' .. package_path_str
end

if not string.find(package.cpath, install_cpath_pattern, 1, true) then
  package.cpath = package.cpath .. ';' .. install_cpath_pattern
end

time([[Luarocks path setup]], false)
time([[try_loadstring definition]], true)
local function try_loadstring(s, component, name)
  local success, result = pcall(loadstring(s), name, _G.packer_plugins[name])
  if not success then
    vim.schedule(function()
      vim.api.nvim_notify('packer.nvim: Error running ' .. component .. ' for ' .. name .. ': ' .. result, vim.log.levels.ERROR, {})
    end)
  end
  return result
end

time([[try_loadstring definition]], false)
time([[Defining packer_plugins]], true)
_G.packer_plugins = {
  LeaderF = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/LeaderF",
    url = "https://github.com/Yggdroot/LeaderF"
  },
  ["Nvim-R"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/Nvim-R",
    url = "https://github.com/jalvesaq/Nvim-R"
  },
  ["barbar.nvim"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/barbar.nvim",
    url = "https://github.com/romgrk/barbar.nvim"
  },
  ["bioSyntax-vim"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/bioSyntax-vim",
    url = "https://github.com/bioSyntax/bioSyntax-vim"
  },
  ["coc.nvim"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/coc.nvim",
    url = "https://github.com/neoclide/coc.nvim"
  },
  ["csv.vim"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/csv.vim",
    url = "https://github.com/chrisbra/csv.vim"
  },
  dracula = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/dracula",
    url = "https://github.com/dracula/vim"
  },
  ["float-preview.nvim"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/float-preview.nvim",
    url = "https://github.com/ncm2/float-preview.nvim"
  },
  fzf = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/fzf",
    url = "https://github.com/junegunn/fzf"
  },
  ["fzf.vim"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/fzf.vim",
    url = "https://github.com/junegunn/fzf.vim"
  },
  ["gitsigns.nvim"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/gitsigns.nvim",
    url = "https://github.com/lewis6991/gitsigns.nvim"
  },
  ["i3config.vim"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/i3config.vim",
    url = "https://github.com/mboughaba/i3config.vim"
  },
  ["julia-vim"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/julia-vim",
    url = "https://github.com/JuliaEditorSupport/julia-vim"
  },
  ["kotlin-vim"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/kotlin-vim",
    url = "https://github.com/udalov/kotlin-vim"
  },
  ["lualine.nvim"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/lualine.nvim",
    url = "https://github.com/nvim-lualine/lualine.nvim"
  },
  ["mindful.vim"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/mindful.vim",
    url = "/home/keith/.config/nvim/plugged/mindful.vim"
  },
  nerdcommenter = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/nerdcommenter",
    url = "https://github.com/scrooloose/nerdcommenter"
  },
  ["nvim-scrollview"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/nvim-scrollview",
    url = "https://github.com/dstein64/nvim-scrollview"
  },
  ["nvim-treesitter"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/nvim-treesitter",
    url = "https://github.com/nvim-treesitter/nvim-treesitter"
  },
  ["nvim-ts-context-commentstring"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/nvim-ts-context-commentstring",
    url = "https://github.com/JoosepAlviste/nvim-ts-context-commentstring"
  },
  ["nvim-web-devicons"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/nvim-web-devicons",
    url = "https://github.com/nvim-tree/nvim-web-devicons"
  },
  ["onedark.nvim"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/onedark.nvim",
    url = "https://github.com/navarasu/onedark.nvim"
  },
  ["packer.nvim"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/packer.nvim",
    url = "https://github.com/wbthomason/packer.nvim"
  },
  ["palenight.vim"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/palenight.vim",
    url = "https://github.com/drewtempelmeyer/palenight.vim"
  },
  ["remember.nvim"] = {
    config = { " require('remember') " },
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/remember.nvim",
    url = "https://github.com/vladdoster/remember.nvim"
  },
  ["requirements.txt.vim"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/requirements.txt.vim",
    url = "https://github.com/raimon49/requirements.txt.vim"
  },
  supertab = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/supertab",
    url = "https://github.com/ervandew/supertab"
  },
  tabular = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/tabular",
    url = "https://github.com/godlygeek/tabular"
  },
  ["targets.vim"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/targets.vim",
    url = "https://github.com/wellle/targets.vim"
  },
  tlib_vim = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/tlib_vim",
    url = "https://github.com/tomtom/tlib_vim"
  },
  ["typescript-vim"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/typescript-vim",
    url = "https://github.com/leafgarland/typescript-vim"
  },
  ["vim-colors-pencil"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/vim-colors-pencil",
    url = "https://github.com/reedes/vim-colors-pencil"
  },
  ["vim-devicons"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/vim-devicons",
    url = "https://github.com/ryanoasis/vim-devicons"
  },
  ["vim-devtools-plugin"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/vim-devtools-plugin",
    url = "https://github.com/mllg/vim-devtools-plugin"
  },
  ["vim-emoji"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/vim-emoji",
    url = "https://github.com/junegunn/vim-emoji"
  },
  ["vim-glsl"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/vim-glsl",
    url = "https://github.com/tikhomirov/vim-glsl"
  },
  ["vim-go"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/vim-go",
    url = "https://github.com/fatih/vim-go"
  },
  ["vim-javascript"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/vim-javascript",
    url = "https://github.com/pangloss/vim-javascript"
  },
  ["vim-jinja2-syntax"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/vim-jinja2-syntax",
    url = "https://github.com/glench/vim-jinja2-syntax"
  },
  ["vim-js"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/vim-js",
    url = "https://github.com/yuezk/vim-js"
  },
  ["vim-jsx-pretty"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/vim-jsx-pretty",
    url = "https://github.com/maxmellon/vim-jsx-pretty"
  },
  ["vim-markdown-toc"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/vim-markdown-toc",
    url = "https://github.com/mzlogin/vim-markdown-toc"
  },
  ["vim-one"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/vim-one",
    url = "https://github.com/rakr/vim-one"
  },
  ["vim-quantum"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/vim-quantum",
    url = "https://github.com/tyrannicaltoucan/vim-quantum"
  },
  ["vim-signature"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/vim-signature",
    url = "https://github.com/kshenoy/vim-signature"
  },
  ["vim-snakemake"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/vim-snakemake",
    url = "https://github.com/ibab/vim-snakemake"
  },
  ["vim-surround"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/vim-surround",
    url = "https://github.com/tpope/vim-surround"
  },
  ["vim-textobj-underscore"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/vim-textobj-underscore",
    url = "https://github.com/tyru/vim-textobj-underscore"
  },
  ["vim-textobj-user"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/vim-textobj-user",
    url = "https://github.com/kana/vim-textobj-user"
  },
  ["vim-yaml"] = {
    loaded = true,
    path = "/home/keith/.local/share/nvim/site/pack/packer/start/vim-yaml",
    url = "https://github.com/stephpy/vim-yaml"
  }
}

time([[Defining packer_plugins]], false)
-- Config for: remember.nvim
time([[Config for remember.nvim]], true)
 require('remember') 
time([[Config for remember.nvim]], false)

_G._packer.inside_compile = false
if _G._packer.needs_bufread == true then
  vim.cmd("doautocmd BufRead")
end
_G._packer.needs_bufread = false

if should_profile then save_profiles() end

end)

if not no_errors then
  error_msg = error_msg:gsub('"', '\\"')
  vim.api.nvim_command('echohl ErrorMsg | echom "Error in packer_compiled: '..error_msg..'" | echom "Please check your config for correctness" | echohl None')
end
