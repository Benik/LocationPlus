local E, L, V, P, G = unpack(ElvUI)
local LP = E:NewModule('LocationPlus', 'AceTimer-3.0', 'AceEvent-3.0')
local DT = E:GetModule('DataTexts')
local LSM = LibStub("LibSharedMedia-3.0")
local EP = LibStub("LibElvUIPlugin-1.0")
local addon, ns = ...

local _G = _G
local hooksecurefunc = hooksecurefunc

local format, pairs, tinsert = string.format, pairs, table.insert

local CreateFrame = CreateFrame
local ChatEdit_ChooseBoxForSend = ChatEdit_ChooseBoxForSend
local ChatEdit_ActivateChat = ChatEdit_ActivateChat
local C_Map_GetBestMapForUnit = C_Map.GetBestMapForUnit
local C_Map_GetPlayerMapPosition = C_Map.GetPlayerMapPosition
local GetMinimapZoneText = GetMinimapZoneText
local GetRealZoneText = GetRealZoneText
local GetSubZoneText = GetSubZoneText
local IsInInstance = IsInInstance
local InCombatLockdown = InCombatLockdown
local UnitAffectingCombat = UnitAffectingCombat
local UIFrameFadeIn = UIFrameFadeIn
local UIFrameFadeOut = UIFrameFadeOut
local ToggleFrame = ToggleFrame
local RegisterStateDriver = RegisterStateDriver
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local GameTooltip = _G.GameTooltip
local WorldMapFrame = _G.WorldMapFrame
local GetAddOnMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata

local ZoneTextFrame = _G.ZoneTextFrame
local UNKNOWN = UNKNOWN

LP.Title = format('|cffffa500%s|r|cffffffff%s|r ', 'Location', 'Plus')
LP.version = GetAddOnMetadata("ElvUI_LocPlus", "Version")
LP.Config = {}

if E.db.locplus == nil then E.db.locplus = {} end

local classColor = E:ClassColor(E.myclass, true)

local COORDS_WIDTH = 30 -- Coord panels width
local SPACING = 1 		-- Panel spacing

local function unpackColor(color)
	return color.r, color.g, color.b
end

-- mouse over the location panel
local function LocPanel_OnEnter(self)
	local db = E.db.locplus
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -4)
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("BOTTOM", self, "BOTTOM", 0, 0)

	if InCombatLockdown() and db.ttcombathide then
		GameTooltip:Hide()
	else
		LP:UpdateTooltip()
	end

	if db.mouseover then
		UIFrameFadeIn(self, 0.2, self:GetAlpha(), 1)
	end
end

-- mouse leaving the location panel
local function LocPanel_OnLeave(self)
	local db = E.db.locplus
	GameTooltip:Hide()
	if db.mouseover then
		UIFrameFadeOut(self, 0.2, self:GetAlpha(), db.malpha)
	end
end

-- clicking the location panel
local function LocPanel_OnClick(_, btn)
	if InCombatLockdown() then return end

	local db = E.db.locplus
	local leftDT = _G.LocPlusLeftDT
	local rightDT = _G.LocPlusRightDT

	local zoneText = GetRealZoneText() or UNKNOWN

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
				leftDT:SetScript("OnShow", function() db.dtshow = true end)
				leftDT:SetScript("OnHide", function() db.dtshow = false end)
				ToggleFrame(leftDT)
				ToggleFrame(rightDT)
			else
				ToggleFrame(WorldMapFrame)
			end
		end
	end

	if btn == "RightButton" then
		E:ToggleOptions() LibStub("AceConfigDialog-3.0-ElvUI"):SelectGroup("ElvUI", "locplus")
	end
end

-- Hide in combat, after fade function ends
local function LocPanelOnFade()
	_G.LocationPlusPanel:Hide()
end

-- Coords Creation
local function CreateCoords()
	local mapID = C_Map_GetBestMapForUnit("player")
	local mapPos = mapID and C_Map_GetPlayerMapPosition(mapID, "player")
	local x, y = 0, 0

	if mapPos then
		x, y = mapPos:GetXY()
	end

	local dig

	if E.db.locplus.dig then
		dig = 2
	else
		dig = 0
	end

	x = (mapPos and x) and E:Round(100 * x, dig) or 0
	y = (mapPos and y) and E:Round(100 * y, dig) or 0

	return x, y
end

