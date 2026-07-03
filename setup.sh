#!/bin/bash
#
# dotfiles setup script
# KH
#
set -euo pipefail

DOTS_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Parse command line arguments
HEADLESS=false
UBUNTU=false
MACOS=false
DRY_RUN=false
LINK_ONLY=false
SKIP_PACKAGES=false
SKIP_EXTERNAL_CLONES=false
ENABLE_USER_TIMERS=false

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
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --link-only)
            LINK_ONLY=true
            SKIP_PACKAGES=true
            SKIP_EXTERNAL_CLONES=true
            shift
            ;;
        --no-packages)
            SKIP_PACKAGES=true
            shift
            ;;
        --no-external-clones)
            SKIP_EXTERNAL_CLONES=true
            shift
            ;;
        --enable-user-timers)
            ENABLE_USER_TIMERS=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --headless        Install only non-graphical components"
            echo "  -u, --ubuntu      Configure for Ubuntu (default: Arch Linux)"
            echo "  -m, --macos       Configure for macOS with Homebrew"
            echo "  --dry-run         Print planned filesystem and command actions without running them"
            echo "  --link-only       Link dotfiles only; skip package installation and external clones"
            echo "  --no-packages     Skip package installation"
            echo "  --no-external-clones"
            echo "                    Skip cloning external tools such as zinit and tmux TPM"
            echo "  --enable-user-timers"
            echo "                    Enable linked systemd user timers on Linux"
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
echo "Dry run: $DRY_RUN"
echo "Link only: $LINK_ONLY"
echo "Skip packages: $SKIP_PACKAGES"
echo "Skip external clones: $SKIP_EXTERNAL_CLONES"
echo "Enable user timers: $ENABLE_USER_TIMERS"

# Define package lists based on distribution
if [[ "$MACOS" == "true" ]]; then
    PACKAGES=("bat" "coreutils" "dust" "fd" "figlet" "fzf" "gotop"
              "lolcat" "lsd" "neovim" "ripgrep" "thefuck" "tldr"
              "tmux" "tre-command" "visidata" "zoxide")
    FONT_PACKAGES=("font-hack-nerd-font" "font-symbols-only-nerd-font")
    PACKAGE_INSTALL_CMD="brew install"
    PACKAGE_UPDATE_CMD="brew update"
elif [[ "$UBUNTU" == "true" ]]; then
    PACKAGES=("bat" "fd-find" "fzf" "lsd" "ripgrep" "thefuck" "tldr" "visidata" "zoxide")
    FONT_PACKAGES=("fonts-nerd-fonts" "fonts-weather-icons")
    PACKAGE_INSTALL_CMD="sudo apt install -y"
    PACKAGE_UPDATE_CMD="sudo apt update"
else
    PACKAGES=("bat" "dust" "fd" "fzf" "glow" "gotop-bin" "lolcat" "lsd" "moor" "ripgrep" "tre-command" "thefuck" "tldr" "visidata" "xan" "zoxide")
    FONT_PACKAGES=("ttf-nerd-fonts-symbols" "ttf-hack-nerd" "ttf-weather-icons")
    PACKAGE_INSTALL_CMD="yay -S"
    PACKAGE_UPDATE_CMD=""
fi

# Define configuration components
GRAPHICAL_CONFIGS=("feh" "hypr" "niri" "zathura")
COMMON_CONFIGS=("fcitx" "git" "glow" "kitty" "mimeapps.list" "nvim" "lsd" "termcolors" "yazi")

if [[ "$MACOS" == "true" ]]; then
    # Remove Linux-only configs
    _filtered=()
    for item in "${COMMON_CONFIGS[@]}"; do
        [[ "$item" != "fcitx" && "$item" != "mimeapps.list" ]] && _filtered+=("$item")
    done
    COMMON_CONFIGS=("${_filtered[@]}")
    unset _filtered
fi

COMMON_DOTFILES=("condarc" "ctags" "plotly" "Rprofile" "Renviron" "tmux.conf" "visidatarc")

# Check for configuration directory
if [ -z "${XDG_CONFIG_HOME:-}" ]; then
    XDG_CONFIG_HOME=$HOME/.config
