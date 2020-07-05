#!/bin/bash
#
# dotfiles setup script (mac)
# KH (nov.19)
#
DOTS_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Determine resolution to use
# HIRES=""

# while [[ "$HIRES" != "n" && "$HIRES" != "y" ]]; do
#     read -r -p "Configure system for 4k display? [y|N] " HIRES
#     HIRES="${HIRES,,}"
#
#     if [[ "$HIRES" == "" ]]; then
#         HIRES="n"
#     fi
# done

# Check for configuration directory
export XDG_CONFIG_HOME="$HOME/.config"

if [ -z $XDG_CONFIG_HOME ]; then
    XDG_CONFIG_HOME=$HOME/.config
fi
mkdir -p $XDG_CONFIG_HOME

# Checks for file or directory and creates a sym link if it doesn't already exist
function ln_s() {
    # delete existing symlink if it exists
    if [[ -e "$2" && -L "$2" ]]; then
        rm $2
    fi
    echo "[CREATING] \"$2\""
    ln -sf $1 $2
}

echo "Setting up dotfiles..."

# Setup zsh
ln_s ${DOTS_HOME}/zshrc ~/.zshrc
ln_s ${DOTS_HOME}/zshenv ~/.zshenv
ln_s ${DOTS_HOME}/shell ~/.shell

# Gtk 3.0
if [ ! -e ${XDG_CONFIG_HOME}/gtk-3.0/ ]; then
    mkdir ${XDG_CONFIG_HOME}/gtk-3.0/
fi
ln -sf ${DOTS_HOME}/gtkrc-3.0 ${XDG_CONFIG_HOME}/gtk-3.0/settings.ini
ln -sf ${DOTS_HOME}/gtk.css ${XDG_CONFIG_HOME}/gtk-3.0/gtk.css

ln_s ${DOTS_HOME}/gtkrc-2.0 ~/.gtkrc-2.0

# ~/.config/xx
for path in "git" "nvim" "powerline" "pylintrc" "ranger" "snakemake" "termcolors"; do
    ln_s ${DOTS_HOME}/${path} ${XDG_CONFIG_HOME}/${path}
done

# ~/.xx
for path in "agignore" "ctags" "dir_colors"  \
            "plotly" "Rprofile" "Renviron" "tmux" "tmux.conf" \
            "vim" "vimrc" "visidatarc" "Xmodmap" "Xresources" "condarc"; do
    ln_s ${DOTS_HOME}/${path} ~/.${path}
done

# .xinitrc
# TODO... 
# http://www.mcnabbs.org/andrew/linux/macosx11/

# git
ln_s ${DOTS_HOME}/git/ignore ${HOME}/.gitignore_global
ln_s ${DOTS_HOME}/git/config ${HOME}/.gitconfig

# julia
mkdir -p ${HOME}/.julia/config
ln_s ${DOTS_HOME}/$julia/startup.jl ${HOME}/.julia/config/startup.jl

# Vim temp dirs
mkdir -p ~/.vim/tmp/backup
mkdir -p ~/.vim/tmp/yankring

#
# external dependencies
#

# os x
# brew: fd neovim python fasd the_silver_searcher ripgrep lsd fzf csvkit tldr thefuck
#       gotop
# pip: neovim

# echo 'Installing python packages...'
# pip install --user colorz
# pip install --user haishoku
# pip install --user colorthief

# others
#echo "Installing Cargo packages..."
#cargo install du-dust bb tldr

echo "Done!"
echo "Don't forget to install any necessary fonts, icons, etc."

