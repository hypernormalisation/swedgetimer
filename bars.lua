------------------------------------------------------------------------------------
-- Module for all swing timer bar/widget code.
--
-- Contains:
--   - The function to initialise all the frames on addon load
--   - configuration functions that are used on init/setting change
--   - UIHANDLER objects to handle drag/drop etc behaviour
--   - OnUpdate scripts to handle the limited number of things that are
--      best done on a per-frame basis.
--   - functions to manipulate the widgets in predefined ways
------------------------------------------------------------------------------------
local addon_name, st = ...
local print = st.utils.print_msg
local LSM = LibStub("LibSharedMedia-3.0")
local ST = LibStub("AceAddon-3.0"):GetAddon(addon_name)

--=========================================================================================
-- Intialisation func (called once relevant libs are loaded once per hand)
--=========================================================================================
function ST:init_visuals_template(hand)
    print("initing visuals for hand: "..tostring(hand))
    local frame = self[hand].frame
    local db_shared = self.db.profile
    local db = self:get_hand_table(hand)

    -- Set initial frame properties
    frame:SetPoint("CENTER")
    frame:SetMovable(not db.bar_locked)
    frame:EnableMouse(not db.bar_locked)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", self[hand].on_drag_start)
    frame:SetScript("OnDragStop", self[hand].on_drag_stop)
    frame:SetHeight(db.bar_height)
    frame:SetWidth(db.bar_width)
    frame:ClearAllPoints()
    frame:SetPoint(db.bar_point, UIParent, db.bar_rel_point, db.bar_x_offset, db.bar_y_offset)

    -- Create the backplane and border
    frame.backplane = CreateFrame("Frame", addon_name .. "MHBarBackdropFrame",
        frame, "BackdropTemplate"
    )

    -- Adjust the frame draw levels so the backplane is below the frame
    frame:SetFrameLevel(db_shared.draw_level+1)
    frame.backplane:SetFrameLevel(db_shared.draw_level)
    -- Set to the requested frame strata
    frame:SetFrameStrata(db_shared.frame_strata)
    frame.backplane:SetFrameStrata(db_shared.frame_strata)

    -- Configure the backplane/outline
    self:configure_bar_outline(hand)

    -- Create the swing timer bar
    frame.bar = frame:CreateTexture(nil,"ARTWORK")
    frame.bar:SetPoint("TOPLEFT", 0, 0)
    frame.bar:SetHeight(db.bar_height)
    frame.bar:SetTexture(LSM:Fetch('statusbar', db.bar_texture_key))
    self:set_bar_color(hand)
    frame.bar:SetWidth(db.bar_width)

    -- Create the GCD timer bar
    frame.gcd_bar = frame:CreateTexture(nil, "ARTWORK")
    -- frame.gcd_bar:SetPoint("TOPRIGHT", 0, 0)
    frame.gcd_bar:SetHeight(db.bar_height)
    frame.gcd_bar:SetTexture(LSM:Fetch('statusbar', db.gcd_texture_key))
    frame.gcd_bar:SetVertexColor(unpack(db.bar_color_gcd))
    frame.gcd_bar:SetDrawLayer("ARTWORK", -2)
    frame.gcd_bar:Hide()

    -- Create the deadzone bar
    frame.deadzone = frame:CreateTexture(nil, "ARTWORK")
    frame.deadzone:SetPoint("TOPRIGHT", 0, 0)
    frame.deadzone:SetHeight(db.bar_height)
    frame.deadzone:SetDrawLayer("ARTWORK", -1)
    self:configure_deadzone(hand)
    if not db.enable_deadzone then
        frame.deadzone:Hide()
    end

    -- Create the attack speed/swing timer texts and init them
    frame.left_text = frame:CreateFontString(nil, "OVERLAY")
    frame.left_text:SetShadowColor(0.0,0.0,0.0,1.0)
    frame.left_text:SetShadowOffset(1,-1)
    frame.left_text:SetJustifyV("CENTER")
    frame.left_text:SetJustifyH("LEFT")

    frame.right_text = frame:CreateFontString(nil, "OVERLAY")
    frame.right_text:SetShadowColor(0.0,0.0,0.0,1.0)
    frame.right_text:SetShadowOffset(1,-1)
    frame.right_text:SetJustifyV("CENTER")
    frame.right_text:SetJustifyH("RIGHT")
    self:configure_fonts(hand)

    -- Create the line markers
    -- frame.twist_line = frame:CreateLine() -- the twist window marker
    -- frame.twist_line:SetDrawLayer("OVERLAY", -1)
    -- frame.gcd1_line = frame:CreateLine() -- the first gcd possible before a twist
    -- frame.gcd1_line:SetDrawLayer("OVERLAY", -1)
    -- frame.gcd2_line = frame:CreateLine()
    -- frame.gcd2_line:SetDrawLayer("OVERLAY", -1)
    -- frame.gcd2_line:SetColorTexture(0.4,0.4,1,1)
    -- frame.gcd2_line:SetThickness(db.marker_width)
    -- frame.judgement_line = frame:CreateLine()
    -- frame.judgement_line:SetDrawLayer("OVERLAY", -1)
    -- st.set_markers()

	frame:Show()
