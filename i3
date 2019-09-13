#
# i3 config
# kh april.2019
#

#-------------------------------------------------------------------------------
# Variables
#-------------------------------------------------------------------------------
# Logo key. Use Mod1 for Alt.
set $mod Mod4

# Home row direction keys, like vim
set $left h
set $down j
set $up k
set $right l

# Your preferred terminal emulator
set $term termite

# Your preferred application launcher
set $menu rofi -show drun
set $greenclip rofi -modi "clipboard:greenclip print" -show clipboard -run-command '{cmd}'

# start dmenu
#set $menu dmenu_run

#-------------------------------------------------------------------------------
#  Appearance
#-------------------------------------------------------------------------------

# wallpaper
#exec_always feh --bg-scale ~/d/linux/backgrounds/02727_mossy_1920x1200.jpg 
#exec_always feh --bg-scale ~/d/linux/backgrounds/Luetin_1920.jpg
exec_always feh --bg-scale ~/d/linux/backgrounds/board_black_line_texture_background_wood_55220_1920x1080.jpg

# font
font pango:Droid Sans Mono 10

# window borders
for_window [class=".*"] border pixel 2
hide_edge_borders smart_no_gaps

# gaps
gaps inner 12
smart_gaps on
#gaps inner all set 20
#gaps outer current plus 5

# colors [dracula]
#client.focused          #ea51b2 #d1499f #282936 #a1efe4 #ea51b2 
#client.focused_inactive #3a3c4e #626483 #f7f7fb #3a3c4e #3a3c4e
#client.unfocused        #3a3c4e #282936 #626483 #292d2e #3a3c4e
#client.urgent           #3a3c4e #ebff87 #626483 #ebff87 #3a3c4e

# colors [themer]
# class                 border    backgr.   text      indicator child_border
client.focused          #a067abff #f37055ff #23292dff #1299adff #a067abff
client.unfocused        #42474baa #23292daa #616668aa #23292daa #23292daa

#-------------------------------------------------------------------------------
#  Input
#-------------------------------------------------------------------------------

# not yet implemented.. https://github.com/swaywm/sway/pull/1979
#hide_cursor 5000

#-------------------------------------------------------------------------------
#  Key bindings
#-------------------------------------------------------------------------------

#
# general
#

# terminal
bindsym $mod+Return exec $term

# file browser
bindsym $mod+n exec termite -e ranger


# kill focused window
bindsym $mod+q kill
bindsym Mod1+F4 kill

# start your launcher
bindsym $mod+p exec $menu

# clipboard history
bindsym $mod+o exec $greenclip

# Drag floating windows by holding down $mod and left mouse button.
# Resize them with right mouse button + $mod.
# Despite the name, also works for non-floating windows.
#floating_modifier $mod normal
floating_modifier $mod

# reload the configuration file
bindsym $mod+Shift+c reload

# exit i3
bindsym $mod+Shift+e exit

# Move your focus around
bindsym $mod+$left focus left
bindsym $mod+$down focus down
bindsym $mod+$up focus up
bindsym $mod+$right focus right
# or use $mod+[up|down|left|right]
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

# _move_ the focused window with the same, but add Shift
bindsym $mod+Shift+$left move left
bindsym $mod+Shift+$down move down
bindsym $mod+Shift+$up move up
bindsym $mod+Shift+$right move right

# ditto, with arrow keys
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

#-------------------------------------------------------------------------------
# Workspaces
#-------------------------------------------------------------------------------
set $exec_i3_groups exec --no-startup-id i3-workspace-groups

# Switch active workspace group
bindsym $mod+g exec --no-startup-id i3-switch-active-workspace-group

# Move workspace to another group
bindsym $mod+Shift+g exec --no-startup-id i3-assign-workspace-to-group
bindsym $mod+1 $exec_i3_groups workspace-number 1
bindsym $mod+2 $exec_i3_groups workspace-number 2
bindsym $mod+3 $exec_i3_groups workspace-number 3
bindsym $mod+4 $exec_i3_groups workspace-number 4
bindsym $mod+5 $exec_i3_groups workspace-number 5
bindsym $mod+6 $exec_i3_groups workspace-number 6
bindsym $mod+7 $exec_i3_groups workspace-number 7
bindsym $mod+8 $exec_i3_groups workspace-number 8
bindsym $mod+9 $exec_i3_groups workspace-number 9
bindsym $mod+0 $exec_i3_groups workspace-number 10

