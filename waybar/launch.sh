#!/bin/bash
# Waybar launcher script with hostname detection
# Automatically selects laptop or desktop config based on hostname

HOSTNAME=$(hostname)
WAYBAR_DIR="$HOME/.config/waybar"

# Kill existing waybar instances
killall waybar 2>/dev/null

# Select config based on hostname
if [ "$HOSTNAME" = "europa" ]; then
    # Laptop config for europa
    ln -sf "$WAYBAR_DIR/config.laptop" "$WAYBAR_DIR/config"
    echo "Waybar: Using laptop configuration for $HOSTNAME"
else
    # Desktop config for all other hosts
    ln -sf "$WAYBAR_DIR/config.desktop" "$WAYBAR_DIR/config"
    echo "Waybar: Using desktop configuration for $HOSTNAME"
fi

# Launch waybar
waybar &
