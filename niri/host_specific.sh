#!/bin/bash
#
# Select this machine's Niri host config.
#
# The dotfiles tree is shared between machines, so the selection cannot live in
# it: whichever machine linked last would win for both. The link goes into
# per-machine state instead, and config.kdl includes it from there.
set -euo pipefail

NIRI_DIR="${NIRI_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/niri"

host_config="${NIRI_DIR}/host-$(hostname).kdl"
if [ ! -f "$host_config" ]; then
    echo "No Niri host config for $(hostname); expected ${host_config}" >&2
    exit 1
fi

mkdir -p "$STATE_DIR"
ln -sfT "$host_config" "${STATE_DIR}/host.kdl"
echo "Niri host config for $(hostname): ${host_config}"