bindsym $mod+Shift+1 $exec_i3_groups move-to-number 1
bindsym $mod+Shift+2 $exec_i3_groups move-to-number 2
bindsym $mod+Shift+3 $exec_i3_groups move-to-number 3
bindsym $mod+Shift+4 $exec_i3_groups move-to-number 4
bindsym $mod+Shift+5 $exec_i3_groups move-to-number 5
bindsym $mod+Shift+6 $exec_i3_groups move-to-number 6
bindsym $mod+Shift+7 $exec_i3_groups move-to-number 7
bindsym $mod+Shift+8 $exec_i3_groups move-to-number 8
bindsym $mod+Shift+9 $exec_i3_groups move-to-number 9
bindsym $mod+Shift+0 $exec_i3_groups move-to-number 10

# default workspace navigation
bindsym $mod+Control+1 workspace number 1
bindsym $mod+Control+2 workspace number 2
bindsym $mod+Control+3 workspace number 3
bindsym $mod+Control+4 workspace number 4
bindsym $mod+Control+5 workspace number 5
bindsym $mod+Control+6 workspace number 6
bindsym $mod+Control+7 workspace number 7
bindsym $mod+Control+8 workspace number 8
bindsym $mod+Control+9 workspace number 9
bindsym $mod+Control+0 workspace number 10

# Switch to previous workspace in group.
bindsym $mod+u $exec_i3_groups workspace-prev

# Switch to next workspace in group.
bindsym $mod+i $exec_i3_groups workspace-next

# Move to previous workspace in group.
bindsym $mod+Shift+p $exec_i3_groups move-to-prev

# Move to next workspace in group.
bindsym $mod+Shift+n $exec_i3_groups move-to-next

# switch to workspace
# bindsym $mod+1 workspace 1
# bindsym $mod+2 workspace 2
# bindsym $mod+3 workspace 3
# bindsym $mod+4 workspace 4
# bindsym $mod+5 workspace 5
# bindsym $mod+6 workspace 6
# bindsym $mod+7 workspace 7
# bindsym $mod+8 workspace 8
# bindsym $mod+9 workspace 9
# bindsym $mod+0 workspace 10

# move focused container to workspace
#bindsym $mod+Shift+1 move container to workspace 📖
#bindsym $mod+Shift+2 move container to workspace #
#bindsym $mod+Shift+3 move container to workspace 🌎
#bindsym $mod+Shift+4 move container to workspace ♫
# bindsym $mod+Shift+1 move container to workspace 1
# bindsym $mod+Shift+2 move container to workspace 2
# bindsym $mod+Shift+3 move container to workspace 3
# bindsym $mod+Shift+4 move container to workspace 4
# bindsym $mod+Shift+5 move container to workspace 5
# bindsym $mod+Shift+6 move container to workspace 6
# bindsym $mod+Shift+7 move container to workspace 7
# bindsym $mod+Shift+8 move container to workspace 8
# bindsym $mod+Shift+9 move container to workspace 9
# bindsym $mod+Shift+0 move container to workspace 10

# move workspace to different monitor
bindsym $mod+m move workspace to output left

# specify default monitors for first few workspaces
workspace "1" output HDMI-0
workspace "2" output HDMI-0
workspace "3" output HDMI-0
workspace "4" output DP-1
workspace "5" output DP-1
workspace "6" output DP-1

#-------------------------------------------------------------------------------
# Layout
#-------------------------------------------------------------------------------

# You can "split" the current object of your focus with
# $mod+b or $mod+v, for horizontal and vertical splits
# respectively.
bindsym $mod+b splith
bindsym $mod+v splitv

# Switch the current container between different layout styles
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split