end



------------------------------------------------------------------------------------
-- Configuration functions (called on frame inits and setting changes)
------------------------------------------------------------------------------------
function ST:configure_deadzone(hand)
	local db = self:get_hand_table(hand)
	local f = self:get_frame(hand).deadzone
    f:SetTexture(LSM:Fetch('statusbar', db.deadzone_texture_key))
	f:SetVertexColor(
        self:convert_color(db.deadzone_bar_color)
    )
end

function ST:configure_fonts(hand)
    local db = self:get_hand_table(hand)
	local frame = self[hand].frame
	local font_path = LSM:Fetch('font', db.text_font)
	local opt_string = self.outline_map[db.font_outline_key]
	frame.left_text:SetFont(font_path, db.font_size, opt_string)
	frame.right_text:SetFont(font_path, db.font_size, opt_string)
	frame.left_text:SetPoint("TOPLEFT", 3, -(db.bar_height / 2) + (db.font_size / 2))
	frame.right_text:SetPoint("TOPRIGHT", -3, -(db.bar_height / 2) + (db.font_size / 2))
	frame.left_text:SetTextColor(unpack(db.font_color))
	frame.right_text:SetTextColor(unpack(db.font_color))
end

--=========================================================================================
-- Drag and drop handlers
--=========================================================================================
function ST:configure_bar_outline(hand)
	local frame = self[hand].frame
    local db = self:get_hand_table(hand)
	local mode = db.border_mode_key
	local texture_key = db.border_texture_key
    local tv = db.backplane_outline_width
	-- 8 corresponds to no border
	tv = tv + 8
	-- Switch settings based on mode
	if mode == "None" then
		texture_key = "None"
		tv = 8
	elseif mode == "Texture" then
		tv = 8
	elseif mode == "Solid" then
		texture_key = "None"
	end
    frame.backplane.backdropInfo = {
        bgFile = LSM:Fetch('statusbar', db.backplane_texture_key),
		edgeFile = LSM:Fetch('border', texture_key),
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 6, right = 6, top = 6, bottom = 6}
    }
    frame.backplane:ApplyBackdrop()
	tv = tv - 2
    frame.backplane:SetPoint('TOPLEFT', -1*tv, tv)
    frame.backplane:SetPoint('BOTTOMRIGHT', tv, -1*tv)
	frame.backplane:SetBackdropColor(0,0,0, db.backplane_alpha)
end

function ST:set_bar_position(hand)
    local db = self:get_hand_table(hand)
	local frame = self[hand].frame
	frame:ClearAllPoints()
	frame:SetPoint(db.bar_point, UIParent, db.bar_rel_point, db.bar_x_offset, db.bar_y_offset)
	frame.bar:SetPoint("TOPLEFT", 0, 0)
	frame.bar:SetPoint("TOPLEFT", 0, 0)
	frame.gcd_bar:SetPoint("TOPLEFT", 0, 0)
	frame.deadzone:SetPoint("TOPRIGHT", 0, 0)
	frame.left_text:SetPoint("TOPLEFT", 3, -(db.bar_height / 2) + (db.font_size / 2))
	frame.right_text:SetPoint("TOPRIGHT", -3, -(db.bar_height / 2) + (db.font_size / 2))
	self:configure_bar_outline(hand)
end

function ST:drag_stop_template(hand)
    local frame = self[hand].frame
    local db = self:get_hand_table(hand)
    frame:StopMovingOrSizing()
    local point, _, rel_point, x_offset, y_offset = frame:GetPoint()
    db.bar_x_offset = st.utils.simple_round(x_offset, 0.1)
    db.bar_y_offset = st.utils.simple_round(y_offset, 0.1)
    db.bar_point = point
    db.bar_rel_point = rel_point
    self:set_bar_position(hand)
    self:set_bar_color(hand)
