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

# Create needed directories
for dir in "compton" "gedit" "i3" "i3status" "sway" "termite"; do
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

ln -s /home/keith/d/dots/gtkrc-2.0 ~/.gtkrc-2.0

# ~/.config/xx
for path in "awesome" "cava" "dunst" "feh" "git" "mimeapps.list" "nvim" "redshift.conf"  \
            "labnote" "polybar" "powerline" "pylintrc" "ranger" "snakemake" "spicetify" \
            "termcolors" "wal" "zathura"; do
    ln_s ${DOTS_HOME}/${path} ${XDG_CONFIG_HOME}/${path}
done

# ~/.xx
for path in "agignore" "ansiweatherrc" "ctags" "dir_colors"  \
            "Rprofile" "Renviron" "tmux" "tmux.conf" \
            "vim" "vimrc" "visidatarc" "xinitrc" "xmodmaprc" "Xresources" \
            "condarc" "xprofile"; do
    ln_s ${DOTS_HOME}/${path} ~/.${path}
done

# git
ln_s ${DOTS_HOME}/git/ignore ${HOME}/.gitignore_global
ln_s ${DOTS_HOME}/git/config ${HOME}/.gitconfig

# julia
mkdir -p ${HOME}/.julia/config
ln_s ${DOTS_HOME}/$julia/startup.jl ${HOME}/.julia/config/startup.jl

# ~/.config/xx/config
for path in "sway" "rofi" "termite"; do
    ln_s ${DOTS_HOME}/${path} ${XDG_CONFIG_HOME}/${path}/config
done

# i3
ln_s ${DOTS_HOME}/i3/config ${XDG_CONFIG_HOME}/i3/config
ln_s ${DOTS_HOME}/i3/i3status.left ${XDG_CONFIG_HOME}/i3status/config.left
ln_s ${DOTS_HOME}/i3/i3status.right ${XDG_CONFIG_HOME}/i3status/config.right

mkdir -p ~/.cache/i3

# picom
mkdir -p ${XDG_CONFIG_HOME}/picom
ln -sf ${DOTS_HOME}/picom ${XDG_CONFIG_HOME}/picom/picom.conf

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

rm ${XDG_CONFIG_HOME}/mimeapps.list
ln_s ${DOTS_HOME}/mimeapps.list ${XDG_CONFIG_HOME}/mimeapps.list

#
# external dependencies
#

# arch
echo "Arch packages:"
echo "bat fasd fd fzf gotop lsd moar powerline ripgrep thefuck tldr visidata"
echo "polybar nerd-fonts-complete ttf-weather-icons"

while true
do
    read -r -p "Install Arch packages? [Y/n] " input
    case $input in
        [yY][eE][sS]|[yY])
            # install yay
            echo "Installing yay AUR helper..."

            cd /tmp
            git clone https://aur.archlinux.org/yay.git
            cd yay
            makepkg -si
            cd -

            echo "Finished installing yay..."

            # install arch packages
            echo "Installing Arch packages..."
            yay -S bat fasd fd fzf gotop-bin lsd moar spicetify-cli thefuck visidata \
                   powerline ripgrep tldr polybar nerd-fonts-complete ttf-weather-icons
            ;;
       [nN][oO]|[nN])
            echo "Skipping Arch package installation..."
            break
            ;;
        *)
            echo "Invalid input..."
            ;;
    esac
done

# echo 'Installing python packages...'
# pip install --user colorz
# pip install --user haishoku
# pip install --user colorthief

# others
#echo "Installing Cargo packages..."
#cargo install du-dust bb tldr

echo "Done!"
echo "Don't forget to install any necessary fonts, icons, etc."

