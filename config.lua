------------------------------------------------------------------------------------
-- Module to contain config default
------------------------------------------------------------------------------------
local addon_name, st = ...
local LSM = LibStub("LibSharedMedia-3.0")
local ST = LibStub("AceAddon-3.0"):GetAddon(addon_name)
-- local print = st.utils.print_msg

------------------------------------------------------------------------------------
-- Default settings for the addon.
ST.defaults = {

	profile = {

		-- Top level
		welcome_message = true,
		bars_locked = true,
		enabled = true, -- top level control

		-- Frame strata/draw level
		frame_strata = "MEDIUM",
		draw_level = 10,

		-- Bar visual behaviour
		bar_full_delay = 0.3,

		-- Latency scale factors.
		latency_linear_offset = 0.0,
		latency_scale_factor = 1.0,

		-- GCD marker offsets
		gcd_marker_offset_mode = "None",
		gcd_marker_offset_scale_factor = 1.0,
		gcd_marker_fixed_offset = 100,

		-- Deadzone
		deadzone_scale_factor = 1.4,

		-- Class-specific defaults
		['**'] = ST.class_defaults,
		DEATHKNIGHT = ST.DEATHKNIGHT.defaults,
		DRUID = ST.DRUID.defaults,
		HUNTER = ST.HUNTER.defaults,
		MAGE = ST.MAGE.defaults,
		PALADIN = ST.PALADIN.defaults,
		PRIEST = ST.PRIEST.defaults,
		ROGUE = ST.ROGUE.defaults,
		SHAMAN = ST.SHAMAN.defaults,
		WARLOCK = ST.WARLOCK.defaults,
		WARRIOR = ST.WARRIOR.defaults,
    },

}

--=========================================================================================
-- Functions to handle options
--=========================================================================================

function ST:convert_color(t, new_alpha)
	-- Convert standard 0-255 colors down to WoW 0-1 ranges.
	local r,g,b,a = unpack(t)
	a = new_alpha or a
	r = r/255
	g = g/255
	b = b/255
	return r, g, b, a
end

function ST:convert_color_up(t, new_alpha)
	-- Convert WoW 0-1 ranges up to standard 0-255 ranges.
	local r,g,b,a = unpack(t)
	a = new_alpha or a
	r = r * 255
	g = g * 255
	b = b * 255
	return r, g, b, a
end

local contextual_visibility_values = {
	in_combat = "In Combat",
	has_attackable_target = "Has Attackable Target",
	in_range = "In Range of Target",
}

local outline_map = {
	_none="",
	outline="OUTLINE",
	thick_outline="THICKOUTLINE",
}
ST.outline_map = outline_map

local bar_border_modes = {
	Solid="Solid",
	Texture="Texture",
	None="None",
}

ST.outlines = {
	_none="None",
	outline="Outline",
	thick_outline="Thick Outline",
}

ST.texts = {
	attack_speed="Attack speed",
	swing_timer="Swing timer",
}

local gcd_padding_modes = {
	Dynamic="Dynamic",
	Fixed="Fixed",
	None="None",
}

local valid_anchor_points = {
	TOPLEFT="TOPLEFT",
    TOPRIGHT="TOPRIGHT",
    BOTTOMLEFT="BOTTOMLEFT",
    BOTTOMRIGHT="BOTTOMRIGHT",
    TOP="TOP",
    BOTTOM="BOTTOM",
    LEFT="LEFT",
    RIGHT="RIGHT",
    CENTER="CENTER",
}

--=========================================================================================
-- The top-level opts that apply across classes.
--=========================================================================================
local top_level_opts = {
	-- top-top level opts? silly name
	top_header = {
		type = "header",
		order = 0.1,
		name = "Top Level Options"
	},
	bar_enabled = {
		type = "toggle",
		order = 1,
		name = "Enabled",
		desc = "Enables or disables SwedgeTimer.",
		get = "GetValue",
		set = "SetValue",
	},
	welcome_message = {
		type = "toggle",
		order = 1.1,
		name = "Welcome message",
		desc = "Displays a login message showing the addon version on player login or reload.",
		get = "GetValue",
		set = "SetValue",
	},
	bar_full_delay = {
		type = "range",
		order = 1.2,
		name = "Bar Full Visual Delay (s)",
		desc = "SwedgeTimer allows for different bar configurations when the swing timer bar is " ..
			"full or filling. A delay can be set to prevent these states rapidaly changing during normal " ..
			"combat.",
		get = "GetValue",
		set = "SetValue",
		min = 0, max = 1.0, step = 0.01,
	},

	-- Latency opts
	top_latency_header = {
		type = "header",
		order = 2.0,
		name = "Latency Options"
	},
	top_latency_desc = {
		type = "description",
		order = 2.1,
		name = "These options control latency adjustments in SwedgeTimer's time-sensitive elements.",
	},
	gcd_padding_mode = {
		order=8,
		type="select",
		values=gcd_padding_modes,
		style="dropdown",
		desc="The type of GCD offset, if any, to use.",
		name="GCD offset mode",
		get = "GetValue",
		set = function(self, key)
			ST.db.profile.gcd_padding_mode=key
			st.bar.set_gcd_marker_offsets()
		end,
	},
}