local function HideDT()
	_G.LocPlusRightDT:SetShown(E.db.locplus.dtshow)
	_G.LocPlusLeftDT:SetShown(E.db.locplus.dtshow)
end

-- Location panel
function LP:CreateLocationPanel()
	local db = E.db.locplus

	local loc_panel = CreateFrame('Frame', 'LocationPlusPanel', E.UIParent, 'BackdropTemplate')
	loc_panel:SetTemplate('Default')
	loc_panel:Width(db.lpwidth or 200)
	loc_panel:Height(db.dtheight or 21)
	loc_panel:Point('TOP', E.UIParent, 'TOP', 0, -E.mult -22)
	loc_panel:SetFrameStrata(db.frameStrata or 'LOW')
	loc_panel:SetFrameLevel(db.frameLevel or 2)
	loc_panel:EnableMouse(true)
	loc_panel:SetScript('OnEnter', LocPanel_OnEnter)
	loc_panel:SetScript('OnLeave', LocPanel_OnLeave)
	loc_panel:SetScript('OnMouseUp', LocPanel_OnClick)

	-- Location Text
	loc_panel.Text = loc_panel:CreateFontString(nil, "OVERLAY")
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
			if db.mouseover then
				UIFrameFadeIn(self, 0.2, self:GetAlpha(), db.malpha)
			else
				UIFrameFadeIn(self, 0.2, self:GetAlpha(), 1)
			end
			self:Show()
		elseif db.combat then
			if event == "PLAYER_REGEN_DISABLED" then
				UIFrameFadeOut(self, 0.2, self:GetAlpha(), 0)
				self.fadeInfo.finishedFunc = LocPanelOnFade
			elseif event == "PLAYER_REGEN_ENABLED" then
				if db.mouseover then
					UIFrameFadeIn(self, 0.2, self:GetAlpha(), db.malpha)
				else
					UIFrameFadeIn(self, 0.2, self:GetAlpha(), 1)
				end
				self:Show()
			end
		end
	end)

	loc_panel:RegisterEvent("PLAYER_REGEN_DISABLED")
	loc_panel:RegisterEvent("PLAYER_REGEN_ENABLED")
	loc_panel:RegisterEvent("PET_BATTLE_CLOSE")
	loc_panel:RegisterEvent("PET_BATTLE_OPENING_START")

	-- Mover
	E:CreateMover(loc_panel, "LocationMover", L["LocationPlus "], nil, nil, nil, nil, nil, 'locplus')
end

-- Coord panels
function LP:CreateCoordPanels()
	local db = E.db.locplus
	local locPanel = _G.LocationPlusPanel

	-- X Coord panel
	local coordsX = CreateFrame('Frame', "XCoordsPanel", locPanel, 'BackdropTemplate')
	coordsX:SetTemplate('Default')
	coordsX:Width(COORDS_WIDTH)
	coordsX:Height(db.dtheight)
	coordsX:SetFrameStrata('LOW')
	coordsX.Text = coordsX:CreateFontString(nil, "OVERLAY")
	coordsX.Text:SetAllPoints()
	coordsX.Text:SetJustifyH("CENTER")
	coordsX.Text:SetJustifyV("MIDDLE")

	-- Y Coord panel
	local coordsY = CreateFrame('Frame', "YCoordsPanel", locPanel, 'BackdropTemplate')
	coordsY:SetTemplate('Default')
	coordsY:Width(COORDS_WIDTH)
	coordsY:Height(db.dtheight)
	coordsY:SetFrameStrata('LOW')
	coordsY.Text = coordsY:CreateFontString(nil, "OVERLAY")
	coordsY.Text:SetAllPoints()
	coordsY.Text:SetJustifyH("CENTER")
	coordsY.Text:SetJustifyV("MIDDLE")

	LP:CoordsColor()
end

-- Datatext panels
function LP:CreateDatatextPanels()
	local db = E.db.locplus
	local locPanel = _G.LocationPlusPanel

	-- Left coords Datatext panel
	local left_dtp = CreateFrame('Frame', 'LocPlusLeftDT', E.UIParent, 'BackdropTemplate')
	left_dtp:SetTemplate('Default', true)
	left_dtp:Width(db.dtwidth)
	left_dtp:Height(db.dtheight)
	left_dtp:SetFrameStrata('LOW')
	left_dtp:SetParent(locPanel)

	DT:RegisterPanel(left_dtp, 1, 'ANCHOR_BOTTOM', 0, -4)

	-- Right coords Datatext panel
	local right_dtp = CreateFrame('Frame', 'LocPlusRightDT', E.UIParent, 'BackdropTemplate')
	right_dtp:SetTemplate('Default', true)
	right_dtp:Width(db.dtwidth)
	right_dtp:Height(db.dtheight)
	right_dtp:SetFrameStrata('LOW')
	right_dtp:SetParent(locPanel)

	DT:RegisterPanel(right_dtp, 1, 'ANCHOR_BOTTOM', 0, -4)
