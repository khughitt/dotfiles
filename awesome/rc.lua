----------------------------------
-- AwesomeWM 3.5.1 config       --
-- Based on github.com/tdy/dots --
----------------------------------
local gears = require("gears")
local scratch = require("scratch")
awful = require("awful")
awful.rules = require("awful.rules")
require("awful.autofocus")

-- Widgets and layout library
local wibox = require("wibox")

-- awesome-client support
require("awful.remote")

-- Theme handling library
local beautiful = require("beautiful")
beautiful.init(awful.util.getdir("config") .. "/themes/glow/theme.lua")
naughty = require("naughty")
local menubar = require("menubar")
local vicious = require("vicious")
local wi = require("wi")

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = err })
        in_error = false
    end)
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, and wallpapers

-- This is used later as the default terminal and editor to run.
terminal = "urxvt"
editor = os.getenv("EDITOR") or "vim"
editor_cmd = terminal .. " -e " .. editor
files = "nautilus"
browser = "chromium"

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod4"
altkey = "Mod1"

-- Table of layouts to cover with awful.layout.inc, order matters.
local layouts =
{
    awful.layout.suit.floating,
    awful.layout.suit.tile.left,
    awful.layout.suit.tile.right,
    awful.layout.suit.tile.bottom,
    --awful.layout.suit.tile.top,
    awful.layout.suit.fair,
    --awful.layout.suit.fair.horizontal,
    --awful.layout.suit.max.fullscreen,
    awful.layout.suit.magnifier
}
-- }}}

-- {{{ Naughty presets
naughty.config.defaults.timeout = 5
naughty.config.defaults.screen = 1
naughty.config.defaults.position = "top_right"
naughty.config.defaults.margin = 8
naughty.config.defaults.gap = 1
naughty.config.defaults.ontop = true
naughty.config.defaults.font = "Sergo UI 12"
naughty.config.defaults.icon = nil
naughty.config.defaults.icon_size = 256
naughty.config.defaults.fg = beautiful.fg_tooltip
naughty.config.defaults.bg = beautiful.bg_tooltip
naughty.config.defaults.border_color = beautiful.border_tooltip
naughty.config.defaults.border_width = 2
naughty.config.defaults.hover_timeout = nil
-- }}}

-- {{{ Wallpaper
beautiful.wallpaper = os.getenv("HOME") .. "/Dropbox/linux/backgrounds/Luetin_1920.jpg"
if beautiful.wallpaper then
    for s = 1, screen.count() do
        gears.wallpaper.maximized(beautiful.wallpaper, s, true)
    end
end
-- }}}

-- {{{ Tags
-- Define a tag table which hold all screen tags.
tags = {
  names = {'www', 'term', 'code', 'doc', 'misc'},
  layout = {layouts[2], layouts[2], layouts[3], layouts[2], layouts[4]}
}
for s = 1, screen.count() do
    -- Each screen has its own tag table.
    tags[s] = awful.tag(tags.names, s, tags.layout)
end
-- }}}

-- {{{ Menu
-- Create a laucher widget and a main menu
myawesomemenu = {
   { "manual", terminal .. " -e man awesome" },
   { "edit config", editor_cmd .. " " .. awesome.conffile },
   { "restart", awesome.restart },
   { "quit", awesome.quit }
}

mymainmenu = awful.menu({ items = { { "awesome", myawesomemenu, beautiful.awesome_icon },
                                    { "open terminal", terminal }
                                  }
                        })

mylauncher = awful.widget.launcher({ image = beautiful.awesome_icon,
                                     menu = mymainmenu })

-- Menubar configuration
menubar.utils.terminal = terminal -- Set the terminal for applications that require it
-- }}}