ST.options = {
	type = "group",
	name = addon_name,
	handler = ST,
	args = {
		top_level = {
			name = "Global Options",
			type = "group",
			args = top_level_opts,
			-- args = {
			-- 	some_group = {
			-- 		name = "Test",
			-- 		type = "group",
			-- 		args = top_level_opts,
			-- 	},
			-- 	-- some_other_group = {
			-- 	-- 	name = "Test2",
			-- 	-- 	type = "group",
			-- 	-- 	args = top_level_opts,
			-- 	-- },
			-- }
		},
	}
}

local old_opts = {
	type = "group",
	name = addon_name,
	handler = ST,
	args = {

		------------------------------------------------------------------------------------
		-- top-level settings
		welcome_message = {
			type = "toggle",
			order = 1.1,
			name = "Welcome message",
			desc = "Displays a login message showing the addon version on player login or reload.",
			get = "GetValue",
			set = "SetValue",
		},
		bar_enabled = {
			type = "toggle",
			order = 1,
			name = "Enabled",
			desc = "Enables or disables SwedgeTimer.",
			get = "GetValue",
			set = "SetValue",
		},

		bar_locked = {
			type = "toggle",
			order = 1.12,
			name = "Bar locked",
			desc = "Prevents the swing bar from being dragged with the mouse.",
			get = "GetValue",
			set = function(self, input)
				ST.db.profile.bar_locked = input
				st.bar.frame:SetMovable(not input)
				st.bar.frame:EnableMouse(not input)
			end,
		},

		------------------------------------------------------------------------------------
		-- addon feature behaviour
		bar_behaviour = {
			type = "group",
			name = "Behaviour",
			handler = ST,
			order = 1,
			args = {
				
				------------------------------------------------------------------------------------
				-- Visibility options, when to show the bar.
				autohide_header = {
					type="header",
					order=5.0,
					name="Bar visibility",
				},
				autohide_desc = {
					type="description",
					order=5.01,
					name="Determines under what conditions the bar should be shown.",
				},
				visibility_key = {
					type="select",
					order=5.1,
					name="Visibility",
					desc="The visibility setting to use.",
					values=bar_visibility_values,
					sorting=bar_vis_ordering,
					get = "GetValue",
					set = "SetValue",
				},

				------------------------------------------------------------------------------------
				-- marker options
				marker_settings = {
					order=6,
					type="header",
					name="Marker settings",
				},
				marker_descriptions = {
					order=7,
					type="description",
					name="When GCD offset mode is Dynamic or Fixed, the GCD markers are pushed back "..
					"from the end of the swing to account for player input/lag. When the mode is set to Dynamic, this uses the calibrated lag "..
					"described in Lag Compensation."
				},
				gcd_padding_mode = {
					order=8,
					type="select",
					values=gcd_padding_modes,
					style="dropdown",
					desc="The type of GCD offset, if any, to use.",
					name="GCD offset mode",
					get = "GetValue",
					set = function(self, key)
						ST.db.profile.gcd_padding_mode=key
						st.bar.set_gcd_marker_offsets()
					end,
				},
				gcd_static_padding_ms = {
					type = "range",
					order = 9,
					name = "Fixed GCD offset (ms)",
					desc = "The GCD markers are set at one and two standard GCDs before the swing ends, plus this offset.",
					min = 0, max = 400,
					step = 1,
					get = "GetValue",
					set = function(self, key)
						ST.db.profile.gcd_static_padding_ms = key
						st.bar.set_gcd_marker_offsets()
					end,
					disabled = function()
						return ST.db.profile.gcd_padding_mode ~= "Fixed"
					end,
				},

			},
		},

		------------------------------------------------------------------------------------
		-- Size/position options
		positioning = {
			type = "group",
			name = "Size and Position",
			handler = ST,
			order = 2,
			args = {

				------------------------------------------------------------------------------------
				-- size options
				size_header = {
					type='header',
					name='Size',
					order=1,
				},

				bar_width = {
					type = "range",
					order = 2,
					name = "Width",
					desc = "The width of the swing timer bar.",
					min = 100, max = 600,
					step = 1,
					get = "GetValue",
					set = function(self, key)
						ST.db.profile.bar_width = key
						set_bar_size()
					end,
				},

				bar_height = {
					type = "range",
					order = 3,
					name = "Height",
					desc = "The height of the swing timer bar.",
					min = 6, max = 60,
					step = 1,
					get = "GetValue",
					set = function(self, key)
						ST.db.profile.bar_height = key
						set_bar_size()
					end,
				},

				------------------------------------------------------------------------------------
				-- position options
				position_header = {
					type = 'header',
					name = 'Position',
					order = 4,
				},
				position_description = {
					order=4.1,
					type="description",
					name="When the bar is not locked, it can be clicked and dragged with the mouse.",
				},
				position_description2 = {
					order=4.2,
					type="description",
					name="If you don't understand how UI frames anchor, then either keep both anchors on "..
					"CENTER and enter offsets manually, or position the bar with the mouse.",
				},
				bar_x_offset = {
					type = "input",
					order = 5,
					name = "Bar x offset",
					desc = "The x position of the bar.",
					get = function()
						return tostring(ST.db.profile.bar_x_offset)
					end,
					set = function(self, input)
						ST.db.profile.bar_x_offset = input
						set_bar_position()
					end			
				},
				bar_y_offset = {
					type = "input",
					order = 6,
					name = "Bar y offset",
					desc = "The y position of the bar.",
					get = function()
						return tostring(ST.db.profile.bar_y_offset)
					end,
					set = function(self, input)
						ST.db.profile.bar_y_offset = input
						set_bar_position()
					end			
				},

				bar_point = {
					order = 6.1,
					type="select",
					name = "Anchor",
					desc = "One of the region's anchors.",
					values = valid_anchor_points,
					get = "GetValue",
					set = function(self, input)
						ST.db.profile.bar_point = input
						set_bar_position()
					end,
				},
				bar_rel_point = {
					order = 6.2,
					type="select",
					name = "Relative anchor",
					desc = "Anchor point on region to align against.",
					values = valid_anchor_points,
					get = "GetValue",
					set = function(self, input)
						ST.db.profile.bar_rel_point = input
						set_bar_position()
					end,
				},


				------------------------------------------------------------------------------------
				-- strata/draw level options
				strata_header = {
					type = 'header',
					name = 'Frame Strata',
					order = 7.0,
				},
				strata_description = {
					type = 'description',
					name = 'The frame strata the addon should be drawn at. Anything higher than MEDIUM '..
                    'will be drawn over some in-game menus, so this is the highest strata allowed.',
					order = 7.1,
				},
				frame_strata = {
					order = 7.2,
					type="select",
					name = "Frame strata",
					desc = "The frame strata the addon should be drawn at.",
					values = {
						BACKGROUND = "BACKGROUND",
						LOW = "LOW",
						MEDIUM = "MEDIUM",
					},
					get = "GetValue",
					set = function(self, input)
						ST.db.profile.frame_strata = input
						st.bar.frame:SetFrameStrata(input)
						st.bar.frame.backplane:SetFrameStrata(input)
					end,
				},
				draw_level = {
					type = "range",
					order = 7.3,
					name = "Draw level",
					desc = "The bar's draw level within the frame strata.",
					min = 1, max=100,
					step=1,
					get = "GetValue",
					set = function(self, input)
						ST.db.profile.draw_level = input
						st.bar.frame:SetFrameLevel(input+1)
						st.bar.frame.backplane:SetFrameLevel(input)
					end
				},

			},
		},

	}
}

function ST:GetValue(info)
	return self.db.profile[info[#info]]
end

function ST:SetValue(info, value)
	self.db.profile[info[#info]] = value
end

--=========================================================================================
-- End, if debug verify module was read.
--=========================================================================================
if st.debug then print('-- Parsed config.lua module correctly') end
