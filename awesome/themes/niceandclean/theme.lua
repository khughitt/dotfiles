-- niceandclean, awesome3 theme, by Blazeix, based off of ghost1227's openbox theme.

--{{{ Main
local awful = require("awful")
awful.util = require("awful.util")

theme = {}

home          = os.getenv("HOME")
config        = awful.util.getdir("config")
shared        = "/usr/share/awesome"
if not awful.util.file_readable(shared .. "/icons/awesome16.png") then
    shared    = "/usr/share/local/awesome"
end
sharedicons   = shared .. "/icons"
sharedthemes  = shared .. "/themes"
themes        = config .. "/themes"
themename     = "/niceandclean"
if not awful.util.file_readable(themes .. themename .. "/theme.lua") then
	themes = sharedthemes
end
themedir = themes .. themename

wallpaper1    = themedir .. "/background.jpg"
wallpaper2    = themedir .. "/background.png"
wallpaper3    = sharedthemes .. "/zenburn/zenburn-background.png"
wallpaper4    = sharedthemes .. "/default/background.png"
wpscript      = home .. "/.wallpaper"
wpscript2     = themedir .. "/niceandclean.sh"

if awful.util.file_readable(wpscript2) then
	theme.wallpaper_cmd = { "sh " .. wpscript2 }
elseif awful.util.file_readable(wallpaper1) then
	theme.wallpaper = wallpaper1
elseif awful.util.file_readable(wallpaper2) then
	theme.wallpaper = wallpaper2
elseif awful.util.file_readable(wpscript) then
	theme.wallpaper_cmd = { "sh " .. wpscript }
elseif awful.util.file_readable(wallpaper3) then
	theme.wallpaper = wallpaper3
else
	theme.wallpaper = wallpaper4
end

if awful.util.file_readable(config .. "/vain/init.lua") then
    theme.useless_gap_width  = "3"
end
--}}}

theme.font          = "sans 8"

theme.bg_normal     = "#222222"
theme.bg_focus      = "#d8d8d8"
theme.bg_urgent     = "#d02e54"
theme.bg_minimize   = "#444444"
theme.bg_em         = "#66ff33"

theme.fg_normal     = "#cccccc"
theme.fg_focus      = "#000000"
theme.fg_urgent     = "#ffffff"
theme.fg_minimize   = "#ffffff"
theme.fg_em         = "#66ff33"

theme.border_width  = "2"
theme.border_normal = "#747474"
--theme.border_focus  = "#535d6c"
theme.border_marked = "#91231c"
theme.border_focus  = "#ce2c51"

-- There are other variable sets
-- overriding the default one when
-- defined, the sets are:
-- [taglist|tasklist]_[bg|fg]_[focus|urgent]
-- titlebar_[bg|fg]_[normal|focus]
-- tooltip_[font|opacity|fg_color|bg_color|border_width|border_color]
-- mouse_finder_[color|timeout|animate_timeout|radius|factor]
-- Example:
--theme.taglist_bg_focus = "#ff0000"

-- Display the taglist squares
theme.taglist_squares_sel = themedir .. "/taglist/squarefw.png"
theme.taglist_squares_unsel = themedir .. "/taglist/squarew.png"

theme.tasklist_floating_icon = themedir .. "/tasklist/floatingw_grey.png"

-- Variables set for theming the menu:
-- menu_[bg|fg]_[normal|focus]
-- menu_[border_color|border_width]
theme.menu_submenu_icon = themedir .. "/submenu.png"
theme.menu_height = "15"
theme.menu_width  = "110"
theme.menu_border_width = "0"

-- You can add as many variables as
-- you wish and access them by using
-- beautiful.variable in your rc.lua
--theme.bg_widget = "#cc0000"

-- Define the image to load
theme.titlebar_close_button_normal = themedir .. "/titlebar/close_normal.png"
theme.titlebar_close_button_focus = themedir .. "/titlebar/close_focus.png"

theme.titlebar_ontop_button_normal_inactive = themedir .. "/titlebar/ontop_normal_inactive.png"
theme.titlebar_ontop_button_focus_inactive = themedir .. "/titlebar/ontop_focus_inactive.png"
theme.titlebar_ontop_button_normal_active = themedir .. "/titlebar/ontop_normal_active.png"
theme.titlebar_ontop_button_focus_active = themedir .. "/titlebar/ontop_focus_active.png"

theme.titlebar_sticky_button_normal_inactive = themedir .. "/titlebar/sticky_normal_inactive.png"
theme.titlebar_sticky_button_focus_inactive = themedir .. "/titlebar/sticky_focus_inactive.png"
theme.titlebar_sticky_button_normal_active = themedir .. "/titlebar/sticky_normal_active.png"
theme.titlebar_sticky_button_focus_active = themedir .. "/titlebar/sticky_focus_active.png"

