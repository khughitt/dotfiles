#!/bin/bash
#
# dotfiles setup script
# KH
#
DOTS_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Parse command line arguments
HEADLESS=false
UBUNTU=false
MACOS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --headless)
            HEADLESS=true
            shift
            ;;
        --ubuntu|-u)
            UBUNTU=true
            shift
            ;;
        --macos|-m)
            MACOS=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --headless        Install only non-graphical components"
            echo "  -u, --ubuntu      Configure for Ubuntu (default: Arch Linux)"
            echo "  -m, --macos       Configure for macOS with Homebrew"
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

# macOS has no Wayland/X11, so skip graphical configs
if [[ "$MACOS" == "true" ]]; then
    HEADLESS=true
fi

echo "Installing dotfiles relative to: $DOTS_HOME..."
echo "Headless mode: $HEADLESS"
echo "Ubuntu mode: $UBUNTU"
echo "macOS mode: $MACOS"

# Define package lists based on distribution
if [[ "$MACOS" == "true" ]]; then
    PACKAGES=("bat" "coreutils" "dust" "fasd" "fd" "figlet" "fzf" "gotop"
              "lolcat" "lsd" "neovim" "ripgrep" "thefuck" "tldr"
              "tmux" "tre-command" "visidata")
    FONT_PACKAGES=("font-hack-nerd-font" "font-symbols-only-nerd-font")
    PACKAGE_MANAGER="brew"
    PACKAGE_INSTALL_CMD="brew install"
    PACKAGE_UPDATE_CMD="brew update"
elif [[ "$UBUNTU" == "true" ]]; then
    PACKAGES=("bat" "fasd" "fd-find" "fzf" "lsd" "ripgrep" "thefuck" "tldr" "visidata")
    FONT_PACKAGES=("fonts-nerd-fonts" "fonts-weather-icons")
    PACKAGE_MANAGER="apt"
    PACKAGE_INSTALL_CMD="sudo apt install -y"
    PACKAGE_UPDATE_CMD="sudo apt update"
else
    PACKAGES=("bat" "dust" "fasd" "fd" "fzf" "gotop-bin" "lolcat" "lsd" "moor" "powerline" "ripgrep" "tre-command" "thefuck" "tldr" "visidata" "xan")
    FONT_PACKAGES=("ttf-nerd-fonts-symbols" "ttf-hack-nerd" "ttf-weather-icons")
    PACKAGE_MANAGER="yay"
    PACKAGE_INSTALL_CMD="yay -S"
    PACKAGE_UPDATE_CMD=""
fi

# Define configuration components
GRAPHICAL_CONFIGS=("feh" "hypr" "zathura")
COMMON_CONFIGS=("fcitx" "git" "mimeapps.list" "nvim" "lsd" "powerline" "snakemake" "termcolors" "yazi")

if [[ "$MACOS" == "true" ]]; then
    # Remove Linux-only configs
    _filtered=()
    for item in "${COMMON_CONFIGS[@]}"; do
        [[ "$item" != "fcitx" && "$item" != "mimeapps.list" ]] && _filtered+=("$item")
    done
    COMMON_CONFIGS=("${_filtered[@]}")
    unset _filtered
fi

COMMON_DOTFILES=("condarc" "ctags" "dir_colors" "plotly" "Rprofile" "Renviron" "tmux.conf" "visidatarc")

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
    local distro_name
    if [[ "$MACOS" == "true" ]]; then
        distro_name="macOS (Homebrew)"
    elif [[ "$UBUNTU" == "true" ]]; then
        distro_name="Ubuntu"
    else
        distro_name="Arch"
    fi

    echo "$distro_name packages:"
    printf '%s ' "${packages[@]}"
    echo ""
    printf '%s ' "${FONT_PACKAGES[@]}"
    echo ""

    while true; do
        read -r -p "Install $distro_name packages? [Y/n] " input
        case $input in
            [yY][eE][sS]|[yY])
                if [[ "$MACOS" == "true" ]]; then
                    echo "Installing macOS packages via Homebrew..."
                    brew update
                    brew install "${packages[@]}"
                    brew install --cask "${FONT_PACKAGES[@]}"
                elif [[ "$UBUNTU" == "true" ]]; then
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
                echo "Skipping $distro_name package installation..."
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

# noctalia plugin (only for graphical mode)
if [[ "$HEADLESS" == "false" ]]; then
    NOCTALIA_PLUGIN_DIR="${XDG_CONFIG_HOME}/noctalia/plugins"
    WALI_PANEL_PLUGIN="${NOCTALIA_PLUGIN_DIR}/wali-panel"

    mkdir -p "${NOCTALIA_PLUGIN_DIR}"

    if [ -e "${WALI_PANEL_PLUGIN}" ] && [ ! -L "${WALI_PANEL_PLUGIN}" ]; then
      mv "${WALI_PANEL_PLUGIN}" "${WALI_PANEL_PLUGIN}.bak"
    fi

    ln_s "${DOTS_HOME}/noctalia/plugins/wali-panel" "${WALI_PANEL_PLUGIN}"
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

# scripts, etc.
ln_s ${DOTS_HOME}/bin ~/

# mimetypes & fontconfig (Linux only)
if [[ "$MACOS" != "true" ]]; then
    mkdir -p ~/.local/share/mime
    ln_s ${DOTS_HOME}/mime ~/.local/share/mime/packages
    update-mime-database ~/.local/share/mime

    rm ${XDG_CONFIG_HOME}/mimeapps.list
    ln_s ${DOTS_HOME}/mimeapps.list ${XDG_CONFIG_HOME}/mimeapps.list

    mkdir -p $XDG_CONFIG_HOME/fontconfig
    ln_s ${DOTS_HOME}/fonts.conf $XDG_CONFIG_HOME/fontconfig/fonts.conf
fi

# install tpm
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

#
# external dependencies
#

install_packages "${PACKAGES[@]}"

echo "Done!"
