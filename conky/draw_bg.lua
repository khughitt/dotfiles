ckground by londonali1010 (2009)
	VinDSL Background Hack (2010-2011)

This script draws a background to the Conky window. It covers the whole of the Conky window, but you can specify rounded corners, if you wish.

To call this script in Conky, use (assuming you have saved this script to ~/scripts/):
	lua_load ~/scripts/draw_bg.lua
	lua_draw_hook_pre draw_bg

Changelog:
	+ v3.1	VinDSL Hack (12.01.2011) Added more shading example(s).
	+ v3.0	VinDSL Hack (01.28.2011) Killed memory leak.
	+ v2.4	VinDSL Hack (01.25.2011) Declared all variables in local.
	+ v2.3	VinDSL Hack (12.31.2010) Added shading example(s).
	+ v2.2	VinDSL Hack (12.30.2010) Cleaned up the code a bit.
	+ v2.1	VinDSL Hack (12.24.2010) Added cairo destroy function(s).
	+ v2.0	VinDSL Hack (12.21.2010) Added height adjustment variable.
	+ v1.0	Original release (07.10.2009)

]]

--------------START OF PARAMETERS ------------
-- Change these settings to affect your background:

-- "corner_r" is the radius, in pixels, of the rounded corners. If you don't want rounded corners, use 0.

	local corner_r = 50

-- Set the colour and transparency (alpha) of your background (0.00 - 0.99).

--	(Light Shading Example)
--	local bg_colour = 0x4d4d4d
--	local bg_alpha = 0.50

--	(Medium Shading Example)
--	local bg_colour = 0x222222
--	local bg_alpha = 0.50

--	(Dark Shading Example)
--	local bg_colour = 0x000000
--	local bg_alpha = 0.02

--	(Brown Shading Example)
--	local bg_colour = 0x330000
--	local bg_alpha = 0.04

--	(Ivory Black Shading Example)
--	local bg_colour = 0x292421
--	local bg_alpha = 0.22

--	(Navy Blue Shading Example)
--	local bg_colour = 0x33339F
--	local bg_alpha = 0.33

--	(Olive Green Shading Example)
--	local bg_colour = 0x333319
--	local bg_alpha = 0.13

--	(Silver Shading Example)
	local bg_colour = 0xc0c0c0
	local bg_alpha = 0.1

-- Tweaks the height of your background, in pixels. If you don't need to adjust the height, use 0.

--	(Default Setting)
--	local vindsl_hack_height = 0

	local vindsl_hack_height = -2
---------------END OF PARAMETERS -------------

require 'cairo'
local	cs, cr = nil

local function rgb_to_r_g_b(colour,alpha)
	return ((colour / 0x10000) % 0x100) / 255., ((colour / 0x100) % 0x100) / 255., (colour % 0x100) / 255., alpha
	end

function conky_draw_bg()
	if conky_window == nil then return end
	if cs == nil then cairo_surface_destroy(cs) end
	if cr == nil then cairo_destroy(cr) end
	local w = conky_window.width
	local h = conky_window.height
	local v = vindsl_hack_height
	local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
	local cr = cairo_create(cs)
	
	cairo_move_to(cr,corner_r,0)
	cairo_line_to(cr,w-corner_r,0)
	cairo_curve_to(cr,w,0,w,0,w,corner_r)
	cairo_line_to(cr,w,h+v-corner_r)
	cairo_curve_to(cr,w,h+v,w,h+v,w-corner_r,h+v)
	cairo_line_to(cr,corner_r,h+v)
	cairo_curve_to(cr,0,h+v,0,h+v,0,h+v-corner_r)
	cairo_line_to(cr,0,corner_r)
	cairo_curve_to(cr,0,0,0,0,corner_r,0)
	cairo_close_path(cr)

	cairo_set_source_rgba(cr,rgb_to_r_g_b(bg_colour,bg_alpha))
	cairo_fill(cr)

	cairo_surface_destroy(cs)
	cairo_destroy(cr)
	end
