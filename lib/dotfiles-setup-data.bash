#!/usr/bin/env bash
# shellcheck disable=SC2034

DOTFILES_GRAPHICAL_CONFIGS=(feh hypr niri zathura)
DOTFILES_COMMON_CONFIGS=(crush fcitx git glow kitty mimeapps.list nvim opencode lsd termcolors yazi)
DOTFILES_MACOS_EXCLUDED_COMMON_CONFIGS=(fcitx mimeapps.list)
DOTFILES_COMMON_DOTFILES=(condarc ctags plotly Rprofile Renviron tmux.conf visidatarc)

function dotfiles_select_common_configs() {
    local include_linux_only="${1:-true}"
    local config excluded skip

    DOTFILES_SELECTED_COMMON_CONFIGS=()

    for config in "${DOTFILES_COMMON_CONFIGS[@]}"; do
        skip=false
        if [[ "$include_linux_only" != "true" ]]; then
            for excluded in "${DOTFILES_MACOS_EXCLUDED_COMMON_CONFIGS[@]}"; do
                if [[ "$config" == "$excluded" ]]; then
                    skip=true
                    break
                fi
            done
        fi

        [[ "$skip" == "true" ]] || DOTFILES_SELECTED_COMMON_CONFIGS+=("$config")
    done
}
