#!/bin/bash
#
# host-specific settings for Niri
#
HOSTNAME=$(hostname)
NIRI_DIR="$HOME/.config/niri"

if [ "$HOSTNAME" = "europa" ]; then
    ln -sf "host-europa.kdl" "$NIRI_DIR/host.kdl"
    echo "Using laptop Niri configuration for $HOSTNAME"
else
    ln -sf "host-titan.kdl" "$NIRI_DIR/host.kdl"
    echo "Using desktop Niri configuration for $HOSTNAME"
fi
