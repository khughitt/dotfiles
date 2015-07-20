#!/bin/bash

# Choose shell
read -p "Select a shell to use [bash/zsh]: " SH
if [ "$SH" != "bash" ] && [ "$SH" != "zsh" ]; then
    echo "Invalid choice. Exiting..."
    exit;
fi

# X11
read -p "Install GUI dot files? [yes/no]: " GUI
if [ "$GUI" != "yes" ] && [ "$GUI" != "no" ]; then
    echo "Invalid choice. Exiting..."
    exit;
fi

# Check for configuration directory
if [ -z $XDG_CONFIG_HOME ]; then
    XDG_CONFIG_HOME=$HOME/.config
fi
mkdir -p $XDG_CONFIG_HOME

# Checks for file or directory and creates a sym link if it 
# doesn't already exist
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

# Terminator
#if [ ! -e ~/.config/terminator ]; then
#    mkdir -p ~/.config/terminator
#fi
#ln_s ${PWD}/terminator ~/.config/terminator/config

# IPython
#if [ ! -e $XDG_CONFIG_HOME/ipython ] and ipython -v 2>/dev/null; then
#    ipython profile create
#
#    for filepath in ${PWD}/ipython/*; do
#        $DEST=$XDG_CONFIG_HOME/ipython/profile_default/${filename}
#        if [ -e $DEST ]; then
#            rm -r $DEST
#            ln_s ${filepath} $DEST
#        fi
#    done
#
#    # Todo: update default color scheme to Linux
#else
#    echo "[SKIPPING] Ipython (already exists...)"
#fi

# Awesome
ln_s ${PWD}/awesome ${XDG_CONFIG_HOME}/awesome

# Gedit
cp -r ${PWD}/gedit/styles ${XDG_CONFIG_HOME}/gedit/

# Gtk 3.0
if [ ! -e ${XDG_CONFIG_HOME}/gtk-3.0/ ]; then
    mkdir ${XDG_CONFIG_HOME}/gtk-3.0/
fi
ln -s ${PWD}/gtkrc-3.0 ${XDG_CONFIG_HOME}/gtk-3.0/settings.ini

# Xresources themes
ln -s ${PWD}/termcolors ${XDG_CONFIG_HOME}/

# Byobu
#ln -s ${PWD}/byobu/keybindings.tmux ~/.byobu/

# Everything else
for path in "dir_colors" "gitconfig" "gitignore_global" \
            "Rprofile" "Renviron" "tmux.conf" \
            "vim" "vimrc" "xinitrc" "xmodmaprc" "Xresources"; do
    ln_s ${PWD}/${path} ~/.${path}
done

echo "Done!"
echo "Don't forget to install any necessary fonts, icons, etc."

