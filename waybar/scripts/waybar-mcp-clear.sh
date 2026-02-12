#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${WAYBAR_MCP_FILE:-/tmp/waybar-mcp.json}"
STAMP_FILE="${WAYBAR_MCP_STAMP:-/tmp/waybar-mcp.stamp}"

# Clear the Waybar payload
printf '%s\n' '{"text":"󰂚 ready","tooltip":"Waiting for MCP notifications","class":""}' > "$STATE_FILE"
touch "$STAMP_FILE" 2>/dev/null || true

# Reset submap if running under Hyprland
if command -v hyprctl >/dev/null 2>&1; then
    hyprctl dispatch submap reset >/dev/null 2>&1 || true
fi

# Refresh Waybar module
pkill -RTMIN+8 waybar 2>/dev/null || true
