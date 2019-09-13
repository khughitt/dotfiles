#!/bin/env sh
echo "Installing Minconda"
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
sh Miniconda3-latest-Linux-x86_64.sh

# add channels
conda config --add channels defaults
conda config --add channels bioconda

# leaving out conda-forge by now to avoid compatibility issues
#conda config --add channels conda-forge

# config
conda config --set anaconda_upload yes

# install some useful packages
conda install -c conda-forge ncurses csvkit visidata snakemake-minimal

# neovim
conda install -c conda-forge pynvim jupyter

# black[d]
conda install -c black aiohttp

# radian r console (pip install --user radian)
conda install jedi 

# conda tab completion for zsh
git clone https://github.com/esc/conda-zsh-completion ~/software/conda-zsh-completion

#
# other things that may be useful to install, depending on the system..
#

# conda install the_silver_searcher
# conda install -c conda-forge tmux htop source-highlight
# conda install -c tsnyder figlet 
# conda install -c ostrokach-forge fd-find 
# conda install ripgrep
# conda install rust
