#!/bin/bash
#
# dotfiles setup script
# KH
#
DOTS_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Parse command line arguments
HEADLESS=false
UBUNTU=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --headless|-h)
            HEADLESS=true
            shift
            ;;
        --ubuntu|-u)
            UBUNTU=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -h, --headless    Install only non-graphical components"
            echo "  -u, --ubuntu      Configure for Ubuntu (default: Arch Linux)"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "Installing dotfiles relative to: $DOTS_HOME..."
echo "Headless mode: $HEADLESS"
echo "Ubuntu mode: $UBUNTU"

# Define package lists based on distribution
if [[ "$UBUNTU" == "true" ]]; then
    PACKAGES=("bat" "fasd" "fd-find" "fzf" "lsd" "ripgrep" "thefuck" "tk" "tldr" "visidata")
    FONT_PACKAGES=("fonts-nerd-fonts" "fonts-weather-icons")
    PACKAGE_MANAGER="apt"
    PACKAGE_INSTALL_CMD="sudo apt install -y"
    PACKAGE_UPDATE_CMD="sudo apt update"
else
    PACKAGES=("bat" "dust" "fasd" "fd" "fzf" "gotop-bin" "lsd" "moar" "powerline" "ripgrep" "tre-command" "thefuck" "tk" "tldr" "visidata")
    FONT_PACKAGES=("ttf-nerd-fonts-symbols" "ttf-hack-nerd" "ttf-weather-icons")
    PACKAGE_MANAGER="yay"
    PACKAGE_INSTALL_CMD="yay -S"
    PACKAGE_UPDATE_CMD=""
fi

# Add polybar to packages if not headless
if [[ "$HEADLESS" == "false" ]]; then
    PACKAGES+=("polybar")
fi

# Define configuration components
GRAPHICAL_CONFIGS=("dunst" "feh" "picom.conf" "polybar" "sway" "wal" "zathura")
COMMON_CONFIGS=("fcitx" "git" "mimeapps.list" "nvim" "redshift.conf" "labnote" "lsd" "powerline" "snakemake" "termcolors" "zeit")

GRAPHICAL_DOTFILES=("xinitrc" "Xmodmap" "Xresources" "xprofile")
COMMON_DOTFILES=("cookiecutterrc" "ctags" "dir_colors" "plotly" "Rprofile" "Renviron" "tmux.conf" "vim" "vimrc" "visidatarc" "condarc")

# Determine resolution to use (only for graphical mode)
HIRES=""

if [[ "$HEADLESS" == "false" ]]; then
    while [[ "$HIRES" != "n" && "$HIRES" != "y" ]]; do
        read -r -p "Configure system for 4k display? [y|N] " HIRES
        HIRES="${HIRES,,}"

        if [[ "$HIRES" == "" ]]; then
            HIRES="n"
        fi
    done
else
    HIRES="n"
fi

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

# Function to install packages
function install_packages() {
    local packages=("$@")
    
    echo "${UBUNTU:+Ubuntu}${UBUNTU:+ }${UBUNTU:-Arch} packages:"
    printf '%s ' "${packages[@]}"
    echo ""
    printf '%s ' "${FONT_PACKAGES[@]}"
    echo ""

    while true; do
        read -r -p "Install ${UBUNTU:+Ubuntu}${UBUNTU:+ }${UBUNTU:-Arch} packages? [Y/n] " input
        case $input in
            [yY][eE][sS]|[yY])
                if [[ "$UBUNTU" == "true" ]]; then
                    echo "Installing Ubuntu packages..."
                    $PACKAGE_UPDATE_CMD
                    $PACKAGE_INSTALL_CMD "${packages[@]}"
                    $PACKAGE_INSTALL_CMD "${FONT_PACKAGES[@]}"
                else
                    echo "Installing yay AUR helper..."
                    cd /tmp
                    git clone https://aur.archlinux.org/yay.git
                    cd yay
                    makepkg -si
                    cd -
                    echo "Finished installing yay..."
                    echo "Installing Arch packages..."
                    $PACKAGE_INSTALL_CMD "${packages[@]}"
                    $PACKAGE_INSTALL_CMD "${FONT_PACKAGES[@]}"
                fi
                break
                ;;
            [nN][oO]|[nN])
                echo "Skipping ${UBUNTU:+Ubuntu}${UBUNTU:+ }${UBUNTU:-Arch} package installation..."
                break
                ;;
            *)
                echo "Invalid input..."
                ;;
        esac
    done
}