-- {{{ Wibox
-- Create a textclock widget
mytextclock = awful.widget.textclock()

-- Clock
mytextclock = awful.widget.textclock("<span color='" .. beautiful.fg_em ..
  "'>%a %m/%d</span> @ %I:%M %p")

-- Create a wibox for each screen and add it
mywibox = {}
mygraphbox = {}
mypromptbox = {}
mylayoutbox = {}
mytaglist = {}
mytaglist.buttons = awful.util.table.join(
                    awful.button({ }, 1, awful.tag.viewonly),
                    awful.button({ modkey }, 1, awful.client.movetotag),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, awful.client.toggletag),
                    awful.button({ }, 4, function(t) awful.tag.viewnext(awful.tag.getscreen(t)) end),
                    awful.button({ }, 5, function(t) awful.tag.viewprev(awful.tag.getscreen(t)) end)
                    )
mytasklist = {}
mytasklist.buttons = awful.util.table.join(
                     awful.button({ }, 1, function (c)
                                              if c == client.focus then
                                                  c.minimized = true
                                              else
                                                  -- Without this, the following
                                                  -- :isvisible() makes no sense
                                                  c.minimized = false
                                                  if not c:isvisible() then
                                                      awful.tag.viewonly(c:tags()[1])
                                                  end
                                                  -- This will also un-minimize
                                                  -- the client, if needed
                                                  client.focus = c
                                                  c:raise()
                                              end
                                          end),
                     awful.button({ }, 3, function ()
                                              if instance then
                                                  instance:hide()
                                                  instance = nil
                                              else
                                                  instance = awful.menu.clients({ width=250 })
                                              end
                                          end),
                     awful.button({ }, 4, function ()
                                              awful.client.focus.byidx(1)
                                              if client.focus then client.focus:raise() end
                                          end),
                     awful.button({ }, 5, function ()
                                              awful.client.focus.byidx(-1)
                                              if client.focus then client.focus:raise() end
                                          end))

for s = 1, screen.count() do
    -- Create a promptbox for each screen
    mypromptbox[s] = awful.widget.prompt()
    -- Create an imagebox widget which will contains an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    mylayoutbox[s] = awful.widget.layoutbox(s)
    mylayoutbox[s]:buttons(awful.util.table.join(
                           awful.button({ }, 1, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(layouts, -1) end),
                           awful.button({ }, 4, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(layouts, -1) end)))
    -- Create a taglist widget
    mytaglist[s] = awful.widget.taglist(s, awful.widget.taglist.filter.all, mytaglist.buttons)

    -- Create a tasklist widget
    mytasklist[s] = awful.widget.tasklist(s, awful.widget.tasklist.filter.currenttags, mytasklist.buttons)

    -- Create the wibox
    mywibox[s] = awful.wibox({ position = "top", screen = s })

    -- Widgets that are aligned to the left
    local left_layout = wibox.layout.fixed.horizontal()
    left_layout:add(mylauncher)
    left_layout:add(mytaglist[s])
    left_layout:add(mypromptbox[s])

    -- Widgets that are aligned to the right
    local right_layout = wibox.layout.fixed.horizontal()
    if s == 1 then right_layout:add(wibox.widget.systray()) end
    right_layout:add(volicon)
    right_layout:add(volpct)
    right_layout:add(volspace)
    right_layout:add(mytextclock)
    right_layout:add(space)
    right_layout:add(baticon)
    right_layout:add(batpct)
    right_layout:add(space)
    right_layout:add(mylayoutbox[s])

    -- Now bring it all together (with the tasklist in the middle)
    local layout = wibox.layout.align.horizontal()
    layout:set_left(left_layout)
    layout:set_middle(mytasklist[s])
    layout:set_right(right_layout)

    mywibox[s]:set_widget(layout)
-- Graphbox
  mygraphbox[s] = awful.wibox({ position = "bottom", height = 20, screen = s })

  local left_graphbox = wibox.layout.fixed.horizontal()
  left_graphbox:add(space)
  left_graphbox:add(cpufreq)
  left_graphbox:add(cpugraph0)
  left_graphbox:add(cpupct0)
  left_graphbox:add(cpugraph1)
  left_graphbox:add(cpupct1)
  left_graphbox:add(cpugraph2)
  left_graphbox:add(cpupct2)
  left_graphbox:add(cpugraph3)
  left_graphbox:add(cpupct3)
  left_graphbox:add(tab)
  left_graphbox:add(memused)
  left_graphbox:add(membar)
  left_graphbox:add(mempct)
  left_graphbox:add(tab)
  left_graphbox:add(rootfsused)
  left_graphbox:add(rootfsbar)
  left_graphbox:add(rootfspct)

  local right_graphbox = wibox.layout.fixed.horizontal()
  right_graphbox:add(weather)
  right_graphbox:add(space)

  local graphbox_layout = wibox.layout.align.horizontal()
  graphbox_layout:set_left(left_graphbox)
  graphbox_layout:set_right(right_graphbox)

  mygraphbox[s]:set_widget(graphbox_layout)
end
-- }}}

