--[[
-- ElvUI Location Plus --
a plugin for ElvUI, that adds player location and coords + 2 Datatexts

- Info, requests, bugs: http://www.tukui.org/addons/index.php?act=view&id=56
----------------------------------------------------------------------------------
- Credits:
	-Elv, Blazeflack, for showing me the best way to do this
	-Sinaris(idea from his TukUI edit)
	-iceeagle, grdn, for digging their great code and making this possible.
	-Tukui and Elvui forum community.
----------------------------------------------------------------------------------
- ToDo:

]]--

local E, L, V, P, G = unpack(ElvUI);
local LPB = E:NewModule('LocationPlus', 'AceTimer-3.0', 'AceEvent-3.0');
local DT = E:GetModule('DataTexts');
local LSM = LibStub("LibSharedMedia-3.0");
local EP = LibStub("LibElvUIPlugin-1.0")
local addon, ns = ...

local T = LibStub("LibTourist-3.0");

local format, tonumber, pairs, print = string.format, tonumber, pairs, print

local CreateFrame = CreateFrame
local ChatEdit_ChooseBoxForSend, ChatEdit_ActivateChat = ChatEdit_ChooseBoxForSend, ChatEdit_ActivateChat
local GetBindLocation = GetBindLocation
local GetCurrencyInfo = GetCurrencyInfo
local GetCurrencyListSize = GetCurrencyListSize
local GetCurrentMapAreaID = GetCurrentMapAreaID
local GetMinimapZoneText = GetMinimapZoneText
local GetPlayerMapPosition = GetPlayerMapPosition
local GetProfessionInfo = GetProfessionInfo
local GetProfessions = GetProfessions
local GetRealZoneText = GetRealZoneText
local GetSubZoneText = GetSubZoneText
local GetZonePVPInfo = GetZonePVPInfo
local IsInInstance, InCombatLockdown = IsInInstance, InCombatLockdown
local UnitLevel = UnitLevel
local UIFrameFadeIn, UIFrameFadeOut, ToggleFrame = UIFrameFadeIn, UIFrameFadeOut, ToggleFrame
local IsControlKeyDown, IsShiftKeyDown = IsControlKeyDown, IsShiftKeyDown
local GameTooltip, WorldMapFrame = _G['GameTooltip'], _G['WorldMapFrame']

local PLAYER, UNKNOWN, TRADE_SKILLS, TOKENS, DUNGEONS, PROFESSIONS_FISHING, LEVEL_RANGE, STATUS, HOME, CONTINENT = PLAYER, UNKNOWN, TRADE_SKILLS, TOKENS, DUNGEONS, PROFESSIONS_FISHING, LEVEL_RANGE, STATUS, HOME, CONTINENT
local SANCTUARY_TERRITORY, ARENA, FRIENDLY, HOSTILE, CONTESTED_TERRITORY, COMBAT, AGGRO_WARNING_IN_INSTANCE, PVP, RAID = SANCTUARY_TERRITORY, ARENA, FRIENDLY, HOSTILE, CONTESTED_TERRITORY, COMBAT, AGGRO_WARNING_IN_INSTANCE, PVP, RAID

-- GLOBALS: LocationPlusPanel, LeftCoordDtPanel, RightCoordDtPanel, XCoordsPanel, YCoordsPanel, selectioncolor, continent, continentID, CUSTOM_CLASS_COLORS

local left_dtp = CreateFrame('Frame', 'LeftCoordDtPanel', E.UIParent)
local right_dtp = CreateFrame('Frame', 'RightCoordDtPanel', E.UIParent)

local COORDS_WIDTH = 30 -- Coord panels width
local classColor = E.myclass == 'PRIEST' and E.PriestColors or (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[E.myclass] or RAID_CLASS_COLORS[E.myclass])

