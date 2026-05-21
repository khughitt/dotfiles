#!/bin/bash
# Disable the internal laptop display when an external display is present.
# Niri handles lid close/open automatically; this preserves the old docked
# workflow where eDP-1 stays off while an external monitor is connected.

set -u

INTERNAL_OUTPUT="${NIRI_INTERNAL_OUTPUT:-eDP-1}"
CHECK_INTERVAL_SECONDS="${NIRI_MONITOR_CHECK_INTERVAL_SECONDS:-5}"

has_external() {
    niri msg -j outputs \
        | jq -e --arg internal "$INTERNAL_OUTPUT" '
            if type == "object" then
                [to_entries[] | select(.key != $internal)] | length > 0
            elif type == "array" then
                [.[] | select((.name // "") != $internal)] | length > 0
            else
                false
            end
        ' >/dev/null
}

apply_state() {
    if has_external; then
        niri msg output "$INTERNAL_OUTPUT" off >/dev/null 2>&1 || true
    else
        niri msg output "$INTERNAL_OUTPUT" on >/dev/null 2>&1 || true
    fi
}

sleep 1
while true; do
    apply_state
    sleep "$CHECK_INTERVAL_SECONDS"
done
