#!/bin/bash

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Determine config file to use
CFG="$HOME/.config/polybar/config.$(hostname).ini"

if [ ! -f "$CFG" ]; then
    CFG="$HOME/.config/polybar/config.europa.ini"
fi

echo "LOADING POLYBAR CONFIG: $CFG" 

if type "xrandr"; then
  # multiple monitors
  for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
    MONITOR=$m polybar --config=$CFG --reload bar &
  done
else
  polybar --config=$CFG --reload bar &
fi