-----------------
-- Currency Table
-----------------
-- Add below the currency id you wish to track. 
-- Find the currency ids: http://www.wowhead.com/currencies .
-- Click on the wanted currency and in the address you will see the id.
-- e.g. for Bloody Coin, you will see http://www.wowhead.com/currency=789 . 789 is the id.
-- So, on this case, add 789, (don't forget the comma).
-- If there are 0 earned points, the currency will be filtered out.

local currency = {
	--395,	-- Justice Points
	--396,	-- Valor Points
	--777,	-- Timeless Coins
	--697,	-- Elder Charm of Good Fortune
	--738,	-- Lesser Charm of Good Fortune
	390,	-- Conquest Points
	392,	-- Honor Points
	--515,	-- Darkmoon Prize Ticket
	--402,	-- Ironpaw Token
	--776,	-- Warforged Seal
	
	-- WoD
	--824,	-- Garrison Resources
	--823,	-- Apexis Crystal (for gear, like the valors)
	--994,	-- Seal of Tempered Fate (Raid loot roll)
	--980,	-- Dingy Iron Coins (rogue only, from pickpocketing)
	--944,	-- Artifact Fragment (PvP)
	--1101,	-- Oil
	--1129,	-- Seal of Inevitable Fate
	--821,	-- Draenor Clans Archaeology Fragment
	--828,	-- Ogre Archaeology Fragment
	--829,	-- Arakkoa Archaeology Fragment
	1166, 	-- Timewarped Badge (6.22)
	--1191,	-- Valor Points (6.23)
	
	-- Legion
	--1226,	-- Nethershard (Invasion scenarios)
	1172,	-- Highborne Archaeology Fragment
	1173,	-- Highmountain Tauren Archaeology Fragment
	--1155,	-- Ancient Mana
	1220,	-- Order Resources
	1275,	-- Curious Coin (Buy stuff :P)
	--1226,	-- Nethershard (Invasion scenarios)
	1273,	-- Seal of Broken Fate (Raid)
	--1154,	-- Shadowy Coins
	--1149,	-- Sightless Eye (PvP)
	--1268,	-- Timeworn Artifact (Honor Points?)
	--1299,	-- Brawler's Gold
	--1314,	-- Lingering Soul Fragment (Good luck with this one :D)
	1342,	-- Legionfall War Supplies (Construction at the Broken Shore)
	1355,	-- Felessence (Craft Legentary items)
	--1356,	-- Echoes of Battle (PvP Gear)
	--1357,	-- Echoes of Domination (Elite PvP Gear)
	1416,	-- Coins of Air
	1506,	-- Argus Waystone
	1508,	-- Veiled Argunite
}
------------------------
-- end of Currency Table
------------------------

LPB.version = GetAddOnMetadata("ElvUI_LocPlus", "Version")

if E.db.locplus == nil then E.db.locplus = {} end

do
	DT:RegisterPanel(LeftCoordDtPanel, 1, 'ANCHOR_BOTTOM', 0, -4)
	DT:RegisterPanel(RightCoordDtPanel, 1, 'ANCHOR_BOTTOM', 0, -4)

	L['RightCoordDtPanel'] = L["LocationPlus Right Panel"];
	L['LeftCoordDtPanel'] = L["LocationPlus Left Panel"];

	-- Setting default datatexts
	P.datatexts.panels.RightCoordDtPanel = 'Time'
	P.datatexts.panels.LeftCoordDtPanel = 'Durability'
end

local SPACING = 1

-- Status
local function GetStatus(color)
	local status = ""
	local statusText
	local r, g, b = 1, 1, 0
	local pvpType = GetZonePVPInfo()
	local inInstance, _ = IsInInstance()
		if (pvpType == "sanctuary") then
			status = SANCTUARY_TERRITORY
			r, g, b = 0.41, 0.8, 0.94
		elseif(pvpType == "arena") then
			status = ARENA
			r, g, b = 1, 0.1, 0.1
		elseif(pvpType == "friendly") then
			status = FRIENDLY
			r, g, b = 0.1, 1, 0.1
		elseif(pvpType == "hostile") then
			status = HOSTILE
			r, g, b = 1, 0.1, 0.1
		elseif(pvpType == "contested") then
			status = CONTESTED_TERRITORY
			r, g, b = 1, 0.7, 0.10
		elseif(pvpType == "combat" ) then
			status = COMBAT
			r, g, b = 1, 0.1, 0.1
		elseif inInstance then
			status = AGGRO_WARNING_IN_INSTANCE
			r, g, b = 1, 0.1, 0.1
		else
			status = CONTESTED_TERRITORY
		end

	statusText = format("|cff%02x%02x%02x%s|r", r*255, g*255, b*255, status)
	if color then
		return r, g, b
	else
		return statusText
	end
end

-- Dungeon coords
local function GetDungeonCoords(zone)
	local z, x, y = "", 0, 0;
	local dcoords
	
	if T:IsInstance(zone) then
		z, x, y = T:GetEntrancePortalLocation(zone);
	end
	
	if z == nil then
		dcoords = ""
	elseif E.db.locplus.ttcoords then
		x = tonumber(E:Round(x, 0))
		y = tonumber(E:Round(y, 0))		
		dcoords = format(" |cffffffff(%d, %d)|r", x, y)
	else 
		dcoords = ""
	end

	return dcoords
end

-- PvP/Raid filter
 local function PvPorRaidFilter(zone)

	local isPvP, isRaid;
	
	isPvP = nil;
	isRaid = nil;
	
	if(T:IsArena(zone) or T:IsBattleground(zone)) then
		if E.db.locplus.tthidepvp then
			return;
		end
		isPvP = true;
	end
	
	if(not isPvP and T:GetInstanceGroupSize(zone) >= 10) then
		if E.db.locplus.tthideraid then
			return
		end
		isRaid = true;
	end
	
	return (isPvP and "|cffff0000 "..PVP.."|r" or "")..(isRaid and "|cffff4400 "..RAID.."|r" or "")

end

-- Recommended zones
local function GetRecomZones(zone)

	local low, high = T:GetLevel(zone)
	local r, g, b = T:GetLevelColor(zone)
	local zContinent = T:GetContinent(zone)

	if PvPorRaidFilter(zone) == nil then return end
	
	GameTooltip:AddDoubleLine(
	"|cffffffff"..zone
	..PvPorRaidFilter(zone) or "",
	format("|cff%02xff00%s|r", continent == zContinent and 0 or 255, zContinent)
	..(" |cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255,(low == high and low or ("%d-%d"):format(low, high))));

end

-- Dungeons in the zone
local function GetZoneDungeons(dungeon)

	local low, high = T:GetLevel(dungeon)
	local r, g, b = T:GetLevelColor(dungeon)
	local groupSize = T:GetInstanceGroupSize(dungeon)
	local altGroupSize = T:GetInstanceAltGroupSize(dungeon)
	local groupSizeStyle = (groupSize > 0 and format("|cFFFFFF00|r (%d", groupSize) or "")
	local altGroupSizeStyle = (altGroupSize > 0 and format("|cFFFFFF00|r/%d", altGroupSize) or "")
	local name = dungeon

	if PvPorRaidFilter(dungeon) == nil then return end
	
	GameTooltip:AddDoubleLine(
	"|cffffffff"..name
	..(groupSizeStyle or "")
	..(altGroupSizeStyle or "").."-"..PLAYER..") "
	..GetDungeonCoords(dungeon)
	..PvPorRaidFilter(dungeon) or "",
	("|cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255,(low == high and low or ("%d-%d"):format(low, high))))

end

-- Recommended Dungeons
local function GetRecomDungeons(dungeon)
		
	local low, high = T:GetLevel(dungeon);	
	local r, g, b = T:GetLevelColor(dungeon);
	local instZone = T:GetInstanceZone(dungeon);
	local name = dungeon
	
	if PvPorRaidFilter(dungeon) == nil then return end
	
	if instZone == nil then
		instZone = ""
	else
		instZone = "|cFFFFA500 ("..instZone..")"
	end
	
	GameTooltip:AddDoubleLine(
	"|cffffffff"..name
	..instZone
	..GetDungeonCoords(dungeon)
	..PvPorRaidFilter(dungeon) or "",
	("|cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255,(low == high and low or ("%d-%d"):format(low, high))))

end

-- Icons on Location Panel
local FISH_ICON = "|TInterface\\AddOns\\ElvUI_LocPlus\\media\\fish.tga:14:14|t"
local PET_ICON = "|TInterface\\AddOns\\ElvUI_LocPlus\\media\\pet.tga:14:14|t"
local LEVEL_ICON = "|TInterface\\AddOns\\ElvUI_LocPlus\\media\\levelup.tga:14:14|t"

-- Get Fishing Level
local function GetFishingLvl(minFish, ontt)
	local mapID = GetCurrentMapAreaID()
	local zoneText = T:GetMapNameByIDAlt(mapID) or UNKNOWN;
	local uniqueZone = T:GetUniqueZoneNameForLookup(zoneText, continentID)
	local minFish = T:GetFishingLevel(uniqueZone)
	local _, _, _, fishing = GetProfessions()
	local r, g, b = 1, 0, 0
	local r1, g1, b1 = 1, 0, 0
	local dfish
	
	if minFish then
		if fishing ~= nil then
			local _, _, rank = GetProfessionInfo(fishing)
			if minFish < rank then
				r, g, b = 0, 1, 0
				r1, g1, b1 = 0, 1, 0
			elseif minFish == rank then
				r, g, b = 1, 1, 0
				r1, g1, b1 = 1, 1, 0
			end
		end
		
		dfish = format("|cff%02x%02x%02x%d|r", r*255, g*255, b*255, minFish)
		if ontt then
			return dfish
		else
			if E.db.locplus.showicon then
				return format(" (%s) ", dfish)..FISH_ICON
			else
				return format(" (%s) ", dfish)
			end
		end
	else
		return ""
	end
end

-- PetBattle Range
local function GetBattlePetLvl(zoneText, ontt)
	local mapID = GetCurrentMapAreaID()
	local zoneText = T:GetMapNameByIDAlt(mapID) or UNKNOWN;
	local uniqueZone = T:GetUniqueZoneNameForLookup(zoneText, continentID)
	local low,high = T:GetBattlePetLevel(uniqueZone)
	local plevel
	if low ~= nil or high ~= nil then
		if low ~= high then
			plevel = format("%d-%d", low, high)
		else
			plevel = format("%d", high)
		end
		
		if ontt then
			return plevel
		else
			if E.db.locplus.showicon then
				plevel = format(" (%s) ", plevel)..PET_ICON
			else
				plevel = format(" (%s) ", plevel)
			end
		end
	end
	
	return plevel or ""
end

-- Zone level range
local function GetLevelRange(zoneText, ontt)
	local mapID = GetCurrentMapAreaID()
	local zoneText = T:GetMapNameByIDAlt(mapID) or UNKNOWN;	
	local low, high = T:GetLevel(zoneText)
	local dlevel
	if low > 0 and high > 0 then
		local r, g, b = T:GetLevelColor(zoneText)
		if low ~= high then
			dlevel = format("|cff%02x%02x%02x%d-%d|r", r*255, g*255, b*255, low, high) or ""
		else
			dlevel = format("|cff%02x%02x%02x%d|r", r*255, g*255, b*255, high) or ""
		end
		
		if ontt then
			return dlevel
		else
			if E.db.locplus.showicon then
				dlevel = format(" (%s) ", dlevel)..LEVEL_ICON
			else
				dlevel = format(" (%s) ", dlevel)
			end
		end
	end
	
	return dlevel or ""
end

local capRank = 800

local function UpdateTooltip()
	
	local mapID = GetCurrentMapAreaID()
	local zoneText = T:GetMapNameByIDAlt(mapID) or UNKNOWN;
	local curPos = (zoneText.." ") or "";
	
	GameTooltip:ClearLines()
	
	-- Zone
	GameTooltip:AddDoubleLine(L["Zone : "], zoneText, 1, 1, 1, selectioncolor)
	
	-- Continent
	GameTooltip:AddDoubleLine(CONTINENT.." : ", T:GetContinent(zoneText), 1, 1, 1, selectioncolor)
	
	-- Home
	GameTooltip:AddDoubleLine(HOME.." :", GetBindLocation(), 1, 1, 1, 0.41, 0.8, 0.94)
	
	-- Status
	if E.db.locplus.ttst then
		GameTooltip:AddDoubleLine(STATUS.." :", GetStatus(false), 1, 1, 1)
	end
	
    -- Zone level range
	if E.db.locplus.ttlvl then
		local checklvl = GetLevelRange(zoneText, true)
		if checklvl ~= "" then
			GameTooltip:AddDoubleLine(LEVEL_RANGE.." : ", checklvl, 1, 1, 1)
		end
	end
	
	-- Fishing
	if E.db.locplus.fish then
		local checkfish = GetFishingLvl(true, true)
		if checkfish ~= "" then
			GameTooltip:AddDoubleLine(PROFESSIONS_FISHING.." : ", checkfish, 1, 1, 1)
		end
	end
	
	-- Battle Pet Levels
	if E.db.locplus.petlevel then
		local checkbpet = GetBattlePetLvl(zoneText, true)
		if checkbpet ~= "" then
			GameTooltip:AddDoubleLine(L["Battle Pet level"].. " :", checkbpet, 1, 1, 1, selectioncolor)
		end
	end

	-- Recommended zones
	if E.db.locplus.ttreczones then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L["Recommended Zones :"], selectioncolor)
	
		for zone in T:IterateRecommendedZones() do
			GetRecomZones(zone);
		end		
	end
	
	-- Instances in the zone
	if E.db.locplus.ttinst and T:DoesZoneHaveInstances(zoneText) then 
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(curPos..DUNGEONS.." :", selectioncolor)
			
		for dungeon in T:IterateZoneInstances(zoneText) do
			GetZoneDungeons(dungeon);
		end	
	end
	
	-- Recommended Instances
	local level = UnitLevel('player')
	if E.db.locplus.ttrecinst and T:HasRecommendedInstances() and level >= 15 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L["Recommended Dungeons :"], selectioncolor)
			
		for dungeon in T:IterateRecommendedInstances() do
			GetRecomDungeons(dungeon);
		end
	end
	
	-- Currency
	local numEntries = GetCurrencyListSize() -- Check for entries to disable the tooltip title when no currency
	if E.db.locplus.curr and numEntries > 3 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(TOKENS.." :", selectioncolor)

		for _, id in pairs(currency) do
			local name, amount, icon, _, _, totalMax = GetCurrencyInfo(id)

			if(name and amount > 0) then
				icon = ("|T%s:12:12:1:0|t"):format(icon)
				if totalMax == 0 then
					GameTooltip:AddDoubleLine(icon..format(" %s : ", name), format("%s", amount ), 1, 1, 1, selectioncolor)
				else
					GameTooltip:AddDoubleLine(icon..format(" %s : ", name), format("%s / %s", amount, totalMax ), 1, 1, 1, selectioncolor)
				end
			end
		end
	end

	-- Professions
	local prof1, prof2, archy, fishing, cooking, firstAid = GetProfessions()
	if E.db.locplus.prof and (prof1 or prof2 or archy or fishing or cooking or firstAid) then	
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(TRADE_SKILLS.." :", selectioncolor)
		
		local proftable = { GetProfessions() }
		for _, id in pairs(proftable) do
			local name, icon, rank, maxRank, _, _, _, rankModifier = GetProfessionInfo(id)

			if rank < capRank or (not E.db.locplus.profcap) then
				icon = ("|T%s:12:12:1:0|t"):format(icon)
				if (rankModifier and rankModifier > 0) then
					GameTooltip:AddDoubleLine(format("%s %s :", icon, name), (format("%s |cFF6b8df4+ %s|r / %s", rank, rankModifier, maxRank)), 1, 1, 1, selectioncolor)				
				else
					GameTooltip:AddDoubleLine(format("%s %s :", icon, name), (format("%s / %s", rank, maxRank)), 1, 1, 1, selectioncolor)
				end
			end
		end
	end
	
	-- Hints
	if E.db.locplus.tt then
		if E.db.locplus.tthint then
			GameTooltip:AddLine(" ")
			GameTooltip:AddDoubleLine(L["Click : "], L["Toggle WorldMap"], 0.7, 0.7, 1, 0.7, 0.7, 1)
			GameTooltip:AddDoubleLine(L["RightClick : "], L["Toggle Configuration"],0.7, 0.7, 1, 0.7, 0.7, 1)
			GameTooltip:AddDoubleLine(L["ShiftClick : "], L["Send position to chat"],0.7, 0.7, 1, 0.7, 0.7, 1)
			GameTooltip:AddDoubleLine(L["CtrlClick : "], L["Toggle Datatexts"],0.7, 0.7, 1, 0.7, 0.7, 1)
		end
		GameTooltip:Show()
	else
		GameTooltip:Hide()
	end
	
end

-- mouse over the location panel
local function LocPanel_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -4)
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("BOTTOM", self, "BOTTOM", 0, 0)
	
	if InCombatLockdown() and E.db.locplus.ttcombathide then
		GameTooltip:Hide()
	else
		UpdateTooltip()
	end
	
	if E.db.locplus.mouseover then
		UIFrameFadeIn(self, 0.2, self:GetAlpha(), 1)
	end
end

-- mouse leaving the location panel
local function LocPanel_OnLeave(self)
	GameTooltip:Hide()
	if E.db.locplus.mouseover then
		UIFrameFadeOut(self, 0.2, self:GetAlpha(), E.db.locplus.malpha)
	end
end

-- Hide in combat, after fade function ends
local function LocPanelOnFade()
	LocationPlusPanel:Hide()
end

-- Coords Creation
local function CreateCoords()
	local x, y = GetPlayerMapPosition("player")
	local dig
	
	if E.db.locplus.dig then
		dig = 2
	else
		dig = 0
	end
	
	if x then
		x = tonumber(E:Round(100 * x, dig))
	end
	if y then
		y = tonumber(E:Round(100 * y, dig))
	end
	
	return x, y
end

-- clicking the location panel
local function LocPanel_OnClick(self, btn)
	local zoneText = GetRealZoneText() or UNKNOWN;
	if btn == "LeftButton" then	
		if IsShiftKeyDown() then
			local edit_box = ChatEdit_ChooseBoxForSend()
			local x, y = CreateCoords()
			local message
			local coords = x..", "..y
				if zoneText ~= GetSubZoneText() then
					message = format("%s: %s (%s)", zoneText, GetSubZoneText(), coords)
				else
					message = format("%s (%s)", zoneText, coords)
				end
			ChatEdit_ActivateChat(edit_box)
			edit_box:Insert(message) 
		else
			if IsControlKeyDown() then
				LeftCoordDtPanel:SetScript("OnShow", function(self) E.db.locplus.dtshow = true; end)
				LeftCoordDtPanel:SetScript("OnHide", function(self) E.db.locplus.dtshow = false; end)
				ToggleFrame(LeftCoordDtPanel)
				ToggleFrame(RightCoordDtPanel)
			else 
				ToggleFrame(WorldMapFrame)
			end
		end
	end
	if btn == "RightButton" then
		E:ToggleConfig()
	end
end

-- Custom text color. Credits: Edoc
local color = { r = 1, g = 1, b = 1 }
local function unpackColor(color)
	return color.r, color.g, color.b
end

-- Location panel
local function CreateLocPanel()
	local loc_panel = CreateFrame('Frame', 'LocationPlusPanel', E.UIParent)
	loc_panel:Width(E.db.locplus.lpwidth)
	loc_panel:Height(E.db.locplus.dtheight)
	loc_panel:Point('TOP', E.UIParent, 'TOP', 0, -E.mult -22)
	loc_panel:SetFrameStrata('LOW')
	loc_panel:SetFrameLevel(2)
	loc_panel:EnableMouse(true)
	loc_panel:SetScript('OnEnter', LocPanel_OnEnter) 
	loc_panel:SetScript('OnLeave', LocPanel_OnLeave)
	loc_panel:SetScript('OnMouseUp', LocPanel_OnClick)

	-- Location Text
	loc_panel.Text = LocationPlusPanel:CreateFontString(nil, "LOW")
	loc_panel.Text:Point("CENTER", 0, 0)
	loc_panel.Text:SetAllPoints()
	loc_panel.Text:SetJustifyH("CENTER")
	loc_panel.Text:SetJustifyV("MIDDLE")
	
	-- Hide in combat/Pet battle
	loc_panel:SetScript("OnEvent",function(self, event)
		if event == "PET_BATTLE_OPENING_START" then
			UIFrameFadeOut(self, 0.2, self:GetAlpha(), 0)
			self.fadeInfo.finishedFunc = LocPanelOnFade
		elseif event == "PET_BATTLE_CLOSE" then
			if E.db.locplus.mouseover then
				UIFrameFadeIn(self, 0.2, self:GetAlpha(), E.db.locplus.malpha)
			else
				UIFrameFadeIn(self, 0.2, self:GetAlpha(), 1)
			end
			self:Show()
		elseif E.db.locplus.combat then
			if event == "PLAYER_REGEN_DISABLED" then
				UIFrameFadeOut(self, 0.2, self:GetAlpha(), 0)
				self.fadeInfo.finishedFunc = LocPanelOnFade
			elseif event == "PLAYER_REGEN_ENABLED" then
				if E.db.locplus.mouseover then
					UIFrameFadeIn(self, 0.2, self:GetAlpha(), E.db.locplus.malpha)
				else
					UIFrameFadeIn(self, 0.2, self:GetAlpha(), 1)
				end
				self:Show()
			end
		end
	end)

	-- Mover
	E:CreateMover(LocationPlusPanel, "LocationMover", L["LocationPlus "])
end

local function HideDT()
	if E.db.locplus.dtshow then
		RightCoordDtPanel:Show()
		LeftCoordDtPanel:Show()
	else
		RightCoordDtPanel:Hide()
		LeftCoordDtPanel:Hide()
	end
end

-- Coord panels
local function CreateCoordPanels()

	-- X Coord panel
	local coordsX = CreateFrame('Frame', "XCoordsPanel", LocationPlusPanel)
	coordsX:Width(COORDS_WIDTH)
	coordsX:Height(E.db.locplus.dtheight)
	coordsX:SetFrameStrata('LOW')
	coordsX.Text = XCoordsPanel:CreateFontString(nil, "LOW")
	coordsX.Text:SetAllPoints()
	coordsX.Text:SetJustifyH("CENTER")
	coordsX.Text:SetJustifyV("MIDDLE")

	-- Y Coord panel
	local coordsY = CreateFrame('Frame', "YCoordsPanel", LocationPlusPanel)
	coordsY:Width(COORDS_WIDTH)
	coordsY:Height(E.db.locplus.dtheight)
	coordsY:SetFrameStrata('LOW')
	coordsY.Text = YCoordsPanel:CreateFontString(nil, "LOW")
	coordsY.Text:SetAllPoints()
	coordsY.Text:SetJustifyH("CENTER")
	coordsY.Text:SetJustifyV("MIDDLE")

	LPB:CoordsColor()
end

-- mouse over option
function LPB:MouseOver()
	if E.db.locplus.mouseover then
		LocationPlusPanel:SetAlpha(E.db.locplus.malpha)
	else
		LocationPlusPanel:SetAlpha(1)
	end
end

-- datatext panels width
function LPB:DTWidth()
	LeftCoordDtPanel:Width(E.db.locplus.dtwidth)
	RightCoordDtPanel:Width(E.db.locplus.dtwidth)
end

-- all panels height
function LPB:DTHeight()
	if E.db.locplus.ht then
		LocationPlusPanel:Height((E.db.locplus.dtheight)+6)
	else
		LocationPlusPanel:Height(E.db.locplus.dtheight)
	end

	LeftCoordDtPanel:Height(E.db.locplus.dtheight)
	RightCoordDtPanel:Height(E.db.locplus.dtheight)

	XCoordsPanel:Height(E.db.locplus.dtheight)
	YCoordsPanel:Height(E.db.locplus.dtheight)
end

-- Fonts
function LPB:ChangeFont()

	E["media"].lpFont = LSM:Fetch("font", E.db.locplus.lpfont)

	local panelsToFont = {LocationPlusPanel, XCoordsPanel, YCoordsPanel}
	for _, frame in pairs(panelsToFont) do
		frame.Text:FontTemplate(E["media"].lpFont, E.db.locplus.lpfontsize, E.db.locplus.lpfontflags)
	end

	local dtToFont = {RightCoordDtPanel, LeftCoordDtPanel}
	for _, panel in pairs(dtToFont) do
		for i=1, panel.numPoints do
			local pointIndex = DT.PointLocation[i]
			panel.dataPanels[pointIndex].text:FontTemplate(E["media"].lpFont, E.db.locplus.lpfontsize, E.db.locplus.lpfontflags)
			panel.dataPanels[pointIndex].text:SetPoint("CENTER", 0, 1)
		end
	end
end

-- Enable/Disable shadows
function LPB:ShadowPanels()
	local panelsToAddShadow = {LocationPlusPanel, XCoordsPanel, YCoordsPanel, LeftCoordDtPanel, RightCoordDtPanel}
	
	for _, frame in pairs(panelsToAddShadow) do
		frame:CreateShadow('Default')
		if E.db.locplus.shadow then
			frame.shadow:Show()
		else
			frame.shadow:Hide()
		end
	end

	if E.db.locplus.shadow then
		SPACING = 2
	else
		SPACING = 1
	end

	self:HideCoords()
end

-- Show/Hide coord frames
function LPB:HideCoords()
	XCoordsPanel:Point('RIGHT', LocationPlusPanel, 'LEFT', -SPACING, 0)
	YCoordsPanel:Point('LEFT', LocationPlusPanel, 'RIGHT', SPACING, 0)
	
	LeftCoordDtPanel:ClearAllPoints()
	RightCoordDtPanel:ClearAllPoints()
	
	if E.db.locplus.hidecoords then
		XCoordsPanel:Hide()
		YCoordsPanel:Hide()
		LeftCoordDtPanel:Point('RIGHT', LocationPlusPanel, 'LEFT', -SPACING, 0)
		RightCoordDtPanel:Point('LEFT', LocationPlusPanel, 'RIGHT', SPACING, 0)		
	else
		XCoordsPanel:Show()
		YCoordsPanel:Show()
		LeftCoordDtPanel:Point('RIGHT', XCoordsPanel, 'LEFT', -SPACING, 0)
		RightCoordDtPanel:Point('LEFT', YCoordsPanel, 'RIGHT', SPACING, 0)			
	end
end

-- Toggle transparency
function LPB:TransparentPanels()
	local panelsToAddTrans = {LocationPlusPanel, XCoordsPanel, YCoordsPanel, LeftCoordDtPanel, RightCoordDtPanel}
	
	for _, frame in pairs(panelsToAddTrans) do
		frame:SetTemplate('NoBackdrop')
		if not E.db.locplus.noback then 
			E.db.locplus.shadow = false
		elseif E.db.locplus.trans then
			frame:SetTemplate('Transparent')
		else
			frame:SetTemplate('Default', true)
		end
	end
end

function LPB:UpdateLocation()
	local subZoneText = GetMinimapZoneText() or ""
	local zoneText = GetRealZoneText() or UNKNOWN;
	local displayLine

	-- zone and subzone
	if E.db.locplus.both then
		if (subZoneText ~= "") and (subZoneText ~= zoneText) then
			displayLine = zoneText .. ": " .. subZoneText
		else
			displayLine = subZoneText
		end
	else
		displayLine = subZoneText
	end
	
	-- Show Other (Level, Battle Pet Level, Fishing)
	if E.db.locplus.displayOther == 'RLEVEL' then
		local displaylvl = GetLevelRange(zoneText) or ""
		if displaylvl ~= "" then
			displayLine = displayLine..displaylvl
		end
	elseif E.db.locplus.displayOther == 'PET' then
		local displaypet = GetBattlePetLvl(zoneText) or ""
		if displaypet ~= "" then
			displayLine = displayLine..displaypet
		end
	elseif E.db.locplus.displayOther == 'PFISH' then
		local displayfish = GetFishingLvl(true) or ""
		if displayfish ~= "" then
			displayLine = displayLine..displayfish
		end
	else
		displayLine = displayLine
	end
	
	LocationPlusPanel.Text:SetText(displayLine)
	
	-- Coloring
	if displayLine ~= "" then
		if E.db.locplus.customColor == 1 then
			LocationPlusPanel.Text:SetTextColor(GetStatus(true))
		elseif E.db.locplus.customColor == 2 then
			LocationPlusPanel.Text:SetTextColor(classColor.r, classColor.g, classColor.b)
		else
			LocationPlusPanel.Text:SetTextColor(unpackColor(E.db.locplus.userColor))
		end
	end
	
	-- Sizing
	local fixedwidth = (E.db.locplus.lpwidth + 18)
	local autowidth = (LocationPlusPanel.Text:GetStringWidth() + 18)
	
	if E.db.locplus.lpauto then
		LocationPlusPanel:Width(autowidth)
		LocationPlusPanel.Text:Width(autowidth)
	else
		LocationPlusPanel:Width(fixedwidth)
		if E.db.locplus.trunc then
			LocationPlusPanel.Text:Width(fixedwidth - 18)
			LocationPlusPanel.Text:SetWordWrap(false)
		elseif autowidth > fixedwidth then
			LocationPlusPanel:Width(autowidth)
			LocationPlusPanel.Text:Width(autowidth)
		end
	end		
end

function LPB:UpdateCoords()
	local x, y = CreateCoords()
	local xt,yt

	if (x == 0 or x == nil) and (y == 0 or y == nil) then
		XCoordsPanel.Text:SetText("-")
		YCoordsPanel.Text:SetText("-")
	else
		if x < 10 then
			xt = "0"..x
		else
			xt = x
		end
		
		if y < 10 then
			yt = "0"..y
		else
			yt = y
		end
		XCoordsPanel.Text:SetText(xt)
		YCoordsPanel.Text:SetText(yt)
	end
end

-- Coord panels width
function LPB:CoordsDigit()
	if E.db.locplus.dig then
		XCoordsPanel:Width(COORDS_WIDTH*1.5)
		YCoordsPanel:Width(COORDS_WIDTH*1.5)
	else
		XCoordsPanel:Width(COORDS_WIDTH)
		YCoordsPanel:Width(COORDS_WIDTH)
	end
end

function LPB:CoordsColor()
	if E.db.locplus.customCoordsColor == 1 then
		XCoordsPanel.Text:SetTextColor(unpackColor(E.db.locplus.userColor))
		YCoordsPanel.Text:SetTextColor(unpackColor(E.db.locplus.userColor))			
	elseif E.db.locplus.customCoordsColor == 2 then
		XCoordsPanel.Text:SetTextColor(classColor.r, classColor.g, classColor.b)
		YCoordsPanel.Text:SetTextColor(classColor.r, classColor.g, classColor.b)
	else
		XCoordsPanel.Text:SetTextColor(unpackColor(E.db.locplus.userCoordsColor))
		YCoordsPanel.Text:SetTextColor(unpackColor(E.db.locplus.userCoordsColor))
	end
end

-- Datatext panels
local function CreateDTPanels()

	-- Left coords Datatext panel
	left_dtp:Width(E.db.locplus.dtwidth)
	left_dtp:Height(E.db.locplus.dtheight)
	left_dtp:SetFrameStrata('LOW')
	left_dtp:SetParent(LocationPlusPanel)

	-- Right coords Datatext panel
	right_dtp:Width(E.db.locplus.dtwidth)
	right_dtp:Height(E.db.locplus.dtheight)
	right_dtp:SetFrameStrata('LOW')
	right_dtp:SetParent(LocationPlusPanel)
end

-- Update changes
function LPB:LocPlusUpdate()
	self:TransparentPanels()
	self:ShadowPanels()
	self:DTHeight()
	HideDT()
	self:CoordsDigit()
	self:MouseOver()
	self:HideCoords()
end

-- Defaults in case something is wrong on first load
function LPB:LocPlusDefaults()
	if E.db.locplus.lpwidth == nil then
		E.db.locplus.lpwidth = 200
	end	

	if E.db.locplus.dtwidth == nil then
		E.db.locplus.dtwidth = 100
	end	
	
	if E.db.locplus.dtheight == nil then
		E.db.locplus.dtheight = 21
	end	
end

function LPB:ToggleBlizZoneText()
	if E.db.locplus.zonetext then
		ZoneTextFrame:UnregisterAllEvents()
	else
		ZoneTextFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		ZoneTextFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
		ZoneTextFrame:RegisterEvent("ZONE_CHANGED")	
	end
end

function LPB:TimerUpdate()
	self:ScheduleRepeatingTimer('UpdateCoords', E.db.locplus.timer)
end

function LPB:PLAYER_ENTERING_WORLD(...)
	self:ChangeFont()
	self:UpdateCoords()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end

function LPB:Initialize()
	self:LocPlusDefaults()
	CreateLocPanel()
	CreateDTPanels()
	CreateCoordPanels()
	self:LocPlusUpdate()
	self:TimerUpdate()
	self:ToggleBlizZoneText()
	self:ScheduleRepeatingTimer('UpdateLocation', 0.5)
	EP:RegisterPlugin(addon, LPB.AddOptions)
	LocationPlusPanel:RegisterEvent("PLAYER_REGEN_DISABLED")
	LocationPlusPanel:RegisterEvent("PLAYER_REGEN_ENABLED")
	LocationPlusPanel:RegisterEvent("PET_BATTLE_CLOSE")
	LocationPlusPanel:RegisterEvent("PET_BATTLE_OPENING_START")
	self:RegisterEvent('PLAYER_ENTERING_WORLD')

	if E.db.locplus.LoginMsg then
		print(L["Location Plus "]..format("v|cff33ffff%s|r",LPB.version)..L[" is loaded. Thank you for using it."])
	end
end

E:RegisterModule(LPB:GetName())