end

-- mouse over option
function LP:MouseOver()
	local db = E.db.locplus
	local locPanel = _G.LocationPlusPanel

	if db.mouseover then
		locPanel:SetAlpha(db.malpha)
	else
		locPanel:SetAlpha(1)
	end
end

-- datatext panels width
function LP:DTWidth()
	local db = E.db.locplus

	LocPlusLeftDT:Width(db.dtwidth)
	LocPlusRightDT:Width(db.dtwidth)
end

-- all panels height
function LP:DTHeight()
	local db = E.db.locplus
	local locPanel = _G.LocationPlusPanel

	if db.ht then
		locPanel:Height((db.dtheight)+6)
	else
		locPanel:Height(db.dtheight)
	end

	_G.LocPlusLeftDT:Height(db.dtheight)
	_G.LocPlusRightDT:Height(db.dtheight)

	_G.XCoordsPanel:Height(db.dtheight)
	_G.YCoordsPanel:Height(db.dtheight)
end

-- Fonts
function LP:ChangeFont()
	local db = E.db.locplus
	local panels = {_G.LocationPlusPanel, _G.XCoordsPanel, _G.YCoordsPanel}

	for _, frame in pairs(panels) do
		if db.useDTfont then
			frame.Text:FontTemplate(LSM:Fetch('font', E.db.datatexts.font), E.db.datatexts.fontSize, E.db.datatexts.fontOutline)
		else
			frame.Text:FontTemplate(LSM:Fetch("font", db.lpfont), db.lpfontsize, db.lpfontflags)
		end
	end
end

function LP:ChangeDTFont()
	local db = E.db.locplus
	local dts = {_G.LocPlusLeftDT, _G.LocPlusRightDT}

	for panelName, panel in pairs(dts) do
		for i = 1, panel.numPoints do
			if panel.dataPanels[i] then
				if db.useDTfont then
					panel.dataPanels[i].text:FontTemplate(LSM:Fetch('font', E.db.datatexts.font), E.db.datatexts.fontSize, E.db.datatexts.fontOutline)
				else
					panel.dataPanels[i].text:FontTemplate(LSM:Fetch("font", db.lpfont), db.lpfontsize, db.lpfontflags)
				end
			end
		end

		if panelName and panel then
			DT:UpdatePanelInfo(panelName, panel)
		end
	end
end

-- Enable/Disable shadows
function LP:ShadowPanels()
	local db = E.db.locplus
	local addonPanels = {_G.LocationPlusPanel, _G.XCoordsPanel, _G.YCoordsPanel, _G.LocPlusLeftDT, _G.LocPlusRightDT}

	for _, frame in pairs(addonPanels) do
		frame:CreateShadow()
		frame.shadow:SetShown(db.shadow)
	end

	if db.shadow then
		SPACING = db.spacingAuto and 2 or db.spacingManual
	else
		SPACING = db.spacingAuto and 1 or db.spacingManual
	end

	self:HideCoords()
end

-- Show/Hide coord frames
function LP:HideCoords()
	local db = E.db.locplus
	local locPanel =_G.LocationPlusPanel
	local xCoords = _G.XCoordsPanel
	local yCoords = _G.YCoordsPanel
	local leftDT = _G.LocPlusLeftDT
	local rightDT = _G.LocPlusRightDT

	xCoords:Point('RIGHT', locPanel, 'LEFT', db.spacingAuto and -SPACING or -db.spacingManual, 0)
	yCoords:Point('LEFT', locPanel, 'RIGHT', db.spacingAuto and SPACING or db.spacingManual, 0)

	leftDT:ClearAllPoints()
	rightDT:ClearAllPoints()

	if (db.hidecoords) or (db.hidecoordsInInstance and IsInInstance()) then
		xCoords:Hide()
		yCoords:Hide()
		leftDT:Point('RIGHT', locPanel, 'LEFT', db.spacingAuto and -SPACING or -db.spacingManual, 0)
		rightDT:Point('LEFT', locPanel, 'RIGHT', db.spacingAuto and SPACING or db.spacingManual, 0)
	else
		xCoords:Show()
		yCoords:Show()
		leftDT:Point('RIGHT', xCoords, 'LEFT', db.spacingAuto and -SPACING or -db.spacingManual, 0)
		rightDT:Point('LEFT', yCoords, 'RIGHT', db.spacingAuto and SPACING or db.spacingManual, 0)
	end
