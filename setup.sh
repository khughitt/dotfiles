#!/bin/bash

# Choose shell
read -p "Select a shell to use [bash/zsh]: " SH
if [ "$SH" != "bash" ] && [ "$SH" != "zsh" ]; then
    echo "Invalid choice. Exiting..."
    exit;
fi

# Check for configuration directory
if [ -z $XDG_CONFIG_HOME ]; then
    XDG_CONFIG_HOME=$HOME/.config
fi
mkdir -p $XDG_CONFIG_HOME

# Checks for file or directory and creates a sym link if it doesn't already exist
function ln_s() {
    if [ -e $2 ]; then
        echo "[SKIPPING] \"$2\" (already exists...)"
    else
        echo "[CREATING] \"$2\""
        ln -s $1 $2
    fi
}

echo "Setting up dotfiles..."

# Setup shell
ln_s ${PWD}/${SH}rc ~/.${SH}rc
ln_s ${PWD}/shell ~/.shell

# Awesome
ln_s ${PWD}/awesome ${XDG_CONFIG_HOME}/awesome

# Neovim
ln_s ${PWD}/nvim ${XDG_CONFIG_HOME}/nvim

# Gedit
mkdir -p ${XDG_CONFIG_HOME}/gedit/
cp -r ${PWD}/gedit/styles ${XDG_CONFIG_HOME}/gedit/

# Gtk 3.0
if [ ! -e ${XDG_CONFIG_HOME}/gtk-3.0/ ]; then
    mkdir ${XDG_CONFIG_HOME}/gtk-3.0/
fi
ln -s ${PWD}/gtkrc-3.0 ${XDG_CONFIG_HOME}/gtk-3.0/settings.ini

# Xresources themes
ln -s ${PWD}/termcolors ${XDG_CONFIG_HOME}/

# colorls
ln -s ${PWD}/colorls ${XDG_CONFIG_HOME}/colorls

# compton
mkdir -p ${XDG_CONFIG_HOME}/compton
ln -s ${PWD}/compton.conf ${XDG_CONFIG_HOME}/compton/compton.conf

# i3
mkdir -p ${XDG_CONFIG_HOME}/i3
ln -s ${PWD}/i3 ${XDG_CONFIG_HOME}/i3/config

# mimetypes
ln -s mimeapps.list ${XDG_CONFIG_HOME}/mimeapps.list

# sway
mkdir -p ${XDG_CONFIG_HOME}/sway
ln -s ${PWD}/sway ${XDG_CONFIG_HOME}/sway/config

# redshift
ln -s ${PWD}/redshift ${XDG_CONFIG_HOME}/redshift.conf

# i3status
mkdir -p ${XDG_CONFIG_HOME}/i3status
ln -s ${PWD}/i3status ${XDG_CONFIG_HOME}/i3status/config

# rofi
mkdir -p ${XDG_CONFIG_HOME}/rofi
ln -s ${PWD}/rofi ${XDG_CONFIG_HOME}/rofi/config

# termite
mkdir -p ${XDG_CONFIG_HOME}/termite
ln -s ${PWD}/termite ${XDG_CONFIG_HOME}/termite/config

# labnote
ln -s ${PWD}/labnote ${XDG_CONFIG_HOME}/labnote

# pylint 
ln -s ${PWD}/pylintrc ${XDG_CONFIG_HOME}/pylintrc

# ranger
ln -s ${PWD}/ranger ${XDG_CONFIG_HOME}/ranger

# Everything else
for path in "ctags" "dir_colors" "gitconfig" "gitignore_global" \
            "Rprofile" "Renviron" "tmux" "tmux.conf" \
            "vim" "vimrc" "xinitrc" "xmodmaprc" "Xresources" \
	    "xprofile"; do
    ln_s ${PWD}/${path} ~/.${path}
done

# Copy Xresources to Xdefaults for sway
ln_s ${PWD}/Xresources ~/.Xdefaults

# scripts, etc.
ln -s ${PWD}/bin ~/

# Vim temp dirs
mkdir -p ~/.vim/tmp/backup
mkdir -p ~/.vim/tmp/yankring

# Mimetypes
mkdir -p ~/.local/share/mime
ln -s mime ~/.local/share/mime/packages
update-mime-database ~/.local/share/mime

echo "Done!"
echo "Don't forget to install any necessary fonts, icons, etc."

