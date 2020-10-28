#!/bin/bash
#
# dotfiles setup script
# KH (nov.19)
#
DOTS_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Determine resolution to use
HIRES=""

while [[ "$HIRES" != "n" && "$HIRES" != "y" ]]; do
    read -r -p "Configure system for 4k display? [y|N] " HIRES
    HIRES="${HIRES,,}"

    if [[ "$HIRES" == "" ]]; then
        HIRES="n"
    fi
done

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
for x in "compton" "gedit" "i3" "rofi" "sway" "wal"; do
    mkdir -p ${XDG_CONFIG_HOME}/${x}
done

# Gedit
cp -r ${DOTS_HOME}/gedit/styles ${XDG_CONFIG_HOME}/gedit/

# Gtk 3.0
if [ ! -e ${XDG_CONFIG_HOME}/gtk-3.0/ ]; then
    mkdir ${XDG_CONFIG_HOME}/gtk-3.0/
fi
ln_s ${DOTS_HOME}/gtkrc-3.0 ${XDG_CONFIG_HOME}/gtk-3.0/settings.ini
ln_s ${DOTS_HOME}/gtk.css ${XDG_CONFIG_HOME}/gtk-3.0/gtk.css

ln_s ${DOTS_HOME}/gtkrc-2.0 ~/.gtkrc-2.0

# ~/.config/xx
for path in "awesome" "dunst" "feh" "git" "mimeapps.list" "nvim" "redshift.conf"  \
            "labnote" "polybar" "powerline" "pylintrc" "ranger" "snakemake" "spicetify" \
            "termcolors" "termite" "zathura"; do
    ln_s ${DOTS_HOME}/${path} ${XDG_CONFIG_HOME}/${path}
done

# ~/.xx
for path in "agignore" "ansiweatherrc" "cookiecutterrc" "ctags" "dir_colors"  \
            "picom.conf" "plotly" "Rprofile" "Renviron" "tmux" "tmux.conf" \
            "vim" "vimrc" "visidatarc" "xinitrc" "Xmodmap" "Xresources" \
            "taskrc" "condarc" "xprofile"; do
    ln_s ${DOTS_HOME}/${path} ~/.${path}
done

# git
ln_s ${DOTS_HOME}/git/ignore ${HOME}/.gitignore_global
ln_s ${DOTS_HOME}/git/config ${HOME}/.gitconfig

# julia
mkdir -p ${HOME}/.julia/config
ln_s ${DOTS_HOME}/$julia/startup.jl ${HOME}/.julia/config/startup.jl

# ~/.config/xx/config
for path in "sway"; do
    ln_s ${DOTS_HOME}/${path} ${XDG_CONFIG_HOME}/${path}/config
done

# 4k configs (i3, rofi, wal )
if [[ "$HIRES" == "y" ]]; then
    ln_s ${DOTS_HOME}/i3/config.4k ${XDG_CONFIG_HOME}/i3/config
    ln_s ${DOTS_HOME}/rofi/config.4k.rasi ${XDG_CONFIG_HOME}/rofi/config.rasi
    ln_s ${DOTS_HOME}/wal/templates.4k ${XDG_CONFIG_HOME}/wal/templates
else
    ln_s ${DOTS_HOME}/i3/config ${XDG_CONFIG_HOME}/i3/config
    ln_s ${DOTS_HOME}/rofi/config.rasi ${XDG_CONFIG_HOME}/rofi/config.rasi
    ln_s ${DOTS_HOME}/wal/templates ${XDG_CONFIG_HOME}/wal/templates
fi

# wal colorscheme
ln_s ${DOTS_HOME}/wal/colorschemes ${XDG_CONFIG_HOME}/wal/colorschemes

# create i3 log dir
mkdir -p ~/.cache/i3

# copy Xresources to Xdefaults for sway
ln_s ${DOTS_HOME}/Xresources ~/.Xdefaults

# scripts, etc.
ln_s ${DOTS_HOME}/bin ~/

# Vim temp dirs
mkdir -p ~/.vim/tmp/backup
mkdir -p ~/.vim/tmp/yankring

# Mimetypes
mkdir -p ~/.local/share/mime
ln_s ${DOTS_HOME}/mime ~/.local/share/mime/packages
update-mime-database ~/.local/share/mime

rm ${XDG_CONFIG_HOME}/mimeapps.list
ln_s ${DOTS_HOME}/mimeapps.list ${XDG_CONFIG_HOME}/mimeapps.list

# Fontconfig
mkdir -p $XDG_CONFIG_HOME/fontconfig
ln_s ${DOTS_HOME}/fonts.conf $XDG_CONFIG_HOME/fontconfig/fonts.conf

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

