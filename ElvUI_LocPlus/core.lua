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
LP.Panels = {}

if E.db.locplus == nil then E.db.locplus = {} end

local classColor = E:ClassColor(E.myclass, true)

local COORDS_WIDTH = 30 -- Coord panels width
local SPACING = 1 		-- Panel spacing

local function unpackColor(color)
	return color.r, color.g, color.b
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

local function HideDT()
	_G.LocPlusRightDT:SetShown(E.db.locplus.dtshow)
	_G.LocPlusLeftDT:SetShown(E.db.locplus.dtshow)
end

-- Location panel
function LP:CreateLocationPanel()
	local db = E.db.locplus

	local locPanel = CreateFrame('Frame', 'LocationPlusPanel', E.UIParent, 'BackdropTemplate')
	locPanel:SetTemplate('Default')
	locPanel:Width(db.lpwidth or 200)
	locPanel:Height(db.dtheight or 21)
	locPanel:Point('TOP', E.UIParent, 'TOP', 0, -E.mult -22)
	locPanel:SetFrameStrata(db.frameStrata or 'LOW')
	locPanel:SetFrameLevel(db.frameLevel or 2)
	locPanel:EnableMouse(true)
	locPanel:SetScript('OnEnter', LocPanel_OnEnter)
	locPanel:SetScript('OnLeave', LocPanel_OnLeave)
	locPanel:SetScript('OnMouseUp', LocPanel_OnClick)

	-- Location Text
	locPanel.Text = locPanel:CreateFontString(nil, "OVERLAY")
	locPanel.Text:Point("CENTER", 0, 0)
	locPanel.Text:SetAllPoints()
	locPanel.Text:SetJustifyH("CENTER")
	locPanel.Text:SetJustifyV("MIDDLE")

	-- Hide in combat/Pet battle
	locPanel:SetScript("OnEvent", function(self, event)
		if event == "PET_BATTLE_OPENING_START" then
			UIFrameFadeOut(self, 0.2, self:GetAlpha(), 0)
			self.fadeInfo.finishedFunc = function() self:Hide() end
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
				self.fadeInfo.finishedFunc = function() self:Hide() end
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

	locPanel:RegisterEvent("PLAYER_REGEN_DISABLED")
	locPanel:RegisterEvent("PLAYER_REGEN_ENABLED")
	locPanel:RegisterEvent("PET_BATTLE_CLOSE")
	locPanel:RegisterEvent("PET_BATTLE_OPENING_START")

	-- Mover
	E:CreateMover(locPanel, "LocationMover", L["LocationPlus "], nil, nil, nil, nil, nil, 'locplus')

	self.locPanel = locPanel
	LP["Panels"][locPanel] = true
end

-- Coord panels
function LP:CreateCoordPanels()
	local db = E.db.locplus
	local locPanel = self.locPanel

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

	self.coordsX = coordsX
	LP["Panels"][coordsX] = true

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

	self.coordsY = coordsY
	LP["Panels"][coordsY] = true

	LP:CoordsColor()
end

-- Datatext panels
function LP:CreateDatatextPanels()
	local db = E.db.locplus
	local locPanel = self.locPanel

	-- Left coords Datatext panel
	local leftDT = CreateFrame('Frame', 'LocPlusLeftDT', E.UIParent, 'BackdropTemplate')
	leftDT:SetTemplate('Default', true)
	leftDT:Width(db.dtwidth)
	leftDT:Height(db.dtheight)
	leftDT:SetFrameStrata('LOW')
	leftDT:SetParent(locPanel)

	DT:RegisterPanel(leftDT, 1, 'ANCHOR_BOTTOM', 0, -4)
	self.leftDT = leftDT
	LP["Panels"][leftDT] = true

	-- Right coords Datatext panel
	local rightDT = CreateFrame('Frame', 'LocPlusRightDT', E.UIParent, 'BackdropTemplate')
	rightDT:SetTemplate('Default', true)
	rightDT:Width(db.dtwidth)
	rightDT:Height(db.dtheight)
	rightDT:SetFrameStrata('LOW')
	rightDT:SetParent(locPanel)

	DT:RegisterPanel(rightDT, 1, 'ANCHOR_BOTTOM', 0, -4)
	self.rightDT = rightDT
	LP["Panels"][rightDT] = true

	LP:ChangeDTFont()
end

-- mouse over option
function LP:MouseOver()
	local db = E.db.locplus
	local locPanel = self.locPanel

	if db.mouseover then
		locPanel:SetAlpha(db.malpha)
	else
		locPanel:SetAlpha(1)
	end
end

-- datatext panels width
function LP:DTWidth()
	local db = E.db.locplus

	self.leftDT:Width(db.dtwidth)
	self.rightDT:Width(db.dtwidth)
end

-- all panels height
function LP:DTHeight()
	local db = E.db.locplus
	local locPanel = self.locPanel

	if db.ht then
		locPanel:Height((db.dtheight)+6)
	else
		locPanel:Height(db.dtheight)
	end

	self.leftDT:Height(db.dtheight)
	self.rightDT:Height(db.dtheight)

	self.coordsX:Height(db.dtheight)
	self.coordsY:Height(db.dtheight)
end

-- Fonts
function LP:ChangeFont()
	local db = E.db.locplus
	local panels = LP.Panels

	for frame, _ in pairs(panels) do
		if frame.Text then
			if db.useDTfont then
				frame.Text:FontTemplate(LSM:Fetch('font', E.db.datatexts.font), E.db.datatexts.fontSize, E.db.datatexts.fontOutline)
			else
				frame.Text:FontTemplate(LSM:Fetch("font", db.lpfont), db.lpfontsize, db.lpfontflags)
			end
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
			DT:ForceUpdate_DataText(panelName)
		end
	end
end

-- Enable/Disable shadows
function LP:ShadowPanels()
	local db = E.db.locplus
	local addonPanels = LP.Panels

	for frame, _ in pairs(addonPanels) do
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
	local locPanel = self.locPanel
	local xCoords = self.coordsX
	local yCoords = self.coordsY
	local leftDT = self.leftDT
	local rightDT = self.rightDT

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
	local addonPanels = LP.Panels

	for frame, _ in pairs(addonPanels) do
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
	local locPanel = self.locPanel

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
	local locPanel = self.locPanel

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
	local locPanel = self.locPanel

	if not locPanel then return end
	local r, g, b

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
	local xCoords = self.coordsX
	local yCoords = self.coordsY

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

	RegisterStateDriver(self.locPanel, "visibility", visibility)
end

-- Coord panels width
function LP:CoordsDigit()
	local xCoords = self.coordsX
	local yCoords = self.coordsY

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
	self.coordsX.Text:SetTextColor(r, g, b)
	self.coordsY.Text:SetTextColor(r, g, b)
end

-- Update changes
function LP:UpdateDatatextFrames()
	LP:TransparentPanels()
	LP:ShadowPanels()
	LP:DTHeight()
	LP:StrataAndLevel()
	LP:CoordsDigit()
	LP:MouseOver()
	LP:HideCoords()
	LP:UpdateTextColor()
	LP:ChangeFont()

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

	LP:UpdateDatatextFrames()
	LP:UpdateCoords()
	LP:TimerUpdate()
	LP:ToggleBlizZoneText()
	LP:UpdateVisibility()

	LP:ScheduleRepeatingTimer('UpdateLocation', 0.5)

	LP:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdateTextColor")
	LP:RegisterEvent("ZONE_CHANGED_INDOORS", "UpdateTextColor")
	LP:RegisterEvent("ZONE_CHANGED", "UpdateTextColor")

	hooksecurefunc(DT, 'UpdatePanelInfo', LP.UpdateDatatextFrames)
	hooksecurefunc(DT, 'UpdatePanelAttributes', LP.UpdateDatatextFrames)
	hooksecurefunc(DT, 'UpdatePanelAttributes', LP.ChangeDTFont)
	hooksecurefunc(DT, 'LoadDataTexts', LP.LoadDataTexts)

	EP:RegisterPlugin(addon, LP.AddOptions)
	tinsert(LP.Config, InjectDatatextOptions)

	if E.db.locplus.LoginMsg then
		print(LP.Title..format("v|cffffa500%s|r",LP.version)..L[" is loaded. Thank you for using it."])
	end
end

E:RegisterModule(LP:GetName())