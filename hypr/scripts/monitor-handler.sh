#!/bin/bash
# Automatically disable internal display (eDP-1) when an external monitor
# is connected, and re-enable it when all external monitors are removed.
# Survives suspend/resume by reconnecting the IPC socket when it breaks.

disable_internal() {
    hyprctl keyword monitor "eDP-1, disable"
}

enable_internal() {
    hyprctl keyword monitor "eDP-1, preferred, auto, auto"
}

has_external() {
    hyprctl monitors -j | jq -e '[.[] | select(.name != "eDP-1")] | length > 0' >/dev/null 2>&1
}

check_and_apply() {
    if has_external; then
        disable_internal
    else
        enable_internal
    fi
}

# Initial state check
sleep 1
check_and_apply

# Listen for hotplug events, reconnecting after suspend/resume.
# When the laptop suspends, socat's socket connection breaks and it exits.
# The outer loop catches this, waits for Hyprland to stabilize, re-checks
# monitor state (re-enabling eDP-1 if the external was unplugged while
# suspended), then reconnects.
while true; do
    socat -U - UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" 2>/dev/null | while read -r line; do
        case $line in
            monitoraddedv2*)
                disable_internal
                ;;
            monitorremoved*)
                if ! has_external; then
                    enable_internal
                fi
                ;;
        esac
    done
    # socat exited (suspend/resume or socket reset) — re-check and reconnect
    sleep 2
    check_and_apply
done
