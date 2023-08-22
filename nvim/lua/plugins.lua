return require('packer').startup(function(use)
  -- plugins --
  use 'wbthomason/packer.nvim'

  use 'JoosepAlviste/nvim-ts-context-commentstring'
  use 'ervandew/supertab'
  use 'godlygeek/tabular'
  use 'junegunn/fzf.vim'
  use 'junegunn/vim-emoji'
  use 'kshenoy/vim-signature'
  use 'lewis6991/gitsigns.nvim'
  use 'ncm2/float-preview.nvim'
  use 'romgrk/barbar.nvim'
  use 'scrooloose/nerdcommenter'
  use 'tomtom/tlib_vim'
  use 'tpope/vim-surround'
  use 'wellle/targets.vim'
  use { 'Yggdroot/LeaderF', run = ':LeaderfInstallCExtension' }
  use { 'dstein64/nvim-scrollview', branch = 'main' }
  use { 'junegunn/fzf', run = ":call fzf#install()" }
  use { 'nvim-lualine/lualine.nvim', requires = { 'nvim-tree/nvim-web-devicons', opt = true }}
  use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' }
  use({ 'vladdoster/remember.nvim', config = [[ require('remember') ]] })

  -- language support
  use 'JuliaEditorSupport/julia-vim'
  use 'bioSyntax/bioSyntax-vim'
  use 'chrisbra/csv.vim'
  use 'fatih/vim-go'
  use 'glench/vim-jinja2-syntax'
  use 'ibab/vim-snakemake'
  use 'jalvesaq/Nvim-R'
  use 'leafgarland/typescript-vim'
  use 'maxmellon/vim-jsx-pretty'
  use 'mboughaba/i3config.vim'
  use 'mllg/vim-devtools-plugin'
  use 'mzlogin/vim-markdown-toc'
  use 'pangloss/vim-javascript'
  use 'raimon49/requirements.txt.vim'
  use 'stephpy/vim-yaml'
  use 'tikhomirov/vim-glsl'
  use 'udalov/kotlin-vim'
  use 'yuezk/vim-js'
  use { 'neoclide/coc.nvim', branch = 'release'}

  -- textobjs
  use 'kana/vim-textobj-user'
  use { 'tyru/vim-textobj-underscore', branch = 'support-3-cases' }
  -- use 'glts/vim-textobj-comment'

  -- colorschemes
  use 'drewtempelmeyer/palenight.vim'
  use 'navarasu/onedark.nvim'
  use 'rakr/vim-one'
  use 'reedes/vim-colors-pencil'
  use 'tyrannicaltoucan/vim-quantum'
  use {'dracula/vim', as = 'dracula'}

  -- devicons should come last..
  use 'nvim-tree/nvim-web-devicons'
  use 'ryanoasis/vim-devicons'

  use '~/.config/nvim/plugged/mindful.vim'

  -- maybe..
  -- use 'nathanaelkane/vim-indent-guides'
  -- https://github.com/NvChad/nvim-colorizer.lua
  -- https://github.com/brenoprata10/nvim-highlight-colors

  -- archived
  -- use {'andymass/vim-matchup', event = 'VimEnter'}
  -- use 'ggandor/lightspeed.nvim'
  -- use 'rrethy/vim-hexokinase', { 'run': 'make hexokinase' }
  -- use 'tpope/vim-repeat'
  -- use 'kana/vim-operator-user'
end)