# Make the current focus fullscreen
bindsym $mod+f fullscreen

# Toggle the current focus between tiling and floating mode
bindsym $mod+Shift+space floating toggle

# Swap focus between the tiling area and the floating area
bindsym $mod+space focus mode_toggle

# move focus to the parent container
bindsym $mod+a focus parent

# application shortcuts
#bindsym Mod1+backslash [class="Chromium"] focus, [app_id='terminal_scratchpad'] move scratchpad
#bindsym Mod1+backslash [class="Chromium"] focus
#bindsym Mod1+s [instance="spotify"] focus

# peek
for_window [class="peek"] floating enable

#
# Media keys:
#
bindsym XF86AudioRaiseVolume exec pactl set-sink-volume $(pacmd list-sinks |awk '/* index:/{print $3}') +5%
bindsym XF86AudioLowerVolume exec pactl set-sink-volume $(pacmd list-sinks |awk '/* index:/{print $3}') -5%
bindsym XF86AudioMute exec pactl set-sink-mute $(pacmd list-sinks |awk '/* index:/{print $3}') toggle

# spotify
bindsym XF86AudioPlay exec "dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.PlayPause"
bindsym XF86AudioStop exec "dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Stop"
bindsym XF86AudioPrev exec "dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Previous"
bindsym XF86AudioNext exec "dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Next"


#-------------------------------------------------------------------------------
# Scratchpads
#-------------------------------------------------------------------------------
exec_always --no-startup-id termite --name=termite_scratch -t termite_scratch
for_window[instance="termite_scratch"] move scratchpad

bindsym Mod1+Return \
    [instance="python_scratch|r_scratch"] move scratchpad; \
    [instance="termite_scratch"] scratchpad show, resize set 1200 800; \
    move position 2280px 140px;

exec_always --no-startup-id termite -e radian --name=r_scratch -t r_scratch
for_window[instance="r_scratch"] move scratchpad

bindsym Mod1+space \
    [instance="python_scratch|termite_scratch"] move scratchpad; \
    [instance="r_scratch"] scratchpad show, resize set 1200 800; \
    move position 2280px 140px

exec_always --no-startup-id termite -e ipython --name=python_scratch -t python_scratch
for_window[instance="python_scratch"] move scratchpad

bindsym Mod1+j \
    [instance="r_scratch|termite_scratch"] move scratchpad; \
    [instance="python_scratch"] scratchpad show, resize set 1200 800; \
    move position 2280px 140px

#
# Resizing containers:
#
mode "resize" {
    # left will shrink the containers width
    # right will grow the containers width
    # up will shrink the containers height
    # down will grow the containers height
    bindsym $left resize shrink width 5 px or 5 ppt
    bindsym $down resize grow height 5 px or 5 ppt
    bindsym $up resize shrink height 5 px or 5 ppt
    bindsym $right resize grow width 5 px or 5 ppt

    # ditto, with arrow keys
    bindsym Left resize shrink width 5 px or 5 ppt
    bindsym Down resize grow height 5 px or 5 ppt
    bindsym Up resize shrink height 5 px or 5 ppt
    bindsym Right resize grow width 5 px or 5 ppt

    # return to default mode
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

#
# Status Bar:
#
bar {
    strip_workspace_numbers yes
    i3bar_command i3bar -t
    colors {
        statusline #e9e9f4
        background #33333377
        inactive_workspace #33333377 #33333377 #5c5c5c
        focused_workspace  #33333377 #33333377 #f37055ff
        #inactive_workspace #32323200 #32323200 #5c5c5c
        #focused_workspace  #ef4e7caa #ef4e7cff #000000ff
        #active_workspace #333333 #333333 #888888
        #urgent_workspace #eb709b #eb709b #ffffff
    }
    status_command py3status 
    #status_command i3status 
}

# autostart
exec_always --no-startup-id killall compton; compton
exec --no-startup-id xrandr --output DP-1 --auto --left-of HDMI-0
exec --no-startup-id /usr/lib/geoclue-2.0/demos/agent
exec --no-startup-id blackd
exec --no-startup-id greenclip daemon
