--[[
Name: LibTourist-3.0
Revision: $Rev: 199 $
Author(s): Odica (maintainer), originally created by ckknight and Arrowmaster
Documentation: https://www.wowace.com/projects/libtourist-3-0/pages/api-reference
SVN: svn://svn.wowace.com/wow/libtourist-3-0/mainline/trunk
Description: A library to provide information about zones and instances.
License: MIT
]]

local MAJOR_VERSION = "LibTourist-3.0"
local MINOR_VERSION = 90000 + tonumber(("$Revision: 199 $"):match("(%d+)"))

if not LibStub then error(MAJOR_VERSION .. " requires LibStub") end

local Tourist, oldLib = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not Tourist then
	return
end
if oldLib then
	oldLib = {}
	for k, v in pairs(Tourist) do
		Tourist[k] = nil
		oldLib[k] = v
	end
end

local function trace(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg)
end

-- Localization tables
local BZ = {}
local BZR = {}


trace("|r|cffff4422! -- Tourist:|r Warning: This is an alpha version with limited functionality." )			


local playerLevel = UnitLevel("player")
--trace("INIT: Player Level = "..tostring(playerLevel))

local isAlliance, isHorde, isNeutral
do
	local faction = UnitFactionGroup("player")
	isAlliance = faction == "Alliance"
	isHorde = faction == "Horde"
	isNeutral = not isAlliance and not isHorde
end

local isWestern = GetLocale() == "enUS" or GetLocale() == "deDE" or GetLocale() == "frFR" or GetLocale() == "esES"

local Azeroth = "Azeroth"
local Kalimdor = "Kalimdor"
local Eastern_Kingdoms = "Eastern Kingdoms"
local Outland = "Outland"
local Northrend = "Northrend"
local The_Maelstrom = "The Maelstrom"
local Pandaria = "Pandaria"
local Draenor = "Draenor"
local Broken_Isles = "Broken Isles"
local Argus = "Argus"
local Zandalar = "Zandalar"
local Kul_Tiras = "Kul Tiras"

local X_Y_ZEPPELIN = "%s - %s Zeppelin"
local X_Y_BOAT = "%s - %s Boat"
local X_Y_PORTAL = "%s - %s Portal"
local X_Y_TELEPORT = "%s - %s Teleport"


if GetLocale() == "zhCN" then
	X_Y_ZEPPELIN = "%s - %s 飞艇"
	X_Y_BOAT = "%s - %s 船"
	X_Y_PORTAL = "%s - %s 传送门"
	X_Y_TELEPORT = "%s - %s 传送门"
elseif GetLocale() == "zhTW" then
	X_Y_ZEPPELIN = "%s - %s 飛艇"
	X_Y_BOAT = "%s - %s 船"
	X_Y_PORTAL = "%s - %s 傳送門"
	X_Y_TELEPORT = "%s - %s 傳送門"
elseif GetLocale() == "frFR" then
	X_Y_ZEPPELIN = "Zeppelin %s - %s"
	X_Y_BOAT = "Bateau %s - %s"
	X_Y_PORTAL = "Portail %s - %s"
	X_Y_TELEPORT = "Téléport %s - %s"
elseif GetLocale() == "koKR" then
	X_Y_ZEPPELIN = "%s - %s 비행선"
	X_Y_BOAT = "%s - %s 배"
	X_Y_PORTAL = "%s - %s 차원문"
	X_Y_TELEPORT = "%s - %s 차원문"
end

local recZones = {}
local recInstances = {}
local lows = setmetatable({}, {__index = function() return 0 end})
local highs = setmetatable({}, getmetatable(lows))
local continents = {}
local instances = {}
local paths = {}
local types = {}
local groupSizes = {}
local groupMinSizes = {}
local groupMaxSizes = {}
local groupAltSizes = {}
local factions = {}
local yardWidths = {}
local yardHeights = {}
local yardXOffsets = {}
local yardYOffsets = {}
local continentScales = {}
local fishing = {}
local battlepet_lows = {}
local battlepet_highs = {}
local cost = {}
local textures = {}
local textures_rev = {}
local complexOfInstance = {}
local zoneComplexes = {}
local entrancePortals_zone = {}
local entrancePortals_x = {}
local entrancePortals_y = {}

local zoneIDtoContinentID = {}
local continentZoneToMapID = {}

local zoneMapIDs = {}
local zoneMapIDs_rev = {}

local COSMIC_MAP_ID = 946

-- HELPER AND LOOKUP FUNCTIONS -------------------------------------------------------------

local function PLAYER_LEVEL_UP(self, level)
	playerLevel = UnitLevel("player")
	--trace("Player Level = "..tostring(playerLevel))
	
	for k in pairs(recZones) do
		recZones[k] = nil
	end
	for k in pairs(recInstances) do
		recInstances[k] = nil
	end
	for k in pairs(cost) do
		cost[k] = nil
	end

	for zone in pairs(lows) do
		if not self:IsHostile(zone) then
			local low, high, scaled = self:GetLevel(zone)
			if scaled then
				low = scaled
				high = scaled
			end
			
			local zoneType = self:GetType(zone)
			if zoneType == "Zone" or zoneType == "PvP Zone" and low and high then
				if low <= playerLevel and playerLevel <= high then
					recZones[zone] = true
				end
			elseif zoneType == "Battleground" and low and high then
				local playerLevel = playerLevel
				if low <= playerLevel and playerLevel <= high then
					recInstances[zone] = true
				end
			elseif zoneType == "Instance" and low and high then
				if low <= playerLevel and playerLevel <= high then
					recInstances[zone] = true
				end
			end
		end
	end
end





-- Public alternative for GetMapContinents, removes the map IDs that were added to its output in WoW 6.0
-- Note: GetMapContinents has been removed entirely in 8.0
function Tourist:GetMapContinentsAlt()
	local continents = C_Map.GetMapChildrenInfo(COSMIC_MAP_ID, Enum.UIMapType.Continent, true)
	local retValue = {}
	for i, continentInfo in ipairs(continents) do
		--trace("Continent "..tostring(i)..": "..continentInfo.mapID..": ".. continentInfo.name)
		retValue[continentInfo.mapID] = continentInfo.name
	end
	return retValue
	
--	local temp = { GetMapContinents() }
--	if tonumber(temp[1]) then
--		-- The first value is an ID instead of a name -> WoW 6.0 or later
--		local continents = {}
--		local index = 0
--		for i = 2, #temp, 2 do
--			index = index + 1
--			continents[index] = temp[i]
--		end
--		return continents
--	else
--		-- Backward compatibility for pre-WoW 6.0
--		return temp
--	end
end

-- Public Alternative for GetMapZones because GetMapZones does NOT return all zones (as of 6.0.2), 
-- making its output useless as input for for SetMapZoom. 
-- Note: GetMapZones has been removed entirely in 8.0, just as SetMapZoom
-- NOTE: This method does not convert duplicate zone names for lookup in LibTourist,
-- use GetUniqueZoneNameForLookup for that.
local mapZonesByContinentID = {}
function Tourist:GetMapZonesAlt(continentID)
	if mapZonesByContinentID[continentID] then
		return mapZonesByContinentID[continentID]
	else	
		local mapZones = {}
		local mapChildrenInfo = { C_Map.GetMapChildrenInfo(continentID, Enum.UIMapType.Zone, true) }
		for key, zones in pairs(mapChildrenInfo) do  -- don't know what this extra table is for
			for zoneIndex, zone in pairs(zones) do
				-- Get the localized zone name
				mapZones[zone.mapID] = zone.name
			end
		end

		-- Add to cache
		mapZonesByContinentID[continentID] = mapZones		
		
		return mapZones
		
--[[		
		local zones = {}
		SetMapZoom(continentID)
		local continentAreaID = GetCurrentMapAreaID()
		for i=1, 100, 1 do 
			SetMapZoom(continentID, i) 
			local zoneAreaID = GetCurrentMapAreaID() 
			if zoneAreaID == continentAreaID then 
				-- If the index gets out of bounds, the continent map is returned -> exit the loop
				break 
			end 
			-- Get the localized zone name and store it
--			zones[i] = GetMapNameByID(zoneAreaID)  -- 8.0: GetMapNameByID removed
			zones[i] = C_Map.GetMapInfo(zoneAreaID).name
		end
		-- Cache
		mapZonesByContinentID[continentID] = zones
		return zones
]]--
	end
end

--[[
-- Local version of GetMapZonesAlt, used during initialisation of LibTourist
local function GetMapZonesAltLocal(continentID)
	local zones = {}
	SetMapZoom(continentID)
	local continentAreaID = GetCurrentMapAreaID()
	for i=1, 100, 1 do 
		SetMapZoom(continentID, i) 
		local zoneAreaID = GetCurrentMapAreaID() 
		if zoneAreaID == continentAreaID then 
			-- If the index is out of bounds, the continent map is returned -> exit the loop
			break 
		end 
		-- Add area IDs to lookup tables
		zoneIDtoContinentID[zoneAreaID] = continentID
		if not continentZoneToMapID[continentID] then
			continentZoneToMapID[continentID] = {}
		end
		continentZoneToMapID[continentID][i] = zoneAreaID
		-- Get the localized zone name and store it
		--zones[i] = GetMapNameByID(zoneAreaID)  -- 8.0: GetMapNameByID removed
		zones[i] = C_Map.GetMapInfo(zoneAreaID).name
	end
	
	-- Cache (for GetMapZonesAlt)
	mapZonesByContinentID[continentID] = zones
	return zones	
end
]]--


-- Public alternative for GetMapNameByID, returns a unique localized zone name
-- to be used to lookup data in LibTourist
function Tourist:GetMapNameByIDAlt(zoneAreaID)
	--local zoneName = GetMapNameByID(zoneAreaID)  -- 8.0: GetMapNameByID removed
	local zoneName = C_Map.GetMapInfo(zoneAreaID).name
	local continentID = zoneIDtoContinentID[zoneAreaID]
	return Tourist:GetUniqueZoneNameForLookup(zoneName, continentID)
end 


-- Returns a unique localized zone name to be used to lookup data in LibTourist,
-- based on a localized or English zone name
function Tourist:GetUniqueZoneNameForLookup(zoneName, continentID)
	if continentID == 5 then
		if zoneName == BZ["The Maelstrom"] or zoneName == "The Maelstrom" then
			zoneName = BZ["The Maelstrom"].." (zone)"
		end
	end
	if continentID == 7 then
		if zoneName == BZ["Nagrand"] or zoneName == "Nagrand"  then
			zoneName = BZ["Nagrand"].." ("..BZ["Draenor"]..")"
		end
		if zoneName == BZ["Shadowmoon Valley"] or zoneName == "Shadowmoon Valley"  then
			zoneName = BZ["Shadowmoon Valley"].." ("..BZ["Draenor"]..")"
		end
		if zoneName == BZ["Hellfire Citadel"] or zoneName == "Hellfire Citadel"  then
			zoneName = BZ["Hellfire Citadel"].." ("..BZ["Draenor"]..")"
		end
	end
	if continentID == 8 then
		if zoneName == BZ["Dalaran"] or zoneName == "Dalaran"  then
			zoneName = BZ["Dalaran"].." ("..BZ["Broken Isles"]..")"
		end
		if zoneName == BZ["The Violet Hold"] or zoneName == "The Violet Hold"  then
			zoneName = BZ["The Violet Hold"].." ("..BZ["Broken Isles"]..")"
		end
	end
	return zoneName
end

-- Returns a unique English zone name to be used to lookup data in LibTourist,
-- based on a localized or English zone name
function Tourist:GetUniqueEnglishZoneNameForLookup(zoneName, continentID)
	if continentID == 5 then
		if zoneName == BZ["The Maelstrom"] or zoneName == "The Maelstrom" then
			zoneName = "The Maelstrom (zone)"
		end
	end
	if continentID == 7 then
		if zoneName == BZ["Nagrand"] or zoneName == "Nagrand" then
			zoneName = "Nagrand (Draenor)"
		end
		if zoneName == BZ["Shadowmoon Valley"] or zoneName == "Shadowmoon Valley" then
			zoneName = "Shadowmoon Valley (Draenor)"
		end
		if zoneName == BZ["Hellfire Citadel"] or zoneName == "Hellfire Citadel" then
			zoneName = "Hellfire Citadel (Draenor)"
		end
	end
	if continentID == 8 then
		if zoneName == BZ["Dalaran"] or zoneName == "Dalaran" then
			zoneName = "Dalaran (Broken Isles)"
		end	
		if zoneName == BZ["The Violet Hold"] or zoneName == "The Violet Hold"  then
			zoneName = "The Violet Hold (Broken Isles)"
		end
	end
	return zoneName
end

-- Minimum fishing skill to fish these zones junk-free (Draenor: to catch Enormous Fish only)
function Tourist:GetFishingLevel(zone)
	return fishing[zone]
end

function Tourist:GetBattlePetLevel(zone)
	return battlepet_lows[zone], battlepet_highs[zone]
end

-- function has been replaced by GetScaledZoneLevel
-- WoW Legions: most zones scale to the player's level between 100 and 110
--function Tourist:GetLegionZoneLevel()
--	local playerLvl = playerLevel
--
--	if playerLvl <= 100 then 
--		return 100
--	elseif playerLvl >= 110 then
--		return 110
--	else
--		return playerLvl
--	end
--end

-- WoW patch 7.3.5: most zones now scale - within their level range - to the player's level
function Tourist:GetScaledZoneLevel(zone)
	local playerLvl = playerLevel

	if playerLvl <= lows[zone] then 
		return lows[zone]
	elseif playerLvl >= highs[zone] then
		return highs[zone]
	else
		return playerLvl
	end
end

function Tourist:GetLevelString(zone)
	local lo, hi, scaled = Tourist:GetLevel(zone)
	
	if lo and hi then
		if scaled then
			if lo == hi then
				return tostring(scaled).." ("..tostring(lo)..")"
			else
				return tostring(scaled).." ("..tostring(lo).."-"..tostring(hi)..")"
			end
		else	
			if lo == hi then
				return tostring(lo)
			else
				return tostring(lo).."-"..tostring(hi)
			end
		end
	else
		return tostring(lo) or tostring(hi) or ""
	end
end

function Tourist:GetBattlePetLevelString(zone)
	local lo, hi = Tourist:GetBattlePetLevel(zone)
	if lo and hi then
		if lo == hi then
			return tostring(lo)
		else
			return tostring(lo).."-"..tostring(hi)
		end
	else
		return tostring(lo) or tostring(hi) or ""
	end
end

function Tourist:GetLevel(zone)

	if types[zone] == "Battleground" then
		-- Note: Not all BG's start at level 10, but all BG's support players up to MAX_PLAYER_LEVEL.

		local playerLvl = playerLevel
		if playerLvl <= lows[zone] then
			-- Player is too low level to enter the BG -> return the lowest available bracket
			-- by assuming the player is at the min level required for the BG.
			playerLvl = lows[zone]
		end

		-- Find the most suitable bracket
		if playerLvl >= MAX_PLAYER_LEVEL then
			return MAX_PLAYER_LEVEL, MAX_PLAYER_LEVEL, nil
		elseif playerLvl >= 105 then
			return 105, 109, nil
		elseif playerLvl >= 100 then
			return 100, 104, nil			
		elseif playerLvl >= 95 then
			return 95, 99, nil
		elseif playerLvl >= 90 then
			return 90, 94, nil
		elseif playerLvl >= 85 then
			return 85, 89, nil
		elseif playerLvl >= 80 then
			return 80, 84, nil
		elseif playerLvl >= 75 then
			return 75, 79, nil
		elseif playerLvl >= 70 then
			return 70, 74, nil
		elseif playerLvl >= 65 then
			return 65, 69, nil
		elseif playerLvl >= 60 then
			return 60, 64, nil
		elseif playerLvl >= 55 then
			return 55, 59, nil
		elseif playerLvl >= 50 then
			return 50, 54, nil
		elseif playerLvl >= 45 then
			return 45, 49, nil
		elseif playerLvl >= 40 then
			return 40, 44, nil
		elseif playerLvl >= 35 then
			return 35, 39, nil
		elseif playerLvl >= 30 then
			return 30, 34, nil
		elseif playerLvl >= 25 then
			return 25, 29, nil
		elseif playerLvl >= 20 then
			return 20, 24, nil
		elseif playerLvl >= 15 then
			return 15, 19, nil
		else
			return 10, 14, nil
		end
	else
		if types[zone] ~= "Arena" and types[zone] ~= "Complex" and types[zone] ~= "City" and types[zone] ~= "Continent" then
			-- Zones and Instances (scaling):
			return lows[zone], highs[zone], Tourist:GetScaledZoneLevel(zone)
		else
			-- Other zones
			return lows[zone], highs[zone], nil
		end
	end
end

function Tourist:GetBattlePetLevelColor(zone, petLevel)
	local low, high = self:GetBattlePetLevel(zone)
	
	return Tourist:CalculateLevelColor(low, high, petLevel)
end


function Tourist:GetLevelColor(zone)
	local low, high, scaled = self:GetLevel(zone)

	if types[zone] == "Battleground" then
		if playerLevel < low then
			-- player cannot enter the lowest bracket of the BG -> red
			return 1, 0, 0
		end
	end
	
	if scaled then
		return Tourist:CalculateLevelColor(scaled, scaled, playerLevel)
	else
		return Tourist:CalculateLevelColor(low, high, playerLevel)
	end
end
	
	
function Tourist:CalculateLevelColor(low, high, currentLevel)
	local midBracket = (low + high) / 2

	if low <= 0 and high <= 0 then
		-- City or level unknown -> White
		return 1, 1, 1
	elseif currentLevel == low and currentLevel == high then
		-- Exact match, one-level bracket -> Yellow
		return 1, 1, 0
	elseif currentLevel <= low - 3 then
		-- Player is three or more levels short of Low -> Red
		return 1, 0, 0
	elseif currentLevel < low then
		-- Player is two or less levels short of Low -> sliding scale between Red and Orange
		-- Green component goes from 0 to 0.5
		local greenComponent = (currentLevel - low + 3) / 6
		return 1, greenComponent, 0
	elseif currentLevel == low then
		-- Player is at low, at least two-level bracket -> Orange
		return 1, 0.5, 0
	elseif currentLevel < midBracket then
		-- Player is between low and the middle of the bracket -> sliding scale between Orange and Yellow
		-- Green component goes from 0.5 to 1
		local halfBracketSize = (high - low) / 2
		local posInBracketHalf = currentLevel - low
		local greenComponent = 0.5 + (posInBracketHalf / halfBracketSize) * 0.5
		return 1, greenComponent, 0
	elseif currentLevel == midBracket then
		-- Player is at the middle of the bracket -> Yellow
		return 1, 1, 0
	elseif currentLevel < high then
		-- Player is between the middle of the bracket and High -> sliding scale between Yellow and Green
		-- Red component goes from 1 to 0
		local halfBracketSize = (high - low) / 2
		local posInBracketHalf = currentLevel - midBracket
		local redComponent = 1 - (posInBracketHalf / halfBracketSize)
		return redComponent, 1, 0
	elseif currentLevel == high then
		-- Player is at High, at least two-level bracket -> Green
		return 0, 1, 0
	elseif currentLevel < high + 3 then
		-- Player is up to three levels above High -> sliding scale between Green and Gray
		-- Red and Blue components go from 0 to 0.5
		-- Green component goes from 1 to 0.5
		local pos = (currentLevel - high) / 3
		local redAndBlueComponent = pos * 0.5
		local greenComponent = 1 - redAndBlueComponent
		return redAndBlueComponent, greenComponent, redAndBlueComponent
	else
		-- Player is at High + 3 or above -> Gray
		return 0.5, 0.5, 0.5
	end
end

function Tourist:GetFactionColor(zone)
	if factions[zone] == "Sanctuary" then
		-- Blue
		return 0.41, 0.8, 0.94
	elseif self:IsPvPZone(zone) then
		-- Orange
		return 1, 0.7, 0
	elseif factions[zone] == (isHorde and "Alliance" or "Horde") then
		-- Red
		return 1, 0, 0
	elseif factions[zone] == (isHorde and "Horde" or "Alliance") then
		-- Green
		return 0, 1, 0
	else
		-- Yellow
		return 1, 1, 0
	end
end

function Tourist:GetZoneYardSize(zone)
--  Out of order -----
	if 1==1 then return nil, nil end
--  ------------------	
	return yardWidths[zone], yardHeights[zone]
end

function Tourist:GetZoneYardOffset(zone)
--  Out of order -----
	if 1==1 then return nil, nil end
--  ------------------	
	return yardXOffsets[zone], yardYOffsets[zone]
end


-- This function is used to calculate the distance in yards between two sets of coordinates
-- Zone can be a continent or Azeroth
function Tourist:GetYardDistance(zone1, x1, y1, zone2, x2, y2)
--  Out of order -----
	if 1==1 then return nil end
--  ------------------	


	local zone1_continent = continents[zone1]
	local zone2_continent = continents[zone2]
	
	if not zone1_continent or not zone2_continent then
		-- Unknown zone
		return nil
	end
	if (zone1_continent == Outland) ~= (zone2_continent == Outland) then
		-- Cannot calculate distances from or to outside Outland
		return nil
	end
	if (zone1_continent == The_Maelstrom or zone2_continent == The_Maelstrom) and (zone1 ~= zone2) then
		-- Cannot calculate distances from or to outside The Maelstrom
		-- In addition, in The Maelstrom only distances within a single zone can be calculated
		-- as the zones are not geographically related to each other
		return nil
	end
	if (zone1_continent == Draenor) ~= (zone2_continent == Draenor) then
		-- Cannot calculate distances from or to outside Draenor
		return nil
	end
	
	-- Get the zone sizes in yards
	local zone1_yardWidth = yardWidths[zone1]
	local zone1_yardHeight = yardHeights[zone1]
	local zone2_yardWidth = yardWidths[zone2]
	local zone2_yardHeight = yardHeights[zone2]
	if not zone1_yardWidth or not zone2_yardWidth or zone1_yardWidth == 0 or zone2_yardWidth == 0 then
		-- Need zone sizes to continue
		return nil
	end

	-- Convert position coordinates (a value between 0 and 1) to yards, measured from the top and the left of the map
	local x1_yard = zone1_yardWidth * x1
	local y1_yard = zone1_yardHeight * y1
	local x2_yard = zone2_yardWidth * x2
	local y2_yard = zone2_yardHeight * y2

	if zone1 ~= zone2 then
		-- The two locations are not within the same zone. Get the zone offsets (their position at the continent map), which
		-- are also measured from the top and the left of the map
		local zone1_yardXOffset = yardXOffsets[zone1]
		local zone1_yardYOffset = yardYOffsets[zone1]
		local zone2_yardXOffset = yardXOffsets[zone2]
		local zone2_yardYOffset = yardYOffsets[zone2]	
	
		-- Don't apply zone offsets if a zone is a continent (this includes Azeroth)
		if zone1 == zone1_continent then
			zone1_yardXOffset = 0
			zone1_yardYOffset = 0
		end
		if zone2 == zone2_continent then
			zone2_yardXOffset = 0
			zone2_yardYOffset = 0
		end
	
		if not zone1_yardXOffset or not zone1_yardYOffset or not zone2_yardXOffset or not zone2_yardYOffset then
			-- Need all offsets to continue
			return nil
		end

		-- Calculate the positions on the continent map, in yards
		x1_yard = x1_yard + zone1_yardXOffset
		y1_yard = y1_yard + zone1_yardYOffset

		x2_yard = x2_yard + zone2_yardXOffset
		y2_yard = y2_yard + zone2_yardYOffset

		if zone1_continent ~= zone2_continent then
			-- The two locations are not on the same continent
			-- Possible continents here are the Azeroth continents, except The Maelstrom.
			local cont1_scale = continentScales[zone1_continent]
			local cont1_XOffset = yardXOffsets[zone1_continent]
			local cont1_YOffset = yardYOffsets[zone1_continent]
			local cont2_scale = continentScales[zone2_continent]
			local cont2_XOffset = yardXOffsets[zone2_continent]
			local cont2_YOffset = yardYOffsets[zone2_continent]
			
			-- Calculate x and y on the Azeroth map, expressed in Azeroth yards
			if zone1 ~= Azeroth then
				x1_yard = (x1_yard * cont1_scale) + cont1_XOffset
				y1_yard = (y1_yard * cont1_scale) + cont1_YOffset
			end
			if zone2 ~= Azeroth then
				x2_yard = (x2_yard * cont2_scale) + cont2_XOffset
				y2_yard = (y2_yard * cont2_scale) + cont2_YOffset
			end
			
			-- Calculate distance, in Azeroth yards
			local x_diff = x1_yard - x2_yard
			local y_diff = y1_yard - y2_yard
			local distAz = x_diff*x_diff + y_diff*y_diff
			
			if zone1 ~= Azeroth then
				-- Correct the distance for the source continent scale
				return (distAz^0.5) / cont1_scale
			else
				return (distAz^0.5)
			end
		end
	end

	-- x and y for both locations are now at the same map level (a zone or a continent) -> calculate distance
	local x_diff = x1_yard - x2_yard
	local y_diff = y1_yard - y2_yard
	local dist_2 = x_diff*x_diff + y_diff*y_diff
	return dist_2^0.5
end

-- This function is used to calculate the coordinates of a location in zone1, on the map of zone2.
-- Zone can be a continent or Azeroth
function Tourist:TransposeZoneCoordinate(x, y, zone1, zone2)
--  Out of order -----
	if 1==1 then return nil, nil end
--  ------------------	

--	trace("TZC: z1 = "..tostring(zone1)..", z2 = "..tostring(zone2))

	if zone1 == zone2 then
		-- Nothing to do
		return x, y
	end

	local zone1_continent = continents[zone1]
	local zone2_continent = continents[zone2]
	if not zone1_continent or not zone2_continent then
		-- Unknown zone
		return nil
	end
	if (zone1_continent == Outland) ~= (zone2_continent == Outland) then
		-- Cannot transpose from or to outside Outland
		return nil
	end
	if (zone1_continent == The_Maelstrom or zone2_continent == The_Maelstrom) then
		-- Cannot transpose from, to or within The Maelstrom
		return nil
	end
	if (zone1_continent == Draenor) ~= (zone2_continent == Draenor) then
		-- Cannot transpose from or to outside Draenor
		return nil
	end
	
	-- Get the zone sizes in yards
	local zone1_yardWidth = yardWidths[zone1]
	local zone1_yardHeight = yardHeights[zone1]
	local zone2_yardWidth = yardWidths[zone2]
	local zone2_yardHeight = yardHeights[zone2]
	if not zone1_yardWidth or not zone2_yardWidth or zone1_yardWidth == 0 or zone2_yardWidth == 0 then
		-- Need zone sizes to continue
		return nil
	end
	
	-- Get zone offsets
	local zone1_yardXOffset = yardXOffsets[zone1]
	local zone1_yardYOffset = yardYOffsets[zone1]
	local zone2_yardXOffset = yardXOffsets[zone2]
	local zone2_yardYOffset = yardYOffsets[zone2]	
	if not zone1_yardXOffset or not zone1_yardYOffset or not zone2_yardXOffset or not zone2_yardYOffset then
		-- Need all offsets to continue
		return nil
	end
	
	-- Don't apply zone offsets if a zone is a continent (this includes Azeroth)
	if zone1 == zone1_continent then
		zone1_yardXOffset = 0
		zone1_yardYOffset = 0
	end
	if zone2 == zone2_continent then
		zone2_yardXOffset = 0
		zone2_yardYOffset = 0
	end

	-- Convert source coordinates (a value between 0 and 1) to yards, measured from the top and the left of the map
	local x_yard = zone1_yardWidth * x
	local y_yard = zone1_yardHeight * y

	-- Calculate the positions on the continent map, in yards
	x_yard = x_yard + zone1_yardXOffset
	y_yard = y_yard + zone1_yardYOffset

	if zone1_continent ~= zone2_continent then
		-- Target zone is not on the same continent
		-- Possible continents here are the Azeroth continents, except The Maelstrom.
		local cont1_scale = continentScales[zone1_continent]
		local cont1_XOffset = yardXOffsets[zone1_continent]
		local cont1_YOffset = yardYOffsets[zone1_continent]
		local cont2_scale = continentScales[zone2_continent]
		local cont2_XOffset = yardXOffsets[zone2_continent]
		local cont2_YOffset = yardYOffsets[zone2_continent]

		if zone1 ~= Azeroth then
			-- Translate the coordinate from the source continent to Azeroth
			x_yard = (x_yard * cont1_scale) + cont1_XOffset
			y_yard = (y_yard * cont1_scale) + cont1_YOffset
		end
			
		if zone2 ~= Azeroth then
			-- Translate the coordinate from Azeroth to the target continent
			x_yard = (x_yard - cont2_XOffset) / cont2_scale
			y_yard = (y_yard - cont2_YOffset) / cont2_scale
		end
	end

	-- 'Move' (transpose) the coordinates to the target zone
	x_yard = x_yard - zone2_yardXOffset
	y_yard = y_yard - zone2_yardYOffset

	-- Convert yards back to coordinates
	x = x_yard / zone2_yardWidth
	y = y_yard / zone2_yardHeight

	return x, y
end