end

-- Update Spacing
function LP:UpdateSpacing()
	LP:ShadowPanels()
	LP:HideCoords()
end

-- Toggle transparency
function LP:TransparentPanels()
	local db = E.db.locplus
	local addonPanels = {_G.LocationPlusPanel, _G.XCoordsPanel, _G.YCoordsPanel, _G.LocPlusLeftDT, _G.LocPlusRightDT}

	for _, frame in pairs(addonPanels) do
		frame:SetTemplate('NoBackdrop')
		if not db.noback then
			db.shadow = false
		elseif db.trans then
			frame:SetTemplate('Transparent')
		else
			frame:SetTemplate('Default')
		end
	end
end

function LP:StrataAndLevel()
	local db = E.db.locplus
	local locPanel = _G.LocationPlusPanel

	locPanel:SetFrameStrata(db.frameStrata)
	locPanel:SetFrameLevel(db.frameLevel)
end

function LP:PLAYER_REGEN_ENABLED()
	self:UpdateLocation()
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

function LP:UpdateLocation()
	if InCombatLockdown() or (UnitAffectingCombat("player") or UnitAffectingCombat("pet")) then
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end

	local db = E.db.locplus
	local subZoneText = GetMinimapZoneText() or ""
	local zoneText = GetRealZoneText() or UNKNOWN
	local displayLine
	local locPanel = _G.LocationPlusPanel

	-- zone and subzone
	if db.both then
		if (subZoneText ~= "") and (subZoneText ~= zoneText) then
			displayLine = zoneText .. ": " .. subZoneText
		else
			displayLine = subZoneText
		end
	else
		displayLine = subZoneText
	end

	-- Show Other (Level, Battle Pet Level, Fishing)
	if db.displayOther == 'RLEVEL' then
		local displaylvl = LP:GetLevelRange(zoneText) or ""
		if displaylvl ~= "" then
			displayLine = displayLine..displaylvl
		end
	elseif E.Retail and db.displayOther == 'PET' then
		local displaypet = LP:GetBattlePetLvl(zoneText) or ""
		if displaypet ~= "" then
			displayLine = displayLine..displaypet
		end
	elseif E.db.locplus.displayOther == 'PFISH' and not E.Retail then
		local displayfish = LP:GetFishingLvl(false) or ""
		if displayfish ~= "" then
			displayLine = displayLine..displayfish
		end
	else
		displayLine = displayLine
	end

	locPanel.Text:SetText(displayLine)

	-- Sizing
	local fixedwidth = (db.lpwidth + 18)
	local autowidth = (locPanel.Text:GetStringWidth() + 18)

	if db.lpauto then
		locPanel:Width(autowidth)
		locPanel.Text:Width(autowidth)
	else
		locPanel:Width(fixedwidth)
		if db.trunc then
			locPanel.Text:Width(fixedwidth - 18)
			locPanel.Text:SetWordWrap(false)
		elseif autowidth > fixedwidth then
			locPanel:Width(autowidth)
			locPanel.Text:Width(autowidth)
		end
	end
end

function LP:UpdateTextColor()
	-- Coloring
	local db = E.db.locplus
	local r, g, b
	local locPanel = _G.LocationPlusPanel

	if locPanel.Text ~= "" then
		if db.customColor == 1 then
			r, g, b = LP:GetStatus(true)
		elseif db.customColor == 2 then
			r, g, b = classColor.r, classColor.g, classColor.b
		else
			r, g, b = unpackColor(db.userColor)
		end
		locPanel.Text:SetTextColor(r, g, b)
	end
end

function LP:UpdateCoords()
	local x, y = CreateCoords()
	local xt, yt
	local xCoords = _G.XCoordsPanel
	local yCoords = _G.YCoordsPanel

	if (x == 0 or x == nil) and (y == 0 or y == nil) then
		xCoords.Text:SetText("-")
		yCoords.Text:SetText("-")

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
		xCoords.Text:SetText(xt)
		yCoords.Text:SetText(yt)
	end
