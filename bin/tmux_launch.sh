#!/usr/bin/env zsh
if [ $(ps -f -u $USER | grep tmux | wc -l) -gt 1 ]; then
    # Fix DISPLAY variable
    # http://yubinkim.com/?p=203
    for name in `tmux ls -F '#{session_name}'`; do
        tmux setenv -g -t $name DISPLAY $DISPLAY #set display for all sessions
    done
    # Attach to existing tmux session
    tmux attach
else
    # New tmux session
    tmux
fi

