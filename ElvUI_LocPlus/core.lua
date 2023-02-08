local E, L, V, P, G = unpack(ElvUI);
local LP = E:NewModule('LocationPlus', 'AceTimer-3.0', 'AceEvent-3.0');
local DT = E:GetModule('DataTexts');
local LSM = LibStub("LibSharedMedia-3.0");
local EP = LibStub("LibElvUIPlugin-1.0");
local addon, ns = ...

local format, tonumber, pairs, print, tinsert = string.format, tonumber, pairs, print, table.insert

local CreateFrame = CreateFrame
local ChatEdit_ChooseBoxForSend, ChatEdit_ActivateChat = ChatEdit_ChooseBoxForSend, ChatEdit_ActivateChat
local C_Map_GetBestMapForUnit = C_Map.GetBestMapForUnit
local C_Map_GetPlayerMapPosition = C_Map.GetPlayerMapPosition
local GetMinimapZoneText = GetMinimapZoneText
local GetRealZoneText, GetSubZoneText = GetRealZoneText, GetSubZoneText
local GetZonePVPInfo = GetZonePVPInfo
local IsInInstance, InCombatLockdown = IsInInstance, InCombatLockdown
local UIFrameFadeIn, UIFrameFadeOut, ToggleFrame = UIFrameFadeIn, UIFrameFadeOut, ToggleFrame
local IsControlKeyDown, IsShiftKeyDown = IsControlKeyDown, IsShiftKeyDown
local GameTooltip, WorldMapFrame = _G['GameTooltip'], _G['WorldMapFrame']

local UNKNOWN = UNKNOWN
local SANCTUARY_TERRITORY, ARENA, FRIENDLY, HOSTILE, CONTESTED_TERRITORY, COMBAT, AGGRO_WARNING_IN_INSTANCE = SANCTUARY_TERRITORY, ARENA, FRIENDLY, HOSTILE, CONTESTED_TERRITORY, COMBAT, AGGRO_WARNING_IN_INSTANCE

-- GLOBALS: LocationPlusPanel, LocPlusLeftDT, LocPlusRightDT, XCoordsPanel, YCoordsPanel, CUSTOM_CLASS_COLORS

LP.Title = format('|cffffa500%s|r|cffffffff%s|r ', 'Location', 'Plus')
LP.version = GetAddOnMetadata("ElvUI_LocPlus", "Version")
LP.Config = {}

if E.db.locplus == nil then E.db.locplus = {} end

local classColor = E:ClassColor(E.myclass, true)

local COORDS_WIDTH = 30 -- Coord panels width
local SPACING = 1 		-- Panel spacing

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

-- Hide in combat, after fade function ends
local function LocPanelOnFade()
	LocationPlusPanel:Hide()
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
				LocPlusLeftDT:SetScript("OnShow", function(self) E.db.locplus.dtshow = true; end)
				LocPlusLeftDT:SetScript("OnHide", function(self) E.db.locplus.dtshow = false; end)
				ToggleFrame(LocPlusLeftDT)
				ToggleFrame(LocPlusRightDT)
			else
				ToggleFrame(WorldMapFrame)
			end
		end
	end
	if btn == "RightButton" then
		E:ToggleOptions(); LibStub("AceConfigDialog-3.0-ElvUI"):SelectGroup("ElvUI", "locplus")
	end
end

-- Custom text color. Credits: Edoc
local color = { r = 1, g = 1, b = 1 }
local function unpackColor(color)
	return color.r, color.g, color.b
end

-- Location panel
local function CreateLocationPanel()
	local db = E.db.locplus
	local loc_panel = CreateFrame('Frame', 'LocationPlusPanel', E.UIParent, 'BackdropTemplate')
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
	loc_panel.Text = LocationPlusPanel:CreateFontString(nil, "OVERLAY")
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
	E:CreateMover(LocationPlusPanel, "LocationMover", L["LocationPlus "], nil, nil, nil, nil, nil, 'locplus')
end

local function HideDT()
	LocPlusRightDT:SetShown(E.db.locplus.dtshow)
	LocPlusLeftDT:SetShown(E.db.locplus.dtshow)
end

