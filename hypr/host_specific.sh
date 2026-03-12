#!/bin/bash
#
# host-specific settings
#
HOSTNAME=$(hostname)
HYPR_DIR="$HOME/.config/hypr"

# Select config based on hostname
if [ "$HOSTNAME" = "europa" ]; then
    ln -sf "$HYPR_DIR/host-europa.conf" "$HYPR_DIR/host.conf"
    echo "Using laptop configuration for $HOSTNAME"
else
    ln -sf "$HYPR_DIR/host-titan.conf" "$HYPR_DIR/host.conf"
    echo "Using desktop configuration for $HOSTNAME"
fi