echo "Setting up dotfiles..."

# Setup zsh
ln_s ${DOTS_HOME}/zshrc ~/.zshrc
ln_s ${DOTS_HOME}/zshenv ~/.zshenv
ln_s ${DOTS_HOME}/shell ~/.shell

# Create needed directories (only for graphical mode)
if [[ "$HEADLESS" == "false" ]]; then
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
fi

# Install ~/.config components
if [[ "$HEADLESS" == "false" ]]; then
    for path in "${GRAPHICAL_CONFIGS[@]}"; do
        ln_s ${DOTS_HOME}/${path} ${XDG_CONFIG_HOME}/${path}
    done
fi

for path in "${COMMON_CONFIGS[@]}"; do
    ln_s ${DOTS_HOME}/${path} ${XDG_CONFIG_HOME}/${path}
done

# Install ~/. components
if [[ "$HEADLESS" == "false" ]]; then
    for path in "${GRAPHICAL_DOTFILES[@]}"; do
        ln_s ${DOTS_HOME}/${path} ~/.${path}
    done
fi

for path in "${COMMON_DOTFILES[@]}"; do
    ln_s ${DOTS_HOME}/${path} ~/.${path}
done

# ghci
mkdir -p ${HOME}/.ghc
ln_s ${DOTS_HOME}/ghci.conf ${HOME}/.ghc/ghci.conf

# gimp (only for graphical mode)
if [[ "$HEADLESS" == "false" ]]; then
    GIMP_DIR="${XDG_CONFIG_HOME}/GIMP/3.0"
    GIMP_PLUGIN_DIR="${XDG_CONFIG_HOME}/GIMP/3.0/plug-ins"
    GIMPRC="${GIMP_DIR}/gimprc"

    mkdir -p "${GIMP_DIR}"

    if [ -e $GIMPRC ]; then
      mv $GIMPRC $GIMPRC.bak
    fi
    if [ -e $GIMP_PLUGIN_DIR ]; then
      mv $GIMP_PLUGIN_DIR $GIMP_PLUGIN_DIR.bak
    fi

    ln -s "${DOTS_HOME}/gimp/gimprc" $GIMPRC 
    ln -s "${DOTS_HOME}/gimp/plug-ins" $GIMP_PLUGIN_DIR
fi

# git
ln_s ${DOTS_HOME}/git/ignore ${HOME}/.gitignore_global
ln_s ${DOTS_HOME}/git/config ${HOME}/.gitconfig

# julia
mkdir -p ${HOME}/.julia/config
ln_s ${DOTS_HOME}/julia/startup.jl ${HOME}/.julia/config/startup.jl

# jupyter
mkdir -p ${HOME}/.jupyter
ln_s ${DOTS_HOME}/jupyter/jupyter_qtconsole_config.py ${HOME}/.jupyter/jupyter_qtconsole_config.py

# mamba
ln_s ${DOTS_HOME}/condarc ${HOME}/.mambarc

# r
ln_s ${DOTS_HOME}/lintr ${HOME}/.lintr

# ripgrep
ln_s ${DOTS_HOME}/rgignore ${HOME}/.rgignore

# 4k configs (i3, rofi, wal) - only for graphical mode
if [[ "$HEADLESS" == "false" ]]; then
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

    # symlink Xresources to Xdefaults for sway
    ln_s ${DOTS_HOME}/Xresources ~/.Xdefaults
fi

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

install_packages "${PACKAGES[@]}"

echo "Done!"
