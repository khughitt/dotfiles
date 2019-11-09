#!/bin/bash
#
# dotfiles setup script
# KH (nov.19)
#
DOTS_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Check for configuration directory
if [ -z $XDG_CONFIG_HOME ]; then
    XDG_CONFIG_HOME=$HOME/.config
fi
mkdir -p $XDG_CONFIG_HOME

# Checks for file or directory and creates a sym link if it doesn't already exist
function ln_s() {
    echo "[CREATING] \"$2\""
    ln -sf $1 $2
}

# Linuxbrew
#echo "Installing Homebrew..." && sleep 5
#sh -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)"

# install tre (requires `brew vendor-install ruby` to be run, first)
#brew install dduan/formulae/tre

# others
#echo "Installing Cargo packages..."
#cargo install du-dust bb tldr

#echo "Installing Arch packages..."
#sudo pacman -S bat fasd fd fzf lsd thefuck visidata

#echo "Installing Arch packages (AUR)..."
#yay gotop mdcat moar

echo "Setting up dotfiles..."

# Setup zsh
ln_s ${DOTS_HOME}/zshrc ~/.zshrc
ln_s ${DOTS_HOME}/zshenv ~/.zshenv
ln_s ${DOTS_HOME}/shell ~/.shell

# Create needed directories
for dir in "compton" "gedit" "i3" "i3status" "sway" "rofi" "termite"; do
    mkdir -p ${XDG_CONFIG_HOME}/${dir}
done

# Gedit
cp -r ${DOTS_HOME}/gedit/styles ${XDG_CONFIG_HOME}/gedit/

# Gtk 3.0
if [ ! -e ${XDG_CONFIG_HOME}/gtk-3.0/ ]; then
    mkdir ${XDG_CONFIG_HOME}/gtk-3.0/
fi
ln -sf ${DOTS_HOME}/gtkrc-3.0 ${XDG_CONFIG_HOME}/gtk-3.0/settings.ini
ln -sf ${DOTS_HOME}/gtk.css ${XDG_CONFIG_HOME}/gtk-3.0/gtk.css

# ~/.config/xx
for path in "awesome" "cava" "feh" "mimeapps.list" "redshift.conf"  \
            "labnote" "pylintrc" "ranger" "termcolors"; do
    ln_s ${DOTS_HOME}/${path} ${XDG_CONFIG_HOME}/${path}
done

# ~/.xx
for path in "agignore" "ansiweatherrc" "ctags" "dir_colors" "gitconfig" \
            "gitignore_global" "Rprofile" "Renviron" "tmux" "tmux.conf" \
            "vim" "vimrc" "visidatarc" "xinitrc" "xmodmaprc" "Xresources" \
	        "xprofile"; do
    ln_s ${DOTS_HOME}/${path} ~/.${path}
done

# julia
mkdir -p ${HOME}/.julia/config
ln_s ${DOTS_HOME}/$julia/startup.jl ${HOME}/.julia/config/startup.jl

# ~/.config/xx/config
for path in "sway" "rofi" "termite"; do
    ln_s ${DOTS_HOME}/${path} ${XDG_CONFIG_HOME}/${path}/config
done

# i3, i3status
ln_s ${DOTS_HOME}/i3/config ${XDG_CONFIG_HOME}/i3/config
ln_s ${DOTS_HOME}/i3/i3status.left ${XDG_CONFIG_HOME}/i3status/config.left
ln_s ${DOTS_HOME}/i3/i3status.right ${XDG_CONFIG_HOME}/i3status/config.right

mkdir -p ~/.cache/i3

# compton
ln -sf ${DOTS_HOME}/compton.conf ${XDG_CONFIG_HOME}/compton/compton.conf

# copy Xresources to Xdefaults for sway
ln_s ${DOTS_HOME}/Xresources ~/.Xdefaults

# scripts, etc.
ln -sf ${DOTS_HOME}/bin ~/

# Vim temp dirs
mkdir -p ~/.vim/tmp/backup
mkdir -p ~/.vim/tmp/yankring

# Mimetypes
mkdir -p ~/.local/share/mime
ln -sf ${DOTS_HOME}/mime ~/.local/share/mime/packages
update-mime-database ~/.local/share/mime

ln_s ${DOTS_HOME}/mimeapps.list ${XDG_CONFIG_HOME}/mimeapps.list

echo "Done!"
echo "Don't forget to install any necessary fonts, icons, etc."

