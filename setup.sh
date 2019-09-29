#!/bin/bash

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

# Setup zsh
ln_s ${PWD}/zshrc ~/.zshrc
ln_s ${PWD}/zenv ~/.zenv
ln_s ${PWD}/shell ~/.shell

# Create needed directories
for dir in "compton" "gedit" "i3" "i3status" "sway" "rofi" "termite"; do
    mkdir -p ${XDG_CONFIG_HOME}/${dir}
done

# Gedit
cp -r ${PWD}/gedit/styles ${XDG_CONFIG_HOME}/gedit/

# Gtk 3.0
if [ ! -e ${XDG_CONFIG_HOME}/gtk-3.0/ ]; then
    mkdir ${XDG_CONFIG_HOME}/gtk-3.0/
fi
ln -s ${PWD}/gtkrc-3.0 ${XDG_CONFIG_HOME}/gtk-3.0/settings.ini
ln -s ${PWD}/gtk.css ${XDG_CONFIG_HOME}/gtk-3.0/gtk.css

# ~/.config/xx
for path in "termcolors" "cava" "mimeapps.list" "redshift.conf"  \
            "labnote" "pylintrc" "ranger"; do
    ln_s ${PWD}/${path} ${XDG_CONFIG_HOME}/${path}
done

# ~/.xx
for path in "agignore" "ansiweatherrc" "ctags" "dir_colors" "gitconfig" \
            "gitignore_global" "Rprofile" "Renviron" "tmux" "tmux.conf" \
            "vim" "vimrc" "visidatarc" "xinitrc" "xmodmaprc" "Xresources" \
	        "xprofile"; do
    ln_s ${PWD}/${path} ~/.${path}
done

# ~/.config/xx/config
for path in "sway" "rofi" "termite"; do
    ln_s ${PWD}/${path} ${XDG_CONFIG_HOME}/${path}/config
done

# i3, i3status
ln_s ${PWD}/i3/config ${XDG_CONFIG_HOME}/i3/config
ln_s ${PWD}/i3/i3status.left ${XDG_CONFIG_HOME}/i3status/config.left
ln_s ${PWD}/i3/i3status.right ${XDG_CONFIG_HOME}/i3status/config.right

mkdir -p ~/.cache/i3

# compton
ln -s ${PWD}/compton.conf ${XDG_CONFIG_HOME}/compton/compton.conf

# copy Xresources to Xdefaults for sway
ln_s ${PWD}/Xresources ~/.Xdefaults

# scripts, etc.
ln -s ${PWD}/bin ~/

# Vim temp dirs
mkdir -p ~/.vim/tmp/backup
mkdir -p ~/.vim/tmp/yankring

# Mimetypes
mkdir -p ~/.local/share/mime
ln -s ${PWD}/mime ~/.local/share/mime/packages
update-mime-database ~/.local/share/mime

ln_s ${PWD}/mimeapps.list ${XDG_CONFIG_HOME}/mimeapps.list

echo "Done!"
echo "Don't forget to install any necessary fonts, icons, etc."