local zonesToIterate = setmetatable({}, {__index = function(self, key)
	local t = {}
	self[key] = t
	for k,v in pairs(continents) do
		if v == key and v ~= k and yardXOffsets[k] then
			t[#t+1] = k
		end
	end
	return t
end})


-- This function is used to find the actual zone a player is in, including coordinates for that zone, if the current map 
-- is a map that contains the player position, but is not the map of the zone where the player really is.
-- x, y = player position on current map
-- zone = the zone of the current map
function Tourist:GetBestZoneCoordinate(x, y, zone)
--  Out of order -----
	if 1==1 then return nil, nil, nil end
--  ------------------	

	-- This only works properly if we have a player position and the current map zone is not a continent or so
	if not x or not y or not zone or x ==0 or y == 0 or Tourist:IsContinent(zone) then
		return x, y, zone
	end

	-- Get current map zone data
	local zone_continent = continents[zone]
	local zone_yardXOffset = yardXOffsets[zone]
	local zone_yardYOffset = yardYOffsets[zone]
	local zone_yardWidth = yardWidths[zone]
	local zone_yardHeight = yardHeights[zone]
	if not zone_yardXOffset or not zone_yardYOffset or not zone_yardWidth or not zone_yardHeight then
		-- Need all offsets to continue
		return x, y, zone
	end

	-- Convert coordinates to offsets in yards (within the zone)
	local x_yard = zone_yardWidth * x
	local y_yard = zone_yardHeight * y

	-- Translate the location to a location on the continent map
	x_yard = x_yard + zone_yardXOffset
	y_yard = y_yard + zone_yardYOffset
	
	local best_zone, best_x, best_y, best_value

	-- Loop through all zones on the continent...
	for _,z in ipairs(zonesToIterate[zone_continent]) do
		local z_yardXOffset = yardXOffsets[z]
		local z_yardYOffset = yardYOffsets[z]
		local z_yardWidth = yardWidths[z]
		local z_yardHeight = yardHeights[z]

		-- Translate the coordinates to the zone
		local x_yd = x_yard - z_yardXOffset
		local y_yd = y_yard - z_yardYOffset

		if x_yd >= 0 and y_yd >= 0 and x_yd <= z_yardWidth and y_yd <= z_yardHeight then
			-- Coordinates are within the probed zone
			if types[z] == "City" then
				-- City has no adjacent zones -> done
				return x_yd/z_yardWidth, y_yd/z_yardHeight, z
			end
			-- Calculate the midpoint of the zone map
			local x_tmp = x_yd - z_yardWidth / 2
			local y_tmp = y_yd - z_yardHeight / 2
			-- Calculate the distance (sort of, no need to sqrt)
			local value = x_tmp*x_tmp + y_tmp*y_tmp
			if not best_value or value < best_value then
				-- Lowest distance wins (= closest to map center)
				best_zone = z
				best_value = value
				best_x = x_yd/z_yardWidth
				best_y = y_yd/z_yardHeight
			end
		end
	end
	
	if not best_zone then
		-- No best zone found -> best map is the continent map
		return x_yard / yardWidths[zone_continent], y_yard / yardHeights[zone_continent], zone_continent
	end
	
	return best_x, best_y, best_zone
end


local function retNil() 
	return nil 
end
	
local function retOne(object, state)
	if state == object then
		return nil
	else
		return object
	end
end

local function retNormal(t, position)
	return (next(t, position))
end

local function round(num, digits)
	-- banker's rounding
	local mantissa = 10^digits
	local norm = num*mantissa
	norm = norm + 0.5
	local norm_f = math.floor(norm)
	if norm == norm_f and (norm_f % 2) ~= 0 then
		return (norm_f-1)/mantissa
	end
	return norm_f/mantissa
end

local function mysort(a,b)
	if not lows[a] then
		return false
	elseif not lows[b] then
		return true
	else
		local aval, bval = groupSizes[a] or groupMaxSizes[a], groupSizes[b] or groupMaxSizes[b]
		if aval and bval then
			if aval ~= bval then
				return aval < bval
			end
		end
		aval, bval = lows[a], lows[b]
		if aval ~= bval then
			return aval < bval
		end
		aval, bval = highs[a], highs[b]
		if aval ~= bval then
			return aval < bval
		end
		return a < b
	end
end
local t = {}
local function myiter(t)
	local n = t.n
	n = n + 1
	local v = t[n]
	if v then
		t[n] = nil
		t.n = n
		return v
	else
		t.n = nil
	end
end
function Tourist:IterateZoneInstances(zone)
	local inst = instances[zone]

	if not inst then
		return retNil
	elseif type(inst) == "table" then
		for k in pairs(t) do
			t[k] = nil
		end
		for k in pairs(inst) do
			t[#t+1] = k
		end
		table.sort(t, mysort)
		t.n = 0
		return myiter, t, nil
	else
		return retOne, inst, nil
	end
end

function Tourist:IterateZoneComplexes(zone)
	local compl = zoneComplexes[zone]

	if not compl then
		return retNil
	elseif type(compl) == "table" then
		for k in pairs(t) do
			t[k] = nil
		end
		for k in pairs(compl) do
			t[#t+1] = k
		end
		table.sort(t, mysort)
		t.n = 0
		return myiter, t, nil
	else
		return retOne, compl, nil
	end
end

function Tourist:GetInstanceZone(instance)
	for k, v in pairs(instances) do
		if v then
			if type(v) == "string" then
				if v == instance then
					return k
				end
			else -- table
				for l in pairs(v) do
					if l == instance then
						return k
					end
				end
			end
		end
	end
end

function Tourist:GetComplexZone(complex)
	for k, v in pairs(zoneComplexes) do
		if v then
			if type(v) == "string" then
				if v == complex then
					return k
				end
			else -- table
				for l in pairs(v) do
					if l == complex then
						return k
					end
				end
			end
		end
	end
end

function Tourist:DoesZoneHaveInstances(zone)
	return not not instances[zone]
end

function Tourist:DoesZoneHaveComplexes(zone)
	return not not zoneComplexes[zone]
end

local zonesInstances
local function initZonesInstances()
	if not zonesInstances then
		zonesInstances = {}
		for zone, v in pairs(lows) do
			if types[zone] ~= "Transport" then
				zonesInstances[zone] = true
			end
		end
	end
	initZonesInstances = nil
end

function Tourist:IterateZonesAndInstances()
	if initZonesInstances then
		initZonesInstances()
	end
	return retNormal, zonesInstances, nil
end

local function zoneIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and (types[k] == "Instance" or types[k] == "Battleground" or types[k] == "Arena" or types[k] == "Complex") do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateZones()
	if initZonesInstances then
		initZonesInstances()
	end
	return zoneIter, nil, nil
end

local function instanceIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and (types[k] ~= "Instance" and types[k] ~= "Battleground" and types[k] ~= "Arena") do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateInstances()
	if initZonesInstances then
		initZonesInstances()
	end
	return instanceIter, nil, nil
end

local function bgIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and types[k] ~= "Battleground" do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateBattlegrounds()
	if initZonesInstances then
		initZonesInstances()
	end
	return bgIter, nil, nil
end

local function arIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and types[k] ~= "Arena" do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateArenas()
	if initZonesInstances then
		initZonesInstances()
	end
	return arIter, nil, nil
end

local function compIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and types[k] ~= "Complex" do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateComplexes()
	if initZonesInstances then
		initZonesInstances()
	end
	return compIter, nil, nil
end

local function pvpIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and types[k] ~= "PvP Zone" do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IteratePvPZones()
	if initZonesInstances then
		initZonesInstances()
	end
	return pvpIter, nil, nil
end

local function allianceIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and factions[k] ~= "Alliance" do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateAlliance()
	if initZonesInstances then
		initZonesInstances()
	end
	return allianceIter, nil, nil
end

local function hordeIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and factions[k] ~= "Horde" do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateHorde()
	if initZonesInstances then
		initZonesInstances()
	end
	return hordeIter, nil, nil
end

if isHorde then
	Tourist.IterateFriendly = Tourist.IterateHorde
	Tourist.IterateHostile = Tourist.IterateAlliance
else
	Tourist.IterateFriendly = Tourist.IterateAlliance
	Tourist.IterateHostile = Tourist.IterateHorde
end

local function sanctIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and factions[k] ~= "Sanctuary" do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateSanctuaries()
	if initZonesInstances then
		initZonesInstances()
	end
	return sanctIter, nil, nil
end

local function contestedIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and factions[k] do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateContested()
	if initZonesInstances then
		initZonesInstances()
	end
	return contestedIter, nil, nil
end

local function kalimdorIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and continents[k] ~= Kalimdor do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateKalimdor()
	if initZonesInstances then
		initZonesInstances()
	end
	return kalimdorIter, nil, nil
end

local function easternKingdomsIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and continents[k] ~= Eastern_Kingdoms do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateEasternKingdoms()
	if initZonesInstances then
		initZonesInstances()
	end
	return easternKingdomsIter, nil, nil
end

local function outlandIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and continents[k] ~= Outland do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateOutland()
	if initZonesInstances then
		initZonesInstances()
	end
	return outlandIter, nil, nil
end

local function northrendIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and continents[k] ~= Northrend do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateNorthrend()
	if initZonesInstances then
		initZonesInstances()
	end
	return northrendIter, nil, nil
end

local function theMaelstromIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and continents[k] ~= The_Maelstrom do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateTheMaelstrom()
	if initZonesInstances then
		initZonesInstances()
	end
	return theMaelstromIter, nil, nil
end

local function pandariaIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and continents[k] ~= Pandaria do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IteratePandaria()
	if initZonesInstances then
		initZonesInstances()
	end
	return pandariaIter, nil, nil
end


local function draenorIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and continents[k] ~= Draenor do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateDraenor()
	if initZonesInstances then
		initZonesInstances()
	end
	return draenorIter, nil, nil
end


local function brokenislesIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and continents[k] ~= Broken_Isles do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateBrokenIsles()
	if initZonesInstances then
		initZonesInstances()
	end
	return brokenislesIter, nil, nil
end


function Tourist:IterateRecommendedZones()
	return retNormal, recZones, nil
end

function Tourist:IterateRecommendedInstances()
	return retNormal, recInstances, nil
end

function Tourist:HasRecommendedInstances()
	return next(recInstances) ~= nil
end

function Tourist:IsInstance(zone)
	local t = types[zone]
	return t == "Instance" or t == "Battleground" or t == "Arena"
end

function Tourist:IsZone(zone)
	local t = types[zone]
	return t and t ~= "Instance" and t ~= "Battleground" and t ~= "Transport" and t ~= "Arena" and t ~= "Complex"
end

function Tourist:IsContinent(zone)
	local t = types[zone]
	return t == "Continent"
end

function Tourist:GetComplex(zone)
	return complexOfInstance[zone]
end

function Tourist:GetType(zone)
	return types[zone] or "Zone"
end

function Tourist:IsZoneOrInstance(zone)
	local t = types[zone]
	return t and t ~= "Transport"
end

function Tourist:IsTransport(zone)
	local t = types[zone]
	return t == "Transport"
end

function Tourist:IsComplex(zone)
	local t = types[zone]
	return t == "Complex"
end

function Tourist:IsBattleground(zone)
	local t = types[zone]
	return t == "Battleground"
end

function Tourist:IsArena(zone)
	local t = types[zone]
	return t == "Arena"
end

function Tourist:IsPvPZone(zone)
	local t = types[zone]
	return t == "PvP Zone"
end

function Tourist:IsCity(zone)
	local t = types[zone]
	return t == "City"
end

function Tourist:IsAlliance(zone)
	return factions[zone] == "Alliance"
end

function Tourist:IsHorde(zone)
	return factions[zone] == "Horde"
end

if isHorde then
	Tourist.IsFriendly = Tourist.IsHorde
	Tourist.IsHostile = Tourist.IsAlliance
else
	Tourist.IsFriendly = Tourist.IsAlliance
	Tourist.IsHostile = Tourist.IsHorde
end

function Tourist:IsSanctuary(zone)
	return factions[zone] == "Sanctuary"
end

function Tourist:IsContested(zone)
	return not factions[zone]
end

function Tourist:GetContinent(zone)
	return continents[zone] or UNKNOWN
end

function Tourist:IsInKalimdor(zone)
	return continents[zone] == Kalimdor
end

function Tourist:IsInEasternKingdoms(zone)
	return continents[zone] == Eastern_Kingdoms
end

function Tourist:IsInOutland(zone)
	return continents[zone] == Outland
end

function Tourist:IsInNorthrend(zone)
	return continents[zone] == Northrend
end

function Tourist:IsInTheMaelstrom(zone)
	return continents[zone] == The_Maelstrom
end

function Tourist:IsInPandaria(zone)
	return continents[zone] == Pandaria
end

function Tourist:IsInDraenor(zone)
	return continents[zone] == Draenor
end

function Tourist:IsInBrokenIsles(zone)
	return continents[zone] == Broken_Isles
end

function Tourist:GetInstanceGroupSize(instance)
	return groupSizes[instance] or groupMaxSizes[instance] or 0
end

function Tourist:GetInstanceGroupMinSize(instance)
	return groupMinSizes[instance] or groupSizes[instance] or 0
end

function Tourist:GetInstanceGroupMaxSize(instance)
	return groupMaxSizes[instance] or groupSizes[instance] or 0
end

function Tourist:GetInstanceGroupSizeString(instance, includeAltSize)
	local retValue
	if groupSizes[instance] then
		-- Fixed size
		retValue = tostring(groupSizes[instance])
	elseif groupMinSizes[instance] and groupMaxSizes[instance] then
		-- Variable size
		if groupMinSizes[instance] == groupMaxSizes[instance] then
			-- ...but equal
			retValue = tostring(groupMinSizes[instance])
		else
			retValue = tostring(groupMinSizes[instance]).."-"..tostring(groupMaxSizes[instance])
		end
	else
		-- No size known
		return ""
	end
	if includeAltSize and groupAltSizes[instance] then
		-- Add second size
		retValue = retValue.." or "..tostring(groupAltSizes[instance])
	end
	return retValue
end

function Tourist:GetInstanceAltGroupSize(instance)
	return groupAltSizes[instance] or 0
end

function Tourist:GetTexture(zone)
	return textures[zone]
end

function Tourist:GetZoneMapID(zone)
	return zoneMapIDs[zone]
end

-- Returns the MapAreaID for a given continent ID and zone Index (the index of the zone within the continent)
function Tourist:GetMapAreaIDByContinentZone(continentID, zoneIndex)
	if continentID and continentZoneToMapID[continentID] then
		return continentZoneToMapID[continentID][zoneIndex]
	else
		return nil
	end
end

-- Returns the MapAreaID of a zone based on the texture name
function Tourist:GetZoneMapIDFromTexture(texture)
	if not texture then
		return -1
	end
	local zone = textures_rev[texture]
	if zone then
		return zoneMapIDs[zone]
	else
		-- Might be phased terrain, look for "_terrain<number>" postfix
		local pos1 = string.find(texture, "_terrain")
		if pos1 then
			-- Remove the postfix from the texture name and try again
			texture = string.sub(texture, 0, pos1 - 1)
			zone = textures_rev[texture]
			if zone then
				return zoneMapIDs[zone]
			end
		end
		-- Might be tiered terrain (garrison), look for "_tier<number>" postfix
		local pos2 = string.find(texture, "_tier")
		if pos2 then
			-- Remove the postfix from the texture name and try again
			texture = string.sub(texture, 0, pos2 - 1)
			zone = textures_rev[texture]
			if zone then
				return zoneMapIDs[zone]
			end
		end
	end
	return nil
end

function Tourist:GetZoneFromTexture(texture)
	if not texture then
		return "Azeroth"
	end
	local zone = textures_rev[texture]
	if zone then
		return zone
	else
		-- Might be phased terrain, look for "_terrain<number>" postfix
		local pos1 = string.find(texture, "_terrain")
		if pos1 then
			-- Remove the postfix from the texture name and try again
			texture = string.sub(texture, 0, pos1 - 1)
			zone = textures_rev[texture]
			if zone then
				return zone
			end
		end
		-- Might be tiered terrain (garrison), look for "_tier<number>" postfix
		local pos2 = string.find(texture, "_tier")
		if pos2 then
			-- Remove the postfix from the texture name and try again
			texture = string.sub(texture, 0, pos2 - 1)
			zone = textures_rev[texture]
			if zone then
				return zone
			end
		end
	end
	return nil
end

function Tourist:GetEnglishZoneFromTexture(texture)
	if not texture then
		return "Azeroth"
	end
	local zone = textures_rev[texture]
	if zone then
		return BZR[zone]
	else
		-- Might be phased terrain, look for "_terrain<number>" postfix
		local pos1 = string.find(texture, "_terrain")
		if pos1 then
			-- Remove the postfix from the texture name
			texture = string.sub(texture, 0, pos1 - 1)
			zone = textures_rev[texture]
			if zone then
				return BZR[zone]
			end
		end
		-- Might be tiered terrain (garrison), look for "_tier<number>" postfix
		local pos2 = string.find(texture, "_tier")
		if pos2 then
			-- Remove the postfix from the texture name and try again
			texture = string.sub(texture, 0, pos2 - 1)
			zone = textures_rev[texture]
			if zone then
				return BZR[zone]
			end
		end
	end
	return nil
end

function Tourist:GetEntrancePortalLocation(instance)
	return entrancePortals_zone[instance], entrancePortals_x[instance], entrancePortals_y[instance]
end

local inf = math.huge
local stack = setmetatable({}, {__mode='k'})
local function iterator(S)
	local position = S['#'] - 1
	S['#'] = position
	local x = S[position]
	if not x then
		for k in pairs(S) do
			S[k] = nil
		end
		stack[S] = true
		return nil
	end
	return x
end

setmetatable(cost, {
	__index = function(self, vertex)
		local price = 1

		if lows[vertex] > playerLevel then
			price = price * (1 + math.ceil((lows[vertex] - playerLevel) / 6))
		end

		if factions[vertex] == (isHorde and "Horde" or "Alliance") then
			price = price / 2
		elseif factions[vertex] == (isHorde and "Alliance" or "Horde") then
			if types[vertex] == "City" then
				price = price * 10
			else
				price = price * 3
			end
		end

		if types[x] == "Transport" then
			price = price * 2
		end

		self[vertex] = price
		return price
	end
})

function Tourist:IteratePath(alpha, bravo)
	if paths[alpha] == nil or paths[bravo] == nil then
		return retNil
	end

	local d = next(stack) or {}
	stack[d] = nil
	local Q = next(stack) or {}
	stack[Q] = nil
	local S = next(stack) or {}
	stack[S] = nil
	local pi = next(stack) or {}
	stack[pi] = nil

	for vertex, v in pairs(paths) do
		d[vertex] = inf
		Q[vertex] = v
	end
	d[alpha] = 0

	while next(Q) do
		local u
		local min = inf
		for z in pairs(Q) do
			local value = d[z]
			if value < min then
				min = value
				u = z
			end
		end
		if min == inf then
			return retNil
		end
		Q[u] = nil
		if u == bravo then
			break
		end

		local adj = paths[u]
		if type(adj) == "table" then
			local d_u = d[u]
			for v in pairs(adj) do
				local c = d_u + cost[v]
				if d[v] > c then
					d[v] = c
					pi[v] = u
				end
			end
		elseif adj ~= false then
			local c = d[u] + cost[adj]
			if d[adj] > c then
				d[adj] = c
				pi[adj] = u
			end
		end
	end

	local i = 1
	local last = bravo
	while last do
		S[i] = last
		i = i + 1
		last = pi[last]
	end

	for k in pairs(pi) do
		pi[k] = nil
	end
	for k in pairs(Q) do
		Q[k] = nil
	end
	for k in pairs(d) do
		d[k] = nil
	end
	stack[pi] = true
	stack[Q] = true
	stack[d] = true

	S['#'] = i

	return iterator, S
end

local function retWithOffset(t, key)
	while true do
		key = next(t, key)
		if not key then
			return nil
		end
		if yardYOffsets[key] then
			return key
		end
	end
end

function Tourist:IterateBorderZones(zone, zonesOnly)
	local path = paths[zone]
	if not path then
		return retNil
	elseif type(path) == "table" then
		return zonesOnly and retWithOffset or retNormal, path
	else
		if zonesOnly and not yardYOffsets[path] then
			return retNil
		end
		return retOne, path
	end
end

function Tourist:GetLookupTable()
	return BZ
end

function Tourist:GetReverseLookupTable()
	return BZR
end

--------------------------------------------------------------------------------------------------------
--                                            Localization                                            --
--------------------------------------------------------------------------------------------------------
local MapIdLookupTable = {
    [1] = "Durotar",
    [2] = "Burning Blade Coven",
    [3] = "Tiragarde Keep",
    [4] = "Tiragarde Keep",
    [5] = "Skull Rock",
    [6] = "Dustwind Cave",
    [7] = "Mulgore",
    [8] = "Palemane Rock",
    [9] = "The Venture Co. Mine",
    [10] = "Northern Barrens",
    [11] = "Wailing Caverns",
    [12] = "Kalimdor",
    [13] = "Eastern Kingdoms",
    [14] = "Arathi Highlands",
    [15] = "Badlands",
    [16] = "Uldaman",
    [17] = "Blasted Lands",
    [18] = "Tirisfal Glades",
    [19] = "Scarlet Monastery Entrance",
    [20] = "Keeper's Rest",
    [21] = "Silverpine Forest",
    [22] = "Western Plaguelands",
    [23] = "Eastern Plaguelands",
    [24] = "Light's Hope Chapel",
    [25] = "Hillsbrad Foothills",
    [26] = "The Hinterlands",
    [27] = "Dun Morogh",
    [28] = "Coldridge Pass",
    [29] = "The Grizzled Den",
    [30] = "New Tinkertown",
    [31] = "Gol'Bolar Quarry",
    [32] = "Searing Gorge",
    [33] = "Blackrock Mountain",
    [34] = "Blackrock Mountain",
    [35] = "Blackrock Mountain",
    [36] = "Burning Steppes",
    [37] = "Elwynn Forest",
    [38] = "Fargodeep Mine",
    [39] = "Fargodeep Mine",
    [40] = "Jasperlode Mine",
    [41] = "Dalaran",
    [42] = "Deadwind Pass",
    [43] = "The Master's Cellar",
    [44] = "The Master's Cellar",
    [45] = "The Master's Cellar",
    [46] = "Karazhan Catacombs",
    [47] = "Duskwood",
    [48] = "Loch Modan",
    [49] = "Redridge Mountains",
    [50] = "Northern Stranglethorn",
    [50] = "Northern Stranglethorn",
    [51] = "Swamp of Sorrows",
    [52] = "Westfall",
    [53] = "Gold Coast Quarry",
    [54] = "Jangolode Mine",
    [55] = "The Deadmines",
    [56] = "Wetlands",
    [57] = "Teldrassil",
    [58] = "Shadowthread Cave",
    [59] = "Fel Rock",
    [60] = "Ban'ethil Barrow Den",
    [61] = "Ban'ethil Barrow Den",
    [62] = "Darkshore",
    [63] = "Ashenvale",
    [64] = "Thousand Needles",
    [65] = "Stonetalon Mountains",
    [66] = "Desolace",
    [67] = "Maraudon",
    [68] = "Maraudon",
    [69] = "Feralas",
    [70] = "Dustwallow Marsh",
    [71] = "Tanaris",
    [72] = "The Noxious Lair",
    [73] = "The Gaping Chasm",
    [74] = "Caverns of Time",
    [75] = "Caverns of Time",
    [76] = "Azshara",
    [77] = "Felwood",
    [78] = "Un'Goro Crater",
    [79] = "The Slithering Scar",
    [80] = "Moonglade",
    [81] = "Silithus",
    [82] = "Twilight's Run",
    [83] = "Winterspring",
    [84] = "Stormwind City",
    [85] = "Orgrimmar",
    [86] = "Orgrimmar",
    [87] = "Ironforge",
    [88] = "Thunder Bluff",
    [89] = "Darnassus",
    [90] = "Undercity",
    [91] = "Alterac Valley",
    [92] = "Warsong Gulch",
    [93] = "Arathi Basin",
    [94] = "Eversong Woods",
    [95] = "Ghostlands",
    [96] = "Amani Catacombs",
    [97] = "Azuremyst Isle",
    [98] = "Tides' Hollow",
    [99] = "Stillpine Hold",
    [100] = "Hellfire Peninsula",
    [101] = "Outland",
    [102] = "Zangarmarsh",
    [103] = "The Exodar",
    [104] = "Shadowmoon Valley",
    [105] = "Blade's Edge Mountains",
    [106] = "Bloodmyst Isle",
    [107] = "Nagrand",
    [108] = "Terokkar Forest",
    [109] = "Netherstorm",
    [110] = "Silvermoon City",
    [111] = "Shattrath City",
    [112] = "Eye of the Storm",
    [113] = "Northrend",
    [114] = "Borean Tundra",
    [115] = "Dragonblight",
    [116] = "Grizzly Hills",
    [117] = "Howling Fjord",
    [118] = "Icecrown",
    [119] = "Sholazar Basin",
    [120] = "The Storm Peaks",
    [121] = "Zul'Drak",
    [122] = "Isle of Quel'Danas",
    [123] = "Wintergrasp",
    [124] = "Plaguelands: The Scarlet Enclave",
    [125] = "Dalaran",
    [126] = "Dalaran",
    [127] = "Crystalsong Forest",
    [128] = "Strand of the Ancients",
    [129] = "The Nexus",
    [130] = "The Culling of Stratholme",
    [131] = "The Culling of Stratholme",
    [132] = "Ahn'kahet: The Old Kingdom",
    [133] = "Utgarde Keep",
    [134] = "Utgarde Keep",
    [135] = "Utgarde Keep",
    [136] = "Utgarde Pinnacle",
    [137] = "Utgarde Pinnacle",
    [138] = "Halls of Lightning",
    [139] = "Halls of Lightning",
    [140] = "Halls of Stone",
    [141] = "The Eye of Eternity",
    [142] = "The Oculus",
    [143] = "The Oculus",
    [144] = "The Oculus",
    [145] = "The Oculus",
    [146] = "The Oculus",
    [147] = "Ulduar",
    [148] = "Ulduar",
    [149] = "Ulduar",
    [150] = "Ulduar",
    [150] = "Ulduar",
    [151] = "Ulduar",
    [152] = "Ulduar",
    [153] = "Gundrak",
    [154] = "Gundrak",
    [155] = "The Obsidian Sanctum",
    [156] = "Vault of Archavon",
    [157] = "Azjol-Nerub",
    [158] = "Azjol-Nerub",
    [159] = "Azjol-Nerub",
    [160] = "Drak'Tharon Keep",
    [161] = "Drak'Tharon Keep",
    [162] = "Naxxramas",
    [163] = "Naxxramas",
    [164] = "Naxxramas",
    [165] = "Naxxramas",
    [166] = "Naxxramas",
    [167] = "Naxxramas",
    [168] = "The Violet Hold",
    [169] = "Isle of Conquest",
    [170] = "Hrothgar's Landing",
    [171] = "Trial of the Champion",
    [172] = "Trial of the Crusader",
    [173] = "Trial of the Crusader",
    [174] = "The Lost Isles",
    [175] = "Kaja'mite Cavern",
    [176] = "Volcanoth's Lair",
    [177] = "Gallywix Labor Mine",
    [178] = "Gallywix Labor Mine",
    [179] = "Gilneas",
    [180] = "Emberstone Mine",
    [181] = "Greymane Manor",
    [182] = "Greymane Manor",
    [183] = "The Forge of Souls",
    [184] = "Pit of Saron",
    [185] = "Halls of Reflection",
    [186] = "Icecrown Citadel",
    [187] = "Icecrown Citadel",
    [188] = "Icecrown Citadel",
    [189] = "Icecrown Citadel",
    [190] = "Icecrown Citadel",
    [191] = "Icecrown Citadel",
    [192] = "Icecrown Citadel",
    [193] = "Icecrown Citadel",
    [194] = "Kezan",
    [195] = "Kaja'mine",
    [196] = "Kaja'mine",
    [197] = "Kaja'mine",
    [198] = "Mount Hyjal",
    [199] = "Southern Barrens",
    [200] = "The Ruby Sanctum",
    [201] = "Kelp'thar Forest",
    [202] = "Gilneas City",
    [203] = "Vashj'ir",
    [204] = "Abyssal Depths",
    [205] = "Shimmering Expanse",
    [206] = "Twin Peaks",
    [207] = "Deepholm",
    [208] = "Twilight Depths",
    [209] = "Twilight Depths",
    [210] = "The Cape of Stranglethorn",
    [213] = "Ragefire Chasm",
    [217] = "Ruins of Gilneas",
    [218] = "Ruins of Gilneas City",
    [219] = "Zul'Farrak",
    [220] = "The Temple of Atal'Hakkar",
    [221] = "Blackfathom Deeps",
    [222] = "Blackfathom Deeps",
    [223] = "Blackfathom Deeps",
    [224] = "Stranglethorn Vale",
    [225] = "The Stockade",
    [226] = "Gnomeregan",
    [227] = "Gnomeregan",
    [228] = "Gnomeregan",
    [229] = "Gnomeregan",
    [230] = "Uldaman",
    [231] = "Uldaman",
    [232] = "Molten Core",
    [233] = "Zul'Gurub",
    [234] = "Dire Maul",
    [235] = "Dire Maul",
    [236] = "Dire Maul",
    [237] = "Dire Maul",
    [238] = "Dire Maul",
    [239] = "Dire Maul",
    [240] = "Dire Maul",
    [241] = "Twilight Highlands",
    [242] = "Blackrock Depths",
    [243] = "Blackrock Depths",
    [244] = "Tol Barad",
    [245] = "Tol Barad Peninsula",
    [246] = "The Shattered Halls",
    [247] = "Ruins of Ahn'Qiraj",
    [248] = "Onyxia's Lair",
    [249] = "Uldum",
    [250] = "Blackrock Spire",
    [251] = "Blackrock Spire",
    [252] = "Blackrock Spire",
    [253] = "Blackrock Spire",
    [254] = "Blackrock Spire",
    [255] = "Blackrock Spire",
    [256] = "Auchenai Crypts",
    [257] = "Auchenai Crypts",
    [258] = "Sethekk Halls",
    [259] = "Sethekk Halls",
    [260] = "Shadow Labyrinth",
    [261] = "The Blood Furnace",
    [262] = "The Underbog",
    [263] = "The Steamvault",
    [264] = "The Steamvault",
    [265] = "The Slave Pens",
    [266] = "The Botanica",
    [267] = "The Mechanar",
    [268] = "The Mechanar",
    [269] = "The Arcatraz",
    [270] = "The Arcatraz",
    [271] = "The Arcatraz",
    [272] = "Mana-Tombs",
    [273] = "The Black Morass",
    [274] = "Old Hillsbrad Foothills",
    [275] = "The Battle for Gilneas",
    [276] = "The Maelstrom",
    [277] = "Lost City of the Tol'vir",
    [279] = "Wailing Caverns",
    [280] = "Maraudon",
    [281] = "Maraudon",
    [282] = "Baradin Hold",
    [283] = "Blackrock Caverns",
    [284] = "Blackrock Caverns",
    [285] = "Blackwing Descent",
    [286] = "Blackwing Descent",
    [287] = "Blackwing Lair",
    [288] = "Blackwing Lair",
    [289] = "Blackwing Lair",
    [290] = "Blackwing Lair",
    [291] = "The Deadmines",
    [292] = "The Deadmines",
    [293] = "Grim Batol",
    [294] = "The Bastion of Twilight",
    [295] = "The Bastion of Twilight",
    [296] = "The Bastion of Twilight",
    [297] = "Halls of Origination",
    [298] = "Halls of Origination",
    [299] = "Halls of Origination",
    [300] = "Razorfen Downs",
    [301] = "Razorfen Kraul",
    [302] = "Scarlet Monastery",
    [303] = "Scarlet Monastery",
    [304] = "Scarlet Monastery",
    [305] = "Scarlet Monastery",
    [306] = "ScholomanceOLD",
    [307] = "ScholomanceOLD",
    [308] = "ScholomanceOLD",
    [309] = "ScholomanceOLD",
    [310] = "Shadowfang Keep",
    [311] = "Shadowfang Keep",
    [312] = "Shadowfang Keep",
    [313] = "Shadowfang Keep",
    [314] = "Shadowfang Keep",
    [315] = "Shadowfang Keep",
    [316] = "Shadowfang Keep",
    [317] = "Stratholme",
    [318] = "Stratholme",
    [319] = "Ahn'Qiraj",
    [320] = "Ahn'Qiraj",
    [321] = "Ahn'Qiraj",
    [322] = "Throne of the Tides",
    [323] = "Throne of the Tides",
    [324] = "The Stonecore",
    [325] = "The Vortex Pinnacle",
    [327] = "Ahn'Qiraj: The Fallen Kingdom",
    [328] = "Throne of the Four Winds",
    [329] = "Hyjal Summit",
    [330] = "Gruul's Lair",
    [331] = "Magtheridon's Lair",
    [332] = "Serpentshrine Cavern",
    [333] = "Zul'Aman",
    [334] = "Tempest Keep",
    [335] = "Sunwell Plateau",
    [336] = "Sunwell Plateau",
    [337] = "Zul'Gurub",
    [338] = "Molten Front",
    [339] = "Black Temple",
    [340] = "Black Temple",
    [341] = "Black Temple",
    [342] = "Black Temple",
    [343] = "Black Temple",
    [344] = "Black Temple",
    [345] = "Black Temple",
    [346] = "Black Temple",
    [347] = "Hellfire Ramparts",
    [348] = "Magisters' Terrace",
    [349] = "Magisters' Terrace",
    [350] = "Karazhan",
    [351] = "Karazhan",
    [352] = "Karazhan",
    [353] = "Karazhan",
    [354] = "Karazhan",
    [355] = "Karazhan",
    [356] = "Karazhan",
    [357] = "Karazhan",
    [358] = "Karazhan",
    [359] = "Karazhan",
    [360] = "Karazhan",
    [361] = "Karazhan",
    [362] = "Karazhan",
    [363] = "Karazhan",
    [364] = "Karazhan",
    [365] = "Karazhan",
    [366] = "Karazhan",
    [367] = "Firelands",
    [368] = "Firelands",
    [369] = "Firelands",
    [370] = "The Nexus",
    [371] = "The Jade Forest",
    [372] = "Greenstone Quarry",
    [373] = "Greenstone Quarry",
    [374] = "The Widow's Wail",
    [375] = "Oona Kagu",
    [376] = "Valley of the Four Winds",
    [377] = "Cavern of Endless Echoes",
    [378] = "The Wandering Isle",
    [379] = "Kun-Lai Summit",
    [380] = "Howlingwind Cavern",
    [381] = "Pranksters' Hollow",
    [382] = "Knucklethump Hole",
    [383] = "The Deeper",
    [384] = "The Deeper",
    [385] = "Tomb of Conquerors",
    [386] = "Ruins of Korune",
    [387] = "Ruins of Korune",
    [388] = "Townlong Steppes",
    [389] = "Niuzao Temple",
    [390] = "Vale of Eternal Blossoms",
    [391] = "Shrine of Two Moons",
    [392] = "Shrine of Two Moons",
    [393] = "Shrine of Seven Stars",
    [394] = "Shrine of Seven Stars",
    [395] = "Guo-Lai Halls",
    [396] = "Guo-Lai Halls",
    [397] = "Eye of the Storm",
    [398] = "Well of Eternity",
    [399] = "Hour of Twilight",
    [400] = "Hour of Twilight",
    [401] = "End Time",
    [402] = "End Time",
    [403] = "End Time",
    [404] = "End Time",
    [405] = "End Time",
    [406] = "End Time",
    [407] = "Darkmoon Island",
    [408] = "Darkmoon Island",
    [409] = "Dragon Soul",
    [410] = "Dragon Soul",
    [411] = "Dragon Soul",
    [412] = "Dragon Soul",
    [413] = "Dragon Soul",
    [414] = "Dragon Soul",
    [415] = "Dragon Soul",
    [416] = "Dustwallow Marsh",
    [417] = "Temple of Kotmogu",
    [418] = "Krasarang Wilds",
    [419] = "Ruins of Ogudei",
    [420] = "Ruins of Ogudei",
    [421] = "Ruins of Ogudei",
    [422] = "Dread Wastes",
    [423] = "Silvershard Mines",
    [424] = "Pandaria",
    [425] = "Northshire",
    [426] = "Echo Ridge Mine",
    [427] = "Coldridge Valley",
    [428] = "Frostmane Hovel",
    [429] = "Temple of the Jade Serpent",
    [430] = "Temple of the Jade Serpent",
    [431] = "Scarlet Halls",
    [432] = "Scarlet Halls",
    [433] = "The Veiled Stair",
    [434] = "The Ancient Passage",
    [435] = "Scarlet Monastery",
    [436] = "Scarlet Monastery",
    [437] = "Gate of the Setting Sun",
    [438] = "Gate of the Setting Sun",
    [439] = "Stormstout Brewery",
    [440] = "Stormstout Brewery",
    [441] = "Stormstout Brewery",
    [442] = "Stormstout Brewery",
    [443] = "Shado-Pan Monastery",
    [444] = "Shado-Pan Monastery",
    [445] = "Shado-Pan Monastery",
    [446] = "Shado-Pan Monastery",
    [447] = "A Brewing Storm",
    [448] = "The Jade Forest",
    [449] = "Temple of Kotmogu",
    [450] = "Unga Ingoo",
    [451] = "Assault on Zan'vess",
    [452] = "Brewmoon Festival",
    [453] = "Mogu'shan Palace",
    [454] = "Mogu'shan Palace",
    [455] = "Mogu'shan Palace",
    [456] = "Terrace of Endless Spring",
    [457] = "Siege of Niuzao Temple",
    [458] = "Siege of Niuzao Temple",
    [459] = "Siege of Niuzao Temple",
    [460] = "Shadowglen",
    [461] = "Valley of Trials",
    [462] = "Camp Narache",
    [463] = "Echo Isles",
    [464] = "Spitescale Cavern",
    [465] = "Deathknell",
    [466] = "Night Web's Hollow",
    [467] = "Sunstrider Isle",
    [468] = "Ammen Vale",
    [469] = "New Tinkertown",
    [470] = "Frostmane Hold",
    [471] = "Mogu'shan Vaults",
    [472] = "Mogu'shan Vaults",
    [473] = "Mogu'shan Vaults",
    [474] = "Heart of Fear",
    [475] = "Heart of Fear",
    [476] = "Scholomance",
    [477] = "Scholomance",
    [478] = "Scholomance",
    [479] = "Scholomance",
    [480] = "Proving Grounds",
    [481] = "Crypt of Forgotten Kings",
    [482] = "Crypt of Forgotten Kings",
    [483] = "Dustwallow Marsh",
    [486] = "Krasarang Wilds",
    [487] = "A Little Patience",
    [488] = "Dagger in the Dark",
    [489] = "Dagger in the Dark",
    [490] = "Black Temple",
    [491] = "Black Temple",
    [492] = "Black Temple",
    [493] = "Black Temple",
    [494] = "Black Temple",
    [495] = "Black Temple",
    [496] = "Black Temple",
    [497] = "Black Temple",
    [498] = "Krasarang Wilds",
    [499] = "Deeprun Tram",
    [500] = "Deeprun Tram",
    [501] = "Dalaran",
    [502] = "Dalaran",
    [503] = "Brawl'gar Arena",
    [504] = "Isle of Thunder",
    [505] = "Lightning Vein Mine",
    [506] = "The Swollen Vault",
    [507] = "Isle of Giants",
    [508] = "Throne of Thunder",
    [509] = "Throne of Thunder",
    [510] = "Throne of Thunder",
    [511] = "Throne of Thunder",
    [512] = "Throne of Thunder",
    [513] = "Throne of Thunder",
    [514] = "Throne of Thunder",
    [515] = "Throne of Thunder",
    [516] = "Isle of Thunder",
    [517] = "Lightning Vein Mine",
    [518] = "Thunder King's Citadel",
    [519] = "Deepwind Gorge",
    [520] = "Vale of Eternal Blossoms",
    [521] = "Vale of Eternal Blossoms",
    [522] = "The Secrets of Ragefire",
    [523] = "Dun Morogh",
    [524] = "Battle on the High Seas",
    [525] = "Frostfire Ridge",
    [526] = "Turgall's Den",
    [527] = "Turgall's Den",
    [528] = "Turgall's Den",
    [529] = "Turgall's Den",
    [530] = "Grom'gar",
    [531] = "Grulloc's Grotto",
    [532] = "Grulloc's Grotto",
    [533] = "Snowfall Alcove",
    [534] = "Tanaan Jungle",
    [535] = "Talador",
    [536] = "Tomb of Lights",
    [537] = "Tomb of Souls",
    [538] = "The Breached Ossuary",
    [539] = "Shadowmoon Valley",
    [540] = "Bloodthorn Cave",
    [541] = "Den of Secrets",
    [542] = "Spires of Arak",
    [543] = "Gorgrond",
    [544] = "Moira's Reach",
    [545] = "Moira's Reach",
    [546] = "Fissure of Fury",
    [547] = "Fissure of Fury",
    [548] = "Cragplume Cauldron",
    [549] = "Cragplume Cauldron",
    [550] = "Nagrand",
    [551] = "The Masters' Cavern",
    [552] = "Stonecrag Gorge",
    [553] = "Oshu'gun",
    [554] = "Timeless Isle",
    [555] = "Cavern of Lost Spirits",
    [556] = "Siege of Orgrimmar",
    [557] = "Siege of Orgrimmar",
    [558] = "Siege of Orgrimmar",
    [559] = "Siege of Orgrimmar",
    [560] = "Siege of Orgrimmar",
    [561] = "Siege of Orgrimmar",
    [562] = "Siege of Orgrimmar",
    [563] = "Siege of Orgrimmar",
    [564] = "Siege of Orgrimmar",
    [565] = "Siege of Orgrimmar",
    [566] = "Siege of Orgrimmar",
    [567] = "Siege of Orgrimmar",
    [568] = "Siege of Orgrimmar",
    [569] = "Siege of Orgrimmar",
    [570] = "Siege of Orgrimmar",
    [571] = "Celestial Tournament",
    [572] = "Draenor",
    [573] = "Bloodmaul Slag Mines",
    [574] = "Shadowmoon Burial Grounds",
    [575] = "Shadowmoon Burial Grounds",
    [576] = "Shadowmoon Burial Grounds",
    [577] = "Tanaan Jungle",
    [578] = "Umbral Halls",
    [579] = "Lunarfall Excavation",
    [580] = "Lunarfall Excavation",
    [581] = "Lunarfall Excavation",
    [582] = "Lunarfall",
    [585] = "Frostwall Mine",
    [586] = "Frostwall Mine",
    [587] = "Frostwall Mine",
    [588] = "Ashran",
    [589] = "Ashran Mine",
    [590] = "Frostwall",
    [592] = "Defense of Karabor",
    [593] = "Auchindoun",
    [594] = "Shattrath City",
    [595] = "Iron Docks",
    [596] = "Blackrock Foundry",
    [597] = "Blackrock Foundry",
    [598] = "Blackrock Foundry",
    [599] = "Blackrock Foundry",
    [600] = "Blackrock Foundry",
    [601] = "Skyreach",
    [602] = "Skyreach",
    [606] = "Grimrail Depot",
    [607] = "Grimrail Depot",
    [608] = "Grimrail Depot",
    [609] = "Grimrail Depot",
    [610] = "Highmaul",
    [611] = "Highmaul",
    [612] = "Highmaul",
    [613] = "Highmaul",
    [614] = "Highmaul",
    [615] = "Highmaul",
    [616] = "Upper Blackrock Spire",
    [617] = "Upper Blackrock Spire",
    [618] = "Upper Blackrock Spire",
    [619] = "Broken Isles",
    [620] = "The Everbloom",
    [621] = "The Everbloom",
    [622] = "Stormshield",
    [623] = "Hillsbrad Foothills (Southshore vs. Tarren Mill)",
    [624] = "Warspear",
    [625] = "Dalaran",
    [626] = "Dalaran",
    [627] = "Dalaran",
    [628] = "Dalaran",
    [629] = "Dalaran",
    [630] = "Azsuna",
    [631] = "Nar'thalas Academy",
    [632] = "Oceanus Cove",
    [633] = "Temple of a Thousand Lights",
    [634] = "Stormheim",
    [635] = "Shield's Rest",
    [636] = "Stormscale Cavern",
    [637] = "Thorignir Refuge",
    [638] = "Thorignir Refuge",
    [639] = "Aggramar's Vault",
    [640] = "Vault of Eyir",
    [641] = "Val'sharah",
    [642] = "Darkpens",
    [643] = "Sleeper's Barrow",
    [644] = "Sleeper's Barrow",
    [645] = "Twisting Nether",
    [646] = "Broken Shore",
    [647] = "Acherus: The Ebon Hold",
    [648] = "Acherus: The Ebon Hold",
    [649] = "Helheim",
    [650] = "Highmountain",
    [651] = "Bitestone Enclave",
    [652] = "Thunder Totem",
    [653] = "Cave of the Blood Trial",
    [654] = "Mucksnout Den",
    [655] = "Lifespring Cavern",
    [656] = "Lifespring Cavern",
    [657] = "Path of Huln",
    [658] = "Path of Huln",
    [659] = "Stonedark Grotto",
    [660] = "Feltotem Caverns",
    [661] = "Hellfire Citadel",
    [662] = "Hellfire Citadel",
    [663] = "Hellfire Citadel",
    [664] = "Hellfire Citadel",
    [665] = "Hellfire Citadel",
    [666] = "Hellfire Citadel",
    [667] = "Hellfire Citadel",
    [668] = "Hellfire Citadel",
    [669] = "Hellfire Citadel",
    [670] = "Hellfire Citadel",
    [671] = "The Cove of Nashal",
    [672] = "Mardum, the Shattered Abyss",
    [673] = "Cryptic Hollow",
    [674] = "Soul Engine",
    [675] = "Soul Engine",
    [676] = "Broken Shore",
    [677] = "Vault of the Wardens",
    [678] = "Vault of the Wardens",
    [679] = "Vault of the Wardens",
    [680] = "Suramar",
    [681] = "The Arcway Vaults",
    [682] = "Felsoul Hold",
    [683] = "The Arcway Vaults",
    [684] = "Shattered Locus",
    [685] = "Shattered Locus",
    [686] = "Elor'shan",
    [687] = "Kel'balor",
    [688] = "Ley Station Anora",
    [689] = "Ley Station Moonfall",
    [690] = "Ley Station Aethenar",
    [691] = "Nyell's Workshop",
    [692] = "Falanaar Arcway",
    [693] = "Falanaar Arcway",
    [694] = "Helmouth Shallows",
    [695] = "Skyhold",
    [696] = "Stormheim",
    [697] = "Azshara",
    [698] = "Icecrown Citadel",
    [699] = "Icecrown Citadel",
    [700] = "Icecrown Citadel",
    [701] = "Icecrown Citadel",
    [702] = "Netherlight Temple",
    [703] = "Halls of Valor",
    [704] = "Halls of Valor",
    [705] = "Halls of Valor",
    [706] = "Helmouth Cliffs",
    [707] = "Helmouth Cliffs",
    [708] = "Helmouth Cliffs",
    [709] = "The Wandering Isle",
    [710] = "Vault of the Wardens",
    [711] = "Vault of the Wardens",
    [712] = "Vault of the Wardens",
    [713] = "Eye of Azshara",
    [714] = "Niskara",
    [715] = "Emerald Dreamway",
    [716] = "Skywall",
    [717] = "Dreadscar Rift",
    [718] = "Dreadscar Rift",
    [719] = "Mardum, the Shattered Abyss",
    [720] = "Mardum, the Shattered Abyss",
    [721] = "Mardum, the Shattered Abyss",
    [723] = "The Violet Hold",
    [725] = "The Maelstrom",
    [726] = "The Maelstrom",
    [728] = "Terrace of Endless Spring",
    [729] = "Crumbling Depths",
    [731] = "Neltharion's Lair",
    [732] = "Violet Hold",
    [733] = "Darkheart Thicket",
    [734] = "Hall of the Guardian",
    [735] = "Hall of the Guardian",
    [736] = "The Beyond",
    [737] = "The Vortex Pinnacle",
    [738] = "Firelands",
    [739] = "Trueshot Lodge",
    [740] = "Shadowgore Citadel",
    [741] = "Shadowgore Citadel",
    [742] = "Abyssal Maw",
    [743] = "Abyssal Maw",
    [744] = "Ulduar",
    [745] = "Ulduar",
    [746] = "Ulduar",
    [747] = "The Dreamgrove",
    [748] = "Niskara",
    [749] = "The Arcway",
    [750] = "Thunder Totem",
    [751] = "Black Rook Hold",
    [752] = "Black Rook Hold",
    [753] = "Black Rook Hold",
    [754] = "Black Rook Hold",
    [755] = "Black Rook Hold",
    [756] = "Black Rook Hold",
    [757] = "Ursoc's Lair",
    [758] = "Gloaming Reef",
    [759] = "Black Temple",
    [760] = "Malorne's Nightmare",
    [761] = "Court of Stars",
    [762] = "Court of Stars",
    [763] = "Court of Stars",
    [764] = "The Nighthold",
    [765] = "The Nighthold",
    [766] = "The Nighthold",
    [767] = "The Nighthold",
    [768] = "The Nighthold",
    [769] = "The Nighthold",
    [770] = "The Nighthold",
    [771] = "The Nighthold",
    [772] = "The Nighthold",
    [773] = "Tol Barad",
    [774] = "Tol Barad",
    [775] = "The Exodar",
    [776] = "Azuremyst Isle",
    [777] = "The Emerald Nightmare",
    [778] = "The Emerald Nightmare",
    [779] = "The Emerald Nightmare",
    [780] = "The Emerald Nightmare",
    [781] = "The Emerald Nightmare",
    [782] = "The Emerald Nightmare",
    [783] = "The Emerald Nightmare",
    [784] = "The Emerald Nightmare",
    [785] = "The Emerald Nightmare",
    [786] = "The Emerald Nightmare",
    [787] = "The Emerald Nightmare",
    [788] = "The Emerald Nightmare",
    [789] = "The Emerald Nightmare",
    [790] = "Eye of Azshara",
    [791] = "Temple of the Jade Serpent",
    [792] = "Temple of the Jade Serpent",
    [793] = "Black Rook Hold",
    [794] = "Karazhan",
    [795] = "Karazhan",
    [796] = "Karazhan",
    [797] = "Karazhan",
    [798] = "The Arcway",
    [799] = "The Oculus",
    [800] = "The Oculus",
    [801] = "The Oculus",
    [802] = "The Oculus",
    [803] = "The Oculus",
    [804] = "Scarlet Monastery",
    [805] = "Scarlet Monastery",
    [806] = "Trial of Valor",
    [807] = "Trial of Valor",
    [808] = "Trial of Valor",
    [809] = "Karazhan",
    [810] = "Karazhan",
    [811] = "Karazhan",
    [812] = "Karazhan",
    [813] = "Karazhan",
    [814] = "Karazhan",
    [815] = "Karazhan",
    [816] = "Karazhan",
    [817] = "Karazhan",
    [818] = "Karazhan",
    [819] = "Karazhan",
    [820] = "Karazhan",
    [821] = "Karazhan",
    [822] = "Karazhan",
    [823] = "Pit of Saron",
    [824] = "Islands",
    [825] = "Wailing Caverns",
    [826] = "Cave of the Bloodtotem",
    [827] = "Stratholme",
    [828] = "The Eye of Eternity",
    [829] = "Halls of Valor",
    [830] = "Krokuun",
    [831] = "The Exodar",
    [832] = "The Exodar",
    [833] = "Nath'raxas Spire",
    [834] = "Coldridge Valley",
    [835] = "The Deadmines",
    [836] = "The Deadmines",
    [837] = "Arathi Basin",
    [838] = "Battle for Blackrock Mountain",
    [839] = "The Maelstrom",
    [840] = "Gnomeregan",
    [841] = "Gnomeregan",
    [842] = "Gnomeregan",
    [843] = "Shado-Pan Showdown",
    [844] = "Arathi Basin",
    [845] = "Cathedral of Eternal Night",
    [846] = "Cathedral of Eternal Night",
    [847] = "Cathedral of Eternal Night",
    [848] = "Cathedral of Eternal Night",
    [849] = "Cathedral of Eternal Night",
    [850] = "Tomb of Sargeras",
    [851] = "Tomb of Sargeras",
    [852] = "Tomb of Sargeras",
    [853] = "Tomb of Sargeras",
    [854] = "Tomb of Sargeras",
    [855] = "Tomb of Sargeras",
    [856] = "Tomb of Sargeras",
    [857] = "Throne of the Four Winds",
    [858] = "Assault on Broken Shore",
    [859] = "Warsong Gulch",
    [860] = "The Ruby Sanctum",
    [861] = "Mardum, the Shattered Abyss",
    [862] = "Zuldazar",
    [863] = "Nazmir",
    [864] = "Vol'dun",
    [865] = "Stormheim",
    [866] = "Stormheim",
    [867] = "Azsuna",
    [868] = "Val'sharah",
    [869] = "Highmountain",
    [870] = "Highmountain",
    [871] = "The Lost Glacier",
    [872] = "Stormstout Brewery",
    [873] = "Stormstout Brewery",
    [874] = "Stormstout Brewery",
    [875] = "Zandalar",
    [876] = "Kul Tiras",
    [877] = "Fields of the Eternal Hunt",
    [879] = "Mardum, the Shattered Abyss",
    [880] = "Mardum, the Shattered Abyss",
    [881] = "The Eye of Eternity",
    [882] = "Mac'Aree",
    [883] = "The Vindicaar",
    [884] = "The Vindicaar",
    [885] = "Antoran Wastes",
    [886] = "The Vindicaar",
    [887] = "The Vindicaar",
    [888] = "Hall of Communion",
    [889] = "Arcatraz",
    [890] = "Arcatraz",
    [891] = "Azuremyst Isle",
    [892] = "Azuremyst Isle",
    [893] = "Azuremyst Isle",
    [894] = "Azuremyst Isle",
    [895] = "Tiragarde Sound",
    [896] = "Drustvar",
    [897] = "The Deaths of Chromie",
    [898] = "The Deaths of Chromie",
    [899] = "The Deaths of Chromie",
    [900] = "The Deaths of Chromie",
    [901] = "The Deaths of Chromie",
    [902] = "The Deaths of Chromie",
    [903] = "The Seat of the Triumvirate",
    [904] = "Silithus Brawl",
    [905] = "Argus",
    [906] = "Arathi Highlands",
    [907] = "Seething Shore",
    [908] = "Ruins of Lordaeron",
    [909] = "Antorus, the Burning Throne",
    [910] = "Antorus, the Burning Throne",
    [911] = "Antorus, the Burning Throne",
    [912] = "Antorus, the Burning Throne",
    [913] = "Antorus, the Burning Throne",
    [914] = "Antorus, the Burning Throne",
    [915] = "Antorus, the Burning Throne",
    [916] = "Antorus, the Burning Throne",
    [917] = "Antorus, the Burning Throne",
    [918] = "Antorus, the Burning Throne",
    [919] = "Antorus, the Burning Throne",
    [920] = "Antorus, the Burning Throne",
    [921] = "Invasion Point: Aurinor",
    [922] = "Invasion Point: Bonich",
    [923] = "Invasion Point: Cen'gar",
    [924] = "Invasion Point: Naigtal",
    [925] = "Invasion Point: Sangua",
    [926] = "Invasion Point: Val",
    [927] = "Greater Invasion Point: Pit Lord Vilemus",
    [928] = "Greater Invasion Point: Mistress Alluradel",
    [929] = "Greater Invasion Point: Matron Folnuna",
    [930] = "Greater Invasion Point: Inquisitor Meto",
    [931] = "Greater Invasion Point: Sotanathor",
    [932] = "Greater Invasion Point: Occularus",
    [933] = "Forge of Aeons",
    [934] = "Atal'Dazar",
    [935] = "Atal'Dazar",
    [936] = "Freehold",
    [938] = "Gilneas Island",
    [939] = "Tropical Isle 8.0",
    [940] = "The Vindicaar",
    [941] = "The Vindicaar",
    [942] = "Stormsong Valley",
    [943] = "Arathi Highlands",
    [946] = "Cosmic",
    [947] = "Azeroth",
    [948] = "The Maelstrom",
    [971] = "Telogrus Rift",
    [972] = "Telogrus Rift",
    [973] = "The Sunwell",
    [974] = "Tol Dagor",
    [975] = "Tol Dagor",
    [976] = "Tol Dagor",
    [977] = "Tol Dagor",
    [978] = "Tol Dagor",
    [979] = "Tol Dagor",
    [980] = "Tol Dagor",
    [981] = "Un'gol Ruins",
    [985] = "Eastern Kingdoms",
    [986] = "Kalimdor",
    [987] = "Outland",
    [988] = "Northrend",
    [989] = "Pandaria",
    [990] = "Draenor",
    [991] = "Zandalar",
    [992] = "Kul Tiras",
    [993] = "Broken Isles",
    [994] = "Argus",
    [997] = "Tirisfal Glades",
    [998] = "Undercity",
    [1004] = "Kings' Rest",
    [1009] = "Atul'Aman",
    [1010] = "The MOTHERLODE!!",
    [1011] = "Zandalar",
    [1012] = "Stormwind City",
    [1013] = "The Stockade",
    [1014] = "Kul Tiras",
    [1015] = "Waycrest Manor",
    [1016] = "Waycrest Manor",
    [1017] = "Waycrest Manor",
    [1018] = "Waycrest Manor",
    [1021] = "Chamber of Heart",
    [1022] = "Uncharted Island",
    [1029] = "WaycrestDimension",
    [1030] = "Greymane Manor",
    [1031] = "Greymane Manor",
    [1032] = "Skittering Hollow",
    [1033] = "The Rotting Mire",
    [1034] = "Verdant Wilds",
    [1035] = "Molten Cay",
    [1036] = "The Dread Chain",
    [1037] = "Whispering Reef",
    [1038] = "Temple of Sethraliss",
    [1039] = "Shrine of the Storm",
    [1040] = "Shrine of the Storm",
    [1041] = "The Underrot",
    [1042] = "The Underrot",
    [1043] = "Temple of Sethraliss",
    [1044] = "Arathi Highlands",
    [1045] = "Thros, The Blighted Lands",
    [1148] = "Uldir",
    [1149] = "Uldir",
    [1150] = "Uldir",
    [1151] = "Uldir",
    [1152] = "Uldir",
    [1153] = "Uldir",
    [1154] = "Uldir",
    [1155] = "Uldir",
    [1156] = "The Great Sea",
    [1157] = "The Great Sea",
    [1158] = "Arathi Highlands",
    [1159] = "Blackrock Depths",
    [1160] = "Blackrock Depths",
    [1161] = "Boralus",
    [1162] = "Siege of Boralus",
    [1163] = "Dazar'alor",
    [1164] = "Dazar'alor",
    [1165] = "Dazar'alor",
    [1166] = "Zanchul",
    [1167] = "Zanchul",
    [1169] = "Tol Dagor",
    [1170] = "Gorgrond - Mag'har Scenario",
    [1171] = "Gol Thovas",
    [1172] = "Gol Thovas",
    [1173] = "Rastakhan's Might",
    [1174] = "Rastakhan's Might",
    [1176] = "Breath Of Pa'ku",
    [1177] = "Breath Of Pa'ku",
    [1179] = "Abyssal Melody",
    [1180] = "Abyssal Melody",
    [1181] = "Zuldazar",
    [1182] = "SalstoneMine_Stormsong",
    [1183] = "Thornheart",
    [1184] = "Winterchill Mine",
    [1185] = "Winterchill Mine",
    [1186] = "Blackrock Depths",
    [1187] = "Azsuna",
    [1188] = "Val'sharah",
    [1189] = "Highmountain",
    [1190] = "Stormheim",
    [1191] = "Suramar",
    [1192] = "Broken Shore",
    [1193] = "Zuldazar",
    [1194] = "Nazmir",
    [1195] = "Vol'dun",
    [1196] = "Tiragarde Sound",
    [1197] = "Drustvar",
    [1198] = "Stormsong Valley",
}

local zoneTranslation = {
	enUS = {
		-- These zones are known in LibTourist's zones collection but are not returned by C_Map.GetMapInfo.
		-- TODO: check if these are now returned by C_Map.GetAreaInfo. Remove from LibTourist? Fix localizations?
		-- Note: The number at the end of each line is the old ID (pre-BFA)
		[9901] = "Amani Pass",  -- 3508
		[9902] = "The Dark Portal",  -- 72
		[9903] = "The Ring of Valor",  -- 4406
		[9904] = "Dire Maul (East)",  -- 5914
		[9905] = "Dire Maul (North)",  -- 5913
		[9906] = "Dire Maul (West)",  -- 5915
		[9907] = "Coilfang Reservoir",  -- 3905
		[9908] = "Ring of Observance", -- 3893
		[9909] = "Nagrand Arena",  -- 559
		[9910] = "Blade's Edge Arena",  -- 562
		[9911] = "Dalaran Arena",  -- 4378
		[9912] = "Coldarra",  -- 4024
		[9913] = "The Frozen Sea",  -- 3979
		[9914] = "The Tiger's Peak",  -- 6732
	},
	deDE = {
		[9901] = "Amani Pass",  -- 3508
		[9902] = "The Dark Portal",  -- 72
		[9903] = "The Ring of Valor",  -- 4406
		[9904] = "Dire Maul (East)",  -- 5914
		[9905] = "Dire Maul (North)",  -- 5913
		[9906] = "Dire Maul (West)",  -- 5915
		[9907] = "Coilfang Reservoir",  -- 3905
		[9908] = "Ring of Observance", -- 3893
		[9909] = "Nagrand Arena",  -- 559
		[9910] = "Blade's Edge Arena",  -- 562
		[9911] = "Dalaran Arena",  -- 4378
		[9912] = "Coldarra",  -- 4024
		[9913] = "The Frozen Sea",  -- 3979
		[9914] = "The Tiger's Peak",  -- 6732
	},
	esES = {
		[9901] = "Amani Pass",  -- 3508
		[9902] = "The Dark Portal",  -- 72
		[9903] = "The Ring of Valor",  -- 4406
		[9904] = "Dire Maul (East)",  -- 5914
		[9905] = "Dire Maul (North)",  -- 5913
		[9906] = "Dire Maul (West)",  -- 5915
		[9907] = "Coilfang Reservoir",  -- 3905
		[9908] = "Ring of Observance", -- 3893
		[9909] = "Nagrand Arena",  -- 559
		[9910] = "Blade's Edge Arena",  -- 562
		[9911] = "Dalaran Arena",  -- 4378
		[9912] = "Coldarra",  -- 4024
		[9913] = "The Frozen Sea",  -- 3979
		[9914] = "The Tiger's Peak",  -- 6732
	},
	esMX = {
		[9901] = "Amani Pass",  -- 3508
		[9902] = "The Dark Portal",  -- 72
		[9903] = "The Ring of Valor",  -- 4406
		[9904] = "Dire Maul (East)",  -- 5914
		[9905] = "Dire Maul (North)",  -- 5913
		[9906] = "Dire Maul (West)",  -- 5915
		[9907] = "Coilfang Reservoir",  -- 3905
		[9908] = "Ring of Observance", -- 3893
		[9909] = "Nagrand Arena",  -- 559
		[9910] = "Blade's Edge Arena",  -- 562
		[9911] = "Dalaran Arena",  -- 4378
		[9912] = "Coldarra",  -- 4024
		[9913] = "The Frozen Sea",  -- 3979
		[9914] = "The Tiger's Peak",  -- 6732
	},
	frFR = {
		[9901] = "Amani Pass",  -- 3508
		[9902] = "The Dark Portal",  -- 72
		[9903] = "The Ring of Valor",  -- 4406
		[9904] = "Dire Maul (East)",  -- 5914
		[9905] = "Dire Maul (North)",  -- 5913
		[9906] = "Dire Maul (West)",  -- 5915
		[9907] = "Coilfang Reservoir",  -- 3905
		[9908] = "Ring of Observance", -- 3893
		[9909] = "Nagrand Arena",  -- 559
		[9910] = "Blade's Edge Arena",  -- 562
		[9911] = "Dalaran Arena",  -- 4378
		[9912] = "Coldarra",  -- 4024
		[9913] = "The Frozen Sea",  -- 3979
		[9914] = "The Tiger's Peak",  -- 6732
	},
	itIT = {
		[9901] = "Amani Pass",  -- 3508
		[9902] = "The Dark Portal",  -- 72
		[9903] = "The Ring of Valor",  -- 4406
		[9904] = "Dire Maul (East)",  -- 5914
		[9905] = "Dire Maul (North)",  -- 5913
		[9906] = "Dire Maul (West)",  -- 5915
		[9907] = "Coilfang Reservoir",  -- 3905
		[9908] = "Ring of Observance", -- 3893
		[9909] = "Nagrand Arena",  -- 559
		[9910] = "Blade's Edge Arena",  -- 562
		[9911] = "Dalaran Arena",  -- 4378
		[9912] = "Coldarra",  -- 4024
		[9913] = "The Frozen Sea",  -- 3979
		[9914] = "The Tiger's Peak",  -- 6732
	},
	koKR = {
		[9901] = "Amani Pass",  -- 3508
		[9902] = "The Dark Portal",  -- 72
		[9903] = "The Ring of Valor",  -- 4406
		[9904] = "Dire Maul (East)",  -- 5914
		[9905] = "Dire Maul (North)",  -- 5913
		[9906] = "Dire Maul (West)",  -- 5915
		[9907] = "Coilfang Reservoir",  -- 3905
		[9908] = "Ring of Observance", -- 3893
		[9909] = "Nagrand Arena",  -- 559
		[9910] = "Blade's Edge Arena",  -- 562
		[9911] = "Dalaran Arena",  -- 4378
		[9912] = "Coldarra",  -- 4024
		[9913] = "The Frozen Sea",  -- 3979
		[9914] = "The Tiger's Peak",  -- 6732
	},
	ptBR = {
		[9901] = "Amani Pass",  -- 3508
		[9902] = "The Dark Portal",  -- 72
		[9903] = "The Ring of Valor",  -- 4406
		[9904] = "Dire Maul (East)",  -- 5914
		[9905] = "Dire Maul (North)",  -- 5913
		[9906] = "Dire Maul (West)",  -- 5915
		[9907] = "Coilfang Reservoir",  -- 3905
		[9908] = "Ring of Observance", -- 3893
		[9909] = "Nagrand Arena",  -- 559
		[9910] = "Blade's Edge Arena",  -- 562
		[9911] = "Dalaran Arena",  -- 4378
		[9912] = "Coldarra",  -- 4024
		[9913] = "The Frozen Sea",  -- 3979
		[9914] = "The Tiger's Peak",  -- 6732
	},
	ruRU = {
		[9901] = "Amani Pass",  -- 3508
		[9902] = "The Dark Portal",  -- 72
		[9903] = "The Ring of Valor",  -- 4406
		[9904] = "Dire Maul (East)",  -- 5914
		[9905] = "Dire Maul (North)",  -- 5913
		[9906] = "Dire Maul (West)",  -- 5915
		[9907] = "Coilfang Reservoir",  -- 3905
		[9908] = "Ring of Observance", -- 3893
		[9909] = "Nagrand Arena",  -- 559
		[9910] = "Blade's Edge Arena",  -- 562
		[9911] = "Dalaran Arena",  -- 4378
		[9912] = "Coldarra",  -- 4024
		[9913] = "The Frozen Sea",  -- 3979
		[9914] = "The Tiger's Peak",  -- 6732
	},
	zhCN = {
		[9901] = "Amani Pass",  -- 3508
		[9902] = "The Dark Portal",  -- 72
		[9903] = "The Ring of Valor",  -- 4406
		[9904] = "Dire Maul (East)",  -- 5914
		[9905] = "Dire Maul (North)",  -- 5913
		[9906] = "Dire Maul (West)",  -- 5915
		[9907] = "Coilfang Reservoir",  -- 3905
		[9908] = "Ring of Observance", -- 3893
		[9909] = "Nagrand Arena",  -- 559
		[9910] = "Blade's Edge Arena",  -- 562
		[9911] = "Dalaran Arena",  -- 4378
		[9912] = "Coldarra",  -- 4024
		[9913] = "The Frozen Sea",  -- 3979
		[9914] = "The Tiger's Peak",  -- 6732
	},
	zhTW = {
		[9901] = "Amani Pass",  -- 3508
		[9902] = "The Dark Portal",  -- 72
		[9903] = "The Ring of Valor",  -- 4406
		[9904] = "Dire Maul (East)",  -- 5914
		[9905] = "Dire Maul (North)",  -- 5913
		[9906] = "Dire Maul (West)",  -- 5915
		[9907] = "Coilfang Reservoir",  -- 3905
		[9908] = "Ring of Observance", -- 3893
		[9909] = "Nagrand Arena",  -- 559
		[9910] = "Blade's Edge Arena",  -- 562
		[9911] = "Dalaran Arena",  -- 4378
		[9912] = "Coldarra",  -- 4024
		[9913] = "The Frozen Sea",  -- 3979
		[9914] = "The Tiger's Peak",  -- 6732
	},
}








--[[
local zoneTranslation = {
	enUS = {
		-- Complexes
		[1941] = "Caverns of Time",
		[25] = "Blackrock Mountain",
		[4406] = "The Ring of Valor",
		[3545] = "Hellfire Citadel",
		[3905] = "Coilfang Reservoir",
		[3893] = "Ring of Observance",
		[3842] = "Tempest Keep",
		[4024] = "Coldarra",
		[5695] = "Ahn'Qiraj: The Fallen Kingdom",

		-- Continents
		[0] = "Eastern Kingdoms",
		[1] = "Kalimdor",
		[530] = "Outland",
		[571] = "Northrend",
		[5416] = "The Maelstrom",
		[870] = "Pandaria",
		["Azeroth"] = "Azeroth",

		-- Transports
		[72] = "The Dark Portal",
		[2257] = "Deeprun Tram",

		-- Dungeons
		[5914] = "Dire Maul (East)",
		[5913] = "Dire Maul (North)",
		[5915] = "Dire Maul (West)",

		-- Arenas
		[559] = "Nagrand Arena",
		[562] = "Blade's Edge Arena",
		[572] = "Ruins of Lordaeron",
		[4378] = "Dalaran Arena",
		[6732] = "The Tiger's Peak",

		-- Other
		[4298] = "Plaguelands: The Scarlet Enclave",
		[3508] = "Amani Pass",
		[3979] = "The Frozen Sea",
	},
	deDE = {
		-- Complexes
		[1941] = "Höhlen der Zeit",
		[25] = "Der Schwarzfels",
		[4406] = "Der Ring der Ehre",
		[3545] = "Höllenfeuerzitadelle",
		[3905] = "Der Echsenkessel",
		[3893] = "Ring der Beobachtung",
		[3842] = "Festung der Stürme",
		[4024] = "Kaltarra",
		[5695] = "Ahn'Qiraj: Das Gefallene Königreich",

		-- Continents
		[0] = "Östliche Königreiche",
		[1] = "Kalimdor",
		[530] = "Scherbenwelt",
		[571] = "Nordend",
		[5416] = "Der Mahlstrom",
		[870] = "Pandaria",
		["Azeroth"] = "Azeroth",

		-- Transports
		[72] = "Das Dunkle Portal",
		[2257] = "Die Tiefenbahn",

		-- Dungeons
		[5914] = "Düsterbruch - Ost",
		[5913] = "Düsterbruch - Nord",
		[5915] = "Düsterbruch - West",

		-- Arenas
		[559] = "Arena von Nagrand",
		[562] = "Arena des Schergrats",
		[572] = "Ruinen von Lordaeron",
		[4378] = "Arena von Dalaran",
		[6732] = "Der Tigergipfel", 

		-- Other
		[4298] = "Pestländer: Die Scharlachrote Enklave",
		[3508] = "Amanipass",
		[3979] = "Die Gefrorene See",
	},
	esES = {
		-- Complexes
		[1941] = "Cavernas del Tiempo",
		[25] = "Montaña Roca Negra",
		[4406] = "El Círculo del Valor",
		[3545] = "Ciudadela del Fuego Infernal",
		[3905] = "Reserva Colmillo Torcido",
		[3893] = "Círculo de la Observancia",
		[3842] = "El Castillo de la Tempestad",
		[4024] = "Gelidar",
		[5695] = "Ahn'Qiraj: El Reino Caído",

		-- Continents
		[0] = "Reinos del Este",
		[1] = "Kalimdor",
		[530] = "Terrallende",
		[571] = "Rasganorte",
		[5416] = "La Vorágine",
		[870] = "Pandaria",
		["Azeroth"] = "Azeroth",

		-- Transports
		[72] = "El Portal Oscuro",
		[2257] = "Tranvía Subterráneo",

		-- Dungeons
		[5914] = "La Masacre: Este",
		[5913] = "La Masacre: Norte",
		[5915] = "La Masacre: Oeste",

		-- Arenas
		[559] = "Arena de Nagrand",
		[562] = "Arena Filospada",
		[572] = "Ruinas de Lordaeron",
		[4378] = "Arena de Dalaran",
		[6732] = "La Cima del Tigre",

		-- Other
		[4298] = "Tierras de la Peste: El Enclave Escarlata",
		[3508] = "Paso de Amani",
		[3979] = "El Mar Gélido",
	},
	esMX = {
		-- Complexes
		[1941] = "Cavernas del Tiempo",
		[25] = "Montaña Roca Negra",
		[4406] = "El Círculo del Valor",
		[3545] = "Ciudadela del Fuego Infernal",
		[3905] = "Reserva Colmillo Torcido",
		[3893] = "Círculo de la Observancia",
		[3842] = "El Castillo de la Tempestad",
		[4024] = "Gelidar",
		[5695] = "Ahn'Qiraj: El Reino Caído",

		-- Continents
		[0] = "Reinos del Este",
		[1] = "Kalimdor",
		[530] = "Terrallende",
		[571] = "Rasganorte",
		[5416] = "La Vorágine",
		[870] = "Pandaria",
		["Azeroth"] = "Azeroth",

		-- Transports
		[72] = "El Portal Oscuro",
		[2257] = "Tranvía Subterráneo",

		-- Dungeons
		[5914] = "La Masacre: Este",
		[5913] = "La Masacre: Norte",
		[5915] = "La Masacre: Oeste",

		-- Arenas
		[559] = "Arena de Nagrand",
		[562] = "Arena Filospada",
		[572] = "Ruinas de Lordaeron",
		[4378] = "Arena de Dalaran",
		[6732] = "La Cima del Tigre",

		-- Other
		[4298] = "Tierras de la Peste: El Enclave Escarlata",
		[3508] = "Paso de Amani",
		[3979] = "El Mar Gélido",
	},
	frFR = {
		-- Complexes
		[1941] = "Grottes du Temps",
		[25] = "Mont Rochenoire",
		[4406] = "L’arène des Valeureux",
		[3545] = "Citadelle des Flammes infernales",
		[3905] = "Réservoir de Glissecroc",
		[3893] = "Cercle d’observance",
		[3842] = "Donjon de la Tempête",
		[4024] = "Frimarra",
		[5695] = "Ahn’Qiraj : le royaume Déchu",

		-- Continents
		[0] = "Royaumes de l'est",
		[1] = "Kalimdor",
		[530] = "Outreterre",
		[571] = "Norfendre",
		[5416] = "Le Maelström",
		[870] = "Pandarie",
		["Azeroth"] = "Azeroth",

		-- Transports
		[72] = "La porte des Ténèbres",
		[2257] = "Tram des profondeurs",

		-- Dungeons
		[5914] = "Haches-Tripes - Est",
		[5913] = "Haches-Tripes - Nord",
		[5915] = "Haches-Tripes - Ouest",

		-- Arenas
		[559] = "Arène de Nagrand",
		[562] = "Arène des Tranchantes",
		[572] = "Ruines de Lordaeron",
		[4378] = "Arène de Dalaran",
		[6732] = "Le croc du Tigre",

		-- Other
		[4298] = "Maleterres : l’enclave Écarlate",
		[3508] = "Passage des Amani",
		[3979] = "La mer Gelée",
	},
	itIT = {
		-- Complexes
		[1941] = "Caverne del Tempo",
		[25] = "Massiccio Roccianera",
		[4406] = "Arena del Valore",
		[3545] = "Cittadella del Fuoco Infernale",
		[3905] = "Bacino degli Spiraguzza",
		[3893] = "Anello dell'Osservanza",
		[3842] = "Forte Tempesta",
		[4024] = "Ibernia",
		[5695] = "Ahn'Qiraj: il Regno Perduto",

		-- Continents
		[0] = "Regni Orientali",
		[1] = "Kalimdor",
		[530] = "Terre Esterne",
		[571] = "Nordania",
		[5416] = "Maelstrom",
		[870] = "Pandaria",
		["Azeroth"] = "Azeroth",

		-- Transports
		[72] = "Portale Oscuro",
		[2257] = "Tram degli Abissi",

		-- Dungeons
		[5914] = "Maglio Infausto - Est",
		[5913] = "Maglio Infausto - Nord",
		[5915] = "Maglio Infausto - Ovest",

		-- Arenas
		[559] = "Arena di Nagrand",
		[562] = "Arena di Spinaguzza",
		[572] = "Rovine di Lordaeron",
		[4378] = "Arena di Dalaran",
		[6732] = "Picco della Tigre",

		-- Other
		[4298] = "Terre Infette: l'Enclave Scarlatta",
		[3508] = "Passo degli Amani",
		[3979] = "Mare Ghiacciato",
	},
	koKR = {
		-- Complexes
		[1941] = "시간의 동굴",
		[25] = "검은바위 산",
		[4406] = "용맹의 투기장",
		[3545] = "지옥불 성채",
		[3905] = "갈퀴송곳니 저수지",
		[3893] = "규율의 광장",
		[3842] = "폭풍우 요새",
		[4024] = "콜다라",
		[5695] = "안퀴라즈: 무너진 왕국",

		-- Continents
		[0] = "동부 왕국",
		[1] = "칼림도어",
		[530] = "아웃랜드",
		[571] = "노스렌드",
		[5416] = "혼돈의 소용돌이",
		[870] = "판다리아",
		["Azeroth"] = "아제로스",

		-- Transports
		[72] = "어둠의 문",
		[2257] = "깊은굴 지하철",

		-- Dungeons
		[5914] = "혈투의 전장 - 동쪽",
		[5913] = "혈투의 전장 - 북쪽",
		[5915] = "혈투의 전장 - 서쪽",

		-- Arenas
		[559] = "나그란드 투기장",
		[562] = "칼날 산맥 투기장",
		[572] = "로데론의 폐허",
		[4378] = "달라란 투기장",
		[6732] = "범의 봉우리",

		-- Other
		[4298] = "동부 역병지대: 붉은십자군 초소",
		[3508] = "아마니 고개",
		[3979] = "얼어붙은 바다",
	},
	ptBR = {
		-- Complexes
		[1941] = "Cavernas do Tempo",
		[25] = "Montanha Rocha Negra",
		[4406] = "Ringue dos Valorosos",
		[3545] = "Cidadela Fogo do Inferno",
		[3905] = "Reservatório Presacurva",
		[3893] = "Círculo da Obediência",
		[3842] = "Bastilha da Tormenta",
		[4024] = "Gelarra",
		[5695] = "Ahn'Qiraj: O Reino Derrotado",

		-- Continents
		[0] = "Reinos do Leste",
		[1] = "Kalimdor",
		[530] = "Terralém",
		[571] = "Nortúndria",
		[5416] = "Voragem",
		[870] = "Pandária",
		["Azeroth"] = "Azeroth",

		-- Transports
		[72] = "Portal Negro",
		[2257] = "Metrô Correfundo",

		-- Dungeons
		[5914] = "Gládio Cruel – Leste",
		[5913] = "Gládio Cruel – Norte",
		[5915] = "Gládio Cruel – Oeste",

		-- Arenas
		[559] = "Arena de Nagrand",
		[562] = "Arena da Lâmina Afiada",
		[572] = "Ruínas de Lordaeron",
		[4378] = "Arena de Dalaran",
		[6732] = "O Pico do Tigre",
		
		-- Other
		[4298] = "Terras Pestilentas: Enclave Escarlate",
		[3508] = "Desfiladeiro Amani",
		[3979] = "Mar Congelado",
	},
	ruRU = {
		-- Complexes
		[1941] = "Пещеры Времени",
		[25] = "Черная гора",
		[4406] = "Арена Доблести",
		[3545] = "Цитадель Адского Пламени",
		[3905] = "Резервуар Кривого Клыка",
		[3893] = "Ритуальный Круг",
		[3842] = "Крепость Бурь",
		[4024] = "Хладарра",
		[5695] = "Ан'Кираж: Павшее Королевство",

		-- Continents
		[0] = "Восточные королевства",
		[1] = "Калимдор",
		[530] = "Запределье",
		[571] = "Нордскол",
		[5416] = "Водоворот",
		[870] = "Пандария",
		["Azeroth"] = "Азерот",

		-- Transports
		[72] = "Темный портал",
		[2257] = "Подземный поезд",

		-- Dungeons
		[5914] = "Забытый город – восток",
		[5913] = "Забытый город – север",
		[5915] = "Забытый город – запад",

		-- Arenas
		[559] = "Арена Награнда",
		[562] = "Арена Острогорья",
		[572] = "Руины Лордерона",
		[4378] = "Арена Даларана",
		[6732] = "Пик Тигра",
		
		-- Other
		[4298] = "Чумные земли: Анклав Алого ордена",
		[3508] = "Перевал Амани",
		[3979] = "Ледяное море",
	},
	zhCN = {
		-- Complexes
		[1941] = "时光之穴",
		[25] = "黑石山",
		[4406] = "勇气竞技场",
		[3545] = "地狱火堡垒",
		[3905] = "盘牙水库",
		[3893] = "仪式广场",
		[3842] = "风暴要塞",
		[4024] = "考达拉",
		[5695] = "安其拉：堕落王国",

		-- Continents
		[0] = "东部王国",
		[1] = "卡利姆多",
		[530] = "外域",
		[571] = "诺森德",
		[5416] = "大漩涡",
		[870] = "潘达利亚",
		["Azeroth"] = "艾泽拉斯",

		-- Transports
		[72] = "黑暗之门",
		[2257] = "矿道地铁",

		-- Dungeons
		[5914] = "厄运之槌 - 东",
		[5913] = "厄运之槌 - 北",
		[5915] = "厄运之槌 - 西",

		-- Arenas
		[559] = "纳格兰竞技场",
		[562] = "刀锋山竞技场",
		[572] = "洛丹伦废墟",
		[4378] = "达拉然竞技场",
		[6732] = "虎踞峰",
		
		-- Other
		[4298] = "东瘟疫之地：血色领地",
		[3508] = "阿曼尼小径",
		[3979] = "冰冻之海",
	},
	zhTW = {
		-- Complexes
		[1941] = "時光之穴",
		[25] = "黑石山",
		[4406] = "勇武競技場",
		[3545] = "地獄火堡壘",
		[3905] = "盤牙蓄湖",
		[3893] = "儀式競技場",
		[3842] = "風暴要塞",
		[4024] = "凜懼島",
		[5695] = "安其拉: 沒落的王朝",

		-- Continents
		[0] = "東部王國",
		[1] = "卡林多",
		[530] = "外域",
		[571] = "北裂境",
		[5416] = "大漩渦",
		[870] = "潘達利亞",
		["Azeroth"] = "艾澤拉斯",

		-- Transports
		[72] = "黑暗之門",
		[2257] = "礦道地鐵",

		-- Dungeons
		[5914] = "厄運之槌 - 東方",
		[5913] = "厄運之槌 - 北方",
		[5915] = "厄運之槌 - 西方",

		-- Arenas
		[559] = "納葛蘭競技場",
		[562] = "劍刃競技場",
		[572] = "羅德隆廢墟",
		[4378] = "達拉然競技場",
		[6732] = "猛虎峰",
		
		-- Other
		[4298] = "東瘟疫之地:血色領區",
		[3508] = "阿曼尼小徑",
		[3979] = "冰凍之海",
	},
}
]]--


local function CreateLocalizedZoneNameLookups()
	local uiMapID
	local mapInfo
	local localizedZoneName
	local englishZoneName

	-- 8.0: Use the C_Map API
	-- Note: the loop below is not very sexy but makes sure missing entries in MapIdLookupTable are reported.
	-- It is executed only once, upon initialization.
	for uiMapID = 1, 5000, 1 do
		mapInfo = C_Map.GetMapInfo(uiMapID)	
		if mapInfo then
			localizedZoneName = mapInfo.name
			englishZoneName = MapIdLookupTable[uiMapID]
			
			if englishZoneName then 		
				-- Add combination of English and localized name to lookup tables
				if not BZ[englishZoneName] then
					BZ[englishZoneName] = localizedZoneName
				end
				if not BZR[localizedZoneName] then
					BZR[localizedZoneName] = englishZoneName
				end	
			else
				-- Not in lookup
				trace("|r|cffff4422! -- Tourist:|r English name not found in lookup for uiMapID "..tostring(uiMapID).." ("..tostring(localizedZoneName)..")" )				
			end
		end
	end
	
--[[	
	for mapID, englishName in pairs(MapIdLookupTable) do
		-- Get localized map name
		--localizedZoneName = GetMapNameByID(mapID)  -- 8.0: GetMapNameByID removed
		zoneInfo = C_Map.GetMapInfo(mapID)
		if zoneInfo then
			localizedZoneName = zoneInfo.name
			-- Add combination of English and localized name to lookup tables
			if not BZ[englishName] then
				BZ[englishName] = localizedZoneName
			end
			if not BZR[localizedZoneName] then
				BZR[localizedZoneName] = englishName
			end
			--trace(tostring(mapID)..": "..tostring(localizedZoneName))
		else
			trace("! ----- No map name for ID "..tostring(mapID).." ("..tostring(englishName)..")")
		end
	end
	]]--

	-- Load from zoneTranslation
	local GAME_LOCALE = GetLocale()
	for key, localizedZoneName in pairs(zoneTranslation[GAME_LOCALE]) do
		local englishName = zoneTranslation["enUS"][key]
		if not BZ[englishName] then
			BZ[englishName] = localizedZoneName
		end
		if not BZR[localizedZoneName] then
			BZR[localizedZoneName] = englishName
		end
	end
end

local function AddDuplicatesToLocalizedLookup()
	BZ[Tourist:GetUniqueEnglishZoneNameForLookup("The Maelstrom", 5)] = Tourist:GetUniqueZoneNameForLookup("The Maelstrom", 5)
	BZR[Tourist:GetUniqueZoneNameForLookup("The Maelstrom", 5)] = Tourist:GetUniqueEnglishZoneNameForLookup("The Maelstrom", 5)
	
	BZ[Tourist:GetUniqueEnglishZoneNameForLookup("Nagrand", 7)] = Tourist:GetUniqueZoneNameForLookup("Nagrand", 7)
	BZR[Tourist:GetUniqueZoneNameForLookup("Nagrand", 7)] = Tourist:GetUniqueEnglishZoneNameForLookup("Nagrand", 7)

	BZ[Tourist:GetUniqueEnglishZoneNameForLookup("Shadowmoon Valley", 7)] = Tourist:GetUniqueZoneNameForLookup("Shadowmoon Valley", 7)
	BZR[Tourist:GetUniqueZoneNameForLookup("Shadowmoon Valley", 7)] = Tourist:GetUniqueEnglishZoneNameForLookup("Shadowmoon Valley", 7)
	
	BZ[Tourist:GetUniqueEnglishZoneNameForLookup("Hellfire Citadel", 7)] = Tourist:GetUniqueZoneNameForLookup("Hellfire Citadel", 7)
	BZR[Tourist:GetUniqueZoneNameForLookup("Hellfire Citadel", 7)] = Tourist:GetUniqueEnglishZoneNameForLookup("Hellfire Citadel", 7)
	
	BZ[Tourist:GetUniqueEnglishZoneNameForLookup("Dalaran", 8)] = Tourist:GetUniqueZoneNameForLookup("Dalaran", 8)
	BZR[Tourist:GetUniqueZoneNameForLookup("Dalaran", 8)] = Tourist:GetUniqueEnglishZoneNameForLookup("Dalaran", 8)
	
	BZ[Tourist:GetUniqueEnglishZoneNameForLookup("The Violet Hold", 8)] = Tourist:GetUniqueZoneNameForLookup("The Violet Hold", 8)
	BZR[Tourist:GetUniqueZoneNameForLookup("The Violet Hold", 8)] = Tourist:GetUniqueEnglishZoneNameForLookup("The Violet Hold", 8)
end


--------------------------------------------------------------------------------------------------------
--                                            BZ table                                             --
--------------------------------------------------------------------------------------------------------

do
	Tourist.frame = oldLib and oldLib.frame or CreateFrame("Frame", MAJOR_VERSION .. "Frame", UIParent)
	Tourist.frame:UnregisterAllEvents()
	Tourist.frame:RegisterEvent("PLAYER_LEVEL_UP")
	Tourist.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	Tourist.frame:SetScript("OnEvent", function(frame, event, ...)
		PLAYER_LEVEL_UP(Tourist, ...)
	end)


	trace("Tourist: Initializing localized zone name lookups...")
	CreateLocalizedZoneNameLookups()
	AddDuplicatesToLocalizedLookup()

	
	-- TRANSPORT DEFINITIONS ----------------------------------------------------------------

	local transports = {}

	-- Boats
	transports["BOOTYBAY_RATCHET_BOAT"] = string.format(X_Y_BOAT, BZ["The Cape of Stranglethorn"], BZ["Northern Barrens"])
	transports["MENETHIL_HOWLINGFJORD_BOAT"] = string.format(X_Y_BOAT, BZ["Wetlands"], BZ["Howling Fjord"])
	transports["MENETHIL_THERAMORE_BOAT"] = string.format(X_Y_BOAT, BZ["Wetlands"], BZ["Dustwallow Marsh"])
	transports["MOAKI_KAMAGUA_BOAT"] = string.format(X_Y_BOAT, BZ["Dragonblight"], BZ["Howling Fjord"])
	transports["MOAKI_UNUPE_BOAT"] = string.format(X_Y_BOAT, BZ["Dragonblight"], BZ["Borean Tundra"])
	transports["STORMWIND_BOREANTUNDRA_BOAT"] = string.format(X_Y_BOAT, BZ["Stormwind City"], BZ["Borean Tundra"])
	transports["TELDRASSIL_AZUREMYST_BOAT"] = string.format(X_Y_BOAT, BZ["Teldrassil"], BZ["Azuremyst Isle"])
	transports["TELDRASSIL_STORMWIND_BOAT"] = string.format(X_Y_BOAT, BZ["Teldrassil"], BZ["Stormwind City"])
	transports["STORMWIND_TIRAGARDESOUND_BOAT"] = string.format(X_Y_BOAT, BZ["Stormwind City"], BZ["Tiragarde Sound"])
	transports["ECHOISLES_ZULDAZAR_BOAT"] = string.format(X_Y_BOAT, BZ["Echo Isles"], BZ["Zuldazar"])
	
	
	-- Zeppelins
	transports["ORGRIMMAR_BOREANTUNDRA_ZEPPELIN"] = string.format(X_Y_ZEPPELIN, BZ["Orgrimmar"], BZ["Borean Tundra"])
	transports["ORGRIMMAR_GROMGOL_ZEPPELIN"] = string.format(X_Y_ZEPPELIN, BZ["Orgrimmar"], BZ["Northern Stranglethorn"])
	transports["ORGRIMMAR_THUNDERBLUFF_ZEPPELIN"] = string.format(X_Y_ZEPPELIN, BZ["Orgrimmar"], BZ["Thunder Bluff"])
	transports["ORGRIMMAR_UNDERCITY_ZEPPELIN"] = string.format(X_Y_ZEPPELIN, BZ["Orgrimmar"], BZ["Undercity"])
	transports["UNDERCITY_GROMGOL_ZEPPELIN"] = string.format(X_Y_ZEPPELIN, BZ["Undercity"], BZ["Northern Stranglethorn"])
	transports["UNDERCITY_HOWLINGFJORD_ZEPPELIN"] = string.format(X_Y_ZEPPELIN, BZ["Undercity"], BZ["Howling Fjord"])
	
	-- Teleports
	transports["SILVERMOON_UNDERCITY_TELEPORT"] = string.format(X_Y_TELEPORT, BZ["Silvermoon City"], BZ["Undercity"])
	transports["DALARAN_CRYSTALSONG_TELEPORT"] = string.format(X_Y_TELEPORT, BZ["Dalaran"], BZ["Crystalsong Forest"])
	
	-- Portals
	transports["DALARAN_COT_PORTAL"] = string.format(X_Y_PORTAL, BZ["Dalaran"], BZ["Caverns of Time"])
	transports["DALARAN_ORGRIMMAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Dalaran"], BZ["Orgrimmar"])
	transports["DALARAN_STORMWIND_PORTAL"] = string.format(X_Y_PORTAL, BZ["Dalaran"], BZ["Stormwind City"])
	transports["DALARANBROKENISLES_COT_PORTAL"] = string.format(X_Y_PORTAL, BZ["Dalaran"].." ("..BZ["Broken Isles"]..")", BZ["Caverns of Time"])
	transports["DALARANBROKENISLES_DARNASSUS_PORTAL"] = string.format(X_Y_PORTAL, BZ["Dalaran"].." ("..BZ["Broken Isles"]..")", BZ["Darnassus"])
	transports["DALARANBROKENISLES_DRAGONBLIGHT_PORTAL"] = string.format(X_Y_PORTAL, BZ["Dalaran"].." ("..BZ["Broken Isles"]..")", BZ["Dragonblight"])
	transports["DALARANBROKENISLES_EXODAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Dalaran"].." ("..BZ["Broken Isles"]..")", BZ["The Exodar"])
	transports["DALARANBROKENISLES_HILLSBRAD_PORTAL"] = string.format(X_Y_PORTAL, BZ["Dalaran"].." ("..BZ["Broken Isles"]..")", BZ["Hillsbrad Foothills"])
	transports["DALARANBROKENISLES_IRONFORGE_PORTAL"] = string.format(X_Y_PORTAL, BZ["Dalaran"].." ("..BZ["Broken Isles"]..")", BZ["Ironforge"])
	transports["DALARANBROKENISLES_KARAZHAN_PORTAL"] = string.format(X_Y_PORTAL, BZ["Dalaran"].." ("..BZ["Broken Isles"]..")", BZ["Karazhan"])
	transports["DALARANBROKENISLES_ORGRIMMAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Dalaran"].." ("..BZ["Broken Isles"]..")", BZ["Orgrimmar"])
	transports["DALARANBROKENISLES_SEVENSTARS_PORTAL"] = string.format(X_Y_PORTAL, BZ["Dalaran"].." ("..BZ["Broken Isles"]..")", BZ["Shrine of Seven Stars"])
	transports["DALARANBROKENISLES_SHATTRATH_PORTAL"] = string.format(X_Y_PORTAL, BZ["Dalaran"].." ("..BZ["Broken Isles"]..")", BZ["Shattrath City"])
	transports["DALARANBROKENISLES_SILVERMOON_PORTAL"] = string.format(X_Y_PORTAL, BZ["Dalaran"].." ("..BZ["Broken Isles"]..")", BZ["Silvermoon City"])
	transports["DALARANBROKENISLES_STORMWIND_PORTAL"] = string.format(X_Y_PORTAL, BZ["Dalaran"].." ("..BZ["Broken Isles"]..")", BZ["Stormwind City"])
	transports["DALARANBROKENISLES_THUNDERBLUFF_PORTAL"] = string.format(X_Y_PORTAL, BZ["Dalaran"].." ("..BZ["Broken Isles"]..")", BZ["Thunder Bluff"])
	transports["DALARANBROKENISLES_TWOMOONS_PORTAL"] = string.format(X_Y_PORTAL, BZ["Dalaran"].." ("..BZ["Broken Isles"]..")", BZ["Shrine of Two Moons"])
	transports["DALARANBROKENISLES_UNDERCITY_PORTAL"] = string.format(X_Y_PORTAL, BZ["Dalaran"].." ("..BZ["Broken Isles"]..")", BZ["Undercity"])
	transports["DARKMOON_ELWYNNFOREST_PORTAL"] = string.format(X_Y_PORTAL, BZ["Darkmoon Island"], BZ["Elwynn Forest"])
	transports["DARKMOON_MULGORE_PORTAL"] = string.format(X_Y_PORTAL, BZ["Darkmoon Island"], BZ["Mulgore"])
	transports["DARNASSUS_EXODAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Darnassus"], BZ["The Exodar"])
	transports["DARNASSUS_HELLFIRE_PORTAL"] = string.format(X_Y_PORTAL, BZ["Darnassus"], BZ["Hellfire Peninsula"])
	transports["DEEPHOLM_ORGRIMMAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Deepholm"], BZ["Orgrimmar"])
	transports["DEEPHOLM_STORMWIND_PORTAL"] = string.format(X_Y_PORTAL, BZ["Deepholm"], BZ["Stormwind City"])
	transports["ELWYNNFOREST_DARKMOON_PORTAL"] = string.format(X_Y_PORTAL, BZ["Elwynn Forest"], BZ["Darkmoon Island"])
	transports["EXODAR_DARNASSUS_PORTAL"] = string.format(X_Y_PORTAL, BZ["The Exodar"], BZ["Darnassus"])
	transports["EXODAR_HELLFIRE_PORTAL"] = string.format(X_Y_PORTAL, BZ["The Exodar"], BZ["Hellfire Peninsula"])
	transports["FROSTFIRERIDGE_ORGRIMMAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Frostfire Ridge"], BZ["Orgrimmar"])
	transports["HELLFIRE_ORGRIMMAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Hellfire Peninsula"], BZ["Orgrimmar"])
	transports["HELLFIRE_STORMWIND_PORTAL"] = string.format(X_Y_PORTAL, BZ["Hellfire Peninsula"], BZ["Stormwind City"])
	transports["IRONFORGE_HELLFIRE_PORTAL"] = string.format(X_Y_PORTAL, BZ["Ironforge"], BZ["Hellfire Peninsula"])
	transports["ISLEOFTHUNDER_TOWNLONGSTEPPES_PORTAL"] = string.format(X_Y_PORTAL, BZ["Isle of Thunder"], BZ["Townlong Steppes"])
	transports["JADEFOREST_ORGRIMMAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["The Jade Forest"], BZ["Orgrimmar"])
	transports["JADEFOREST_STORMWIND_PORTAL"] = string.format(X_Y_PORTAL, BZ["The Jade Forest"], BZ["Stormwind City"])
	transports["MULGORE_DARKMOON_PORTAL"] = string.format(X_Y_PORTAL, BZ["Mulgore"], BZ["Darkmoon Island"])
	transports["ORGRIMMAR_BLASTEDLANDS_PORTAL"] = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Blasted Lands"])
	transports["ORGRIMMAR_DALARANBROKENISLES_PORTAL"] = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Dalaran"].." ("..BZ["Broken Isles"]..")")
	transports["ORGRIMMAR_DEEPHOLM_PORTAL"] = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Deepholm"])
	transports["ORGRIMMAR_HELLFIRE_PORTAL"] = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Hellfire Peninsula"])
	transports["ORGRIMMAR_JADEFOREST_PORTAL"] = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["The Jade Forest"])
	transports["ORGRIMMAR_MOUNTHYJAL_PORTAL"] = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Mount Hyjal"])
	transports["ORGRIMMAR_TOLBARAD_PORTAL"] = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Tol Barad Peninsula"])
	transports["ORGRIMMAR_TWILIGHTHIGHLANDS_PORTAL"] = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Twilight Highlands"])
	transports["ORGRIMMAR_ULDUM_PORTAL"] = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Uldum"])
	transports["ORGRIMMAR_VASHJIR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Vashj'ir"])
	transports["SEVENSTARS_DALARAN_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shrine of Seven Stars"], BZ["Dalaran"])
	transports["SEVENSTARS_DARNASSUS_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shrine of Seven Stars"], BZ["Darnassus"])
	transports["SEVENSTARS_EXODAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shrine of Seven Stars"], BZ["The Exodar"])
	transports["SEVENSTARS_IRONFORGE_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shrine of Seven Stars"], BZ["Ironforge"])
	transports["SEVENSTARS_SHATTRATH_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shrine of Seven Stars"], BZ["Shattrath City"])
	transports["SEVENSTARS_STORMWIND_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shrine of Seven Stars"], BZ["Stormwind City"])
	transports["SHADOWMOONVALLEY_STORMWIND_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shadowmoon Valley"], BZ["Stormwind City"])
	transports["SHATTRATH_ORGRIMMAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["Orgrimmar"])
	transports["SHATTRATH_QUELDANAS_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["Isle of Quel'Danas"])
	transports["SHATTRATH_STORMWIND_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["Stormwind City"])
	transports["SILVERMOON_HELLFIRE_PORTAL"] = string.format(X_Y_PORTAL, BZ["Silvermoon City"], BZ["Hellfire Peninsula"])
	transports["STORMSHIELD_DARNASSUS_PORTAL"] = string.format(X_Y_PORTAL, BZ["Stormshield"], BZ["Darnassus"])
	transports["STORMSHIELD_IRONFORGE_PORTAL"] = string.format(X_Y_PORTAL, BZ["Stormshield"], BZ["Ironforge"])
	transports["STORMSHIELD_STORMWIND_PORTAL"] = string.format(X_Y_PORTAL, BZ["Stormshield"], BZ["Stormwind City"])
	transports["STORMWIND_BLASTEDLANDS_PORTAL"] = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Blasted Lands"])
	transports["STORMWIND_DALARANBROKENISLES_PORTAL"] = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Dalaran"].." ("..BZ["Broken Isles"]..")")
	transports["STORMWIND_DEEPHOLM_PORTAL"] = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Deepholm"])
	transports["STORMWIND_HELLFIRE_PORTAL"] = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Hellfire Peninsula"])
	transports["STORMWIND_JADEFOREST_PORTAL"] = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["The Jade Forest"])
	transports["STORMWIND_MOUNTHYJAL_PORTAL"] = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Mount Hyjal"])
	transports["STORMWIND_TOLBARAD_PORTAL"] = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Tol Barad Peninsula"])
	transports["STORMWIND_TWILIGHTHIGHLANDS_PORTAL"] = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Twilight Highlands"])
	transports["STORMWIND_ULDUM_PORTAL"] = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Uldum"])
	transports["STORMWIND_VASHJIR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Vashj'ir"])
	transports["THUNDERBLUFF_HELLFIRE_PORTAL"] = string.format(X_Y_PORTAL, BZ["Thunder Bluff"], BZ["Hellfire Peninsula"])
	transports["TOLBARAD_ORGRIMMAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Tol Barad Peninsula"], BZ["Orgrimmar"])
	transports["TOLBARAD_STORMWIND_PORTAL"] = string.format(X_Y_PORTAL, BZ["Tol Barad Peninsula"], BZ["Stormwind City"])
	transports["TOWNLONGSTEPPES_ISLEOFTHUNDER_PORTAL"] = string.format(X_Y_PORTAL, BZ["Townlong Steppes"], BZ["Isle of Thunder"])
	transports["TWILIGHTHIGHLANDS_ORGRIMMAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Twilight Highlands"], BZ["Orgrimmar"])
	transports["TWILIGHTHIGHLANDS_STORMWIND_PORTAL"] = string.format(X_Y_PORTAL, BZ["Twilight Highlands"], BZ["Stormwind City"])
	transports["TWOMOONS_DALARAN_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shrine of Two Moons"], BZ["Dalaran"])
	transports["TWOMOONS_ORGRIMMAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shrine of Two Moons"], BZ["Orgrimmar"])
	transports["TWOMOONS_SHATTRATH_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shrine of Two Moons"], BZ["Shattrath City"])
	transports["TWOMOONS_SILVERMOON_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shrine of Two Moons"], BZ["Silvermoon City"])
	transports["TWOMOONS_THUNDERBLUFF_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shrine of Two Moons"], BZ["Thunder Bluff"])
	transports["TWOMOONS_UNDERCITY_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shrine of Two Moons"], BZ["Undercity"])
	transports["UNDERCITY_HELLFIRE_PORTAL"] = string.format(X_Y_PORTAL, BZ["Undercity"], BZ["Hellfire Peninsula"])
	transports["WARSPEAR_ORGRIMMAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Warspear"], BZ["Orgrimmar"])
	transports["WARSPEAR_THUNDERBLUFF_PORTAL"] = string.format(X_Y_PORTAL, BZ["Warspear"], BZ["Thunder Bluff"])
	transports["WARSPEAR_UNDERCITY_PORTAL"] = string.format(X_Y_PORTAL, BZ["Warspear"], BZ["Undercity"])

	transports["STORMWIND_TIRAGARDESOUND_PORTAL"] = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Tiragarde Sound"])
	transports["TIRAGARDESOUND_STORMWIND_PORTAL"] = string.format(X_Y_PORTAL, BZ["Tiragarde Sound"], BZ["Stormwind City"])
	transports["EXODAR_TIRAGARDESOUND_PORTAL"] = string.format(X_Y_PORTAL, BZ["The Exodar"], BZ["Tiragarde Sound"])
	transports["TIRAGARDESOUND_EXODAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Tiragarde Sound"], BZ["The Exodar"])
	transports["IRONFORGE_TIRAGARDESOUND_PORTAL"] = string.format(X_Y_PORTAL, BZ["Ironforge"], BZ["Tiragarde Sound"])
	transports["TIRAGARDESOUND_IRONFORGE_PORTAL"] = string.format(X_Y_PORTAL, BZ["Tiragarde Sound"], BZ["Ironforge"])
	
	transports["SILVERMOON_ZULDAZAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Silvermoon City"], BZ["Zuldazar"])
	transports["ZULDAZAR_SILVERMOON_PORTAL"] = string.format(X_Y_PORTAL, BZ["Zuldazar"], BZ["Silvermoon City"])
	transports["ORGRIMMAR_ZULDAZAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Zuldazar"])
	transports["ORGRIMMAR_ZULDAZAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Zuldazar"])
	transports["ZULDAZAR_ORGRIMMAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Zuldazar"], BZ["Orgrimmar"])
	transports["THUNDERBLUFF_ZULDAZAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Thunder Bluff"], BZ["Zuldazar"])
	transports["ZULDAZAR_THUNDERBLUFF_PORTAL"] = string.format(X_Y_PORTAL, BZ["Zuldazar"], BZ["Thunder Bluff"])
	
	
	local zones = {}

	-- CONTINENTS ---------------------------------------------------------------

	zones[BZ["Azeroth"]] = {
		type = "Continent",
--		yards = 44531.82907938571,
		yards = 33400.121,
		x_offset = 0,
		y_offset = 0,
		continent = Azeroth,
	}
	
	zones[BZ["Eastern Kingdoms"]] = {
		type = "Continent",
		continent = Eastern_Kingdoms,
	}

	zones[BZ["Kalimdor"]] = {
		type = "Continent",
		continent = Kalimdor,
	}

	zones[BZ["Outland"]] = {
		type = "Continent",
		continent = Outland,
	}

	zones[BZ["Northrend"]] = {
		type = "Continent",
		continent = Northrend,
	}

	zones[BZ["The Maelstrom"]] = {
		type = "Continent",
		continent = The_Maelstrom,
	}

	zones[BZ["Pandaria"]] = {
		type = "Continent",
		continent = Pandaria,
	}

	zones[BZ["Draenor"]] = {
		type = "Continent",
		continent = Draenor,
	}

	zones[BZ["Broken Isles"]] = {
		type = "Continent",
		continent = Broken_Isles,
	}

	zones[BZ["Argus"]] = {
		type = "Continent",
		continent = Argus,
	}

	zones[BZ["Zandalar"]] = {
		type = "Continent",
		continent = Zandalar,
	}	

	zones[BZ["Kul Tiras"]] = {
		type = "Continent",
		continent = Kul_Tiras,
	}	
	
	-- TRANSPORTS ---------------------------------------------------------------

	zones[transports["STORMWIND_BOREANTUNDRA_BOAT"]] = {
		paths = {
			[BZ["Stormwind City"]] = true,
			[BZ["Borean Tundra"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["ORGRIMMAR_BOREANTUNDRA_ZEPPELIN"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
			[BZ["Borean Tundra"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["UNDERCITY_HOWLINGFJORD_ZEPPELIN"]] = {
		paths = {
			[BZ["Tirisfal Glades"]] = true,
			[BZ["Howling Fjord"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["ORGRIMMAR_BLASTEDLANDS_PORTAL"]] = {
		paths = {
			[BZ["Blasted Lands"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["ORGRIMMAR_HELLFIRE_PORTAL"]] = {
		paths = {
			[BZ["Hellfire Peninsula"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}
	
	zones[transports["HELLFIRE_ORGRIMMAR_PORTAL"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["UNDERCITY_HELLFIRE_PORTAL"]] = {
		paths = {
			[BZ["Hellfire Peninsula"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["THUNDERBLUFF_HELLFIRE_PORTAL"]] = {
		paths = {
			[BZ["Hellfire Peninsula"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["SILVERMOON_HELLFIRE_PORTAL"]] = {
		paths = {
			[BZ["Hellfire Peninsula"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["STORMWIND_BLASTEDLANDS_PORTAL"]] = {
		paths = {
			[BZ["Blasted Lands"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["STORMWIND_HELLFIRE_PORTAL"]] = {
		paths = {
			[BZ["Hellfire Peninsula"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	
	zones[transports["HELLFIRE_STORMWIND_PORTAL"]] = {
		paths = {
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["DALARAN_STORMWIND_PORTAL"]] = {
		paths = BZ["Stormwind City"],
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["DALARAN_ORGRIMMAR_PORTAL"]] = {
		paths = BZ["Orgrimmar"],
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["DARNASSUS_HELLFIRE_PORTAL"]] = {
		paths = {
			[BZ["Hellfire Peninsula"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["EXODAR_HELLFIRE_PORTAL"]] = {
		paths = {
			[BZ["Hellfire Peninsula"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["DARNASSUS_EXODAR_PORTAL"]] = {
		paths = {
			[BZ["The Exodar"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["EXODAR_DARNASSUS_PORTAL"]] = {
		paths = {
			[BZ["Darnassus"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}


	zones[transports["MULGORE_DARKMOON_PORTAL"]] = {
		paths = BZ["Darkmoon Island"],
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["DARKMOON_MULGORE_PORTAL"]] = {
		paths = BZ["Mulgore"],
		faction = "Horde",
		type = "Transport",
	}


	zones[transports["ELWYNNFOREST_DARKMOON_PORTAL"]] = {
		paths = BZ["Darkmoon Island"],
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["DARKMOON_ELWYNNFOREST_PORTAL"]] = {
		paths = BZ["Elwynn Forest"],
		faction = "Alliance",
		type = "Transport",
	}



	zones[transports["IRONFORGE_HELLFIRE_PORTAL"]] = {
		paths = {
			[BZ["Hellfire Peninsula"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["TELDRASSIL_STORMWIND_BOAT"]] = {
		paths = {
			[BZ["Teldrassil"]] = true,
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["TELDRASSIL_AZUREMYST_BOAT"]] = {
		paths = {
			[BZ["Teldrassil"]] = true,
			[BZ["Azuremyst Isle"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["BOOTYBAY_RATCHET_BOAT"]] = {
		paths = {
			[BZ["The Cape of Stranglethorn"]] = true,
			[BZ["Northern Barrens"]] = true,
		},
		type = "Transport",
	}

	zones[transports["MENETHIL_HOWLINGFJORD_BOAT"]] = {
		paths = {
			[BZ["Wetlands"]] = true,
			[BZ["Howling Fjord"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["MENETHIL_THERAMORE_BOAT"]] = {
		paths = {
			[BZ["Wetlands"]] = true,
			[BZ["Dustwallow Marsh"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["ORGRIMMAR_GROMGOL_ZEPPELIN"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
			[BZ["Northern Stranglethorn"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["ORGRIMMAR_UNDERCITY_ZEPPELIN"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
			[BZ["Tirisfal Glades"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["ORGRIMMAR_THUNDERBLUFF_ZEPPELIN"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
			[BZ["Thunder Bluff"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["SHATTRATH_QUELDANAS_PORTAL"]] = {
		paths = BZ["Isle of Quel'Danas"],
		type = "Transport",
	}

	zones[transports["SHATTRATH_ORGRIMMAR_PORTAL"]] = {
		paths = BZ["Orgrimmar"],
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["SHATTRATH_STORMWIND_PORTAL"]] = {
		paths = BZ["Stormwind City"],
		faction = "Alliance",
		type = "Transport",
	}


	zones[transports["MOAKI_UNUPE_BOAT"]] = {
		paths = {
			[BZ["Dragonblight"]] = true,
			[BZ["Borean Tundra"]] = true,
		},
		type = "Transport",
	}

	zones[transports["MOAKI_KAMAGUA_BOAT"]] = {
		paths = {
			[BZ["Dragonblight"]] = true,
			[BZ["Howling Fjord"]] = true,
		},
		type = "Transport",
	}

	zones[BZ["The Dark Portal"]] = {
		paths = {
			[BZ["Blasted Lands"]] = true,
			[BZ["Hellfire Peninsula"]] = true,
		},
		type = "Transport",
	}

	zones[BZ["Deeprun Tram"]] = {
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Stormwind City"]] = true,
			[BZ["Ironforge"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["UNDERCITY_GROMGOL_ZEPPELIN"]] = {
		paths = {
			[BZ["Northern Stranglethorn"]] = true,
			[BZ["Tirisfal Glades"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["SILVERMOON_UNDERCITY_TELEPORT"]] = {
		paths = {
			[BZ["Silvermoon City"]] = true,
			[BZ["Undercity"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["DALARAN_CRYSTALSONG_TELEPORT"]] = {
		paths = {
			[BZ["Dalaran"]] = true,
			[BZ["Crystalsong Forest"]] = true,
		},
		type = "Transport",
	}

	zones[transports["DALARAN_COT_PORTAL"]] = {
		paths = BZ["Caverns of Time"],
		type = "Transport",
	}


	zones[transports["STORMWIND_TWILIGHTHIGHLANDS_PORTAL"]] = {
		paths = {
			[BZ["Twilight Highlands"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["TWILIGHTHIGHLANDS_STORMWIND_PORTAL"]] = {
		paths = {
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["STORMWIND_MOUNTHYJAL_PORTAL"]] = {
		paths = {
			[BZ["Mount Hyjal"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["STORMWIND_DEEPHOLM_PORTAL"]] = {
		paths = {
			[BZ["Deepholm"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["DEEPHOLM_STORMWIND_PORTAL"]] = {
		paths = {
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["TOLBARAD_STORMWIND_PORTAL"]] = {
		paths = {
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["STORMWIND_ULDUM_PORTAL"]] = {
		paths = {
			[BZ["Uldum"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["STORMWIND_VASHJIR_PORTAL"]] = {
		paths = {
			[BZ["Vashj'ir"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["STORMWIND_TOLBARAD_PORTAL"]] = {
		paths = {
			[BZ["Tol Barad Peninsula"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["ORGRIMMAR_TWILIGHTHIGHLANDS_PORTAL"]] = {
		paths = {
			[BZ["Twilight Highlands"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["TWILIGHTHIGHLANDS_ORGRIMMAR_PORTAL"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["ORGRIMMAR_MOUNTHYJAL_PORTAL"]] = {
		paths = {
			[BZ["Mount Hyjal"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["ORGRIMMAR_DEEPHOLM_PORTAL"]] = {
		paths = {
			[BZ["Deepholm"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["DEEPHOLM_ORGRIMMAR_PORTAL"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["TOLBARAD_ORGRIMMAR_PORTAL"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["ORGRIMMAR_ULDUM_PORTAL"]] = {
		paths = {
			[BZ["Uldum"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["ORGRIMMAR_VASHJIR_PORTAL"]] = {
		paths = {
			[BZ["Vashj'ir"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["ORGRIMMAR_TOLBARAD_PORTAL"]] = {
		paths = {
			[BZ["Tol Barad Peninsula"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	
	zones[transports["ORGRIMMAR_JADEFOREST_PORTAL"]] = {
		paths = {
			[BZ["The Jade Forest"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}
	
	zones[transports["JADEFOREST_ORGRIMMAR_PORTAL"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["STORMWIND_JADEFOREST_PORTAL"]] = {
		paths = {
			[BZ["The Jade Forest"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	zones[transports["JADEFOREST_STORMWIND_PORTAL"]] = {
		paths = {
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}	

	zones[transports["TOWNLONGSTEPPES_ISLEOFTHUNDER_PORTAL"]] = {
		paths = {
			[BZ["Isle of Thunder"]] = true,
		},
		type = "Transport",
	}	

	zones[transports["ISLEOFTHUNDER_TOWNLONGSTEPPES_PORTAL"]] = {
		paths = {
			[BZ["Townlong Steppes"]] = true,
		},
		type = "Transport",
	}	

	zones[transports["WARSPEAR_ORGRIMMAR_PORTAL"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}
	
	zones[transports["WARSPEAR_UNDERCITY_PORTAL"]] = {
		paths = {
			[BZ["Undercity"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}
	
	zones[transports["WARSPEAR_THUNDERBLUFF_PORTAL"]] = {
		paths = {
			[BZ["Thunder Bluff"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	
	zones[transports["STORMSHIELD_STORMWIND_PORTAL"]] = {
		paths = {
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}	

	zones[transports["STORMSHIELD_IRONFORGE_PORTAL"]] = {
		paths = {
			[BZ["Ironforge"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["STORMSHIELD_DARNASSUS_PORTAL"]] = {
		paths = {
			[BZ["Darnassus"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	zones[transports["SHADOWMOONVALLEY_STORMWIND_PORTAL"]] = {
		paths = {
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}	

	zones[transports["FROSTFIRERIDGE_ORGRIMMAR_PORTAL"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}	
	

	
	zones[transports["TWOMOONS_ORGRIMMAR_PORTAL"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}	
	
	zones[transports["TWOMOONS_UNDERCITY_PORTAL"]] = {
		paths = {
			[BZ["Undercity"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}
	
	zones[transports["TWOMOONS_THUNDERBLUFF_PORTAL"]] = {
		paths = {
			[BZ["Thunder Bluff"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}	
	
	zones[transports["TWOMOONS_SILVERMOON_PORTAL"]] = {
		paths = {
			[BZ["Silvermoon City"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}
	
	zones[transports["TWOMOONS_SHATTRATH_PORTAL"]] = {
		paths = {
			[BZ["Shattrath City"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}
	
	zones[transports["TWOMOONS_DALARAN_PORTAL"]] = {
		paths = {
			[BZ["Dalaran"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}	
	
	zones[transports["SEVENSTARS_EXODAR_PORTAL"]] = {
		paths = {
			[BZ["The Exodar"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	zones[transports["SEVENSTARS_STORMWIND_PORTAL"]] = {
		paths = {
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	zones[transports["SEVENSTARS_IRONFORGE_PORTAL"]] = {
		paths = {
			[BZ["Ironforge"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	zones[transports["SEVENSTARS_DARNASSUS_PORTAL"]] = {
		paths = {
			[BZ["Darnassus"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	zones[transports["SEVENSTARS_SHATTRATH_PORTAL"]] = {
		paths = {
			[BZ["Shattrath City"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	zones[transports["SEVENSTARS_DALARAN_PORTAL"]] = {
		paths = {
			[BZ["Dalaran"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	
	zones[transports["DALARANBROKENISLES_STORMWIND_PORTAL"]] = {
		paths = {
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["DALARANBROKENISLES_EXODAR_PORTAL"]] = {
		paths = {
			[BZ["The Exodar"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	zones[transports["DALARANBROKENISLES_DARNASSUS_PORTAL"]] = {
		paths = {
			[BZ["Darnassus"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	zones[transports["DALARANBROKENISLES_IRONFORGE_PORTAL"]] = {
		paths = {
			[BZ["Ironforge"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	zones[transports["DALARANBROKENISLES_SEVENSTARS_PORTAL"]] = {
		paths = {
			[BZ["Shrine of Seven Stars"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["DALARANBROKENISLES_ORGRIMMAR_PORTAL"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}
	
	zones[transports["DALARANBROKENISLES_UNDERCITY_PORTAL"]] = {
		paths = {
			[BZ["Undercity"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["DALARANBROKENISLES_THUNDERBLUFF_PORTAL"]] = {
		paths = {
			[BZ["Thunder Bluff"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["DALARANBROKENISLES_SILVERMOON_PORTAL"]] = {
		paths = {
			[BZ["Silvermoon City"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["DALARANBROKENISLES_TWOMOONS_PORTAL"]] = {
		paths = {
			[BZ["Shrine of Two Moons"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}	
	
	zones[transports["DALARANBROKENISLES_COT_PORTAL"]] = {
		paths = {
			[BZ["Caverns of Time"]] = true,
		},
		type = "Transport",
	}	
	
	zones[transports["DALARANBROKENISLES_SHATTRATH_PORTAL"]] = {
		paths = {
			[BZ["Shattrath City"]] = true,
		},
		type = "Transport",
	}	
	
	zones[transports["DALARANBROKENISLES_DRAGONBLIGHT_PORTAL"]] = {
		paths = {
			[BZ["Dragonblight"]] = true,
		},
		type = "Transport",
	}	
	
	zones[transports["DALARANBROKENISLES_HILLSBRAD_PORTAL"]] = {
		paths = {
			[BZ["Hillsbrad Foothills"]] = true,
		},
		type = "Transport",
	}	
	
	zones[transports["DALARANBROKENISLES_KARAZHAN_PORTAL"]] = {
		paths = {
			[BZ["Karazhan"]] = true,
		},
		type = "Transport",
	}	
	
	zones[transports["ORGRIMMAR_DALARANBROKENISLES_PORTAL"]] = {
		paths = {
			[BZ["Dalaran"].." ("..BZ["Broken Isles"]..")"] = true,
		},
		faction = "Horde",
		type = "Transport",
	}	
	
	zones[transports["STORMWIND_DALARANBROKENISLES_PORTAL"]] = {
		paths = {
			[BZ["Dalaran"].." ("..BZ["Broken Isles"]..")"] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}	

	zones[transports["ECHOISLES_ZULDAZAR_BOAT"]] = {
		paths = {
			[BZ["Echo Isles"]] = true,
			[BZ["Zuldazar"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["STORMWIND_TIRAGARDESOUND_BOAT"]] = {
		paths = {
			[BZ["Stormwind City"]] = true,
			[BZ["Tiragarde Sound"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["STORMWIND_TIRAGARDESOUND_PORTAL"]] = {
		paths = {
			[BZ["Tiragarde Sound"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	zones[transports["TIRAGARDESOUND_STORMWIND_PORTAL"]] = {
		paths = {
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	
	zones[transports["EXODAR_TIRAGARDESOUND_PORTAL"]] = {
		paths = {
			[BZ["Tiragarde Sound"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	zones[transports["TIRAGARDESOUND_EXODAR_PORTAL"]] = {
		paths = {
			[BZ["The Exodar"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	zones[transports["IRONFORGE_TIRAGARDESOUND_PORTAL"]] = {
		paths = {
			[BZ["Tiragarde Sound"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	zones[transports["TIRAGARDESOUND_IRONFORGE_PORTAL"]] = {
		paths = {
			[BZ["Ironforge"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}	
	
	
	
	zones[transports["SILVERMOON_ZULDAZAR_PORTAL"]] = {
		paths = {
			[BZ["Zuldazar"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}	

	zones[transports["ZULDAZAR_SILVERMOON_PORTAL"]] = {
		paths = {
			[BZ["Silvermoon City"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}		

	zones[transports["ORGRIMMAR_ZULDAZAR_PORTAL"]] = {
		paths = {
			[BZ["Zuldazar"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}	

	zones[transports["ZULDAZAR_ORGRIMMAR_PORTAL"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}	

	zones[transports["THUNDERBLUFF_ZULDAZAR_PORTAL"]] = {
		paths = {
			[BZ["Zuldazar"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}	

	zones[transports["ZULDAZAR_THUNDERBLUFF_PORTAL"]] = {
		paths = {
			[BZ["Thunder Bluff"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}
	
	
	-- ZONES, INSTANCES AND COMPLEXES ---------------------------------------------------------

	-- Eastern Kingdoms cities and zones --
	
	zones[BZ["Stormwind City"]] = {
		continent = Eastern_Kingdoms,
		instances = BZ["The Stockade"],
		paths = {
			[BZ["Deeprun Tram"]] = true,
			[BZ["The Stockade"]] = true,
			[BZ["Elwynn Forest"]] = true,
			[transports["TELDRASSIL_STORMWIND_BOAT"]] = true,
			[transports["STORMWIND_BOREANTUNDRA_BOAT"]] = true,
			[transports["STORMWIND_BLASTEDLANDS_PORTAL"]] = true,
			[transports["STORMWIND_HELLFIRE_PORTAL"]] = true,
			[transports["STORMWIND_TWILIGHTHIGHLANDS_PORTAL"]] = true,
			[transports["STORMWIND_MOUNTHYJAL_PORTAL"]] = true,
			[transports["STORMWIND_DEEPHOLM_PORTAL"]] = true,
			[transports["STORMWIND_ULDUM_PORTAL"]] = true,
			[transports["STORMWIND_VASHJIR_PORTAL"]] = true,
			[transports["STORMWIND_TOLBARAD_PORTAL"]] = true,
			[transports["STORMWIND_JADEFOREST_PORTAL"]] = true,
			[transports["STORMWIND_DALARANBROKENISLES_PORTAL"]] = true,
			[transports["STORMWIND_TIRAGARDESOUND_BOAT"]] = true,
			[transports["STORMWIND_TIRAGARDESOUND_PORTAL"]] = true,
		},
		faction = "Alliance",
		type = "City",
		fishing_min = 75,
		battlepet_low = 1,
		battlepet_high = 1,
	}
	
	zones[BZ["Undercity"]] = {
		continent = Eastern_Kingdoms,
		instances = BZ["Ruins of Lordaeron"],
		paths = {
			[BZ["Tirisfal Glades"]] = true,
			[transports["SILVERMOON_UNDERCITY_TELEPORT"]] = true,
			[transports["UNDERCITY_HELLFIRE_PORTAL"]] = true,
		},
		faction = "Horde",
		type = "City",
		fishing_min = 75,
		battlepet_low = 1,
		battlepet_high = 3,
	}	
	
	zones[BZ["Ironforge"]] = {
		continent = Eastern_Kingdoms,
		instances = BZ["Gnomeregan"],
		paths = {
			[BZ["Dun Morogh"]] = true,
			[BZ["Deeprun Tram"]] = true,
			[transports["IRONFORGE_HELLFIRE_PORTAL"]] = true,
			[transports["IRONFORGE_TIRAGARDESOUND_PORTAL"]] = true,
		},
		faction = "Alliance",
		type = "City",
		fishing_min = 75,
		battlepet_low = 1,
		battlepet_high = 3,
	}

	zones[BZ["Silvermoon City"]] = {
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Eversong Woods"]] = true,
			[transports["SILVERMOON_UNDERCITY_TELEPORT"]] = true,
			[transports["SILVERMOON_HELLFIRE_PORTAL"]] = true,
			[transports["SILVERMOON_ZULDAZAR_PORTAL"]] = true,
		},
		faction = "Horde",
		type = "City",
		battlepet_low = 1,
		battlepet_high = 3,
	}
	
	
	zones[BZ["Northshire"]] = {
		low = 1,
		high = 6,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Elwynn Forest"]] = true,
		},
		faction = "Alliance",
		fishing_min = 25,
	}

	zones[BZ["Sunstrider Isle"]] = {
		low = 1,
		high = 6,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Eversong Woods"]] = true,
		},
		faction = "Horde",
		fishing_min = 25,
	}

	zones[BZ["Deathknell"]] = {
		low = 1,
		high = 6,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Tirisfal Glades"]] = true,
		},
		faction = "Horde",
		fishing_min = 25,
	}	
	
	zones[BZ["Coldridge Valley"]] = {
		low = 1,
		high = 6,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Dun Morogh"]] = true,
		},
		faction = "Alliance",
		fishing_min = 25,
	}
	
	zones[BZ["New Tinkertown"]] = {
		low = 1,
		high = 6,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Dun Morogh"]] = true,
		},
		faction = "Alliance",
		fishing_min = 25,
	}	
	
	
	
	zones[BZ["Dun Morogh"]] = {
		low = 1,
		high = 20,
		continent = Eastern_Kingdoms,
		instances = BZ["Gnomeregan"],
		paths = {
			[BZ["Wetlands"]] = true,
			[BZ["Gnomeregan"]] = true,
			[BZ["Ironforge"]] = true,
			[BZ["Loch Modan"]] = true,
			[BZ["Coldridge Valley"]] = true,
			[BZ["New Tinkertown"]] = true,
		},
		faction = "Alliance",
		fishing_min = 25,
		battlepet_low = 1,
		battlepet_high = 2,
	}	
	
	zones[BZ["Elwynn Forest"]] = {
		low = 1,
		high = 20,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Northshire"]] = true,
			[BZ["Westfall"]] = true,
			[BZ["Redridge Mountains"]] = true,
			[BZ["Stormwind City"]] = true,
			[BZ["Duskwood"]] = true,
			[BZ["Burning Steppes"]] = true,
			[transports["ELWYNNFOREST_DARKMOON_PORTAL"]] = true,
		},
		faction = "Alliance",
		fishing_min = 25,
		battlepet_low = 1,
		battlepet_high = 2,
	}	
	
	zones[BZ["Eversong Woods"]] = {
		low = 1,
		high = 20,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Silvermoon City"]] = true,
			[BZ["Ghostlands"]] = true,
			[BZ["Sunstrider Isle"]] = true,
		},
		faction = "Horde",
		fishing_min = 25,
		battlepet_low = 1,
		battlepet_high = 2,
	}	
	
	zones[BZ["Gilneas"]] = {
		low = 1,
		high = 20,
		continent = Eastern_Kingdoms,
		paths = {},  -- phased instance
		faction = "Alliance",
		fishing_min = 25,
		battlepet_low = 1,
		battlepet_high = 1,
	}	
	
	zones[BZ["Gilneas City"]] = {
		low = 1,
		high = 20,
		continent = Eastern_Kingdoms,
		paths = {},  -- phased instance
		faction = "Alliance",
		battlepet_low = 1,
		battlepet_high = 2,
	}

	zones[BZ["Ruins of Gilneas"]] = {
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Silverpine Forest"]] = true,
			[BZ["Ruins of Gilneas City"]] = true,
		},
		fishing_min = 75,
	}

	zones[BZ["Ruins of Gilneas City"]] = {
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Silverpine Forest"]] = true,
			[BZ["Ruins of Gilneas"]] = true,
		},
		fishing_min = 75,
	}
	
	zones[BZ["Tirisfal Glades"]] = {
		low = 1,
		high = 20,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Scarlet Monastery"]] = true,
			[BZ["Scarlet Halls"]] = true,
		},
		paths = {
			[BZ["Western Plaguelands"]] = true,
			[BZ["Undercity"]] = true,
			[BZ["Scarlet Monastery"]] = true,
			[BZ["Scarlet Halls"]] = true,
			[transports["UNDERCITY_GROMGOL_ZEPPELIN"]] = true,
			[transports["ORGRIMMAR_UNDERCITY_ZEPPELIN"]] = true,
			[transports["UNDERCITY_HOWLINGFJORD_ZEPPELIN"]] = true,
			[BZ["Silverpine Forest"]] = true,
			[BZ["Deathknell"]] = true,
		},
--		complexes = {
--			[BZ["Scarlet Monastery"]] = true,   -- Duplicate name with instance (thanks, Blizz)
--		},
		faction = "Horde",
		fishing_min = 25,
		battlepet_low = 1,
		battlepet_high = 2,
	}	
	
	zones[BZ["Westfall"]] = {
		low = 10,
		high = 60,
		continent = Eastern_Kingdoms,
		instances = BZ["The Deadmines"],
		paths = {
			[BZ["Duskwood"]] = true,
			[BZ["Elwynn Forest"]] = true,
			[BZ["The Deadmines"]] = true,
		},
		faction = "Alliance",
		fishing_min = 75,
		battlepet_low = 3,
		battlepet_high = 4,
	}	
	
	zones[BZ["Ghostlands"]] = {
		low = 10,
		high = 60,
		continent = Eastern_Kingdoms,
		instances = BZ["Zul'Aman"],
		paths = {
			[BZ["Eastern Plaguelands"]] = true,
			[BZ["Zul'Aman"]] = true,
			[BZ["Eversong Woods"]] = true,
		},
		faction = "Horde",
		fishing_min = 75,
		battlepet_low = 3,
		battlepet_high = 6,
	}

	zones[BZ["Loch Modan"]] = {
		low = 10,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Wetlands"]] = true,
			[BZ["Badlands"]] = true,
			[BZ["Dun Morogh"]] = true,
			[BZ["Searing Gorge"]] = not isHorde and true or nil,
		},
		faction = "Alliance",
		fishing_min = 75,
		battlepet_low = 3,
		battlepet_high = 6,
	}

	zones[BZ["Silverpine Forest"]] = {
		low = 10,
		high = 60,
		continent = Eastern_Kingdoms,
		instances = BZ["Shadowfang Keep"],
		paths = {
			[BZ["Tirisfal Glades"]] = true,
			[BZ["Hillsbrad Foothills"]] = true,
			[BZ["Shadowfang Keep"]] = true,
			[BZ["Ruins of Gilneas"]] = true,
		},
		faction = "Horde",
		fishing_min = 75,
		battlepet_low = 3,
		battlepet_high = 6,
	}

	zones[BZ["Redridge Mountains"]] = {
		low = 15,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Burning Steppes"]] = true,
			[BZ["Elwynn Forest"]] = true,
			[BZ["Duskwood"]] = true,
			[BZ["Swamp of Sorrows"]] = true,
		},
		fishing_min = 75,
		battlepet_low = 4,
		battlepet_high = 6,
	}
	
	zones[BZ["Duskwood"]] = {
		low = 20,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Redridge Mountains"]] = true,
			[BZ["Northern Stranglethorn"]] = true,
			[BZ["Westfall"]] = true,
			[BZ["Deadwind Pass"]] = true,
			[BZ["Elwynn Forest"]] = true,
		},
		fishing_min = 150,
		battlepet_low = 5,
		battlepet_high = 7,
	}	
	
	zones[BZ["Hillsbrad Foothills"]] = {
		low = 15,
		high = 60,
		continent = Eastern_Kingdoms,
		instances = BZ["Alterac Valley"],
		paths = {
			[BZ["Alterac Valley"]] = true,
			[BZ["The Hinterlands"]] = true,
			[BZ["Arathi Highlands"]] = true,
			[BZ["Silverpine Forest"]] = true,
			[BZ["Western Plaguelands"]] = true,
		},
		faction = "Horde",
		fishing_min = 150,
		battlepet_low = 6,
		battlepet_high = 7,
	}

	zones[BZ["Wetlands"]] = {
		low = 25,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Arathi Highlands"]] = true,
			[transports["MENETHIL_THERAMORE_BOAT"]] = true,
			[transports["MENETHIL_HOWLINGFJORD_BOAT"]] = true,
			[BZ["Dun Morogh"]] = true,
			[BZ["Loch Modan"]] = true,
		},
		fishing_min = 150,
		battlepet_low = 6,
		battlepet_high = 7,
	}

	zones[BZ["Arathi Highlands"]] = {
		low = 25,
		high = 60,
		continent = Eastern_Kingdoms,
		instances = BZ["Arathi Basin"],
		paths = {
			[BZ["Wetlands"]] = true,
			[BZ["Hillsbrad Foothills"]] = true,
			[BZ["Arathi Basin"]] = true,
			[BZ["The Hinterlands"]] = true,
		},
		fishing_min = 150,
		battlepet_low = 7,
		battlepet_high = 8,
	}

	zones[BZ["Stranglethorn Vale"]] = {
		low = 25,
		high = 60,
		continent = Eastern_Kingdoms,
		instances = BZ["Zul'Gurub"],
		paths = {
			[BZ["Duskwood"]] = true,
			[BZ["Zul'Gurub"]] = true,
			[transports["ORGRIMMAR_GROMGOL_ZEPPELIN"]] = true,
			[transports["UNDERCITY_GROMGOL_ZEPPELIN"]] = true,
			[transports["BOOTYBAY_RATCHET_BOAT"]] = true,
		},
		fishing_min = 150,
		battlepet_low = 7,
		battlepet_high = 10,
	}
	
	zones[BZ["Northern Stranglethorn"]] = {
		low = 25,
		high = 60,
		continent = Eastern_Kingdoms,
		instances = BZ["Zul'Gurub"],
		paths = {
			[BZ["The Cape of Stranglethorn"]] = true,
			[BZ["Duskwood"]] = true,
			[BZ["Zul'Gurub"]] = true,
			[transports["ORGRIMMAR_GROMGOL_ZEPPELIN"]] = true,
			[transports["UNDERCITY_GROMGOL_ZEPPELIN"]] = true,
		},
		fishing_min = 150,
		battlepet_low = 7,
		battlepet_high = 9,
	}

	zones[BZ["The Cape of Stranglethorn"]] = {
		low = 30,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = {
			[transports["BOOTYBAY_RATCHET_BOAT"]] = true,
			["Northern Stranglethorn"] = true,
		},
		fishing_min = 225,
		battlepet_low = 9,
		battlepet_high = 10,
	}

	zones[BZ["The Hinterlands"]] = {
		low = 30,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Hillsbrad Foothills"]] = true,
			[BZ["Western Plaguelands"]] = true,
			[BZ["Arathi Highlands"]] = true,
		},
		fishing_min = 225,
		battlepet_low = 11,
		battlepet_high = 12,
	}

	zones[BZ["Western Plaguelands"]] = {
		low = 35,
		high = 60,
		continent = Eastern_Kingdoms,
		instances = BZ["Scholomance"],
		paths = {
			[BZ["The Hinterlands"]] = true,
			[BZ["Eastern Plaguelands"]] = true,
			[BZ["Tirisfal Glades"]] = true,
			[BZ["Scholomance"]] = true,
			[BZ["Hillsbrad Foothills"]] = true,
		},
		fishing_min = 225,
		battlepet_low = 10,
		battlepet_high = 11,
	}

	zones[BZ["Eastern Plaguelands"]] = {
		low = 40,
		high = 60,
		continent = Eastern_Kingdoms,
		instances = BZ["Stratholme"],
		paths = {
			[BZ["Western Plaguelands"]] = true,
			[BZ["Stratholme"]] = true,
			[BZ["Ghostlands"]] = true,
		},
		type = "PvP Zone",
		fishing_min = 300,
		battlepet_low = 12,
		battlepet_high = 13,
	}

	zones[BZ["Badlands"]] = {
		low = 40,
		high = 60,
		continent = Eastern_Kingdoms,
		instances = BZ["Uldaman"],
		paths = {
			[BZ["Uldaman"]] = true,
			[BZ["Searing Gorge"]] = true,
			[BZ["Loch Modan"]] = true,
		},
		fishing_min = 300,
		battlepet_low = 13,
		battlepet_high = 14,
	}	
	
	zones[BZ["Searing Gorge"]] = {
		low = 40,
		high = 60,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Blackrock Depths"]] = true,
			[BZ["Blackrock Caverns"]] = true,
			[BZ["Blackwing Lair"]] = true,
			[BZ["Blackwing Descent"]] = true,
			[BZ["Molten Core"]] = true,
			[BZ["Blackrock Spire"]] = true,
			[BZ["Upper Blackrock Spire"]] = true,
		},
		paths = {
			[BZ["Blackrock Mountain"]] = true,
			[BZ["Badlands"]] = true,
			[BZ["Loch Modan"]] = not isHorde and true or nil,
		},
		complexes = {
			[BZ["Blackrock Mountain"]] = true,
		},
		fishing_min = 425,
		battlepet_low = 13,
		battlepet_high = 14,
	}	
	
	zones[BZ["Burning Steppes"]] = {
		low = 40,
		high = 60,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Blackrock Depths"]] = true,
			[BZ["Blackrock Caverns"]] = true,
			[BZ["Blackwing Lair"]] = true,
			[BZ["Blackwing Descent"]] = true,
			[BZ["Molten Core"]] = true,
			[BZ["Blackrock Spire"]] = true,
			[BZ["Upper Blackrock Spire"]] = true,
		},
		paths = {
			[BZ["Blackrock Mountain"]] = true,
			[BZ["Redridge Mountains"]] = true,
			[BZ["Elwynn Forest"]] = true,
		},
		complexes = {
			[BZ["Blackrock Mountain"]] = true,
		},
		fishing_min = 425,
		battlepet_low = 15,
		battlepet_high = 16,
	}	
	
	zones[BZ["Swamp of Sorrows"]] = {
		low = 40,
		high = 60,
		continent = Eastern_Kingdoms,
		instances = BZ["The Temple of Atal'Hakkar"],
		paths = {
			[BZ["Blasted Lands"]] = true,
			[BZ["Deadwind Pass"]] = true,
			[BZ["The Temple of Atal'Hakkar"]] = true,
			[BZ["Redridge Mountains"]] = true,
		},
		fishing_min = 425,
		battlepet_low = 14,
		battlepet_high = 15,
	}

	zones[BZ["Blasted Lands"]] = {
		low = 40,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["The Dark Portal"]] = true,
			[BZ["Swamp of Sorrows"]] = true,
		},
		fishing_min = 425,
		battlepet_low = 16,
		battlepet_high = 17,
	}

	zones[BZ["Deadwind Pass"]] = {
		low = 50,
		high = 60,
		continent = Eastern_Kingdoms,
		instances = BZ["Karazhan"],
		paths = {
			[BZ["Duskwood"]] = true,
			[BZ["Swamp of Sorrows"]] = true,
			[BZ["Karazhan"]] = true,
		},
		fishing_min = 425,
		battlepet_low = 17,
		battlepet_high = 18,
	}

	-- DK starting zone
	zones[BZ["Plaguelands: The Scarlet Enclave"]] = {
		low = 55,
		high = 58,
		continent = Eastern_Kingdoms,
		yards = 3162.5,
		x_offset = 0,
		y_offset = 0,
		texture = "ScarletEnclave",
	}

	zones[BZ["Isle of Quel'Danas"]] = {
		continent = Eastern_Kingdoms,
		low = 70,
		high = 70,
		paths = {
			[BZ["Magisters' Terrace"]] = true,
			[BZ["Sunwell Plateau"]] = true,
		},
		instances = {
			[BZ["Magisters' Terrace"]] = true,
			[BZ["Sunwell Plateau"]] = true,
		},
		fishing_min = 450,
		battlepet_low = 20,
		battlepet_high = 20,
	}
	
	zones[BZ["Vashj'ir"]] = {
		low = 80,
		high = 90,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Throne of the Tides"]] = true,
		},
		fishing_min = 575,
		battlepet_low = 22,
		battlepet_high = 23,
	}

	zones[BZ["Kelp'thar Forest"]] = {
		low = 80,
		high = 90,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Shimmering Expanse"]] = true,
		},
		fishing_min = 575,
		battlepet_low = 22,
		battlepet_high = 23,
	}

	zones[BZ["Shimmering Expanse"]] = {
		low = 80,
		high = 90,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Kelp'thar Forest"]] = true,
			[BZ["Abyssal Depths"]] = true,
		},
		fishing_min = 575,
		battlepet_low = 22,
		battlepet_high = 23,
	}

	zones[BZ["Abyssal Depths"]] = {
		low = 80,
		high = 90,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Throne of the Tides"]] = true,
		},
		paths = {
			[BZ["Shimmering Expanse"]] = true,
			[BZ["Throne of the Tides"]] = true,
		},
		fishing_min = 575,
		battlepet_low = 22,
		battlepet_high = 23,
	}	
	
	zones[BZ["Twilight Highlands"]] = {
		low = 84,
		high = 90,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Grim Batol"]] = true,
			[BZ["The Bastion of Twilight"]] = true,
			[BZ["Twin Peaks"]] = true,
		},
		paths = {
			[BZ["Wetlands"]] = true,
			[BZ["Grim Batol"]] = true,
			[BZ["Twin Peaks"]] = true,
			[transports["TWILIGHTHIGHLANDS_STORMWIND_PORTAL"]] = true,
			[transports["TWILIGHTHIGHLANDS_ORGRIMMAR_PORTAL"]] = true,
		},
		fishing_min = 650,
		battlepet_low = 23,
		battlepet_high = 24,
	}	
	
	zones[BZ["Tol Barad"]] = {
		low = 84,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Tol Barad Peninsula"]] = true,
		},
		type = "PvP Zone",
		fishing_min = 675,
		battlepet_low = 23,
		battlepet_high = 24,
	}

	zones[BZ["Tol Barad Peninsula"]] = {
		low = 84,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Tol Barad"]] = true,
			[transports["TOLBARAD_ORGRIMMAR_PORTAL"]] = true,
			[transports["TOLBARAD_STORMWIND_PORTAL"]] = true,
		},
		fishing_min = 675,
		battlepet_low = 23,
		battlepet_high = 24,
	}	
	
	zones[BZ["Amani Pass"]] = {
		continent = Eastern_Kingdoms,
	}	



	-- Kalimdor cities and zones --
	
	zones[BZ["Orgrimmar"]] = {
		continent = Kalimdor,
		instances = {
			[BZ["Ragefire Chasm"]] = true,
			[BZ["The Ring of Valor"]] = true,
		},
		paths = {
			[BZ["Durotar"]] = true,
			[BZ["Ragefire Chasm"]] = true,
			[BZ["Azshara"]] = true,
			[transports["ORGRIMMAR_UNDERCITY_ZEPPELIN"]] = true,
			[transports["ORGRIMMAR_GROMGOL_ZEPPELIN"]] = true,
			[transports["ORGRIMMAR_BOREANTUNDRA_ZEPPELIN"]] = true,
			[transports["ORGRIMMAR_THUNDERBLUFF_ZEPPELIN"]] = true,
			[transports["ORGRIMMAR_BLASTEDLANDS_PORTAL"]] = true,
			[transports["ORGRIMMAR_HELLFIRE_PORTAL"]] = true,
			[transports["ORGRIMMAR_TWILIGHTHIGHLANDS_PORTAL"]] = true,
			[transports["ORGRIMMAR_MOUNTHYJAL_PORTAL"]] = true,
			[transports["ORGRIMMAR_DEEPHOLM_PORTAL"]] = true,
			[transports["ORGRIMMAR_ULDUM_PORTAL"]] = true,
			[transports["ORGRIMMAR_VASHJIR_PORTAL"]] = true,
			[transports["ORGRIMMAR_TOLBARAD_PORTAL"]] = true,
			[transports["ORGRIMMAR_JADEFOREST_PORTAL"]] = true,
			[transports["ORGRIMMAR_DALARANBROKENISLES_PORTAL"]] = true,
			[transports["ORGRIMMAR_ZULDAZAR_PORTAL"]] = true,
		},
		faction = "Horde",
		type = "City",
		fishing_min = 75,
		battlepet_low = 1,
		battlepet_high = 1,
	}
	
	zones[BZ["Thunder Bluff"]] = {
		continent = Kalimdor,
		paths = {
			[BZ["Mulgore"]] = true,
			[transports["ORGRIMMAR_THUNDERBLUFF_ZEPPELIN"]] = true,
			[transports["THUNDERBLUFF_HELLFIRE_PORTAL"]] = true,
			[transports["THUNDERBLUFF_ZULDAZAR_PORTAL"]] = true,
		},
		faction = "Horde",
		type = "City",
		fishing_min = 75,
		battlepet_low = 1,
		battlepet_high = 2,
	}
	
	zones[BZ["The Exodar"]] = {
		continent = Kalimdor,
		paths = {
			[BZ["Azuremyst Isle"]] = true,
			[transports["EXODAR_HELLFIRE_PORTAL"]] = true,
			[transports["EXODAR_DARNASSUS_PORTAL"]] = true,
			[transports["EXODAR_TIRAGARDESOUND_PORTAL"]] = true,
		},
		faction = "Alliance",
		type = "City",
		battlepet_low = 1,
		battlepet_high = 2,
	}	
	
	zones[BZ["Darnassus"]] = {
		continent = Kalimdor,
		paths = {
			[BZ["Teldrassil"]] = true,
			[transports["DARNASSUS_HELLFIRE_PORTAL"]] = true,
			[transports["DARNASSUS_EXODAR_PORTAL"]] = true,
		},
		faction = "Alliance",
		type = "City",
		fishing_min = 75,
		battlepet_low = 1,
		battlepet_high = 2,
	}



	zones[BZ["Ammen Vale"]] = {
		low = 1,
		high = 6,
		continent = Kalimdor,
		paths = {
			[BZ["Azuremyst Isle"]] = true,
		},
		faction = "Alliance",
		fishing_min = 25,
	}
	
	zones[BZ["Valley of Trials"]] = {
		low = 1,
		high = 6,
		continent = Kalimdor,
		paths = {
			[BZ["Durotar"]] = true,
		},
		faction = "Horde",
		fishing_min = 25,
	}
	
	zones[BZ["Echo Isles"]] = {
		low = 1,
		high = 6,
		continent = Kalimdor,
		paths = {
			[BZ["Durotar"]] = true,
			[transports["ECHOISLES_ZULDAZAR_BOAT"]] = true,
		},
		faction = "Horde",
		fishing_min = 25,
	}

	zones[BZ["Camp Narache"]] = {
		low = 1,
		high = 6,
		continent = Kalimdor,
		paths = {
			[BZ["Mulgore"]] = true,
		},
		faction = "Horde",
		fishing_min = 25,
	}
	
	zones[BZ["Shadowglen"]] = {
		low = 1,
		high = 6,
		continent = Kalimdor,
		paths = {
			[BZ["Teldrassil"]] = true,
		},
		faction = "Alliance",
		fishing_min = 25,
	}	
	
	
	zones[BZ["Azuremyst Isle"]] = {
		low = 1,
		high = 20,
		continent = Kalimdor,
		paths = {
			[BZ["The Exodar"]] = true,
			[BZ["Ammen Vale"]] = true,
			[BZ["Bloodmyst Isle"]] = true,
			[transports["TELDRASSIL_AZUREMYST_BOAT"]] = true,
		},
		faction = "Alliance",
		fishing_min = 25,
		battlepet_low = 1,
		battlepet_high = 2,
	}	
	
	zones[BZ["Durotar"]] = {
		low = 1,
		high = 20,
		continent = Kalimdor,
		instances = BZ["Ragefire Chasm"],
		paths = {
			[BZ["Northern Barrens"]] = true,
			[BZ["Orgrimmar"]] = true,
			[BZ["Valley of Trials"]] = true,
			[BZ["Echo Isles"]] = true,
		},
		faction = "Horde",
		fishing_min = 25,
		battlepet_low = 1,
		battlepet_high = 2,
	}	
	
	zones[BZ["Mulgore"]] = {
		low = 1,
		high = 20,
		continent = Kalimdor,
		paths = {
			[BZ["Thunder Bluff"]] = true,
			[BZ["Southern Barrens"]] = true,
			[transports["MULGORE_DARKMOON_PORTAL"]] = true,
		},
		faction = "Horde",
		fishing_min = 25,
		battlepet_low = 1,
		battlepet_high = 2,
	}	
	
	zones[BZ["Teldrassil"]] = {
		low = 1,
		high = 20,
		continent = Kalimdor,
		paths = {
			[BZ["Darnassus"]] = true,
			[BZ["Shadowglen"]] = true,
			[transports["TELDRASSIL_AZUREMYST_BOAT"]] = true,
			[transports["TELDRASSIL_STORMWIND_BOAT"]] = true,
		},
		faction = "Alliance",
		fishing_min = 25,
		battlepet_low = 1,
		battlepet_high = 2,
	}	
	
	zones[BZ["Azshara"]] = {
		low = 10,
		high = 60,
		continent = Kalimdor,
		paths = BZ["Ashenvale"],
		paths = BZ["Orgrimmar"],
		fishing_min = 75,
		faction = "Horde",
		battlepet_low = 3,
		battlepet_high = 6,
	}	
	
	zones[BZ["Bloodmyst Isle"]] = {
		low = 10,
		high = 60,
		continent = Kalimdor,
		paths = BZ["Azuremyst Isle"],
		faction = "Alliance",
		fishing_min = 75,
		battlepet_low = 3,
		battlepet_high = 6,
	}	
	
	zones[BZ["Darkshore"]] = {
		low = 10,
		high = 60,
		continent = Kalimdor,
		paths = {
			[BZ["Ashenvale"]] = true,
		},
		faction = "Alliance",
		fishing_min = 75,
		battlepet_low = 3,
		battlepet_high = 6,
	}

	zones[BZ["Northern Barrens"]] = {
		low = 10,
		high = 60,
		continent = Kalimdor,
		instances = {
			[BZ["Wailing Caverns"]] = true,
			[BZ["Warsong Gulch"]] = isHorde and true or nil,
		},
		paths = {
			[BZ["Southern Barrens"]] = true,
			[BZ["Ashenvale"]] = true,
			[BZ["Durotar"]] = true,
			[BZ["Wailing Caverns"]] = true,
			[transports["BOOTYBAY_RATCHET_BOAT"]] = true,
			[BZ["Warsong Gulch"]] = isHorde and true or nil,
			[BZ["Stonetalon Mountains"]] = true,
		},
		faction = "Horde",
		fishing_min = 75,
		battlepet_low = 3,
		battlepet_high = 4,
	}

	zones[BZ["Ashenvale"]] = {
		low = 15,
		high = 60,
		continent = Kalimdor,
		instances = {
			[BZ["Blackfathom Deeps"]] = true,
			[BZ["Warsong Gulch"]] = not isHorde and true or nil,
		},
		paths = {
			[BZ["Azshara"]] = true,
			[BZ["Northern Barrens"]] = true,
			[BZ["Blackfathom Deeps"]] = true,
			[BZ["Warsong Gulch"]] = not isHorde and true or nil,
			[BZ["Felwood"]] = true,
			[BZ["Darkshore"]] = true,
			[BZ["Stonetalon Mountains"]] = true,
		},
		fishing_min = 150,
		battlepet_low = 4,
		battlepet_high = 6,
	}

	zones[BZ["Stonetalon Mountains"]] = {
		low = 20,
		high = 60,
		continent = Kalimdor,
		paths = {
			[BZ["Desolace"]] = true,
			[BZ["Northern Barrens"]] = true,
			[BZ["Southern Barrens"]] = true,
			[BZ["Ashenvale"]] = true,
		},
		fishing_min = 150,
		battlepet_low = 5,
		battlepet_high = 7,
	}
	
	zones[BZ["Desolace"]] = {
		low = 30,
		high = 60,
		continent = Kalimdor,
		instances = BZ["Maraudon"],
		paths = {
			[BZ["Feralas"]] = true,
			[BZ["Stonetalon Mountains"]] = true,
			[BZ["Maraudon"]] = true,
		},
		fishing_min = 225,
		battlepet_low = 7,
		battlepet_high = 9,
	}	
	
	zones[BZ["Southern Barrens"]] = {
		low = 25,
		high = 60,
		continent = Kalimdor,
		instances = {
			[BZ["Razorfen Kraul"]] = true,
		},
		paths = {
			[BZ["Northern Barrens"]] = true,
			[BZ["Thousand Needles"]] = true,
			[BZ["Razorfen Kraul"]] = true,
			[BZ["Dustwallow Marsh"]] = true,
			[BZ["Stonetalon Mountains"]] = true,
			[BZ["Mulgore"]] = true,
		},
		fishing_min = 225,
		battlepet_low = 9,
		battlepet_high = 10,
	}	
	
	zones[BZ["Dustwallow Marsh"]] = {
		low = 35,
		high = 60,
		continent = Kalimdor,
		instances = BZ["Onyxia's Lair"],
		paths = {
			[BZ["Onyxia's Lair"]] = true,
			[BZ["Southern Barrens"]] = true,
			[BZ["Thousand Needles"]] = true,
			[transports["MENETHIL_THERAMORE_BOAT"]] = true,
		},
		fishing_min = 225,
		battlepet_low = 12,
		battlepet_high = 13,
	}	
	
	zones[BZ["Feralas"]] = {
		low = 35,
		high = 60,
		continent = Kalimdor,
		instances = {
			[BZ["Dire Maul (East)"]] = true,
			[BZ["Dire Maul (North)"]] = true,
			[BZ["Dire Maul (West)"]] = true,
		},
		paths = {
			[BZ["Thousand Needles"]] = true,
			[BZ["Desolace"]] = true,
			[BZ["Dire Maul"]] = true,
		},
		complexes = {
			[BZ["Dire Maul"]] = true,
		},
		fishing_min = 225,
		battlepet_low = 11,
		battlepet_high = 12,
	}	
	
	zones[BZ["Thousand Needles"]] = {
		low = 40,
		high = 60,
		continent = Kalimdor,
		instances = {
			[BZ["Razorfen Downs"]] = true,
		},
		paths = {
			[BZ["Feralas"]] = true,
			[BZ["Southern Barrens"]] = true,
			[BZ["Tanaris"]] = true,
			[BZ["Dustwallow Marsh"]] = true,
			[BZ["Razorfen Downs"]] = true,
		},
		fishing_min = 300,
		battlepet_low = 13,
		battlepet_high = 14,
	}	
	
	zones[BZ["Felwood"]] = {
		low = 40,
		high = 60,
		continent = Kalimdor,
		paths = {
			[BZ["Winterspring"]] = true,
			[BZ["Moonglade"]] = true,
			[BZ["Ashenvale"]] = true,
		},
		fishing_min = 300,
		battlepet_low = 14,
		battlepet_high = 15,
	}	
	
	zones[BZ["Tanaris"]] = {
		low = 40,
		high = 60,
		continent = Kalimdor,
		instances = {
			[BZ["Zul'Farrak"]] = true,
			[BZ["Old Hillsbrad Foothills"]] = true,
			[BZ["The Black Morass"]] = true,
			[BZ["Hyjal Summit"]] = true,
			[BZ["The Culling of Stratholme"]] = true,
			[BZ["End Time"]] = true,
			[BZ["Hour of Twilight"]] = true,
			[BZ["Well of Eternity"]] = true,
			[BZ["Dragon Soul"]] = true,
		},
		paths = {
			[BZ["Thousand Needles"]] = true,
			[BZ["Un'Goro Crater"]] = true,
			[BZ["Zul'Farrak"]] = true,
			[BZ["Caverns of Time"]] = true,
			[BZ["Uldum"]] = true,
		},
		complexes = {
			[BZ["Caverns of Time"]] = true,
		},
		fishing_min = 300,
		battlepet_low = 13,
		battlepet_high = 14,
	}

	zones[BZ["Un'Goro Crater"]] = {
		low = 40,
		high = 60,
		continent = Kalimdor,
		paths = {
			[BZ["Silithus"]] = true,
			[BZ["Tanaris"]] = true,
		},
		fishing_min = 375,
		battlepet_low = 15,
		battlepet_high = 16,
	}

	zones[BZ["Winterspring"]] = {
		low = 40,
		high = 60,
		continent = Kalimdor,
		paths = {
			[BZ["Felwood"]] = true,
			[BZ["Moonglade"]] = true,
			[BZ["Mount Hyjal"]] = true,
		},
		fishing_min = 425,
		battlepet_low = 17,
		battlepet_high = 18,
	}	
	
	zones[BZ["Silithus"]] = {
		low = 40,
		high = 60,
		continent = Kalimdor,
		paths = {
			[BZ["Ruins of Ahn'Qiraj"]] = true,
			[BZ["Un'Goro Crater"]] = true,
			[BZ["Ahn'Qiraj: The Fallen Kingdom"]] = true,
		},
		instances = {
			[BZ["Ahn'Qiraj"]] = true,
			[BZ["Ruins of Ahn'Qiraj"]] = true,
		},
		complexes = {
			[BZ["Ahn'Qiraj: The Fallen Kingdom"]] = true,
		},
		type = "PvP Zone",
		fishing_min = 425,
		battlepet_low = 16,
		battlepet_high = 17,
	}

	zones[BZ["Moonglade"]] = {
		continent = Kalimdor,
		low = 1,
		high = 90,
		paths = {
			[BZ["Felwood"]] = true,
			[BZ["Winterspring"]] = true,
		},
		fishing_min = 300,
		battlepet_low = 15,
		battlepet_high = 16,
	}

	zones[BZ["Mount Hyjal"]] = {
		low = 80,
		high = 90,
		continent = Kalimdor,
		paths = {
			[BZ["Winterspring"]] = true,
		},
		instances = {
			[BZ["Firelands"]] = true,
		},
		fishing_min = 575,
		battlepet_low = 22,
		battlepet_high = 24,
	}

	zones[BZ["Uldum"]] = {
		low = 80,
		high = 90,
		continent = Kalimdor,
		paths = {
			[BZ["Tanaris"]] = true,
		},
		instances = {
			[BZ["Halls of Origination"]] = true,
			[BZ["Lost City of the Tol'vir"]] = true,
			[BZ["The Vortex Pinnacle"]] = true,
			[BZ["Throne of the Four Winds"]] = true,
		},
		fishing_min = 650,
		battlepet_low = 23,
		battlepet_high = 24,
	}

	zones[BZ["Molten Front"]] = {
		low = 85,
		high = 85,
		continent = Kalimdor,
		battlepet_low = 24,
		battlepet_high = 24,
	}
	
	
	
	
	-- Outland city and zones --
	
	zones[BZ["Shattrath City"]] = {
		continent = Outland,
		paths = {
			[BZ["Terokkar Forest"]] = true,
			[BZ["Nagrand"]] = true,
			[transports["SHATTRATH_QUELDANAS_PORTAL"]] = true,
			[transports["SHATTRATH_STORMWIND_PORTAL"]] = true,
			[transports["SHATTRATH_ORGRIMMAR_PORTAL"]] = true,
			},
		faction = "Sanctuary",
		type = "City",
		battlepet_low = 17,
		battlepet_high = 17,
	}
	
	
	
	zones[BZ["Hellfire Peninsula"]] = {
		low = 58,
		high = 80,
		continent = Outland,
		instances = {
			[BZ["The Blood Furnace"]] = true,
			[BZ["Hellfire Ramparts"]] = true,
			[BZ["Magtheridon's Lair"]] = true,
			[BZ["The Shattered Halls"]] = true,
		},
		paths = {
			[BZ["Zangarmarsh"]] = true,
			[BZ["The Dark Portal"]] = true,
			[BZ["Terokkar Forest"]] = true,
			[BZ["Hellfire Citadel"]] = true,
			[transports["HELLFIRE_ORGRIMMAR_PORTAL"]] = true,
			[transports["HELLFIRE_STORMWIND_PORTAL"]] = true,
		},
		complexes = {
			[BZ["Hellfire Citadel"]] = true,
		},
		type = "PvP Zone",
		fishing_min = 375,
		battlepet_low = 17,
		battlepet_high = 18,
	}	
	
	zones[BZ["Zangarmarsh"]] = {
		low = 60,
		high = 80,
		continent = Outland,
		instances = {
			[BZ["The Underbog"]] = true,
			[BZ["Serpentshrine Cavern"]] = true,
			[BZ["The Steamvault"]] = true,
			[BZ["The Slave Pens"]] = true,
		},
		paths = {
			[BZ["Coilfang Reservoir"]] = true,
			[BZ["Blade's Edge Mountains"]] = true,
			[BZ["Terokkar Forest"]] = true,
			[BZ["Nagrand"]] = true,
			[BZ["Hellfire Peninsula"]] = true,
		},
		complexes = {
			[BZ["Coilfang Reservoir"]] = true,
		},
		type = "PvP Zone",
		fishing_min = 400,
		battlepet_low = 18,
		battlepet_high = 19,
	}	
	
	zones[BZ["Terokkar Forest"]] = {
		low = 62,
		high = 80,
		continent = Outland,
		instances = {
			[BZ["Mana-Tombs"]] = true,
			[BZ["Sethekk Halls"]] = true,
			[BZ["Shadow Labyrinth"]] = true,
			[BZ["Auchenai Crypts"]] = true,
		},
		paths = {
			[BZ["Ring of Observance"]] = true,
			[BZ["Shadowmoon Valley"]] = true,
			[BZ["Zangarmarsh"]] = true,
			[BZ["Shattrath City"]] = true,
			[BZ["Hellfire Peninsula"]] = true,
			[BZ["Nagrand"]] = true,
		},
		complexes = {
			[BZ["Ring of Observance"]] = true,
		},
		type = "PvP Zone",
		fishing_min = 450,
		battlepet_low = 18,
		battlepet_high = 19,
	}

	zones[BZ["Nagrand"]] = {
		low = 64,
		high = 80,
		continent = Outland,
		instances = {
			[BZ["Nagrand Arena"]] = true,
		},
		paths = {
			[BZ["Zangarmarsh"]] = true,
			[BZ["Shattrath City"]] = true,
			[BZ["Terokkar Forest"]] = true,
		},
		type = "PvP Zone",
		fishing_min = 475,
		battlepet_low = 18,
		battlepet_high = 19,
	}

	zones[BZ["Blade's Edge Mountains"]] = {
		low = 65,
		high = 80,
		continent = Outland,
		instances =
		{
			[BZ["Gruul's Lair"]] = true,
			[BZ["Blade's Edge Arena"]] = true,
		},
		paths = {
			[BZ["Netherstorm"]] = true,
			[BZ["Zangarmarsh"]] = true,
			[BZ["Gruul's Lair"]] = true,
		},
		battlepet_low = 18,
		battlepet_high = 20,
	}

	zones[BZ["Netherstorm"]] = {
		low = 67,
		high = 80,
		continent = Outland,
		instances = {
			[BZ["The Mechanar"]] = true,
			[BZ["The Botanica"]] = true,
			[BZ["The Arcatraz"]] = true,
			[BZ["Tempest Keep"]] = true,  -- previously "The Eye"
			[BZ["Eye of the Storm"]] = true,
		},
		paths = {
--			[BZ["Tempest Keep"]] = true,
			[BZ["Blade's Edge Mountains"]] = true,
		},
--		complexes = {
--			[BZ["Tempest Keep"]] = true,
--		},
		fishing_min = 475,
		battlepet_low = 20,
		battlepet_high = 21,
	}

	zones[BZ["Shadowmoon Valley"]] = {
		low = 67,
		high = 80,
		continent = Outland,
		instances = BZ["Black Temple"],
		paths = {
			[BZ["Terokkar Forest"]] = true,
			[BZ["Black Temple"]] = true,
		},
		fishing_min = 375,
		battlepet_low = 20,
		battlepet_high = 21,
	}
	
	
	
	
	-- Northrend city and zones --
	
	zones[BZ["Dalaran"]] = {
		continent = Northrend,
		paths = {
			[BZ["The Violet Hold"]] = true,
			[transports["DALARAN_CRYSTALSONG_TELEPORT"]] = true,
			[transports["DALARAN_COT_PORTAL"]] = true,
			[transports["DALARAN_STORMWIND_PORTAL"]] = true,
			[transports["DALARAN_ORGRIMMAR_PORTAL"]] = true,
		},
		instances = {
			[BZ["The Violet Hold"]] = true,
			[BZ["Dalaran Arena"]] = true,
		},
		type = "City",
		texture = "Dalaran",
		faction = "Sanctuary",
		fishing_min = 525,
		battlepet_low = 21,
		battlepet_high = 21,
	}
	
	
	zones[BZ["Borean Tundra"]] = {
		low = 58,
		high = 80,
		continent = Northrend,
		paths = {
			[BZ["Coldarra"]] = true,
			[BZ["Dragonblight"]] = true,
			[BZ["Sholazar Basin"]] = true,
			[transports["STORMWIND_BOREANTUNDRA_BOAT"]] = true,
			[transports["ORGRIMMAR_BOREANTUNDRA_ZEPPELIN"]] = true,
			[transports["MOAKI_UNUPE_BOAT"]] = true,
		},
		instances = {
			[BZ["The Nexus"]] = true,
			[BZ["The Oculus"]] = true,
			[BZ["The Eye of Eternity"]] = true,
		},
		complexes = {
			[BZ["Coldarra"]] = true,
		},
		fishing_min = 475,
		battlepet_low = 20,
		battlepet_high = 22,
	}	
	
	zones[BZ["Howling Fjord"]] = {
		low = 58,
		high = 80,
		continent = Northrend,
		paths = {
			[BZ["Grizzly Hills"]] = true,
			[transports["MENETHIL_HOWLINGFJORD_BOAT"]] = true,
			[transports["UNDERCITY_HOWLINGFJORD_ZEPPELIN"]] = true,
			[transports["MOAKI_KAMAGUA_BOAT"]] = true,
			[BZ["Utgarde Keep"]] = true,
			[BZ["Utgarde Pinnacle"]] = true,
		},
		instances = {
			[BZ["Utgarde Keep"]] = true,
			[BZ["Utgarde Pinnacle"]] = true,
		},
		fishing_min = 475,
		battlepet_low = 20,
		battlepet_high = 22,
	}	
	
	zones[BZ["Dragonblight"]] = {
		low = 61,
		high = 80,
		continent = Northrend,
		paths = {
			[BZ["Borean Tundra"]] = true,
			[BZ["Grizzly Hills"]] = true,
			[BZ["Zul'Drak"]] = true,
			[BZ["Crystalsong Forest"]] = true,
			[transports["MOAKI_UNUPE_BOAT"]] = true,
			[transports["MOAKI_KAMAGUA_BOAT"]] = true,
			[BZ["Azjol-Nerub"]] = true,
			[BZ["Ahn'kahet: The Old Kingdom"]] = true,
			[BZ["Naxxramas"]] = true,
			[BZ["The Obsidian Sanctum"]] = true,
		},
		instances = {
			[BZ["Azjol-Nerub"]] = true,
			[BZ["Ahn'kahet: The Old Kingdom"]] = true,
			[BZ["Naxxramas"]] = true,
			[BZ["The Obsidian Sanctum"]] = true,
			[BZ["Strand of the Ancients"]] = true,
		},
		fishing_min = 475,
		battlepet_low = 22,
		battlepet_high = 23,
	}	
	
	zones[BZ["Grizzly Hills"]] = {
		low = 63,
		high = 80,
		continent = Northrend,
		paths = {
			[BZ["Howling Fjord"]] = true,
			[BZ["Dragonblight"]] = true,
			[BZ["Zul'Drak"]] = true,
			[BZ["Drak'Tharon Keep"]] = true,
		},
		instances = BZ["Drak'Tharon Keep"],
		fishing_min = 475,
		battlepet_low = 21,
		battlepet_high = 22,
	}	
	
	zones[BZ["Zul'Drak"]] = {
		low = 64,
		high = 80,
		continent = Northrend,
		paths = {
			[BZ["Dragonblight"]] = true,
			[BZ["Grizzly Hills"]] = true,
			[BZ["Crystalsong Forest"]] = true,
			[BZ["Gundrak"]] = true,
			[BZ["Drak'Tharon Keep"]] = true,
		},
		instances = {
			[BZ["Gundrak"]] = true,
			[BZ["Drak'Tharon Keep"]] = true,
		},
		fishing_min = 475,
		battlepet_low = 22,
		battlepet_high = 23,
	}

	zones[BZ["Sholazar Basin"]] = {
		low = 66,
		high = 80,
		continent = Northrend,
		paths = BZ["Borean Tundra"],
		fishing_min = 525,
		battlepet_low = 21,
		battlepet_high = 22,
	}

	zones[BZ["Icecrown"]] = {
		low = 67,
		high = 80,
		continent = Northrend,
		paths = {
			[BZ["Trial of the Champion"]] = true,
			[BZ["Trial of the Crusader"]] = true,
			[BZ["The Forge of Souls"]] = true,
			[BZ["Pit of Saron"]] = true,
			[BZ["Halls of Reflection"]] = true,
			[BZ["Icecrown Citadel"]] = true,
			[BZ["Hrothgar's Landing"]] = true,
		},
		instances = {
			[BZ["Trial of the Champion"]] = true,
			[BZ["Trial of the Crusader"]] = true,
			[BZ["The Forge of Souls"]] = true,
			[BZ["Pit of Saron"]] = true,
			[BZ["Halls of Reflection"]] = true,
			[BZ["Icecrown Citadel"]] = true,
			[BZ["Isle of Conquest"]] = true,
		},
		fishing_min = 550,
		battlepet_low = 22,
		battlepet_high = 23,
	}
	
	zones[BZ["The Storm Peaks"]] = {
		low = 67,
		high = 80,
		continent = Northrend,
		paths = {
			[BZ["Crystalsong Forest"]] = true,
			[BZ["Halls of Stone"]] = true,
			[BZ["Halls of Lightning"]] = true,
			[BZ["Ulduar"]] = true,
		},
		instances = {
			[BZ["Halls of Stone"]] = true,
			[BZ["Halls of Lightning"]] = true,
			[BZ["Ulduar"]] = true,
		},
		fishing_min = 550,
		battlepet_low = 22,
		battlepet_high = 23,
	}	
	
	zones[BZ["Crystalsong Forest"]] = {
		low = 67,
		high = 80,
		continent = Northrend,
		paths = {
			[transports["DALARAN_CRYSTALSONG_TELEPORT"]] = true,
			[BZ["Dragonblight"]] = true,
			[BZ["Zul'Drak"]] = true,
			[BZ["The Storm Peaks"]] = true,
		},
		fishing_min = 500,
		battlepet_low = 22,
		battlepet_high = 23,
	}	
	
	zones[BZ["Hrothgar's Landing"]] = {
		low = 67,
		high = 80,
		paths = BZ["Icecrown"],
		continent = Northrend,
		fishing_min = 550,
		battlepet_low = 22,
		battlepet_high = 22,
	}	
	
	zones[BZ["Wintergrasp"]] = {
		low = 67,
		high = 80,
		continent = Northrend,
		paths = BZ["Vault of Archavon"],
		instances = BZ["Vault of Archavon"],
		type = "PvP Zone",
		fishing_min = 525,
		battlepet_low = 22,
		battlepet_high = 22,
	}	

	zones[BZ["The Frozen Sea"]] = {
		continent = Northrend,
		fishing_min = 575,
	}	
	
	-- The Maelstrom zones --
	
	-- Goblin start zone
	zones[BZ["Kezan"]] = {
		low = 1,
		high = 5,
		continent = The_Maelstrom,
		faction = "Horde",
		fishing_min = 25,
		battlepet_low = 1,
		battlepet_high = 1,
	}

	-- Goblin start zone
	zones[BZ["The Lost Isles"]] = {
		low = 1,
		high = 10,
		continent = The_Maelstrom,
		faction = "Horde",
		fishing_min = 25,
		battlepet_low = 1,
		battlepet_high = 2,
	}	
	
	zones[BZ["The Maelstrom"].." (zone)"] = {
		low = 82,
		high = 90,
		continent = The_Maelstrom,
		paths = {
		},
		faction = "Sanctuary",
	}

	zones[BZ["Deepholm"]] = {
		low = 82,
		high = 90,
		continent = The_Maelstrom,
		instances = {
			[BZ["The Stonecore"]] = true,
		},
		paths = {
			[BZ["The Stonecore"]] = true,
			[transports["DEEPHOLM_ORGRIMMAR_PORTAL"]] = true,
			[transports["DEEPHOLM_STORMWIND_PORTAL"]] = true,
		},
		fishing_min = 550,
		battlepet_low = 22,
		battlepet_high = 23,
	}	
	
	zones[BZ["Darkmoon Island"]] = {
		continent = The_Maelstrom,
		fishing_min = 75,
		paths = {
			[transports["DARKMOON_MULGORE_PORTAL"]] = true,
			[transports["DARKMOON_ELWYNNFOREST_PORTAL"]] = true,
		},
		battlepet_low = 1, 
		battlepet_high = 10,
	}
	
	
	
	-- Pandaria cities and zones -- 
	
	zones[BZ["Shrine of Seven Stars"]] = {
		continent = Pandaria,
		paths = {
			[BZ["Vale of Eternal Blossoms"]] = true,
			[transports["SEVENSTARS_EXODAR_PORTAL"]] = true,
			[transports["SEVENSTARS_STORMWIND_PORTAL"]] = true,
			[transports["SEVENSTARS_IRONFORGE_PORTAL"]] = true,
			[transports["SEVENSTARS_DARNASSUS_PORTAL"]] = true,
			[transports["SEVENSTARS_SHATTRATH_PORTAL"]] = true,
			[transports["SEVENSTARS_DALARAN_PORTAL"]] = true,
		},
		faction = "Alliance",
		type = "City",
		battlepet_low = 23,
		battlepet_high = 23,
	}

	zones[BZ["Shrine of Two Moons"]] = {
		continent = Pandaria,
		paths = {
			[BZ["Vale of Eternal Blossoms"]] = true,
			[transports["TWOMOONS_ORGRIMMAR_PORTAL"]] = true,
			[transports["TWOMOONS_UNDERCITY_PORTAL"]] = true,
			[transports["TWOMOONS_THUNDERBLUFF_PORTAL"]] = true,
			[transports["TWOMOONS_SILVERMOON_PORTAL"]] = true,
			[transports["TWOMOONS_SHATTRATH_PORTAL"]] = true,
			[transports["TWOMOONS_DALARAN_PORTAL"]] = true,
		},
		faction = "Horde",
		type = "City",
		battlepet_low = 23,
		battlepet_high = 23,
	}
	
	
	zones[BZ["The Wandering Isle"]] = {
		low = 1,
		high = 10,
		continent = Pandaria,
--		fishing_min = 25,
 		faction = "Sanctuary",  -- Not contested and not Alliance nor Horde -> no PvP -> sanctuary
	}	
	
	zones[BZ["The Jade Forest"]] = {
		low = 80,
		high = 90,
		continent = Pandaria,
		instances = {
			[BZ["Temple of the Jade Serpent"]] = true,
		},
		paths = {
			[BZ["Temple of the Jade Serpent"]] = true,
			[BZ["Valley of the Four Winds"]] = true,
			[BZ["Timeless Isle"]] = true,
			[transports["JADEFOREST_ORGRIMMAR_PORTAL"]] = true,
			[transports["JADEFOREST_STORMWIND_PORTAL"]] = true,
		},
		fishing_min = 650,
		battlepet_low = 23,
		battlepet_high = 25,
	}	
	
	zones[BZ["Valley of the Four Winds"]] = {
		low = 81,
		high = 90,
		continent = Pandaria,
		instances = {
			[BZ["Stormstout Brewery"]] = true,
			[BZ["Deepwind Gorge"]] = true,
		},
		paths = {
			[BZ["Stormstout Brewery"]] = true,
			[BZ["The Jade Forest"]] = true,
			[BZ["Krasarang Wilds"]] = true,
			[BZ["The Veiled Stair"]] = true,
			[BZ["Deepwind Gorge"]] = true,
		},
		fishing_min = 700,
		battlepet_low = 23,
		battlepet_high = 25,
	}	
	
	zones[BZ["Krasarang Wilds"]] = {
		low = 81,
		high = 90,
		continent = Pandaria,
		paths = {
			[BZ["Valley of the Four Winds"]] = true,
		},
		fishing_min = 700,
		battlepet_low = 23,
		battlepet_high = 25,
	}	
	
	zones[BZ["The Veiled Stair"]] = {
		low = 87,
		high = 87,
		continent = Pandaria,
		instances = {
			[BZ["Terrace of Endless Spring"]] = true,
		},
		paths = {
			[BZ["Terrace of Endless Spring"]] = true,
			[BZ["Valley of the Four Winds"]] = true,
			[BZ["Kun-Lai Summit"]] = true,
		},
		fishing_min = 750,
		battlepet_low = 23,
		battlepet_high = 25,
	}	
	
	zones[BZ["Kun-Lai Summit"]] = {
		low = 82,
		high = 90,
		continent = Pandaria,
		instances = {
			[BZ["Shado-Pan Monastery"]] = true,
			[BZ["Mogu'shan Vaults"]] = true,
			[BZ["The Tiger's Peak"]] = true,
		},
		paths = {
			[BZ["Shado-Pan Monastery"]] = true,
			[BZ["Mogu'shan Vaults"]] = true,
			[BZ["Vale of Eternal Blossoms"]] = true,
			[BZ["The Veiled Stair"]] = true,
		},
		fishing_min = 625,
		battlepet_low = 23,
		battlepet_high = 25,
	}

	zones[BZ["Townlong Steppes"]] = {
		low = 83,
		high = 90,
		continent = Pandaria,
		instances = {
			[BZ["Siege of Niuzao Temple"]] = true,
		},
		paths = {
			[BZ["Siege of Niuzao Temple"]] = true,
			[BZ["Dread Wastes"]] = true,
			[transports["TOWNLONGSTEPPES_ISLEOFTHUNDER_PORTAL"]] = true,
		},
		fishing_min = 700,
		battlepet_low = 24,
		battlepet_high = 25,
	}

	zones[BZ["Dread Wastes"]] = {
		low = 84,
		high = 90,
		continent = Pandaria,
		instances = {
			[BZ["Gate of the Setting Sun"]] = true,
			[BZ["Heart of Fear"]] = true,
		},
		paths = {
			[BZ["Gate of the Setting Sun"]] = true,
			[BZ["Heart of Fear"]] = true,
			[BZ["Townlong Steppes"]] = true
		},
		fishing_min = 625,
		battlepet_low = 24,
		battlepet_high = 25,
	}

	zones[BZ["Vale of Eternal Blossoms"]] = {
		low = 85,
		high = 90,
		continent = Pandaria,
		instances = {
			[BZ["Mogu'shan Palace"]] = true,
			[BZ["Siege of Orgrimmar"]] = true,
		},
		paths = {
			[BZ["Mogu'shan Palace"]] = true,
			[BZ["Kun-Lai Summit"]] = true,
			[BZ["Siege of Orgrimmar"]] = true,
		},
		fishing_min = 825,
		battlepet_low = 23,
		battlepet_high = 25,
	}

	zones[BZ["Isle of Giants"]] = {
		low = 90,
		high = 90,
		continent = Pandaria,
		fishing_min = 750,
		battlepet_low = 23,
		battlepet_high = 25,
	}
	
	zones[BZ["Isle of Thunder"]] = {
		low = 85,
		high = 90,
		continent = Pandaria,
		instances = {
			[BZ["Throne of Thunder"]] = true,
		},
		paths = {
			[transports["ISLEOFTHUNDER_TOWNLONGSTEPPES_PORTAL"]] = true,
		},
		fishing_min = 750,
		battlepet_low = 23,
		battlepet_high = 25,
	}	
	
	zones[BZ["Timeless Isle"]] = {
		low = 85,
		high = 90,
		continent = Pandaria,
		paths = BZ["The Jade Forest"],
		fishing_min = 825,
		battlepet_low = 25,
		battlepet_high = 25,
	}	
	
	
	-- Draenor cities, garrisons and zones -- 
	
	zones[BZ["Warspear"]] = {
		continent = Draenor,
		paths = {
			[BZ["Ashran"]] = true,
			[transports["WARSPEAR_ORGRIMMAR_PORTAL"]] = true,
			[transports["WARSPEAR_UNDERCITY_PORTAL"]] = true,
			[transports["WARSPEAR_THUNDERBLUFF_PORTAL"]] = true,
		},
		faction = "Horde",
		type = "City",
        fishing_min = 950,
		battlepet_low = 25,
		battlepet_high = 25,
	}

	zones[BZ["Stormshield"]] = {
		continent = Draenor,
		paths = {
			[BZ["Ashran"]] = true,
			[transports["STORMSHIELD_STORMWIND_PORTAL"]] = true,
			[transports["STORMSHIELD_IRONFORGE_PORTAL"]] = true,
			[transports["STORMSHIELD_DARNASSUS_PORTAL"]] = true,
		},
		faction = "Alliance",
		type = "City",
        fishing_min = 950,
		battlepet_low = 25,
		battlepet_high = 25,
	}
	
	-- Alliance garrison
	zones[BZ["Lunarfall"]] = {
        low = 90,
        high = 100,
        continent = Draenor,
        paths = {
            [BZ["Shadowmoon Valley"].." ("..BZ["Draenor"]..")"] = true,
        },
        faction = "Alliance",
        fishing_min = 950,
		yards = 683.334,
		x_offset = 11696.5098,
		y_offset = 9101.3333,
		texture = "garrisonsmvalliance"
    }
	
	-- Horde garrison
	zones[BZ["Frostwall"]] = {
        low = 90,
        high = 100,
        continent = Draenor,
        paths = {
            [BZ["Frostfire Ridge"]] = true,
        },
        faction = "Horde",
        fishing_min = 950,
		yards = 702.08,
		x_offset = 7356.9277,
		y_offset = 5378.4173,
		texture = "garrisonffhorde"
    }

	
	
	zones[BZ["Frostfire Ridge"]] = {
		low = 90,
		high = 100,
		continent = Draenor,
		instances = {
			[BZ["Bloodmaul Slag Mines"]] = true,
		},
		paths = {
			[BZ["Gorgrond"]] = true,
			[BZ["Frostwall"]] = true,
			[transports["FROSTFIRERIDGE_ORGRIMMAR_PORTAL"]] = true,
		},
		fishing_min = 950,
		battlepet_low = 23,
		battlepet_high = 25,
	}	
	
	zones[BZ["Shadowmoon Valley"].." ("..BZ["Draenor"]..")"] = {
		low = 90,
		high = 100,
		continent = Draenor,
		instances = {
			[BZ["Shadowmoon Burial Grounds"]] = true,
		},
		paths = {
			[BZ["Talador"]] = true,
			[BZ["Spires of Arak"]] = true,
			[BZ["Tanaan Jungle"]] = true,
			[BZ["Lunarfall"]] = true,
			[transports["SHADOWMOONVALLEY_STORMWIND_PORTAL"]] = true,
		},
		fishing_min = 950,
		battlepet_low = 23,
		battlepet_high = 25,
	}	
	
	zones[BZ["Gorgrond"]] = {
		low = 92,
		high = 100,
		continent = Draenor,
		instances = {
			[BZ["Iron Docks"]] = true,
			[BZ["Grimrail Depot"]] = true,
			[BZ["The Everbloom"]] = true,
			[BZ["Blackrock Foundry"]] = true,
		},
		paths = {
			[BZ["Frostfire Ridge"]] = true,
			[BZ["Talador"]] = true,
			[BZ["Tanaan Jungle"]] = true,
		},
		fishing_min = 950,
		battlepet_low = 25,
		battlepet_high = 25,
	}	
	
	zones[BZ["Talador"]] = {
		low = 94,
		high = 100,
		continent = Draenor,
		instances = {
			[BZ["Auchindoun"]] = true,
		},
		paths = {
			[BZ["Shadowmoon Valley"].." ("..BZ["Draenor"]..")"] = true,
			[BZ["Gorgrond"]] = true,
			[BZ["Tanaan Jungle"]] = true,
			[BZ["Spires of Arak"]] = true,
			[BZ["Nagrand"].." ("..BZ["Draenor"]..")"] = true,
		},
		fishing_min = 950,
		battlepet_low = 25,
		battlepet_high = 25,
	}		
	
	zones[BZ["Spires of Arak"]] = {
		low = 96,
		high = 100,
		continent = Draenor,
		instances = {
			[BZ["Skyreach"]] = true,
			[BZ["Blackrock Foundry"]] = true,
		},
		paths = {
			[BZ["Shadowmoon Valley"].." ("..BZ["Draenor"]..")"] = true,
			[BZ["Talador"]] = true,
		},
		fishing_min = 950,
		battlepet_low = 25,
		battlepet_high = 25,
	}	
	
	zones[BZ["Nagrand"].." ("..BZ["Draenor"]..")"] = {
		low = 98,
		high = 100,
		continent = Draenor,
		instances = {
			[BZ["Highmaul"]] = true,
			[BZ["Blackrock Foundry"]] = true,
		},
		paths = {
			[BZ["Talador"]] = true,
		},
		fishing_min = 950,
		battlepet_low = 25,
		battlepet_high = 25,
	}

	zones[BZ["Tanaan Jungle"]] = {
		low = 100,
		high = 100,
		continent = Draenor,
		instances = {
			[BZ["Hellfire Citadel"].." ("..BZ["Draenor"]..")"] = true,
		},
		paths = {
			[BZ["Talador"]] = true,
			[BZ["Shadowmoon Valley"].." ("..BZ["Draenor"]..")"] = true,
			[BZ["Gorgrond"]] = true,
		},
		fishing_min = 950,
		battlepet_low = 25,
		battlepet_high = 25,
	}	
	
	zones[BZ["Ashran"]] = {
		low = 100,
		high = 100,
		continent = Draenor,
		type = "PvP Zone",
		paths = {
			[BZ["Warspear"]] = true,
			[BZ["Stormshield"]] = true,
			[transports["WARSPEAR_ORGRIMMAR_PORTAL"]] = true,
			[transports["WARSPEAR_UNDERCITY_PORTAL"]] = true,
			[transports["WARSPEAR_THUNDERBLUFF_PORTAL"]] = true,
			[transports["STORMSHIELD_STORMWIND_PORTAL"]] = true,
			[transports["STORMSHIELD_IRONFORGE_PORTAL"]] = true,
			[transports["STORMSHIELD_DARNASSUS_PORTAL"]] = true,
		},
		fishing_min = 950,
		battlepet_low = 25,
		battlepet_high = 25,
	}	
	
	
	
	-- The Broken Isles cities and zones

	zones[BZ["Dalaran"].." ("..BZ["Broken Isles"]..")"] = {
		continent = Broken_Isles,
		paths = {
			[BZ["The Violet Hold"].." ("..BZ["Broken Isles"]..")"] = true,
			[transports["DALARANBROKENISLES_STORMWIND_PORTAL"]] = true,
			[transports["DALARANBROKENISLES_EXODAR_PORTAL"]] = true,
			[transports["DALARANBROKENISLES_DARNASSUS_PORTAL"]] = true,
			[transports["DALARANBROKENISLES_IRONFORGE_PORTAL"]] = true,
			[transports["DALARANBROKENISLES_SEVENSTARS_PORTAL"]] = true,
			[transports["DALARANBROKENISLES_ORGRIMMAR_PORTAL"]] = true,
			[transports["DALARANBROKENISLES_UNDERCITY_PORTAL"]] = true,
			[transports["DALARANBROKENISLES_THUNDERBLUFF_PORTAL"]] = true,
			[transports["DALARANBROKENISLES_SILVERMOON_PORTAL"]] = true,
			[transports["DALARANBROKENISLES_TWOMOONS_PORTAL"]] = true,
			[transports["DALARANBROKENISLES_COT_PORTAL"]] = true,
			[transports["DALARANBROKENISLES_SHATTRATH_PORTAL"]] = true,
			[transports["DALARANBROKENISLES_DRAGONBLIGHT_PORTAL"]] = true,
			[transports["DALARANBROKENISLES_HILLSBRAD_PORTAL"]] = true,
			[transports["DALARANBROKENISLES_KARAZHAN_PORTAL"]] = true,
			},
		instances = {
			[BZ["The Violet Hold"].." ("..BZ["Broken Isles"]..")"] = true,
		},		
		faction = "Sanctuary",
		type = "City",
		fishing_min = 950,
		battlepet_low = 25,
		battlepet_high = 25,
	}

	zones[BZ["Thunder Totem"]] = {
		continent = Broken_Isles,
		paths = {
			[BZ["Highmountain"]] = true,
			[BZ["Stormheim"]] = true,
		},
		faction = "Sanctuary",
		type = "City",
--		fishing_min = 950,  TODO: check for fishable waters
		battlepet_low = 25,
		battlepet_high = 25,
	}


	zones[BZ["Azsuna"]] = {
		low = 98,
		high = 110,
		continent = Broken_Isles,
		instances = {
			[BZ["Vault of the Wardens"]] = true,
			[BZ["Eye of Azshara"]] = true,
		},
		paths = {
			[BZ["Suramar"]] = true,
			[BZ["Val'sharah"]] = true,
		},
		fishing_min = 950,
		battlepet_low = 25,
		battlepet_high = 25,
	}
	
	zones[BZ["Val'sharah"]] = {
		low = 98,
		high = 110,
		continent = Broken_Isles,
		instances = {
			[BZ["Black Rook Hold"]] = true,
			[BZ["Darkheart Thicket"]] = true,
			[BZ["The Emerald Nightmare"]] = true,
		},
		paths = {
			[BZ["Suramar"]] = true,
			[BZ["Azsuna"]] = true,
			[BZ["Highmountain"]] = true,
		},
		fishing_min = 950,
		battlepet_low = 25,
		battlepet_high = 25,
	}
	
	zones[BZ["Highmountain"]] = {
		low = 98,
		high = 110,
		continent = Broken_Isles,
		instances = {
			[BZ["Neltharion's Lair"]] = true,
		},
		paths = {
			[BZ["Suramar"]] = true,
			[BZ["Stormheim"]] = true,
			[BZ["Val'sharah"]] = true,
			[BZ["Trueshot Lodge"]] = true,
		},
		fishing_min = 950,
		battlepet_low = 25,
		battlepet_high = 25,
	}
	
	zones[BZ["Stormheim"]] = {
		low = 98,
		high = 110,
		continent = Broken_Isles,
		instances = {
			[BZ["Halls of Valor"]] = true,
			[BZ["Helmouth Cliffs"]] = true, 
		},
		paths = {
			[BZ["Suramar"]] = true,
			[BZ["Highmountain"]] = true,
		},
		fishing_min = 950,
		battlepet_low = 25,
		battlepet_high = 25,
	}

	zones[BZ["Broken Shore"]] = {
		low = 110,
		high = 110,
		continent = Broken_Isles,
		instances = {
			[BZ["Cathedral of Eternal Night"]] = true,
		},
		fishing_min = 950,
		battlepet_low = 25,
		battlepet_high = 25,
	}

	zones[BZ["Suramar"]] = {
		low = 110,
		high = 110,
		continent = Broken_Isles,
		instances = {
			[BZ["Court of Stars"]] = true,
			[BZ["The Arcway"]] = true,
			[BZ["The Nighthold"]] = true,		
		},
		paths = {
			[BZ["Broken Shore"]] = true,
			[BZ["Azsuna"]] = true,
			[BZ["Val'sharah"]] = true,
			[BZ["Highmountain"]] = true,
			[BZ["Stormheim"]] = true,
		},
		fishing_min = 950,
		battlepet_low = 25,
		battlepet_high = 25,
	}
	
	-- Hunter class hall. This map is reported by C_Map as a zone, unclear why
	zones[BZ["Trueshot Lodge"]] = {
		continent = Broken_Isles,
		paths = {
			[BZ["Highmountain"]] = true,
		},
		faction = "Sanctuary",
	}

	
	-- Argus zones --
	
	zones[BZ["Krokuun"]] = {
		low = 110,
		high = 110,
		continent = Argus,
	}
	
	zones[BZ["Antoran Wastes"]] = {
		low = 110,
		high = 110,
		continent = Argus,
	}
	
	zones[BZ["Mac'Aree"]] = {
		low = 110,
		high = 110,
		continent = Argus,
		instances = {
			[BZ["The Seat of the Triumvirate"]] = true,
		},
	}
	
	-- WoW BFA zones
	
	-- Zandalar cities and zones (Horde)
	
	zones[BZ["Dazar'alor"]] = {
		paths = {
			[BZ["Zuldazar"]] = true,
			[transports["ECHOISLES_ZULDAZAR_BOAT"]] = true,
			[transports["ZULDAZAR_ORGRIMMAR_PORTAL"]] = true,
			[transports["ZULDAZAR_THUNDERBLUFF_PORTAL"]] = true,
			[transports["ZULDAZAR_SILVERMOON_PORTAL"]] = true,
		},	
		faction = "Horde",
		continent = Zandalar,
		type = "City",
	}
	
	zones[BZ["Nazmir"]] = {
		low = 110,
		high = 120,
		faction = "Horde",
		continent = Zandalar,
	}
	
	zones[BZ["Vol'dun"]] = {
		low = 110,
		high = 120,
		paths = {
			[BZ["Nazmir"]] = true,
			[BZ["Zuldazar"]] = true,		
		},	
		faction = "Horde",
		continent = Zandalar,
	}
	
	zones[BZ["Zuldazar"]] = {
		low = 110,
		high = 120,
		paths = {
			[BZ["Dazar'alor"]] = true,
			[BZ["Nazmir"]] = true,
			[BZ["Vol'dun"]] = true,		
		},	
		faction = "Horde",
		continent = Zandalar,
	}
	
	-- Kul Tiras cities and zones (Alliance)
	
	zones[BZ["Boralus"]] = {
		paths = {
			[BZ["Tiragarde Sound"]] = true,
			[transports["STORMWIND_TIRAGARDESOUND_BOAT"]] = true,
			[transports["TIRAGARDESOUND_STORMWIND_PORTAL"]] = true,
			[transports["TIRAGARDESOUND_EXODAR_PORTAL"]] = true,
			[transports["TIRAGARDESOUND_IRONFORGE_PORTAL"]] = true,
		},	
		faction = "Alliance",
		continent = Kul_Tiras,
		type = "City",
	}
	
	zones[BZ["Stormsong Valley"]] = {
		low = 110,
		high = 120,
		instances = BZ["Shrine of the Storm"],
		paths = {
			[BZ["Shrine of the Storm"]] = true,
			[BZ["Tiragarde Sound"]] = true,
		},		
		faction = "Alliance",
		continent = Kul_Tiras,
	}	

	zones[BZ["Drustvar"]] = {
		low = 110,
		high = 120,
		paths = {
			[BZ["Tiragarde Sound"]] = true,
		},		
		faction = "Alliance",
		continent = Kul_Tiras,
	}
	
	zones[BZ["Tiragarde Sound"]] = {
		low = 110,
		high = 120,
		instances = BZ["Tol Dagor"],
		paths = {
			[BZ["Boralus"]] = true,
			[BZ["Drustvar"]] = true,
			[BZ["Stormsong Valley"]] = true,
			[BZ["Tol Dagor"]] = true,
		},		
		faction = "Alliance",
		continent = Kul_Tiras,
	}	
	
	
	
	
	-- Classic dungeons --
	
	zones[BZ["Ragefire Chasm"]] = {
		low = 15,
		high = 60,
		continent = Kalimdor,
		paths = BZ["Orgrimmar"],
		groupSize = 5,
		faction = "Horde",
		type = "Instance",
		entrancePortal = { BZ["Orgrimmar"], 52.8, 49 },
	}
	
	zones[BZ["The Deadmines"]] = {
		low = 15,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = BZ["Westfall"],
		groupSize = 5,
		faction = "Alliance",
		type = "Instance",
		fishing_min = 75,
		entrancePortal = { BZ["Westfall"], 42.6, 72.2 },
	}	
	
	zones[BZ["Shadowfang Keep"]] = {
		low = 17,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = BZ["Silverpine Forest"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Silverpine Forest"], 44.80, 67.83 },
	}	
	
	zones[BZ["Wailing Caverns"]] = {
		low = 15,
		high = 60,
		continent = Kalimdor,
		paths = BZ["Northern Barrens"],
		groupSize = 5,
		type = "Instance",
		fishing_min = 75,
		entrancePortal = { BZ["Northern Barrens"], 42.1, 66.5 },
	}	
	
	zones[BZ["Blackfathom Deeps"]] = {
		low = 20,
		high = 60,
		continent = Kalimdor,
		paths = BZ["Ashenvale"],
		groupSize = 5,
		type = "Instance",
		fishing_min = 75,
		entrancePortal = { BZ["Ashenvale"], 14.6, 15.3 },
	}	
	
	zones[BZ["The Stockade"]] = {
		low = 20,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = BZ["Stormwind City"],
		groupSize = 5,
		faction = "Alliance",
		type = "Instance",
		entrancePortal = { BZ["Stormwind City"], 50.5, 66.3 },
	}
	
	zones[BZ["Gnomeregan"]] = {
		low = 24,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = BZ["Dun Morogh"],
		groupSize = 5,
		faction = "Alliance",
		type = "Instance",
		entrancePortal = { BZ["Dun Morogh"], 24, 38.9 },
	}	
	
	zones[BZ["Scarlet Halls"]] = {
		low = 26,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = BZ["Tirisfal Glades"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Tirisfal Glades"], 84.9, 35.3 },
	}	
	
	zones[BZ["Scarlet Monastery"]] = {
		low = 28,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = BZ["Tirisfal Glades"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Tirisfal Glades"], 85.3, 32.1 },
	}	

	zones[BZ["Razorfen Kraul"]] = {
		low = 30,
		high = 60,
		continent = Kalimdor,
		paths = BZ["Southern Barrens"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Southern Barrens"], 40.8, 94.5 },
	}
	
	-- consists of The Wicked Grotto, Foulspore Cavern and Earth Song Falls
	zones[BZ["Maraudon"]] = {
		low = 30,
		high = 60,
		continent = Kalimdor,
		paths = BZ["Desolace"],
		groupSize = 5,
		type = "Instance",
		fishing_min = 300,
		entrancePortal = { BZ["Desolace"], 29, 62.4 },
	}	
	
	zones[BZ["Razorfen Downs"]] = {
		low = 35,
		high = 60,
		continent = Kalimdor,
		paths = BZ["Thousand Needles"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Thousand Needles"], 47.5, 23.7 },
	}	
	
	zones[BZ["Uldaman"]] = {
		low = 35,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = BZ["Badlands"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Badlands"], 42.4, 18.6 },
	}
	
	-- a.k.a. Warpwood Quarter
	zones[BZ["Dire Maul (East)"]] = {
		low = 36,
		high = 60,
		continent = Kalimdor,
		paths = BZ["Dire Maul"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Dire Maul"],
		entrancePortal = { BZ["Feralas"], 66.7, 34.8 },
	}	
	
	-- a.k.a. Capital Gardens
	zones[BZ["Dire Maul (West)"]] = {
		low = 39,
		high = 60,
		continent = Kalimdor,
		paths = BZ["Dire Maul"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Dire Maul"],
		entrancePortal = { BZ["Feralas"], 60.3, 30.6 },
	}

	-- a.k.a. Gordok Commons
	zones[BZ["Dire Maul (North)"]] = {
		low = 42,
		high = 60,
		continent = Kalimdor,
		paths = BZ["Dire Maul"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Dire Maul"],
		entrancePortal = { BZ["Feralas"], 62.5, 24.9 },
	}

	zones[BZ["Scholomance"]] = {
		low = 38,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = BZ["Western Plaguelands"],
		groupSize = 5,
		type = "Instance",
		fishing_min = 425,
		entrancePortal = { BZ["Western Plaguelands"], 69.4, 72.8 },
	}
	
	-- consists of Main Gate and Service Entrance
	zones[BZ["Stratholme"]] = {
		low = 42,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = BZ["Eastern Plaguelands"],
		groupSize = 5,
		type = "Instance",
		fishing_min = 425,
		entrancePortal = { BZ["Eastern Plaguelands"], 30.8, 14.4 },
	}	
	
	zones[BZ["Zul'Farrak"]] = {
		low = 44,
		high = 60,
		continent = Kalimdor,
		paths = BZ["Tanaris"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Tanaris"], 36, 11.7 },
	}	
	
	-- consists of Detention Block and Upper City
	zones[BZ["Blackrock Depths"]] = {
		low = 47,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Molten Core"]] = true,
			[BZ["Blackrock Mountain"]] = true,
		},
		groupSize = 5,
		type = "Instance",
		complex = BZ["Blackrock Mountain"],
		entrancePortal = { BZ["Searing Gorge"], 35.4, 84.4 },
	}	
	
	-- a.k.a. Sunken Temple
	zones[BZ["The Temple of Atal'Hakkar"]] = {
		low = 50,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = BZ["Swamp of Sorrows"],
		groupSize = 5,
		type = "Instance",
		fishing_min = 300,
		entrancePortal = { BZ["Swamp of Sorrows"], 70, 54 },
	}	
	
	-- a.k.a. Lower Blackrock Spire
	zones[BZ["Blackrock Spire"]] = {
		low = 55,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Blackrock Mountain"]] = true,
			[BZ["Blackwing Lair"]] = true,
			[BZ["Blackwing Descent"]] = true,
		},
		groupSize = 5,
		type = "Instance",
		complex = BZ["Blackrock Mountain"],
		entrancePortal = { BZ["Burning Steppes"], 29.7, 37.5 },
	}

	
	
	-- Burning Crusade dungeons (Outland) --
	
	zones[BZ["Hellfire Ramparts"]] = {
		low = 58,
		high = 80,
		continent = Outland,
		paths = BZ["Hellfire Citadel"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Hellfire Citadel"],
		entrancePortal = { BZ["Hellfire Peninsula"], 46.8, 54.9 },
	}	

	zones[BZ["The Blood Furnace"]] = {
		low = 59,
		high = 80,
		continent = Outland,
		paths = BZ["Hellfire Citadel"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Hellfire Citadel"],
		entrancePortal = { BZ["Hellfire Peninsula"], 46.8, 54.9 },
	}
	
	zones[BZ["The Slave Pens"]] = {
		low = 60,
		high = 80,
		continent = Outland,
		paths = BZ["Coilfang Reservoir"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Coilfang Reservoir"],
		entrancePortal = { BZ["Zangarmarsh"], 50.2, 40.8 },
	}	
	
	zones[BZ["The Underbog"]] = {
		low = 61,
		high = 80,
		continent = Outland,
		paths = BZ["Coilfang Reservoir"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Coilfang Reservoir"],
		entrancePortal = { BZ["Zangarmarsh"], 50.2, 40.8 },
	}

	zones[BZ["Mana-Tombs"]] = {
		low = 62,
		high = 80,
		continent = Outland,
		paths = BZ["Ring of Observance"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Ring of Observance"],
		entrancePortal = { BZ["Terokkar Forest"], 39.6, 65.5 },
	}

	zones[BZ["Auchenai Crypts"]] = {
		low = 63,
		high = 80,
		continent = Outland,
		paths = BZ["Ring of Observance"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Ring of Observance"],
		entrancePortal = { BZ["Terokkar Forest"], 39.6, 65.5 },
	}
	
	-- a.k.a. The Escape from Durnhold Keep
	zones[BZ["Old Hillsbrad Foothills"]] = {
		low = 64,
		high = 80,
		continent = Kalimdor,
		paths = BZ["Caverns of Time"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Caverns of Time"], 26.7, 32.6 },
	}

	zones[BZ["Sethekk Halls"]] = {
		low = 65,
		high = 80,
		continent = Outland,
		paths = BZ["Ring of Observance"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Ring of Observance"],
		entrancePortal = { BZ["Terokkar Forest"], 39.6, 65.5 },
	}
	
	zones[BZ["Shadow Labyrinth"]] = {
		low = 67,
		high = 80,
		continent = Outland,
		paths = BZ["Ring of Observance"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Ring of Observance"],
		entrancePortal = { BZ["Terokkar Forest"], 39.6, 65.5 },
	}

	zones[BZ["The Shattered Halls"]] = {
		low = 67,
		high = 80,
		continent = Outland,
		paths = BZ["Hellfire Citadel"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Hellfire Citadel"],
		entrancePortal = { BZ["Hellfire Peninsula"], 46.8, 54.9 },
	}

	zones[BZ["The Steamvault"]] = {
		low = 67,
		high = 80,
		continent = Outland,
		paths = BZ["Coilfang Reservoir"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Coilfang Reservoir"],
		entrancePortal = { BZ["Zangarmarsh"], 50.2, 40.8 },
	}

	zones[BZ["The Mechanar"]] = {
		low = 67,
		high = 80,
		continent = Outland,
--		paths = BZ["Tempest Keep"],
		paths = BZ["Netherstorm"],
		groupSize = 5,
		type = "Instance",
--		complex = BZ["Tempest Keep"],
		entrancePortal = { BZ["Netherstorm"], 76.5, 65.1 },
	}

	zones[BZ["The Botanica"]] = {
		low = 67,
		high = 80,
		continent = Outland,
--		paths = BZ["Tempest Keep"],
		paths = BZ["Netherstorm"],
		groupSize = 5,
		type = "Instance",
--		complex = BZ["Tempest Keep"],
		entrancePortal = { BZ["Netherstorm"], 76.5, 65.1 },
	}
	
	zones[BZ["The Arcatraz"]] = {
		low = 68,
		high = 80,
		continent = Outland,
--		paths = BZ["Tempest Keep"],
		paths = BZ["Netherstorm"],
		groupSize = 5,
		type = "Instance",
--		complex = BZ["Tempest Keep"],
		entrancePortal = { BZ["Netherstorm"], 76.5, 65.1 },
	}
	
	
	-- Wrath of the Lich King dungeons (Northrend) --
	
	zones[BZ["Utgarde Keep"]] = {
		low = 58,
		high = 80,
		continent = Northrend,
		paths = BZ["Howling Fjord"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Howling Fjord"], 57.30, 46.84 },
	}	
	
	zones[BZ["The Nexus"]] = {
		low = 59,
		high = 80,
		continent = Northrend,
		paths = BZ["Coldarra"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Coldarra"],
		entrancePortal = { BZ["Borean Tundra"], 27.50, 26.03 },
	}	
	
	zones[BZ["Azjol-Nerub"]] = {
		low = 60,
		high = 80,
		continent = Northrend,
		paths = BZ["Dragonblight"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Dragonblight"], 26.01, 50.83 },
	}	
	
	zones[BZ["Ahn'kahet: The Old Kingdom"]] = {
		low = 61,
		high = 80,
		continent = Northrend,
		paths = BZ["Dragonblight"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Dragonblight"], 28.49, 51.73 },
	}	
	
	zones[BZ["Drak'Tharon Keep"]] = {
		low = 62,
		high = 80,
		continent = Northrend,
		paths = {
			[BZ["Grizzly Hills"]] = true,
			[BZ["Zul'Drak"]] = true,
		},
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Zul'Drak"], 28.53, 86.93 },
	}	
	
	zones[BZ["The Violet Hold"]] = {
		low = 63,
		high = 80,
		continent = Northrend,
		paths = BZ["Dalaran"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Dalaran"], 66.78, 68.19 },
	}
	
	zones[BZ["Gundrak"]] = {
		low = 64,
		high = 80,
		continent = Northrend,
		paths = BZ["Zul'Drak"],
		groupSize = 5,
		type = "Instance",
		fishing_min = 475,
		entrancePortal = { BZ["Zul'Drak"], 76.14, 21.00 },
	}	
	
	zones[BZ["Halls of Stone"]] = {
		low = 65,
		high = 80,
		continent = Northrend,
		paths = BZ["The Storm Peaks"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["The Storm Peaks"], 39.52, 26.91 },
	}	
	
	zones[BZ["Halls of Lightning"]] = {
		low = 67,
		high = 80,
		continent = Northrend,
		paths = BZ["The Storm Peaks"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["The Storm Peaks"], 45.38, 21.37 },
	}	
	
	zones[BZ["The Oculus"]] = {
		low = 67,
		high = 80,
		continent = Northrend,
		paths = BZ["Coldarra"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Coldarra"],
		entrancePortal = { BZ["Borean Tundra"], 27.52, 26.67 },
	}	
	
	zones[BZ["Utgarde Pinnacle"]] = {
		low = 67,
		high = 80,
		continent = Northrend,
		paths = BZ["Howling Fjord"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Howling Fjord"], 57.25, 46.60 },
	}
	
	zones[BZ["The Culling of Stratholme"]] = {
		low = 68,
		high = 80,
		continent = Kalimdor,
		paths = BZ["Caverns of Time"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Caverns of Time"], 60.3, 82.8 },
	}	
	
	zones[BZ["Magisters' Terrace"]] = {
		low = 68,
		high = 80,
		continent = Eastern_Kingdoms,
		paths = BZ["Isle of Quel'Danas"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Isle of Quel'Danas"], 61.3, 30.9 },
	}
	
	-- a.k.a. The Opening of the Black Portal
	zones[BZ["The Black Morass"]] = {
		low = 68,
		high = 75,
		continent = Kalimdor,
		paths = BZ["Caverns of Time"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Caverns of Time"], 34.4, 84.9 },
	}	
	
	zones[BZ["Trial of the Champion"]] = {
		low = 68,
		high = 80,
		continent = Northrend,
		paths = BZ["Icecrown"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Icecrown"], 74.18, 20.45 },
	}	
	
	zones[BZ["The Forge of Souls"]] = {
		low = 70,
		high = 80,
		continent = Northrend,
		paths = BZ["Icecrown"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Icecrown"], 52.60, 89.35 },
	}	
	
	zones[BZ["Halls of Reflection"]] = {
		low = 70,
		high = 80,
		continent = Northrend,
		paths = BZ["Icecrown"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Icecrown"], 52.60, 89.35 },
	}	
	
	zones[BZ["Pit of Saron"]] = {
		low = 70,
		high = 80,
		continent = Northrend,
		paths = BZ["Icecrown"],
		groupSize = 5,
		type = "Instance",
		fishing_min = 550,
		entrancePortal = { BZ["Icecrown"], 52.60, 89.35 },
	}	
	
	
	-- Cataclysm dungeons --
	
	zones[BZ["Blackrock Caverns"]] = {
		low = 80,
		high = 90,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Blackrock Mountain"]] = true,
		},
		groupSize = 5,
		type = "Instance",
		complex = BZ["Blackrock Mountain"],
		entrancePortal = { BZ["Searing Gorge"], 47.8, 69.1 },
	}	
	
	zones[BZ["Throne of the Tides"]] = {
		low = 80,
		high = 90,
		continent = Eastern_Kingdoms,
		paths = BZ["Abyssal Depths"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Abyssal Depths"], 69.3, 25.2 },
	}	
	
	zones[BZ["The Stonecore"]] = {
		low = 81,
		high = 90,
		continent = The_Maelstrom,
		paths = BZ["Deepholm"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Deepholm"], 47.70, 51.96 },
	}	
	
	zones[BZ["The Vortex Pinnacle"]] = {
		low = 81,
		high = 90,
		continent = Kalimdor,
		paths = BZ["Uldum"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Uldum"], 76.79, 84.51 },
	}
	
	zones[BZ["Lost City of the Tol'vir"]] = {
		low = 84,
		high = 90,
		continent = Kalimdor,
		paths = BZ["Uldum"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Uldum"], 60.53, 64.24 },
	}
	
	zones[BZ["Grim Batol"]] = {
		low = 84,
		high = 90,
		continent = Eastern_Kingdoms,
		paths = BZ["Twilight Highlands"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Twilight Highlands"], 19, 53.5 },
	}	
	
	-- TODO: confirm level range
	zones[BZ["Halls of Origination"]] = {
		low = 85,
		high = 85,
		continent = Kalimdor,
		paths = BZ["Uldum"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Uldum"], 69.09, 52.95 },
	}
	
	-- TODO: confirm level range
	zones[BZ["End Time"]] = {
		low = 84,
		high = 90,
		continent = Kalimdor,
		paths = BZ["Caverns of Time"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Caverns of Time"], 57.1, 25.7 },
	}

	-- TODO: confirm level range
	zones[BZ["Hour of Twilight"]] = {
		low = 84,
		high = 90,
		continent = Kalimdor,
		paths = BZ["Caverns of Time"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Caverns of Time"], 67.9, 29.0 },
	}

	-- TODO: confirm level range
	zones[BZ["Well of Eternity"]] = {
		low = 84,
		high = 90,
		continent = Kalimdor,
		paths = BZ["Caverns of Time"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Caverns of Time"], 22.2, 63.6 },
	}
	
	-- Note: before Cataclysm, this was a lvl 70 10-man raid
	zones[BZ["Zul'Aman"]] = {
		low = 85,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = BZ["Ghostlands"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Ghostlands"], 77.7, 63.2 },
		fishing_min = 425,
	}	

	-- Note: before Cataclysm, this was a lvl 60 20-man raid
	zones[BZ["Zul'Gurub"]] = {
		low = 85,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = BZ["Northern Stranglethorn"],
		groupSize = 5,
		type = "Instance",
--		fishing_min = 330,
		entrancePortal = { BZ["Northern Stranglethorn"], 52.2, 17.1 },
	}


	
	-- Mists of Pandaria dungeons --
	
	zones[BZ["Temple of the Jade Serpent"]] = {
		low = 80,
		high = 90,
		continent = Pandaria,
		paths = BZ["The Jade Forest"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["The Jade Forest"], 56.20, 57.90 },
	}	
	
	zones[BZ["Stormstout Brewery"]] = {
		low = 80,
		high = 90,
		continent = Pandaria,
		paths = BZ["Valley of the Four Winds"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Valley of the Four Winds"], 36.10, 69.10 }, 
	}	
	
	zones[BZ["Shado-Pan Monastery"]] = {
		low = 82,
		high = 90,
		continent = Pandaria,
		paths = BZ["Kun-Lai Summit"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Kun-Lai Summit"], 36.7, 47.6 },  
	}	
	
	zones[BZ["Mogu'shan Palace"]] = {
		low = 82,
		high = 90,
		continent = Pandaria,
		paths = BZ["Vale of Eternal Blossoms"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Vale of Eternal Blossoms"], 80.7, 33.0 }, 
	}	
	
	zones[BZ["Gate of the Setting Sun"]] = {
		low = 83,
		high = 90,
		continent = Pandaria,
		paths = BZ["Dread Wastes"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Dread Wastes"], 15.80, 74.30 }, 
	}	
	
	zones[BZ["Siege of Niuzao Temple"]] = {
		low = 83,
		high = 90,
		continent = Pandaria,
		paths = BZ["Townlong Steppes"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Townlong Steppes"], 34.5, 81.1 },
	}	
	


	-- Warlords of Draenor dungeons --

	zones[BZ["Bloodmaul Slag Mines"]] = {
		low = 90,
		high = 100,
		continent = Draenor,
		paths = BZ["Forstfire Ridge"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Forstfire Ridge"], 50.0, 24.8 }, 
	}
	
	zones[BZ["Iron Docks"]] = {
		low = 92,
		high = 100,
		continent = Draenor,
		paths = BZ["Gorgrond"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Gorgrond"], 45.2, 13.7 },
	}		
	
	zones[BZ["Auchindoun"]] = {
		low = 94,
		high = 100,
		continent = Draenor,
		paths = BZ["Talador"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Talador"], 43.6, 74.1 },
	}	
	
	zones[BZ["Skyreach"]] = {
		low = 97,
		high = 100,
		continent = Draenor,
		paths = BZ["Spires of Arak"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Spires of Arak"], 35.6, 33.5 }, 
	}

	zones[BZ["Shadowmoon Burial Grounds"]] = {
		low = 100,
		high = 100,
		continent = Draenor,
		paths = BZ["Shadowmoon Valley"].." ("..BZ["Draenor"]..")",
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Shadowmoon Valley"].." ("..BZ["Draenor"]..")", 31.9, 42.5 },
	}
	
	zones[BZ["Grimrail Depot"]] = {
		low = 100,
		high = 100,
		continent = Draenor,
		paths = BZ["Gorgrond"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Gorgrond"], 55.2, 32.1 },
	}	
	
	zones[BZ["The Everbloom"]] = {
		low = 100,
		high = 100,
		continent = Draenor,
		paths = BZ["Gorgrond"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Gorgrond"], 59.5, 45.3 },
	}

	zones[BZ["Upper Blackrock Spire"]] = {
		low = 100,
		high = 100,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Blackrock Mountain"]] = true,
		},
		groupSize = 5,
		type = "Instance",
		complex = BZ["Blackrock Mountain"],
		entrancePortal = { BZ["Burning Steppes"], 29.7, 37.5 },
	}
	
	
	-- Legion dungeons --
	
	zones[BZ["Eye of Azshara"]] = {
		low = 98,
		high = 110,
		continent = Broken_Isles,
		paths = BZ["Aszuna"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Aszuna"], 67.1, 41.1 }, 
	}

	zones[BZ["Darkheart Thicket"]] = {
		low = 98,
		high = 110,
		continent = Broken_Isles,
		paths = BZ["Val'sharah"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Val'sharah"], 59.2, 31.5 }, 
	}

	zones[BZ["Neltharion's Lair"]] = {
		low = 98,
		high = 110,
		continent = Broken_Isles,
		paths = BZ["Highmountain"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Highmountain"], 49.9, 63.6 }, 
	}

	zones[BZ["Halls of Valor"]] = {
		low = 98,
		high = 110,
		continent = Broken_Isles,
		paths = BZ["Stormheim"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Stormheim"], 68.3, 66.2 }, 
	}	

	zones[BZ["The Violet Hold"].." ("..BZ["Broken Isles"]..")"] = {
		low = 105,
		high = 110,
		continent = Broken_Isles,
		paths = {
			[BZ["Dalaran"].." ("..BZ["Broken Isles"]..")"] = true,
		},
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Dalaran"].." ("..BZ["Broken Isles"]..")", 66.78, 68.19 },
	}
	
	zones[BZ["Helmouth Cliffs"]] = {
		low = 110,
		high = 110,
		continent = Broken_Isles,
		paths = BZ["Stormheim"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Stormheim"], 53.0, 47.2 }, 
	}	
	
	zones[BZ["Court of Stars"]] = {
		low = 110,
		high = 110,
		continent = Broken_Isles,
		paths = BZ["Suramar"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Suramar"], 50.7, 65.5 }, 
	}		
	
	zones[BZ["The Arcway"]] = {
		low = 110,
		high = 110,
		continent = Broken_Isles,
		paths = BZ["Suramar"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Suramar"], 43, 62 }, 
	}		
	
	zones[BZ["Cathedral of Eternal Night"]] = {
		low = 110,
		high = 110,
		continent = Broken_Isles,
		paths = BZ["Broken Shore"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Broken Shore"], 63, 18 },
	}	
	
	zones[BZ["The Seat of the Triumvirate"]] = {
		low = 110,
		high = 110,
		continent = Argus,
		paths = BZ["Mac'Aree"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Mac'Aree"], 22.3, 56.1 }, 
	}	

	zones[BZ["Black Rook Hold"]] = {
		low = 110,
		high = 110,
		continent = Broken_Isles,
		paths = BZ["Val'sharah"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Val'sharah"], 38.7, 53.2 }, 
	}	
	
	zones[BZ["Vault of the Wardens"]] = {
		low = 110,
		high = 110,
		continent = Broken_Isles,
		paths = BZ["Aszuna"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Aszuna"], 48.2, 82.7 }, 
	}	
	
	
	
	-- WoW BFA dungeons
	
	zones[BZ["Shrine of the Storm"]] = {
		low = 110,  -- TODO: Check
		high = 120,
		continent = Kul_Tiras,
		paths = BZ["Stormsong Valley"],
		groupSize = 5,
		type = "Instance",
--		entrancePortal = { BZ["Stormsong Valley"], 0.0, 0.0 }, -- TODO: Check
	}

	zones[BZ["Tol Dagor"]] = {
		low = 110,  -- TODO: Check
		high = 120,
		continent = Kul_Tiras,
		paths = BZ["Tiragarde Sound"],
		groupSize = 5,
		type = "Instance",
--		entrancePortal = { BZ["Tiragarde Sound"], 0.0, 0.0 }, -- TODO: Check
	}		
	
	zones[BZ["The MOTHERLODE!!"]] = {
		low = 110,  -- TODO: Check
		high = 120,
		continent = The_Maelstrom,
		groupSize = 5,
		type = "Instance",
--		entrancePortal = { BZ["???"], 0.0, 0.0 }, -- TODO: Check. Kezan??
	}		
	
	
	
	
	-- Raids --
	
	zones[BZ["Blackwing Lair"]] = {
		low = 60,
		high = 62,
		continent = Eastern_Kingdoms,
		paths = BZ["Blackrock Mountain"],
		groupSize = 40,
		type = "Instance",
		complex = BZ["Blackrock Mountain"],
		entrancePortal = { BZ["Burning Steppes"], 29.7, 37.5 },
	}

	zones[BZ["Molten Core"]] = {
		low = 60,
		high = 62,
		continent = Eastern_Kingdoms,
		paths = BZ["Blackrock Mountain"],
		groupSize = 40,
		type = "Instance",
		complex = BZ["Blackrock Mountain"],
		fishing_min = 1,  -- lava
		entrancePortal = { BZ["Searing Gorge"], 35.4, 84.4 },
	}

	zones[BZ["Ahn'Qiraj"]] = {
		low = 60,
		high = 63,
		continent = Kalimdor,
		paths = BZ["Ahn'Qiraj: The Fallen Kingdom"],
		groupSize = 40,
		type = "Instance",
		complex = BZ["Ahn'Qiraj: The Fallen Kingdom"],
		entrancePortal = { BZ["Ahn'Qiraj: The Fallen Kingdom"], 46.6, 7.4 },
	}
	
	zones[BZ["Ruins of Ahn'Qiraj"]] = {
		low = 60,
		high = 63,
		continent = Kalimdor,
		paths = BZ["Ahn'Qiraj: The Fallen Kingdom"],
		groupSize = 20,
		type = "Instance",
		complex = BZ["Ahn'Qiraj: The Fallen Kingdom"],
		entrancePortal = { BZ["Ahn'Qiraj: The Fallen Kingdom"], 58.9, 14.3 },
	}	
	
	
	zones[BZ["Karazhan"]] = {
		low = 70,
		high = 72,
		continent = Eastern_Kingdoms,
		paths = BZ["Deadwind Pass"],
		groupSize = 10,
		type = "Instance",
		entrancePortal = { BZ["Deadwind Pass"], 40.9, 73.2 },
	}	
	
	-- a.k.a. The Battle for Mount Hyjal
	zones[BZ["Hyjal Summit"]] = {
		low = 70,
		high = 72,
		continent = Kalimdor,
		paths = BZ["Caverns of Time"],
		groupSize = 25,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Caverns of Time"], 38.8, 16.6 },
	}

	zones[BZ["Black Temple"]] = {
		low = 70,
		high = 72,
		continent = Outland,
		paths = BZ["Shadowmoon Valley"],
		groupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Shadowmoon Valley"], 77.7, 43.7 },
	}

	zones[BZ["Magtheridon's Lair"]] = {
		low = 70,
		high = 72,
		continent = Outland,
		paths = BZ["Hellfire Citadel"],
		groupSize = 25,
		type = "Instance",
		complex = BZ["Hellfire Citadel"],
		entrancePortal = { BZ["Hellfire Peninsula"], 46.8, 54.9 },
	}

	zones[BZ["Serpentshrine Cavern"]] = {
		low = 70,
		high = 72,
		continent = Outland,
		paths = BZ["Coilfang Reservoir"],
		groupSize = 25,
		type = "Instance",
		complex = BZ["Coilfang Reservoir"],
		entrancePortal = { BZ["Zangarmarsh"], 50.2, 40.8 },
	}

	zones[BZ["Gruul's Lair"]] = {
		low = 70,
		high = 72,
		continent = Outland,
		paths = BZ["Blade's Edge Mountains"],
		groupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Blade's Edge Mountains"], 68, 24 },
	}

	zones[BZ["Tempest Keep"]] = {
		low = 70,
		high = 72,
		continent = Outland,
--		paths = BZ["Tempest Keep"],
		paths = BZ["Netherstorm"],
		groupSize = 25,
		type = "Instance",
--		complex = BZ["Tempest Keep"],
		entrancePortal = { BZ["Netherstorm"], 76.5, 65.1 },
	}
	
	zones[BZ["Sunwell Plateau"]] = {
		low = 70,
		high = 72,
		continent = Eastern_Kingdoms,
		paths = BZ["Isle of Quel'Danas"],
		groupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Isle of Quel'Danas"], 44.3, 45.7 },
	}


	zones[BZ["The Eye of Eternity"]] = {
		low = 80,
		high = 80,
		continent = Northrend,
		paths = BZ["Coldarra"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		complex = BZ["Coldarra"],
		entrancePortal = { BZ["Borean Tundra"], 27.54, 26.68 },
	}
	
	zones[BZ["Onyxia's Lair"]] = {
		low = 80,
		high = 80,
		continent = Kalimdor,
		paths = BZ["Dustwallow Marsh"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Dustwallow Marsh"], 52, 76 },
	}	

	zones[BZ["Naxxramas"]] = {
		low = 80,
		high = 80,
		continent = Northrend,
		paths = BZ["Dragonblight"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		fishing_min = 1,  -- acid
		entrancePortal = { BZ["Dragonblight"], 87.30, 51.00 },
	}

	zones[BZ["The Obsidian Sanctum"]] = {
		low = 80,
		high = 80,
		continent = Northrend,
		paths = BZ["Dragonblight"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		fishing_min = 1,  -- lava
		entrancePortal = { BZ["Dragonblight"], 60.00, 57.00 },
	}	
	
	zones[BZ["Ulduar"]] = {
		low = 80,
		high = 80,
		continent = Northrend,
		paths = BZ["The Storm Peaks"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["The Storm Peaks"], 41.56, 17.76 },
		fishing_min = 550,
	}

	zones[BZ["Trial of the Crusader"]] = {
		low = 80,
		high = 80,
		continent = Northrend,
		paths = BZ["Icecrown"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Icecrown"], 75.07, 21.80 },
	}

	zones[BZ["Icecrown Citadel"]] = {
		low = 80,
		high = 80,
		continent = Northrend,
		paths = BZ["Icecrown"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Icecrown"], 53.86, 87.27 },
	}

	zones[BZ["Vault of Archavon"]] = {
		low = 80,
		high = 80,
		continent = Northrend,
		paths = BZ["Wintergrasp"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Wintergrasp"], 50, 11.2 },
	}

	zones[BZ["The Ruby Sanctum"]] = {
		low = 80,
		high = 80,
		continent = Northrend,
		paths = BZ["Dragonblight"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		fishing_min = 650,
		entrancePortal = { BZ["Dragonblight"], 61.00, 53.00 },
	}	
	

	zones[BZ["Firelands"]] = {
		low = 85,
		high = 85,
		continent = Kalimdor,
		paths = BZ["Mount Hyjal"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Mount Hyjal"], 47.3, 78.3 },
	}
	
	zones[BZ["Throne of the Four Winds"]] = {
		low = 85,
		high = 85,
		continent = Kalimdor,
		paths = BZ["Uldum"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Uldum"], 38.26, 80.66 },
	}	

	zones[BZ["Blackwing Descent"]] = {
		low = 85,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Burning Steppes"]] = true,
			[BZ["Blackrock Mountain"]] = true,
			[BZ["Blackrock Spire"]] = true,
		},
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		complex = BZ["Blackrock Mountain"],
		entrancePortal = { BZ["Burning Steppes"], 26.1, 24.6 },
	}
	
	zones[BZ["The Bastion of Twilight"]] = {
		low = 85,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = BZ["Twilight Highlands"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Twilight Highlands"], 33.8, 78.2 },
	}	
	
	zones[BZ["Dragon Soul"]] = {
		low = 85,
		high = 85,
		continent = Kalimdor,
		paths = BZ["Caverns of Time"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Caverns of Time"], 60.0, 21.1 },
	}	


	zones[BZ["Mogu'shan Vaults"]] = {
		low = 90,
		high = 90,
		continent = Pandaria,
		paths = BZ["Kun-Lai Summit"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Kun-Lai Summit"], 59.1, 39.8 }, 
	}

	zones[BZ["Heart of Fear"]] = {
		low = 90,
		high = 90,
		continent = Pandaria,
		paths = BZ["Dread Wastes"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Dread Wastes"], 39.0, 35.0 }, 
	}

	zones[BZ["Terrace of Endless Spring"]] = {
		low = 90,
		high = 90,
		continent = Pandaria,
		paths = BZ["The Veiled Stair"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["The Veiled Stair"], 47.9, 60.8 }, 
	}

	zones[BZ["Throne of Thunder"]] = {
		low = 90,
		high = 90,
		continent = Pandaria,
		paths = BZ["Isle of Thunder"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["The Veiled Stair"], 63.5, 32.2 }, 
	}

	zones[BZ["Siege of Orgrimmar"]] = {
		low = 90,
		high = 90,
		continent = Pandaria,
		paths = BZ["Vale of Eternal Blossoms"],
		groupMinSize = 10,
		groupMaxSize = 30,
		type = "Instance",
		entrancePortal = { BZ["Vale of Eternal Blossoms"], 74.0, 42.2 },
	}
	
	
	
	zones[BZ["Blackrock Foundry"]] = {
		low = 100,
		high = 100,
		continent = Draenor,
		paths = BZ["Gorgrond"],
		groupMinSize = 10,
		groupMaxSize = 30,
		type = "Instance",
		entrancePortal = { BZ["Gorgrond"], 51.5, 27.4 },
	}	
	
	zones[BZ["Highmaul"]] = {
		low = 100,
		high = 100,
		continent = Draenor,
		paths = BZ["Nagrand"].." ("..BZ["Draenor"]..")",
		groupMinSize = 10,
		groupMaxSize = 30,
		type = "Instance",
		entrancePortal = { BZ["Nagrand"].." ("..BZ["Draenor"]..")", 34, 38 },
	}
	
	zones[BZ["Hellfire Citadel"].." ("..BZ["Draenor"]..")"] = {
		low = 100,
		high = 100,
		continent = Draenor,
		paths = BZ["Tanaan Jungle"],
		groupMinSize = 10,
		groupMaxSize = 30,
		type = "Instance",
		entrancePortal = { BZ["Tanaan Jungle"], 45, 53 },
	}

	zones[BZ["The Emerald Nightmare"]] = {
		low = 110,
		high = 110,
		continent = Broken_Isles,
		paths = BZ["Val'sharah"],
		groupMinSize = 10,
		groupMaxSize = 30,
		type = "Instance",
		entrancePortal = { BZ["Val'sharah"], 57.1, 39.9 }, 
	}
	
	zones[BZ["The Nighthold"]] = {
		low = 110,
		high = 110,
		continent = Broken_Isles,
		paths = BZ["Suramar"],
		groupMinSize = 10,
		groupMaxSize = 30,
		type = "Instance",
		entrancePortal = { BZ["Suramar"], 43, 62 }, 
	}
	
	zones[BZ["Antorus, the Burning Throne"]] = {
		low = 110,
		high = 110,
		continent = Argus,
		paths = BZ["Antoran Wastes"],
		groupMinSize = 10,
		groupMaxSize = 30,
		type = "Instance",
		--entrancePortal = { BZ["Antoran Wastes"], 0, 0 }, TODO
	}

	
	
	-- Battlegrounds --
	
	zones[BZ["Arathi Basin"]] = {
		low = 10,
		high = MAX_PLAYER_LEVEL,
		continent = Eastern_Kingdoms,
		paths = BZ["Arathi Highlands"],
		groupSize = 15,
		type = "Battleground",
		texture = "ArathiBasin",
	}

	zones[BZ["Warsong Gulch"]] = {
		low = 10,
		high = MAX_PLAYER_LEVEL,
		continent = Kalimdor,
		paths = isHorde and BZ["Northern Barrens"] or BZ["Ashenvale"],
		groupSize = 10,
		type = "Battleground",
		texture = "WarsongGulch",
	}	

	zones[BZ["Eye of the Storm"]] = {
		low = 35,
		high = MAX_PLAYER_LEVEL,
		continent = Outland,
		groupSize = 15,
		type = "Battleground",
		texture = "NetherstormArena",
	}
	
	zones[BZ["Alterac Valley"]] = {
		low = 45,
		high = MAX_PLAYER_LEVEL,
		continent = Eastern_Kingdoms,
		paths = BZ["Hillsbrad Foothills"],
		groupSize = 40,
		type = "Battleground",
		texture = "AlteracValley",
	}	
	
	zones[BZ["Strand of the Ancients"]] = {
		low = 65,
		high = MAX_PLAYER_LEVEL,
		continent = Northrend,
		groupSize = 15,
		type = "Battleground",
		texture = "StrandoftheAncients",
	}

	zones[BZ["Isle of Conquest"]] = {
		low = 75,
		high = MAX_PLAYER_LEVEL,
		continent = Northrend,
		groupSize = 40,
		type = "Battleground",
		texture = "IsleofConquest",
	}

	zones[BZ["The Battle for Gilneas"]] = {
		low = 85,
		high = MAX_PLAYER_LEVEL,
		continent = Eastern_Kingdoms,
		groupSize = 10,
		type = "Battleground",
		texture = "TheBattleforGilneas",
	}

	zones[BZ["Twin Peaks"]] = {
		low = 85,
		high = MAX_PLAYER_LEVEL,
		continent = Eastern_Kingdoms,
		paths = BZ["Twilight Highlands"],
		groupSize = 10,
		type = "Battleground",
		texture = "TwinPeaks",  -- TODO: verify
	}
	
	zones[BZ["Deepwind Gorge"]] = {
		low = 90,
		high = MAX_PLAYER_LEVEL,
		continent = Pandaria,
		paths = BZ["Valley of the Four Winds"],
		groupSize = 15,
		type = "Battleground",
		texture = "DeepwindGorge",  -- TODO: verify
	}


	-- Arenas --
	
	zones[BZ["Blade's Edge Arena"]] = {
		low = 70,
		high = 70,
		continent = Outland,
		type = "Arena",
	}

	zones[BZ["Nagrand Arena"]] = {
		low = 70,
		high = 70,
		continent = Outland,
		type = "Arena",
	}

	zones[BZ["Ruins of Lordaeron"]] = {
		low = 70,
		high = 70,
		continent = Kalimdor,
		type = "Arena",
	}	
	
	zones[BZ["Dalaran Arena"]] = {
		low = 80,
		high = 80,
		continent = Northrend,
		type = "Arena",
	}

	zones[BZ["The Ring of Valor"]] = {
		low = 80,
		high = 80,
		continent = Kalimdor,
		type = "Arena",
	}

	zones[BZ["The Tiger's Peak"]] = {
		low = 90,
		high = 90,
		continent = Pandaria,
		type = "Arena",
	}
	
	
	
	-- Complexes --

	zones[BZ["Dire Maul"]] = {
		low = 36,
		high = 60,
		continent = Kalimdor,
		instances = {
			[BZ["Dire Maul (East)"]] = true,
			[BZ["Dire Maul (North)"]] = true,
			[BZ["Dire Maul (West)"]] = true,
		},
		paths = {
			[BZ["Feralas"]] = true,
			[BZ["Dire Maul (East)"]] = true,
			[BZ["Dire Maul (North)"]] = true,
			[BZ["Dire Maul (West)"]] = true,
		},
		type = "Complex",
	}	
	
	zones[BZ["Blackrock Mountain"]] = {
		low = 47,
		high = 100,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Blackrock Depths"]] = true,
			[BZ["Blackrock Caverns"]] = true,
			[BZ["Blackwing Lair"]] = true,
			[BZ["Blackwing Descent"]] = true,
			[BZ["Molten Core"]] = true,
			[BZ["Blackrock Spire"]] = true,
			[BZ["Upper Blackrock Spire"]] = true,
		},
		paths = {
			[BZ["Burning Steppes"]] = true,
			[BZ["Searing Gorge"]] = true,
			[BZ["Blackwing Lair"]] = true,
			[BZ["Blackwing Descent"]] = true,
			[BZ["Molten Core"]] = true,
			[BZ["Blackrock Depths"]] = true,
			[BZ["Blackrock Caverns"]] = true,
			[BZ["Blackrock Spire"]] = true,
			[BZ["Upper Blackrock Spire"]] = true,
		},
		type = "Complex",
		fishing_min = 1, -- lava
	}

	zones[BZ["Hellfire Citadel"]] = {
		low = 58,
		high = 80,
		continent = Outland,
		instances = {
			[BZ["The Blood Furnace"]] = true,
			[BZ["Hellfire Ramparts"]] = true,
			[BZ["Magtheridon's Lair"]] = true,
			[BZ["The Shattered Halls"]] = true,
		},
		paths = {
			[BZ["Hellfire Peninsula"]] = true,
			[BZ["The Blood Furnace"]] = true,
			[BZ["Hellfire Ramparts"]] = true,
			[BZ["Magtheridon's Lair"]] = true,
			[BZ["The Shattered Halls"]] = true,
		},
		type = "Complex",
	}

	zones[BZ["Coldarra"]] = {
		low = 59,
		high = 80,
		continent = Northrend,
		paths = {
			[BZ["Borean Tundra"]] = true,
			[BZ["The Nexus"]] = true,
			[BZ["The Oculus"]] = true,
			[BZ["The Eye of Eternity"]] = true,
		},
		instances = {
			[BZ["The Nexus"]] = true,
			[BZ["The Oculus"]] = true,
			[BZ["The Eye of Eternity"]] = true,
		},
		type = "Complex",
	}
	
	zones[BZ["Coilfang Reservoir"]] = {
		low = 60,
		high = 80,
		continent = Outland,
		instances = {
			[BZ["The Underbog"]] = true,
			[BZ["Serpentshrine Cavern"]] = true,
			[BZ["The Steamvault"]] = true,
			[BZ["The Slave Pens"]] = true,
		},
		paths = {
			[BZ["Zangarmarsh"]] = true,
			[BZ["The Underbog"]] = true,
			[BZ["Serpentshrine Cavern"]] = true,
			[BZ["The Steamvault"]] = true,
			[BZ["The Slave Pens"]] = true,
		},
		fishing_min = 400,
		type = "Complex",
	}
	
	zones[BZ["Ahn'Qiraj: The Fallen Kingdom"]] = {
		low = 60,
		high = 63,
		continent = Kalimdor,
		paths = {
			[BZ["Silithus"]] = true,
		},
		instances = {
			[BZ["Ahn'Qiraj"]] = true,
			[BZ["Ruins of Ahn'Qiraj"]] = true,
		},
		type = "Complex",
		battlepet_low = 16,
		battlepet_high = 17,
	}
	
	zones[BZ["Ring of Observance"]] = {
		low = 62,
		high = 80,
		continent = Outland,
		instances = {
			[BZ["Mana-Tombs"]] = true,
			[BZ["Sethekk Halls"]] = true,
			[BZ["Shadow Labyrinth"]] = true,
			[BZ["Auchenai Crypts"]] = true,
		},
		paths = {
			[BZ["Terokkar Forest"]] = true,
			[BZ["Mana-Tombs"]] = true,
			[BZ["Sethekk Halls"]] = true,
			[BZ["Shadow Labyrinth"]] = true,
			[BZ["Auchenai Crypts"]] = true,
		},
		type = "Complex",
	}

	zones[BZ["Caverns of Time"]] = {
		low = 64,
		high = 90,
		continent = Kalimdor,
		instances = {
			[BZ["Old Hillsbrad Foothills"]] = true,
			[BZ["The Black Morass"]] = true,
			[BZ["Hyjal Summit"]] = true,
			[BZ["The Culling of Stratholme"]] = true,
			[BZ["End Time"]] = true,
			[BZ["Hour of Twilight"]] = true,
			[BZ["Well of Eternity"]] = true,
			[BZ["Dragon Soul"]] = true,
		},
		paths = {
			[BZ["Tanaris"]] = true,
			[BZ["Old Hillsbrad Foothills"]] = true,
			[BZ["The Black Morass"]] = true,
			[BZ["Hyjal Summit"]] = true,
			[BZ["The Culling of Stratholme"]] = true,
		},
		type = "Complex",
	}
	
	
	-- Had to remove the complex 'Tempest Keep' because of the renamed 'The Eye' instance now has same name (Legion)
	-- zones[BZ["Tempest Keep"]] = {
		-- low = 67,
		-- high = 75,
		-- continent = Outland,
		-- instances = {
			-- [BZ["The Mechanar"]] = true,
			-- [BZ["Tempest Keep"]] = true,  -- previously "The Eye"
			-- [BZ["The Botanica"]] = true,
			-- [BZ["The Arcatraz"]] = true,
		-- },
		-- paths = {
			-- [BZ["Netherstorm"]] = true,
			-- [BZ["The Mechanar"]] = true,
			-- [BZ["Tempest Keep"]] = true,
			-- [BZ["The Botanica"]] = true,
			-- [BZ["The Arcatraz"]] = true,
		-- },
		-- type = "Complex",
	-- }


	
	
	
	
	
	
--------------------------------------------------------------------------------------------------------
--                                                CORE                                                --
--------------------------------------------------------------------------------------------------------

	trace("Tourist: Initializing continents...")
	local continentNames = Tourist:GetMapContinentsAlt()
	local counter = 0

	for continentMapID, continentName in pairs(continentNames) do
		--trace("Processing Continent "..tostring(continentMapID)..": "..continentName.."...")

		--SetMapZoom(continentMapID)
		
		if zones[continentName] then
			-- Get map texture name			
			zones[continentName].texture = C_Map.GetMapArtID(continentMapID) --GetMapInfo()
			-- Get MapID
			zones[continentName].zoneMapID = continentMapID --GetCurrentMapAreaID()

			--trace("Texture for Continent "..continentName..": '"..tostring(zones[continentName].texture).."'")

--[[			
			TODO: Find a way to get size in yards

			local _, cLeft, cTop, cRight, cBottom = GetCurrentMapZone()
			-- Calculate size in yards
			zones[continentName].yards = cLeft - cRight
			
			-- Calculate x-axis shift and y-axis shift, which indicate how many yards the X and Y axis of the continent map are shifted
			-- from the midpoint of the map. These shift values are the difference between the zone offsets returned by UpdateMapHighLight and the 
			-- offsets calculated using data provided by GetCurrentMapZone.
			-- Note: For The Maelstrom continent, no such data is available at all. The four zones of this "continent" are 
			-- geographically not related to each other, so there are no zone offsets and there's no continent shift or size.
			zones[continentName].x_shift = (cLeft + cRight) / 2
			zones[continentName].y_shift = (cTop + cBottom) / 2
					
			trace("Tourist: Continent size in yards for "..tostring(continentName).." ("..tostring(continentMapID).."): "..tostring(round(zones[continentName].yards, 2)))
]]--	
		else
			-- Unknown Continent
			trace("|r|cffff4422! -- Tourist:|r TODO: Add Continent '"..tostring(continentName).."' ("..tostring(continentMapID)..")")		
		end
		
		counter = counter + 1
	end
	trace( "Tourist: Processed "..tostring(counter).." continents" )
	
	
	
	-- --------------------------------------------------------------------------------------------------------------------------
	-- Set the continent offsets and scale for the continents on the Azeroth map, except The Maelstrom.
	-- The offsets are expressed in Azeroth yards (that is, without the scale correction used for the continent maps)
	-- and have been calculated as follows.
	-- I've used a player position because it is displayed at both the continent map and the Azeroth map.
	-- Using the player coordinates (which are a percentage of the map size) and the continent and Azeroth map sizes:
	
	-- a = playerXContinent * continentWidth * continentScale (= player X offset on the continent map, expressed in Azeroth yards)
	-- b = playerXAzeroth * azerothWidth (= player X offset on the Azeroth map)
	-- continentXOffset = b - a

	-- c = playerYContinent * continentHeight * continentScale (= player Y offset on the continent map, expressed in Azeroth yards)
	-- d = playerYAzeroth * azerothHeight (= player Y offset on the Azeroth map)
	-- continentYOffset = d - c

	-- The scales are 'borrowed' from Astrolabe ;-)
	
	zones[BZ["Kalimdor"]].x_offset = -4023.28
	zones[BZ["Kalimdor"]].y_offset = 3243.71
	zones[BZ["Kalimdor"]].scale = 0.5609
	
	zones[BZ["Eastern Kingdoms"]].x_offset = 16095.36
	zones[BZ["Eastern Kingdoms"]].y_offset = 2945.14
	zones[BZ["Eastern Kingdoms"]].scale = 0.5630
	
	zones[BZ["Northrend"]].x_offset = 12223.65
	zones[BZ["Northrend"]].y_offset = 520.24
	zones[BZ["Northrend"]].scale = 0.5949
	
	zones[BZ["Pandaria"]].x_offset = 12223.65
	zones[BZ["Pandaria"]].y_offset = 520.24
	zones[BZ["Pandaria"]].scale = 0.6514
	
	zones[BZ["Broken Isles"]].x_offset = 16297
	zones[BZ["Broken Isles"]].y_offset = 8225.3
	zones[BZ["Broken Isles"]].scale = 0.4469
	
	-- --------------------------------------------------------------------------------------------------------------------------

	
	trace("Tourist: Initializing zones...")
	local doneZones = {}
	local mapZones = {}
	local uniqueZoneName
	local minLvl, maxLvl, minPetLvl, maxPetLvl
	
	for continentMapID, continentName in pairs(continentNames) do	
		mapZones = Tourist:GetMapZonesAlt(continentMapID)
		counter = 0
		for zoneMapID, zoneName in pairs(mapZones) do
			-- Add mapIDs to lookup table
			zoneIDtoContinentID[zoneMapID] = continentMapID

			-- Check for duplicate on continent name + zone name
			if not doneZones[continentName.."."..zoneName] then
				uniqueZoneName = Tourist:GetUniqueZoneNameForLookup(zoneName, continentMapID)
				if zones[uniqueZoneName] then
					-- Set zone mapID
					zones[uniqueZoneName].zoneMapID = zoneMapID
					-- Get zone texture ID (?)
					zones[uniqueZoneName].texture = C_Map.GetMapArtID(continentMapID)
				
					-- New: get zone player and battle pet levels
					minLvl, maxLvl, minPetLvl, maxPetLvl = C_Map.GetMapLevels(zoneMapID)
					if minLvL and minLvL > 0 then  zones[uniqueZoneName].low = minLvl end
					if maxLvl and maxLvl > 0 then zones[uniqueZoneName].high = maxLvl end
					if minPetLvl and minPetLvl > 0 then zones[uniqueZoneName].battlepet_low = minPetLvl end
					if maxPetLvl and maxPetLvl > 0 then zones[uniqueZoneName].battlepet_high = maxPetLvl end
					
					-- TODO: Find a way to get size in yards?					
				else
					trace("|r|cffff4422! -- Tourist:|r TODO: Add zone "..tostring(zoneName).." (to "..tostring(continentName)..")" )			
				end
				
				doneZones[continentName.."."..zoneName] = true
			else
				--trace("|r|cffff4422! -- Tourist:|r Duplicate zone: "..tostring(zoneName).." [ID "..tostring(zoneMapID).."] (at "..tostring(continentName)..")" )
			end
			counter = counter + 1
		end -- zone loop
		
		trace( "Tourist: Processed "..tostring(counter).." zones for "..continentName )

	end -- continent loop

	-- OLD CODE for the loop above:
	
--	for continentID, continentName in pairs(continentNames) do
--		-- Get continent width and height
--		local cWidth = zones[continentName] and zones[continentName].yards or 0
--		local cHeight = 2/3 * cWidth

		-- Build a collection of the indices of the zones within the continent
		-- to be able to lookup a zone index for SetMapZoom()
--		local zoneNames = GetMapZonesAltLocal(continentID)
--		local zoneIndices = {}
--		for index = 1, #zoneNames do
--			zoneIndices[zoneNames[index]] = index
--		end
		
--		for i = 1, #zoneNames do		
			-- The zones Frostfire Ridge, Highmountain and Val'sharah appear twice in the collection of zones of their continent
			-- so we need to be able to skip duplicates, even within a Continent
--			if not doneZones[continentName.."."..zoneNames[i]] then
--				local zoneName = Tourist:GetUniqueZoneNameForLookup(zoneNames[i], continentID)
--				local zoneIndex = zoneIndices[zoneNames[i]]
--				if zones[zoneName] then
					-- Get zone map data
					
					--SetMapZoom(continentID, zoneIndex)
--[[					
					-- TODO: Find a way to get size in yards
					local z, zLeft, zTop, zRight, zBot = GetCurrentMapZone()
				
					-- Calculate zone size
					local sizeInYards = 0
					if zLeft and zRight then
						sizeInYards = zLeft - zRight
					end
					if sizeInYards ~= 0 or not zones[zoneName].yards then
						-- Make sure the size is always set (even if it's 0) but don't overwrite any hardcoded values if the size is 0
						zones[zoneName].yards = sizeInYards
					end
					if zones[zoneName].yards == 0 then 
						trace("|r|cffff4422! -- Tourist:|r Size for "..zoneName.." = 0 yards")
						-- Skip offset calculation as we obviously got no data from GetCurrentMapZone
					else 
					
						-- TODO: local zLeft, zRight, zTop, zBot = C_Map.GetMapRectOnMap(zoneID, continentID) ?
				
					
						if cWidth ~= 0 then
							-- Calculate zone offsets if the size of the continent is known (The Maelstrom has no continent size).
							-- LibTourist uses positive x and y axis with the source located at the top left corner of the map.
							-- GetCurrentMapZone uses a source *somewhere* in the middle of the map, and the x axis is 
							-- reversed so it's positive to the LEFT.
							-- First assume the source is exactly in the middle of the map...
							local zXOffset = (cWidth * 0.5) - zLeft
							local zYOffset = (cHeight * 0.5) - zTop
							-- ...then correct the offsets for continent map axis shifts
							zXOffset = zXOffset + zones[continentName].x_shift
							zYOffset = zYOffset + zones[continentName].y_shift
							zones[zoneName].x_offset = zXOffset
							zones[zoneName].y_offset = zYOffset
						end
					end
]]--								
					-- Get zone texture filename
--					zones[zoneName].texture = C_Map.GetMapArtID(continentMapID) --GetMapInfo()
					-- Get zone mapID
--					zones[zoneName].zoneMapID = GetCurrentMapAreaID()
--				else
--					trace("|r|cffff4422! -- Tourist:|r TODO: Add zone "..tostring(zoneName))
--				end
				
--				doneZones[continentName.."."..zoneNames[i]] = true
--			else
--				trace("|r|cffff4422! -- Tourist:|r Duplicate zone: "..tostring(continentName).."["..tostring(i).."]: "..tostring(zoneNames[i]) )
--			end

--		end -- zones loop
--		trace( "Tourist: Processed "..tostring(#zoneNames).." zones for "..continentName )
		
--	end -- continents loop

	--SetMapToCurrentZone()  -- Obsolete in 8.0

	trace("Tourist: Filling lookup tables...")
	
	-- Fill the lookup tables
	for k,v in pairs(zones) do
		lows[k] = v.low or 0
		highs[k] = v.high or 0
		continents[k] = v.continent or UNKNOWN
		instances[k] = v.instances
		paths[k] = v.paths or false
		types[k] = v.type or "Zone"
		groupSizes[k] = v.groupSize
		groupMinSizes[k] = v.groupMinSize
		groupMaxSizes[k] = v.groupMaxSize
		groupAltSizes[k] = v.altGroupSize
		factions[k] = v.faction
		yardWidths[k] = nil  -- v.yards
		yardHeights[k] = nil -- v.yards and v.yards * 2/3 or nil
		yardXOffsets[k] = nil -- v.x_offset
		yardYOffsets[k] = nil -- v.y_offset
		fishing[k] = v.fishing_min
		battlepet_lows[k] = v.battlepet_low
		battlepet_highs[k] = v.battlepet_high
		textures[k] = v.texture
		complexOfInstance[k] = v.complex
		zoneComplexes[k] = v.complexes
		if v.texture then
			textures_rev[v.texture] = k
		end
		zoneMapIDs[k] = v.zoneMapID
		if v.zoneMapID then
			zoneMapIDs_rev[v.zoneMapID] = k
		end
		if v.entrancePortal then
			entrancePortals_zone[k] = v.entrancePortal[1]
			entrancePortals_x[k] = v.entrancePortal[2]
			entrancePortals_y[k] = v.entrancePortal[3]
		end
		if v.scale then
			continentScales[k] = v.scale
		end
	end
	zones = nil

	trace("Tourist: Initialized.")

	PLAYER_LEVEL_UP(Tourist)
end