-- {{{ Mouse bindings
root.buttons(awful.util.table.join(
    awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- Determine number of tags
num_tags = #tags['names']

-- Function to print out layout information
function layout_info()
    naughty.notify({
      text=string.format('m %d\nc %d', awful.tag.getnmaster(),
                                        awful.tag.getncol())
    })
end

-- {{{ Key bindings
globalkeys = awful.util.table.join(
    awful.key({ modkey,           }, "Left",   awful.tag.viewprev       ),
    awful.key({ altkey, "Control" }, "Left",   awful.tag.viewprev       ),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext       ),
    awful.key({ altkey, "Control" }, "Right",  awful.tag.viewnext       ),
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore),

    -- Gnome shell shortcuts
    awful.key({ altkey, "Control", "Shift"}, "Left",
        function ()
            local i = awful.tag.getidx() - 1

            if i == 0 then
                i = num_tags
            end

            local tag = awful.tag.gettags(client.focus.screen)[i]
            if client.focus and tag then
                awful.client.movetotag(tag)
                awful.tag.viewonly(tag)
            end
        end),
    awful.key({ altkey, "Control", "Shift"}, "Right",
        function ()
            local i = awful.tag.getidx() + 1

            if i == num_tags + 1 then
                i = 1
            end

            local tag = awful.tag.gettags(client.focus.screen)[i]
            if client.focus and tag then
                awful.client.movetotag(tag)
                awful.tag.viewonly(tag)
            end
        end),

    -- Other bindings
    awful.key({ modkey,           }, "j",
        function ()
            awful.client.focus.byidx( 1)
            if client.focus then client.focus:raise() end
        end),
    awful.key({ modkey,           }, "k",
        function ()
            awful.client.focus.byidx(-1)
            if client.focus then client.focus:raise() end
        end),
  awful.key({ altkey, }, "Tab",
    function ()
      awful.client.focus.byidx( 1)
      if client.focus then client.focus:raise() end
    end),
  awful.key({ modkey, "Shift" }, "Tab",
    function ()
      awful.client.focus.byidx(-1)
      if client.focus then client.focus:raise() end
    end),
    awful.key({ modkey,           }, "w", function () mymainmenu:show() end),


    -- Layout manipulation
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto),
    --awful.key({ altkey,           }, "Tab",
    --    function ()
    --        awful.client.focus.history.previous()
    --        if client.focus then
    --            client.focus:raise()
    --        end
    --    end),

    -- Standard program
    awful.key({ modkey,           }, "Return", function () awful.util.spawn(terminal) end),
    awful.key({ modkey, "Control" }, "r", awesome.restart),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit),

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)    end),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)    end),
    awful.key({ modkey, "Shift"   }, "h",     function ()
                                                awful.tag.incnmaster(1)
                                                layout_info()
                                              end),
    awful.key({ modkey, "Shift"   }, "l",     function ()
                                                awful.tag.incnmaster(-1)
                                                layout_info()
                                              end),
    awful.key({ modkey, "Control" }, "h",     function ()
                                                awful.tag.incncol(1)
                                                layout_info()
                                              end),
    awful.key({ modkey, "Control" }, "l",     function ()
                                                awful.tag.incncol(-1)
                                                layout_info()
                                              end),
    awful.key({ modkey,           }, "space", function () awful.layout.inc(layouts,  1) end),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(layouts, -1) end),

    awful.key({ modkey, "Control" }, "n", awful.client.restore),

  -- Lock screen
  awful.key({ modkey }, "F12", function () awful.util.spawn("xlock -mode blank") end),

  -- Multimedia keys
  awful.key({ }, "XF86MonBrightnessDown", function ()
    awful.util.spawn("xbacklight -dec 15") end),
  awful.key({ }, "XF86MonBrightnessUp", function ()
    awful.util.spawn("xbacklight -inc 15") end),
  awful.key({ }, "XF86KbdBrightnessDown", function ()
    awful.util.spawn("asus-kbd-backlight down") end),
  awful.key({ }, "XF86KbdBrightnessUp", function ()
    awful.util.spawn("asus-kbd-backlight up") end),
  awful.key({ }, "XF86AudioRaiseVolume", function ()
    awful.util.spawn_with_shell("pamixer --increase 3") end),
  awful.key({ }, "XF86AudioLowerVolume", function ()
    awful.util.spawn_with_shell("pamixer --decrease 3") end),
  awful.key({ }, "XF86AudioMute", function ()
    awful.util.spawn_with_shell("pamixer --toggle-mute") end),
  awful.key({ }, "XF86Display", function()
    awful.util.spawn_with_shell("toggle-display.sh") end),
  awful.key({ }, "XF86Sleep", function()
    awful.util.spawn("systemctl suspend") end),
  awful.key({ }, "XF86TouchpadToggle", function ()
    awful.util.spawn(os.getenv("HOME") .. "/bin/tptoggle") end),
  awful.key({ modkey }, ",", function ()
    awful.util.spawn_with_shell("xbacklight -dec 10") end),
  awful.key({ modkey }, ".", function ()
    awful.util.spawn_with_shell("xbacklight -inc 10") end),

  -- Other Shortcuts
  awful.key({ modkey, "Shift"   }, "n", function ()
      -- awful.util.spawn("nautilus --no-desktop") 
      awful.util.spawn_with_shell("urxvt -e ranger") 
  end),


  -- Prompt
  awful.key({ modkey },            "r",     function () mypromptbox[mouse.screen]:run() end),
  awful.key({ altkey },            "F2",     function () mypromptbox[mouse.screen]:run() end),

  awful.key({ modkey }, "x",
            function ()
                awful.prompt.run({ prompt = "Run Lua code: " },
                mypromptbox[mouse.screen].widget,
                awful.util.eval, nil,
                awful.util.getdir("cache") .. "/history_eval")
            end),
  -- Menubar
  -- awful.key({ modkey }, "p", function() menubar.show() end)
  awful.key({ modkey }, "p", function () 
      awful.util.spawn_with_shell("XMODIFIERS='' interrobang") 
  end),
  awful.key({ modkey }, "s", function () scratch.pad.toggle() end),
  awful.key({ altkey }, "Return", function () scratch.drop("urxvt", 'center', 'center', 0.5, 0.5) end),
  awful.key({ altkey, "Shift" }, "Return", function () scratch.drop("leafpad", 'center', 'center', 0.5, 0.5) end)
)
  -- }}}

