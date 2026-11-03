#!/usr/bin/env bash
# Arrays are consumed by both check commands.
# shellcheck disable=SC2034
# Shared source inventories for the syntax and ShellCheck gates.
bash_files=(
    bashrc
    bash_profile
    setup.sh
    bin/dotfiles-check
    tools/check-hygiene
    tools/check-code
    tools/test-one
    .githooks/pre-commit
    .githooks/pre-push
    lib/dotfiles-check-data.bash
    bin/dotfiles-health
    bin/dotfiles-layout-check
    bin/dotfiles-secrets-check
    bin/kernel-gate
    bin/install-capture-sudoers
    bin/mindful
    bin/mindful-tui
    lib/dotfiles-setup-data.bash
    niri/host_specific.sh
    niri/scripts/monitor-handler.sh
    nvim/tests/noctalia/run.sh
)

zsh_files=(
    zshrc
    zshenv
    shell/aliases
    shell/audio
    shell/functions
    shell/functions.d/dropbox.zsh
    shell/fzf
    shell/history
    shell/macos
    shell/tmux
    shell/ubuntu
    shell/vconsole
    shell/zoxide
    bin/work-link
    tests/dropbox_ignore_flux.zsh
    tests/work_link.zsh
    tests/history.zsh
    tests/secrets_check.zsh
    tests/setup_and_health.zsh
    tests/dotfiles_check.zsh
    tests/justfile.zsh
    tests/layout_check.zsh
    tests/tmp_cleanup.zsh
)

while IFS= read -r file; do
    zsh_files+=("$file")
done < <(find shell -path 'shell/private' -prune -o -path 'shell/local' -prune -o -type f -name '*.zsh' -print | sort)