-- Coord panels
local function CreateCoordPanels()
	local db = E.db.locplus

	-- X Coord panel
	local coordsX = CreateFrame('Frame', "XCoordsPanel", LocationPlusPanel, 'BackdropTemplate')
	coordsX:Width(COORDS_WIDTH)
	coordsX:Height(db.dtheight)
	coordsX:SetFrameStrata('LOW')
	coordsX.Text = XCoordsPanel:CreateFontString(nil, "OVERLAY")
	coordsX.Text:SetAllPoints()
	coordsX.Text:SetJustifyH("CENTER")
	coordsX.Text:SetJustifyV("MIDDLE")

	-- Y Coord panel
	local coordsY = CreateFrame('Frame', "YCoordsPanel", LocationPlusPanel, 'BackdropTemplate')
	coordsY:Width(COORDS_WIDTH)
	coordsY:Height(db.dtheight)
	coordsY:SetFrameStrata('LOW')
	coordsY.Text = YCoordsPanel:CreateFontString(nil, "OVERLAY")
	coordsY.Text:SetAllPoints()
	coordsY.Text:SetJustifyH("CENTER")
	coordsY.Text:SetJustifyV("MIDDLE")

	LP:CoordsColor()
end

-- mouse over option
function LP:MouseOver()
	local db = E.db.locplus
	if db.mouseover then
		LocationPlusPanel:SetAlpha(db.malpha)
	else
		LocationPlusPanel:SetAlpha(1)
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
	if db.ht then
		LocationPlusPanel:Height((db.dtheight)+6)
	else
		LocationPlusPanel:Height(db.dtheight)
	end

	LocPlusLeftDT:Height(db.dtheight)
	LocPlusRightDT:Height(db.dtheight)

	XCoordsPanel:Height(db.dtheight)
	YCoordsPanel:Height(db.dtheight)
end

-- Fonts
function LP:ChangeFont()
	local db = E.db.locplus
	local panels = {LocationPlusPanel, XCoordsPanel, YCoordsPanel}

	for _, frame in pairs(panels) do
		if db.useDTfont then
			frame.Text:FontTemplate(LSM:Fetch('font', E.db.datatexts.font), E.db.datatexts.fontSize, E.db.datatexts.fontOutline)
		else
			frame.Text:FontTemplate(LSM:Fetch("font", db.lpfont), db.lpfontsize, db.lpfontflags)
		end
	end

	local dts = {LocPlusLeftDT, LocPlusRightDT}
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
		DT:UpdatePanelInfo(panelName, panel)
	end
end

-- Enable/Disable shadows
function LP:ShadowPanels()
	local db = E.db.locplus
	local panelsToAddShadow = {LocationPlusPanel, XCoordsPanel, YCoordsPanel, LocPlusLeftDT, LocPlusRightDT}

	for _, frame in pairs(panelsToAddShadow) do
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
	XCoordsPanel:Point('RIGHT', LocationPlusPanel, 'LEFT', db.spacingAuto and -SPACING or -db.spacingManual, 0)
	YCoordsPanel:Point('LEFT', LocationPlusPanel, 'RIGHT', db.spacingAuto and SPACING or db.spacingManual, 0)

	LocPlusLeftDT:ClearAllPoints()
	LocPlusRightDT:ClearAllPoints()

	if (db.hidecoords) or (db.hidecoordsInInstance and IsInInstance()) then
		XCoordsPanel:Hide()
		YCoordsPanel:Hide()
		LocPlusLeftDT:Point('RIGHT', LocationPlusPanel, 'LEFT', db.spacingAuto and -SPACING or -db.spacingManual, 0)
		LocPlusRightDT:Point('LEFT', LocationPlusPanel, 'RIGHT', db.spacingAuto and SPACING or db.spacingManual, 0)
	else
		XCoordsPanel:Show()
		YCoordsPanel:Show()
		LocPlusLeftDT:Point('RIGHT', XCoordsPanel, 'LEFT', db.spacingAuto and -SPACING or -db.spacingManual, 0)
		LocPlusRightDT:Point('LEFT', YCoordsPanel, 'RIGHT', db.spacingAuto and SPACING or db.spacingManual, 0)
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
	local panelsToAddTrans = {LocationPlusPanel, XCoordsPanel, YCoordsPanel, LocPlusLeftDT, LocPlusRightDT}

	for _, frame in pairs(panelsToAddTrans) do
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
	LocationPlusPanel:SetFrameStrata(db.frameStrata)
	LocationPlusPanel:SetFrameLevel(db.frameLevel)
end

function LP:PLAYER_REGEN_ENABLED()
	self:UpdateLocation()
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

