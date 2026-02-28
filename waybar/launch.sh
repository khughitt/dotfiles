#!/bin/bash
# Waybar + Hyprland launcher script with hostname detection
# Automatically selects laptop or desktop config based on hostname

HOSTNAME=$(hostname)
WAYBAR_DIR="$HOME/.config/waybar"
HYPR_DIR="$HOME/.config/hypr"

# Kill existing waybar instances
killall waybar 2>/dev/null

# Select config based on hostname
if [ "$HOSTNAME" = "europa" ]; then
    ln -sf "$WAYBAR_DIR/config.laptop" "$WAYBAR_DIR/config"
    ln -sf "$HYPR_DIR/host-europa.conf" "$HYPR_DIR/host.conf"
    echo "Using laptop configuration for $HOSTNAME"
else
    ln -sf "$WAYBAR_DIR/config.desktop" "$WAYBAR_DIR/config"
    ln -sf "$HYPR_DIR/host-titan.conf" "$HYPR_DIR/host.conf"
    echo "Using desktop configuration for $HOSTNAME"
fi

# Launch waybar
waybar &
