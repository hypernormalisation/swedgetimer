------------------------------------------------------------------------------------
-- Main module for creating the addon with AceAddon
------------------------------------------------------------------------------------
local addon_name, st = ...
local ST = LibStub("AceAddon-3.0"):NewAddon(addon_name, "AceConsole-3.0", "AceEvent-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
local STL = LibStub("LibClassicSwingTimerAPI", true)
local LRC = LibStub("LibRangeCheck-2.0")
-- print('LRC says: '..tostring(LRC))
-- local rcf = CreateFrame("Frame", nil)

local print = st.utils.print_msg

local SwingTimerInfo = function(hand)
    return STL:SwingTimerInfo(hand)
end

-- keyword-accessible tables
ST.mainhand = {}
ST.offhand = {}
ST.ranged = {}
ST.hands = {
	mainhand = true,
	offhand = true,
	ranged = true
}
ST.h = {"mainhand", "offhand", "ranged"}
ST.mh = {"mainhand", "offhand"}

function ST:iter_hands()
	local i = 0
	local hands = self.h
	local n = #hands
	return function ()
		i = i + 1
		while i <= n do
			return hands[i]
		end
		return nil
	end
end

function ST:iter_melee_hands()
	local i = 0
	local hands = self.mh
	local n = #hands
	return function ()
		i = i + 1
		while i <= n do
			return hands[i]
		end
		return nil
	end
end

function ST:get_frame(hand)
	-- print(self[hand])
	return self[hand].frame
end

function ST:get_in_range(hand)
	if hand == "ranged" then return self.in_ranged_range else return self.in_melee_range end
end

ST.interfaces_are_initialised = false

------------------------------------------------------------------------------------
-- The init/enable/disable
------------------------------------------------------------------------------------
function ST:OnInitialize()

	-- ST.some_counter = ST.some_counter + 1
	-- print(string.format("init count: %i", ST.some_counter))

	-- Addon database
	local SwedgeTimerDB = LibStub("AceDB-3.0"):New(addon_name.."DB", self.defaults, true)
	self.db = SwedgeTimerDB

	-- Options table
	local AC = LibStub("AceConfig-3.0")
	local ACD = LibStub("AceConfigDialog-3.0")
	AC:RegisterOptionsTable(addon_name.."_Options", self.options)
	self.optionsFrame = ACD:AddToBlizOptions(addon_name.."_Options", addon_name)

	local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	-- AC:RegisterOptionsTable(addon_name.."_Profiles", profiles)
	-- ACD:AddToBlizOptions(addon_name.."_Profiles", "Profiles", addon_name)

	self.lrc_ready = false
	self.stl_ready = false

	-- init our lib interfaces only once the range and swing timer
	-- libs are both loaded, as they are interdependent
	-- init_libs has a check to ensure this only happens once per reload
	LRC:RegisterCallback(LRC.CHECKERS_CHANGED, function()
			self.lrc_ready = true
			if self.stl_ready then
				print('initing interfaces on LRC')
				self:init_libs()
			end
		end
	)
	STL:RegisterCallback(STL.SWING_TIMER_READY, function()
			self.stl_ready = true
			if self.lrc_ready then
				print('initing interfaces on STL')
				self:init_libs()
			end
		end
	)

	-- Slashcommands
	self:register_slashcommands()

	-- Sort out character information
	self.player_guid = UnitGUID("player")
	self.player_class = select(2, UnitClass("player"))
	self.has_oh = false
	self.has_ranged = false
	self.mh_timer = 0
	self.oh_timer = 0
	self.ranged_timer = 0
	-- self:check_weapons()

	-- Character state containers
	self.in_combat = false
	self.is_melee_attacking = false
	self.has_target = false
	self.has_attackable_target = false

	-- MH timer containers
	self.mainhand.start = nil
	self.mainhand.speed = nil
	self.mainhand.ends_at = nil
	self.mainhand.inactive_timer = nil
	self.mainhand.has_weapon = true
	self.mainhand.frame = CreateFrame("Frame", addon_name .. "MHBarFrame", UIParent)

	-- OH containers
	self.offhand.start = nil
	self.offhand.speed = nil
	self.offhand.ends_at = nil
	self.offhand.inactive_timer = nil
	self.offhand.has_weapon = nil
	self.offhand.frame = CreateFrame("Frame", addon_name .. "OHBarFrame", UIParent)

	-- ranged containers
	self.ranged.start = nil
	self.ranged.speed = nil
	self.ranged.ends_at = nil
	self.ranged.inactive_timer = nil
	self.ranged.has_weapon = nil
	self.ranged.frame = CreateFrame("Frame", addon_name .. "OHBarFrame", UIParent)

	-- GCD info containers
	self.gcd = {}
	self.gcd.lock = false
    self.gcd.duration = nil
	self.gcd.started = nil
	self.gcd.expires = nil

	-- Register events
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("PLAYER_TARGET_SET_ATTACKING")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("PLAYER_ENTER_COMBAT")
	self:RegisterEvent("PLAYER_LEAVE_COMBAT")
	self:RegisterEvent("UNIT_TARGET")

end

function ST:init_libs()
	if self.interfaces_are_initialised then
		return
	end
	self:init_timers()
	self:init_range_finders()
	self.interfaces_are_initialised = true
end

function ST:OnEnable()
end

------------------------------------------------------------------------------------
-- Range finding
------------------------------------------------------------------------------------
function ST:init_range_finders()
	self.rangefinder_interval = 0.1
	self.melee_range_checker_func = LRC:GetHarmMaxChecker(LRC.MeleeRange)
	local r = 30
	if self.player_class == "HUNTER" then
		r = 35
	end
	self.ranged_range_checker_func = LRC:GetHarmMaxChecker(r)
	self.in_melee_range = nil
	self.in_ranged_range = nil
	self.target_min_range = nil
	self.target_max_range = nil
	-- C_Timer.After(1.0, function() self:rf_update() end)

	self:rf_update()
end

function ST:rf_update()
	self.in_melee_range = self:melee_range_checker_func("target")
	-- print(self.melee_result)
	self.in_ranged_range = self.ranged_range_checker_func("target") and not self.in_melee_range
	self.target_min_range, self.target_max_range = LRC:GetRange("target")
	-- print('minrange = '..tostring(self.target_min_range))
	-- print(self.target_max_range)
	self:set_bar_visibilities()
	self:handle_oor()
	C_Timer.After(self.rangefinder_interval, function() self:rf_update() end)
end

------------------------------------------------------------------------------------
-- Bar out-of-range behaviour
------------------------------------------------------------------------------------
function ST:handle_oor()
	for hand in self:iter_hands() do
		if self:bar_is_enabled(hand) then
			self:handle_oor_hand(hand)
		end
	end
end

function ST:handle_oor_hand(hand)
	local db = self:get_hand_table(hand)
	local frame = self:get_frame(hand)

	if db.oor_effect == "dim" then
		if not self:get_in_range(hand) then
			frame:SetAlpha(db.dim_alpha)
		else
			frame:SetAlpha(1.0)
		end
	end
end

------------------------------------------------------------------------------------
-- Bar visibility
------------------------------------------------------------------------------------
function ST:hide_bar(hand)
	self:get_frame(hand):Hide()
end

function ST:show_bar(hand)
	self:get_frame(hand):Show()
end

function ST:bar_is_enabled(hand)
	local db = self:get_hand_table(hand)
	if hand == "mainhand" then -- always has weapon
		if db.enabled then
			return true
		else
			return false
		end
	elseif db.enabled and self[hand].has_weapon then
		return true
	else
		return false
	end
end

function ST:handle_bar_visibility(hand)
	-- Out of combat requirement overrides all else
	local db = self:get_hand_table(hand)
	if db.hide_ooc then
		if not self.in_combat then
			self:hide_bar(hand)
			return
		end
	end
	if db.force_show_in_combat then
		if self.in_combat then
			self:show_bar(hand)
			return
		end
	end
	-- Then target and range checks
	if db.require_has_valid_target then
		if self.has_attackable_target then
			if db.require_in_range then
				if not self:get_in_range(hand) then
					self:hide_bar(hand)
					return
				end
			end
		else
			self:hide_bar(hand)
			return
		end
	end
	-- If we get here, bar should be shown
	self:show_bar(hand)
end

function ST:set_bar_visibilities()
	-- Function hooked onto the rangefinder C_Timer to determine bar states
	for hand in self:iter_hands() do
		-- Get appropriate range
		-- print(string.format("%s in range: %s", hand, tostring(in_range)))
		if not self:bar_is_enabled(hand) then
			self:hide_bar()
		else
			self:handle_bar_visibility(hand)
			-- self:show_bar(hand)

		end
	end
end

------------------------------------------------------------------------------------
-- State setting
------------------------------------------------------------------------------------
function ST:check_weapons()
	-- Detect what weapon types are equipped.
	for hand in self:iter_hands() do
		local speed = SwingTimerInfo(hand)
		-- print(speed)
		if speed == 0 then
			self[hand].has_weapon = false
		else
			self[hand].has_weapon = true
		end
	end
end

------------------------------------------------------------------------------------
-- GCD funcs
------------------------------------------------------------------------------------
function ST:needs_gcd()
	if self:get_hand_table("mainhand")["show_gcd_underlay"] or
		self:get_hand_table("offhand")["show_gcd_underlay"] or
		self:get_hand_table("ranged")["show_gcd_underlay"] then
		return true
	end
	return false
end

------------------------------------------------------------------------------------
-- The Event handlers for the STL
------------------------------------------------------------------------------------
function ST:register_timer_callbacks()
	STL.RegisterCallback(self, "SWING_TIMER_START", self.timer_event_handler)
	STL.RegisterCallback(self, "SWING_TIMER_UPDATE", self.timer_event_handler)
	STL.RegisterCallback(self, "SWING_TIMER_CLIPPED", self.timer_event_handler)
	STL.RegisterCallback(self, "SWING_TIMER_PAUSED", self.timer_event_handler)
	STL.RegisterCallback(self, "SWING_TIMER_STOP", self.timer_event_handler)
	STL.RegisterCallback(self, "SWING_TIMER_DELTA", self.timer_event_handler)
end

function ST:SWING_TIMER_START(speed, expiration_time, hand)
	local self = ST
	self[hand].start = GetTime()
	self[hand].speed = speed
	self[hand].ends_at = expiration_time

	-- handle gcd if necessary
	-- if self.gcd.lock then
	-- 	self:set_gcd_width()
	-- end
end

function ST:SWING_TIMER_UPDATE(speed, expiration_time, hand)
	self = ST
	local t = GetTime()
	if expiration_time < t then
		expiration_time = t
	end
	self[hand].speed = speed
	self[hand].ends_at = expiration_time
	self:set_bar_texts(hand)
end

function ST:SWING_TIMER_CLIPPED(hand)
end

function ST:SWING_TIMER_PAUSED(hand)
end

function ST:SWING_TIMER_STOP(hand)
	-- unhooks update funcs
	-- ST[hand].frame:SetScript("OnUpdate", nil)
end

function ST:SWING_TIMER_DELTA(delta)
	-- print(string.format("DELTA = %s", delta))
end

-- Stub to call the appropriate handler.
-- Doesn't play well with self syntax sugar.
function ST.timer_event_handler(event, ...)
	local args = {...}
	-- print(args)
	local hand = nil
	if event == "SWING_TIMER_START" or event == "SWING_TIMER_UPDATE" then
		hand = args[3]
	else
		hand = args[1]
	end
	-- print('event says: '..tostring(event))
	-- print(string.format("%s: %s", hand, event))
	if hand == "offhand" then
		-- print(event)
	end
	ST[event](event, ...)
end

------------------------------------------------------------------------------------
-- AceEvent callbacks
------------------------------------------------------------------------------------
function ST:init_timers()
	self:register_timer_callbacks()
	self:check_weapons()
	for hand in self:iter_hands() do
		local t = {SwingTimerInfo(hand)}
		-- print(string.format("%s, %s, %s", tostring(t[1]),
		-- tostring(t[2]), tostring(t[3])))
		self[hand].speed = t[1]
		self[hand].ends_at = t[2]
		self[hand].start = t[3]
		ST:init_visuals_template(hand)
		ST:set_bar_texts(hand)
		-- hook the onupdate
		self[hand].frame:SetScript("OnUpdate", self[hand].onupdate)
	end
end

function ST:PLAYER_ENTERING_WORLD(event, is_initial_login, is_reloading_ui)
end

function ST:PLAYER_EQUIPMENT_CHANGED(event, slot, has_current)
	print('slot says: '..tostring(slot))
	-- print(slot)
	if slot == 16 or slot == 17 or slot == 18 then
		self:check_weapons()
		print('has_oh: '.. tostring(self.offhand.has_weapon))
		print('has ranged: '..tostring(self.ranged.has_weapon))
	end
end

-- GCD events
function ST:SPELL_UPDATE_COOLDOWN()
	if not self:needs_gcd() then
		return
	end
	if self.gcd.lock then
		return
	end
	local time_started, duration = GetSpellCooldown(29515)
    if duration == 0 then
        return
    end
	local t = GetTime()
	self.gcd.lock = true
    self.gcd.duration = duration - (t - time_started)
	self.gcd.started = t
	self.gcd.expires = t + self.gcd.duration
	for hand in self:iter_hands() do
		self:get_frame(hand).gcd_bar:Show()
	end
	-- print(self.gcd.started, self.gcd.duration)
	-- self:set_gcd_width()
	-- set a timer to release the GCD lock when it expires
	C_Timer.After(self.gcd.duration, function() self:release_gcd_lock() end)
end

function ST:release_gcd_lock()
	-- Called when a GCD expires.
	self.gcd.lock = false
    self.gcd.duration = nil
	self.gcd.started = nil
	self.gcd.needs_setpoint = false
	for hand in self:iter_hands() do
		local frame = self:get_frame(hand)
		frame.gcd_bar:SetWidth(0)
		frame.gcd_bar:Hide()
	end
end

function ST:PLAYER_REGEN_ENABLED()
	self.in_combat = false
	-- unhook all onupdates when out of combat
	-- for _, h in ipairs({"mainhand", "offhand", "ranged"}) do
	-- 	self[h].frame:SetScript("OnUpdate", nil)
	-- end
end

function ST:PLAYER_REGEN_DISABLED()
	self.in_combat = true
end

function ST:PLAYER_ENTER_COMBAT()
	self.is_melee_attacking = true
end

function ST:PLAYER_LEAVE_COMBAT()
	self.is_melee_attacking = false
end

function ST:PLAYER_TARGET_SET_ATTACKING()
	-- print('offsetting offhand')
	local t = GetTime()
	local old_start = self.offhand.start
	if old_start + self.offhand.speed < t then
		self.offhand.start = GetTime() - self.offhand.speed
	end
end

function ST:UNIT_TARGET(event, unitId)
	if unitId ~= "player" then
		return
	end
	if UnitExists("target") then self.has_target = true else self.has_target = false end
	if UnitCanAttack("player", "target") == true then
		self.has_attackable_target = true
	else
		self.has_attackable_target = false
	end
end

------------------------------------------------------------------------------------
-- Slashcommands
------------------------------------------------------------------------------------
function ST:register_slashcommands()
	local register_func_string = "SlashCommand"
	self:RegisterChatCommand("st", register_func_string)
	self:RegisterChatCommand("swedgetimer", register_func_string)
	self:RegisterChatCommand("test1", "test1")
end

function ST:test1()
    local db = self:get_hand_table("mainhand")
	local f = self:get_frame("mainhand")
	-- self.mainhand.frame.gcd_bar

end

function ST:SlashCommand(input, editbox)
	local ACD = LibStub("AceConfigDialog-3.0")
	ACD:Open(addon_name.."_Options")
end
