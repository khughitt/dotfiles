#!/bin/bash
#
# Select this machine's Hyprland host config.
#
# The dotfiles tree is shared between machines, so the selection cannot live in
# it: whichever machine linked last would win for both. The link goes into
# per-machine state instead, and hyprland.conf sources it from there.
set -euo pipefail

HYPR_DIR="${HYPR_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"

host_config="${HYPR_DIR}/host-$(hostname).conf"
if [ ! -f "$host_config" ]; then
    echo "No Hyprland host config for $(hostname); expected ${host_config}" >&2
    exit 1
fi

mkdir -p "$STATE_DIR"
ln -sfT "$host_config" "${STATE_DIR}/host.conf"
echo "Hyprland host config for $(hostname): ${host_config}"
