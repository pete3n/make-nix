# Awesome WM configuration
{ pkgs, ... }:
# TODO: Build in to an actual Nix module with configuration options
let
  rcFileContents = # lua
    ''
      -- If LuaRocks is installed, make sure that packages installed through it are
      -- found (e.g. lgi). If LuaRocks is not installed, do nothing.
      pcall(require, "luarocks.loader")

      -- Standard awesome library
      local gears = require("gears")
      local awful = require("awful")
      require("awful.autofocus")
      -- Widget and layout library
      local wibox = require("wibox")
      -- Theme handling library
      local beautiful = require("beautiful")
      -- Notification library
      local naughty = require("naughty")
      local menubar = require("menubar")
      local hotkeys_popup = require("awful.hotkeys_popup")
      -- Enable hotkeys help widget for VIM and other apps
      -- when client with a matching name is opened:
      require("awful.hotkeys_popup.keys")

      -- {{{ Error handling
      -- Check if awesome encountered an error during startup and fell back to
      -- another config (This code will only ever execute for the fallback config)
      if awesome.startup_errors then
      	naughty.notify({
      		preset = naughty.config.presets.critical,
      		title = "Oops, there were errors during startup!",
      		text = awesome.startup_errors,
      	})
      end

      -- Handle runtime errors after startup
      do
      	local in_error = false
      	awesome.connect_signal("debug::error", function(err)
      		-- Make sure we don't go into an endless error loop
      		if in_error then
      			return
      		end
      		in_error = true

      		naughty.notify({
      			preset = naughty.config.presets.critical,
      			title = "Oops, an error happened!",
      			text = tostring(err),
      		})
      		in_error = false
      	end)
      end
      -- }}}

      -- {{{ Variable definitions
      -- Themes define colours, icons, font and wallpapers.
      beautiful.init(gears.filesystem.get_themes_dir() .. "default/theme.lua")

      -- Enable gaps
      beautiful.useless_gap = 4
      beautiful.gap_single_client = true

      -- Borders
      beautiful.border_width = 2
      beautiful.border_focus = "#0066FF"
      beautiful.border_normal = "#595959"

      -- This is used later as the default terminal and editor to run.
      terminal = "alacritty"
      editor = os.getenv("EDITOR") or "nano"
      editor_cmd = terminal .. " -e " .. editor

      -- Default modkey.
      -- Usually, Mod4 is the key with a logo between Control and Alt.
      -- If you do not like this or do not have such a key,
      -- I suggest you to remap Mod4 to another key using xmodmap or other tools.
      -- However, you can use another modifier like Mod1, but it may interact with others.
      modkey = "Mod4"

      -- Table of layouts to cover with awful.layout.inc, order matters.
      awful.layout.layouts = {
      	awful.layout.suit.fair,
      	awful.layout.suit.tile,
      	awful.layout.suit.floating,
      	-- awful.layout.suit.spiral.dwindle,
      	-- awful.layout.suit.spiral,
      	-- awful.layout.suit.tile.bottom,
      	-- awful.layout.suit.tile.left,
      	-- awful.layout.suit.tile.bottom,
      	-- awful.layout.suit.tile.top,
      	-- awful.layout.suit.fair.horizontal,
      	-- awful.layout.suit.max,
      	-- awful.layout.suit.max.fullscreen,
      	-- awful.layout.suit.magnifier,
      	-- awful.layout.suit.corner.nw,
      	-- awful.layout.suit.corner.ne,
      	-- awful.layout.suit.corner.sw,
      	-- awful.layout.suit.corner.se,
      }
      -- }}}

      -- {{{ Menu
      -- Create a launcher widget and a main menu
      myawesomemenu = {
      	{
      		"hotkeys",
      		function()
      			hotkeys_popup.show_help(nil, awful.screen.focused())
      		end,
      	},
      	{ "manual", terminal .. " -e man awesome" },
      	{ "edit config", editor_cmd .. " " .. awesome.conffile },
      	{ "restart", awesome.restart },
      	{
      		"quit",
      		function()
      			awesome.quit()
      		end,
      	},
      }

      mymainmenu = awful.menu({
      	items = {
      		{ "awesome", myawesomemenu, beautiful.awesome_icon },
      		{ "open terminal", terminal },
      	},
      })

      mylauncher = awful.widget.launcher({ image = beautiful.awesome_icon, menu = mymainmenu })

      -- Menubar configuration
      menubar.utils.terminal = terminal -- Set the terminal for applications that require it
      -- }}}

      -- Keyboard map indicator and switcher
      mykeyboardlayout = awful.widget.keyboardlayout()

      -- {{{ Wibar
      -- Create a textclock widget
      mytextclock = wibox.widget.textclock()

      -- Create a wibox for each screen and add it
      local taglist_buttons = gears.table.join(
      	awful.button({}, 1, function(t)
      		t:view_only()
      	end),
      	awful.button({ modkey }, 1, function(t)
      		if client.focus then
      			client.focus:move_to_tag(t)
      		end
      	end),
      	awful.button({}, 3, awful.tag.viewtoggle),
      	awful.button({ modkey }, 3, function(t)
      		if client.focus then
      			client.focus:toggle_tag(t)
      		end
      	end),
      	awful.button({}, 4, function(t)
      		awful.tag.viewnext(t.screen)
      	end),
      	awful.button({}, 5, function(t)
      		awful.tag.viewprev(t.screen)
      	end)
      )

      local tasklist_buttons = gears.table.join(
      	awful.button({}, 1, function(c)
      		if c == client.focus then
      			c.minimized = true
      		else
      			c:emit_signal("request::activate", "tasklist", { raise = true })
      		end
      	end),
      	awful.button({}, 3, function()
      		awful.menu.client_list({ theme = { width = 250 } })
      	end),
      	awful.button({}, 4, function()
      		awful.client.focus.byidx(1)
      	end),
      	awful.button({}, 5, function()
      		awful.client.focus.byidx(-1)
      	end)
      )

      local function set_wallpaper(s)
      	-- Set random wallpaper for up to 3 screens
      	-- Hardcoded with ~/wallpapers
      	awful.spawn.with_shell(
      		"feh --randomize --bg-fill ~/wallpapers/*.{png,jpg,jpeg} ~/wallpapers/*.{png,jpg,jpeg} ~/wallpapers/*.{png,jpg,jpeg}"
      	)
      end

      -- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
      screen.connect_signal("property::geometry", set_wallpaper)

      awful.screen.connect_for_each_screen(function(s)
      	-- Wallpaper
      	set_wallpaper(s)

      	-- Each screen has its own tag table.
      	awful.tag({ "1", "2", "3", "4", "5", "6", "7", "8", "9" }, s, awful.layout.layouts[1])

      	-- Create a promptbox for each screen
      	s.mypromptbox = awful.widget.prompt()
      	-- Create an imagebox widget which will contain an icon indicating which layout we're using.
      	-- We need one layoutbox per screen.
      	s.mylayoutbox = awful.widget.layoutbox(s)
      	s.mylayoutbox:buttons(gears.table.join(
      		awful.button({}, 1, function()
      			awful.layout.inc(1)
      		end),
      		awful.button({}, 3, function()
      			awful.layout.inc(-1)
      		end),
      		awful.button({}, 4, function()
      			awful.layout.inc(1)
      		end),
      		awful.button({}, 5, function()
      			awful.layout.inc(-1)
      		end)
      	))
      	-- Create a taglist widget
      	s.mytaglist = awful.widget.taglist({
      		screen = s,
      		filter = awful.widget.taglist.filter.all,
      		buttons = taglist_buttons,
      	})

      	-- Create a tasklist widget
      	s.mytasklist = awful.widget.tasklist({
      		screen = s,
      		filter = awful.widget.tasklist.filter.currenttags,
      		buttons = tasklist_buttons,
      	})

      	-- Create the wibox - Start hidden by default
      	s.mywibox = awful.wibar({ position = "top", screen = s, visible = false })

      	-- Add widgets to the wibox
      	s.mywibox:setup({
      		layout = wibox.layout.align.horizontal,
      		{ -- Left widgets
      			layout = wibox.layout.fixed.horizontal,
      			mylauncher,
      			s.mytaglist,
      			s.mypromptbox,
      		},
      		s.mytasklist, -- Middle widget
      		{ -- Right widgets
      			layout = wibox.layout.fixed.horizontal,
      			mykeyboardlayout,
      			wibox.widget.systray(),
      			mytextclock,
      			s.mylayoutbox,
      		},
      	})
      end)
      -- }}}

      -- {{{ Mouse bindings
      root.buttons(gears.table.join(
      	awful.button({}, 3, function()
      		mymainmenu:toggle()
      	end),
      	awful.button({}, 4, awful.tag.viewnext),
      	awful.button({}, 5, awful.tag.viewprev)
      ))
      -- }}}

      -- {{{ Key bindings
      globalkeys = gears.table.join(
      	awful.key({ modkey }, "s", function()
      		awful.util.spawn("tdrop -am -w 60% -y 30% -x 20% alacritty")
      	end, { description = "open alacritty scratch terminal", group = "launcher" }),


      	awful.key({ modkey }, "b", hotkeys_popup.show_help, { description = "show bindings", group = "awesome" }),
      	awful.key({ modkey }, "Left", awful.tag.viewprev, { description = "view previous", group = "tag" }),
      	awful.key({ modkey }, "Right", awful.tag.viewnext, { description = "view next", group = "tag" }),
      	awful.key({ modkey }, "Escape", awful.tag.history.restore, { description = "go back", group = "tag" }),

      	awful.key({ modkey }, "a", function()
      		mymainmenu:show()
      	end, { description = "show main menu", group = "awesome" }),

      	awful.key({ modkey }, "w", function()
      		myscreen = awful.screen.focused()
      		myscreen.mywibox.visible = not myscreen.mywibox.visible
      	end, { description = "toggle statusbar" }),

      	awful.key({ modkey, "Shift" }, "w", function()
      		local s = awful.screen.focused()
      		set_wallpaper(s)
      	end, { description = "change random wallpaper", group = "custom" }),

      	-- Layout manipulation

      	-- Swap with the client on the left
      	awful.key({ modkey, "Shift" }, "h", function()
      		awful.client.swap.bydirection("left")
      	end, { description = "swap with left client", group = "client" }),

      	-- Swap with the client below (down)
      	awful.key({ modkey, "Shift" }, "j", function()
      		awful.client.swap.bydirection("down")
      	end, { description = "swap with down client", group = "client" }),

      	-- Swap with the client above (up)
      	awful.key({ modkey, "Shift" }, "k", function()
      		awful.client.swap.bydirection("up")
      	end, { description = "swap with up client", group = "client" }),

      	-- Swap with the client on the right
      	awful.key({ modkey, "Shift" }, "l", function()
      		awful.client.swap.bydirection("right")
      	end, { description = "swap with right client", group = "client" }),

      	-- Move focus to the client on the left
      	awful.key({ modkey }, "h", function()
      		awful.client.focus.bydirection("left")
      		if client.focus then
      			client.focus:raise()
      		end
      	end, { description = "focus left", group = "client" }),

      	-- Move focus to the client below (down)
      	awful.key({ modkey }, "j", function()
      		awful.client.focus.bydirection("down")
      		if client.focus then
      			client.focus:raise()
      		end
      	end, { description = "focus down", group = "client" }),

      	-- Move focus to the client above (up)
      	awful.key({ modkey }, "k", function()
      		awful.client.focus.bydirection("up")
      		if client.focus then
      			client.focus:raise()
      		end
      	end, { description = "focus up", group = "client" }),

      	-- Move focus to the client on the right
      	awful.key({ modkey }, "l", function()
      		awful.client.focus.bydirection("right")
      		if client.focus then
      			client.focus:raise()
      		end
      	end, { description = "focus right", group = "client" }),
      	awful.key({ modkey }, "u", awful.client.urgent.jumpto, { description = "jump to urgent client", group = "client" }),
      	awful.key({ modkey }, "Tab", function()
      		awful.client.focus.history.previous()
      		if client.focus then
      			client.focus:raise()
      		end
      	end, { description = "go back", group = "client" }),

      	-- Standard program
      	awful.key({ modkey }, "Return", function()
      		awful.spawn(terminal)
      	end, { description = "open a terminal", group = "launcher" }),
      	awful.key({ modkey, "Control" }, "r", awesome.restart, { description = "reload awesome", group = "awesome" }),
      	awful.key({ modkey, "Shift" }, "q", awesome.quit, { description = "quit awesome", group = "awesome" }),

      	awful.key({ modkey }, "l", function()
      		awful.tag.incmwfact(0.05)
      	end, { description = "increase master width factor", group = "layout" }),
      	awful.key({ modkey }, "h", function()
      		awful.tag.incmwfact(-0.05)
      	end, { description = "decrease master width factor", group = "layout" }),
      	awful.key({ modkey, "Shift" }, "h", function()
      		awful.tag.incnmaster(1, nil, true)
      	end, { description = "increase the number of master clients", group = "layout" }),
      	awful.key({ modkey, "Shift" }, "l", function()
      		awful.tag.incnmaster(-1, nil, true)
      	end, { description = "decrease the number of master clients", group = "layout" }),
      	awful.key({ modkey, "Control" }, "h", function()
      		awful.tag.incncol(1, nil, true)
      	end, { description = "increase the number of columns", group = "layout" }),
      	awful.key({ modkey, "Control" }, "l", function()
      		awful.tag.incncol(-1, nil, true)
      	end, { description = "decrease the number of columns", group = "layout" }),
      	awful.key({ modkey }, "space", function()
      		awful.layout.inc(1)
      	end, { description = "select next", group = "layout" }),
      	awful.key({ modkey, "Shift" }, "space", function()
      		awful.layout.inc(-1)
      	end, { description = "select previous", group = "layout" }),

      	awful.key({ modkey, "Control" }, "n", function()
      		local c = awful.client.restore()
      		-- Focus restored client
      		if c then
      			c:emit_signal("request::activate", "key.unminimize", { raise = true })
      		end
      	end, { description = "restore minimized", group = "client" }),

      	-- Prompt
      	awful.key({ modkey }, "r", function()
      		awful.util.spawn("sh -c 'rofi -show-icons -combi-modi drun,run -show combi'")
      	end, { description = "run rofi in combi mode", group = "launcher" }),

      	awful.key({ modkey }, "x", function()
      		awful.prompt.run({
      			prompt = "Run Lua code: ",
      			textbox = awful.screen.focused().mypromptbox.widget,
      			exe_callback = awful.util.eval,
      			history_path = awful.util.get_cache_dir() .. "/history_eval",
      		})
      	end, { description = "lua execute prompt", group = "awesome" }),
      	-- Menubar
      	awful.key({ modkey }, "p", function()
      		menubar.show()
      	end, { description = "show the menubar", group = "launcher" })
      )

      clientkeys = gears.table.join(
      	awful.key({ modkey }, "f", function(c)
      		c.fullscreen = not c.fullscreen
      		c:raise()
      	end, { description = "toggle fullscreen", group = "client" }),
      	awful.key({ modkey }, "c", function(c)
      		c:kill()
      	end, { description = "close", group = "client" }),
      	awful.key(
      		{ modkey, "Control" },
      		"space",
      		awful.client.floating.toggle,
      		{ description = "toggle floating", group = "client" }
      	),
      	awful.key({ modkey, "Control" }, "Return", function(c)
      		c:swap(awful.client.getmaster())
      	end, { description = "move to master", group = "client" }),
      	awful.key({ modkey, "Shift" }, "o", function(c)
      		c:move_to_screen()
      	end, { description = "move to screen", group = "client" }),
      	awful.key({ modkey, 				}, "o", function()
      		awful.screen.focus_relative(1)
      	end, { description = "shift focus to next screen", group = "screen" }),
      	awful.key({ modkey, "Control" }, "o", function()
      		awful.screen.focus_relative(-1)
      	end, { description = "shift focus to previous screen", group = "screen" }),
      	awful.key({ modkey }, "t", function(c)
      		c.ontop = not c.ontop
      	end, { description = "toggle keep on top", group = "client" }),
      	awful.key({ modkey }, "n", function(c)
      		-- The client currently has the input focus, so it cannot be
      		-- minimized, since minimized clients can't have the focus.
      		c.minimized = true
      	end, { description = "minimize", group = "client" }),
      	awful.key({ modkey }, "m", function(c)
      		c.maximized = not c.maximized
      		c:raise()
      	end, { description = "(un)maximize", group = "client" }),
      	awful.key({ modkey, "Control" }, "m", function(c)
      		c.maximized_vertical = not c.maximized_vertical
      		c:raise()
      	end, { description = "(un)maximize vertically", group = "client" }),
      	awful.key({ modkey, "Shift" }, "m", function(c)
      		c.maximized_horizontal = not c.maximized_horizontal
      		c:raise()
      	end, { description = "(un)maximize horizontally", group = "client" })
      )

      -- Bind all key numbers to tags.
      -- Be careful: we use keycodes to make it work on any keyboard layout.
      -- This should map on the top row of your keyboard, usually 1 to 9.
      for i = 1, 9 do
      	globalkeys = gears.table.join(
      		globalkeys,
      		-- View tag only.
      		awful.key({ modkey }, "#" .. i + 9, function()
      			local screen = awful.screen.focused()
      			local tag = screen.tags[i]
      			if tag then
      				tag:view_only()
      			end
      		end, { description = "view tag #" .. i, group = "tag" }),
      		-- Toggle tag display.
      		awful.key({ modkey, "Control" }, "#" .. i + 9, function()
      			local screen = awful.screen.focused()
      			local tag = screen.tags[i]
      			if tag then
      				awful.tag.viewtoggle(tag)
      			end
      		end, { description = "toggle tag #" .. i, group = "tag" }),
      		-- Move client to tag.
      		awful.key({ modkey, "Shift" }, "#" .. i + 9, function()
      			if client.focus then
      				local tag = client.focus.screen.tags[i]
      				if tag then
      					client.focus:move_to_tag(tag)
      				end
      			end
      		end, { description = "move focused client to tag #" .. i, group = "tag" }),
      		-- Toggle tag on focused client.
      		awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9, function()
      			if client.focus then
      				local tag = client.focus.screen.tags[i]
      				if tag then
      					client.focus:toggle_tag(tag)
      				end
      			end
      		end, { description = "toggle focused client on tag #" .. i, group = "tag" })
      	)
      end

      clientbuttons = gears.table.join(
      	awful.button({}, 1, function(c)
      		c:emit_signal("request::activate", "mouse_click", { raise = true })
      	end),
      	awful.button({ modkey }, 1, function(c)
      		c:emit_signal("request::activate", "mouse_click", { raise = true })
      		awful.mouse.client.move(c)
      	end),
      	awful.button({ modkey }, 3, function(c)
      		c:emit_signal("request::activate", "mouse_click", { raise = true })
      		awful.mouse.client.resize(c)
      	end)
      )

      -- Set keys
      root.keys(globalkeys)
      -- }}}

      -- {{{ Rules
      -- Rules to apply to new clients (through the "manage" signal).
      awful.rules.rules = {
      	-- All clients will match this rule.
      	{
      		rule = {},
      		properties = {
      			border_width = beautiful.border_width,
      			border_color = beautiful.border_normal,
      			focus = awful.client.focus.filter,
      			raise = true,
      			keys = clientkeys,
      			buttons = clientbuttons,
      			screen = awful.screen.preferred,
      			placement = awful.placement.no_overlap + awful.placement.no_offscreen,
      		},
      	},

      	-- Floating clients.
      	{
      		rule_any = {
      			instance = {
      				"DTA", -- Firefox addon DownThemAll.
      				"copyq", -- Includes session name in class.
      				"pinentry",
      			},
      			class = {
      				"Arandr",
      				"Blueman-manager",
      				"Gpick",
      				"Kruler",
      				"MessageWin", -- kalarm.
      				"Sxiv",
      				"Tor Browser", -- Needs a fixed window size to avoid fingerprinting by screen size.
      				"Wpa_gui",
      				"veromix",
      				"xtightvncviewer",
      			},

      			-- Note that the name property shown in xprop might be set slightly after creation of the client
      			-- and the name shown there might not match defined rules here.
      			name = {
      				"Event Tester", -- xev.
      			},
      			role = {
      				"AlarmWindow", -- Thunderbird's calendar.
      				"ConfigManager", -- Thunderbird's about:config.
      				"pop-up", -- e.g. Google Chrome's (detached) Developer Tools.
      			},
      		},
      		properties = { floating = true },
      	},

      	-- Add titlebars to normal clients and dialogs (HIDDEN)
      	{
      		rule_any = { type = { "normal", "dialog" } },
      		properties = { titlebars_enabled = false },
      	},

      	-- Set Firefox to always map on the tag named "2" on screen 1.
      	-- { rule = { class = "Firefox" },
      	--   properties = { screen = 1, tag = "2" } },
      }
      -- }}}

      -- {{{ Signals
      -- Signal function to execute when a new client appears.
      client.connect_signal("manage", function(c)
      	-- Set the windows at the slave,
      	-- i.e. put it at the end of others instead of setting it master.
      	-- if not awesome.startup then awful.client.setslave(c) end

      	if awesome.startup and not c.size_hints.user_position and not c.size_hints.program_position then
      		-- Prevent clients from being unreachable after screen count changes.
      		awful.placement.no_offscreen(c)
      	end
      end)

      -- Add a titlebar if titlebars_enabled is set to true in the rules.
      client.connect_signal("request::titlebars", function(c)
      	-- buttons for the titlebar
      	local buttons = gears.table.join(
      		awful.button({}, 1, function()
      			c:emit_signal("request::activate", "titlebar", { raise = true })
      			awful.mouse.client.move(c)
      		end),
      		awful.button({}, 3, function()
      			c:emit_signal("request::activate", "titlebar", { raise = true })
      			awful.mouse.client.resize(c)
      		end)
      	)

      	awful.titlebar(c):setup({
      		{ -- Left
      			awful.titlebar.widget.iconwidget(c),
      			buttons = buttons,
      			layout = wibox.layout.fixed.horizontal,
      		},
      		{ -- Middle
      			{ -- Title
      				align = "center",
      				widget = awful.titlebar.widget.titlewidget(c),
      			},
      			buttons = buttons,
      			layout = wibox.layout.flex.horizontal,
      		},
      		{ -- Right
      			awful.titlebar.widget.floatingbutton(c),
      			awful.titlebar.widget.maximizedbutton(c),
      			awful.titlebar.widget.stickybutton(c),
      			awful.titlebar.widget.ontopbutton(c),
      			awful.titlebar.widget.closebutton(c),
      			layout = wibox.layout.fixed.horizontal(),
      		},
      		layout = wibox.layout.align.horizontal,
      	})
      end)

      -- Enable sloppy focus, so that focus follows mouse.
      --client.connect_signal("mouse::enter", function(c)
      --    c:emit_signal("request::activate", "mouse_enter", {raise = false})
      --end)

      -- Set borders on focus
      client.connect_signal("focus", function(c)
      	c.border_color = beautiful.border_focus
      end)
      client.connect_signal("unfocus", function(c)
      	c.border_color = beautiful.border_normal
      end)
      -- }}}

      -- Autostart apps
      awful.spawn.with_shell("picom")
      -- awful.spawn.with_shell("setTouchpad")
    '';

  default_theme = # lua
    ''
      local theme_assets = require("beautiful.theme_assets")
      local xresources = require("beautiful.xresources")
      local dpi = xresources.apply_dpi

      local gfs = require("gears.filesystem")
      local themes_path = gfs.get_themes_dir()

      local theme = {}

      theme.font          = "JetBrains Mono 8"

      theme.bg_normal     = "#222222"
      theme.bg_normal_alpha = 0.8
      theme.bg_focus      = "#535d6c"
      theme.bg_urgent     = "#ff0000"
      theme.bg_minimize   = "#444444"
      theme.bg_systray    = theme.bg_normal

      theme.fg_normal     = "#aaaaaa"
      theme.fg_focus      = "#ffffff"
      theme.fg_urgent     = "#ffffff"
      theme.fg_minimize   = "#ffffff"

      theme.useless_gap   = dpi(3)
      theme.border_width  = dpi(5)
      theme.border_normal = "#000000"
      theme.border_focus  = "#7ebae4"
      theme.border_marked = "#91231c"

      -- Systray
      theme.systray_transparency = 0.8

      -- There are other variable sets
      -- overriding the default one when
      -- defined, the sets are:
      -- taglist_[bg|fg]_[focus|urgent|occupied|empty|volatile]
      -- tasklist_[bg|fg]_[focus|urgent]
      -- titlebar_[bg|fg]_[normal|focus]
      -- tooltip_[font|opacity|fg_color|bg_color|border_width|border_color]
      -- mouse_finder_[color|timeout|animate_timeout|radius|factor]
      -- prompt_[fg|bg|fg_cursor|bg_cursor|font]
      -- hotkeys_[bg|fg|border_width|border_color|shape|opacity|modifiers_fg|label_bg|label_fg|group_margin|font|description_font]
      -- Example:
      --theme.taglist_bg_focus = "#ff0000"

      -- Generate taglist squares:
      local taglist_square_size = dpi(4)
      theme.taglist_squares_sel = theme_assets.taglist_squares_sel(
          taglist_square_size, theme.fg_normal
      )
      theme.taglist_squares_unsel = theme_assets.taglist_squares_unsel(
          taglist_square_size, theme.fg_normal
      )

      -- Variables set for theming notifications:
      -- notification_font
      -- notification_[bg|fg]
      -- notification_[width|height|margin]
      -- notification_[border_color|border_width|shape|opacity]

      -- Variables set for theming the menu:
      -- menu_[bg|fg]_[normal|focus]
      -- menu_[border_color|border_width]
      theme.menu_submenu_icon = themes_path.."default/submenu.png"
      theme.menu_height = dpi(15)
      theme.menu_width  = dpi(100)

      -- You can add as many variables as
      -- you wish and access them by using
      -- beautiful.variable in your rc.lua
      --theme.bg_widget = "#cc0000"

      -- Define the image to load
      theme.titlebar_close_button_normal = themes_path.."default/titlebar/close_normal.png"
      theme.titlebar_close_button_focus  = themes_path.."default/titlebar/close_focus.png"

      theme.titlebar_minimize_button_normal = themes_path.."default/titlebar/minimize_normal.png"
      theme.titlebar_minimize_button_focus  = themes_path.."default/titlebar/minimize_focus.png"

      theme.titlebar_ontop_button_normal_inactive = themes_path.."default/titlebar/ontop_normal_inactive.png"
      theme.titlebar_ontop_button_focus_inactive  = themes_path.."default/titlebar/ontop_focus_inactive.png"
      theme.titlebar_ontop_button_normal_active = themes_path.."default/titlebar/ontop_normal_active.png"
      theme.titlebar_ontop_button_focus_active  = themes_path.."default/titlebar/ontop_focus_active.png"

      theme.titlebar_sticky_button_normal_inactive = themes_path.."default/titlebar/sticky_normal_inactive.png"
      theme.titlebar_sticky_button_focus_inactive  = themes_path.."default/titlebar/sticky_focus_inactive.png"
      theme.titlebar_sticky_button_normal_active = themes_path.."default/titlebar/sticky_normal_active.png"
      theme.titlebar_sticky_button_focus_active  = themes_path.."default/titlebar/sticky_focus_active.png"

      theme.titlebar_floating_button_normal_inactive = themes_path.."default/titlebar/floating_normal_inactive.png"
      theme.titlebar_floating_button_focus_inactive  = themes_path.."default/titlebar/floating_focus_inactive.png"
      theme.titlebar_floating_button_normal_active = themes_path.."default/titlebar/floating_normal_active.png"
      theme.titlebar_floating_button_focus_active  = themes_path.."default/titlebar/floating_focus_active.png"

      theme.titlebar_maximized_button_normal_inactive = themes_path.."default/titlebar/maximized_normal_inactive.png"
      theme.titlebar_maximized_button_focus_inactive  = themes_path.."default/titlebar/maximized_focus_inactive.png"
      theme.titlebar_maximized_button_normal_active = themes_path.."default/titlebar/maximized_normal_active.png"
      theme.titlebar_maximized_button_focus_active  = themes_path.."default/titlebar/maximized_focus_active.png"

      theme.wallpaper = themes_path.."default/background.png"

      -- You can use your own layout icons like this:
      theme.layout_fairh = themes_path.."default/layouts/fairhw.png"
      theme.layout_fairv = themes_path.."default/layouts/fairvw.png"
      theme.layout_floating  = themes_path.."default/layouts/floatingw.png"
      theme.layout_magnifier = themes_path.."default/layouts/magnifierw.png"
      theme.layout_max = themes_path.."default/layouts/maxw.png"
      theme.layout_fullscreen = themes_path.."default/layouts/fullscreenw.png"
      theme.layout_tilebottom = themes_path.."default/layouts/tilebottomw.png"
      theme.layout_tileleft   = themes_path.."default/layouts/tileleftw.png"
      theme.layout_tile = themes_path.."default/layouts/tilew.png"
      theme.layout_tiletop = themes_path.."default/layouts/tiletopw.png"
      theme.layout_spiral  = themes_path.."default/layouts/spiralw.png"
      theme.layout_dwindle = themes_path.."default/layouts/dwindlew.png"
      theme.layout_cornernw = themes_path.."default/layouts/cornernww.png"
      theme.layout_cornerne = themes_path.."default/layouts/cornernew.png"
      theme.layout_cornersw = themes_path.."default/layouts/cornersww.png"
      theme.layout_cornerse = themes_path.."default/layouts/cornersew.png"

      -- Generate Awesome icon:
      theme.awesome_icon = theme_assets.awesome_icon(
          theme.menu_height, theme.bg_focus, theme.fg_focus
      )

      -- Define the icon theme for application icons. If not set then the icons
      -- from /usr/share/icons and /usr/share/icons/hicolor will be used.
      theme.icon_theme = nil

      return theme

      -- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
    '';
in
{
  xdg.configFile."awesome/rc.lua".text = rcFileContents;
  xdg.configFile."awesome/themes/default/theme.lua".text = default_theme;

  home.file.".xinitrc".text = ''
    #!${pkgs.stdenv.shell}
    exec ${pkgs.awesome}/bin/awesome
  '';

  xsession.windowManager.awesome = {
    enable = true;
    luaModules = with pkgs.luaPackages; [
      luarocks
      luadbi-mysql
    ];
  };
}