function LP:UpdateLocation()
	if _G.InCombatLockdown() or (_G.UnitAffectingCombat("player") or _G.UnitAffectingCombat("pet")) then
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	local db = E.db.locplus
	local subZoneText = GetMinimapZoneText() or ""
	local zoneText = GetRealZoneText() or UNKNOWN;
	local displayLine

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

	LocationPlusPanel.Text:SetText(displayLine)

	-- Coloring
	local r, g, b
	if displayLine ~= "" then
		if db.customColor == 1 then
			r, g, b = LP:GetStatus(true)
		elseif db.customColor == 2 then
			r, g, b = classColor.r, classColor.g, classColor.b
		else
			r, g, b = unpackColor(db.userColor)
		end
		LocationPlusPanel.Text:SetTextColor(r, g, b)
	end

	-- Sizing
	local fixedwidth = (db.lpwidth + 18)
	local autowidth = (LocationPlusPanel.Text:GetStringWidth() + 18)

	if db.lpauto then
		LocationPlusPanel:Width(autowidth)
		LocationPlusPanel.Text:Width(autowidth)
	else
		LocationPlusPanel:Width(fixedwidth)
		if db.trunc then
			LocationPlusPanel.Text:Width(fixedwidth - 18)
			LocationPlusPanel.Text:SetWordWrap(false)
		elseif autowidth > fixedwidth then
			LocationPlusPanel:Width(autowidth)
			LocationPlusPanel.Text:Width(autowidth)
		end
	end
end

function LP:UpdateCoords()
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
function LP:CoordsDigit()
	if E.db.locplus.dig then
		XCoordsPanel:Width(COORDS_WIDTH*1.5)
		YCoordsPanel:Width(COORDS_WIDTH*1.5)
	else
		XCoordsPanel:Width(COORDS_WIDTH)
		YCoordsPanel:Width(COORDS_WIDTH)
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
	XCoordsPanel.Text:SetTextColor(r, g, b)
	YCoordsPanel.Text:SetTextColor(r, g, b)
end

-- Datatext panels
local function CreateDatatextPanels()
	local db = E.db.locplus
	-- Left coords Datatext panel
	local left_dtp = CreateFrame('Frame', 'LocPlusLeftDT', E.UIParent, 'BackdropTemplate')
	left_dtp:Width(db.dtwidth)
	left_dtp:Height(db.dtheight)
	left_dtp:SetFrameStrata('LOW')
	left_dtp:SetParent(LocationPlusPanel)

	DT:RegisterPanel(LocPlusLeftDT, 1, 'ANCHOR_BOTTOM', 0, -4)

	-- Right coords Datatext panel
	local right_dtp = CreateFrame('Frame', 'LocPlusRightDT', E.UIParent, 'BackdropTemplate')
	right_dtp:Width(db.dtwidth)
	right_dtp:Height(db.dtheight)
	right_dtp:SetFrameStrata('LOW')
	right_dtp:SetParent(LocationPlusPanel)

	DT:RegisterPanel(LocPlusRightDT, 1, 'ANCHOR_BOTTOM', 0, -4)
end

-- Update changes
function LP:Update()
	LP:TransparentPanels()
	LP:ShadowPanels()
	LP:DTHeight()
	LP:StrataAndLevel()
	HideDT()
	LP:CoordsDigit()
	LP:MouseOver()
	LP:HideCoords()
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
	E.Options.args.datatexts.args.panels.args.LocPlusLeftDT.name = L['LocationPlus Left Panel']
	E.Options.args.datatexts.args.panels.args.LocPlusLeftDT.order = 1101

	E.Options.args.datatexts.args.panels.args.LocPlusRightDT.name = L['LocationPlus Right Panel']
	E.Options.args.datatexts.args.panels.args.LocPlusRightDT.order = 1102
end

function LP:PLAYER_ENTERING_WORLD(...)
	self:ChangeFont()
	self:UpdateCoords()
	self:HideCoords()
end

function LP:LoadDataTexts(...)
	DT:UpdatePanelInfo('LocPlusRightDT')
	DT:UpdatePanelInfo('LocPlusLeftDT')
end

function LP:Initialize()
	CreateLocationPanel()
	CreateDatatextPanels()
	CreateCoordPanels()
	self:Update()
	self:TimerUpdate()
	self:ToggleBlizZoneText()
	self:ScheduleRepeatingTimer('UpdateLocation', 0.5)
	self:RegisterEvent('PLAYER_ENTERING_WORLD')
	hooksecurefunc(DT, 'UpdatePanelInfo', LP.Update)
	hooksecurefunc(DT, 'UpdatePanelAttributes', LP.Update)
	hooksecurefunc(DT, 'UpdatePanelAttributes', LP.ChangeFont)
	hooksecurefunc(DT, 'LoadDataTexts', LP.LoadDataTexts)

	EP:RegisterPlugin(addon, LP.AddOptions)
	tinsert(LP.Config, InjectDatatextOptions)

	if E.db.locplus.LoginMsg then
		print(LP.Title..format("v|cffffa500%s|r",LP.version)..L[" is loaded. Thank you for using it."])
	end
end

local function InitializeCallback()
	LP:Initialize()
end

E:RegisterModule(LP:GetName(), InitializeCallback)
