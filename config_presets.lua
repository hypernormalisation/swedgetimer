------------------------------------------------------------------------------------
-- Module to contain config default settings for the addon, per class and global
------------------------------------------------------------------------------------
local addon_name, st = ...
local LSM = LibStub("LibSharedMedia-3.0")
local ST = LibStub("AceAddon-3.0"):GetAddon(addon_name)


-- This table is used by AceDB's smart defaults feature
-- so we only have to override behaviour in class-specific tables.
ST.bar_defaults = {
    
    -- Visibility behaviour
    enabled = true,
    force_show_in_combat = true,
    hide_ooc = false, -- always overrides the other behaviours
    require_has_valid_target = true,
    require_in_range = false,

    -- Out of range behaviour
    oor_effect = "dim",
    dim_alpha = 0.6,

    -- Bar dimensions/positioning
    bar_height = 16,
    bar_width = 285,
    bar_locked = true,
    bar_x_offset = 0,
    bar_y_offset = -124,
    bar_point = "CENTER",
    bar_rel_point = "CENTER",

    -- Bar appearance
    bar_texture_key = "Solid",
    border_texture_key = "None",
    bar_color_default = {137, 56, 27, 0.6},

    -- Backplane and border
    backplane_alpha = 0.85,
    backplane_texture_key = "Solid",
    border_mode_key = "Solid",
    backplane_outline_width = 1.5,

    -- Fonts
    font_size = 12,
    font_color = {1.0, 1.0, 1.0, 1.0},
    text_font = "PT Sans Narrow",
    font_outline_key = "outline",
    left_text = "attack_speed",
    right_text = "swing_timer",

    -- GCD underlay
    gcd = {
        test1 = 'the default',
        test2 = 'another default',
    },
    show_gcd_underlay = true,
    bar_color_gcd = {0.42, 0.42, 0.42, 0.8},
    gcd_texture_key = "Solid",

    -- GCD markers
    gcd1_marker_enabled = true,
    gcd2_marker_enabled = false,
    gcd_marker_width = 3,
    gcd_marker_color = {230, 230, 230, 1.0},

    -- Deadzone settings
    enable_deadzone = false,
    deadzone_texture_key = "Solid",
    deadzone_bar_color = {131, 9, 41, 0.62},

    -- Show range
    show_range_finder = false,
}

------------------------------------------------------------------------------------
-- ROGUE
------------------------------------------------------------------------------------
ST.ROGUE = {}
ST.ROGUE.defaults = {

    tag = "ROGUE",

    -- Inherit defaults
    ['**'] = ST.bar_defaults,

	-- Mainhand options
	mainhand = {
        enable_deadzone = true,
    },

	-- Offhand options
	offhand = {
		bar_x_offset = 0,
		bar_y_offset = -144,
		bar_color_default = {1, 66, 69, 0.8},
        show_gcd_underlay = false,
	},

	-- Ranged options
	ranged = {
        require_in_range = true,
        force_show_in_combat = false,
		bar_height = 13,
		bar_width = 200,
		bar_x_offset = 0,
		bar_y_offset = -102,
		bar_color_default = {115, 17, 42, 0.8},
		font_size = 11,
        show_gcd_underlay = false,
        show_gcd_markers = false,
        show_range_finder = true,
	},
}

------------------------------------------------------------------------------------
-- DRUID
------------------------------------------------------------------------------------
ST.DRUID = {}
ST.DRUID.defaults = {
    tag = "ROGUE",
    ['**'] = ST.bar_defaults,
}
--=========================================================================================
-- End, if debug verify module was read.
--=========================================================================================
if st.debug then print('-- Parsed config_presets.lua module correctly') end