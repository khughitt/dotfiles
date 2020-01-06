#!/bin/bash

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Determine config file to use
if [[ `hostname` == "Europa" ]]; then
    CFG="$HOME/.config/polybar/config.europa"
else
    CFG="$HOME/.config/polybar/config"
fi

echo `hostname`
echo $CFG

if type "xrandr"; then
  for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
    MONITOR=$m polybar --config=$CFG --reload bar &
  done
else
  polybar --config=$CFG --reload bar &
fi

