#!/bin/env sh
echo "Installing Minconda"
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
sh Miniconda3-latest-Linux-x86_64.sh

# add channels
conda config --add channels defaults
conda config --add channels bioconda
conda config --add channels conda-forge

# config
conda config --set anaconda_upload yes

conda install -c conda-forge ncurses  
conda install csvkit visidata snakemake-minimal pynvim black

git clone https://github.com/esc/conda-zsh-completion ~/software/conda-zsh-completion

# other things that may be useful to install, depending on the system..
# conda install the-silver-searcher neovim 