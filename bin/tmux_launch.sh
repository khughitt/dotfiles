#!/usr/bin/env zsh
# If no existing tmux sessions exist, create a new one
if [ $(ps -f -u $USER | grep tmux | grep -v grep | wc -l) -lt 3 ]; then
    tmux
else
    # If not already inside a tmux session, attach to existing session
    if [ -z "$TMUX" ]; then
        # Fix DISPLAY variable
        # http://yubinkim.com/?p=203
        for name in `tmux ls -F '#{session_name}'`; do
            tmux setenv -g -t $name DISPLAY $DISPLAY #set display for all sessions
        done
        # Attach to existing tmux session
        tmux attach
    fi
fi