end

function ST:drag_start_template(hand)
    local db = self:get_hand_table(hand)
    if not db.bar_locked then
        ST[hand].frame:StartMoving()
    end
end

function ST.mainhand.on_drag_start()
    ST:drag_start_template('mainhand')
end

function ST.mainhand.on_drag_stop()
    ST:drag_stop_template('mainhand')
end

function ST.offhand.on_drag_start()
    ST:drag_start_template('offhand')
end

function ST.offhand.on_drag_stop()
    ST:drag_stop_template('offhand')
end

function ST.ranged.on_drag_start()
    ST:drag_start_template('ranged')
end

function ST.ranged.on_drag_stop()
    ST:drag_stop_template('ranged')
end

--=========================================================================================
-- OnUpdate widget handlers and functions
--=========================================================================================
function ST:onupdate_common(hand)
    local frame = self[hand].frame
    local d = self[hand]
    local t = GetTime()
    local progress = math.min(1, (t - d.start) /
        (d.ends_at - d.start)
    )
    local db = self:get_hand_table(hand)

    -- Update the main bar's width
    local timer_width = db.bar_width * progress
    frame.bar:SetWidth(timer_width)
	frame.bar:SetTexCoord(0, progress, 0, 1)

    -- Update the GCD underlay if necessary.
    if db.show_gcd_underlay and self.gcd.lock then
        self:set_gcd_width(hand, timer_width, progress)
    end
    -- Set texts
    self:set_bar_texts(hand)

end

ST.mainhand.onupdate = function(elapsed)
    ST:onupdate_common("mainhand")
end

ST.offhand.onupdate = function(elapsed)
    ST:onupdate_common("offhand")
end

ST.ranged.onupdate = function(elapsed)
    ST:onupdate_common("ranged")
end

--=========================================================================================
-- Collections of widget altering funcs to be called on specific events
--=========================================================================================
function ST:on_attack_speed_change(hand)
    self:set_deadzone_width(hand)
    self:set_bar_texts(hand)
end

--=========================================================================================
-- Funcs to alter widgets
--=========================================================================================
function ST:set_gcd_width(hand, timer_width, progress)
    local db = self:get_hand_table(hand)
    local frame = self[hand].frame
    local tab = self[hand]
    local t = GetTime()
    local gcd_progress = (self.gcd.expires - tab.start) / (tab.ends_at - tab.start)
    -- if gcd would go over the end of the bar, instead use the swing timer
    -- bar progress to evalute texture coords and gcd bar width
    if gcd_progress > 1 then
        local gcd_width = db.bar_width - timer_width
        frame.gcd_bar:SetWidth(gcd_width)
        frame.gcd_bar:SetTexCoord(progress, 1, 0, 1)
    else
        local gcd_width = (db.bar_width * gcd_progress) - timer_width
        frame.gcd_bar:SetWidth(gcd_width)
        frame.gcd_bar:SetTexCoord(progress, gcd_progress, 0, 1)
    end
    frame.gcd_bar:SetPoint("TOPLEFT", timer_width, 0)
end

function ST:set_bar_texts(hand)
    local frame = self[hand].frame
    local db = self:get_hand_table(hand)

    -- Set texts
    local t = GetTime()
    local speed = self[hand].speed
    local timer = max(0, self[hand].ends_at - t)
    local lookup = {
        attack_speed=format("%.1f", st.utils.simple_round(speed, 0.1)),
        swing_timer=format("%.1f", st.utils.simple_round(timer, 0.1)),
    }
    local left = lookup[db.left_text]
    local right = lookup[db.right_text]

    -- Update the main bars text, hide right text if bar full
    frame.left_text:SetText(left)
    frame.right_text:SetText(right)
end


function ST:set_bar_color(hand, color_table)
    local db = self:get_hand_table(hand)
    local frame = self[hand].frame
    if color_table then
        frame.bar:SetVertexColor(
            unpack(color_table)
        )
    else
        frame.bar:SetVertexColor(
            self:convert_color(db.bar_color_default)
        )
    end
end

function ST:set_deadzone_width(hand)
    print('call to set deadzone width for '..hand)
    local db = self:get_hand_table(hand)
    local frame = self:get_frame(hand).deadzone
    if not db.enable_deadzone then
        return
    end
    local frac = (self.latency.world_ms / 1000) / self[hand].speed
    print(frac)
    frame:SetWidth(frac * db.bar_width)
end
