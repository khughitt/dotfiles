#!/bin/bash
#
# dotfiles setup script
# KH
#
DOTS_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "Installing dotfiles relative to: $DOTS_HOME..."

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

# Create completions cache dir
mkdir -p $HOME/.cache/zinit/completions

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
for x in "compton" "i3" "rofi" "wal"; do
    mkdir -p ${XDG_CONFIG_HOME}/${x}
done

# Gtk 3.0
if [ ! -e ${XDG_CONFIG_HOME}/gtk-3.0/ ]; then
    mkdir ${XDG_CONFIG_HOME}/gtk-3.0/
fi
ln_s ${DOTS_HOME}/gtk-3.0/settings.ini ${XDG_CONFIG_HOME}/gtk-3.0/settings.ini
ln_s ${DOTS_HOME}/gtk-3.0/gtk.css ${XDG_CONFIG_HOME}/gtk-3.0/gtk.css

# Gtk 4.0
if [ ! -e ${XDG_CONFIG_HOME}/gtk-4.0/ ]; then
    mkdir ${XDG_CONFIG_HOME}/gtk-4.0/
fi
ln_s ${DOTS_HOME}/gtk-4.0/settings.ini ${XDG_CONFIG_HOME}/gtk-4.0/settings.ini
ln_s ${DOTS_HOME}/gtk-4.0/gtk.css ${XDG_CONFIG_HOME}/gtk-4.0/gtk.css


# ~/.config/xx
for path in "dunst" "fcitx" "feh" "git" "mimeapps.list" "nvim" "redshift.conf"  \
            "labnote" "lsd" "polybar" "powerline" "snakemake" \
            "picom.conf" "sway" "termcolors" "zathura" "zeit"; do
    ln_s ${DOTS_HOME}/${path} ${XDG_CONFIG_HOME}/${path}
done

# ~/.xx
for path in "cookiecutterrc" "ctags" "dir_colors"  \
            "plotly" "Rprofile" "Renviron" "tmux.conf" \
            "vim" "vimrc" "visidatarc" "xinitrc" "Xmodmap" "Xresources" \
            "condarc" "xprofile"; do
    ln_s ${DOTS_HOME}/${path} ~/.${path}
done

# ghci
mkdir -p ${HOME}/.ghc
ln_s ${DOTS_HOME}/ghci.conf ${HOME}/.ghc/ghci.conf

# gimp
GIMP_DIR="${XDG_CONFIG_HOME}/GIMP/3.0"
GIMP_PLUGIN_DIR="${XDG_CONFIG_HOME}/GIMP/3.0/plug-ins"

GIMPRC="${GIMP_DIR}/gimprc"

mdir -p "${GIMP_DIR}"

if [ -e $GIMPRC ]; then
  mv $GIMPRC $GIMPRC.bak
fi
if [ -e $GIMP_PLUGIN_DIR ]; then
  mv $GIMP_PLUGIN_DIR $GIMP_PLUGIN_DIR.bak
fi

ln -s "${DOTS_HOME}/gimp/gimprc" $GIMPRC 
ln -s "${DOTS_HOME}/gimp/plug-ins" $GIMP_PLUGIN_DIR

# git
ln_s ${DOTS_HOME}/git/ignore ${HOME}/.gitignore_global
ln_s ${DOTS_HOME}/git/config ${HOME}/.gitconfig

# julia
mkdir -p ${HOME}/.julia/config
ln_s ${DOTS_HOME}/$julia/startup.jl ${HOME}/.julia/config/startup.jl

# jupyter
mkdir -p ${HOME}/.jupyter
ln_s ${DOTS_HOME}/jupyter/jupyter_qtconsole_config.py ${HOME}/.jupyter/jupyter_qtconsole_config.py

# mamba
ln_s ${DOTS_HOME}/condarc ${HOME}/.mambarc

# r
ln_s ${DOTS_HOME}/lintr ${HOME}/.lintr

# ripgrep
ln_s ${DOTS_HOME}/rgignore ${HOME}/.rgignore

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

# to install pywal alt color algorithms:
# pip install --user colorz haishoku colorthief

# create i3 and sway log dirs
mkdir -p ~/.cache/i3
mkdir -p ~/.cache/sway

# create pomodoro cache

# symlink Xresources to Xdefaults for sway
ln_s ${DOTS_HOME}/Xresources ~/.Xdefaults

# scripts, etc.
ln_s ${DOTS_HOME}/bin ~/

# create vim backup dir
mkdir -p ~/.vim/tmp/backup

# mimetypes
mkdir -p ~/.local/share/mime
ln_s ${DOTS_HOME}/mime ~/.local/share/mime/packages
update-mime-database ~/.local/share/mime

rm ${XDG_CONFIG_HOME}/mimeapps.list
ln_s ${DOTS_HOME}/mimeapps.list ${XDG_CONFIG_HOME}/mimeapps.list

# fontconfig
mkdir -p $XDG_CONFIG_HOME/fontconfig
ln_s ${DOTS_HOME}/fonts.conf $XDG_CONFIG_HOME/fontconfig/fonts.conf

# install tpm
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

#
# external dependencies
#

# arch
echo "Arch packages:"
echo "bat fasd fd fzf gotop-bin lsd moar powerline ripgrep thefuck tk tldr visidata"
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
            yay -S bat dust fasd fd fzf gotop-bin lsd moar visidata powerline ripgrep polybar \
                   tre-command ttf-nerd-fonts-symbols ttf-hack-nerd ttf-weather-icons
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

echo "Done!"