clientkeys = awful.util.table.join(
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ),
    awful.key({ modkey,           }, "o",      awful.client.movetoscreen                        ),
    awful.key({ modkey,           }, "f",      function (c) c.fullscreen = not c.fullscreen  end),
    awful.key({ modkey, "Shift"   }, "c",      function (c) c:kill()                         end),
    awful.key({ altkey,           }, "F4",     function (c) c:kill()                         end),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end),
    awful.key({ modkey,           }, "d",      function (c) scratch.pad.set(c, 0.6, 0.6, true)      end),
    awful.key({ modkey,           }, "n",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c.maximized_vertical   = not c.maximized_vertical
        end)
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it works on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 9 do
    globalkeys = awful.util.table.join(globalkeys,
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = mouse.screen
                        local tag = awful.tag.gettags(screen)[i]
                        if tag then
                           awful.tag.viewonly(tag)
                        end
                  end),
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = mouse.screen
                      local tag = awful.tag.gettags(screen)[i]
                      if tag then
                         awful.tag.viewtoggle(tag)
                      end
                  end),
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      local tag = awful.tag.gettags(client.focus.screen)[i]
                      if client.focus and tag then
                          awful.client.movetotag(tag)
                          awful.tag.viewonly(tag)
                     end
                  end),
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      local tag = awful.tag.gettags(client.focus.screen)[i]
                      if client.focus and tag then
                          awful.client.toggletag(tag)
                      end
                  end))
end