theme.titlebar_floating_button_normal_inactive = themedir .. "/titlebar/floating_normal_inactive.png"
theme.titlebar_floating_button_focus_inactive = themedir .. "/titlebar/floating_focus_inactive.png"
theme.titlebar_floating_button_normal_active = themedir .. "/titlebar/floating_normal_active.png"
theme.titlebar_floating_button_focus_active = themedir .. "/titlebar/floating_focus_active.png"

theme.titlebar_maximized_button_normal_inactive = themedir .. "/titlebar/maximized_normal_inactive.png"
theme.titlebar_maximized_button_focus_inactive = themedir .. "/titlebar/maximized_focus_inactive.png"
theme.titlebar_maximized_button_normal_active = themedir .. "/titlebar/maximized_normal_active.png"
theme.titlebar_maximized_button_focus_active = themedir .. "/titlebar/maximized_focus_active.png"

-- You can use your own layout icons like this:
theme.layout_fairh = themedir .. "/layouts/fairhw.png"
theme.layout_fairv = themedir .. "/layouts/fairvw.png"
theme.layout_floating = themedir .. "/layouts/floatingw.png"
theme.layout_magnifier = themedir .. "/layouts/magnifierw.png"
theme.layout_max = themedir .. "/layouts/maxw.png"
theme.layout_fullscreen = themedir .. "/layouts/fullscreenw.png"
theme.layout_tilebottom = themedir .. "/layouts/tilebottomw.png"
theme.layout_tileleft = themedir .. "/layouts/tileleftw.png"
theme.layout_tile = themedir .. "/layouts/tilew.png"
theme.layout_tiletop = themedir .. "/layouts/tiletopw.png"
theme.layout_spiral = themedir .. "/layouts/spiralw.png"
theme.layout_dwindle = themedir .. "/layouts/dwindlew.png"

theme.awesome_icon = themedir .. "/awesome16.png"

-- {{{ Widgets
theme.widget_disk = awful.util.getdir("config") .. "/themes/dust/widgets/disk.png"
theme.widget_cpu = awful.util.getdir("config") .. "/themes/dust/widgets/cpu.png"
theme.widget_ac = awful.util.getdir("config") .. "/themes/dust/widgets/ac.png"
theme.widget_acblink = awful.util.getdir("config") .. "/themes/dust/widgets/acblink.png"
theme.widget_blank = awful.util.getdir("config") .. "/themes/dust/widgets/blank.png"
theme.widget_batfull = awful.util.getdir("config") .. "/themes/dust/widgets/batfull.png"
theme.widget_batmed = awful.util.getdir("config") .. "/themes/dust/widgets/batmed.png"
theme.widget_batlow = awful.util.getdir("config") .. "/themes/dust/widgets/batlow.png"
theme.widget_batempty = awful.util.getdir("config") .. "/themes/dust/widgets/batempty.png"
theme.widget_vol = awful.util.getdir("config") .. "/themes/dust/widgets/vol.png"
theme.widget_mute = awful.util.getdir("config") .. "/themes/dust/widgets/mute.png"
theme.widget_pac = awful.util.getdir("config") .. "/themes/dust/widgets/pac.png"
theme.widget_pacnew = awful.util.getdir("config") .. "/themes/dust/widgets/pacnew.png"
theme.widget_mail = awful.util.getdir("config") .. "/themes/dust/widgets/mail.png"
theme.widget_mailnew = awful.util.getdir("config") .. "/themes/dust/widgets/mailnew.png"
theme.widget_temp = awful.util.getdir("config") .. "/themes/dust/widgets/temp.png"
theme.widget_tempwarn = awful.util.getdir("config") .. "/themes/dust/widgets/tempwarm.png"
theme.widget_temphot = awful.util.getdir("config") .. "/themes/dust/widgets/temphot.png"
theme.widget_wifi = awful.util.getdir("config") .. "/themes/dust/widgets/wifi.png"
theme.widget_nowifi = awful.util.getdir("config") .. "/themes/dust/widgets/nowifi.png"
theme.widget_mpd = awful.util.getdir("config") .. "/themes/dust/widgets/mpd.png"
theme.widget_play = awful.util.getdir("config") .. "/themes/dust/widgets/play.png"
theme.widget_pause = awful.util.getdir("config") .. "/themes/dust/widgets/pause.png"
theme.widget_ram = awful.util.getdir("config") .. "/themes/dust/widgets/ram.png"

theme.widget_mem = awful.util.getdir("config") .. "/themes/dust/tp/ram.png"
theme.widget_swap = awful.util.getdir("config") .. "/themes/dust/tp/swap.png"
theme.widget_fs = awful.util.getdir("config") .. "/themes/dust/tp/fs_01.png"
theme.widget_fs2 = awful.util.getdir("config") .. "/themes/dust/tp/fs_02.png"
theme.widget_up = awful.util.getdir("config") .. "/themes/dust/tp/up.png"
theme.widget_down = awful.util.getdir("config") .. "/themes/dust/tp/down.png"
-- }}}


return theme
