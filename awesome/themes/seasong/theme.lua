-- seasong, awesome3 theme
-- Sources:
-- [1] Blazeix's niceandclean awesome3 theme
-- [2] ghost1227's openbox theme
-- [3] kalindy's Phoenix Nebula RC141 color scheme

local awful = require("awful")

-- {{{ Helpers
function hometheme(path) return awful.util.getdir("config") .. "/themes/seasong" .. path end
function hometags(path) return hometheme("/taglist") .. path end
function homelayouts(path) return hometheme("/layouts") .. path end
function homewidgets(path) return hometheme("/widgets") .. path end
function hometp(path) return hometheme("/tp") .. path end

function systheme(path) return "/usr/share/awesome/themes/default" .. path end
function systitle(path) return systheme("/titlebar") .. path end
-- }}}

-- {{ Main
theme = {}
theme.font          = "droid sans mono 10"
theme.menu_height   = 16
theme.menu_width    = 100
-- }}}

-- {{{ Colors
theme.bg_normal     = "#020001"
theme.bg_focus      = "#020001"
theme.bg_urgent     = "#b2e5ff"
theme.bg_tooltip    = "#fff"
theme.bg_em         = "#b2e5ff"
theme.bg_systray    = "#020001"
theme.bg_widget     = "#020001"

theme.fg_normal     = "#555"
theme.fg_focus      = "#b2e5ff" 
theme.fg_urgent     = "#ff0000"
theme.fg_tooltip    = "#020001"
theme.fg_tooltip    = "#313030"
theme.fg_em         = "#b2e5ff"
theme.fg_widget        = "#14d1de"
theme.fg_center_widget = "#009983"
theme.fg_end_widget    = theme.bg_normal 

theme.border_width  = 2
theme.border_normal = "#007099"
theme.border_focus  = "#b2e5ff"
theme.border_marked = "#00baff"
theme.border_tooltip        = "#313030"
theme.border_widget         = "#1b191a"

theme.titlebar_bg_focus     = theme.border_widget
theme.titlebar_bg_normal    = theme.border_widget

theme.mouse_finder_color    = "#009983"
-- }}}

-- {{{ Icons
theme.taglist_squares_sel   = hometags("/squaref.png")
theme.taglist_squares_unsel = hometags("/square.png")

theme.awesome_icon =        hometheme("/awesome16.png")
theme.menu_submenu_icon     = systheme("/submenu.png")

theme.layout_tile           = homelayouts("/tilew.png")
theme.layout_tileleft       = homelayouts("/tileleftw.png")
theme.layout_tilebottom     = homelayouts("/tilebottomw.png")
theme.layout_tiletop        = homelayouts("/tiletopw.png")
theme.layout_fairv          = homelayouts("/fairvw.png")
theme.layout_fairh          = homelayouts("/fairhw.png")
theme.layout_spiral         = homelayouts("/spiralw.png")
theme.layout_dwindle        = homelayouts("/dwindlew.png")
theme.layout_max            = homelayouts("/maxw.png")
theme.layout_fullscreen     = homelayouts("/fullscreenw.png")
theme.layout_magnifier      = homelayouts("/magnifierw.png")
theme.layout_floating       = homelayouts("/floatingw.png")

theme.widget_disk           = homewidgets("/disk.png")
theme.widget_cpu            = homewidgets("/cpu.png")
theme.widget_ac             = homewidgets("/ac.png")
theme.widget_acblink        = homewidgets("/acblink.png")
theme.widget_blank          = homewidgets("/blank.png")
theme.widget_batfull        = homewidgets("/batfull.png")
theme.widget_batmed         = homewidgets("/batmed.png")
theme.widget_batlow         = homewidgets("/batlow.png")
theme.widget_batempty       = homewidgets("/batempty.png")
theme.widget_vol            = homewidgets("/vol.png")
theme.widget_mute           = homewidgets("/mute.png")
theme.widget_pac            = homewidgets("/pac.png")
theme.widget_pacnew         = homewidgets("/pacnew.png")
theme.widget_mail           = homewidgets("/mail.png")
theme.widget_mailnew        = homewidgets("/mailnew.png")
theme.widget_temp           = homewidgets("/temp.png")
theme.widget_tempwarn       = homewidgets("/tempwarm.png")
theme.widget_temphot        = homewidgets("/temphot.png")
theme.widget_wifi           = homewidgets("/wifi.png")
theme.widget_nowifi         = homewidgets("/nowifi.png")
theme.widget_mpd            = homewidgets("/mpd.png")
theme.widget_play           = homewidgets("/play.png")
theme.widget_pause          = homewidgets("/pause.png")
theme.widget_ram            = homewidgets("/ram.png")

theme.widget_mem            = hometp("/ram.png")
theme.widget_swap           = hometp("/swap.png")
theme.widget_fs             = hometp("/fs_01.png")
theme.widget_fs2            = hometp("/fs_02.png")
theme.widget_up             = hometp("/up.png")
theme.widget_down           = hometp("/down.png")

theme.titlebar_close_button_focus               = systitle("/close_focus.png")
theme.titlebar_close_button_normal              = systitle("/close_normal.png")

theme.titlebar_ontop_button_focus_active        = systitle("/ontop_focus_active.png")
theme.titlebar_ontop_button_normal_active       = systitle("/ontop_normal_active.png")
theme.titlebar_ontop_button_focus_inactive      = systitle("/ontop_focus_inactive.png")
theme.titlebar_ontop_button_normal_inactive     = systitle("/ontop_normal_inactive.png")

theme.titlebar_sticky_button_focus_active       = systitle("/sticky_focus_active.png")
theme.titlebar_sticky_button_normal_active      = systitle("/sticky_normal_active.png")
theme.titlebar_sticky_button_focus_inactive     = systitle("/sticky_focus_inactive.png")
theme.titlebar_sticky_button_normal_inactive    = systitle("/sticky_normal_inactive.png")

theme.titlebar_floating_button_focus_active     = systitle("/floating_focus_active.png")
theme.titlebar_floating_button_normal_active    = systitle("/floating_normal_active.png")
theme.titlebar_floating_button_focus_inactive   = systitle("/floating_focus_inactive.png")
theme.titlebar_floating_button_normal_inactive  = systitle("/floating_normal_inactive.png")

theme.titlebar_maximized_button_focus_active    = systitle("/maximized_focus_active.png")
theme.titlebar_maximized_button_normal_active   = systitle("/maximized_normal_active.png")
theme.titlebar_maximized_button_focus_inactive  = systitle("/maximized_focus_inactive.png")
theme.titlebar_maximized_button_normal_inactive = systitle("/maximized_normal_inactive.png")

return theme