clientbuttons = awful.util.table.join(
    awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
    awful.button({ modkey }, 1, awful.mouse.client.move),
    awful.button({ modkey }, 3, awful.mouse.client.resize))

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
awful.rules.rules = {
  -- All clients will match this rule.
  { rule = { },
     properties = { border_width = beautiful.border_width,
     border_color = beautiful.border_normal,
     focus = awful.client.focus.filter,
     keys = clientkeys,
     buttons = clientbuttons,
     size_hints_honor = false } },
  { rule = { class = "MPlayer" }, properties = { floating = true } },
  { rule = { class = "pinentry" }, properties = { floating = true } },
  { rule = { class = "gimp" }, properties = { floating = true } },
  { rule = { class = "Chromium" },
    properties = { tag = tags[1][1], switchtotag=true } },
  { rule = { name = "Mendeley Desktop" },
    properties = { tag = tags[1][4], switchtotag=true } },

  -- Cytoscape
  { rule = { class = "sun-awt-X11-XFramePeer" }, properties = { floating =  true } },
  { rule = { name  = "cytoscape.sh" }, properties = { focus = false } },
  -- Fullscreen flash
  { rule = { class = "Exe"}, properties = {floating = true} },
  -- RCommander view data
  { rule = { class = "Toplevel" }, properties = {floating = true} }
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c, startup)
    -- Enable sloppy focus
    --c:connect_signal("mouse::enter", function(c)
    --    if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
    --        and awful.client.focus.filter(c) then
    --        client.focus = c
    --    end
    --end)

    if not startup then
        -- Set the windows at the slave,
        -- i.e. put it at the end of others instead of setting it master.
        -- awful.client.setslave(c)

        -- Put windows in a smart way, only if they does not set an initial position.
        if not c.size_hints.user_position and not c.size_hints.program_position then
            awful.placement.no_overlap(c)
            awful.placement.no_offscreen(c)
        end
    end

    local titlebars_enabled = false
    if titlebars_enabled and (c.type == "normal" or c.type == "dialog") then
        -- buttons for the titlebar
        local buttons = awful.util.table.join(
                awful.button({ }, 1, function()
                    client.focus = c
                    c:raise()
                    awful.mouse.client.move(c)
                end),
                awful.button({ }, 3, function()
                    client.focus = c
                    c:raise()
                    awful.mouse.client.resize(c)
                end)
                )

        -- Widgets that are aligned to the left
        local left_layout = wibox.layout.fixed.horizontal()
        left_layout:add(awful.titlebar.widget.iconwidget(c))
        left_layout:buttons(buttons)

        -- Widgets that are aligned to the right
        local right_layout = wibox.layout.fixed.horizontal()
        right_layout:add(awful.titlebar.widget.floatingbutton(c))
        right_layout:add(awful.titlebar.widget.maximizedbutton(c))
        right_layout:add(awful.titlebar.widget.stickybutton(c))
        right_layout:add(awful.titlebar.widget.ontopbutton(c))
        right_layout:add(awful.titlebar.widget.closebutton(c))

        -- The title goes in the middle
        local middle_layout = wibox.layout.flex.horizontal()
        local title = awful.titlebar.widget.titlewidget(c)
        title:set_align("center")
        middle_layout:add(title)
        middle_layout:buttons(buttons)

        -- Now bring it all together
        local layout = wibox.layout.align.horizontal()
        layout:set_left(left_layout)
        layout:set_right(right_layout)
        layout:set_middle(middle_layout)

        awful.titlebar(c):set_widget(layout)
    end
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
-- }}}

-- Autostart
function run_once(prg,arg_string,pname,screen)
    if not prg then
        do return nil end
    end

    if not pname then
       pname = prg
    end

    if not arg_string then 
        awful.util.spawn_with_shell("pgrep -f -u $USER -x '" .. pname .. "' || (" .. prg .. ")",screen)
    else
        awful.util.spawn_with_shell("pgrep -f -u $USER -x '" .. pname .. "' || (" .. prg .. " " .. arg_string .. ")",screen)
    end
end

-- Startup Applications
run_once(os.getenv("HOME") .. "/bin/tptoggle")
run_once("nm-applet")
run_once("gnome-screensaver")
run_once("xmodmap ~/.xmodmaprc")
run_once("dropboxd", "", "/opt/dropbox/dropbox")
run_once("redshift -l 37.05:-78.66", "redshift -l 37.05 -78.66")

