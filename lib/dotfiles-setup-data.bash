#!/usr/bin/env bash
# shellcheck disable=SC2034

DOTFILES_GRAPHICAL_CONFIGS=(feh niri zathura)
DOTFILES_COMMON_CONFIGS=(crush familiar fcitx git glow kitty mimeapps.list nvim termcolors)
DOTFILES_MACOS_EXCLUDED_COMMON_CONFIGS=(fcitx mimeapps.list)
DOTFILES_COMMON_DOTFILES=(condarc ctags npmrc plotly Rprofile Renviron tmux.conf visidatarc)

# Noctalia's generated theme output, as "<path in the tree>:<path under XDG_STATE_HOME>".
# Noctalia writes to fixed paths under ~/.config, and ~/.config/{niri,kitty,zathura}
# are whole-directory symlinks into this tree, which both machines share through Dropbox.
# Routed through per-machine state so one machine's colours never reach the other;
# setup.sh makes the links and dotfiles-health verifies them.
DOTFILES_NOCTALIA_GENERATED=(
    "niri/noctalia.kdl:niri/noctalia.kdl"
    "kitty/themes/noctalia.conf:kitty/noctalia.conf"
    "zathura/noctaliarc:zathura/noctaliarc"
)

# Per-machine state that applications write into this tree through the same
# whole-directory ~/.config symlinks, and that must not cross to the other
# machine: runtime caches, sockets, session databases, installed art. Each is
# marked com.dropbox.ignored, which keeps it on the machine that wrote it.
# A trailing "/" names a directory, which setup.sh creates before marking so the
# mark is in place before the application's first write; a file is marked only
# once it exists. setup.sh marks them; dotfiles-health fails on one left unmarked.
DOTFILES_DROPBOX_IGNORED=(
    "crush/.crush/"
    "familiar/identities.yaml"
    "familiar/themes/"
    "fcitx/cached_layout"
    "fcitx/clipboard/"
    "fcitx/data/"
    "fcitx/dbus/"
    "fcitx/libpinyin/"
    "fcitx/log/"
)

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
