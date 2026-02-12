#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${WAYBAR_MCP_FILE:-/tmp/waybar-mcp.json}"
STAMP_FILE="${WAYBAR_MCP_STAMP:-/tmp/waybar-mcp.stamp}"
READY_JSON='{"text":"󰂚 ready","tooltip":"Waiting for MCP notifications","class":""}'

refresh_module() {
    pkill -RTMIN+8 waybar 2>/dev/null || true
}

touch_stamp() {
    touch "$STAMP_FILE" 2>/dev/null || true
}

if [[ "${1-}" == "--clear" ]]; then
    exec "$(dirname "$0")/waybar-mcp-clear.sh"
fi

if [[ ! -s "$STATE_FILE" ]]; then
    touch_stamp
    printf '%s\n' "$READY_JSON"
    exit 0
fi

if jq -e . "$STATE_FILE" >/dev/null 2>&1; then
    touch_stamp
    jq -c . "$STATE_FILE"
else
    touch_stamp
    printf '%s\n' "$READY_JSON"
fi
