#!/bin/bash
#
# dotfiles setup script
# KH
#
set -euo pipefail

DOTS_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
# shellcheck source=lib/dotfiles-setup-data.bash
source "${DOTS_HOME}/lib/dotfiles-setup-data.bash"

# Parse command line arguments
HEADLESS=false
UBUNTU=false
MACOS=false
DRY_RUN=false
LINK_ONLY=false
SKIP_PACKAGES=false
SKIP_EXTERNAL_CLONES=false
ENABLE_USER_TIMERS=false
ONLY_PHASES=()

VALID_PHASES=(
    external-clones
    shell
    gtk
    graphical-config
    common-config
    systemd
    kitty
    home
    app-config
    mime
    tmux
    packages
)

function is_valid_phase() {
    local candidate="$1"
    local phase_name
    for phase_name in "${VALID_PHASES[@]}"; do
        [[ "$phase_name" == "$candidate" ]] && return 0
    done
    return 1
}

function print_valid_phases() {
    printf 'Valid phases: %s\n' "${VALID_PHASES[*]}"
}

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
        --only)
            if [[ $# -lt 2 ]]; then
                echo "--only requires a comma-separated phase list"
                print_valid_phases
                exit 1
            fi
            IFS=',' read -r -a _requested_phases <<< "$2"
            for phase_name in "${_requested_phases[@]}"; do
                if [[ -z "$phase_name" ]] || ! is_valid_phase "$phase_name"; then
                    echo "Unknown setup phase: $phase_name"
                    print_valid_phases
                    exit 1
                fi
                ONLY_PHASES+=("$phase_name")
            done
            unset _requested_phases phase_name
            shift 2
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
            echo "  --only PHASES     Run only comma-separated setup phases"
            print_valid_phases
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
if [[ "${#ONLY_PHASES[@]}" -gt 0 ]]; then
    echo "Only phases: ${ONLY_PHASES[*]}"
fi

# Define package lists based on distribution
if [[ "$MACOS" == "true" ]]; then
    PACKAGES=("bat" "coreutils" "dust" "fd" "figlet" "fzf" "btop"
              "lolcat" "lsd" "neovim" "ripgrep" "thefuck" "tldr"
              "tmux" "tre-command" "visidata" "zoxide")
    FONT_PACKAGES=("font-hack-nerd-font" "font-symbols-only-nerd-font")
    PACKAGE_INSTALL_CMD="brew install"
    PACKAGE_UPDATE_CMD="brew update"
elif [[ "$UBUNTU" == "true" ]]; then
    PACKAGES=("bat" "btop" "fd-find" "fzf" "lsd" "ripgrep" "thefuck" "tldr" "visidata" "zoxide")
    FONT_PACKAGES=("fonts-nerd-fonts" "fonts-weather-icons")
    PACKAGE_INSTALL_CMD="sudo apt install -y"
    PACKAGE_UPDATE_CMD="sudo apt update"
else
    PACKAGES=("bat" "dust" "fd" "fzf" "glow" "btop" "lolcat" "lsd" "moor" "ripgrep" "sd" "tre-command" "thefuck" "tldr" "visidata" "xan" "zoxide")
    FONT_PACKAGES=("ttf-nerd-fonts-symbols" "ttf-hack-nerd" "ttf-weather-icons")
    PACKAGE_INSTALL_CMD="yay -S"
    PACKAGE_UPDATE_CMD=""
fi

GRAPHICAL_CONFIGS=("${DOTFILES_GRAPHICAL_CONFIGS[@]}")
if [[ "$MACOS" != "true" ]]; then
    dotfiles_select_common_configs true
else
    dotfiles_select_common_configs false
fi
COMMON_CONFIGS=("${DOTFILES_SELECTED_COMMON_CONFIGS[@]}")

COMMON_DOTFILES=("${DOTFILES_COMMON_DOTFILES[@]}")

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

function phase() {
    echo "==> $1"
}

function should_run_phase() {
    local requested="$1"
    local phase_name

    [[ "${#ONLY_PHASES[@]}" -eq 0 ]] && return 0

    for phase_name in "${ONLY_PHASES[@]}"; do
        [[ "$phase_name" == "$requested" ]] && return 0
    done

    return 1
}

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

function run_phase() {
    local phase_name="$1"
    local setup_function="$2"

    should_run_phase "$phase_name" || return 0
    "$setup_function"
}

function setup_external_clones() {
    phase "External clone setup"
    if [[ "$SKIP_EXTERNAL_CLONES" == "true" ]]; then
        echo "Skipping external clone setup..."
        return
    fi

    ensure_dir "$HOME/.cache/zinit/completions"

    local zinit_home="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
    if [[ ! -d "$zinit_home/.git" ]]; then
        ensure_dir "$(dirname "$zinit_home")"
        run git clone https://github.com/zdharma-continuum/zinit.git "$zinit_home"
    fi
}

function setup_shell_links() {
    phase "Shell links"
    ln_s "${DOTS_HOME}/zshrc" "${HOME}/.zshrc"
    ln_s "${DOTS_HOME}/zshenv" "${HOME}/.zshenv"
    ln_s "${DOTS_HOME}/shell" "${HOME}/.shell"
}

function setup_gtk_links() {
    [[ "$HEADLESS" == "false" ]] || return 0

    phase "GTK links"
    ensure_dir "${XDG_CONFIG_HOME}/gtk-3.0"
    ln_s "${DOTS_HOME}/gtk-3.0/settings.ini" "${XDG_CONFIG_HOME}/gtk-3.0/settings.ini"
    ln_s "${DOTS_HOME}/gtk-3.0/gtk.css" "${XDG_CONFIG_HOME}/gtk-3.0/gtk.css"

    ensure_dir "${XDG_CONFIG_HOME}/gtk-4.0"
    ln_s "${DOTS_HOME}/gtk-4.0/settings.ini" "${XDG_CONFIG_HOME}/gtk-4.0/settings.ini"
    ln_s "${DOTS_HOME}/gtk-4.0/gtk.css" "${XDG_CONFIG_HOME}/gtk-4.0/gtk.css"
}

function setup_graphical_config_links() {
    [[ "$HEADLESS" == "false" ]] || return 0

    phase "Graphical config links"
    local path
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
}

function setup_common_config_links() {
    phase "Common config links"
    local path
    for path in "${COMMON_CONFIGS[@]}"; do
        ln_s "${DOTS_HOME}/${path}" "${XDG_CONFIG_HOME}/${path}"
    done
}

function setup_systemd_user_units() {
    [[ "$MACOS" != "true" ]] || return 0

    phase "Systemd user units"
    ensure_dir "${XDG_CONFIG_HOME}/systemd/user"
    ln_s "${DOTS_HOME}/systemd/user/dropbox-ignore-flux.service" "${XDG_CONFIG_HOME}/systemd/user/dropbox-ignore-flux.service"
    ln_s "${DOTS_HOME}/systemd/user/dropbox-ignore-flux.timer" "${XDG_CONFIG_HOME}/systemd/user/dropbox-ignore-flux.timer"

    if [[ "$ENABLE_USER_TIMERS" == "true" ]]; then
        run systemctl --user daemon-reload
        run systemctl --user enable --now dropbox-ignore-flux.timer
    fi
}

function setup_kitty_overrides() {
    phase "Kitty OS overrides"
    if [[ "$MACOS" == "true" ]]; then
        ln_s "${DOTS_HOME}/kitty/os-macos.conf" "${DOTS_HOME}/kitty/os-local.conf"

        # macOS ships no xterm-kitty in its terminfo db, so git/less/etc. warn the
        # "terminal is not fully functional". Compile kitty's bundled entry into
        # ~/.terminfo, which ncurses auto-searches. (Linux gets it from the
        # kitty-terminfo package.)
        local kitty_terminfo="/Applications/kitty.app/Contents/Resources/kitty/terminfo/kitty.terminfo"
        [[ -f "$kitty_terminfo" ]] && run tic -x -o "${HOME}/.terminfo" "$kitty_terminfo"
    else
        ln_s "${DOTS_HOME}/kitty/os-linux.conf" "${DOTS_HOME}/kitty/os-local.conf"
    fi
}

function setup_home_dotfile_links() {
    phase "Home dotfile links"
    local path
    for path in "${COMMON_DOTFILES[@]}"; do
        ln_s "${DOTS_HOME}/${path}" "${HOME}/.${path}"
    done
}

function setup_application_config_links() {
    phase "Application config links"

    ensure_dir "${HOME}/.ghc"
    ln_s "${DOTS_HOME}/ghci.conf" "${HOME}/.ghc/ghci.conf"

    if [[ "$HEADLESS" == "false" ]]; then
        local gimp_dir="${XDG_CONFIG_HOME}/GIMP/3.0"
        local gimp_plugin_dir="${XDG_CONFIG_HOME}/GIMP/3.0/plug-ins"
        local gimprc="${gimp_dir}/gimprc"

        ensure_dir "$gimp_dir"

        if [ -e "$gimprc" ]; then
            run mv "$gimprc" "$gimprc.bak"
        fi
        if [ -e "$gimp_plugin_dir" ]; then
            run mv "$gimp_plugin_dir" "$gimp_plugin_dir.bak"
        fi

        ln_s "${DOTS_HOME}/gimp/gimprc" "$gimprc"
        ln_s "${DOTS_HOME}/gimp/plug-ins" "$gimp_plugin_dir"
    fi

    if [[ "$HEADLESS" == "false" ]]; then
        local noctalia_plugin_dir="${XDG_CONFIG_HOME}/noctalia/plugins"
        local noctalia_palette_dir="${XDG_CONFIG_HOME}/noctalia/palettes"
        local wali_panel_plugin="${noctalia_plugin_dir}/wali-panel"
        local memory_alert_plugin="${noctalia_plugin_dir}/memory-pressure-alert"
        local glow_palette="${noctalia_palette_dir}/Glow.json"

        ensure_dir "$noctalia_plugin_dir"
        ensure_dir "$noctalia_palette_dir"

        if [ -e "$wali_panel_plugin" ] && [ ! -L "$wali_panel_plugin" ]; then
            run mv "$wali_panel_plugin" "${wali_panel_plugin}.bak"
        fi

        ln_s "${DOTS_HOME}/noctalia/plugins/wali-panel" "$wali_panel_plugin"
        ln_s "${DOTS_HOME}/noctalia/plugins/memory-pressure-alert" "$memory_alert_plugin"
        ln_s "${DOTS_HOME}/noctalia/palettes/Glow.json" "$glow_palette"
    fi

    ln_s "${DOTS_HOME}/git/ignore" "${HOME}/.gitignore_global"
    ln_s "${DOTS_HOME}/git/config" "${HOME}/.gitconfig"

    ensure_dir "${HOME}/.julia/config"
    ln_s "${DOTS_HOME}/julia/startup.jl" "${HOME}/.julia/config/startup.jl"

    ensure_dir "${HOME}/.jupyter"
    ln_s "${DOTS_HOME}/jupyter/jupyter_qtconsole_config.py" "${HOME}/.jupyter/jupyter_qtconsole_config.py"

    ln_s "${DOTS_HOME}/condarc" "${HOME}/.mambarc"
    ln_s "${DOTS_HOME}/lintr" "${HOME}/.lintr"
    ln_s "${DOTS_HOME}/rgignore" "${HOME}/.rgignore"
    ln_s "${DOTS_HOME}/bin" "${HOME}/bin"
}

function setup_mime_links() {
    [[ "$MACOS" != "true" ]] || return 0

    phase "MIME links"
    ensure_dir "${HOME}/.local/share/mime"
    ln_s "${DOTS_HOME}/mime" "${HOME}/.local/share/mime/packages"
    if [[ "$LINK_ONLY" != "true" ]] && command -v update-mime-database >/dev/null; then
        run update-mime-database "${HOME}/.local/share/mime"
    fi

    ln_s "${DOTS_HOME}/mimeapps.list" "${XDG_CONFIG_HOME}/mimeapps.list"
}

function setup_tmux_plugin_manager() {
    phase "Tmux plugin manager"
    if [[ "$SKIP_EXTERNAL_CLONES" == "true" ]]; then
        return
    fi

    if [[ ! -d "${HOME}/.tmux/plugins/tpm/.git" ]]; then
        ensure_dir "${HOME}/.tmux/plugins"
        run git clone https://github.com/tmux-plugins/tpm "${HOME}/.tmux/plugins/tpm"
    fi
}

function setup_package_installation() {
    phase "Package installation"
    install_packages "${PACKAGES[@]}"
}

echo "Setting up dotfiles..."

ensure_dir "$XDG_CONFIG_HOME"

run_phase external-clones setup_external_clones
run_phase shell setup_shell_links
run_phase gtk setup_gtk_links
run_phase graphical-config setup_graphical_config_links
run_phase common-config setup_common_config_links
run_phase systemd setup_systemd_user_units
run_phase kitty setup_kitty_overrides
run_phase home setup_home_dotfile_links
run_phase app-config setup_application_config_links
run_phase mime setup_mime_links
run_phase tmux setup_tmux_plugin_manager
run_phase packages setup_package_installation

echo "Done!"
