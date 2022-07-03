#!/usr/bin/env sh
#
# Polybar zeit status indicator
# KH (Jan 2021)
#

# get zeit status and strip ansi colors
tracking=`zeit tracking --no-colors`

if ! echo $tracking | grep -q "not running"; then
    # get current activity and time spent
    tag=`echo $tracking | grep --color='never' -o "on [a-z0-9\-]* for" | sed "s/on //" | sed "s/ for//"`
    time_spent=`echo ${tracking##* }`

    # determine tag color to use
    color=`mindful tags --colors | grep --color='never' "#$tag,"`
    color=`echo ${color##*,}`

    # testing...
    monitor_power=$(xset -q|grep Monitor|awk '{print $3;}')
    foo="bar"

    echo "%{u$color}%{F$color} #$tag%{F-} ($time_spent)"
else
    echo "⏳not tracking $monitor_power $foo"
fi