fi

function describe_cmd() {
    printf '%q ' "$@"
    echo ""
}

function run() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] $(describe_cmd "$@")"
    else
        "$@"
    fi
}

function ensure_dir() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        return
    fi
    run mkdir -p "$dir"
}

ensure_dir "$XDG_CONFIG_HOME"

if [[ "$SKIP_EXTERNAL_CLONES" != "true" ]]; then
    # Create completions cache dir
    ensure_dir "$HOME/.cache/zinit/completions"

    # Install zinit outside shell startup.
    ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
    if [[ ! -d "$ZINIT_HOME/.git" ]]; then
        ensure_dir "$(dirname "$ZINIT_HOME")"
        run git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
    fi
else
    echo "Skipping external clone setup..."
fi

# Checks for file or directory and creates a sym link if it doesn't already exist
function ln_s() {
    # Existing symlinks are replaced; a real file/dir is moved aside to .bak so
    # we never nest a link inside it (e.g. an app-generated ~/.config/kitty) or
    # clobber real data.
    local src="$1"
    local dest="$2"

    if [[ ! -e "$src" ]]; then
        echo "Link source does not exist: $src"
        exit 1
    fi

    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
        echo "[SKIPPING] \"$dest\" already points to \"$src\""
        return
    fi

    ensure_dir "$(dirname "$dest")"

    if [[ -e "$dest" && ! -L "$dest" && -e "${dest}.bak" ]]; then
        echo "Refusing to overwrite existing backup: ${dest}.bak"
        exit 1
    fi

    if [[ -L "$2" ]]; then
        run rm "$dest"
    elif [[ -e "$2" ]]; then
        echo "[BACKUP] \"$dest\" -> \"$dest.bak\""
        run mv "$dest" "$dest.bak"
    fi
    echo "[CREATING] \"$dest\""
    run ln -sf "$src" "$dest"
}

