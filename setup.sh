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

# Everything else
for path in "dir_colors" "gitconfig" "gitignore_global" \
            "Rprofile" "Renviron" "tmux" "tmux.conf" \
            "vim" "vimrc" "xinitrc" "xmodmaprc" "Xresources"; do
    ln_s ${PWD}/${path} ~/.${path}
done

# scripts, etc.
ln -s ${PWD}/bin ~/

# Vim temp dirs
mkdir -p ~/.vim/tmp/backup
mkdir -p ~/.vim/tmp/yankring

echo "Done!"
echo "Don't forget to install any necessary fonts, icons, etc."