end

function LP:UpdateVisibility()
	local db = E.db.locplus

	local visibility = db.visibility
	if visibility and visibility:match('[\n\r]') then
		visibility = visibility:gsub('[\n\r]','')
	end

	RegisterStateDriver(_G.LocationPlusPanel, "visibility", visibility)
end

-- Coord panels width
function LP:CoordsDigit()
	local xCoords = _G.XCoordsPanel
	local yCoords = _G.YCoordsPanel

	if E.db.locplus.dig then
		xCoords:Width(COORDS_WIDTH*1.5)
		yCoords:Width(COORDS_WIDTH*1.5)
	else
		xCoords:Width(COORDS_WIDTH)
		yCoords:Width(COORDS_WIDTH)
	end
end

function LP:CoordsColor()
	local db = E.db.locplus
	local r, g ,b

	if db.customCoordsColor == 1 then
		r, g, b = unpackColor(db.userColor)
	elseif db.customCoordsColor == 2 then
		r, g, b = classColor.r, classColor.g, classColor.b
	else
		r, g, b = unpackColor(db.userCoordsColor)
	end
	_G.XCoordsPanel.Text:SetTextColor(r, g, b)
	_G.YCoordsPanel.Text:SetTextColor(r, g, b)
end

-- Update changes
function LP:UpdateFrames()
	LP:TransparentPanels()
	LP:ShadowPanels()
	LP:DTHeight()
	LP:StrataAndLevel()
	LP:CoordsDigit()
	LP:MouseOver()
	LP:HideCoords()
	LP:UpdateTextColor()

	HideDT()
end

function LP:ToggleBlizZoneText()
	if E.db.locplus.zonetext then
		ZoneTextFrame:UnregisterAllEvents()
	else
		ZoneTextFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		ZoneTextFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
		ZoneTextFrame:RegisterEvent("ZONE_CHANGED")
	end
end

function LP:TimerUpdate()
	self:ScheduleRepeatingTimer('UpdateCoords', E.db.locplus.timer)
end

function LP:AddOptions()
	for _, func in pairs(LP.Config) do
		func()
	end
end

local function InjectDatatextOptions()
	local options = E.Options.args.datatexts.args.panels.args

	options.LocPlusLeftDT.name = L['LocationPlus Left Panel']
	options.LocPlusLeftDT.order = 1101

	options.LocPlusRightDT.name = L['LocationPlus Right Panel']
	options.LocPlusRightDT.order = 1102
end

function LP:LoadDataTexts(...)
	DT:UpdatePanelInfo('LocPlusRightDT')
	DT:UpdatePanelInfo('LocPlusLeftDT')
end

function LP:Initialize()
	LP:CreateLocationPanel()
	LP:CreateDatatextPanels()
	LP:CreateCoordPanels()

	LP:UpdateFrames()
	LP:ChangeFont()
	LP:UpdateCoords()
	LP:HideCoords()
	LP:UpdateTextColor()
	LP:TimerUpdate()
	LP:ToggleBlizZoneText()
	LP:UpdateVisibility()

	E:Delay(5, LP.ChangeDTFont) -- take a look at this
	LP:ScheduleRepeatingTimer('UpdateLocation', 0.5)

	LP:RegisterEvent("ZONE_CHANGED_NEW_AREA", LP.UpdateTextColor)
	LP:RegisterEvent("ZONE_CHANGED_INDOORS", LP.UpdateTextColor)
	LP:RegisterEvent("ZONE_CHANGED", LP.UpdateTextColor)

	hooksecurefunc(DT, 'UpdatePanelInfo', LP.UpdateFrames)
	hooksecurefunc(DT, 'UpdatePanelAttributes', LP.UpdateFrames)
	hooksecurefunc(DT, 'UpdatePanelAttributes', LP.ChangeDTFont)
	hooksecurefunc(DT, 'LoadDataTexts', LP.LoadDataTexts)

	EP:RegisterPlugin(addon, LP.AddOptions)
	tinsert(LP.Config, InjectDatatextOptions)

	if E.db.locplus.LoginMsg then
		print(LP.Title..format("v|cffffa500%s|r",LP.version)..L[" is loaded. Thank you for using it."])
	end
end

E:RegisterModule(LP:GetName())