# Function to install packages
function install_packages() {
    if [[ "$SKIP_PACKAGES" == "true" ]]; then
        echo "Skipping package installation..."
        return
    fi

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
                    run brew update
                    run brew install "${packages[@]}"
                    run brew install --cask "${FONT_PACKAGES[@]}"
                elif [[ "$UBUNTU" == "true" ]]; then
                    echo "Installing Ubuntu packages..."
                    if [[ -n "$PACKAGE_UPDATE_CMD" ]]; then
                        # shellcheck disable=SC2086
                        run $PACKAGE_UPDATE_CMD
                    fi
                    # shellcheck disable=SC2086
                    run $PACKAGE_INSTALL_CMD "${packages[@]}"
                    # shellcheck disable=SC2086
                    run $PACKAGE_INSTALL_CMD "${FONT_PACKAGES[@]}"
                else
                    if [[ ! -x "/usr/bin/yay" && ! -x "$HOME/.local/bin/yay" ]]; then
                        echo "Installing yay AUR helper..."
                        local cwd
                        cwd="$(pwd)"
                        run git clone https://aur.archlinux.org/yay.git /tmp/yay
                        if [[ "$DRY_RUN" != "true" ]]; then
                            cd /tmp/yay
                            run makepkg -si
                            cd "$cwd"
                        fi
                        echo "Finished installing yay..."
                    fi
                    echo "Installing Arch packages..."
                    # shellcheck disable=SC2086
                    run $PACKAGE_INSTALL_CMD "${packages[@]}"
                    # shellcheck disable=SC2086
                    run $PACKAGE_INSTALL_CMD "${FONT_PACKAGES[@]}"
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
ln_s "${DOTS_HOME}/zshrc" "${HOME}/.zshrc"
ln_s "${DOTS_HOME}/zshenv" "${HOME}/.zshenv"
ln_s "${DOTS_HOME}/shell" "${HOME}/.shell"

# Create needed directories (only for graphical mode)
if [[ "$HEADLESS" == "false" ]]; then
    # Gtk 3.0
    ensure_dir "${XDG_CONFIG_HOME}/gtk-3.0"
    ln_s "${DOTS_HOME}/gtk-3.0/settings.ini" "${XDG_CONFIG_HOME}/gtk-3.0/settings.ini"
    ln_s "${DOTS_HOME}/gtk-3.0/gtk.css" "${XDG_CONFIG_HOME}/gtk-3.0/gtk.css"

    # Gtk 4.0
    ensure_dir "${XDG_CONFIG_HOME}/gtk-4.0"
    ln_s "${DOTS_HOME}/gtk-4.0/settings.ini" "${XDG_CONFIG_HOME}/gtk-4.0/settings.ini"
    ln_s "${DOTS_HOME}/gtk-4.0/gtk.css" "${XDG_CONFIG_HOME}/gtk-4.0/gtk.css"
fi

# Install ~/.config components
if [[ "$HEADLESS" == "false" ]]; then
    for path in "${GRAPHICAL_CONFIGS[@]}"; do
        if [[ "$path" == "niri" && -e "${XDG_CONFIG_HOME}/${path}" && ! -L "${XDG_CONFIG_HOME}/${path}" ]]; then
            if [ -e "${XDG_CONFIG_HOME}/${path}.bak" ]; then
                echo "Refusing to overwrite existing ${XDG_CONFIG_HOME}/${path}.bak"
                exit 1
            fi
            run mv "${XDG_CONFIG_HOME}/${path}" "${XDG_CONFIG_HOME}/${path}.bak"
        fi
        ln_s "${DOTS_HOME}/${path}" "${XDG_CONFIG_HOME}/${path}"
    done

    if [[ "$DRY_RUN" != "true" && -x "${XDG_CONFIG_HOME}/niri/host_specific.sh" ]]; then
        "${XDG_CONFIG_HOME}/niri/host_specific.sh"
    fi
fi

for path in "${COMMON_CONFIGS[@]}"; do
    ln_s "${DOTS_HOME}/${path}" "${XDG_CONFIG_HOME}/${path}"
done

# systemd user units (Linux only). Link individual units instead of replacing
# ~/.config/systemd, which may contain host-local services.
if [[ "$MACOS" != "true" ]]; then
    ensure_dir "${XDG_CONFIG_HOME}/systemd/user"
    ln_s "${DOTS_HOME}/systemd/user/dropbox-ignore-flux.service" "${XDG_CONFIG_HOME}/systemd/user/dropbox-ignore-flux.service"
    ln_s "${DOTS_HOME}/systemd/user/dropbox-ignore-flux.timer" "${XDG_CONFIG_HOME}/systemd/user/dropbox-ignore-flux.timer"

    if [[ "$ENABLE_USER_TIMERS" == "true" ]]; then
        run systemctl --user daemon-reload
        run systemctl --user enable --now dropbox-ignore-flux.timer
    fi
fi

# kitty OS-specific overrides (pulled in via `include os-local.conf`)
if [[ "$MACOS" == "true" ]]; then
    ln_s "${DOTS_HOME}/kitty/os-macos.conf" "${DOTS_HOME}/kitty/os-local.conf"

    # macOS ships no xterm-kitty in its terminfo db, so git/less/etc. warn the
    # "terminal is not fully functional". Compile kitty's bundled entry into
    # ~/.terminfo, which ncurses auto-searches. (Linux gets it from the
    # kitty-terminfo package.)
    _kitty_terminfo="/Applications/kitty.app/Contents/Resources/kitty/terminfo/kitty.terminfo"
    [[ -f "$_kitty_terminfo" ]] && run tic -x -o "${HOME}/.terminfo" "$_kitty_terminfo"
    unset _kitty_terminfo
else
    ln_s "${DOTS_HOME}/kitty/os-linux.conf" "${DOTS_HOME}/kitty/os-local.conf"
fi

# Install ~/. components
for path in "${COMMON_DOTFILES[@]}"; do
    ln_s "${DOTS_HOME}/${path}" "${HOME}/.${path}"
done

# ghci
ensure_dir "${HOME}/.ghc"
ln_s "${DOTS_HOME}/ghci.conf" "${HOME}/.ghc/ghci.conf"

# gimp (only for graphical mode)
if [[ "$HEADLESS" == "false" ]]; then
    GIMP_DIR="${XDG_CONFIG_HOME}/GIMP/3.0"
    GIMP_PLUGIN_DIR="${XDG_CONFIG_HOME}/GIMP/3.0/plug-ins"
    GIMPRC="${GIMP_DIR}/gimprc"

    ensure_dir "${GIMP_DIR}"

    if [ -e "$GIMPRC" ]; then
      run mv "$GIMPRC" "$GIMPRC.bak"
    fi
    if [ -e "$GIMP_PLUGIN_DIR" ]; then
      run mv "$GIMP_PLUGIN_DIR" "$GIMP_PLUGIN_DIR.bak"
    fi

    ln_s "${DOTS_HOME}/gimp/gimprc" "$GIMPRC"
    ln_s "${DOTS_HOME}/gimp/plug-ins" "$GIMP_PLUGIN_DIR"
fi

# noctalia local assets (only for graphical mode)
if [[ "$HEADLESS" == "false" ]]; then
    NOCTALIA_PLUGIN_DIR="${XDG_CONFIG_HOME}/noctalia/plugins"
    NOCTALIA_PALETTE_DIR="${XDG_CONFIG_HOME}/noctalia/palettes"
    WALI_PANEL_PLUGIN="${NOCTALIA_PLUGIN_DIR}/wali-panel"
    GLOW_PALETTE="${NOCTALIA_PALETTE_DIR}/Glow.json"

    ensure_dir "${NOCTALIA_PLUGIN_DIR}"
    ensure_dir "${NOCTALIA_PALETTE_DIR}"

    if [ -e "${WALI_PANEL_PLUGIN}" ] && [ ! -L "${WALI_PANEL_PLUGIN}" ]; then
      run mv "${WALI_PANEL_PLUGIN}" "${WALI_PANEL_PLUGIN}.bak"
    fi

    ln_s "${DOTS_HOME}/noctalia/plugins/wali-panel" "${WALI_PANEL_PLUGIN}"
    ln_s "${DOTS_HOME}/noctalia/palettes/Glow.json" "${GLOW_PALETTE}"
fi

# git
ln_s "${DOTS_HOME}/git/ignore" "${HOME}/.gitignore_global"
ln_s "${DOTS_HOME}/git/config" "${HOME}/.gitconfig"

# julia
ensure_dir "${HOME}/.julia/config"
ln_s "${DOTS_HOME}/julia/startup.jl" "${HOME}/.julia/config/startup.jl"

# jupyter
ensure_dir "${HOME}/.jupyter"
ln_s "${DOTS_HOME}/jupyter/jupyter_qtconsole_config.py" "${HOME}/.jupyter/jupyter_qtconsole_config.py"

# mamba
ln_s "${DOTS_HOME}/condarc" "${HOME}/.mambarc"

# r
ln_s "${DOTS_HOME}/lintr" "${HOME}/.lintr"

# ripgrep
ln_s "${DOTS_HOME}/rgignore" "${HOME}/.rgignore"

# scripts, etc.
ln_s "${DOTS_HOME}/bin" "${HOME}/bin"

# mimetypes (Linux only)
if [[ "$MACOS" != "true" ]]; then
    ensure_dir "${HOME}/.local/share/mime"
    ln_s "${DOTS_HOME}/mime" "${HOME}/.local/share/mime/packages"
    if [[ "$LINK_ONLY" != "true" ]] && command -v update-mime-database >/dev/null; then
        run update-mime-database "${HOME}/.local/share/mime"
    fi

    ln_s "${DOTS_HOME}/mimeapps.list" "${XDG_CONFIG_HOME}/mimeapps.list"
fi

# install tpm
if [[ "$SKIP_EXTERNAL_CLONES" != "true" ]]; then
    if [[ ! -d "${HOME}/.tmux/plugins/tpm/.git" ]]; then
        ensure_dir "${HOME}/.tmux/plugins"
        run git clone https://github.com/tmux-plugins/tpm "${HOME}/.tmux/plugins/tpm"
    fi
fi

#
# external dependencies
#

install_packages "${PACKAGES[@]}"

echo "Done!"
