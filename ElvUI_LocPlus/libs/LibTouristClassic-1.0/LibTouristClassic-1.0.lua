--[[
Name: LibTouristClassic-1.0
Revision: $Rev: 265 $
Author(s): Odica; based on LibTourist-3.0
Documentation: https://www.wowace.com/projects/libtourist-1-0/pages/api-reference
Git: https://repos.wowace.com/wow/libtourist-classic libtourist-classic
Description: A library to provide information about zones and instances for WoW Classic
License: MIT
]]

local MAJOR_VERSION = "LibTouristClassic-1.0"
local MINOR_VERSION = 90000 + tonumber(("$Revision: 263 $"):match("(%d+)"))

if not LibStub then error(MAJOR_VERSION .. " requires LibStub") end
local C_Map = C_Map
local Tourist, oldLib = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not Tourist then
	return
end

local addonName = ...

if oldLib then
	oldLib = {}
	for k, v in pairs(Tourist) do
		Tourist[k] = nil
		oldLib[k] = v
	end
end

local HBD = LibStub("HereBeDragons-2.0")
function Tourist:GetHBD() return HBD end

local function trace(msg)
--	DEFAULT_CHAT_FRAME:AddMessage(msg)
end

local MAX_LEVEL = 85 -- Because the buggy WoW API still returns 60 as MAX_PLAYER_LEVEL

trace("Tourist: Loading LibTourist Classic...")


-- Localization tables
local BZ = {}
local BZR = {}

local playerLevel = UnitLevel("player")

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

local X_Y_ZEPPELIN = "%s - %s Zeppelin"
local X_Y_BOAT = "%s - %s Boat"
local X_Y_PORTAL = "%s - %s Portal"
local X_Y_TELEPORT = "%s - %s Teleport"
local X_Y_FLIGHTPATH = "%s - %s Flight path" -- used for path connections between zones that can only be reached using the taxi service


if GetLocale() == "zhCN" then
	X_Y_ZEPPELIN = "%s - %s 飞艇"
	X_Y_BOAT = "%s - %s 船"
	X_Y_PORTAL = "%s - %s 传送门"
	X_Y_TELEPORT = "%s - %s 传送门"
	X_Y_FLIGHTPATH = "%s - %s 飞行路径"
elseif GetLocale() == "zhTW" then
	X_Y_ZEPPELIN = "%s - %s 飛艇"
	X_Y_BOAT = "%s - %s 船"
	X_Y_PORTAL = "%s - %s 傳送門"
	X_Y_TELEPORT = "%s - %s 傳送門"
	X_Y_FLIGHTPATH = "%s - %s 飛行路徑"
elseif GetLocale() == "frFR" then
	X_Y_ZEPPELIN = "Zeppelin %s - %s"
	X_Y_BOAT = "Bateau %s - %s"
	X_Y_PORTAL = "Portail %s - %s"
	X_Y_TELEPORT = "Téléport %s - %s"
	X_Y_FLIGHTPATH = "Trajectoire de vol %s - %s"
elseif GetLocale() == "koKR" then
	X_Y_ZEPPELIN = "%s - %s 비행선"
	X_Y_BOAT = "%s - %s 배"
	X_Y_PORTAL = "%s - %s 차원문"
	X_Y_TELEPORT = "%s - %s 차원문"
	X_Y_FLIGHTPATH = "%s - %s 비행 경로"
elseif GetLocale() == "deDE" then
	X_Y_ZEPPELIN = "%s - %s Zeppelin"
	X_Y_BOAT = "%s - %s Schiff"
	X_Y_PORTAL = "%s - %s Portal"
	X_Y_TELEPORT = "%s - %s Teleport"
	X_Y_FLIGHTPATH = "%s - %s Flugbahn"
elseif GetLocale() == "esES" then
	X_Y_ZEPPELIN = "%s - %s Zepelín"
	X_Y_BOAT = "%s - %s Barco"
	X_Y_PORTAL = "%s - %s Portal"
	X_Y_TELEPORT = "%s - %s Teletransportador"
	X_Y_FLIGHTPATH = "%s - %s Trayectoria de vuelo"
elseif GetLocale() == "esMX" then
	X_Y_ZEPPELIN = "%s - %s Zepelín"
	X_Y_BOAT = "%s - %s Barco"
	X_Y_PORTAL = "%s - %s Portal"
	X_Y_TELEPORT = "%s - %s Teletransportador"
	X_Y_FLIGHTPATH = "%s - %s Trayectoria de vuelo"
elseif GetLocale() == "itIT" then
	X_Y_ZEPPELIN = "%s - %s Zeppelin"
	X_Y_BOAT = "%s - %s Barca"
	X_Y_PORTAL = "%s - %s Portale"
	X_Y_TELEPORT = "%s - %s Teletrasporto"
	X_Y_FLIGHTPATH = "%s - %s Percorso di volo"
elseif GetLocale() == "ptBR" then
	X_Y_ZEPPELIN = "%s - %s Zepelim"
	X_Y_BOAT = "%s - %s Barco"
	X_Y_PORTAL = "%s - %s Portal"
	X_Y_TELEPORT = "%s - %s Teleporte"
	X_Y_FLIGHTPATH = "%s - %s Rota de Vôo"
end

local recZones = {}
local recInstances = {}
local lows = setmetatable({}, {__index = function() return 0 end})
local highs = setmetatable({}, getmetatable(lows))
local continents = {}
local instances = {}
local paths = {}
local flightnodes = {}
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
local fishing_low = {}
local fishing_high = {}
local cost = {}
local textures = {}
local textures_rev = {}
local complexOfInstance = {}
local zoneComplexes = {}
local entrancePortals_zone = {}
local entrancePortals_x = {}
local entrancePortals_y = {}

local zoneMapIDtoContinentMapID = {}
local zoneMapIDs = {}
local mapZonesByContinentID = {}

local FlightnodeLookupTable = {}
local gatheringFlightnodes = false
local flightnodeDataGathered = false

local GAME_LOCALE = GetLocale()
local COSMIC_MAP_ID = 946
local THE_MAELSTROM_MAP_ID = 948

local flightNodeIgnoreList = {
	[59] = "Dun Baldar, Alterac Valley",
	[60] = "Frostwolf Keep, Alterac Valley",
	[108] = "Nagrand - PvP - Attack Run End 3",
	[142] = "Hellfire Peninsula - Reaver's Fall",
	[212] = "Quest - Sunwell Daily - Ship Bombing - End",
	[113] = "Quest - Nethrandamus Start",
	[131] = "Quest - Horde Hellfire Start",
	[136] = "Quest - Hellfire, Aerial Mission (Horde) End",
	[211] = "Quest - Sunwell Daily - Ship Bombing - Start",
	[104] = "Nagrand - PvP - Attack Run End 1",
	[152] = "Quest - Netherstorm - Manaforge Ultris (Start)",
	[137] = "Quest - Hellfire, Aerial Mission (Alliance) Start",
	[145] = "Quest - Netherstorm - Stealth Flight - Begin",
	[112] = "Eversong - Duskwither Teleport End",
	[135] = "Quest - Hellfire, Aerial Mission (Horde) Start",
	[134] = "Quest - Hellfire Peninsula (Alliance) End",
	[109] = "Nagrand - PvP - Attack Run Start 4",
	[95] = "Zangarmarsh - Quest - As the Crow Flies",
	[147] = "Hellfire Peninsula - Force Camp Beach Head",
	[106] = "Nagrand - PvP - Attack Run End 2",
	[169] = "Quest - Netherwing Ledge - Mine Cart Ride - South - Start",
	[97] = "Quest - Elekk Path to Kessel",
	[143] = "Quest - Caverns of Time (Intro Flight Path) (End)",
	[111] = "Eversong - Duskwither Teleport",
	[157] = "Quest - Blade's Edge - Vision Guide - Start",
	[154] = "Quest - Netherstorm - Manaforge Ultris (Second Pass) Start",
	[138] = "Quest - Hellfire, Aerial Mission (Alliance) End",
	[209] = "Quest - Sunwell Daily - Dead Scar Bombing - Start",
	[133] = "Quest - Hellfire Peninsula (Alliance Path) Start",
	[107] = "Nagrand - PvP - Attack Run Start 3",
	[148] = "Shatter Point, Hellfire Peninsula (Beach Assault)",
	[153] = "Quest - Netherstorm - Manaforge Ultris (End)",
	[110] = "Nagrand - PvP - Attack Run End 4",
	[171] = "Skettis",
	[144] = "Quest - Caverns of Time (Intro Flight Path) (Start)",
	[103] = "Nagrand - PvP - Attack Run Start 1 ",
	[132] = "Quest - Horde Hellfire End",
	[105] = "Nagrand - PvP - Attack Run Start 2",
	[36] = "Generic, World Target 001",
	[168] = "Filming",
	[170] = "Quest - Netherwing Ledge - Mine Cart Ride - South - End",
	[172] = "Ogri'La",
	[173] = "Quest - Yarzill Flight Start",
	[176] = "Quest - Howling Fjord Tauren Canoe (Start)",
	[177] = "Quest - Howling Fjord Tauren Canoe (End)",
	[180] = "Quest - Dustwallow - Alcaz Survey Start",
	[181] = "Quest - Dustwallow - Alcaz Survey End",
	[186] = "Quest - Howling Fjord - Flight to the Windrunner - Start",
	[187] = "Quest - Howling Fjord - Flight to the Windrunner - End",
	[188] = "Quest - Howling Fjord - Test at Sea - Start",
	[193] = "Quest - Howling Fjord - Mission: Plague This! - End",
	[194] = "Quest - Howling Fjord - Mission: Plague This! - Start",
	[199] = "Quest - Howling Fjord - McGoyver Start",
	[200] = "Quest - Howling Fjord - McGoyver End",
	[203] = "Quest - Stars' Rest -> Wintergarde",
	[210] = "Quest - Sunwell Daily - Dead Scar Bombing - End",
	[221] = "Amber Ledge, Borean (To Beryl)",
	[222] = "Beryl Point, Borean",
	[225] = "Amber Ledge, Borean (to Coldarra)",
	[232] = "Borean Tundra - Warsong Hold Wolf Start",
	[235] = "Transitus Shield, Coldarra (NOT USED)",
	[236] = "Coldarra, Keristrasza to Malygos",
	[239] = "Borean Tundra - Quest - Dusk Start",
	[240] = "Borean Tundra - Quest - Dusk - End",
	[242] = "Quest - Dragonblight - Spiritual Vision - Begin",
	[261] = "Quest - Stars' Rest to Wintergarde End",
	[262] = "Grizzly Hills, Alliance Log Ride Start 01",
	[267] = "Grizzly Hills, Alliance Log Ride Start",
	[269] = "Quest - Westguard Keep to Wintergarde Keep Begin",
	[270] = "Quest - Westguard Keep to Wintergarde Keep End",
	[271] = "Grizzly Hills, Horde Log Ride Start",
	[273] = "Wyrmrest Temple - bottom to top, Dragonblight - Begin",
	[275] = "Wyrmrest Temple - top to bottom, Dragonblight - Begin",
	[277] = "Wyrmrest Temple - top to middle, Dragonblight - Begin",
	[280] = "Wyrmrest Temple - middle to top, Dragonblight - Begin",
	[282] = "Wyrmrest Temple - middle to bottom, Dragonblight - Begin",
	[284] = "Wyrmrest Temple - bottom to middle, Dragonblight - Begin",
	[285] = "Quest - Wintergarde -> Stars' Rest (Start)",
	[287] = "Quest - Valgarde -> Westguard Keep Start",
	[292] = "Flavor - Stormwind Harbor  - Start",
	[301] = "Quest - Borean Tundra - Check In With Bixie - Begin",
	[311] = "Camp Onequah, Grizzly Hills (Quest)",
	[313] = "Westfall Brigade, Grizzly Hills (Quest)",
	[314] = "Zim'Torga, Zul'Drak (Quest)",
	[316] = "Ebon Hold - Acherus -> Death's Breach Start",
	[318] = "Ebon Hold - Death's Breach -> Acherus Start",
	[358] = "Quest - Icecrown - North Sea Kraken Bombing - Start",
	[359] = "Quest - Icecrown - North Sea Kraken Bombing - End",
	[392] = "CC Prologue - GT - Quest - Vent Horizon - Start",
	[393] = "CC Prologue - GT - Quest - Vent Horizon - End",
	[394] = "CC Prologue - GT - Battle Flight - Start",
	[404] = "Durotar - ET - CC Prologue Spy Frog Start",
	[405] = "Durotar - ET - CC Prologue Spy Frog End",
	[438] = "Durotar - ET - CC Prologue Troll Taxi Bat Start",
	[439] = "Durotar - ET - CC Prologue Troll Recruit End",
}


--------------------------------------------------------------------------------------------------------
--                                            Localization                                            --
--------------------------------------------------------------------------------------------------------

-- UIMapIDs as used by C_Map.GetMapInfo
local MapIdLookupTable = {
	[86] = "Orgrimmar",
    [113] = "Northrend",
    [114] = "Borean Tundra",
    [115] = "Dragonblight",
    [116] = "Grizzly Hills",
    [117] = "Howling Fjord",
    [118] = "Icecrown",
    [119] = "Sholazar Basin",
    [120] = "The Storm Peaks",
    [121] = "Zul'Drak",
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
    [179] = "Gilneas",
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
    [409] = "Dragon Soul",
    [410] = "Dragon Soul",
    [411] = "Dragon Soul",
    [412] = "Dragon Soul",
    [413] = "Dragon Soul",
    [414] = "Dragon Soul",
    [415] = "Dragon Soul",
	[946] = "Cosmic",
    [947] = "Azeroth",
    [948] = "The Maelstrom",
    [987] = "Outland",
	[988] = "Northrend",
    [1375] = "Halls of Stone",	
    [1411] = "Durotar",
    [1412] = "Mulgore",
    [1413] = "The Barrens",
    [1414] = "Kalimdor",
    [1415] = "Eastern Kingdoms",
    [1417] = "Arathi Highlands",
    [1418] = "Badlands",
    [1419] = "Blasted Lands",
    [1420] = "Tirisfal Glades",
    [1421] = "Silverpine Forest",
    [1422] = "Western Plaguelands",
    [1423] = "Eastern Plaguelands",
    [1424] = "Hillsbrad Foothills",
    [1425] = "The Hinterlands",
    [1426] = "Dun Morogh",
    [1427] = "Searing Gorge",
    [1428] = "Burning Steppes",
    [1429] = "Elwynn Forest",
    [1430] = "Deadwind Pass",
    [1431] = "Duskwood",
    [1432] = "Loch Modan",
    [1433] = "Redridge Mountains",
    [1434] = "Northern Stranglethorn",
    [1435] = "Swamp of Sorrows",
    [1436] = "Westfall",
    [1437] = "Wetlands",
    [1438] = "Teldrassil",
    [1439] = "Darkshore",
    [1440] = "Ashenvale",
    [1441] = "Thousand Needles",
    [1442] = "Stonetalon Mountains",
    [1443] = "Desolace",
    [1444] = "Feralas",
    [1445] = "Dustwallow Marsh",
    [1446] = "Tanaris",
    [1447] = "Azshara",
    [1448] = "Felwood",
    [1449] = "Un'Goro Crater",
    [1450] = "Moonglade",
    [1451] = "Silithus",
    [1452] = "Winterspring",
    [1453] = "Stormwind City",
    [1454] = "Orgrimmar",
    [1455] = "Ironforge",
    [1456] = "Thunder Bluff",
    [1457] = "Darnassus",
    [1458] = "Undercity",
    [1459] = "Alterac Valley",
    [1460] = "Warsong Gulch",
    [1461] = "Arathi Basin",
    [1463] = "Eastern Kingdoms",
    [1464] = "Kalimdor",
    [1554] = "Serpentshrine Cavern",
    [1555] = "Tempest Keep",
    [1941] = "Eversong Woods",
    [1942] = "Ghostlands",
    [1943] = "Azuremyst Isle",
    [1944] = "Hellfire Peninsula",
    [1945] = "Outland",
    [1946] = "Zangarmarsh",
    [1947] = "The Exodar",
    [1948] = "Shadowmoon Valley",
    [1949] = "Blade's Edge Mountains",
    [1950] = "Bloodmyst Isle",
    [1951] = "Nagrand",
    [1952] = "Terokkar Forest",
    [1953] = "Netherstorm",
    [1954] = "Silvermoon City",
    [1955] = "Shattrath City",
    [1956] = "Eye of the Storm",
    [1957] = "Isle of Quel'Danas",
    [2104] = "Wintergrasp",
    [2340] = "Tol Barad",	
}

-- InstanceIDs as used by GetRealZoneText
local InstanceIdLookupTable = {
    [1] = "Kalimdor",
    [13] = "Test Dungeon",
    [25] = "Scott Test",
    [29] = "CashTest",
    [30] = "Alterac Valley",
    [33] = "Shadowfang Keep",
    [34] = "Stormwind Stockade",
    [35] = "<unused>StormwindPrison",
    [36] = "Deadmines",
    [37] = "Azshara Crater",
    [42] = "Collin's Test",
    [43] = "Wailing Caverns",
    [44] = "<unused> Monastery",
    [47] = "Razorfen Kraul",
    [48] = "Blackfathom Deeps",
    [70] = "Uldaman",
    [90] = "Gnomeregan",
    [109] = "Sunken Temple",
    [129] = "Razorfen Downs",
    [169] = "Emerald Dream",
    [189] = "Scarlet Monastery",
    [209] = "Zul'Farrak",
    [229] = "Blackrock Spire",
    [230] = "Blackrock Depths",
    [249] = "Onyxia's Lair",
    [269] = "Opening of the Dark Portal",
    [289] = "Scholomance",
    [309] = "Zul'Gurub",
    [329] = "Stratholme",
    [349] = "Maraudon",
    [369] = "Deeprun Tram",
    [389] = "Ragefire Chasm",
    [409] = "Molten Core",
    [429] = "Dire Maul",
    [449] = "Alliance PVP Barracks",
    [450] = "Horde PVP Barracks",
    [451] = "Development Land",
    [469] = "Blackwing Lair",
    [489] = "Warsong Gulch",
    [509] = "Ruins of Ahn'Qiraj",
    [529] = "Arathi Basin",
    [530] = "Outland",
    [531] = "Ahn'Qiraj Temple",
    [532] = "Karazhan",
    [533] = "Naxxramas",
    [534] = "The Battle for Mount Hyjal",
    [540] = "Hellfire Citadel: The Shattered Halls",
    [542] = "Hellfire Citadel: The Blood Furnace",
    [543] = "Hellfire Citadel: Ramparts",
    [544] = "Magtheridon's Lair",
    [545] = "Coilfang: The Steamvault",
    [546] = "Coilfang: The Underbog",
    [547] = "Coilfang: The Slave Pens",
    [548] = "Coilfang: Serpentshrine Cavern",
    [550] = "Tempest Keep",
    [552] = "Tempest Keep: The Arcatraz",
    [553] = "Tempest Keep: The Botanica",
    [554] = "Tempest Keep: The Mechanar",
    [555] = "Auchindoun: Shadow Labyrinth",
    [556] = "Auchindoun: Sethekk Halls",
    [557] = "Auchindoun: Mana-Tombs",
    [558] = "Auchindoun: Auchenai Crypts",
    [559] = "Nagrand Arena",
    [560] = "The Escape From Durnholde",
    [562] = "Blade's Edge Arena",
    [564] = "Black Temple",
    [565] = "Gruul's Lair",
    [566] = "Eye of the Storm",
    [568] = "Zul'Aman",
    [571] = "Northrend",
    [572] = "Ruins of Lordaeron",
    [574] = "Utgarde Keep",
    [575] = "Utgarde Pinnacle",
    [576] = "The Nexus",
    [578] = "The Oculus",
    [580] = "The Sunwell",
    [582] = "Transport: Rut'theran to Auberdine",
    [584] = "Transport: Menethil to Theramore",
    [585] = "Magister's Terrace",
    [586] = "Transport: Exodar to Auberdine",
    [587] = "Transport: Feathermoon Ferry",
    [588] = "Transport: Menethil to Auberdine",
    [589] = "Transport: Orgrimmar to Grom'Gol",
    [590] = "Transport: Grom'Gol to Undercity",
    [591] = "Transport: Undercity to Orgrimmar",
    [592] = "Transport: Borean Tundra Test",
    [593] = "Transport: Booty Bay to Ratchet",
    [594] = "Transport: Howling Fjord Sister Mercy (Quest)",
    [595] = "The Culling of Stratholme",
    [596] = "Transport: Naglfar",
    [598] = "Sunwell Fix (Unused)",
    [599] = "Halls of Stone",
    [600] = "Drak'Tharon Keep",
    [601] = "Azjol-Nerub",
    [602] = "Halls of Lightning",
    [603] = "Ulduar",
    [604] = "Gundrak",
    [605] = "Development Land (non-weighted textures)",
    [607] = "Strand of the Ancients",
    [608] = "Violet Hold",
    [609] = "Ebon Hold",
    [610] = "Transport: Tirisfal to Vengeance Landing",
    [612] = "Transport: Menethil to Valgarde",
    [613] = "Transport: Orgrimmar to Warsong Hold",
    [614] = "Transport: Stormwind to Valiance Keep",
    [615] = "The Obsidian Sanctum",
    [616] = "The Eye of Eternity",
    [617] = "Dalaran Sewers",
    [618] = "The Ring of Valor",
    [619] = "Ahn'kahet: The Old Kingdom",
    [620] = "Transport: Moa'ki to Unu'pe",
    [621] = "Transport: Moa'ki to Kamagua",
    [622] = "Transport: Orgrim's Hammer",
    [623] = "Transport: The Skybreaker",
    [624] = "Vault of Archavon",
    [627] = "unused",
    [628] = "Isle of Conquest",
    [631] = "Icecrown Citadel",
    [632] = "The Forge of Souls",
    [637] = "Abyssal Maw Exterior",
    [638] = "Gilneas",
    [641] = "Transport: Alliance Airship BG",
    [642] = "Transport: HordeAirshipBG",
    [643] = "Throne of the Tides",
    [644] = "Halls of Origination",
    [645] = "Blackrock Caverns",
    [646] = "Deepholm",
	[647] = "Transport: Orgrimmar to Thunder Bluff",
    [648] = "LostIsles",
	[649] = "Trial of the Crusader",
    [650] = "Trial of the Champion",
    [651] = "ElevatorSpawnTest",
    [654] = "Gilneas2",
    [655] = "GilneasPhase1",
    [656] = "GilneasPhase2",
    [657] = "The Vortex Pinnacle",
	[658] = "Pit of Saron",
    [659] = "Lost Isles Volcano Eruption",
    [660] = "Deephome Ceiling",
    [661] = "Lost Isles Town in a Box",
    [662] = "Transport: Alliance Vashj'ir Ship",
	[668] = "Halls of Reflection",
    [669] = "Blackwing Descent",
    [670] = "Grim Batol",
    [671] = "The Bastion of Twilight",
	[672] = "Transport: The Skybreaker (Icecrown Citadel Raid)",
    [673] = "Transport: Orgrim's Hammer (Icecrown Citadel Raid)",
    [674] = "Transport: Ship to Vashj'ir",
    [712] = "Transport: The Skybreaker (IC Dungeon)",
    [713] = "Transport: Orgrim's Hammer (IC Dungeon)",
    [718] = "Trasnport: The Mighty Wind (Icecrown Citadel Raid)",	
    [719] = "Mount Hyjal Phase 1",
    [720] = "Firelands",
    [721] = "Firelands Terrain 2",
    [723] = "Stormwind",
    [724] = "The Ruby Sanctum",
    [725] = "The Stonecore",
    [726] = "Twin Peaks",
    [727] = "STV Diamond Mine BG",
    [730] = "Maelstrom Zone",
    [731] = "Stonetalon Bomb",
    [732] = "Tol Barad",
    [734] = "Ahn'Qiraj Terrace",
    [736] = "Twilight Highlands Dragonmaw Phase",
    [738] = "Ship to Vashj'ir (Orgrimmar -> Vashj'ir)",
    [739] = "Vashj'ir Sub - Horde",
    [740] = "Vashj'ir Sub - Alliance",
    [741] = "Twilight Highlands Horde Transport",
    [742] = "Vashj'ir Sub - Horde - Circling Abyssal Maw",
    [743] = "Vashj'ir Sub - Alliance circling Abyssal Maw",
    [746] = "Uldum Phase Oasis",
    [747] = "Transport: Deepholm Gunship",
    [748] = "Transport: Onyxia/Nefarian Elevator",
    [749] = "Transport: Gilneas Moving Gunship",
    [750] = "Transport: Gilneas Static Gunship",
    [751] = "Redridge - Orc Bomb",
    [752] = "Redridge - Bridge Phase One",
    [753] = "Redridge - Bridge Phase Two",
    [754] = "Throne of the Four Winds",
    [755] = "Lost City of the Tol'vir",
    [757] = "Baradin Hold",
    [759] = "Uldum Phased Entrance",
    [760] = "Twilight Highlands Phased Entrance",
    [761] = "The Battle for Gilneas",
    [762] = "Twilight Highlands Zeppelin 1",
    [763] = "Twilight Highlands Zeppelin 2",
    [764] = "Uldum - Phase Wrecked Camp",
    [765] = "Krazzworks Attack Zeppelin",
    [766] = "Transport: Gilneas Moving Gunship 02",
    [767] = "Transport: Gilneas Moving Gunship 03",
    [859] = "Zul'Gurub",
    [861] = "Molten Front",
    [930] = "Scenario: Alcaz Island",
    [938] = "End Time",
    [939] = "Well of Eternity",
    [940] = "Hour of Twilight",
    [951] = "Nexus Legendary",
    [967] = "Dragon Soul",
    [968] = "Rated Eye of the Storm",
    [974] = "Darkmoon Faire",
    [977] = "Maelstrom Deathwing Fight",
    [980] = "Tol'Vir Arena",
    [2118] = "Wintergrasp",
    [2565] = "Northrend (3.0 phase)",
    [2567] = "Northrend (3.1 phase)",	
    [2755] = "Battle for Tol Barad",
}



-- These zones are known in LibTourist's zones collection but are not returned by C_Map.GetMapInfo.
-- The IDs are the areaIDs as used by C_Map.GetAreaInfo.
local zoneTranslation = {
	enUS = {
		-- Instances
		[5914] = "Dire Maul - East",
		[5913] = "Dire Maul - North",
		[5915] = "Dire Maul - West",
		[5916] = "Stratholme - Main Gate",
		[5917] = "Stratholme - Service Entrance",
		[2366] = "The Black Morass",
		[2367] = "Old Hillsbrad Foothills",
		[3606] = "Hyjal Summit",
		[4075] = "Sunwell Plateau",
--		[4131] = "Magister's Terrace",
		
		-- Complexes
		[1445] = "Blackrock Mountain",
		[3545] = "Hellfire Citadel",
		[3688] = "Auchindoun",
		[3905] = "Coilfang Reservoir",
		[5695] = "Ahn'Qiraj: The Fallen Kingdom",
		[2300] = "Caverns of Time",
		[4024] = "Coldarra",
	},
	deDE = {
		-- Instances
		[5914] = "Düsterbruch - Ost",
		[5913] = "Düsterbruch - Nord",
		[5915] = "Düsterbruch - West",
		[5916] = "Stratholme - Haupttor",
		[5917] = "Stratholme - Dienstboteneingang",
		[2366] = "Der schwarze Morast",
		[2367] = "Vorgebirge des Alten Hügellands",
		[3606] = "Hyjalgipfel",
		[4075] = "Sonnenbrunnenplateau",
--		[4131] = "Terrasse der Magister",
		-- Complexes
		[1445] = "Der Schwarzfels",
		[3545] = "Höllenfeuerzitadelle",
		[3688] = "Auchindoun",
		[3905] = "Der Echsenkessel",
		[5695] = "Ahn'Qiraj: Das Gefallene Königreich",
		[2300] = "Höhlen der Zeit",
		[4024] = "Kaltarra",

	},
	esES = {
		-- Instances
		[5914] = "La Masacre: Este",
		[5913] = "La Masacre: Norte",
		[5915] = "La Masacre: Oeste",
		[5916] = "Stratholme: Entrada Principal",
		[5917] = "Stratholme: Entrada de servicio",
		[2366] = "La Ciénaga Negra",
		[2367] = "Antiguas Laderas de Trabalomas",
		[3606] = "La Cima Hyjal",
		[4075] = "Meseta de La Fuente del Sol",
--		[4131] = "Bancal del Magister",
		-- Complexes
		[1445] = "Montaña Roca Negra",
		[3545] = "Ciudadela del Fuego Infernal",
		[3688] = "Auchindoun",
		[3905] = "Reserva Colmillo Torcido",
		[5695] = "Ahn'Qiraj: El Reino Caído",
		[2300] = "Cavernas del Tiempo",
		[4024] = "Gelidar",
	},
	esMX = {
		-- Instances
		[5914] = "La Masacre: Este",
		[5913] = "La Masacre: Norte",
		[5915] = "La Masacre: Oeste",
		[5916] = "Stratholme: Entrada Principal",
		[5917] = "Stratholme: Entrada de servicio",		
		[2366] = "La Ciénaga Negra",
		[2367] = "Antiguas Laderas de Trabalomas",
		[3606] = "La Cima Hyjal",
		[4075] = "Meseta de La Fuente del Sol",
--		[4131] = "Bancal del Magister",
		-- Complexes
		[1445] = "Montaña Roca Negra",
		[3545] = "Ciudadela del Fuego Infernal",
		[3688] = "Auchindoun",
		[3905] = "Reserva Colmillo Torcido",
		[5695] = "Ahn'Qiraj: El Reino Caído",
		[2300] = "Cavernas del Tiempo",
		[4024] = "Gelidar",
	},
	frFR = {
		-- Instances
		[5914] = "Haches-Tripes - Est",
		[5913] = "Haches-Tripes - Nord",
		[5915] = "Haches-Tripes - Ouest",
		[5916] = "Stratholme - Grande porte",
		[5917] = "Stratholme - Entrée de service",
		[2366] = "Le Noir Marécage",
		[2367] = "Contreforts de Hautebrande d'antan",
		[3606] = "Sommet d'Hyjal",
		[4075] = "Plateau du Puits de soleil",
--		[4131] = "Terrasse des Magistères",
		-- Complexes
		[1445] = "Mont Rochenoire",
		[3545] = "Citadelle des Flammes infernales",
		[3688] = "Auchindoun",
		[3905] = "Réservoir de Glissecroc",
		[5695] = "Ahn’Qiraj : le royaume Déchu",
		[2300] = "Grottes du temps",
		[4024] = "Frimarra",
	},
	itIT = {
		-- Instances
		[5914] = "Maglio Infausto - Est",
		[5913] = "Maglio Infausto - Nord",
		[5915] = "Maglio Infausto - Ovest",
		[5916] = "Stratholme - Cancello Principale",
		[5917] = "Stratholme - Ingresso di Servizio",
		[2366] = "La palude nera",
		[2367] = "Antiche colline pedemontane di Hillsbrad",
		[3606] = "Vertice Hyjal",
		[4075] = "Altopiano del sole",
--		[4131] = "Terrazza dei Magistri",
		-- Complexes
		[1445] = "Massiccio Roccianera",
		[3545] = "Cittadella del Fuoco Infernale",
		[3688] = "Auchindoun",
		[3905] = "Bacino degli Spiraguzza",
		[5695] = "Ahn'qiraj: il Regno Perduto",
		[2300] = "Caverne del tempo",
		[4024] = "Ibernia",
	},
	koKR = {
		-- Instances
		[5914] = "혈투의 전장 - 동쪽",
		[5913] = "혈투의 전장 - 북쪽",
		[5915] = "혈투의 전장 - 서쪽",
		[5916] = "스트라솔름 - 정문",
		[5917] = "스트라솔름 - 공무용 입구",
		[2366] = "검은늪",
		[2367] = "옛 힐스브래드 구릉지",
		[3606] = "하이잘 정상",
		[4075] = "태양샘 고원",
--		[4131] = "마법학자의 정원",
		-- Complexes
		[1445] = "검은바위 산",
		[3545] = "지옥불 성채",
		[3688] = "아킨둔",
		[3905] = "갈퀴송곳니 저수지",
		[5695] = "안퀴라즈: 무너진 왕국",
		[2300] = "시간의 동굴",
		[4024] = "콜다라",
	},
	ptBR = {
		-- Instances
		[5914] = "Gládio Cruel – Leste",
		[5913] = "Gládio Cruel – Norte",
		[5915] = "Gládio Cruel – Oeste",
		[5916] = "Stratholme – Portão Principal",
		[5917] = "Stratholme – Entrada de Serviço",
		[2366] = "Lamaçal Negro",
		[2367] = "Antigo Contraforte de Eira dos Montes",
		[3606] = "Pico Hyjal",
		[4075] = "Platô da Nascente do Sol",
--		[4131] = "Terraço dos Magísteres",		
		-- Complexes
		[1445] = "Montanha Rocha Negra",
		[3545] = "Cidadela Fogo do Inferno",
		[3688] = "Auchindoun",
		[3905] = "Reservatório Presacurva",
		[5695] = "Ahn'Qiraj: O Reino Derrotado",
		[2300] = "Cavernas do Tempo",
		[4024] = "Gelarra",
	},
	zhCN = {
		-- Instances
		[5914] = "厄运之槌 - 东",
		[5913] = "厄运之槌 - 北",
		[5915] = "厄运之槌 - 西",
		[5916] = "斯坦索姆 - 正门",
		[5917] = "斯坦索姆 - 仆从入口",
		[2366] = "黑色沼泽",
		[2367] = "旧希尔斯布莱德丘陵",
		[3606] = "海加尔峰",
		[4075] = "太阳之井高地",
--		[4131] = "魔导师平台",
		-- Complexes
		[1445] = "黑石山",
		[3545] = "地狱火堡垒",
		[3688] = "奥金顿",
		[3905] = "盘牙水库",
		[5695] = "安其拉：堕落王国",
		[2300] = "时光之穴",
		[4024] = "考达拉",
	},
	zhTW = {
		-- Instances
		[5914] = "厄運之槌 - 東方",
		[5913] = "厄運之槌 - 北方",
		[5915] = "厄運之槌 - 西方",
		[5916] = "斯坦索姆 - 主門",
		[5917] = "斯坦索姆 - 僕從入口",
		[2366] = "黑色沼澤",
		[2367] = "希爾斯布萊德丘陵舊址",
		[3606] = "海加爾山",
		[4075] = "太陽之井高地",
--		[4131] = "博學者殿堂",
		-- Complexes
		[1445] = "黑石山",
		[3545] = "地獄火堡壘",
		[3688] = "奧齊頓",
		[3905] = "盤牙蓄湖",
		[5695] = "其拉：沒落的王朝",
		[2300] = "時光之穴",
		[4024] = "凜懼島",
	},
}

local function CreateLocalizedZoneNameLookups()
	local uiMapID
	local mapInfo
	local localizedZoneName
	local englishZoneName

	-- Note: the loop below is not very sexy but makes sure missing entries in MapIdLookupTable are reported.
	-- It is executed only once, upon initialization.
	for uiMapID = 1, 2000, 1 do
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
				-- Not in UIMap ID lookup
				trace("|r|cffff4422! -- Tourist:|r English name not found in lookup for uiMapID "..tostring(uiMapID).." ("..tostring(localizedZoneName)..")" )
			end
		end
	end

	-- Some but not all instances are returned by C_Map.GetMapInfo.
	-- Try to get missing localized names using the Instance ID lookup and GetRealZoneText:
	for instanceID = 1, 2000, 1 do
		localizedZoneName = GetRealZoneText(instanceID);
		if localizedZoneName and localizedZoneName ~= ""  then
			englishZoneName = InstanceIdLookupTable[instanceID]

			if englishZoneName then
				-- Add combination of English and localized name to lookup tables, if missing
				if not BZ[englishZoneName] then
					BZ[englishZoneName] = localizedZoneName
				end
				if not BZR[localizedZoneName] then
					BZR[localizedZoneName] = englishZoneName
				end
			else
				-- Not in instance ID lookup
				trace("|r|cffff4422! -- Tourist:|r English name not found in lookup for instanceID "..tostring(instanceID).." ("..tostring(localizedZoneName)..")" )
			end
		end
	end

	-- Load from zoneTranslation
	local translations = zoneTranslation[GAME_LOCALE]
	if not translations then
		translations = zoneTranslation["enUS"]
	end
	for key, localizedZoneName in pairs(translations) do
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
	BZ[Tourist:GetUniqueEnglishZoneNameForLookup("The Maelstrom", THE_MAELSTROM_MAP_ID)] = Tourist:GetUniqueZoneNameForLookup("The Maelstrom", THE_MAELSTROM_MAP_ID)
	BZR[Tourist:GetUniqueZoneNameForLookup("The Maelstrom", THE_MAELSTROM_MAP_ID)] = Tourist:GetUniqueEnglishZoneNameForLookup("The Maelstrom", THE_MAELSTROM_MAP_ID)
end


local function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

local function GetFlightnodeFaction(faction)
	if faction == 0 then
		return "Neutral"
	end
	if faction == 1 then
		return "Horde"
	end
	if faction == 2 then
		return "Alliance"
	else
		return tostring(faction)
	end
end

local function GetFlightnodeFactionLetter(faction)
	if faction == 0 then
		return "N"
	end
	if faction == 1 then
		return "H"
	end
	if faction == 2 then
		return "A"
	else
		return tostring(faction)
	end
end

--[[
	GatherFlightnodeData is called just in time, right before first use, because when LibTourist is being loaded at player logon,
	not all flightpoints are available yet through the C_TaxiMap interface.

	The FlightnodeLookupTable, which is built during initialization using the hardcoded relationships between zones and nodes,
	contains the flightnode IDs but no values yet. GatherFlightnodeData fills the lookup as much as possible with MapTaxiNodeInfo
	structures retrieved from the C_TaxiMap interface.

	structure TaxiMap.MapTaxiNodeInfo
		number nodeID						-- unique node ID
		table position						-- position of the node on the Flight Master's map
		string name							-- node name as displayed in game, includes zone name (mostly)
		string atlasName					-- atlas object type, includes faction
		Enum.FlightPathFaction faction		-- 0 = Neutral, 1 = Horde, 2 = Alliance
		(optional) string textureKitPrefix	-- no clue what this is for
		string factionName					-- added by LibTourist
]]--

local function GatherFlightnodeData()
	local zMapID, zName, nodes, numNodes
	local count = 0
	local errCount = 0
	if gatheringFlightnodes == true then return end
	gatheringFlightnodes = true

	local missingNodes = {}


	-- Add node objects from the C_TaxiMap interface to the lookup
	for zMapID, zName in pairs(MapIdLookupTable) do
		-- Use MapIdLookupTable instead of iterating through continents and zones to be sure all known zones are checked for flight nodes
		nodes = C_TaxiMap.GetTaxiNodesForMap(zMapID)

		if nodes ~= nil then
			numNodes = tablelength(nodes)
			if numNodes > 0 then
				for i, node in ipairs(nodes) do
					if not FlightnodeLookupTable[node.nodeID] then
						if not missingNodes[node.nodeID] and not flightNodeIgnoreList[node.nodeID] then
							trace( "|r|cffff4422! -- Tourist: Missing    ["..tostring(node.nodeID).."] = true,     -- "..tostring(node.name).." ("..tostring(GetFlightnodeFactionLetter(node.faction))..")")

							errCount = errCount + 1
							missingNodes[node.nodeID] = node.name
						end
					else
						if FlightnodeLookupTable[node.nodeID] == true then
							count = count + 1
							-- Add faction name
							node["factionName"] = GetFlightnodeFaction(node.faction)
							-- Store node object in lookup
							FlightnodeLookupTable[node.nodeID] = node
						end
					end
				end
			end
		end
	end

	-- Add hardcoded node-to-zone relations to FlightnodeLookupTable
	local nodesToUpdate = {}
	for zone in Tourist:IterateZones() do
		for node in Tourist:IterateZoneFlightnodes(zone) do
			if FlightnodeLookupTable[node.nodeID] then
				if not nodesToUpdate[node.nodeID] then
					nodesToUpdate[node.nodeID] = {}
				end
				nodesToUpdate[node.nodeID][zone] = true
			else
				trace( "|r|cffff4422! -- Tourist: Missing    ["..tostring(node.nodeID).."] = true,     -- "..tostring(node.name).." ("..tostring(GetFlightnodeFactionLetter(node.faction))..")")
				errCount = errCount + 1
			end
		end
	end
	for k, v in pairs(nodesToUpdate) do
		FlightnodeLookupTable[k]["zones"] = v
	end

	trace("Tourist: Found "..tostring(count).." of "..tostring(tablelength(FlightnodeLookupTable)).." known flight nodes; "..tostring(errCount).." unknown nodes.")

	flightnodeDataGathered = true
	gatheringFlightnodes = false
end

-- Refreshes the values of the FlightnodeLookupTable
function Tourist:RefreshFlightNodeData()
	-- Reset lookup
	for k, v in pairs(FlightnodeLookupTable) do
		FlightnodeLookupTable[k] = true
	end
	-- Re-gather data
	GatherFlightnodeData()
end

-- Returns the lookup table with all flightnodes. Key = node ID.
-- Value is a node struct(see C_Taximap.MapTaxiNodeInfo) if the node could be found by GatherFlightnodeData.
-- If the node was not returned by C_Taximap, value is true.
function Tourist:GetFlightnodeLookupTable()
	if flightnodeDataGathered == false then
		GatherFlightnodeData()
	end
	return FlightnodeLookupTable
end

-- Returns a C_Taximap.MapTaxiNodeInfo (with some extra attributes) for the specified nodeID, if available
function Tourist:GetFlightnode(nodeID)
	local node = Tourist:GetFlightnodeLookupTable()[nodeID]
	if node == true then
		return nil
	else
		return node
	end
end

-- This function replaces the abandoned LibBabble-Zone library and returns a lookup table
-- containing all zone names (including continents, instances etcetera) where the English
-- zone name is the key and the localized zone name is the value.
function Tourist:GetLookupTable()
	return BZ
end

-- This function replaces the abandoned LibBabble-Zone library and returns a lookup table
-- containing all zone names (including continents, instances etcetera) where the localized
-- zone name is the key and the English zone name is the value.
function Tourist:GetReverseLookupTable()
	return BZR
end

-- Returns the lookup table with all uiMapIDs as key and the English zone name as value.
function Tourist:GetMapIDLookupTable()
	return MapIdLookupTable
end

-- Returns the lookup table with all instanceIDs as key and the English instance name as value.
function Tourist:GetInstanceIDLookupTable()
	return InstanceIdLookupTable
end


-- HELPER AND LOOKUP FUNCTIONS -------------------------------------------------------------

local function PLAYER_LEVEL_UP(self, level)
	playerLevel = UnitLevel("player")

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
			local low, high = self:GetLevel(zone)

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


-- Public alternative for legacy function GetMapContinents. Returns uiMapID as key, continent name as value.
function Tourist:GetMapContinentsAlt()
	local continents = C_Map.GetMapChildrenInfo(COSMIC_MAP_ID, Enum.UIMapType.Continent, true)
	local retValue = {}
	for i, continentInfo in ipairs(continents) do
		retValue[continentInfo.mapID] = continentInfo.name
	end
	return retValue
end

-- Public Alternative for legacy function GetMapZones. Returns uiMapID as key, zone name as value.
function Tourist:GetMapZonesAlt(continentID)
	if mapZonesByContinentID[continentID] then
		-- Get from cache
		return mapZonesByContinentID[continentID]
	else
		local mapZones = {}
		local recursive = (continentID ~= 947)  -- 947 = Azeroth, get zones that have Azeroth as parent only
		local mapChildrenInfo = { C_Map.GetMapChildrenInfo(continentID, Enum.UIMapType.Zone, recursive) }
		for key, zones in pairs(mapChildrenInfo) do  -- don't know what this extra table is for
			for zoneIndex, zone in pairs(zones) do
				-- Get the localized zone name
				mapZones[zone.mapID] = zone.name
			end
		end

		-- Add to cache
		mapZonesByContinentID[continentID] = mapZones

		return mapZones
	end
end

-- Public alternative for legacy function GetMapNameByID
-- Takes a uiMapID or instanceID and returns the localized name
function Tourist:GetMapNameByIDAlt(uiMapID)
	if tonumber(uiMapID) == nil then
		return nil
	end

	local mapInfo = C_Map.GetMapInfo(uiMapID)
	if mapInfo then
		local zoneName = mapInfo.name
		local continentMapID = Tourist:GetContinentMapID(uiMapID)
		--trace("ContinentMap ID for "..tostring(zoneName).." ("..tostring(uiMapID)..") is "..tostring(continentMapID))
		if uiMapID == THE_MAELSTROM_MAP_ID then
			-- Exception for The Maelstrom continent because GetUniqueZoneNameForLookup excpects the zone name and not the continent name
			return zoneName
		else
			return Tourist:GetUniqueZoneNameForLookup(zoneName, continentMapID)
		end
	else
		local instanceName = GetRealZoneText(uiMapID)
		if instanceName then
			return instanceName
		else
			return nil
		end
	end
end

-- Returns the uiMapID of the Continent for the given uiMapID
function Tourist:GetContinentMapID(uiMapID)
	-- First, check the cache, built during initialisation based on the zones returned by GetMapZonesAlt
	local continentMapID = zoneMapIDtoContinentMapID[uiMapID]
	if continentMapID then
		-- Done
		return continentMapID
	end

	-- Not in cache, look for the continent, searching up through the map hierarchy.
	-- Add the results to the cache to speed up future queries.
	local mapInfo = C_Map.GetMapInfo(uiMapID)
	if not mapInfo or mapInfo.mapType == 0 or mapInfo.mapType == 1 then
		-- No data or Cosmic map or World map
		zoneMapIDtoContinentMapID[uiMapID] = nil
		return nil
	end

	if mapInfo.mapType == 2 then
		-- Map is a Continent map
		zoneMapIDtoContinentMapID[uiMapID] = mapInfo.mapID
		return mapInfo.mapID
	end

	local parentMapInfo = C_Map.GetMapInfo(mapInfo.parentMapID)
	if not parentMapInfo then
		-- No parent -> no continent ID
		zoneMapIDtoContinentMapID[uiMapID] = nil
		return nil
	else
		if parentMapInfo.mapType == 2 then
			-- Found the continent
			zoneMapIDtoContinentMapID[uiMapID] = parentMapInfo.mapID
			return parentMapInfo.mapID
		else
			-- Parent is not the Continent -> Search up one level
			return Tourist:GetContinentMapID(parentMapInfo.mapID)
		end
	end
end


-- Returns a unique localized zone name to be used to lookup data in LibTourist,
-- based on a localized or English zone name
function Tourist:GetUniqueZoneNameForLookup(zoneName, continentMapID)
	if continentMapID == THE_MAELSTROM_MAP_ID then  -- The Maelstrom
		if zoneName == BZ["The Maelstrom"] or zoneName == "The Maelstrom" then
			zoneName = BZ["The Maelstrom"].." ("..ZONE..")"
		end
	end
	return zoneName
end

-- Returns a unique English zone name to be used to lookup data in LibTourist,
-- based on a localized or English zone name
function Tourist:GetUniqueEnglishZoneNameForLookup(zoneName, continentMapID)
	if continentMapID == THE_MAELSTROM_MAP_ID then  -- The Maelstrom
		if zoneName == BZ["The Maelstrom"] or zoneName == "The Maelstrom" then
			zoneName = "The Maelstrom (Zone)"
		end
	end
	return zoneName
end




local function FormatLevelString(lo, hi)
	if lo and hi then
		if lo == hi then
			return tostring(lo)
		else
			return tostring(lo).."-"..tostring(hi)
		end
	else
		return tostring(lo or hi or "")
	end
end

-- Formats the minimum and maximum player level for the given zone as "[min]-[max]".
-- Returns one number if min and max are equal.
-- Returns an empty string if no player levels are applicable (like in Cities).
function Tourist:GetLevelString(zone)
	local lo, hi = Tourist:GetLevel(zone)
	return FormatLevelString(lo, hi)
end

-- Returns minimum fishing skill to fish and minimum skill to avoid get-aways
function Tourist:GetFishingLevel(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	return fishing_low[zone], fishing_high[zone]
end


-- Formats the minimum and maximum fishing level for the given zone as "[min]-[max]".
-- Returns one number if min and max are equal.
-- Returns an empty string if no player levels are applicable (like in Cities).
function Tourist:GetFishingLevelString(zone)
	local lo, hi = Tourist:GetFishingLevel(zone)
	return FormatLevelString(lo, hi)
end


-- Returns the minimum and maximum level for the given zone, instance or battleground.
function Tourist:GetLevel(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone

	if types[zone] == "Battleground" then
		-- Note: Not all BG's start at level 10, but all BG's support players up to MAX_LEVEL.

		local playerLvl = playerLevel
		if playerLvl <= lows[zone] then
			-- Player is too low level to enter the BG -> return the lowest available bracket
			-- by assuming the player is at the min level required for the BG.
			playerLvl = lows[zone]
		end

		-- Find the most suitable bracket
		if playerLvl >= MAX_LEVEL then
			return MAX_LEVEL, MAX_LEVEL
		elseif playerLvl >= 80 then
			return 80, 84
		elseif playerLvl >= 75 then
			return 75, 79
		elseif playerLvl >= 70 then
			return 70, 74
		elseif playerLvl >= 65 then
			return 65, 69
		elseif playerLvl >= 60 then
			return 60, 64
		elseif playerLvl >= 55 then
			return 55, 59
		elseif playerLvl >= 50 then
			return 50, 54
		elseif playerLvl >= 45 then
			return 45, 49
		elseif playerLvl >= 40 then
			return 40, 44
		elseif playerLvl >= 35 then
			return 35, 39
		elseif playerLvl >= 30 then
			return 30, 34
		elseif playerLvl >= 25 then
			return 25, 29
		elseif playerLvl >= 20 then
			return 20, 24
		elseif playerLvl >= 15 then
			return 15, 19
		else
			return 10, 14
		end
	else
		return lows[zone], highs[zone]
	end
end

-- Returns an r, g and b value representing a color ranging from grey (too low) via
-- green, yellow and orange to red (too high), by calling CalculateLevelColor with
-- the min and max level of the given zone and the current player level.
function Tourist:GetLevelColor(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	local low, high = self:GetLevel(zone)

	if types[zone] == "Battleground" then
		if playerLevel < low then
			-- player cannot enter the lowest bracket of the BG -> red
			return 1, 0, 0
		end
	end

	return Tourist:CalculateLevelColor(low, high, playerLevel)
end

-- Returns an r, g and b value representing a color ranging from grey (too low) via
-- green, yellow and orange to red (too high) depending on the player level within
-- the given range. Returns white if no level is applicable, like in cities.
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

-- Returns an r, g and b value representing a color, depending on the given zone and the current character's faction.
function Tourist:GetFactionColor(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone

	if self:IsPvPZone(zone) then
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

-- Returns an r, g and b value representing a color, depending on the given flight node faction and the current character's faction.
-- faction can be 0, 1, 2, "Neutral", "Horde" or "Alliance".
function Tourist:GetFlightnodeFactionColor(faction)
	faction = GetFlightnodeFaction(faction)
	if faction == (isHorde and "Alliance" or "Horde") then
		-- Red (hostile)
		return 1, 0, 0
	elseif faction == (isHorde and "Horde" or "Alliance") then
		-- Green (friendly)
		return 0, 1, 0
	else
		-- Yellow (neutral or unknown)
		return 1, 1, 0
	end
end

-- Returns the width and height of a zone map in game yards. The height is always 2/3 of the width.
function Tourist:GetZoneYardSize(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	return yardWidths[zone], yardHeights[zone]
end

-- Calculates a distance in game yards between point A and point B.
-- Points A and B can be in different zones but must be on the same continent.
function Tourist:GetYardDistance(zone1, x1, y1, zone2, x2, y2)
	if tonumber(zone1) == nil then
		-- Not a uiMapID, translate zone name to map ID
		zone1 = Tourist:GetZoneMapID(zone1)
	end
	if tonumber(zone2) == nil then
		-- Not a uiMapID, translate zone name to map ID
		zone2 = Tourist:GetZoneMapID(zone2)
	end
	if zone1 and zone2 then
		return HBD:GetZoneDistance(zone1, x1, y1, zone2, x2, y2)
	else
		return nil, nil, nil
	end
end

-- This function is used to calculate the coordinates of a location in zone1, on the map of zone2.
-- The zones can be continents (including Azeroth).
-- The return value can be outside the 0 to 1 range.
function Tourist:TransposeZoneCoordinate(x, y, zone1, zone2)
	if tonumber(zone1) == nil then
		-- Not a uiMapID, translate zone name to map ID
		zone1 = Tourist:GetZoneMapID(zone1)
	end
	if tonumber(zone2) == nil then
		-- Not a uiMapID, translate zone name to map ID
		zone2 = Tourist:GetZoneMapID(zone2)
	end

	return HBD:TranslateZoneCoordinates(x, y, zone1, zone2, true)  -- True: allow < 0 and > 1
end

-- This function is used to find the actual zone a player is in, including coordinates for that zone, if the current map
-- is a map that contains the player position, but is not the map of the zone where the player really is.
-- Return values:
-- x, y = player position on the most suitable map
-- zone = the unique localized zone name of the most suitable map
-- uiMapID = ID of the most suitable map
function Tourist:GetBestZoneCoordinate()
	local uiMapID = C_Map.GetBestMapForUnit("player")

	if uiMapID then
		local zone = Tourist:GetMapNameByIDAlt(uiMapID)
		local pos = C_Map.GetPlayerMapPosition(uiMapID, "player")
		if pos then
			return pos.x, pos.y, zone, uiMapID
		else
			return nil, nil, zone, uiMapID
		end
    else
      local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID, instanceGroupSize, LfgDungeonID = GetInstanceInfo()
      if instanceID then
	    return nil, nil, name, instanceID
      end
	end
	return nil, nil, nil, nil
end


-- Returns an r, g and b value representing a color, depending on the given zone and the current character's faction.
function Tourist:GetFactionColor(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone

	if self:IsPvPZone(zone) then
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


-- Returns an r, g and b value indicating the gathering difficulty for the specified node level
function Tourist:GetGatheringSkillColor(minLevel, currentSkill)
	local lvl1Corr = 0
	if minLevel == 1 then 
		lvl1Corr = -1
	end
	
	if currentSkill < minLevel then
		-- Red
		return 1, 0.1, 0.1	
	elseif currentSkill < minLevel + 25 + lvl1Corr then
		-- Orange
		return 1, 0.5, 0.25
	elseif currentSkill < minLevel + 50 + lvl1Corr then
		-- Yellow
		return 1, 1, 0	
	elseif currentSkill < minLevel + 100 + lvl1Corr then
		-- Green
		return 0.25, 0.75, 0.25	
	else
		-- Gray
		return 0.5, 0.5, 0.5
	end
end

-- Returns the minimum required skinning skill for a given mob or zone level
function Tourist:GetRequiredSkinningSkill(level)
	if level <= 10 then
		return 1
	elseif level <= 20 then
		return (level * 10) - 100
	else
		return level * 5
	end
end


-- Formats the minimum and maximum skinning skill for the given zone as "[min]-[max]".
-- Returns one number if min and max are equal.
-- Returns an empty string if no player levels are applicable (like in Cities).
function Tourist:GetSkinningLevelString(zone)
	local low, high = Tourist:GetLevel(zone)
	local skinningLow = Tourist:GetRequiredSkinningSkill(low)
	local skinningHigh = Tourist:GetRequiredSkinningSkill(high)
	return FormatLevelString(skinningLow, skinningHigh)
end




local t = {}

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


-- Flight nodes -------------------------

local function flightnodesort(a, b)
	return a.name < b.name
end

function Tourist:IterateZoneInstances(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
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

function Tourist:IterateZoneFlightnodes(zone)
	if flightnodeDataGathered == false then
		GatherFlightnodeData()
	end

	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	local nodes = flightnodes[zone]

	if not nodes then
		-- No nodes
		return retNil
	elseif type(nodes) == "table" then
		-- Table of node IDs. Check if they have been found by GatherFlightnodeData
		-- If so, the value is a node object, otherwise the value is true
		local foundNodes = {}
		for id, _ in pairs(nodes) do
			if FlightnodeLookupTable[id] ~= true then
				-- FlightnodeLookupTable[id] is an object, use it as key for the iter code below
				foundNodes[FlightnodeLookupTable[id]] = true
--			else
				--trace("Skipped: "..tostring(id))
			end
		end

		for k in pairs(t) do
			t[k] = nil
		end
		for k in pairs(foundNodes) do
			t[#t+1] = k
		end
		table.sort(t, flightnodesort)
		t.n = 0
		return myiter, t, nil
	else
		-- Single node ID. Check if it has been found by GatherFlightnodeData
		if FlightnodeLookupTable[nodes] ~= true then
			return retOne, FlightnodeLookupTable[nodes], nil
		else
			-- No data
			return retNil
		end
	end
end

-- Zones ------------------------

function Tourist:IterateZoneComplexes(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
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
	instance = Tourist:GetMapNameByIDAlt(instance) or instance
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
	complex = Tourist:GetMapNameByIDAlt(complex) or complex
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
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	return not not instances[zone]
end

function Tourist:DoesZoneHaveFlightnodes(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	return not not flightnodes[zone]
end

function Tourist:DoesZoneHaveComplexes(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	return not not zoneComplexes[zone]
end


local zonesInstances
local function initZonesInstances()
	if not zonesInstances then
		zonesInstances = {}
		for zone, v in pairs(lows) do
			if types[zone] ~= "Transport" and types[zone] ~= "Portal" and types[zone] ~= "Flightpath" and types[zone] ~= "Continent" then
				zonesInstances[zone] = true
			end
		end
	end
	initZonesInstances = nil  -- Set function to nil so initialisation is done only once (and just in time)
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
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	local t = types[zone]
	return t == "Instance" or t == "Battleground" or t == "Arena"
end

function Tourist:IsZone(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	local t = types[zone]
	return t and t ~= "Instance" and t ~= "Battleground" and t ~= "Transport" and t ~= "Portal" and t ~= "Flightpath" and t ~= "Arena" and t ~= "Complex"
end

function Tourist:IsContinent(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	local t = types[zone]
	return t == "Continent"
end

function Tourist:GetComplex(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	return complexOfInstance[zone]
end

function Tourist:GetType(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	return types[zone] or "Zone"
end

function Tourist:IsZoneOrInstance(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	local t = types[zone]
	return t and t ~= "Transport" and t ~= "Portal" and t~= "Flightpath"
end

function Tourist:IsTransport(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	local t = types[zone]
	return t == "Transport" or t == "Portal" or t == "Flightpath"
end

function Tourist:IsComplex(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	local t = types[zone]
	return t == "Complex"
end

function Tourist:IsBattleground(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	local t = types[zone]
	return t == "Battleground"
end

function Tourist:IsArena(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	local t = types[zone]
	return t == "Arena"
end

function Tourist:IsPvPZone(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	local t = types[zone]
	return t == "PvP Zone"
end

function Tourist:IsCity(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	local t = types[zone]
	return t == "City"
end

function Tourist:IsAlliance(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	return factions[zone] == "Alliance"
end

function Tourist:IsHorde(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	return factions[zone] == "Horde"
end

if isHorde then
	Tourist.IsFriendly = Tourist.IsHorde
	Tourist.IsHostile = Tourist.IsAlliance
else
	Tourist.IsFriendly = Tourist.IsAlliance
	Tourist.IsHostile = Tourist.IsHorde
end

function Tourist:IsContested(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	return not factions[zone]
end

function Tourist:GetContinent(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	return BZ[continents[zone]] or UNKNOWN
end

function Tourist:IsInKalimdor(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	return continents[zone] == Kalimdor
end

function Tourist:IsInEasternKingdoms(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	return continents[zone] == Eastern_Kingdoms
end

function Tourist:IsInOutland(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	return continents[zone] == Outland
end

function Tourist:IsInNorthrend(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	return continents[zone] == Northrend
end

function Tourist:IsInTheMaelstrom(zone)
	return continents[zone] == The_Maelstrom
end


function Tourist:GetInstanceGroupSize(instance)
	instance = Tourist:GetMapNameByIDAlt(instance) or instance
	return groupSizes[instance] or groupMaxSizes[instance] or 0
end

function Tourist:GetInstanceGroupMinSize(instance)
	instance = Tourist:GetMapNameByIDAlt(instance) or instance
	return groupMinSizes[instance] or groupSizes[instance] or 0
end

function Tourist:GetInstanceGroupMaxSize(instance)
	instance = Tourist:GetMapNameByIDAlt(instance) or instance
	return groupMaxSizes[instance] or groupSizes[instance] or 0
end

function Tourist:GetInstanceGroupSizeString(instance, includeAltSize)
	instance = Tourist:GetMapNameByIDAlt(instance) or instance
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
	instance = Tourist:GetMapNameByIDAlt(instance) or instance
	return groupAltSizes[instance] or 0
end

function Tourist:GetTexture(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	return textures[zone]
end

function Tourist:GetZoneMapID(zone)
	return zoneMapIDs[zone]
end

function Tourist:GetEntrancePortalLocation(instance)
	instance = Tourist:GetMapNameByIDAlt(instance) or instance
	local x, y = entrancePortals_x[instance], entrancePortals_y[instance]
	if x then x = x/100 end
	if y then y = y/100 end
	return entrancePortals_zone[instance], x, y
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
		local allowInaccesible = false  -- allow inacessible content (due to player level) and hostile portals, flightpaths (for testing)

		if lows[vertex] > playerLevel then
			price = price * (1 + math.ceil((lows[vertex] - playerLevel) / 6))
		end

		if factions[vertex] == (isHorde and "Horde" or "Alliance") then
			-- Friendly: 50% off
			price = price / 2
			if types[vertex] == "Flightpath" then
				-- Flightpaths are preferably only to be used when there is no other connection available
				price = price * 10
			end
		elseif factions[vertex] == (isHorde and "Alliance" or "Horde") then
			-- Hostile
			if types[vertex] == "Portal" or types[vertex] == "Flightpath" then
				-- No go
				price = inf
			else 
				if types[vertex] == "City" then
					-- Very dangerous
					price = price * 10
				else
					-- Less dangerous
					price = price * 3
				end
			end
		end

		if continents[vertex] == Outland and playerLevel < 58 then
			-- Avoid using Shattrath portals in paths between Azeroth locations when they're not yet available
			price = inf
		end

		if types[vertex] == "Transport" then
			-- Not sure why transports should be more expensive than road connections (to be tuned?)
			price = price * 2
		end

		-- Avoid using connections to inaccessible continents
		if continents[vertex] == Outland and playerLevel < 58 then
			if allowInaccesible then price = price * 1000 else price = inf end
		end
		if continents[vertex] == Northrend and playerLevel < 68 then
			if allowInaccesible then price = price * 1000 else price = inf end
		end
		if continents[vertex] == The_Maelstrom and playerLevel < 78 then
			if allowInaccesible then price = price * 1000 else price = inf end
		end

		self[vertex] = price
		return price
	end
})

-- This function tries to calculate the most optimal path between alpha and bravo 
-- by foot or ground mount, that is, without using a flying mount or a taxi service (with a few exceptions). 
-- The return value is an iteration that gives a travel advice in the form of a list 
-- of zones, transports and portals to follow in order to get from alpha to bravo. 
-- The function tries to avoid hostile zones by calculating a "price" for each possible 
-- route. The price calculation takes zone level, faction and type into account.
-- See metatable above for the 'pricing' mechanism.
function Tourist:IteratePath(alpha, bravo)
	alpha = Tourist:GetMapNameByIDAlt(alpha) or alpha  -- departure zone
	bravo = Tourist:GetMapNameByIDAlt(bravo) or bravo  -- destination zone

	if paths[alpha] == nil or paths[bravo] == nil then
		-- departure zone and destination zone must both have at least one path
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

	for vertex, v in pairs(paths) do  -- for each zone with at least one path
		d[vertex] = inf -- add to price stack: d[<zone>] = price of the route to get to that zone from alpha, initially infinite
		Q[vertex] = v   -- add to zone stack:  Q[<zone>] = <path collection>, contains all zones that have one or more paths
	end
	d[alpha] = 0  -- price for departure zone = 0 (no costs to get there)

	while next(Q) do   		-- do this for each zone as long as there are zones present in the zone stack
		local u  			-- this will hold the zone name with the lowest price
		local min = inf		-- this will hold the lowest price that has been found while searching; initially infinite
		for z in pairs(Q) do   		-- for each zone currently present in the zone stack
			local value = d[z]		-- get price for the route to get to that zone (see note below)
			if value < min then		-- compare to find the zone with the lowest price. If a lower price is found:
				min = value				-- remember lowest route price so far
				u = z					-- remember the zone with the lowest route price so far
			end
		end
		
		if min == inf then
			return retNil  -- no zone found for which a price has been determined -> exit and return nil (no path possible between alpha and bravo)
		end
		Q[u] = nil  -- remove the zone that came up as cheapest from the stack so it won't be used twice
		if u == bravo then
			break 	-- we have reached our destination zone; stop searching by exiting the 'while next(Q)' loop
		end

		-- The very first cycle will result in the departure zone being the cheapest to go to. This zone has price 0, while all other zones are still
		-- priced 'infinite' at this point. The departure zone will then be picked up for processing of its connections (paths).
		--
		-- Each zone that has been processed will be removed from the stack. The departure zone will therefore be the first zone to be removed.
		-- Because every cycle the a zone with the lowest available price is processed, the remaining zones in the stack will always have an equal or 
		-- higher price (if not inifinite).
		--
		-- In subsequent cycles, prices will be calculated and set for other zones, causing them to be picked up for processing eventually in later cycles.
		-- The price reflects the costs to reach that zone, originating from the departure zone.
		--
		-- Only zones will be priced, that have a connection with the zone that is being processed (starting with the departure zone).
		-- Prices are only registered when they are lower than the registered price. When this happens the registered price is always 'infinite'.
		-- Because the price of the route keeps increasing, prices are never updated once set. This ensures that the search always moves away from the 
		-- departure zone, like an oil stain.
		-- 
		-- At some point the destination zone will be priced too, if it comes up during the search.
		--
		-- When eventually the destination zone is picked as cheapest one left in the stack, this means that:
		--   a) there is a route between departure and destination, because the destination zone has been priced
		--   b) this route is made up out of the cheapest connections available
		-- As a result, there is no need to continue the search because every other option would be more expensive.
		

		-- process the path connections of the found zone
		local adj = paths[u]  			-- get the path connections of the zone being processed (adj = adjecent?)
		if type(adj) == "table" then	-- multiple paths go from here
			local d_u = d[u]			-- current route price: the price of the route to get to the zone being processed
			for v in pairs(adj) do		-- for each path that goes from here
				local c = d_u + cost[v]		-- add the price of that path to the route price
				if d[v] > c then	-- if the currently known price of this path (initialized at infinite at the beginning) is greater than the calculated price...
					d[v] = c		-- - update the price of the path to that zone in the collection of prices
					pi[v] = u		-- - store or update how to get there: pi[<path zone name>] = <current zone name> 
				end
			end
		elseif adj ~= false then		-- one path goes from here
			local c = d[u] + cost[adj]	-- add the price of that path to the route price
			if d[adj] > c then			-- if the the calculated route price for this path is less than the currently known price (initialized at inf at the beginning) is greater than ...
				d[adj] = c					-- - update the price of the path to that zone in the collection of prices
				pi[adj] = u					-- - store or update how to get there: pi[<path zone name>] = <current zone name> 		
			end
		end
	end

	-- At this point, pi will contain a collection of all connections that have been priced, stored as: pi[<you should go here>] = <from here>
	-- Amongst these are the connections that have to be used to create the cheapest route between departure and destination.
	-- Next, the route will be extracted from the data in pi.
	--
	-- The loop below starts at the destination zone and works it way back to the departure zone, asking
	-- "from which direction should I be coming when I arrive here?"
	-- until there is no answer to that question, which will be the case for the departure zone. Technically, the departure zone 
	-- has not been priced and is therefore not present in the collection.
	--
	-- The resulting sequence is stored in S[<index>] = <zone name>
	-- The sequence appears to be reversed, starting at the destination zone (not sure why that is)

	local i = 1
	local last = bravo
	while last do
		S[i] = last
		i = i + 1
		last = pi[last]
	end

	-- reset the helper stacks
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

	S['#'] = i  -- set the stack size of S

	return iterator, S  -- return result
end


local function retIsZone(t, key)
	while true do
		key = next(t, key)
		if not key then
			return nil
		end
		if Tourist:IsZone(key) then
			return key
		end
	end
end

-- This returns an iteration of zone connections (paths).
-- The second parameter determines whether other connections like transports and portals should be included
function Tourist:IterateBorderZones(zone, zonesOnly)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	local path = paths[zone]

	if not path then
		return retNil
	elseif type(path) == "table" then
		return zonesOnly and retIsZone or retNormal, path
	else
		if zonesOnly and not Tourist:IsZone(path) then
			return retNil
		end
		return retOne, path
	end
end


--------------------------------------------------------------------------------------------------------
--                                            Main code                                               --
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

	-- Boats -------------------------------------
	-- Classic
	transports["STRANGLETHORN_BARRENS_BOAT"] = string.format(X_Y_BOAT, BZ["The Cape of Stranglethorn"], BZ["The Barrens"])
	transports["BARRENS_STRANGLETHORN_BOAT"] = string.format(X_Y_BOAT, BZ["The Barrens"], BZ["The Cape of Stranglethorn"])
	
	transports["WETLANDS_DUSTWALLOW_BOAT"] = string.format(X_Y_BOAT, BZ["Wetlands"], BZ["Dustwallow Marsh"])
	transports["DUSTWALLOW_WETLANDS_BOAT"] = string.format(X_Y_BOAT, BZ["Dustwallow Marsh"], BZ["Wetlands"])
	
	transports["STORMWIND_DARKSHORE_BOAT"] = string.format(X_Y_BOAT, BZ["Stormwind City"], BZ["Darkshore"])
	transports["DARKSHORE_STORMWIND_BOAT"] = string.format(X_Y_BOAT, BZ["Darkshore"], BZ["Stormwind City"])
	
	-- TBC
	transports["DARKSHORE_TELDRASSIL_BOAT"] = string.format(X_Y_BOAT, BZ["Darkshore"], BZ["Teldrassil"])
	transports["TELDRASSIL_DARKSHORE_BOAT"] = string.format(X_Y_BOAT, BZ["Teldrassil"], BZ["Darkshore"])
	
	transports["DARKSHORE_AZUREMYST_BOAT"] = string.format(X_Y_BOAT, BZ["Darkshore"], BZ["Azuremyst Isle"])
	transports["AZUREMYST_DARKSHORE_BOAT"] = string.format(X_Y_BOAT, BZ["Azuremyst Isle"], BZ["Darkshore"])

	-- WotLK
	transports["WETLANDS_HOWLINGFJORD_BOAT"] = string.format(X_Y_BOAT, BZ["Wetlands"], BZ["Howling Fjord"])
	transports["HOWLINGFJORD_WETLANDS_BOAT"] = string.format(X_Y_BOAT, BZ["Howling Fjord"], BZ["Wetlands"])
	
	transports["STORMWIND_BOREANTUNDRA_BOAT"] = string.format(X_Y_BOAT, BZ["Stormwind City"], BZ["Borean Tundra"])
	transports["BOREANTUNDRA_STORMWIND_BOAT"] = string.format(X_Y_BOAT, BZ["Borean Tundra"], BZ["Stormwind City"])

	transports["BOREANTUNDRA_DRAGONBLIGHT_BOAT"] = string.format(X_Y_BOAT, BZ["Dragonblight"], BZ["Borean Tundra"])
	transports["DRAGONBLIGHT_BOREANTUNDRA_BOAT"] = string.format(X_Y_BOAT, BZ["Borean Tundra"], BZ["Dragonblight"])
	
	transports["DRAGONBLIGHT_HOWLINGFJORD_BOAT"] = string.format(X_Y_BOAT, BZ["Dragonblight"], BZ["Howling Fjord"])
	transports["HOWLINGFJORD_DRAGONBLIGHT_BOAT"] = string.format(X_Y_BOAT, BZ["Howling Fjord"], BZ["Dragonblight"])


	-- Zeppelins -------------------------------------
	-- Classic
	transports["ORGRIMMAR_TIRISFAL_ZEPPELIN"] = string.format(X_Y_ZEPPELIN, BZ["Orgrimmar"], BZ["Tirisfal Glades"])
	transports["TIRISFAL_ORGRIMMAR_ZEPPELIN"] = string.format(X_Y_ZEPPELIN, BZ["Tirisfal Glades"], BZ["Orgrimmar"])
	
	transports["ORGRIMMAR_STRANGLETHORN_ZEPPELIN"] = string.format(X_Y_ZEPPELIN, BZ["Orgrimmar"], BZ["Northern Stranglethorn"])
	transports["STRANGLETHORN_ORGRIMMAR_ZEPPELIN"] = string.format(X_Y_ZEPPELIN, BZ["Northern Stranglethorn"], BZ["Orgrimmar"])
	
	transports["TIRISFAL_STRANGLETHORN_ZEPPELIN"] = string.format(X_Y_ZEPPELIN, BZ["Tirisfal Glades"], BZ["Northern Stranglethorn"])
	transports["STRANGLETHORN_TIRISFAL_ZEPPELIN"] = string.format(X_Y_ZEPPELIN, BZ["Northern Stranglethorn"], BZ["Tirisfal Glades"])

	-- WotLK
	transports["ORGRIMMAR_BOREANTUNDRA_ZEPPELIN"] = string.format(X_Y_ZEPPELIN, BZ["Orgrimmar"], BZ["Borean Tundra"])
	transports["BOREANTUNDRA_ORGRIMMAR_ZEPPELIN"] = string.format(X_Y_ZEPPELIN, BZ["Borean Tundra"], BZ["Orgrimmar"])

	transports["TIRISFAL_HOWLINGFJORD_ZEPPELIN"] = string.format(X_Y_ZEPPELIN, BZ["Tirisfal Glades"], BZ["Howling Fjord"])
	transports["HOWLINGFJORD_TIRISFAL_ZEPPELIN"] = string.format(X_Y_ZEPPELIN, BZ["Howling Fjord"], BZ["Tirisfal Glades"])




	-- Portals -------------------------------------
	-- TBC
	transports["SHATTRATH_IRONFORGE_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["Ironforge"])
	transports["IRONFORGE_SHATTRATH_PORTAL"] = string.format(X_Y_PORTAL, BZ["Ironforge"], BZ["Shattrath City"])
	
	transports["SHATTRATH_STORMWIND_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["Stormwind City"])
	transports["STORMWIND_SHATTRATH_PORTAL"] = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Shattrath City"])
	
	transports["SHATTRATH_DARNASSUS_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["Darnassus"])
	transports["DARNASSUS_SHATTRATH_PORTAL"] = string.format(X_Y_PORTAL, BZ["Darnassus"], BZ["Shattrath City"])
	
	transports["SHATTRATH_ORGRIMMAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["Orgrimmar"])
	transports["ORGRIMMAR_SHATTRATH_PORTAL"] = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Shattrath City"])
	
	transports["SHATTRATH_THUNDERBLUFF_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["Thunder Bluff"])
	transports["THUNDERBLUFF_SHATTRATH_PORTAL"] = string.format(X_Y_PORTAL, BZ["Thunder Bluff"], BZ["Shattrath City"])
	
	transports["SHATTRATH_UNDERCITY_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["Undercity"])
	transports["UNDERCITY_SHATTRATH_PORTAL"] = string.format(X_Y_PORTAL, BZ["Undercity"], BZ["Shattrath City"])
	
	transports["SHATTRATH_EXODAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["The Exodar"])
	transports["EXODAR_SHATTRATH_PORTAL"] = string.format(X_Y_PORTAL, BZ["The Exodar"], BZ["Shattrath City"])
	
	transports["SHATTRATH_SILVERMOON_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["Silvermoon City"])
	transports["SILVERMOON_SHATTRATH_PORTAL"] = string.format(X_Y_PORTAL, BZ["Silvermoon City"], BZ["Shattrath City"])

	transports["THE_DARK_PORTAL_BLASTED_LANDS"] = string.format(X_Y_PORTAL, BZ["Blasted Lands"], BZ["Hellfire Peninsula"])
	transports["THE_DARK_PORTAL_HELLFIRE"] = string.format(X_Y_PORTAL, BZ["Hellfire Peninsula"], BZ["Blasted Lands"])	

	transports["SHATTRATH_QUELDANAS_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["Isle of Quel'Danas"])

	-- WotLK
	transports["DALARAN_COT_PORTAL"] = string.format(X_Y_PORTAL, BZ["Dalaran"], BZ["Caverns of Time"])

	transports["DALARAN_ORGRIMMAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Dalaran"], BZ["Orgrimmar"])
	
	transports["DALARAN_STORMWIND_PORTAL"] = string.format(X_Y_PORTAL, BZ["Dalaran"], BZ["Stormwind City"])

	-- Cataclysm
	
	transports["MOLTENFRONT_MOUNTHYJAL_PORTAL"] = string.format(X_Y_PORTAL, BZ["Molten Front"], BZ["Mount Hyjal"])
	transports["MOUNTHYJAL_MOLTENFRONT_PORTAL"] = string.format(X_Y_PORTAL, BZ["Mount Hyjal"], BZ["Molten Front"])
	transports["MOUNTHYJAL_ORGRIMMAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Mount Hyjal"], BZ["Orgrimmar"])
	transports["MOUNTHYJAL_STORMWIND_PORTAL"] = string.format(X_Y_PORTAL, BZ["Mount Hyjal"], BZ["Stormwind City"])
	transports["ORGRIMMAR_MOUNTHYJAL_PORTAL"] = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Mount Hyjal"])
	transports["STORMWIND_MOUNTHYJAL_PORTAL"] = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Mount Hyjal"])

	transports["ORGRIMMAR_ULDUM_PORTAL"] = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Uldum"])
	transports["STORMWIND_ULDUM_PORTAL"] = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Uldum"])

	transports["DEEPHOLM_ORGRIMMAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Deepholm"], BZ["Orgrimmar"])
	transports["DEEPHOLM_STORMWIND_PORTAL"] = string.format(X_Y_PORTAL, BZ["Deepholm"], BZ["Stormwind City"])
	transports["ORGRIMMAR_DEEPHOLM_PORTAL"] = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Deepholm"])
	transports["STORMWIND_DEEPHOLM_PORTAL"] = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Deepholm"])

	transports["ORGRIMMAR_TOLBARAD_PORTAL"] = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Tol Barad Peninsula"])
	transports["STORMWIND_TOLBARAD_PORTAL"] = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Tol Barad Peninsula"])
	transports["TOLBARAD_ORGRIMMAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Tol Barad Peninsula"], BZ["Orgrimmar"])
	transports["TOLBARAD_STORMWIND_PORTAL"] = string.format(X_Y_PORTAL, BZ["Tol Barad Peninsula"], BZ["Stormwind City"])

	transports["ORGRIMMAR_TWILIGHTHIGHLANDS_PORTAL"] = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Twilight Highlands"])
	transports["TWILIGHTHIGHLANDS_ORGRIMMAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Twilight Highlands"], BZ["Orgrimmar"])
	transports["STORMWIND_TWILIGHTHIGHLANDS_PORTAL"] = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Twilight Highlands"])
	transports["TWILIGHTHIGHLANDS_STORMWIND_PORTAL"] = string.format(X_Y_PORTAL, BZ["Twilight Highlands"], BZ["Stormwind City"])

	

	-- Teleports -------------------------------------
	-- Classic
	transports["DARNASSUS_TELDRASSIL_TELEPORT"] = string.format(X_Y_TELEPORT, BZ["Darnassus"], BZ["Teldrassil"])
	transports["TELDRASSIL_DARNASSUS_TELEPORT"] = string.format(X_Y_TELEPORT, BZ["Teldrassil"], BZ["Darnassus"])
	
	-- TBC
	transports["SILVERMOON_UNDERCITY_TELEPORT"] = string.format(X_Y_TELEPORT, BZ["Silvermoon City"], BZ["Undercity"])
	transports["UNDERCITY_SILVERMOON_TELEPORT"] = string.format(X_Y_TELEPORT, BZ["Undercity"], BZ["Silvermoon City"])

	-- WotLK
	transports["DALARAN_CRYSTALSONG_TELEPORT"] = string.format(X_Y_TELEPORT, BZ["Dalaran"], BZ["Crystalsong Forest"])
	transports["CRYSTALSONG_DALARAN_TELEPORT"] = string.format(X_Y_TELEPORT, BZ["Crystalsong Forest"], BZ["Dalaran"])


	-- Fight paths -------------------------------------
	
	-- WotLK: flight paths to Icecrown and Wintergrasp
	transports["DALARAN_ICECROWN_FLIGHTPATH"] = string.format(X_Y_FLIGHTPATH, BZ["Dalaran"], BZ["Icecrown"])
	transports["ICECROWN_DALARAN_FLIGHTPATH"] = string.format(X_Y_FLIGHTPATH, BZ["Icecrown"], BZ["Dalaran"])
	transports["DALARAN_WINTERGRASP_FLIGHTPATH"] = string.format(X_Y_FLIGHTPATH, BZ["Dalaran"], BZ["Wintergrasp"])
	transports["WINTERGRASP_DALARAN_FLIGHTPATH"] = string.format(X_Y_FLIGHTPATH, BZ["Wintergrasp"], BZ["Dalaran"])

	
	-- Cataclysm: flight paths to Vashj'ir
	transports["IRONFORGE_KELPTHAR_FLIGHTPATH"] = string.format(X_Y_FLIGHTPATH, BZ["Ironforge"], BZ["Kelp'thar Forest"])
	transports["KELPTHAR_IRONFORGE_FLIGHTPATH"] = string.format(X_Y_FLIGHTPATH, BZ["Kelp'thar Forest"], BZ["Ironforge"])
	transports["UNDERCITY_KELPTHAR_FLIGHTPATH"] = string.format(X_Y_FLIGHTPATH, BZ["Undercity"], BZ["Kelp'thar Forest"])
	transports["KELPTHAR_UNDERCITY_FLIGHTPATH"] = string.format(X_Y_FLIGHTPATH, BZ["Kelp'thar Forest"], BZ["Undercity"])
	transports["SEARINGGORGE_KELPTHAR_FLIGHTPATH"] = string.format(X_Y_FLIGHTPATH, BZ["Searing Gorge"], BZ["Kelp'thar Forest"])
	transports["KELPTHAR_SEARINGGORGE_FLIGHTPATH"] = string.format(X_Y_FLIGHTPATH, BZ["Kelp'thar Forest"], BZ["Searing Gorge"])	






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


	-- TRANSPORTS ---------------------------------------------------------------

	zones[transports["ORGRIMMAR_TIRISFAL_ZEPPELIN"]] = {
		paths = {
			[BZ["Tirisfal Glades"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["TIRISFAL_ORGRIMMAR_ZEPPELIN"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}


	zones[transports["ORGRIMMAR_STRANGLETHORN_ZEPPELIN"]] = {
		paths = {
			[BZ["Northern Stranglethorn"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["STRANGLETHORN_ORGRIMMAR_ZEPPELIN"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}


	zones[transports["TIRISFAL_STRANGLETHORN_ZEPPELIN"]] = {
		paths = {
			[BZ["Northern Stranglethorn"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["STRANGLETHORN_TIRISFAL_ZEPPELIN"]] = {
		paths = {
			[BZ["Tirisfal Glades"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}



	zones[transports["STRANGLETHORN_BARRENS_BOAT"]] = {
		paths = {
			[BZ["The Barrens"]] = true,
		},
		type = "Transport",
	}

	zones[transports["BARRENS_STRANGLETHORN_BOAT"]] = {
		paths = {
			[BZ["The Cape of Stranglethorn"]] = true,
		},
		type = "Transport",
	}	
	
	
	
	

	zones[transports["STORMWIND_DARKSHORE_BOAT"]] = {
		paths = {
			[BZ["Darkshore"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["DARKSHORE_STORMWIND_BOAT"]] = {
		paths = {
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}



	zones[BZ["Deeprun Tram"]] = {
		paths = {
			[BZ["Stormwind City"]] = true,
			[BZ["Ironforge"]] = true,
		},
		faction = "Alliance",		
		type = "Transport",
	}



	-- TBC
	zones[transports["SILVERMOON_UNDERCITY_TELEPORT"]] = {
		paths = {
			[BZ["Undercity"]] = true,
		},
		faction = "Horde",
		type = "Portal",
	}
	
	zones[transports["UNDERCITY_SILVERMOON_TELEPORT"]] = {
		paths = {
			[BZ["Silvermoon City"]] = true,
		},
		faction = "Horde",
		type = "Portal",
	}	

	zones[transports["DARKSHORE_AZUREMYST_BOAT"]] = {
		paths = {
			[BZ["Azuremyst Isle"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	zones[transports["AZUREMYST_DARKSHORE_BOAT"]] = {
		paths = {
			[BZ["Darkshore"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	
	
	
	zones[transports["DARKSHORE_TELDRASSIL_BOAT"]] = {
		paths = {
			[BZ["Teldrassil"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["TELDRASSIL_DARKSHORE_BOAT"]] = {
		paths = {
			[BZ["Darkshore"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["DARNASSUS_TELDRASSIL_TELEPORT"]] = {
		paths = {
			[BZ["Teldrassil"]] = true,
		},
		type = "Portal",
	}

	zones[transports["TELDRASSIL_DARNASSUS_TELEPORT"]] = {
		paths = {
			[BZ["Darnassus"]] = true,
		},
		type = "Portal",
	}

	zones[transports["SHATTRATH_DARNASSUS_PORTAL"]] = {
		paths = {
			[BZ["Darnassus"]] = true,
		},
		faction = "Alliance",
		type = "Portal",
	}
	
	zones[transports["DARNASSUS_SHATTRATH_PORTAL"]] = {
		paths = {
			[BZ["Shattrath City"]] = true,
		},
		faction = "Alliance",
		type = "Portal",
	}

	zones[transports["SHATTRATH_EXODAR_PORTAL"]] = {
		paths = {
			[BZ["The Exodar"]] = true,
		},
		faction = "Alliance",
		type = "Portal",
	}
	
	zones[transports["EXODAR_SHATTRATH_PORTAL"]] = {
		paths = {
			[BZ["Shattrath City"]] = true,
		},
		faction = "Alliance",
		type = "Portal",
	}	
	
	
	
	zones[transports["SHATTRATH_IRONFORGE_PORTAL"]] = {
		paths = {
			[BZ["Ironforge"]] = true,
		},
		faction = "Alliance",
		type = "Portal",
	}
	
	zones[transports["IRONFORGE_SHATTRATH_PORTAL"]] = {
		paths = {
			[BZ["Shattrath City"]] = true,
		},
		faction = "Alliance",
		type = "Portal",
	}	

	zones[transports["SHATTRATH_QUELDANAS_PORTAL"]] = {
		paths = BZ["Isle of Quel'Danas"],
		type = "Portal",
	}

	zones[transports["SHATTRATH_ORGRIMMAR_PORTAL"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Portal",
	}
	
	zones[transports["ORGRIMMAR_SHATTRATH_PORTAL"]] = {
		paths = {
			[BZ["Shattrath City"]] = true,
		},
		faction = "Horde",
		type = "Portal",
	}

	zones[transports["SHATTRATH_SILVERMOON_PORTAL"]] = {
		paths = {
			[BZ["Silvermoon City"]] = true,
		},
		faction = "Horde",
		type = "Portal",
	}
	
	zones[transports["SILVERMOON_SHATTRATH_PORTAL"]] = {
		paths = {
			[BZ["Shattrath City"]] = true,
		},
		faction = "Horde",
		type = "Portal",
	}	
	
	
	
	zones[transports["SHATTRATH_STORMWIND_PORTAL"]] = {
		paths = {
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Portal",
	}
	
	zones[transports["STORMWIND_SHATTRATH_PORTAL"]] = {
		paths = {
			[BZ["Shattrath City"]] = true,
		},
		faction = "Alliance",
		type = "Portal",
	}	

	zones[transports["SHATTRATH_THUNDERBLUFF_PORTAL"]] = {
		paths = {
			[BZ["Thunder Bluff"]] = true,
		},
		faction = "Horde",
		type = "Portal",
	}

	zones[transports["THUNDERBLUFF_SHATTRATH_PORTAL"]] = {
		paths = {
			[BZ["Shattrath City"]] = true,
		},
		faction = "Horde",
		type = "Portal",
	}

	zones[transports["SHATTRATH_UNDERCITY_PORTAL"]] = {
		paths = {
			[BZ["Undercity"]] = true,
		},
		faction = "Horde",
		type = "Portal",
	}

	zones[transports["UNDERCITY_SHATTRATH_PORTAL"]] = {
		paths = {
			[BZ["Shattrath City"]] = true,
		},
		faction = "Horde",
		type = "Portal",
	}


	zones[transports["THE_DARK_PORTAL_BLASTED_LANDS"]] = {
		paths = {
			[BZ["Hellfire Peninsula"]] = true,
		},
		type = "Portal",
	}

	zones[transports["THE_DARK_PORTAL_HELLFIRE"]] = {
		paths = {
			[BZ["Blasted Lands"]] = true,
		},
		type = "Portal",
	}


	-- WotLK
	
	zones[transports["DALARAN_COT_PORTAL"]] = {
		paths = {
			[BZ["Caverns of Time"]] = true,
		},
		type = "Portal",
	}	
	
	zones[transports["DALARAN_STORMWIND_PORTAL"]] = {
		paths = {
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Portal",
	}

	zones[transports["DALARAN_ORGRIMMAR_PORTAL"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Portal",
	}	
	
	zones[transports["DALARAN_CRYSTALSONG_TELEPORT"]] = {
		paths = {
			[BZ["Crystalsong Forest"]] = true,
		},
		type = "Portal",
	}

	zones[transports["CRYSTALSONG_DALARAN_TELEPORT"]] = {
		paths = {
			[BZ["Dalaran"]] = true,
		},
		type = "Portal",
	}
	
	
	
	zones[transports["STORMWIND_BOREANTUNDRA_BOAT"]] = {
		paths = {
			[BZ["Borean Tundra"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["BOREANTUNDRA_STORMWIND_BOAT"]] = {
		paths = {
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}	
	
	zones[transports["ORGRIMMAR_BOREANTUNDRA_ZEPPELIN"]] = {
		paths = {
			[BZ["Borean Tundra"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}	
	
	zones[transports["BOREANTUNDRA_ORGRIMMAR_ZEPPELIN"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}		
	
	zones[transports["TIRISFAL_HOWLINGFJORD_ZEPPELIN"]] = {
		paths = {
			[BZ["Howling Fjord"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["HOWLINGFJORD_TIRISFAL_ZEPPELIN"]] = {
		paths = {
			[BZ["Tirisfal Glades"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["WETLANDS_DUSTWALLOW_BOAT"]] = {
		paths = {
			[BZ["Dustwallow Marsh"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["DUSTWALLOW_WETLANDS_BOAT"]] = {
		paths = {
			[BZ["Wetlands"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["WETLANDS_HOWLINGFJORD_BOAT"]] = {
		paths = {
			[BZ["Howling Fjord"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["HOWLINGFJORD_WETLANDS_BOAT"]] = {
		paths = {
			[BZ["Wetlands"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["DRAGONBLIGHT_BOREANTUNDRA_BOAT"]] = {
		paths = {
			[BZ["Borean Tundra"]] = true,
		},
		type = "Transport",
	}
	
	zones[transports["BOREANTUNDRA_DRAGONBLIGHT_BOAT"]] = {
		paths = {
			[BZ["Dragonblight"]] = true,
		},
		type = "Transport",
	}


	zones[transports["DRAGONBLIGHT_HOWLINGFJORD_BOAT"]] = {
		paths = {
			[BZ["Howling Fjord"]] = true,
		},
		type = "Transport",
	}

	zones[transports["HOWLINGFJORD_DRAGONBLIGHT_BOAT"]] = {
		paths = {
			[BZ["Dragonblight"]] = true,
		},
		type = "Transport",
	}

	zones[transports["DALARAN_ICECROWN_FLIGHTPATH"]] = {
		paths = BZ["Icecrown"],
		type = "Flightpath",
	}

	zones[transports["ICECROWN_DALARAN_FLIGHTPATH"]] = {
		paths = BZ["Dalaran"],
		type = "Flightpath",
	}

	zones[transports["DALARAN_WINTERGRASP_FLIGHTPATH"]] = {
		paths = BZ["Wintergrasp"],
		type = "Flightpath",
	}
	
	zones[transports["WINTERGRASP_DALARAN_FLIGHTPATH"]] = {
		paths = BZ["Dalaran"],
		type = "Flightpath",
	}	





	-- Cataclysm
	
	zones[transports["STORMWIND_MOUNTHYJAL_PORTAL"]] = {
		paths = {
			[BZ["Mount Hyjal"]] = true,
		},
		faction = "Alliance",
		type = "Portal",
	}

	zones[transports["MOUNTHYJAL_STORMWIND_PORTAL"]] = {
		paths = {
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Portal",
	}

	zones[transports["ORGRIMMAR_MOUNTHYJAL_PORTAL"]] = {
		paths = {
			[BZ["Mount Hyjal"]] = true,
		},
		faction = "Horde",
		type = "Portal",
	}

	zones[transports["MOUNTHYJAL_ORGRIMMAR_PORTAL"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Portal",
	}	

	zones[transports["MOUNTHYJAL_MOLTENFRONT_PORTAL"]] = {
		paths = {
			[BZ["Molten Front"]] = true,
		},
		type = "Portal",
	}

	zones[transports["MOLTENFRONT_MOUNTHYJAL_PORTAL"]] = {
		paths = {
			[BZ["Mount Hyjal"]] = true,
		},
		type = "Portal",
	}
	
	
	zones[transports["STORMWIND_ULDUM_PORTAL"]] = {
		paths = {
			[BZ["Uldum"]] = true,
		},
		faction = "Alliance",
		type = "Portal",
	}

	zones[transports["ORGRIMMAR_ULDUM_PORTAL"]] = {
		paths = {
			[BZ["Uldum"]] = true,
		},
		faction = "Horde",
		type = "Portal",
	}

	zones[transports["STORMWIND_DEEPHOLM_PORTAL"]] = {
		paths = {
			[BZ["Deepholm"]] = true,
		},
		faction = "Alliance",
		type = "Portal",
	}

	zones[transports["DEEPHOLM_STORMWIND_PORTAL"]] = {
		paths = {
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Portal",
	}

	zones[transports["ORGRIMMAR_DEEPHOLM_PORTAL"]] = {
		paths = {
			[BZ["Deepholm"]] = true,
		},
		faction = "Horde",
		type = "Portal",
	}

	zones[transports["DEEPHOLM_ORGRIMMAR_PORTAL"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Portal",
	}

	zones[transports["TOLBARAD_STORMWIND_PORTAL"]] = {
		paths = {
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Portal",
	}	
	
	zones[transports["STORMWIND_TOLBARAD_PORTAL"]] = {
		paths = {
			[BZ["Tol Barad Peninsula"]] = true,
		},
		faction = "Alliance",
		type = "Portal",
	}

	zones[transports["TOLBARAD_ORGRIMMAR_PORTAL"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Portal",
	}

	zones[transports["ORGRIMMAR_TOLBARAD_PORTAL"]] = {
		paths = {
			[BZ["Tol Barad Peninsula"]] = true,
		},
		faction = "Horde",
		type = "Portal",
	}
	
	zones[transports["STORMWIND_TWILIGHTHIGHLANDS_PORTAL"]] = {
		paths = {
			[BZ["Twilight Highlands"]] = true,
		},
		faction = "Alliance",
		type = "Portal",
	}

	zones[transports["TWILIGHTHIGHLANDS_STORMWIND_PORTAL"]] = {
		paths = {
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Portal",
	}
	
	zones[transports["ORGRIMMAR_TWILIGHTHIGHLANDS_PORTAL"]] = {
		paths = {
			[BZ["Twilight Highlands"]] = true,
		},
		faction = "Horde",
		type = "Portal",
	}

	zones[transports["TWILIGHTHIGHLANDS_ORGRIMMAR_PORTAL"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Portal",
	}
	
	

	zones[transports["IRONFORGE_KELPTHAR_FLIGHTPATH"]] = {
		paths = {
			[BZ["Kelp'thar Forest"]] = true,
		},
		faction = "Alliance",
		type = "Flightpath",
	}

	zones[transports["KELPTHAR_IRONFORGE_FLIGHTPATH"]] = {
		paths = {
			[BZ["Ironforge"]] = true,
		},
		faction = "Alliance",
		type = "Flightpath",
	}		
	

	zones[transports["UNDERCITY_KELPTHAR_FLIGHTPATH"]] = {
		paths = {
			[BZ["Kelp'thar Forest"]] = true,
		},
		faction = "Horde",
		type = "Flightpath",
	}

	zones[transports["KELPTHAR_UNDERCITY_FLIGHTPATH"]] = {
		paths = {
			[BZ["Undercity"]] = true,
		},
		faction = "Horde",
		type = "Flightpath",
	}

	zones[transports["SEARINGGORGE_KELPTHAR_FLIGHTPATH"]] = {
		paths = {
			[BZ["Kelp'thar Forest"]] = true,
		},
		faction = "Horde",
		type = "Flightpath",
	}

	zones[transports["KELPTHAR_SEARINGGORGE_FLIGHTPATH"]] = {
		paths = {
			[BZ["Searing Gorge"]] = true,
		},
		faction = "Horde",
		type = "Flightpath",
	}	
	

	-- ZONES, INSTANCES AND COMPLEXES ---------------------------------------------------------

	-- ============== ZONES =======================================================================

	-- Eastern Kingdoms cities and zones --

	zones[BZ["Stormwind City"]] = {
		continent = Eastern_Kingdoms,
		instances = BZ["The Stockade"],
		paths = {
			[BZ["Deeprun Tram"]] = true,
			[BZ["The Stockade"]] = true,
			[BZ["Elwynn Forest"]] = true,
			[transports["STORMWIND_SHATTRATH_PORTAL"]] = true,
			[transports["STORMWIND_BOREANTUNDRA_BOAT"]] = true,
			[transports["STORMWIND_DARKSHORE_BOAT"]] = true,
			[transports["STORMWIND_MOUNTHYJAL_PORTAL"]] = true,
			[transports["STORMWIND_ULDUM_PORTAL"]] = true,
			[transports["STORMWIND_DEEPHOLM_PORTAL"]] = true,
			[transports["STORMWIND_TOLBARAD_PORTAL"]] = true,
		},
		flightnodes = {
			[2] = true,      -- Stormwind, Elwynn (A)
		},
		faction = "Alliance",
		type = "City",
		fishing_low = 1,
		fishing_high = 75,
	}

	zones[BZ["Undercity"]] = {
		continent = Eastern_Kingdoms,
		instances = BZ["Ruins of Lordaeron"],
		paths = {
			[BZ["Tirisfal Glades"]] = true,
			[BZ["Ruins of Lordaeron"]] = true,
			[transports["UNDERCITY_SILVERMOON_TELEPORT"]] = true,
			[transports["UNDERCITY_SHATTRATH_PORTAL"]] = true,
			[transports["UNDERCITY_KELPTHAR_FLIGHTPATH"]] = true,
		},
		flightnodes = {
			[11] = true,     -- Undercity, Tirisfal (H)
		},
		faction = "Horde",
		type = "City",
		fishing_low = 1,		
		fishing_high = 75,
	}

	zones[BZ["Ironforge"]] = {
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Dun Morogh"]] = true,
			[BZ["Deeprun Tram"]] = true,
			[transports["IRONFORGE_SHATTRATH_PORTAL"]] = true,
			[transports["IRONFORGE_KELPTHAR_FLIGHTPATH"]] = true,			
		},
		flightnodes = {
			[6] = true,      -- Ironforge, Dun Morogh (A)
		},
		faction = "Alliance",
		type = "City",
		fishing_low = 1,
		fishing_high = 75,
	}

	zones[BZ["Dun Morogh"]] = {
		low = 1,
		high = 10,
		continent = Eastern_Kingdoms,
		instances = BZ["Gnomeregan"],
		paths = {
			[BZ["Gnomeregan"]] = true,
			[BZ["Ironforge"]] = true,
			[BZ["Loch Modan"]] = true,
		},
		flightnodes = {
			[6] = true,      -- Ironforge, Dun Morogh (A)
			[619] = true,     -- Kharanos, Dun Morogh (A)
			[620] = true,     -- Gol'Bolar Quarry, Dun Morogh (A)
		},		
		faction = "Alliance",
		fishing_low = 1,
		fishing_high = 25,
	}

	zones[BZ["Elwynn Forest"]] = {
		low = 1,
		high = 10,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Westfall"]] = true,
			[BZ["Redridge Mountains"]] = true,
			[BZ["Stormwind City"]] = true,
			[BZ["Duskwood"]] = true,
		},
		flightnodes = {
			[2] = true,      -- Stormwind, Elwynn (A)
			[582] = true,     -- Goldshire, Elwynn (A)
			[589] = true,     -- Eastvale Logging Camp, Elwynn (A)
		},		
		faction = "Alliance",
		fishing_low = 1,
		fishing_high = 25,
	}

	zones[BZ["Tirisfal Glades"]] = {
		low = 1,
		high = 10,
		continent = Eastern_Kingdoms,
		instances = BZ["Scarlet Monastery"],
		paths = {
			[BZ["Western Plaguelands"]] = true,
			[BZ["Undercity"]] = true,
			[BZ["Silverpine Forest"]] = true,
			[BZ["Scarlet Monastery"]] = true,
			[transports["TIRISFAL_ORGRIMMAR_ZEPPELIN"]] = true,
			[transports["TIRISFAL_STRANGLETHORN_ZEPPELIN"]] = true,
			[transports["TIRISFAL_HOWLINGFJORD_ZEPPELIN"]] = true,
		},
		flightnodes = {
			[11] = true,     -- Undercity, Tirisfal (H)
			[384] = true,     -- The Bulwark, Tirisfal (H)
			[460] = true,     -- Brill, Tirisfal Glades (H)			
		},		
		faction = "Horde",
		fishing_low = 1,
		fishing_high = 25,
	}

	zones[BZ["Westfall"]] = {
		low = 10,
		high = 15,
		continent = Eastern_Kingdoms,
		instances = BZ["The Deadmines"],
		paths = {
			[BZ["Duskwood"]] = true,
			[BZ["Elwynn Forest"]] = true,
			[BZ["The Deadmines"]] = true,
		},
		flightnodes = {
			[4] = true,      -- Sentinel Hill, Westfall (A)
			[583] = true,     -- Moonbrook, Westfall (A)
			[584] = true,     -- Furlbrow's Pumpkin Farm, Westfall (A)			
		},
		faction = "Alliance",
		fishing_low = 1,
		fishing_high = 75,
	}

	zones[BZ["Loch Modan"]] = {
		low = 10,
		high = 20,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Wetlands"]] = true,
			[BZ["Badlands"]] = true,
			[BZ["Dun Morogh"]] = true,
			[BZ["Searing Gorge"]] = not isHorde and true or nil,
		},
		flightnodes = {
			[8] = true,     -- Thelsamar, Loch Modan (A)
			[555] = true,     -- Farstrider Lodge, Loch Modan (A)
		},
		faction = "Alliance",
		fishing_low = 1,
		fishing_high = 75,
	}

	zones[BZ["Silverpine Forest"]] = {
		low = 10,
		high = 20,
		continent = Eastern_Kingdoms,
		instances = BZ["Shadowfang Keep"],
		paths = {
			[BZ["Tirisfal Glades"]] = true,
			[BZ["Hillsbrad Foothills"]] = true,
			[BZ["Shadowfang Keep"]] = true,
			[BZ["Ruins of Gilneas"]] = true,
			[BZ["Ruins of Gilneas City"]] = true,
		},
        flightnodes = {
            [10] = true,     -- The Sepulcher, Silverpine Forest (H)
			[645] = true,     -- Forsaken High Command, Silverpine Forest (H)
			[654] = true,     -- The Forsaken Front, Silverpine Forest (H)
			[681] = true,     -- Forsaken Rear Guard, Silverpine Forest (H)
        },
		faction = "Horde",
		fishing_low = 1,
		fishing_high = 75,
	}

	zones[BZ["Redridge Mountains"]] = {
		low = 15,
		high = 20,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Burning Steppes"]] = true,
			[BZ["Elwynn Forest"]] = true,
			[BZ["Duskwood"]] = true,
		},
		flightnodes = {
			[5] = true,      -- Lakeshire, Redridge (A)
			[596] = true,     -- Shalewind Canyon, Redridge (A)
			[615] = true,     -- Camp Everstill, Redridge (A)
		},
		faction = "Alliance",
		fishing_low = 55,
		fishing_high = 150,
	}

	zones[BZ["Duskwood"]] = {
		low = 20,
		high = 25,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Redridge Mountains"]] = true,
			[BZ["Northern Stranglethorn"]] = true,
			[BZ["Westfall"]] = true,
			[BZ["Deadwind Pass"]] = true,
			[BZ["Elwynn Forest"]] = true,
		},
		flightnodes = {
			[12] = true,     -- Darkshire, Duskwood (A)
			[622] = true,     -- Raven Hill, Duskwood (A)
		},
		faction = "Alliance",
		fishing_low = 55,
		fishing_high = 150,
	}

	zones[BZ["Hillsbrad Foothills"]] = {
		low = 20,
		high = 25,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Alterac Valley"]] = true,
			[BZ["The Hinterlands"]] = true,
			[BZ["Arathi Highlands"]] = true,
			[BZ["Silverpine Forest"]] = true,
		},
		flightnodes = {
			[13] = true,    -- Tarren Mill, Hillsbrad (H)
			[14] = true,    -- Southshore, Hillsbrad (A)
			[667] = true,     -- Ruins of Southshore, Hillsbrad (H)
			[668] = true,     -- Southpoint Gate, Hillsbrad (H)
			[669] = true,     -- Eastpoint Tower, Hillsbrad (H)
		},
		fishing_low = 55,
		fishing_high = 150,
	}

	zones[BZ["Wetlands"]] = {
		low = 20,
		high = 25,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Arathi Highlands"]] = true,
			[transports["WETLANDS_DUSTWALLOW_BOAT"]] = true,
			[transports["WETLANDS_HOWLINGFJORD_BOAT"]] = true,
			[BZ["Loch Modan"]] = true,
		},
		flightnodes = {
			[7] = true,      -- Menethil Harbor, Wetlands (A)
			[551] = true,     -- Whelgar's Retreat, Wetlands (A)
			[552] = true,     -- Greenwarden's Grove, Wetlands (A)
			[553] = true,     -- Dun Modr, Wetlands (A)
			[554] = true,     -- Slabchisel's Survey, Wetlands (A)
		},
		fishing_low = 55,
		fishing_high = 150,
	}

	zones[BZ["Arathi Highlands"]] = {
		low = 25,
		high = 30,
		continent = Eastern_Kingdoms,
		instances = BZ["Arathi Basin"],
		paths = {
			[BZ["Wetlands"]] = true,
			[BZ["Hillsbrad Foothills"]] = true,
			[BZ["Arathi Basin"]] = true,
		},
		flightnodes = {
			[16] = true,     -- Refuge Pointe, Arathi (A)
            [17] = true,     -- Hammerfall, Arathi (H)
			[601] = true,     -- Galen's Fall, Arathi (H)
		},
		fishing_low = 130,
		fishing_high = 225,
	}

	-- Cataclysm: split up into Nothern Stranglethorn and The Cape of Stranglethorn, but Stranglethorn Vale still exists as a map
	zones[BZ["Stranglethorn Vale"]] = {
		low = 25,
		high = 35,
		continent = Eastern_Kingdoms,
		instances = BZ["Zul'Gurub"],
		paths = {
			[BZ["Duskwood"]] = true,
			[BZ["Zul'Gurub"]] = true,
			[transports["STRANGLETHORN_ORGRIMMAR_ZEPPELIN"]] = true,
			[transports["STRANGLETHORN_TIRISFAL_ZEPPELIN"]] = true,
			[transports["STRANGLETHORN_BARRENS_BOAT"]] = true,
		},
		flightnodes = {
			[18] = true,     -- Booty Bay, Stranglethorn (H)
			[19] = true,     -- Booty Bay, Stranglethorn (A)
			[20] = true,     -- Grom'gol, Stranglethorn (H)
			[195] = true,    -- Rebel Camp, Stranglethorn Vale (A)
			[590] = true,     -- Fort Livingston, Stranglethorn (A)
			[591] = true,     -- Explorers' League Digsite, Stranglethorn (A)
			[592] = true,     -- Hardwrench Hideaway, Stranglethorn (H)
			[593] = true,     -- Bambala, Stranglethorn (H)			
		},
		fishing_low = 130,
		fishing_high = 225,
	}

	zones[BZ["Northern Stranglethorn"]] = {
		low = 25,
		high = 30,
		continent = Eastern_Kingdoms,
		instances = BZ["Zul'Gurub"],
		paths = {
			[BZ["The Cape of Stranglethorn"]] = true,
			[BZ["Duskwood"]] = true,
			[BZ["Zul'Gurub"]] = true,
			[transports["STRANGLETHORN_ORGRIMMAR_ZEPPELIN"]] = true,
			[transports["TIRISFAL_STRANGLETHORN_ZEPPELIN"]] = true,
		},
		flightnodes = {
			[593] = true,    -- Bambala, Stranglethorn (H)
			[590] = true,    -- Fort Livingston, Stranglethorn (A)
			[195] = true,    -- Rebel Camp, Stranglethorn Vale (A)
			[20] = true,     -- Grom'gol, Stranglethorn (H)
		},
		fishing_low = 130,
		fishing_high = 225,
	}

	zones[BZ["The Cape of Stranglethorn"]] = {
		low = 30,
		high = 35,
		continent = Eastern_Kingdoms,
		paths = {
			[transports["STRANGLETHORN_BARRENS_BOAT"]] = true,
			[BZ["Northern Stranglethorn"]] = true,
		},
		flightnodes = {
			[18] = true,     -- Booty Bay, Stranglethorn (H)
			[19] = true,     -- Booty Bay, Stranglethorn (A)
			[592] = true,    -- Hardwrench Hideaway, Stranglethorn (H)
			[591] = true,    -- Explorers' League Digsite, Stranglethorn (A)
		},
		fishing_low = 130,
		fishing_high = 225,
	}




	zones[BZ["The Hinterlands"]] = {
		low = 30,
		high = 35,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Hillsbrad Foothills"]] = true,
			[BZ["Western Plaguelands"]] = true,
		},
		flightnodes = {
			[43] = true,     -- Aerie Peak, The Hinterlands (A)
			[76] = true,     -- Revantusk Village, The Hinterlands (H)
			[617] = true,     -- Hiri'watha Research Station, The Hinterlands (H)
			[618] = true,     -- Stormfeather Outpost, The Hinterlands (A)
		},
		fishing_low = 205,
		fishing_high = 300,
	}

	zones[BZ["Western Plaguelands"]] = {
		low = 35,
		high = 40,
		continent = Eastern_Kingdoms,
		instances = BZ["Scholomance"],
		paths = {
			[BZ["The Hinterlands"]] = true,
			[BZ["Eastern Plaguelands"]] = true,
			[BZ["Tirisfal Glades"]] = true,
			[BZ["Scholomance"]] = true,
		},
		flightnodes = {
			[66] = true,     -- Chillwind Camp, Western Plaguelands (A)
			[383] = true,     -- Thondoril River, Western Plaguelands (N)
			[649] = true,     -- Andorhal, Western Plaguelands (H)
			[650] = true,     -- Andorhal, Western Plaguelands (A)
			[651] = true,     -- The Menders' Stead, Western Plaguelands (N)
			[672] = true,     -- Hearthglen, Western Plaguelands (N)
		},
		fishing_low = 205,
		fishing_high = 300,
	}

	zones[BZ["Eastern Plaguelands"]] = {
		low = 40,
		high = 45,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Stratholme - Main Gate"]] = true,
			[BZ["Stratholme - Service Entrance"]] = true,
			[BZ["Naxxramas"]] = true,
		},
		paths = {
			[BZ["Western Plaguelands"]] = true,
			[BZ["Stratholme"]] = true,
			[BZ["Naxxramas"]] = true,
		},
		flightnodes = {
			[67] = true,    -- Light's Hope Chapel, Eastern Plaguelands (A)
			[68] = true,    -- Light's Hope Chapel, Eastern Plaguelands (H)
			[85] = true,    -- Northpass Tower, Eastern Plaguelands (N)
			[86] = true,    -- Eastwall Tower, Eastern Plaguelands (N)
			[84] = true,    -- Plaguewood Tower, Eastern Plaguelands (N)
			[87] = true,    -- Crown Guard Tower, Eastern Plaguelands (N)
			[315] = true,     -- Acherus: The Ebon Hold (N)
			[630] = true,     -- Light's Shield Tower, Eastern Plaguelands (N)
		},
		type = "PvP Zone",
		fishing_low = 330,
		fishing_high = 425,
	}

	zones[BZ["Badlands"]] = {
		low = 45,
		high = 48,
		continent = Eastern_Kingdoms,
		instances = BZ["Uldaman"],
		paths = {
			[BZ["Uldaman"]] = true,
			[BZ["Searing Gorge"]] = true,
			[BZ["Loch Modan"]] = true,
		},
		flightnodes = {
			[21] = true,     -- Kargath, Badlands (H)
			[632] = true,     -- Bloodwatcher Point, Badlands (H)
			[633] = true,     -- Dustwind Dig, Badlands (A)
			[634] = true,     -- Dragon's Mouth, Badlands (A)
			[635] = true,     -- Fuselight, Badlands (N)			
		},
	}

	zones[BZ["Searing Gorge"]] = {
		low = 47,
		high = 51,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Blackrock Depths"]] = true,
			[BZ["Blackwing Lair"]] = true,
			[BZ["Molten Core"]] = true,
			[BZ["Blackrock Spire"]] = true,
			[BZ["Blackwing Descent"]] = true,
		},
		paths = {
			[BZ["Blackrock Mountain"]] = true,
			[BZ["Badlands"]] = true,
			[BZ["Loch Modan"]] = not isHorde and true or nil,
			[transports["SEARINGGORGE_KELPTHAR_FLIGHTPATH"]] = true,
		},
		flightnodes = {
			[75] = true,     -- Thorium Point, Searing Gorge (H)
			[74] = true,     -- Thorium Point, Searing Gorge (A)
			[673] = true,     -- Iron Summit, Searing Gorge (N)
		},
		complexes = {
			[BZ["Blackrock Mountain"]] = true,
		},
	}

	zones[BZ["Burning Steppes"]] = {
		low = 50,
		high = 52,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Blackrock Depths"]] = true,
			[BZ["Blackwing Lair"]] = true,
			[BZ["Molten Core"]] = true,
			[BZ["Blackrock Spire"]] = true,
			[BZ["Blackwing Descent"]] = true,
		},
		paths = {
			[BZ["Blackrock Mountain"]] = true,
			[BZ["Redridge Mountains"]] = true,
		},
		flightnodes = {
			[70] = true,     -- Flame Crest, Burning Steppes (H)
			[71] = true,     -- Morgan's Vigil, Burning Steppes (A)
			[675] = true,     -- Flamestar Post, Burning Steppes (N)
			[676] = true,     -- Chiselgrip, Burning Steppes (N)
		},
		complexes = {
			[BZ["Blackrock Mountain"]] = true,
		},
		fishing_low = 330,
		fishing_high = 425,
	}

	zones[BZ["Swamp of Sorrows"]] = {
		low = 52,
		high = 54,
		continent = Eastern_Kingdoms,
		instances = BZ["The Temple of Atal'Hakkar"],
		paths = {
			[BZ["Blasted Lands"]] = true,
			[BZ["Deadwind Pass"]] = true,
			[BZ["The Temple of Atal'Hakkar"]] = true,
		},
		flightnodes = {
			[56] = true,     -- Stonard, Swamp of Sorrows (H)
			[598] = true,     -- Marshtide Watch, Swamp of Sorrows (A)
			[599] = true,     -- Bogpaddle, Swamp of Sorrows (N)
			[600] = true,     -- The Harborage, Swamp of Sorrows (A)
		},
		fishing_low = 130,
		fishing_high = 225,
	}

	zones[BZ["Blasted Lands"]] = {
		low = 55,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = {
			[transports["THE_DARK_PORTAL_BLASTED_LANDS"]] = true,
			[BZ["Swamp of Sorrows"]] = true,
		},
		flightnodes = {
			[45] = true,     -- Nethergarde Keep, Blasted Lands (A)
			[602] = true,     -- Surwich, Blasted Lands (A)
			[603] = true,     -- Sunveil Excursion, Blasted Lands (H)
			[604] = true,     -- Dreadmaul Hold, Blasted Lands (H)			
		},
	}

	zones[BZ["Deadwind Pass"]] = {
		low = 55,
		high = 56,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Duskwood"]] = true,
			[BZ["Swamp of Sorrows"]] = true,
			[BZ["Karazhan"]] = true,
		},
		instances = {
			[BZ["Karazhan"]] = true,
		},
		fishing_low = 330,
		fishing_high = 425,
	}

	-- Kalimdor cities and zones --

	zones[BZ["Orgrimmar"]] = {
		continent = Kalimdor,
		instances = BZ["Ragefire Chasm"],
		paths = {
			[BZ["Durotar"]] = true,
			[BZ["The Barrens"]] = true,
			[BZ["Ragefire Chasm"]] = true,
			[transports["ORGRIMMAR_STRANGLETHORN_ZEPPELIN"]] = true,
			[transports["ORGRIMMAR_TIRISFAL_ZEPPELIN"]] = true,
			[transports["ORGRIMMAR_SHATTRATH_PORTAL"]] = true,
			[transports["ORGRIMMAR_BOREANTUNDRA_ZEPPELIN"]] = true,
			[transports["ORGRIMMAR_MOUNTHYJAL_PORTAL"]] = true,
			[transports["ORGRIMMAR_ULDUM_PORTAL"]] = true,
			[transports["ORGRIMMAR_DEEPHOLM_PORTAL"]] = true,
			[transports["ORGRIMMAR_TOLBARAD_PORTAL"]] = true,
		},
		flightnodes = {
			[23] = true,     -- Orgrimmar, Durotar (H)
		},
		faction = "Horde",
		type = "City",
		fishing_low = 1,
		fishing_high = 75,
	}

	zones[BZ["Thunder Bluff"]] = {
		continent = Kalimdor,
		paths = {
			[BZ["Mulgore"]] = true,
			[transports["THUNDERBLUFF_SHATTRATH_PORTAL"]] = true,			
		},
		flightnodes = {
			[22] = true,     -- Thunder Bluff, Mulgore (H)
		},
		faction = "Horde",
		type = "City",
		fishing_low = 1,
		fishing_high = 75,
	}

	zones[BZ["Darnassus"]] = {
		continent = Kalimdor,
		paths = {
			[transports["DARNASSUS_TELDRASSIL_TELEPORT"]] = true,
			[transports["DARNASSUS_SHATTRATH_PORTAL"]] = true,
		},
		faction = "Alliance",
		type = "City",
		fishing_low = 1,
		fishing_high = 75,
	}

	zones[BZ["Durotar"]] = {
		low = 1,
		high = 10,
		continent = Kalimdor,
		paths = {
			[BZ["The Barrens"]] = true,
			[BZ["Orgrimmar"]] = true,
		},
		flightnodes = {
			[23] = true,     -- Orgrimmar, Durotar (H)
			[536] = true,     -- Sen'jin Village, Durotar (H)
			[537] = true,     -- Razor Hill, Durotar (H)
		},		
		faction = "Horde",
		fishing_low = 1,
		fishing_high = 25,
	}

	zones[BZ["Mulgore"]] = {
		low = 1,
		high = 10,
		continent = Kalimdor,
		paths = {
			[BZ["Thunder Bluff"]] = true,
			[BZ["Southern Barrens"]] = true,
		},
		flightnodes = {
			[22] = true,     -- Thunder Bluff, Mulgore (H)
			[402] = true,     -- Bloodhoof Village, Mulgore (H)
		},		
		faction = "Horde",
		fishing_low = 1,
		fishing_high = 25,
	}

	zones[BZ["Teldrassil"]] = {
		low = 1,
		high = 10,
		continent = Kalimdor,
		paths = {
			[transports["TELDRASSIL_DARNASSUS_TELEPORT"]] = true,
			[transports["TELDRASSIL_DARKSHORE_BOAT"]] = true,
		},
		flightnodes = {
			[27] = true,     -- Rut'theran Village, Teldrassil (A)
			[456] = true,     -- Dolanaar, Teldrassil (A)
			[457] = true,     -- Darnassus, Teldrassil (A)
		},
		faction = "Alliance",
		fishing_low = 1,
		fishing_high = 25,
	}

	zones[BZ["Azshara"]] = {
		low = 10,
		high = 20,
		continent = Kalimdor,
		paths = {
			[BZ["Ashenvale"]] = true,
		},
		flightnodes = {
			[44] = true, -- Valormok, Azshara (H)
			[64] = true, -- Talrendis Point, Azshara (A)
			[613] = true,     -- Southern Rocketway, Azshara (H)
			[614] = true,     -- Northern Rocketway, Azshara (H)
			[683] = true,     -- Valormok, Azshara (H)
		},
		fishing_low = 205,
		fishing_high = 300,
	}

	zones[BZ["Darkshore"]] = {
		low = 10,
		high = 20,
		continent = Kalimdor,
		paths = {
			[BZ["Ashenvale"]] = true,
			[transports["DARKSHORE_STORMWIND_BOAT"]] = true,
			[transports["DARKSHORE_TELDRASSIL_BOAT"]] = true,
			[transports["DARKSHORE_AZUREMYST_BOAT"]] = true,
		},
		flightnodes = {
			[26] = true,     -- Auberdine, Darkshore (A)
			[339] = true,     -- Grove of the Ancients, Darkshore (A)
		},
		faction = "Alliance",
		fishing_low = 1,
		fishing_high = 75,
	}

	zones[BZ["The Barrens"]] = {
		low = 10,
		high = 20,
		continent = Kalimdor,
		instances = {
			[BZ["Wailing Caverns"]] = true,
			[BZ["Warsong Gulch"]] = isHorde and true or nil,
		},
		paths = {
			[BZ["Southern Barrens"]] = true,
			[BZ["Ashenvale"]] = true,
			[BZ["Durotar"]] = true,
			[BZ["Stonetalon Mountains"]] = true,
			[BZ["Wailing Caverns"]] = true,
			[BZ["Warsong Gulch"]] = isHorde and true or nil,
			[transports["BARRENS_STRANGLETHORN_BOAT"]] = true,
		},
		flightnodes = {
			[80] = true,    -- Ratchet, The Barrens (N)
			[25] = true,    -- The Crossroads, The Barrens (H)
			[458] = true,     -- Nozzlepot's Outpost, The Barrens (H)
		},
		fishing_low = 1,
		fishing_high = 75,
	}


	zones[BZ["Ashenvale"]] = {
		low = 20,
		high = 25,
		continent = Kalimdor,
		instances = {
			[BZ["Blackfathom Deeps"]] = true,
			[BZ["Warsong Gulch"]] = not isHorde and true or nil,
		},
		paths = {
			[BZ["Azshara"]] = true,
			[BZ["The Barrens"]] = true,
			[BZ["Blackfathom Deeps"]] = true,
			[BZ["Warsong Gulch"]] = not isHorde and true or nil,
			[BZ["Felwood"]] = true,
			[BZ["Darkshore"]] = true,
			[BZ["Stonetalon Mountains"]] = true,
		},
		flightnodes = {
			[61] = true,     -- Splintertree Post, Ashenvale (H)
			[28] = true,     -- Astranaar, Ashenvale (A)
			[58] = true,     -- Zoram'gar Outpost, Ashenvale (H)
			[167] = true,    -- Forest Song, Ashenvale (A)
			[338] = true,     -- Blackfathom Camp, Ashenvale (A)
			[350] = true,     -- Hellscream's Watch, Ashenvale (H)
			[351] = true,     -- Stardust Spire, Ashenvale (A)
			[354] = true,     -- The Mor'Shan Ramparts, Ashenvale (H)
			[356] = true,     -- Silverwind Refuge, Ashenvale (H)
		},
		fishing_low = 55,
		fishing_high = 150,
	}

	zones[BZ["Stonetalon Mountains"]] = {
		low = 25,
		high = 30,
		continent = Kalimdor,
		paths = {
			[BZ["Desolace"]] = true,
			[BZ["The Barrens"]] = true,
			[BZ["Ashenvale"]] = true,
		},
		flightnodes = {
			[33] = true,     -- Stonetalon Peak, Stonetalon Mountains (A)
			[29] = true,     -- Sun Rock Retreat, Stonetalon Mountains (H)
		    [360] = true,     -- Cliffwalker Post, Stonetalon Mountains (H)
			[361] = true,     -- Windshear Hold, Stonetalon Mountains (A)
			[362] = true,     -- Krom'gar Fortress, Stonetalon Mountains (H)
			[363] = true,     -- Malaka'jin, Stonetalon Mountains (H)
			[364] = true,     -- Northwatch Expedition Base Camp, Stonetalon Mountains (A)
			[365] = true,     -- Farwatcher's Glen, Stonetalon Mountains (A)
			[540] = true,     -- The Sludgewerks, Stonetalon Mountains (H)
			[541] = true,     -- Mirkfallon Post, Stonetalon Mountains (A)
		},
		fishing_low = 55,
		fishing_high = 150,
	}

	zones[BZ["Desolace"]] = {
		low = 30,
		high = 35,
		continent = Kalimdor,
		instances = BZ["Maraudon"],
		paths = {
			[BZ["Feralas"]] = true,
			[BZ["Stonetalon Mountains"]] = true,
			[BZ["Maraudon"]] = true,
		},
		flightnodes = {
			[38] = true,     -- Shadowprey Village, Desolace (H)
			[37] = true,     -- Nijel's Point, Desolace (A)
		    [366] = true,     -- Furien's Post, Desolace (H)
			[367] = true,     -- Thargad's Camp, Desolace (A)
			[368] = true,     -- Karnum's Glade, Desolace (N)
			[369] = true,     -- Thunk's Abode, Desolace (N)
			[370] = true,     -- Ethel Rethor, Desolace (N)
		},
		fishing_low = 130,
		fishing_high = 225,
	}

	zones[BZ["Dustwallow Marsh"]] = {
		low = 35,
		high = 40,
		continent = Kalimdor,
		instances = BZ["Onyxia's Lair"],
		paths = {
			[BZ["Onyxia's Lair"]] = true,
			[BZ["Southern Barrens"]] = true,
			[transports["DUSTWALLOW_WETLANDS_BOAT"]] = true,
		},
		flightnodes = {
			[55] = true,     -- Brackenwall Village, Dustwallow Marsh (H)
			[32] = true,     -- Theramore, Dustwallow Marsh (A)
			[179] = true,    -- Mudsprocket, Dustwallow Marsh (N)
		},
		fishing_low = 130,
		fishing_high = 225,
	}

	zones[BZ["Feralas"]] = {
		low = 35,
		high = 40,
		continent = Kalimdor,
		instances = {
			[BZ["Dire Maul - East"]] = true,
			[BZ["Dire Maul - North"]] = true,
			[BZ["Dire Maul - West"]] = true,
		},
		paths = {
			[BZ["Thousand Needles"]] = true,
			[BZ["Desolace"]] = true,
			[BZ["Dire Maul"]] = true,
		},
		flightnodes = {
			[41] = true,     -- Feathermoon, Feralas (A)
			[42] = true,     -- Camp Mojache, Feralas (H)
			[31] = true,     -- Thalanaar, Feralas (A)
			[565] = true,     -- Dreamer's Rest, Feralas (A)
			[567] = true,     -- Tower of Estulan, Feralas (A)
			[568] = true,     -- Camp Ataya, Feralas (H)
			[569] = true,     -- Stonemaul Hold, Feralas (H)
		},
		complexes = {
			[BZ["Dire Maul"]] = true,
		},
		fishing_low = 205,
		fishing_high = 300,
	}

	zones[BZ["Thousand Needles"]] = {
		low = 40,
		high = 45,
		continent = Kalimdor,
		paths = {
			[BZ["Feralas"]] = true,
			[BZ["Southern Barrens"]] = true,
			[BZ["Tanaris"]] = true,
		},
		flightnodes = {
			[30] = true,     -- Freewind Post, Thousand Needles (H)
			[513] = true,     -- Fizzle & Pozzik's Speedbarge, Thousand Needles (N)
		},
		fishing_low = 130,
		fishing_high = 225,
	}

	zones[BZ["Felwood"]] = {
		low = 45,
		high = 50,
		continent = Kalimdor,
		paths = {
			[BZ["Winterspring"]] = true,
			[BZ["Moonglade"]] = true,
			[BZ["Ashenvale"]] = true,
		},
		flightnodes = {
			[48] = true,     -- Bloodvenom Post, Felwood (H)
			[65] = true,     -- Talonbranch Glade, Felwood (A)
			[166] = true,    -- Emerald Sanctuary, Felwood (N)
			[594] = true,     -- Whisperwind Grove, Felwood (N)
			[595] = true,     -- Wildheart Point, Felwood (N)
			[597] = true,     -- Irontree Clearing, Felwood (H)
		},
		fishing_low = 205,
		fishing_high = 300,
	}

	zones[BZ["Tanaris"]] = {
		low = 45,
		high = 50,
		continent = Kalimdor,
		instances = 
		{
			[BZ["Zul'Farrak"]] = true,
			[BZ["Old Hillsbrad Foothills"]] = true,
			[BZ["The Black Morass"]] = true,
			[BZ["Hyjal Summit"]] = true,
			[BZ["Dragon Soul"]] = true,
			[BZ["End Time"]] = true,
			[BZ["Well of Eternity"]] = true,
			[BZ["Hour of Twilight"]] = true,
		},
		paths = {
			[BZ["Thousand Needles"]] = true,
			[BZ["Un'Goro Crater"]] = true,
			[BZ["Zul'Farrak"]] = true,
			[BZ["Caverns of Time"]] = true,
			[BZ["Uldum"]] = true,
		},
		flightnodes = {
			[39] = true,     -- Gadgetzan, Tanaris (A)
			[40] = true,     -- Gadgetzan, Tanaris (H)
			[531] = true,     -- Dawnrise Expedition, Tanaris (H)
			[532] = true,     -- Gunstan's Dig, Tanaris (A)
			[539] = true,     -- Bootlegger Outpost, Tanaris (N)
		},
		complexes = {
			[BZ["Caverns of Time"]] = true,
		},		
		fishing_low = 205,
		fishing_high = 300,
	}

	zones[BZ["Un'Goro Crater"]] = {
		low = 50,
		high = 55,
		continent = Kalimdor,
		paths = {
			[BZ["Silithus"]] = true,
			[BZ["Tanaris"]] = true,
		},
		flightnodes = {
			[79] = true,     -- Marshal's Refuge, Un'Goro Crater (N)
			[386] = true,     -- Mossy Pile, Un'Goro Crater (N)
		},
		fishing_low = 205,
		fishing_high = 300,
	}

	zones[BZ["Winterspring"]] = {
		low = 50,
		high = 55,
		continent = Kalimdor,
		paths = {
			[BZ["Felwood"]] = true,
			[BZ["Moonglade"]] = true,
			[BZ["Mount Hyjal"]] = true,
		},
		flightnodes = {
			[53] = true,    -- Everlook, Winterspring (H)
			[52] = true,    -- Everlook, Winterspring (A)
		},
		fishing_low = 330,
		fishing_high = 425,
	}

	zones[BZ["Silithus"]] = {
		low = 55,
		high = 60,
		continent = Kalimdor,
		instances = {
			[BZ["Ahn'Qiraj Temple"]] = true,
			[BZ["Ruins of Ahn'Qiraj"]] = true,
		},
		paths = {
			[BZ["Un'Goro Crater"]] = true,
			[BZ["Ahn'Qiraj: The Fallen Kingdom"]] = true,
		},
		flightnodes = {
			[73] = true,    -- Cenarion Hold, Silithus (A)
			[72] = true,    -- Cenarion Hold, Silithus (H)
		},
		complexes = {
			[BZ["Ahn'Qiraj: The Fallen Kingdom"]] = true,
		},
		type = "PvP Zone",
		fishing_low = 330,
		fishing_high = 425,
	}

	zones[BZ["Moonglade"]] = {
		continent = Kalimdor,
		low = 15,
		high = 15,
		paths = {
			[BZ["Felwood"]] = true,
		},
		flightnodes = {
			[49] = true,    -- Moonglade (A)
			[69] = true,    -- Moonglade (H)
			[62] = true,    -- Nighthaven, Moonglade (A)
			[63] = true,    -- Nighthaven, Moonglade (H)
		},
		fishing_low = 205,
		fishing_high = 300,
	}




	-- The Burning Crusade Cities -------------------------------------
	
	zones[BZ["Silvermoon City"]] = {
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Eversong Woods"]] = true,
			[BZ["Undercity"]] = true,
			[transports["SILVERMOON_UNDERCITY_TELEPORT"]] = true,
			[transports["SILVERMOON_SHATTRATH_PORTAL"]] = true,
		},
		flightnodes = {
			[82] = true,    -- Silvermoon City (H)
		},
		faction = "Horde",
		type = "City",
		fishing_low = 1,
		fishing_high = 75,
	}

	zones[BZ["The Exodar"]] = {
		continent = Kalimdor,
		paths = {
			[BZ["Azuremyst Isle"]] = true,
			[transports["EXODAR_SHATTRATH_PORTAL"]] = true,
		},
		flightnodes = {
			[94] = true,    -- The Exodar (A)
		},		
		faction = "Alliance",
		type = "City",
		fishing_low = 1,
		fishing_high = 75,
	}

	zones[BZ["Shattrath City"]] = {
		continent = Outland,
		paths = {
			[BZ["Nagrand"]] = true,
			[BZ["Terokkar Forest"]] = true,
			[transports["SHATTRATH_THUNDERBLUFF_PORTAL"]] = true,
			[transports["SHATTRATH_STORMWIND_PORTAL"]] = true,
			[transports["SHATTRATH_UNDERCITY_PORTAL"]] = true,
			[transports["SHATTRATH_SILVERMOON_PORTAL"]] = true,
			[transports["SHATTRATH_EXODAR_PORTAL"]] = true,
			[transports["SHATTRATH_DARNASSUS_PORTAL"]] = true,
			[transports["SHATTRATH_ORGRIMMAR_PORTAL"]] = true,
			[transports["SHATTRATH_IRONFORGE_PORTAL"]] = true,
			[transports["SHATTRATH_QUELDANAS_PORTAL"]] = true,
		},
		flightnodes = {
			[128] = true,    -- Shattrath, Terokkar Forest (N)
		},
		type = "City",
		fishing_low = 1,
		fishing_high = 75,
	}



	-- The Burning Crusade Zones --------------------------------------
	
	-- Blood Elf zones
	zones[BZ["Eversong Woods"]] = {
		low = 1,
		high = 10,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Silvermoon City"]] = true,
			[BZ["Ghostlands"]] = true,
		},
		flightnodes = {
			[82] = true,    -- Silvermoon City (H)
			[625] = true,     -- Fairbreeze Village, Eversong Woods (H)
			[631] = true,     -- Falconwing Square, Eversong Woods (H)
		},	
		faction = "Horde",
		fishing_low = 1,
		fishing_high = 25,
	}
	
	zones[BZ["Ghostlands"]] = {
		low = 10,
		high = 20,
		continent = Eastern_Kingdoms,
		instances = BZ["Zul'Aman"],
		paths = {
			[BZ["Eastern Plaguelands"]] = true,
			[BZ["Zul'Aman"]] = true,
			[BZ["Eversong Woods"]] = true,
		},
		flightnodes = {
			[83] = true,    -- Tranquillien, Ghostlands (H)
			[205] = true,    -- Zul'Aman, Ghostlands (N)
		},
		faction = "Horde",
		fishing_low = 1,
		fishing_high = 25,
	}

	-- Dranei zones
	zones[BZ["Azuremyst Isle"]] = {
		low = 1,
		high = 10,
		continent = Kalimdor,
		paths = {
			[BZ["The Exodar"]] = true,
			[BZ["Bloodmyst Isle"]] = true,
			[transports["AZUREMYST_DARKSHORE_BOAT"]] = true,
		},
		flightnodes = {
			[94] = true,    -- The Exodar (A)
			[624] = true,     -- Azure Watch, Azuremyst Isle (A)
		},
		faction = "Alliance",
		fishing_low = 1,
		fishing_high = 25,
	}

	zones[BZ["Bloodmyst Isle"]] = {
		low = 10,
		high = 20,
		continent = Kalimdor,
		paths = {
			[BZ["Azuremyst Isle"]] = true,
		},
		flightnodes = {
			[93] = true,    -- Blood Watch, Bloodmyst Isle (A)
		},
		faction = "Alliance",
		fishing_low = 1,
		fishing_high = 25,
	}

	-- Outland zones
	zones[BZ["Hellfire Peninsula"]] = {
		low = 58,
		high = 63,
		continent = Outland,
		instances = {
			[BZ["The Blood Furnace"]] = true,
			[BZ["Hellfire Ramparts"]] = true,
			[BZ["Magtheridon's Lair"]] = true,
			[BZ["The Shattered Halls"]] = true,
		},
		paths = {
			[BZ["Zangarmarsh"]] = true,
			[transports["THE_DARK_PORTAL_HELLFIRE"]] = true,
			[BZ["Terokkar Forest"]] = true,
			[BZ["Hellfire Citadel"]] = true,
		},
		complexes = {
			[BZ["Hellfire Citadel"]] = true,
		},
		flightnodes = {
			[99] = true,     -- Thrallmar, Hellfire Peninsula (H)
			[101] = true,    -- Temple of Telhamat, Hellfire Peninsula (A)
			[141] = true,    -- Spinebreaker Ridge, Hellfire Peninsula (H)
			[149] = true,    -- Shatter Point, Hellfire Peninsula (A)
			[102] = true,    -- Falcon Watch, Hellfire Peninsula (H)
			[100] = true,    -- Honor Hold, Hellfire Peninsula (A)
			[129] = true,	 -- The Dark Portal, Hellfire Peninsula (A)
			[130] = true,	 -- The Dark Portal, Hellfire Peninsula (H)
		},
        type = "PvP Zone",
		fishing_low = 280,
		fishing_high = 375,		
	}

	zones[BZ["Zangarmarsh"]] = {
		low = 60,
		high = 64,
		continent = Outland,
		instances = {
			[BZ["The Underbog"]] = true,
			[BZ["Serpentshrine Cavern"]] = true,
			[BZ["The Steamvault"]] = true,
			[BZ["The Slave Pens"]] = true,
		},
		paths = {
			[BZ["Blade's Edge Mountains"]] = true,
			[BZ["Terokkar Forest"]] = true,
			[BZ["Nagrand"]] = true,
			[BZ["Hellfire Peninsula"]] = true,
			[BZ["Coilfang Reservoir"]] = true,
		},
		complexes = {
			[BZ["Coilfang Reservoir"]] = true,
		},		
		flightnodes = {
			[118] = true,    -- Zabra'jin, Zangarmarsh (H)
			[164] = true,    -- Orebor Harborage, Zangarmarsh (A)
			[151] = true,    -- Swamprat Post, Zangarmarsh (H)
			[117] = true,    -- Telredor, Zangarmarsh (A)
		},
        type = "PvP Zone",
		fishing_low = 305,
		fishing_high = 400,
	}
	
	zones[BZ["Terokkar Forest"]] = {
		low = 62,
		high = 65,
		continent = Outland,
		instances = {
			[BZ["Mana-Tombs"]] = true,
			[BZ["Sethekk Halls"]] = true,
			[BZ["Shadow Labyrinth"]] = true,
			[BZ["Auchenai Crypts"]] = true,
		},
		paths = {
			[BZ["Shadowmoon Valley"]] = true,
			[BZ["Zangarmarsh"]] = true,
			[BZ["Shattrath City"]] = true,
			[BZ["Hellfire Peninsula"]] = true,
			[BZ["Nagrand"]] = true,
			[BZ["Auchindoun"]] = true,
		},
		complexes = {
			[BZ["Auchindoun"]] = true,
		},			
		flightnodes = {
			[127] = true,    -- Stonebreaker Hold, Terokkar Forest (H)
			[128] = true,    -- Shattrath, Terokkar Forest (N)
			[121] = true,    -- Allerian Stronghold, Terokkar Forest (A)
		},
        type = "PvP Zone",
		fishing_low = 355,
		fishing_high = 450,
	}

	zones[BZ["Nagrand"]] = {
		low = 64,
		high = 67,
		continent = Outland,
		instances = {
			[BZ["Nagrand Arena"]] = true,
		},
		paths = {
			[BZ["Zangarmarsh"]] = true,
			[BZ["Shattrath City"]] = true,
			[BZ["Terokkar Forest"]] = true,
			[BZ["Nagrand Arena"]] = true,
		},
		flightnodes = {
			[120] = true,    -- Garadar, Nagrand (H)
			[119] = true,    -- Telaar, Nagrand (A)
		},
        type = "PvP Zone",
		fishing_low = 380,
		fishing_high = 475,
	}

	zones[BZ["Blade's Edge Mountains"]] = {
		low = 65,
		high = 68,
		continent = Outland,
		instances = {
			[BZ["Gruul's Lair"]] = true,
			[BZ["Blade's Edge Arena"]] = true,
		},
		paths = {
			[BZ["Netherstorm"]] = true,
			[BZ["Zangarmarsh"]] = true,
			[BZ["Gruul's Lair"]] = true,
			[BZ["Blade's Edge Arena"]] = true,
		},
		flightnodes = {
			[126] = true,    -- Thunderlord Stronghold, Blade's Edge Mountains (H)
			[163] = true,    -- Mok'Nathal Village, Blade's Edge Mountains (H)
			[160] = true,    -- Evergrove, Blade's Edge Mountains (N)
			[125] = true,    -- Sylvanaar, Blade's Edge Mountains (A)
			[156] = true,    -- Toshley's Station, Blade's Edge Mountains (A)
		},
		-- No fishable waters
	}	

	zones[BZ["Shadowmoon Valley"]] = {
		low = 67,
		high = 70,
		continent = Outland,
		instances = {
			[BZ["Black Temple"]] = true,
		},
		paths = {
			[BZ["Terokkar Forest"]] = true,
			[BZ["Black Temple"]] = true,
		},
		flightnodes = {
			[124] = true,     -- Wildhammer Stronghold, Shadowmoon Valley (A)
			[123] = true,     -- Shadowmoon Village, Shadowmoon Valley (H)
			[140] = true,     -- Altar of Sha'tar, Shadowmoon Valley (N)
			[159] = true,     -- Sanctum of the Stars, Shadowmoon Valley (N)			
		},
		fishing_low = 280,
		fishing_high = 375,
	}
	
	zones[BZ["Netherstorm"]] = {
		low = 67,
		high = 70,
		continent = Outland,
		instances = {
			[BZ["The Mechanar"]] = true,
			[BZ["The Botanica"]] = true,
			[BZ["The Arcatraz"]] = true,
			[BZ["Tempest Keep"]] = true, -- = The Eye
		},
		paths = {
			[BZ["Blade's Edge Mountains"]] = true,
			[BZ["The Mechanar"]] = true,
			[BZ["The Botanica"]] = true,
			[BZ["The Arcatraz"]] = true,
			[BZ["Tempest Keep"]] = true,
		},
		complexes = {
--			[BZ["Tempest Keep"]] = true,
		},		
		flightnodes = {
			[150] = true,    -- Cosmowrench, Netherstorm (N)
			[122] = true,    -- Area 52, Netherstorm (N)
			[139] = true,    -- The Stormspire, Netherstorm (N)
		},
		fishing_low = 380,
		fishing_high = 475,
	}	
	
	
	
	-- TBC 2.4 zone
	zones[BZ["Isle of Quel'Danas"]] = {
		continent = Eastern_Kingdoms,
		low = 70,
		high = 70,
		instances = {
			[BZ["Magister's Terrace"]] = true,
			[BZ["Sunwell Plateau"]] = true,
		},
		paths = {
			[BZ["Magister's Terrace"]] = true,
			[BZ["Sunwell Plateau"]] = true,
		},		
--		flightnodes = {
--			[00] = true,    -- TODO
--		},
		fishing_low = 355,
		fishing_high = 450,
	}




	-- Wrath of the Lich King Cities
	
	zones[BZ["Dalaran"]] = {
		continent = Northrend,
		paths = {
			[BZ["The Violet Hold"]] = true,
			[transports["DALARAN_CRYSTALSONG_TELEPORT"]] = true,
			[transports["DALARAN_COT_PORTAL"]] = true,
			[transports["DALARAN_STORMWIND_PORTAL"]] = true,
			[transports["DALARAN_ORGRIMMAR_PORTAL"]] = true,
			[transports["DALARAN_ICECROWN_FLIGHTPATH"]] = true,
			[transports["DALARAN_WINTERGRASP_FLIGHTPATH"]] = true,
		},
		instances = {
			[BZ["The Violet Hold"]] = true,
--			[BZ["Dalaran Arena"]] = true,
		},
		flightnodes = {
			[310] = true,     -- Dalaran (N)
		},		
		type = "City",
		texture = "Dalaran",
		faction = "Sanctuary",
		fishing_low = 450,  -- TODO: check
		fishing_high = 525,
	}	



	-- Wrath of the Lich King Zones

	zones[BZ["Borean Tundra"]] = {
		low = 68,
		high = 72,
		continent = Northrend,
		paths = {
			[BZ["Coldarra"]] = true,
			[BZ["Dragonblight"]] = true,
			[BZ["Sholazar Basin"]] = true,
			[transports["BOREANTUNDRA_STORMWIND_BOAT"]] = true,
			[transports["BOREANTUNDRA_ORGRIMMAR_ZEPPELIN"]] = true,
			[transports["DRAGONBLIGHT_BOREANTUNDRA_BOAT"]] = true,
		},
		instances = {
			[BZ["The Nexus"]] = true,
			[BZ["The Oculus"]] = true,
			[BZ["The Eye of Eternity"]] = true,
		},
		complexes = {
			[BZ["Coldarra"]] = true,
		},
		flightnodes = {
			[226] = true,     -- Transitus Shield, Coldarra (N)
			[234] = true,     -- Coldarra Ledge, Coldarra (H)
			[245] = true,     -- Valiance Keep, Borean Tundra (A)
			[246] = true,     -- Fizzcrank Airstrip, Borean Tundra (A)
			[257] = true,     -- Warsong Hold, Borean Tundra (H)
			[258] = true,     -- Taunka'le Village, Borean Tundra (H)
			[259] = true,     -- Bor'gorok Outpost, Borean Tundra (H)
			[289] = true,     -- Amber Ledge, Borean Tundra (N)
			[296] = true,     -- Unu'pe, Borean Tundra (N)
		},				
		fishing_low = 370,  -- TODO: check
		fishing_high = 475,
	}

	zones[BZ["Howling Fjord"]] = {
		low = 68,
		high = 72,
		continent = Northrend,
		paths = {
			[BZ["Grizzly Hills"]] = true,
			[transports["HOWLINGFJORD_WETLANDS_BOAT"]] = true,
			[transports["HOWLINGFJORD_TIRISFAL_ZEPPELIN"]] = true,
			[transports["HOWLINGFJORD_DRAGONBLIGHT_BOAT"]] = true,
			[BZ["Utgarde Keep"]] = true,
			[BZ["Utgarde Pinnacle"]] = true,
		},
		instances = {
			[BZ["Utgarde Keep"]] = true,
			[BZ["Utgarde Pinnacle"]] = true,
		},
		flightnodes = {
			[183] = true,     -- Valgarde Port, Howling Fjord (A)
			[184] = true,     -- Fort Wildervar, Howling Fjord (A)
			[185] = true,     -- Westguard Keep, Howling Fjord (A)
			[190] = true,     -- New Agamand, Howling Fjord (H)
			[191] = true,     -- Vengeance Landing, Howling Fjord (H)
			[192] = true,     -- Camp Winterhoof, Howling Fjord (H)
			[248] = true,     -- Apothecary Camp, Howling Fjord (H)
			[295] = true,     -- Kamagua, Howling Fjord (N)
		},				
		fishing_low = 370,  -- TODO: check
		fishing_high = 475,
	}

	zones[BZ["Dragonblight"]] = {
		low = 71,
		high = 75,
		continent = Northrend,
		paths = {
			[BZ["Borean Tundra"]] = true,
			[BZ["Grizzly Hills"]] = true,
			[BZ["Zul'Drak"]] = true,
			[BZ["Crystalsong Forest"]] = true,
			[transports["BOREANTUNDRA_DRAGONBLIGHT_BOAT"]] = true,
			[transports["DRAGONBLIGHT_HOWLINGFJORD_BOAT"]] = true,
			[BZ["Azjol-Nerub"]] = true,
			[BZ["Ahn'kahet: The Old Kingdom"]] = true,
			[BZ["Naxxramas"]] = true,
			[BZ["The Obsidian Sanctum"]] = true,
			[BZ["Strand of the Ancients"]] = true,
		},
		instances = {
			[BZ["Azjol-Nerub"]] = true,
			[BZ["Ahn'kahet: The Old Kingdom"]] = true,
			[BZ["Naxxramas"]] = true,
			[BZ["The Obsidian Sanctum"]] = true,
			[BZ["Strand of the Ancients"]] = true,
		},
		flightnodes = {
			[244] = true,     -- Wintergarde Keep, Dragonblight (A)
			[247] = true,     -- Stars' Rest, Dragonblight (A)
			[251] = true,     -- Fordragon Hold, Dragonblight (A)
			[252] = true,     -- Wyrmrest Temple, Dragonblight (N)
			[254] = true,     -- Venomspite, Dragonblight (H)
			[256] = true,     -- Agmar's Hammer, Dragonblight (H)
			[260] = true,     -- Kor'koron Vanguard, Dragonblight (H)
			[294] = true,     -- Moa'ki, Dragonblight (N)
		},				
		fishing_low = 370,  -- TODO: check
		fishing_high = 475,
	}

	zones[BZ["Grizzly Hills"]] = {
		low = 73,
		high = 75,
		continent = Northrend,
		paths = {
			[BZ["Howling Fjord"]] = true,
			[BZ["Dragonblight"]] = true,
			[BZ["Zul'Drak"]] = true,
			[BZ["Drak'Tharon Keep"]] = true,
		},
		instances = BZ["Drak'Tharon Keep"],
		flightnodes = {
			[249] = true,     -- Camp Oneqwah, Grizzly Hills (H)
			[250] = true,     -- Conquest Hold, Grizzly Hills (H)
			[253] = true,     -- Amberpine Lodge, Grizzly Hills (A)
			[255] = true,     -- Westfall Brigade, Grizzly Hills (A)
		},				
		fishing_low = 370,  -- TODO: check
		fishing_high = 475,
	}

	zones[BZ["Zul'Drak"]] = {
		low = 74,
		high = 76,
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
		flightnodes = {
			[304] = true,     -- The Argent Stand, Zul'Drak (N)
			[305] = true,     -- Ebon Watch, Zul'Drak (N)
			[306] = true,     -- Light's Breach, Zul'Drak (N)
			[307] = true,     -- Zim'Torga, Zul'Drak (N)
			[290] = true,     -- Argent Stand, Zul'Drak (H)
			[331] = true,     -- Gundrak, Zul'Drak (N)
		},				
		fishing_low = 370,  -- TODO: check
		fishing_high = 475,
	}

	zones[BZ["Sholazar Basin"]] = {
		low = 76,
		high = 78,
		continent = Northrend,
		paths = BZ["Borean Tundra"],
		flightnodes = {
			[308] = true,     -- River's Heart, Sholazar Basin (N)
			[309] = true,     -- Nesingwary Base Camp, Sholazar Basin (N)
		},				
		fishing_low = 450,  -- TODO: check
		fishing_high = 525,
	}

	zones[BZ["Crystalsong Forest"]] = {
		low = 77,
		high = 80,
		continent = Northrend,
		paths = {
			[transports["CRYSTALSONG_DALARAN_TELEPORT"]] = true,
			[BZ["Dragonblight"]] = true,
			[BZ["Zul'Drak"]] = true,
			[BZ["The Storm Peaks"]] = true,
		},
		flightnodes = {
			[336] = true,     -- Windrunner's Overlook, Crystalsong Forest (A)
			[337] = true,     -- Sunreaver's Command, Crystalsong Forest (H)
		},				
		fishing_low = 425,  -- TODO: check
		fishing_high = 500,
	}

	zones[BZ["The Storm Peaks"]] = {
		low = 77,
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
		flightnodes = {
			[320] = true,     -- K3, The Storm Peaks (N)
			[321] = true,     -- Frosthold, The Storm Peaks (A)
			[322] = true,     -- Dun Nifflelem, The Storm Peaks (N)
			[323] = true,     -- Grom'arsh Crash-Site, The Storm Peaks (H)
			[324] = true,     -- Camp Tunka'lo, The Storm Peaks (H)
			[326] = true,     -- Ulduar, The Storm Peaks (N)
			[327] = true,     -- Bouldercrag's Refuge, The Storm Peaks (N)
		},				
		fishing_low = 475,  -- TODO: check
		fishing_high = 550,
	}

	zones[BZ["Icecrown"]] = {
		low = 77,
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
			[BZ["Isle of Conquest"]] = true,
			[transports["ICECROWN_DALARAN_FLIGHTPATH"]] = true,
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
		flightnodes = {
			[325] = true,     -- Death's Rise, Icecrown (N)
			[333] = true,     -- The Shadow Vault, Icecrown (H)
			[334] = true,     -- The Argent Vanguard, Icecrown (N)
			[335] = true,     -- Crusaders' Pinnacle, Icecrown (N)
			[340] = true,     -- Argent Tournament Grounds, Icecrown (N)
		},				
		fishing_low = 475,  -- TODO: check
		fishing_high = 550,
	}

	zones[BZ["Hrothgar's Landing"]] = { 
		low = 77,
		high = 80,
		paths = BZ["Icecrown"],
		continent = Northrend,
		fishing_low = 475,  -- TODO: check
		fishing_high = 550,
	}

	zones[BZ["Wintergrasp"]] = {
		low = 77,
		high = 80,
		continent = Northrend,
		paths = {
			[BZ["Vault of Archavon"]] = true,
			[transports["WINTERGRASP_DALARAN_FLIGHTPATH"]] = true,
		},
		instances = BZ["Vault of Archavon"],
		type = "PvP Zone",
		flightnodes = {
			[303] = true,     -- Valiance Landing Camp, Wintergrasp (A)
			[332] = true,     -- Warsong Camp, Wintergrasp (H)
		},						
		fishing_low = 450,  -- TODO: check
		fishing_high = 550,
	}

--	zones[BZ["The Frozen Sea"]] = {
--		continent = Northrend,
--		fishing_low = 450,  -- TODO: check
--		fishing_high = 575,
--	}


	-- Cataclysm zones --------------------------

	zones[BZ["Mount Hyjal"]] = {
		low = 80,
		high = 82,
		continent = Kalimdor,
		paths = {
			[BZ["Winterspring"]] = true,
			[transports["MOUNTHYJAL_ORGRIMMAR_PORTAL"]] = true,
			[transports["MOUNTHYJAL_STORMWIND_PORTAL"]] = true,
			[transports["MOUNTHYJAL_MOLTENFRONT_PORTAL"]] = true,
			[BZ["Firelands"]] = true,
		},
		flightnodes = {
			[558] = true,    -- Grove of Aessina, Hyjal (N)
			[616] = true,    -- Gates of Sothann, Hyjal (N)
			[781] = true,    -- Sanctuary of Malorne, Hyjal (N)
			[559] = true,    -- Nordrassil, Hyjal (N)
			[557] = true,    -- Shrine of Aviana, Hyjal (N)
		},
		instances = {
			[BZ["Firelands"]] = true,
		},
		fishing_low = 450,
		fishing_high = 575,
	}

	zones[BZ["Molten Front"]] = {
		low = 85,
		high = 85,
		paths = {
			[transports["MOLTENFRONT_MOUNTHYJAL_PORTAL"]] = true,
		},
		continent = Kalimdor,
	}

	zones[BZ["Uldum"]] = {
		low = 83,
		high = 84,
		continent = Kalimdor,
		paths = {
			[BZ["Tanaris"]] = true,
			[BZ["Halls of Origination"]] = true,
			[BZ["Lost City of the Tol'vir"]] = true,
			[BZ["The Vortex Pinnacle"]] = true,
			[BZ["Throne of the Four Winds"]] = true,
		},
		instances = {
			[BZ["Halls of Origination"]] = true,
			[BZ["Lost City of the Tol'vir"]] = true,
			[BZ["The Vortex Pinnacle"]] = true,
			[BZ["Throne of the Four Winds"]] = true,
		},
		flightnodes = {
			[653] = true,    -- Oasis of Vir'sar, Uldum (N)
			[652] = true,    -- Ramkahen, Uldum (N)
			[674] = true,    -- Schnottz's Landing, Uldum (N)
		},
		fishing_low = 575,  -- TODO: check
		fishing_high = 650,
	}


	zones[BZ["Southern Barrens"]] = {
		low = 30,
		high = 35,
		continent = Kalimdor,
		instances = {
			[BZ["Razorfen Kraul"]] = true,
			[BZ["Razorfen Downs"]] = true,
		},
		paths = {
			[BZ["The Barrens"]] = true,
			[BZ["Thousand Needles"]] = true,
			[BZ["Mulgore"]] = true,
			[BZ["Dustwallow Marsh"]] = true,
			[BZ["Razorfen Kraul"]] = true,
			[BZ["Razorfen Downs"]] = true,
		},
		flightnodes = {
			[388] = true,    -- Northwatch Hold, Southern Barrens (A)
			[389] = true,    -- Fort Triumph, Southern Barrens (A)
			[390] = true,    -- Hunter's Hill, Southern Barrens (H)
			[77] = true,     -- Vendetta Point, Southern Barrens (H)
			[387] = true,    -- Honor's Stand, Southern Barrens (A)
			[391] = true,    -- Desolation Hold, Southern Barrens (H)
		},
		fishing_low = 130,
		fishing_high = 225,
	}


	zones[BZ["Twilight Highlands"]] = {
		low = 84,
		high = 85,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Grim Batol"]] = true,
			[BZ["The Bastion of Twilight"]] = true,
			[BZ["Twin Peaks"]] = true,
		},
		paths = {
			[BZ["Wetlands"]] = true,
			[BZ["Grim Batol"]] = true,
			[BZ["The Bastion of Twilight"]] = true,
			[BZ["Twin Peaks"]] = true,
			[transports["TWILIGHTHIGHLANDS_STORMWIND_PORTAL"]] = true,
			[transports["TWILIGHTHIGHLANDS_ORGRIMMAR_PORTAL"]] = true,
		},
		flightnodes = {
			[657] = true,    -- The Gullet, Twilight Highlands (H)
			[659] = true,    -- Bloodgulch, Twilight Highlands (H)
			[661] = true,    -- Dragonmaw Port, Twilight Highlands (H)
			[663] = true,    -- Victor's Point, Twilight Highlands (A)
			[665] = true,    -- Thundermar, Twilight Highlands (A)
			[656] = true,    -- Crushblow, Twilight Highlands (H)
			[658] = true,    -- Vermillion Redoubt, Twilight Highlands (N)
			[660] = true,    -- The Krazzworks, Twilight Highlands (H)
			[662] = true,    -- Highbank, Twilight Highlands (A)
			[664] = true,    -- Firebeard's Patrol, Twilight Highlands (A)
			[666] = true,    -- Kirthaven, Twilight Highlands (A)
		},
		fishing_low = 575,  -- TODO: check
		fishing_high = 650,		
	}	



	zones[BZ["Tol Barad"]] = {
		low = 84,
		high = 85,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Baradin Hold"]] = true,
		},
		paths = {
			[BZ["Tol Barad Peninsula"]] = true,
			[BZ["Baradin Hold"]] = true,
		},
		type = "PvP Zone",
	}

	zones[BZ["Tol Barad Peninsula"]] = {
		low = 85,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Tol Barad"]] = true,
			[transports["TOLBARAD_ORGRIMMAR_PORTAL"]] = true,
			[transports["TOLBARAD_STORMWIND_PORTAL"]] = true,
		},
	}	


	-- Worgen starting zone
	zones[BZ["Gilneas"]] = {
		low = 1,
		high = 14,
		continent = Eastern_Kingdoms,
		paths = {},  -- phased instance
		faction = "Alliance",
	}	
	
	zones[BZ["Gilneas City"]] = {
		low = 1,
		high = 5,
		continent = Eastern_Kingdoms,
		paths = {},  -- phased instance
		faction = "Alliance",
	}

	zones[BZ["Ruins of Gilneas"]] = {
		low = 14,
		high = 20,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Silverpine Forest"]] = true,
			[BZ["Ruins of Gilneas City"]] = true,
		},
		flightnodes = {
			[646] = true,    -- Forsaken Forward Command, Gilneas (H)
		},
	}

	zones[BZ["Ruins of Gilneas City"]] = {
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Silverpine Forest"]] = true,
			[BZ["Ruins of Gilneas"]] = true,
		},
	}


	-- Vashj'ir

	zones[BZ["Vashj'ir"]] = {
		low = 80,
		high = 82,
		continent = Eastern_Kingdoms,
		paths = {
			[transports["KELPTHAR_IRONFORGE_FLIGHTPATH"]] = true,
			[transports["KELPTHAR_UNDERCITY_FLIGHTPATH"]] = true,
			[transports["KELPTHAR_SEARINGGORGE_FLIGHTPATH"]] = true,
		},
		instances = {
			[BZ["Throne of the Tides"]] = true,
		},
		flightnodes = {
			[522] = true,    -- Silver Tide Hollow, Vashj'ir (N) S seahorse
			[524] = true,    -- Darkbreak Cove, Vashj'ir (A) A seahorse
			[526] = true,    -- Tenebrous Cavern, Vashj'ir (H) A seahorse
			[605] = true,    -- Voldrin's Hold, Vashj'ir (A) S seahorse
			[611] = true,    -- Voldrin's Hold, Vashj'ir (A) S
			[606] = true,    -- Sandy Beach, Vashj'ir (A) S 
			[607] = true,    -- Sandy Beach, Vashj'ir (A) S seahorse
			[608] = true,    -- Sandy Beach, Vashj'ir (H) S 
			[609] = true,    -- Sandy Beach, Vashj'ir (H) S seahorse
			[610] = true,    -- Stygian Bounty, Vashj'ir (H) S 
			[612] = true,    -- Stygian Bounty, Vashj'ir (H) S seahorse
			[521] = true,    -- Smuggler's Scar, Vashj'ir (N) K seahorse
			[523] = true,    -- Tranquil Wash, Vashj'ir (A) S seahorse
			[525] = true,    -- Legion's Rest, Vashj'ir (H) S seahorse
		},
		fishing_low = 450,
		fishing_high = 575,
	}

	zones[BZ["Kelp'thar Forest"]] = {
		low = 80,
		high = 82,
		continent = Eastern_Kingdoms,
		paths = {
			[transports["KELPTHAR_IRONFORGE_FLIGHTPATH"]] = true,
			[transports["KELPTHAR_UNDERCITY_FLIGHTPATH"]] = true,
			[transports["KELPTHAR_SEARINGGORGE_FLIGHTPATH"]] = true,
			[BZ["Shimmering Expanse"]] = true,
		},
		flightnodes = {
			[521] = true,    -- Smuggler's Scar, Vashj'ir (N) seahorse
		},
		fishing_low = 450,
		fishing_high = 575,
	}

	zones[BZ["Shimmering Expanse"]] = {
		low = 80,
		high = 82,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Kelp'thar Forest"]] = true,
			[BZ["Abyssal Depths"]] = true,
		},
		flightnodes = {
			[522] = true,    -- Silver Tide Hollow, Vashj'ir (N) seahorse
			[605] = true,    -- Voldrin's Hold, Vashj'ir (A) seahorse
			[611] = true,    -- Voldrin's Hold, Vashj'ir (A) 
			[606] = true,    -- Sandy Beach, Vashj'ir (A)  
			[607] = true,    -- Sandy Beach, Vashj'ir (A) seahorse
			[608] = true,    -- Sandy Beach, Vashj'ir (H)  
			[609] = true,    -- Sandy Beach, Vashj'ir (H) seahorse
			[610] = true,    -- Stygian Bounty, Vashj'ir (H)  
			[612] = true,    -- Stygian Bounty, Vashj'ir (H) seahorse
			[523] = true,    -- Tranquil Wash, Vashj'ir (A) seahorse
			[525] = true,    -- Legion's Rest, Vashj'ir (H) seahorse
		},
		fishing_low = 450,
		fishing_high = 575,	
	}

	zones[BZ["Abyssal Depths"]] = {
		low = 80,
		high = 82,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Throne of the Tides"]] = true,
		},
		paths = {
			[BZ["Shimmering Expanse"]] = true,
			[BZ["Throne of the Tides"]] = true,
		},
		flightnodes = {
			[524] = true,    -- Darkbreak Cove, Vashj'ir (A) seahorse
			[526] = true,    -- Tenebrous Cavern, Vashj'ir (H) seahorse
		},
		fishing_low = 450,
		fishing_high = 575,
	}


	-- The Maelstrom zones (Cataclysm) --

	-- Goblin start zone 1
	zones[BZ["The Lost Isles"]] = {
		low = 5,
		high = 12,
		continent = The_Maelstrom,
		faction = "Horde",
	}	
	
	-- Goblin start zone 2
	zones[BZ["Kezan"]] = {
		low = 1,
		high = 5,
		continent = The_Maelstrom,
		faction = "Horde",
	}

	zones[BZ["The Maelstrom"].." (zone)"] = {
		continent = The_Maelstrom,
		paths = {
		},
		faction = "Sanctuary",
	}

	zones[BZ["Deepholm"]] = {
		low = 82,
		high = 83,
		continent = The_Maelstrom,
		expansion = Cataclysm,
		instances = {
			[BZ["The Stonecore"]] = true,
		},
		paths = {
			[BZ["The Stonecore"]] = true,
			[transports["DEEPHOLM_ORGRIMMAR_PORTAL"]] = true,
			[transports["DEEPHOLM_STORMWIND_PORTAL"]] = true,
		},
	}	







	-- ============== DUNGEONS =======================================================================


	-- Classic dungeons ------------------------

	zones[BZ["Ragefire Chasm"]] = {
		low = 10,
		high = 20,
		continent = Kalimdor,
		paths = BZ["Orgrimmar"],
		groupSize = 5,
		faction = "Horde",
		type = "Instance",
		entrancePortal = { BZ["Orgrimmar"], 52.8, 49 },
	}

	zones[BZ["The Deadmines"]] = {
		low = 15,
		high = 25,
		continent = Eastern_Kingdoms,
		paths = BZ["Westfall"],
		groupSize = 5,
		faction = "Alliance",
		type = "Instance",
		fishing_low = 1,
		fishing_high = 75,
		entrancePortal = { BZ["Westfall"], 42.6, 72.2 },
	}

	zones[BZ["Shadowfang Keep"]] = {
		low = 11,
		high = 26,
		continent = Eastern_Kingdoms,
		paths = BZ["Silverpine Forest"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Silverpine Forest"], 44.80, 67.83 },
	}

	zones[BZ["Wailing Caverns"]] = {
		low = 10,
		high = 25,
		continent = Kalimdor,
		paths = BZ["The Barrens"],
		groupSize = 5,
		type = "Instance",
		fishing_low = 1,
		fishing_high = 75,
		entrancePortal = { BZ["The Barrens"], 42.1, 66.5 },
	}

	zones[BZ["Blackfathom Deeps"]] = {
		low = 15,
		high = 25,
		continent = Kalimdor,
		paths = BZ["Ashenvale"],
		groupSize = 5,
		type = "Instance",
		fishing_low = 1,
		fishing_high = 75,
		entrancePortal = { BZ["Ashenvale"], 14.6, 15.3 },
	}

	zones[BZ["The Stockade"]] = {
		low = 15,
		high = 30,
		continent = Eastern_Kingdoms,
		paths = BZ["Stormwind City"],
		groupSize = 5,
		faction = "Alliance",
		type = "Instance",
		entrancePortal = { BZ["Stormwind City"], 39.85, 54.30 },
	}

	zones[BZ["Gnomeregan"]] = {
		low = 19,
		high = 29,
		continent = Eastern_Kingdoms,
		paths = BZ["Dun Morogh"],
		groupSize = 5,
		faction = "Alliance",
		type = "Instance",
		entrancePortal = { BZ["Dun Morogh"], 24, 38.9 },
	}

	-- Consists of Graveyard, Library, Armory and Cathedral
	zones[BZ["Scarlet Monastery"]] = {
		low = 20,
		high = 34,
		continent = Eastern_Kingdoms,
		paths = BZ["Tirisfal Glades"],
		groupSize = 5,
		type = "Instance",
		fishing_low = 130,
		fishing_high = 225,
		entrancePortal = { BZ["Tirisfal Glades"], 85.3, 32.1 },
	}

	zones[BZ["Razorfen Kraul"]] = {
		low = 25,
		high = 35,
		continent = Kalimdor,
		paths = BZ["Southern Barrens"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Southern Barrens"], 40.8, 94.5 },  -- TODO: check
	}

	zones[BZ["Razorfen Downs"]] = {
		low = 35,
		high = 45,
		continent = Kalimdor,
		paths = BZ["Southern Barrens"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Southern Barrens"], 47.5, 23.7 },  -- TODO check
	}

	-- consists of The Wicked Grotto, Foulspore Cavern and Earth Song Falls
	zones[BZ["Maraudon"]] = {
		low = 25,
		high = 39,
		continent = Kalimdor,
		paths = BZ["Desolace"],
		groupSize = 5,
		type = "Instance",
		fishing_low = 205,
		fishing_high = 300,
		entrancePortal = { BZ["Desolace"], 29, 62.4 },
	}

	zones[BZ["Uldaman"]] = {
		low = 30,
		high = 45,
		continent = Eastern_Kingdoms,
		paths = BZ["Badlands"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Badlands"], 42.4, 18.6 },
	}

	-- a.k.a. Warpwood Quarter
	zones[BZ["Dire Maul - East"]] = {
		low = 36,
		high = 46,
		continent = Kalimdor,
		paths = BZ["Dire Maul"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Dire Maul"],
		entrancePortal = { BZ["Feralas"], 66.7, 34.8 },
	}

	-- a.k.a. Capital Gardens
	zones[BZ["Dire Maul - West"]] = {
		low = 39,
		high = 49,
		continent = Kalimdor,
		paths = BZ["Dire Maul"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Dire Maul"],
		entrancePortal = { BZ["Feralas"], 60.3, 30.6 },
	}

	-- a.k.a. Gordok Commons
	zones[BZ["Dire Maul - North"]] = {
		low = 42,
		high = 52,
		continent = Kalimdor,
		paths = BZ["Dire Maul"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Dire Maul"],
		entrancePortal = { BZ["Feralas"], 62.5, 24.9 },
	}

	zones[BZ["Scholomance"]] = {
		low = 33,
		high = 43,
		continent = Eastern_Kingdoms,
		paths = BZ["Western Plaguelands"],
		groupSize = 5,
		type = "Instance",
		fishing_low = 330,
		fishing_high = 425,
		entrancePortal = { BZ["Western Plaguelands"], 69.4, 72.8 },
	}

	-- a.k.a. Live Stratholme
	zones[BZ["Stratholme - Main Gate"]] = {
		low = 37,
		high = 47,
		continent = Eastern_Kingdoms,
		paths = BZ["Stratholme"],
		groupSize = 5,
		type = "Instance",
		fishing_low = 330,
		fishing_high = 425,
		complex = BZ["Stratholme"],
		entrancePortal = { BZ["Eastern Plaguelands"], 30.8, 14.4 },
	}

	-- a.k.a. Undead Stratholme
	zones[BZ["Stratholme - Service Entrance"]] = {
		low = 40,
		high = 50,
		continent = Eastern_Kingdoms,
		paths = BZ["Stratholme"],
		groupSize = 5,
		type = "Instance",
		fishing_low = 330,
		fishing_high = 425,
		complex = BZ["Stratholme"],
		entrancePortal = { BZ["Eastern Plaguelands"], 30.8, 14.4 },
	}
	

	zones[BZ["Zul'Farrak"]] = {
		low = 39,
		high = 49,
		continent = Kalimdor,
		paths = BZ["Tanaris"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Tanaris"], 36, 11.7 },
	}

	-- consists of Detention Block and Upper City
	zones[BZ["Blackrock Depths"]] = {
		low = 42,
		high = 61,
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
		low = 45,
		high = 55,
		continent = Eastern_Kingdoms,
		paths = BZ["Swamp of Sorrows"],
		groupSize = 5,
		type = "Instance",
		fishing_low = 205,
		fishing_high = 300,
		entrancePortal = { BZ["Swamp of Sorrows"], 70, 54 },
	}

	zones[BZ["Blackrock Spire"]] = {
		low = 48,
		high = 65,
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




	-- The Burning Crusade Dungeons --------------------------------------


	-- a.k.a The Escape From Durnholde
	zones[BZ["Old Hillsbrad Foothills"]] = {
		low = 63,
		high = 75,
		continent = Kalimdor,
		paths = {
			[BZ["Caverns of Time"]] = true,
		},
		groupSize = 5,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Tanaris"], 66.2, 49.3 },
	}

	-- a.k.a. Opening of the Dark Portal
	zones[BZ["The Black Morass"]] = {
		low = 65,
		high = 75,
		continent = Kalimdor,
		paths = {
			[BZ["Caverns of Time"]] = true,
		},
		groupSize = 5,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Tanaris"], 66.2, 49.3 },
	}

	zones[BZ["Karazhan"]] = {
		low = 70,
		high = 70,
		continent = Eastern_Kingdoms,
		paths = BZ["Deadwind Pass"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Deadwind Pass"], 40.9, 73.2 },
	}
	
	zones[BZ["Zul'Aman"]] = {
		low = 85,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = BZ["Ghostlands"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Ghostlands"], 77.7, 63.2 },
	}
	
	-- ---

	zones[BZ["Hellfire Ramparts"]] = {
		low = 57,
		high = 75,
		continent = Outland,
		paths = BZ["Hellfire Citadel"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Hellfire Citadel"],
		entrancePortal = { BZ["Hellfire Peninsula"], 47.8, 53.3 },
	}
	
	zones[BZ["The Blood Furnace"]] = {
		low = 58,
		high = 75,
		continent = Outland,
		paths = BZ["Hellfire Citadel"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Hellfire Citadel"],
		entrancePortal = { BZ["Hellfire Peninsula"], 46.1, 51.8 },
	}
	
	zones[BZ["The Shattered Halls"]] = {
		low = 65,
		high = 75,
		continent = Outland,
		paths = BZ["Hellfire Citadel"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Hellfire Citadel"],
		entrancePortal = { BZ["Hellfire Peninsula"], 47.8, 51.1 },
	}
	
	-- ---
	
	zones[BZ["The Slave Pens"]] = {
		low = 59,
		high = 75,
		continent = Outland,
		paths = BZ["Coilfang Reservoir"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Coilfang Reservoir"],
		entrancePortal = { BZ["Zangarmarsh"], 49.0, 36.0 },
	}
	
	zones[BZ["The Underbog"]] = {
		low = 60,
		high = 75,
		continent = Outland,
		paths = BZ["Coilfang Reservoir"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Coilfang Reservoir"],
		entrancePortal = { BZ["Zangarmarsh"], 54.0, 43.0 },
	}
	
	zones[BZ["The Steamvault"]] = {
		low = 65,
		high = 75,
		continent = Outland,
		paths = BZ["Coilfang Reservoir"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Coilfang Reservoir"],
		entrancePortal = { BZ["Zangarmarsh"], 50.0, 33.0 },
	}
	
	-- ---
	
	zones[BZ["Auchenai Crypts"]] = {
		low = 62,
		high = 75,
		continent = Outland,
		paths = BZ["Auchindoun"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Auchindoun"],
		entrancePortal = { BZ["Terokkar Forest"], 35, 65.8 },
	}
	
	zones[BZ["Shadow Labyrinth"]] = {
		low = 65,
		high = 75,
		continent = Outland,
		paths = BZ["Auchindoun"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Auchindoun"],
		entrancePortal = { BZ["Terokkar Forest"], 39.6, 65.5 },
	}
	
	zones[BZ["Sethekk Halls"]] = {
		low = 63,
		high = 75,
		continent = Outland,
		paths = BZ["Auchindoun"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Auchindoun"],
		entrancePortal = { BZ["Terokkar Forest"], 43.4, 65.4 },
	}
	
	zones[BZ["Mana-Tombs"]] = {
		low = 61,
		high = 75,
		continent = Outland,
		paths = BZ["Auchindoun"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Auchindoun"],
		entrancePortal = { BZ["Terokkar Forest"], 39.2, 58.5 },
	}	
	
	-- ---

	zones[BZ["The Mechanar"]] = {
		low = 65,
		high = 75,
		continent = Outland,
		paths = BZ["Netherstorm"],
--		paths = BZ["Tempest Keep"],
		groupSize = 5,
		type = "Instance",
--		complex = BZ["Tempest Keep"],
		entrancePortal = { BZ["Netherstorm"], 76.5, 65.1 },
	}
	
	zones[BZ["The Botanica"]] = {
		low = 65,
		high = 75,
		continent = Outland,
		paths = BZ["Netherstorm"],
--		paths = BZ["Tempest Keep"],
		groupSize = 5,
		type = "Instance",
--		complex = BZ["Tempest Keep"],
		entrancePortal = { BZ["Netherstorm"], 76.5, 65.1 },
	}
	
	zones[BZ["The Arcatraz"]] = {
		low = 65,
		high = 75,
		continent = Outland,
		paths = BZ["Netherstorm"],
--		paths = BZ["Tempest Keep"],
		groupSize = 5,
		type = "Instance",
--		complex = BZ["Tempest Keep"],
		entrancePortal = { BZ["Netherstorm"], 76.5, 65.1 },
	}

	-- TBC 2.4 dungeon
	zones[BZ["Magister's Terrace"]] = {
		low = 65,
		high = 75,
		continent = Eastern_Kingdoms,
		paths = BZ["Isle of Quel'Danas"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Isle of Quel'Danas"], 61.3, 30.9 },
	}	






	-- Wrath of the Lich King Dungeons
	
	zones[BZ["Utgarde Keep"]] = {
		low = 67,
		high = 83,
		continent = Northrend,
		paths = BZ["Howling Fjord"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Howling Fjord"], 57.30, 46.84 },
	}

	zones[BZ["Utgarde Pinnacle"]] = {
		low = 73,
		high = 83,
		continent = Northrend,
		paths = BZ["Howling Fjord"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Howling Fjord"], 57.25, 46.60 },
	}

	zones[BZ["The Nexus"]] = {
		low = 68,
		high = 83,
		continent = Northrend,
		paths = BZ["Coldarra"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Coldarra"],
		entrancePortal = { BZ["Borean Tundra"], 27.50, 26.03 },
	}

	zones[BZ["The Oculus"]] = {
		low = 75,
		high = 83,
		continent = Northrend,
		paths = BZ["Coldarra"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Coldarra"],
		entrancePortal = { BZ["Borean Tundra"], 27.52, 26.67 },
	}

	zones[BZ["Azjol-Nerub"]] = {
		low = 69,
		high = 83,
		continent = Northrend,
		paths = BZ["Dragonblight"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Dragonblight"], 26.01, 50.83 },
	}

	zones[BZ["Ahn'kahet: The Old Kingdom"]] = {
		low = 70,
		high = 83,
		continent = Northrend,
		paths = BZ["Dragonblight"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Dragonblight"], 28.49, 51.73 },
	}

	zones[BZ["Drak'Tharon Keep"]] = {
		low = 71,
		high = 83,
		continent = Northrend,
		paths = {
			[BZ["Grizzly Hills"]] = true,
			[BZ["Zul'Drak"]] = true,
		},
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Zul'Drak"], 28.53, 86.93 },
	}

	zones[BZ["Gundrak"]] = {
		low = 73,
		high = 83,
		continent = Northrend,
		paths = BZ["Zul'Drak"],
		groupSize = 5,
		type = "Instance",
		fishing_low = 350,  -- TODO: check
		fishing_high = 475,
		entrancePortal = { BZ["Zul'Drak"], 76.14, 21.00 },
	}

	zones[BZ["Halls of Stone"]] = {
		low = 74,
		high = 83,
		continent = Northrend,
		paths = BZ["The Storm Peaks"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["The Storm Peaks"], 39.52, 26.91 },
	}

	zones[BZ["Halls of Lightning"]] = {
		low = 75,
		high = 83,
		continent = Northrend,
		paths = BZ["The Storm Peaks"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["The Storm Peaks"], 45.38, 21.37 },
	}

	zones[BZ["The Violet Hold"]] = {
		low = 72,
		high = 83,
		continent = Northrend,
		paths = BZ["Dalaran"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Dalaran"], 66.78, 68.19 },
	}

	zones[BZ["Trial of the Champion"]] = {
		low = 75,
		high = 83,
		continent = Northrend,
		paths = BZ["Icecrown"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Icecrown"], 74.18, 20.45 },
	}

	zones[BZ["The Forge of Souls"]] = {
		low = 75,
		high = 83,
		continent = Northrend,
		paths = BZ["Icecrown"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Icecrown"], 52.60, 89.35 },
	}

	zones[BZ["Pit of Saron"]] = {
		low = 79,
		high = 83,
		continent = Northrend,
		paths = BZ["Icecrown"],
		groupSize = 5,
		type = "Instance",
		fishing_low = 475,  -- TODO: check
		fishing_high = 550,
		entrancePortal = { BZ["Icecrown"], 52.60, 89.35 },
	}

	zones[BZ["Halls of Reflection"]] = {
		low = 79,
		high = 83,
		continent = Northrend,
		paths = BZ["Icecrown"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Icecrown"], 52.60, 89.35 },
	}
	
	
	-- Cataclysm dungeons
	
	zones[BZ["Lost City of the Tol'vir"]] = {
		low = 83,
		high = 85,
		continent = Kalimdor,
		paths = BZ["Uldum"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Uldum"], 60.53, 64.24 },
	}

	zones[BZ["Halls of Origination"]] = {
		low = 83,
		high = 85,
		continent = Kalimdor,
		paths = BZ["Uldum"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Uldum"], 69.09, 52.95 },
	}

	zones[BZ["The Vortex Pinnacle"]] = {
		low = 80,
		high = 85,
		continent = Kalimdor,
		paths = BZ["Uldum"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Uldum"], 76.79, 84.51 },
	}

	-- Note: before Cataclysm, this was a lvl 60 20-man raid
	zones[BZ["Zul'Gurub"]] = {
		low = 85,
		high = 85,
		continent = Eastern_Kingdoms,
		expansion = Cataclysm,
		paths = BZ["Northern Stranglethorn"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Northern Stranglethorn"], 52.2, 17.1 },
	}
	
	zones[BZ["The Stonecore"]] = {
		low = 80,
		high = 85,
		continent = The_Maelstrom,
		paths = BZ["Deepholm"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Deepholm"], 47.70, 51.96 },
	}

	zones[BZ["Throne of the Tides"]] = {
		low = 80,
		high = 82,
		continent = Eastern_Kingdoms,
		paths = BZ["Abyssal Depths"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Abyssal Depths"], 69.3, 25.2 },
	}

	zones[BZ["Grim Batol"]] = {
		low = 83,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = BZ["Twilight Highlands"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Twilight Highlands"], 19, 53.5 },
	}


	-- patch 4.4.2
	zones[BZ["End Time"]] = {
		low = 85,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Caverns of Time"]] = true,
		},
		groupSize = 5,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Tanaris"], 66.2, 49.3 },
	}

	-- patch 4.4.2
	zones[BZ["Well of Eternity"]] = {
		low = 85,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Caverns of Time"]] = true,
		},
		groupSize = 5,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Tanaris"], 66.2, 49.3 },
	}

	-- patch 4.4.2
	zones[BZ["Hour of Twilight"]] = {
		low = 85,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Caverns of Time"]] = true,
		},
		groupSize = 5,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Tanaris"], 66.2, 49.3 },
	}


	-- ============== RAIDS =======================================================================


	-- Classic Raids -----------------------------

	-- Cataclysm: converted into a dungeon (see Cataclysm dungeons)
	-- zones[BZ["Zul'Gurub"]] = {
		-- low = 60,
		-- high = 60,
		-- continent = Eastern_Kingdoms,
		-- paths = BZ["Stranglethorn Vale"],
		-- groupSize = 20,
		-- type = "Instance",
		-- fishing_low = 205,
		-- fishing_high = 330,
		-- entrancePortal = { BZ["Stranglethorn Vale"], 52.2, 17.1 },
	-- }

	zones[BZ["Blackwing Lair"]] = {
		low = 60,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = BZ["Blackrock Mountain"],
		groupSize = 40,
		type = "Instance",
		complex = BZ["Blackrock Mountain"],
		entrancePortal = { BZ["Burning Steppes"], 29.7, 37.5 },
	}

	zones[BZ["Molten Core"]] = {
		low = 50,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = BZ["Blackrock Mountain"],
		groupSize = 40,
		type = "Instance",
		complex = BZ["Blackrock Mountain"],
		entrancePortal = { BZ["Searing Gorge"], 35.4, 84.4 },
	}

	zones[BZ["Ahn'Qiraj Temple"]] = {
		low = 60,
		high = 60,
		continent = Kalimdor,
		paths = BZ["Ahn'Qiraj: The Fallen Kingdom"],
		groupSize = 40,
		type = "Instance",
		complex = BZ["Ahn'Qiraj: The Fallen Kingdom"],
		entrancePortal = { BZ["Ahn'Qiraj: The Fallen Kingdom"], 46.6, 7.4 },  TODO
	}

	zones[BZ["Ruins of Ahn'Qiraj"]] = {
		low = 60,
		high = 60,
		continent = Kalimdor,
		paths = BZ["Ahn'Qiraj: The Fallen Kingdom"],
		groupSize = 20,
		type = "Instance",
		complex = BZ["Ahn'Qiraj: The Fallen Kingdom"],
		entrancePortal = { BZ["Ahn'Qiraj: The Fallen Kingdom"], 58.9, 14.3 },  TODO
	}

	zones[BZ["Onyxia's Lair"]] = {
		low = 80,
		high = 83,
		continent = Kalimdor,
		paths = BZ["Dustwallow Marsh"],
		groupSize = 40,
		type = "Instance",
		entrancePortal = { BZ["Dustwallow Marsh"], 52, 76 },
	}

	zones[BZ["Naxxramas"]] = {
		low = 80,
		high = 83,
		continent = Eastern_Kingdoms,
		paths = BZ["Eastern Plaguelands"],
		groupSize = 40,
		type = "Instance",
		fishing_high = 1,  -- acid
		entrancePortal = { BZ["Eastern Plaguelands"], 87.30, 51.00 },
	}


	-- The Burning Crusade Raids --------------------------------------
	
	zones[BZ["Magtheridon's Lair"]] = {
		low = 70,
		high = 70,
		continent = Outland,
		paths = BZ["Hellfire Citadel"],
		groupSize = 25,
		type = "Instance",
		complex = BZ["Hellfire Citadel"],
		entrancePortal = { BZ["Hellfire Peninsula"], 46.8, 54.9 },
	}	
	
	zones[BZ["Serpentshrine Cavern"]] = {
		low = 70,
		high = 70,
		continent = Outland,
		paths = BZ["Coilfang Reservoir"],
		groupSize = 25,
		type = "Instance",
		complex = BZ["Coilfang Reservoir"],
		entrancePortal = { BZ["Zangarmarsh"], 50.2, 40.8 },
	}	
	
	zones[BZ["Gruul's Lair"]] = {
		low = 70,
		high = 70,
		continent = Outland,
		paths = BZ["Blade's Edge Mountains"],
		groupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Blade's Edge Mountains"], 68, 24 },
	}	
	
	zones[BZ["Black Temple"]] = {
		low = 70,
		high = 70,
		continent = Outland,
		paths = BZ["Shadowmoon Valley"],
		groupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Shadowmoon Valley"], 77.7, 43.7 },
	}	
	
	--zones[BZ["The Eye"]] = {
	zones[BZ["Tempest Keep"]] = {
		low = 70,
		high = 70,
		continent = Outland,
--		paths = BZ["Tempest Keep"],
		paths = BZ["Netherstorm"],		
		groupSize = 25,
		type = "Instance",
--		complex = BZ["Tempest Keep"],
		entrancePortal = { BZ["Netherstorm"], 76.5, 65.1 },
	}	
	
	-- a.k.a The Battle for Mount Hyjal
	zones[BZ["Hyjal Summit"]] = {
		low = 70,
		high = 70,
		continent = Kalimdor,
		paths = BZ["Caverns of Time"],
		groupSize = 25,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Tanaris"], 66.2, 49.3 },
	}
	

	
	
	-- TBC 2.4 raid
	zones[BZ["Sunwell Plateau"]] = {
		low = 70,
		high = 70,
		continent = Eastern_Kingdoms,
		paths = BZ["Isle of Quel'Danas"],
		groupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Isle of Quel'Danas"], 44.3, 45.7 },
	}	


	-- Wrath of the Lich King Raids
	
	zones[BZ["The Eye of Eternity"]] = {
		low = 80,
		high = 83,
		continent = Northrend,
		paths = BZ["Coldarra"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		complex = BZ["Coldarra"],
		entrancePortal = { BZ["Borean Tundra"], 27.54, 26.68 },
	}

	zones[BZ["Naxxramas"]] = {
		low = 80,
		high = 83,
		continent = Northrend,
		paths = BZ["Dragonblight"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Dragonblight"], 87.30, 51.00 },
	}

	zones[BZ["The Obsidian Sanctum"]] = {
		low = 80,
		high = 83,
		continent = Northrend,
		paths = BZ["Dragonblight"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Dragonblight"], 60.00, 57.00 },
	}

	zones[BZ["Ulduar"]] = {
		low = 80,
		high = 83,
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
		high = 83,
		continent = Northrend,
		paths = BZ["Icecrown"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Icecrown"], 75.07, 21.80 },
	}

	zones[BZ["Icecrown Citadel"]] = {
		low = 80,
		high = 83,
		continent = Northrend,
		paths = BZ["Icecrown"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Icecrown"], 53.86, 87.27 },
	}

	zones[BZ["Vault of Archavon"]] = {
		low = 80,
		high = 83,
		continent = Northrend,
		paths = BZ["Wintergrasp"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Wintergrasp"], 50, 11.2 }, 
	}

	zones[BZ["The Ruby Sanctum"]] = {
		low = 80,
		high = 83,
		continent = Northrend,
		paths = BZ["Dragonblight"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Dragonblight"], 61.00, 53.00 },
	}


	-- Cataclysm raids

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

	zones[BZ["The Bastion of Twilight"]] = {
		low = 85,
		high = 85,
		continent = Eastern_Kingdoms,
		expansion = Cataclysm,
		paths = BZ["Twilight Highlands"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Twilight Highlands"], 34.2, 77.7 },
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
		expansion = Cataclysm,
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
	
	-- patch 4.4.2
	zones[BZ["Dragon Soul"]] = {
		low = 85,
		high = 85,
		continent = Kalimdor,
		expansion = Cataclysm,
		paths = BZ["Caverns of Time"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Caverns of Time"], 60.0, 21.1 },
	}
	
	-- Opens when your faction controls Tol Barad
	zones[BZ["Baradin Hold"]] = {
		low = 85,
		high = 85,
		continent = Eastern_Kingdoms,
		expansion = Cataclysm,
		paths = BZ["Tol Barad"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		-- entrancePortal = { BZ["Tol Barad"], 33.8, 78.2 }, n/a
	}
	
	-- ============== BATTLEGROUNDS =======================================================================


	-- Classic Battlegrounds --

	zones[BZ["Arathi Basin"]] = {
		low = 10,
		high = MAX_LEVEL,
		continent = Eastern_Kingdoms,
		paths = BZ["Arathi Highlands"],
		groupSize = 15,
		type = "Battleground",
		texture = "ArathiBasin",
	}

	zones[BZ["Warsong Gulch"]] = {
		low = 10,
		high = MAX_LEVEL,
		continent = Kalimdor,
		paths = isHorde and BZ["The Barrens"] or BZ["Ashenvale"],
		groupSize = 10,
		type = "Battleground",
		texture = "WarsongGulch",
	}

	zones[BZ["Alterac Valley"]] = {
		low = 45,
		high = MAX_LEVEL,
		continent = Eastern_Kingdoms,
		paths = BZ["Hillsbrad Foothills"],
		groupSize = 40,
		type = "Battleground",
		texture = "AlteracValley",
	}

	-- The Burning Crusade Battlegrounds --------------------------------------
	
	zones[BZ["Eye of the Storm"]] = {
		low = 35,
		high = MAX_LEVEL,
		continent = Outland,
		paths = BZ["Netherstorm"],
		groupSize = 25,
		type = "Battleground",
		texture = "NetherstormArena",
	}
	
	
	
	-- Wrath of the Lich King Battlegrounds
	
	zones[BZ["Strand of the Ancients"]] = {
		low = 65,
		high = MAX_LEVEL,
		continent = Northrend,
		paths = BZ["Dragonblight"],
		groupSize = 15,
		type = "Battleground",
		texture = "StrandoftheAncients",
	}
	
	zones[BZ["Isle of Conquest"]] = {
		low = 71,
		high = MAX_LEVEL,
		continent = Northrend,
		paths = BZ["Icecrown"],
		groupSize = 40,
		type = "Battleground",
		texture = "IsleofConquest",
	}
	
	
	
	-- Cataclysm Battlegrounds
	
	zones[BZ["The Battle for Gilneas"]] = {
		low = 10,
		high = MAX_LEVEL,
		continent = Eastern_Kingdoms,
		groupSize = 10,
		type = "Battleground",
		texture = "TheBattleforGilneas",
	}	
	
	zones[BZ["Twin Peaks"]] = {
		low = 10,
		high = MAX_LEVEL,
		continent = Eastern_Kingdoms,
		expansion = Cataclysm,
		paths = BZ["Twilight Highlands"],
		groupSize = 10,
		type = "Battleground",
		texture = "TwinPeaks",  -- TODO: verify
	}
	


	-- ============== ARENAS =======================================================================
	
	
	-- The Burning Crusade Arenas --------------------------------------
	
	zones[BZ["Blade's Edge Arena"]] = {
		low = 10,
		high = MAX_LEVEL,
		continent = Outland,
		paths = BZ["Blade's Edge Mountains"],
		type = "Arena",
	}

	zones[BZ["Nagrand Arena"]] = {
		low = 10,
		high = MAX_LEVEL,
		continent = Outland,
		paths = BZ["Nagrand"],
		type = "Arena",
	}
	
	zones[BZ["Ruins of Lordaeron"]] = {
		low = 10,
		high = MAX_LEVEL,
		continent = Kalimdor,
		paths = BZ["Undercity"],
		type = "Arena",
	}
	

	-- Wrath of the Lich King Arenas
	
--	zones[BZ["Dalaran Arena"]] = {
--		low = 10,
--		high = MAX_LEVEL,
--		continent = Northrend,
--		type = "Arena",
--	}
	
	zones[BZ["The Ring of Valor"]] = {
		low = 10,
		high = MAX_LEVEL,
		continent = Kalimdor,
		type = "Arena",
	}	
	
	
	

	-- ============== COMPLEXES =======================================================================

	-- Classic Complexes ---------------------------------------------

	zones[BZ["Dire Maul"]] = {
		low = 36,
		high = 52,
		continent = Kalimdor,
		instances = {
			[BZ["Dire Maul - East"]] = true,
			[BZ["Dire Maul - North"]] = true,
			[BZ["Dire Maul - West"]] = true,
		},
		paths = {
			[BZ["Feralas"]] = true,
			[BZ["Dire Maul - East"]] = true,
			[BZ["Dire Maul - North"]] = true,
			[BZ["Dire Maul - West"]] = true,
		},
		type = "Complex",
	}

	zones[BZ["Blackrock Mountain"]] = {
		low = 42,
		high = 85,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Blackrock Depths"]] = true,
			[BZ["Blackwing Lair"]] = true,
			[BZ["Molten Core"]] = true,
			[BZ["Blackrock Spire"]] = true,
			[BZ["Blackwing Descent"]] = true,
		},
		paths = {
			[BZ["Burning Steppes"]] = true,
			[BZ["Searing Gorge"]] = true,
			[BZ["Blackwing Lair"]] = true,
			[BZ["Molten Core"]] = true,
			[BZ["Blackrock Depths"]] = true,
			[BZ["Blackrock Spire"]] = true,
			[BZ["Blackwing Descent"]] = true,
		},
		type = "Complex",
		fishing_high = 1, -- lava
	}

	zones[BZ["Stratholme"]] = {
		low = 37,
		high = 50,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Stratholme - Main Gate"]] = true,
			[BZ["Stratholme - Service Entrance"]] = true,
		},
		paths = {
			[BZ["Stratholme - Main Gate"]] = true,
			[BZ["Stratholme - Service Entrance"]] = true,
			[BZ["Eastern Plaguelands"]] = true,
		},
		type = "Complex",
	}



	-- The Burning Crusade complexes -------------------------------------


	zones[BZ["Ahn'Qiraj: The Fallen Kingdom"]] = {
		low = 60,
		high = 63,
		continent = Kalimdor,
		instances = {
			[BZ["Ahn'Qiraj Temple"]] = true,
			[BZ["Ruins of Ahn'Qiraj"]] = true,
		},
		paths = {
			[BZ["Silithus"]] = true,
			[BZ["Ahn'Qiraj Temple"]] = true,
			[BZ["Ruins of Ahn'Qiraj"]] = true,
		},	
		type = "Complex",
	}

	-- No UiMapID available?
	 zones[BZ["Caverns of Time"]] = {
		low = 63,
		high = 85,
		continent = Kalimdor,
		instances = {
			[BZ["Old Hillsbrad Foothills"]] = true,
			[BZ["The Black Morass"]] = true,
			[BZ["Hyjal Summit"]] = true,
			[BZ["Dragon Soul"]] = true,
			[BZ["End Time"]] = true,
			[BZ["Well of Eternity"]] = true,
			[BZ["Hour of Twilight"]] = true,
		},
		paths = {
			[BZ["Tanaris"]] = true,
			[BZ["Old Hillsbrad Foothills"]] = true,
			[BZ["The Black Morass"]] = true,
			[BZ["Hyjal Summit"]] = true,
			[BZ["Dragon Soul"]] = true,
			[BZ["End Time"]] = true,
			[BZ["Well of Eternity"]] = true,
			[BZ["Hour of Twilight"]] = true,
		},
		type = "Complex",
	}
	

	-- No UiMapID available?
	zones[BZ["Hellfire Citadel"]] = {
		low = 57,
		high = 75,
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
	
	-- No UiMapID available?
	zones[BZ["Coilfang Reservoir"]] = {
		low = 59,
		high = 75,
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
		type = "Complex",	
	}	
	
	-- No UiMapID available?
	-- inner circle: "Ring of Observance"
	zones[BZ["Auchindoun"]] = {
		low = 61,
		high = 75,
		continent = Outland,
		instances = {
			[BZ["Auchenai Crypts"]] = true,
			[BZ["Shadow Labyrinth"]] = true,
			[BZ["Sethekk Halls"]] = true,
			[BZ["Mana-Tombs"]] = true,
		},
		paths = {
			[BZ["Terokkar Forest"]] = true,
			[BZ["Auchenai Crypts"]] = true,
			[BZ["Shadow Labyrinth"]] = true,
			[BZ["Sethekk Halls"]] = true,
			[BZ["Mana-Tombs"]] = true,
		},
		type = "Complex",	
	}		
	
	-- Had to remove the complex 'Tempest Keep' because of the 'The Eye' instance actually has same name
	-- zones[BZ["Tempest Keep"]] = {
		-- low = 67,
		-- high = 70,
		-- continent = Outland,
		-- instances = {
			-- [BZ["The Mechanar"]] = true,
			-- [BZ["The Eye"]] = true,
			-- [BZ["The Botanica"]] = true,
			-- [BZ["The Arcatraz"]] = true,
		-- },
		-- paths = {
			-- [BZ["Netherstorm"]] = true,
			-- [BZ["The Mechanar"]] = true,
			-- [BZ["The Eye"]] = true,
			-- [BZ["The Botanica"]] = true,
			-- [BZ["The Arcatraz"]] = true,
		-- },
		-- type = "Complex",	
	-- }	
	

	
	-- Wrath of the Lich King Complexes
	
	zones[BZ["Coldarra"]] = {
		low = 68,
		high = 83,
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






--------------------------------------------------------------------------------------------------------
--                                       HERB TRANSLATIONS                                            --
--------------------------------------------------------------------------------------------------------


-- Thanks to GatherMate2 Classic
local herbTranslations = {
	koKR = {
		["Adder's Tongue"] = "얼레지 꽃",
		["Ancient Lichen"] = "고대 이끼",
		["Arthas' Tears"] = "아서스의 눈물",
		["Black Lotus"] = "검은 연꽃",
		["Blindweed"] = "실명초",
		["Briarthorn"] = "찔레가시",
		["Bruiseweed"] = "생채기풀",
		["Dreamfoil"] = "꿈풀",
		["Dreaming Glory"] = "꿈초롱이",
		["Earthroot"] = "뱀뿌리",
		["Fadeleaf"] = "미명초잎",
		["Felweed"] = "지옥풀",
		["Firebloom"] = "화염초",
		["Firethorn"] = "화염가시풀",
		["Frost Lotus"] = "서리 연꽃",
		["Frozen Herb"] = "얼어붙은 약초",
		["Ghost Mushroom"] = "유령버섯",
		["Goldclover"] = "황금토끼풀",
		["Golden Sansam"] = "황금 산삼",
		["Goldthorn"] = "황금가시",
		["Grave Moss"] = "무덤이끼",
		["Gromsblood"] = "그롬의 피",
		["Icecap"] = "얼음송이",
		["Icethorn"] = "얼음가시",
		["Khadgar's Whisker"] = "카드가의 수염",
		["Kingsblood"] = "왕꽃잎풀",
		["Lichbloom"] = "시체꽃",
		["Liferoot"] = "생명의 뿌리",
		["Mageroyal"] = "마법초",
		["Mana Thistle"] = "마나 엉겅퀴",
		["Mountain Silversage"] = "은초롱이",
		["Netherbloom"] = "황천꽃",
		["Nightmare Vine"] = "악몽의 덩굴",
		["Peacebloom"] = "평온초",
		["Plaguebloom"] = "역병초",
		["Purple Lotus"] = "보라 연꽃",
		["Ragveil"] = "가림막이버섯",
		["Silverleaf"] = "은엽수 덤불",
		["Stranglekelp"] = "갈래물풀",
		["Sungrass"] = "태양풀",
		["Talandra's Rose"] = "탈란드라의 장미",
		["Terocone"] = "테로열매",
		["Tiger Lily"] = "참나리",
		["Wild Steelbloom"] = "야생 철쭉",
		["Wintersbite"] = "겨울서리풀",
		["Stormvine"] = "폭풍덩굴",
		["Cinderbloom"] = "재투성이꽃",
		["Azshara's Veil"] = "아즈샤라의 신비",
		["Heartblossom"] = "심장꽃",
		["Whiptail"] = "채찍꼬리",
		["Twilight Jasmine"] = "황혼의 말리꽃",
		["Bloodthistle"] = "피 엉겅퀴",
		["Dragon's Teeth"] = "용 송곳니",
		["Flame Cap"] = "불꽃송이",
		["Sorrowmoss"] = "슬픔이끼",
	},
	deDE = {
		["Adder's Tongue"] = "Schlangenzunge",
		["Ancient Lichen"] = "Urflechte",
		["Arthas' Tears"] = "Arthas’ Tränen",
		["Black Lotus"] = "Schwarzer Lotus",
		["Blindweed"] = "Blindkraut",
		["Briarthorn"] = "Wilddornrose",
		["Bruiseweed"] = "Beulengras",
		["Dreamfoil"] = "Traumblatt",
		["Dreaming Glory"] = "Traumwinde",
		["Earthroot"] = "Erdwurzel",
		["Fadeleaf"] = "Blassblatt",
		["Felweed"] = "Teufelsgras",
		["Firebloom"] = "Feuerblüte",
		["Firethorn"] = "Feuerdorn",
		["Frost Lotus"] = "Frostlotus",
		["Frozen Herb"] = "Gefrorenes Kraut",
		["Ghost Mushroom"] = "Geisterpilz",
		["Goldclover"] = "Goldklee",
		["Golden Sansam"] = "Goldener Sansam",
		["Goldthorn"] = "Golddorn",
		["Grave Moss"] = "Grabmoos",
		["Gromsblood"] = "Gromsblut",
		["Icecap"] = "Eiskappe",
		["Icethorn"] = "Eisdorn",
		["Khadgar's Whisker"] = "Khadgars Schnurrbart",
		["Kingsblood"] = "Königsblut",
		["Lichbloom"] = "Lichblüte",
		["Liferoot"] = "Lebenswurz",
		["Mageroyal"] = "Maguskönigskraut",
		["Mana Thistle"] = "Manadistel",
		["Mountain Silversage"] = "Bergsilbersalbei",
		["Netherbloom"] = "Netherblüte",
		["Nightmare Vine"] = "Alptraumranke",
		["Peacebloom"] = "Friedensblume",
		["Plaguebloom"] = "Pestblüte",
		["Purple Lotus"] = "Lila Lotus",
		["Ragveil"] = "Zottelkappe",
		["Silverleaf"] = "Silberblatt",
		["Stranglekelp"] = "Würgetang",
		["Sungrass"] = "Sonnengras",
		["Talandra's Rose"] = "Talandras Rose",
		["Terocone"] = "Terozapfen",
		["Tiger Lily"] = "Tigerlilie",
		["Wild Steelbloom"] = "Wildstahlblume",
		["Wintersbite"] = "Winterbiss",	
		["Stormvine"] = "Sturmwinde",
		["Cinderbloom"] = "Aschenblüte",
		["Azshara's Veil"] = "Azsharas Schleier",
		["Heartblossom"] = "Herzblüte",
		["Whiptail"] = "Gertenrohr",
		["Twilight Jasmine"] = "Schattenjasmin",
		["Bloodthistle"] = "Blutdistel",
		["Dragon's Teeth"] = "Drachenzahn",
		["Flame Cap"] = "Flammenkappe",
		["Sorrowmoss"] = "Trauermoos",
	},
	frFR = {
		["Adder's Tongue"] = "Langue de serpent",
		["Ancient Lichen"] = "Lichen ancien",
		["Arthas' Tears"] = "Larmes d'Arthas",
		["Black Lotus"] = "Lotus noir",
		["Blindweed"] = "Aveuglette",
		["Briarthorn"] = "Eglantine",
		["Bruiseweed"] = "Doulourante",
		["Dreamfoil"] = "Feuillerêve",
		["Dreaming Glory"] = "Glaurier",
		["Earthroot"] = "Terrestrine",
		["Fadeleaf"] = "Pâlerette",
		["Felweed"] = "Gangrelette",
		["Firebloom"] = "Fleur de feu",
		["Firethorn"] = "Epine de feu",
		["Frost Lotus"] = "Lotus givré",
		["Frozen Herb"] = "Herbe gelée",
		["Ghost Mushroom"] = "Champignon fantôme",
		["Goldclover"] = "Trèfle doré",
		["Golden Sansam"] = "Sansam doré",
		["Goldthorn"] = "Dorépine",
		["Grave Moss"] = "Tombeline",
		["Gromsblood"] = "Gromsang",
		["Icecap"] = "Calot de glace",
		["Icethorn"] = "Glacépine",
		["Khadgar's Whisker"] = "Moustache de Khadgar",
		["Kingsblood"] = "Sang-royal",
		["Lichbloom"] = "Fleur-de-liche",
		["Liferoot"] = "Vietérule",
		["Mageroyal"] = "Mage royal",
		["Mana Thistle"] = "Chardon de mana",
		["Mountain Silversage"] = "Sauge-argent des montagnes",
		["Netherbloom"] = "Néantine",
		["Nightmare Vine"] = "Cauchemardelle",
		["Peacebloom"] = "Pacifique",
		["Plaguebloom"] = "Chagrinelle",
		["Purple Lotus"] = "Lotus pourpre",
		["Ragveil"] = "Voile-misère",
		["Silverleaf"] = "Feuillargent",
		["Stranglekelp"] = "Etouffante",
		["Sungrass"] = "Soleillette",
		["Talandra's Rose"] = "Rose de Talandra",
		["Terocone"] = "Terocône",
		["Tiger Lily"] = "Lys tigré",
		["Wild Steelbloom"] = "Aciérite sauvage",
		["Wintersbite"] = "Hivernale",
		["Stormvine"] = "Vignétincelle",
		["Cinderbloom"] = "Cendrelle",
		["Azshara's Veil"] = "Voile d'Azshara",
		["Heartblossom"] = "Pétale de cœur",
		["Whiptail"] = "Fouettine",
		["Twilight Jasmine"] = "Jasmin crépusculaire",
		["Bloodthistle"] = "Chardon sanglant",
		["Dragon's Teeth"] = "Dents de dragon",
		["Flame Cap"] = "Chapeflamme",
		["Sorrowmoss"] = "Chagrinelle",
	},
	esES = {
		["Adder's Tongue"] = "Lengua de víboris",
		["Ancient Lichen"] = "Liquen Antiguo",
		["Arthas' Tears"] = "Lágrimas de Arthas",
		["Black Lotus"] = "Loto negro",
		["Blindweed"] = "Carolina",
		["Briarthorn"] = "Brezospina",
		["Bruiseweed"] = "Hierba cardenal",
		["Dreamfoil"] = "Hojasueño",
		["Dreaming Glory"] = "Gloria de ensueño",
		["Earthroot"] = "Raíz de tierra",
		["Fadeleaf"] = "Pálida",
		["Felweed"] = "Hierba vil",
		["Firebloom"] = "Flor de fuego",
		["Firethorn"] = "Espino de fuego",
		["Frost Lotus"] = "Loto de escarcha",
		["Frozen Herb"] = "Hierba congelada",
		["Ghost Mushroom"] = "Champiñón fantasma",
		["Goldclover"] = "Trébol de oro",
		["Golden Sansam"] = "Sansam dorado",
		["Goldthorn"] = "Espina de oro",
		["Grave Moss"] = "Musgo de tumba",
		["Gromsblood"] = "Gromsanguina",
		["Icecap"] = "Setelo",
		["Icethorn"] = "Espina de hielo",
		["Khadgar's Whisker"] = "Mostacho de Khadgar",
		["Kingsblood"] = "Sangrerregia",
		["Lichbloom"] = "Flor exánime",
		["Liferoot"] = "Vidarraíz",
		["Mageroyal"] = "Marregal",
		["Mana Thistle"] = "Cardo de maná",
		["Mountain Silversage"] = "Salviargenta de montaña",
		["Netherbloom"] = "Flor abisal",
		["Nightmare Vine"] = "Vid pesadilla",
		["Peacebloom"] = "Flor de paz",
		["Plaguebloom"] = "Flor de peste",
		["Purple Lotus"] = "Loto cárdeno",
		["Ragveil"] = "Velada",
		["Silverleaf"] = "Hojaplata",
		["Stranglekelp"] = "Alga estranguladora",
		["Sungrass"] = "Solea",
		["Talandra's Rose"] = "Rosa de Talandra",
		["Terocone"] = "Teropiña",
		["Tiger Lily"] = "Lirio atigrado",
		["Wild Steelbloom"] = "Acérita salvaje",
		["Wintersbite"] = "Ivernalia",
		["Stormvine"] = "Viñaviento",
		["Cinderbloom"] = "Flor de ceniza",
		["Azshara's Veil"] = "Velo de Azshara",
		["Heartblossom"] = "Flor de corazón",
		["Whiptail"] = "Colátigo",
		["Twilight Jasmine"] = "Jazmín Crepuscular",
		["Bloodthistle"] = "Cardo de sangre",
		["Dragon's Teeth"] = "Dientes de dragón",
		["Flame Cap"] = "Seta flamígera",
		["Sorrowmoss"] = "Musgopena",
	},
	esMX = {
		["Adder's Tongue"] = "Lengua de víboris",
		["Ancient Lichen"] = "Liquen Antiguo",
		["Arthas' Tears"] = "Lágrimas de Arthas",
		["Black Lotus"] = "Loto negro",
		["Blindweed"] = "Carolina",
		["Briarthorn"] = "Brezospina",
		["Bruiseweed"] = "Hierba cardenal",
		["Dreamfoil"] = "Hojasueño",
		["Dreaming Glory"] = "Gloria de ensueño",
		["Earthroot"] = "Raíz de tierra",
		["Fadeleaf"] = "Pálida",
		["Felweed"] = "Hierba vil",
		["Firebloom"] = "Flor de fuego",
		["Firethorn"] = "Espino de fuego",
		["Frost Lotus"] = "Loto de escarcha",
		["Frozen Herb"] = "Hierba congelada",
		["Ghost Mushroom"] = "Champiñón fantasma",
		["Goldclover"] = "Trébol de oro",
		["Golden Sansam"] = "Sansam dorado",
		["Goldthorn"] = "Espina de oro",
		["Grave Moss"] = "Musgo de tumba",
		["Gromsblood"] = "Gromsanguina",
		["Icecap"] = "Setelo",
		["Icethorn"] = "Espina de hielo",
		["Khadgar's Whisker"] = "Mostacho de Khadgar",
		["Kingsblood"] = "Sangrerregia",
		["Lichbloom"] = "Flor exánime",
		["Liferoot"] = "Vidarraíz",
		["Mageroyal"] = "Marregal",
		["Mana Thistle"] = "Cardo de maná",
		["Mountain Silversage"] = "Salviargenta de montaña",
		["Netherbloom"] = "Flor abisal",
		["Nightmare Vine"] = "Vid pesadilla",
		["Peacebloom"] = "Flor de paz",
		["Plaguebloom"] = "Flor de peste",
		["Purple Lotus"] = "Loto cárdeno",
		["Ragveil"] = "Velada",
		["Silverleaf"] = "Hojaplata",
		["Stranglekelp"] = "Alga estranguladora",
		["Sungrass"] = "Solea",
		["Talandra's Rose"] = "Rosa de Talandra",
		["Terocone"] = "Teropiña",
		["Tiger Lily"] = "Lirio atigrado",
		["Wild Steelbloom"] = "Acérita salvaje",
		["Wintersbite"] = "Ivernalia",
		["Stormvine"] = "Viñaviento",
		["Cinderbloom"] = "Flor de ceniza",
		["Azshara's Veil"] = "Velo de Azshara",
		["Heartblossom"] = "Flor de corazón",
		["Whiptail"] = "Colátigo",
		["Twilight Jasmine"] = "Jazmín Crepuscular",
		["Bloodthistle"] = "Cardo de sangre",
		["Dragon's Teeth"] = "Dientes de dragón",
		["Flame Cap"] = "Seta flamígera",
		["Sorrowmoss"] = "Musgopena",
	},
	itIT = {
		["Adder's Tongue"] = "Lingua di vipera",
		["Ancient Lichen"] = "Lichene Antico",
		["Arthas' Tears"] = "Lacrima di Arthas",
		["Black Lotus"] = "Fiore di Loto Nero",
		["Blindweed"] = "Erbacieca",
		["Briarthorn"] = "Grandespina",
		["Bruiseweed"] = "Erbalivida",
		["Dreamfoil"] = "Erba Onirica",
		["Dreaming Glory"] = "Gloria d'Oro",
		["Earthroot"] = "Bulboterro",
		["Fadeleaf"] = "Foglia Eterea",
		["Felweed"] = "Erbavile",
		["Firebloom"] = "Sbocciafuoco",
		["Firethorn"] = "Ardispina",
		["Frost Lotus"] = "Loto Gelido",
		["Frozen Herb"] = "Erba del Gelo",
		["Ghost Mushroom"] = "Fungo Fantasma",
		["Goldclover"] = "Trifoglio d'Oro",
		["Golden Sansam"] = "Sansam Dorato",
		["Goldthorn"] = "Orospino",
		["Grave Moss"] = "Muschio di Tomba",
		["Gromsblood"] = "Sangue di Grom",
		["Icecap"] = "Corolla Invernale",
		["Icethorn"] = "Gelaspina",
		["Khadgar's Whisker"] = "Ciuffo di Khadgar",
		["Kingsblood"] = "Sanguesacro",
		["Lichbloom"] = "Fiore del Lich",
		["Liferoot"] = "Bulbovivo",
		["Mageroyal"] = "Magareale",
		["Mana Thistle"] = "Cardomana",
		["Mountain Silversage"] = "Ramargento Montano",
		["Netherbloom"] = "Sbocciafatuo",
		["Nightmare Vine"] = "Vite dell'Incubo",
		["Peacebloom"] = "Sbocciapace",
		["Plaguebloom"] = "Sbocciapiaga",
		["Purple Lotus"] = "Fiore di Loto Purpureo",
		["Ragveil"] = "Velorotto",
		["Silverleaf"] = "Fogliargenta",
		["Stranglekelp"] = "Algatorta",
		["Sungrass"] = "Erbasole",
		["Talandra's Rose"] = "Rosa di Talandra",
		["Terocone"] = "Terocone",
		["Tiger Lily"] = "Giglio Tigrato",
		["Wild Steelbloom"] = "Fiordiferro Selvatico",
		["Wintersbite"] = "Morso dell'Inverno",  -- guessed
		["Stormvine"] = "Vite Tempestosa",
		["Cinderbloom"] = "Sbocciacenere",
		["Azshara's Veil"] = "Velo di Azshara",
		["Heartblossom"] = "Cuorfiorito",
		["Whiptail"] = "Frustaliana",
		["Twilight Jasmine"] = "Gelsomino del Crepuscolo",
		["Bloodthistle"] = "Cardosangue",
		["Dragon's Teeth"] = "Dente di Drago",
		["Flame Cap"] = "Corolla Infernale",
		["Sorrowmoss"] = "Muschiocupo",
	},
	ptBR = {
		["Adder's Tongue"] = "Língua de Áspide",
		["Ancient Lichen"] = "Líquen-antigo",
		["Arthas' Tears"] = "Lágrimas de Arthas",
		["Black Lotus"] = "Lótus Preto",
		["Blindweed"] = "Ervacega",
		["Briarthorn"] = "Cravespinho",
		["Bruiseweed"] = "Ervamossa",
		["Dreamfoil"] = "Folha-de-sonho",
		["Dreaming Glory"] = "Glória-sonhadora",
		["Earthroot"] = "Raiz-telúrica",
		["Fadeleaf"] = "Some-folha",
		["Felweed"] = "Vilerva",
		["Firebloom"] = "Ignídea",
		["Firethorn"] = "Espinho de Fogo",
		["Frost Lotus"] = "Lótus Gélido",
		["Frozen Herb"] = "Planta Congelada",
		["Ghost Mushroom"] = "Cogumelo-fantasma",
		["Goldclover"] = "Trevo Dourado",
		["Golden Sansam"] = "Sonsona-dourada",
		["Goldthorn"] = "Espinheira-dourada",
		["Grave Moss"] = "Musgo-de-tumba",
		["Gromsblood"] = "Sangue-de-grom",
		["Icecap"] = "Chapéu-de-gelo",
		["Icethorn"] = "Espinho de Gelo",
		["Khadgar's Whisker"] = "Bigode-de-hadgar",
		["Kingsblood"] = "Sangue-real",
		["Lichbloom"] = "Flor-de-lich",
		["Liferoot"] = "Raiz-da-vida",
		["Mageroyal"] = "Magi-real",
		["Mana Thistle"] = "Manacardo",
		["Mountain Silversage"] = "Sávia-prata-da-montanha",
		["Netherbloom"] = "Floretérea",
		["Nightmare Vine"] = "Vinha-do-pesadelo",
		["Peacebloom"] = "Botão-da-paz",
		["Plaguebloom"] = "Botão-da-praga",  -- guessed
		["Purple Lotus"] = "Lótus Roxo",
		["Ragveil"] = "Trapovéu",
		["Silverleaf"] = "Flor-de-seda",
		["Stranglekelp"] = "Estrangulalga",
		["Sungrass"] = "Ervassol",
		["Talandra's Rose"] = "Rosa de Talandra",
		["Terocone"] = "Teropinha",
		["Tiger Lily"] = "Lírio Tigre",
		["Wild Steelbloom"] = "Ácera-agreste",
		["Wintersbite"] = "Modida-do-inverno",	-- guessed
		["Stormvine"] = "Tempesvina",
		["Cinderbloom"] = "Cinzanilha",
		["Azshara's Veil"] = "Véu-de-azshara",
		["Heartblossom"] = "Coronália",
		["Whiptail"] = "Azorrangue",
		["Twilight Jasmine"] = "Jasmim-do-crepúsculo",
		["Bloodthistle"] = "Cardossangue",
		["Dragon's Teeth"] = "Dentes-de-dragão",
		["Flame Cap"] = "Chapéu-de-fogo",
		["Sorrowmoss"] = "Limágoa",
	},	
	zhTW = {
		["Adder's Tongue"] = "奎蛇之舌",
		["Ancient Lichen"] = "古老青苔",
		["Arthas' Tears"] = "阿薩斯之淚",
		["Black Lotus"] = "黑蓮花",
		["Blindweed"] = "盲目草",
		["Briarthorn"] = "石南草",
		["Bruiseweed"] = "跌打草",
		["Dreamfoil"] = "夢葉草",
		["Dreaming Glory"] = "譽夢草",
		["Earthroot"] = "地根草",
		["Fadeleaf"] = "枯葉草",
		["Felweed"] = "魔獄草",
		["Firebloom"] = "火焰花",
		["Firethorn"] = "火棘",
		["Frost Lotus"] = "冰霜蓮花",
		["Frozen Herb"] = "冰凍草藥",
		["Ghost Mushroom"] = "鬼魂菇",
		["Goldclover"] = "金黃苜蓿",
		["Golden Sansam"] = "黃金蔘",
		["Goldthorn"] = "金棘草",
		["Grave Moss"] = "墓地苔",
		["Gromsblood"] = "格羅姆之血",
		["Icecap"] = "冰蓋草",
		["Icethorn"] = "冰棘",
		["Khadgar's Whisker"] = "卡德加的鬍鬚",
		["Kingsblood"] = "皇血草",
		["Lichbloom"] = "低語藤",
		["Liferoot"] = "活根草",
		["Mageroyal"] = "魔皇草",
		["Mana Thistle"] = "法力薊",
		["Mountain Silversage"] = "山鼠草",
		["Netherbloom"] = "虛空花",
		["Nightmare Vine"] = "夢魘根",
		["Peacebloom"] = "寧神花",
		["Plaguebloom"] = "瘟疫花",
		["Purple Lotus"] = "紫蓮花",
		["Ragveil"] = "拉格維花",
		["Silverleaf"] = "銀葉草",
		["Stranglekelp"] = "荊棘藻",
		["Sungrass"] = "太陽草",
		["Talandra's Rose"] = "泰蘭卓的玫瑰",
		["Terocone"] = "泰魯草",
		["Tiger Lily"] = "虎百合",
		["Wild Steelbloom"] = "野鋼花",
		["Wintersbite"] = "冬刺草",
		["Stormvine"] = "風暴藤",
		["Cinderbloom"] = "燼花",
		["Azshara's Veil"] = "艾薩拉的帷紗",
		["Heartblossom"] = "心綻花",
		["Whiptail"] = "鞭尾蜥草",
		["Twilight Jasmine"] = "暮光茉莉",
		["Bloodthistle"] = "血薊",
		["Dragon's Teeth"] = "龍之牙",
		["Flame Cap"] = "火帽花",
		["Sorrowmoss"] = "悲傷苔蘚",
	},
	zhCN = {
		["Adder's Tongue"] = "蛇信草",
		["Ancient Lichen"] = "远古苔",
		["Arthas' Tears"] = "阿尔萨斯之泪",
		["Black Lotus"] = "黑莲花",
		["Blindweed"] = "盲目草",
		["Briarthorn"] = "石南草",
		["Bruiseweed"] = "跌打草",
		["Dreamfoil"] = "梦叶草",
		["Dreaming Glory"] = "梦露花",
		["Earthroot"] = "地根草",
		["Fadeleaf"] = "枯叶草",
		["Felweed"] = "魔草",
		["Firebloom"] = "火焰花",
		["Firethorn"] = "火棘",
		["Frost Lotus"] = "雪莲花",
		["Frozen Herb"] = "冰冷的草药",
		["Ghost Mushroom"] = "幽灵菇",
		["Goldclover"] = "金苜蓿",
		["Golden Sansam"] = "黄金参",
		["Goldthorn"] = "金棘草",
		["Grave Moss"] = "墓地苔",
		["Gromsblood"] = "格罗姆之血",
		["Icecap"] = "冰盖草",
		["Icethorn"] = "冰棘草",
		["Khadgar's Whisker"] = "卡德加的胡须",
		["Kingsblood"] = "皇血草",
		["Lichbloom"] = "巫妖花",
		["Liferoot"] = "活根草",
		["Mageroyal"] = "魔皇草",
		["Mana Thistle"] = "法力蓟",
		["Mountain Silversage"] = "山鼠草",
		["Netherbloom"] = "虚空花",
		["Nightmare Vine"] = "噩梦藤",
		["Peacebloom"] = "宁神花",
		["Plaguebloom"] = "瘟疫花",
		["Purple Lotus"] = "紫莲花",
		["Ragveil"] = "邪雾草",
		["Silverleaf"] = "银叶草",
		["Stranglekelp"] = "荆棘藻",
		["Sungrass"] = "太阳草",
		["Talandra's Rose"] = "塔兰德拉的玫瑰",
		["Terocone"] = "泰罗果",
		["Tiger Lily"] = "卷丹",
		["Wild Steelbloom"] = "野钢花",
		["Wintersbite"] = "冬刺草",
		["Stormvine"] = "风暴藤",
		["Cinderbloom"] = "燃烬草",
		["Azshara's Veil"] = "艾萨拉雾菇",
		["Heartblossom"] = "心灵之花",
		["Whiptail"] = "鞭尾草",
		["Twilight Jasmine"] = "暮光茉莉",
		["Bloodthistle"] = "血蓟",
		["Dragon's Teeth"] = "龙齿草",
		["Flame Cap"] = "烈焰菇",
		["Sorrowmoss"] = "天灾花",
	},
}

local function LHerbs(tag)
	if herbTranslations[GAME_LOCALE] then
		return herbTranslations[GAME_LOCALE][tag] or tag
	else
		return tag  -- Return English name
	end
end


--------------------------------------------------------------------------------------------------------
--                                              HERB DATA                                             --
--------------------------------------------------------------------------------------------------------

local herbs = {
	[2447] = {
		name = LHerbs("Peacebloom"),
		itemID = 2447,
		minLevel = 1,
		zones = {
			[1447] = true,		-- Azshara
			[1943] = true,		-- Azuremyst Isle
			[1950] = true,		-- Bloodmyst Isle
			[1439] = true,		-- Darkshore
			[1426] = true,		-- Dun Morogh
			[1411] = true,		-- Durotar
			[1429] = true,		-- Elwynn Forest
			[1941] = true,		-- Eversong Woods
			[1942] = true,		-- Ghostlands
			[179] = true,		-- Gilneas
			[1432] = true,		-- Loch Modan
			[1412] = true,		-- Mulgore
			[1421] = true,		-- Silverpine Forest
			[1438] = true,		-- Teldrassil
			[1413] = true,		-- The Barrens
			[174] = true,		-- The Lost Isles
			[1420] = true,		-- Tirisfal Glades
			[1436] = true,		-- Westfall
		},
	},
	[765] = {
		name = LHerbs("Silverleaf"),
		itemID = 765,
		minLevel = 1,
		zones = {
			[1447] = true,		-- Azshara
			[1943] = true,		-- Azuremyst Isle
			[1950] = true,		-- Bloodmyst Isle
			[1439] = true,		-- Darkshore
			[1426] = true,		-- Dun Morogh
			[1411] = true,		-- Durotar
			[1429] = true,		-- Elwynn Forest
			[1941] = true,		-- Eversong Woods
			[1942] = true,		-- Ghostlands
			[179] = true,		-- Gilneas
			[1432] = true,		-- Loch Modan
			[1412] = true,		-- Mulgore
			[1421] = true,		-- Silverpine Forest
			[1438] = true,		-- Teldrassil
			[1413] = true,		-- The Barrens
			[174] = true,		-- The Lost Isles
			[1420] = true,		-- Tirisfal Glades
			[1436] = true,		-- Westfall
		},
	},
	[22710] = {
		name = LHerbs("Bloodthistle"),
		itemID = 22710,
		minLevel = 1,
		zones = {
			[1941] = true,		-- Eversong Woods
		},
	},
	[2449] = {
		name = LHerbs("Earthroot"),
		itemID = 2449,
		minLevel = 15,
		zones = {
			[1447] = true,		-- Azshara
			[1943] = true,		-- Azuremyst Isle
			[1950] = true,		-- Bloodmyst Isle
			[1439] = true,		-- Darkshore
			[1426] = true,		-- Dun Morogh
			[1411] = true,		-- Durotar
			[1429] = true,		-- Elwynn Forest
			[1941] = true,		-- Eversong Woods
			[1942] = true,		-- Ghostlands
			[179] = true,		-- Gilneas
			[1432] = true,		-- Loch Modan
			[1412] = true,		-- Mulgore
			[1433] = true,		-- Redridge Mountains
			[1421] = true,		-- Silverpine Forest
			[1438] = true,		-- Teldrassil
			[1413] = true,		-- The Barrens
			[174] = true,		-- The Lost Isles
			[1420] = true,		-- Tirisfal Glades
			[279] = true,		-- Wailing Caverns
			[1436] = true,		-- Westfall
		},
	},
	[785] = {
		name = LHerbs("Mageroyal"),
		itemID = 785,
		minLevel = 50,
		zones = {
			[1440] = true,		-- Ashenvale
			[1447] = true,		-- Azshara
			[1950] = true,		-- Bloodmyst Isle
			[1439] = true,		-- Darkshore
			[1411] = true,		-- Durotar
			[1431] = true,		-- Duskwood
			[1942] = true,		-- Ghostlands
			[1424] = true,		-- Hillsbrad Foothills
			[1432] = true,		-- Loch Modan
			[1433] = true,		-- Redridge Mountains
			[1421] = true,		-- Silverpine Forest
			[199] = true,		-- Southern Barrens
			[1442] = true,		-- Stonetalon Mountains
			[1438] = true,		-- Teldrassil
			[1413] = true,		-- The Barrens
			[1436] = true,		-- Westfall
			[1437] = true,		-- Wetlands
		},
	},
	[2450] = {
		name = LHerbs("Briarthorn"),
		itemID = 2450,
		minLevel = 70,
		zones = {
			[1440] = true,		-- Ashenvale
			[1447] = true,		-- Azshara
			[1950] = true,		-- Bloodmyst Isle
			[1439] = true,		-- Darkshore
			[1431] = true,		-- Duskwood
			[1942] = true,		-- Ghostlands
			[1424] = true,		-- Hillsbrad Foothills
			[1432] = true,		-- Loch Modan
			[301] = true,		-- Razorfen Kraul
			[1433] = true,		-- Redridge Mountains
			[1421] = true,		-- Silverpine Forest
			[1442] = true,		-- Stonetalon Mountains
			[1413] = true,		-- The Barrens
			[1436] = true,		-- Westfall
			[1437] = true,		-- Wetlands
		},
	},
	[3820] = {
		name = LHerbs("Stranglekelp"),
		itemID = 3820,
		minLevel = 85,
		zones = {
			[1459] = true,		-- Alterac Valley
			[1417] = true,		-- Arathi Highlands
			[1440] = true,		-- Ashenvale
			[1447] = true,		-- Azshara
			[1943] = true,		-- Azuremyst Isle
			[221] = true,		-- Blackfathom Deeps
			[1950] = true,		-- Bloodmyst Isle
			[1439] = true,		-- Darkshore
			[1443] = true,		-- Desolace
			[1445] = true,		-- Dustwallow Marsh
			[1444] = true,		-- Feralas
			[1942] = true,		-- Ghostlands
			[1424] = true,		-- Hillsbrad Foothills
			[280] = true,		-- Maraudon
			[1434] = true,		-- Northern Stranglethorn
			[1421] = true,		-- Silverpine Forest
			[224] = true,		-- Stranglethorn Vale
			[1435] = true,		-- Swamp of Sorrows
			[1446] = true,		-- Tanaris
			[1413] = true,		-- The Barrens
			[210] = true,		-- The Cape of Stranglethorn
			[1425] = true,		-- The Hinterlands
			[1441] = true,		-- Thousand Needles
			[1422] = true,		-- Western Plaguelands
			[1436] = true,		-- Westfall
			[1437] = true,		-- Wetlands
		},
	},
	[2453] = {
		name = LHerbs("Bruiseweed"),
		itemID = 2453,
		minLevel = 85,
		zones = {
			[1417] = true,		-- Arathi Highlands
			[1440] = true,		-- Ashenvale
			[221] = true,		-- Blackfathom Deeps
			[1950] = true,		-- Bloodmyst Isle
			[1439] = true,		-- Darkshore
			[1443] = true,		-- Desolace
			[1431] = true,		-- Duskwood
			[1942] = true,		-- Ghostlands
			[1424] = true,		-- Hillsbrad Foothills
			[1432] = true,		-- Loch Modan
			[1433] = true,		-- Redridge Mountains
			[1421] = true,		-- Silverpine Forest
			[1442] = true,		-- Stonetalon Mountains
			[1413] = true,		-- The Barrens
			[1425] = true,		-- The Hinterlands
			[1441] = true,		-- Thousand Needles
			[279] = true,		-- Wailing Caverns
			[1436] = true,		-- Westfall
			[1437] = true,		-- Wetlands
		},
	},
	[3369] = {
		name = LHerbs("Grave Moss"),
		itemID = 3369,
		minLevel = 105,
		zones = {
			[1459] = true,		-- Alterac Valley
			[1417] = true,		-- Arathi Highlands
			[1443] = true,		-- Desolace
			[1431] = true,		-- Duskwood
			[1423] = true,		-- Eastern Plaguelands
			[1424] = true,		-- Hillsbrad Foothills
			[300] = true,		-- Razorfen Downs
			[302] = true,		-- Scarlet Monastery
			[1413] = true,		-- The Barrens
			[1437] = true,		-- Wetlands
		},
	},
	[3355] = {
		name = LHerbs("Wild Steelbloom"),
		itemID = 3355,
		minLevel = 115,
		zones = {
			[1417] = true,		-- Arathi Highlands
			[1440] = true,		-- Ashenvale
			[1418] = true,		-- Badlands
			[1443] = true,		-- Desolace
			[1431] = true,		-- Duskwood
			[1424] = true,		-- Hillsbrad Foothills
			[1434] = true,		-- Northern Stranglethorn
			[224] = true,		-- Stranglethorn Vale
			[1413] = true,		-- The Barrens
			[1425] = true,		-- The Hinterlands
			[1441] = true,		-- Thousand Needles
			[1437] = true,		-- Wetlands
		},
	},
	[3356] = {
		name = LHerbs("Kingsblood"),
		itemID = 3356,
		minLevel = 125,
		zones = {
			[1417] = true,		-- Arathi Highlands
			[1440] = true,		-- Ashenvale
			[1418] = true,		-- Badlands
			[1443] = true,		-- Desolace
			[1431] = true,		-- Duskwood
			[1445] = true,		-- Dustwallow Marsh
			[1444] = true,		-- Feralas
			[1424] = true,		-- Hillsbrad Foothills
			[1434] = true,		-- Northern Stranglethorn
			[302] = true,		-- Scarlet Monastery
			[199] = true,		-- Southern Barrens
			[1442] = true,		-- Stonetalon Mountains
			[224] = true,		-- Stranglethorn Vale
			[1435] = true,		-- Swamp of Sorrows
			[1413] = true,		-- The Barrens
			[1425] = true,		-- The Hinterlands
			[1441] = true,		-- Thousand Needles
			[279] = true,		-- Wailing Caverns
			[1422] = true,		-- Western Plaguelands
			[1437] = true,		-- Wetlands
		},
	},
	[3818] = {
		name = LHerbs("Fadeleaf"),
		itemID = 3818,
		minLevel = 150,
		zones = {
			[1459] = true,		-- Alterac Valley
			[1417] = true,		-- Arathi Highlands
			[1418] = true,		-- Badlands
			[1445] = true,		-- Dustwallow Marsh
			[1444] = true,		-- Feralas
			[1434] = true,		-- Northern Stranglethorn
			[301] = true,		-- Razorfen Kraul
			[302] = true,		-- Scarlet Monastery
			[224] = true,		-- Stranglethorn Vale
			[1435] = true,		-- Swamp of Sorrows
			[210] = true,		-- The Cape of Stranglethorn
			[1425] = true,		-- The Hinterlands
			[1422] = true,		-- Western Plaguelands
		},
	},
	[3821] = {
		name = LHerbs("Goldthorn"),
		itemID = 3821,
		minLevel = 150,
		zones = {
			[1417] = true,		-- Arathi Highlands
			[1418] = true,		-- Badlands
			[1443] = true,		-- Desolace
			[1445] = true,		-- Dustwallow Marsh
			[1444] = true,		-- Feralas
			[1434] = true,		-- Northern Stranglethorn
			[300] = true,		-- Razorfen Downs
			[302] = true,		-- Scarlet Monastery
			[224] = true,		-- Stranglethorn Vale
			[1435] = true,		-- Swamp of Sorrows
			[210] = true,		-- The Cape of Stranglethorn
			[1425] = true,		-- The Hinterlands
		},
	},
	[3357] = {
		name = LHerbs("Liferoot"),
		itemID = 3357,
		minLevel = 150,
		zones = {
			[1417] = true,		-- Arathi Highlands
			[1440] = true,		-- Ashenvale
			[1443] = true,		-- Desolace
			[1445] = true,		-- Dustwallow Marsh
			[1423] = true,		-- Eastern Plaguelands
			[1444] = true,		-- Feralas
			[1424] = true,		-- Hillsbrad Foothills
			[1953] = true,		-- Netherstorm
			[1434] = true,		-- Northern Stranglethorn
			[302] = true,		-- Scarlet Monastery
			[1421] = true,		-- Silverpine Forest
			[199] = true,		-- Southern Barrens
			[224] = true,		-- Stranglethorn Vale
			[1435] = true,		-- Swamp of Sorrows
			[1425] = true,		-- The Hinterlands
			[1441] = true,		-- Thousand Needles
			[279] = true,		-- Wailing Caverns
			[1422] = true,		-- Western Plaguelands
			[1437] = true,		-- Wetlands
		},
	},
	[3358] = {
		name = LHerbs("Khadgar's Whisker"),
		itemID = 3358,
		minLevel = 160,
		zones = {
			[1417] = true,		-- Arathi Highlands
			[1418] = true,		-- Badlands
			[1443] = true,		-- Desolace
			[234] = true,		-- Dire Maul
			[1445] = true,		-- Dustwallow Marsh
			[1423] = true,		-- Eastern Plaguelands
			[1444] = true,		-- Feralas
			[1424] = true,		-- Hillsbrad Foothills
			[1434] = true,		-- Northern Stranglethorn
			[199] = true,		-- Southern Barrens
			[224] = true,		-- Stranglethorn Vale
			[1435] = true,		-- Swamp of Sorrows
			[210] = true,		-- The Cape of Stranglethorn
			[1425] = true,		-- The Hinterlands
			[1422] = true,		-- Western Plaguelands
		},
	},
	[3819] = {
		name = LHerbs("Dragon's Teeth"),
		itemID = 3819,
		minLevel = 195,
		zones = {
			[1418] = true,		-- Badlands
		},
	},
	[4625] = {
		name = LHerbs("Firebloom"),
		itemID = 4625,
		minLevel = 205,
		zones = {
			[1418] = true,		-- Badlands
			[1419] = true,		-- Blasted Lands
			[1428] = true,		-- Burning Steppes
			[1427] = true,		-- Searing Gorge
			[1446] = true,		-- Tanaris
		},
	},
	[8831] = {
		name = LHerbs("Purple Lotus"),
		itemID = 8831,
		minLevel = 210,
		zones = {
			[1440] = true,		-- Ashenvale
			[1418] = true,		-- Badlands
			[1448] = true,		-- Felwood
			[1444] = true,		-- Feralas
			[1434] = true,		-- Northern Stranglethorn
			[224] = true,		-- Stranglethorn Vale
			[1446] = true,		-- Tanaris
			[1425] = true,		-- The Hinterlands
			[233] = true,		-- Zul'Gurub
		},
	},
	[8836] = {
		name = LHerbs("Arthas' Tears"),
		itemID = 8836,
		minLevel = 220,
		zones = {
			[1423] = true,		-- Eastern Plaguelands
			[1448] = true,		-- Felwood
			[300] = true,		-- Razorfen Downs
			[1422] = true,		-- Western Plaguelands
		},
	},
	[8838] = {
		name = LHerbs("Sungrass"),
		itemID = 8838,
		minLevel = 230,
		zones = {
			[1418] = true,		-- Badlands
			[1419] = true,		-- Blasted Lands
			[1428] = true,		-- Burning Steppes
			[234] = true,		-- Dire Maul
			[1423] = true,		-- Eastern Plaguelands
			[1448] = true,		-- Felwood
			[1444] = true,		-- Feralas
			[1427] = true,		-- Searing Gorge
			[1451] = true,		-- Silithus
			[1446] = true,		-- Tanaris
			[1425] = true,		-- The Hinterlands
			[1441] = true,		-- Thousand Needles
			[1449] = true,		-- Un'Goro Crater
			[1422] = true,		-- Western Plaguelands
			[233] = true,		-- Zul'Gurub
		},
	},
	[8839] = {
		name = LHerbs("Blindweed"),
		itemID = 8839,
		minLevel = 235,
		zones = {
			[1459] = true,		-- Alterac Valley
			[1444] = true,		-- Feralas
			[280] = true,		-- Maraudon
			[1435] = true,		-- Swamp of Sorrows
			[1425] = true,		-- The Hinterlands
			[1449] = true,		-- Un'Goro Crater
			[1422] = true,		-- Western Plaguelands
			[1946] = true,		-- Zangarmarsh
		},
	},
	[8845] = {
		name = LHerbs("Ghost Mushroom"),
		itemID = 8845,
		minLevel = 245,
		zones = {
			[1459] = true,		-- Alterac Valley
			[1443] = true,		-- Desolace
			[234] = true,		-- Dire Maul
			[1944] = true,		-- Hellfire Peninsula
			[280] = true,		-- Maraudon
			[1425] = true,		-- The Hinterlands
			[1449] = true,		-- Un'Goro Crater
			[1946] = true,		-- Zangarmarsh
		},
	},
	[8846] = {
		name = LHerbs("Gromsblood"),
		itemID = 8846,
		minLevel = 250,
		zones = {
			[1459] = true,		-- Alterac Valley
			[1440] = true,		-- Ashenvale
			[1419] = true,		-- Blasted Lands
			[1443] = true,		-- Desolace
			[234] = true,		-- Dire Maul
			[1448] = true,		-- Felwood
		},
	},
	[13464] = {
		name = LHerbs("Golden Sansam"),
		itemID = 13464,
		minLevel = 260,
		zones = {
			[1418] = true,		-- Badlands
			[1419] = true,		-- Blasted Lands
			[1428] = true,		-- Burning Steppes
			[1423] = true,		-- Eastern Plaguelands
			[1448] = true,		-- Felwood
			[1444] = true,		-- Feralas
			[1944] = true,		-- Hellfire Peninsula
			[1953] = true,		-- Netherstorm
			[1451] = true,		-- Silithus
			[1435] = true,		-- Swamp of Sorrows
			[1425] = true,		-- The Hinterlands
			[1449] = true,		-- Un'Goro Crater
			[1946] = true,		-- Zangarmarsh
			[233] = true,		-- Zul'Gurub
		},
	},
	[13463] = {
		name = LHerbs("Dreamfoil"),
		itemID = 13463,
		minLevel = 270,
		zones = {
			[1459] = true,		-- Alterac Valley
			[1419] = true,		-- Blasted Lands
			[1428] = true,		-- Burning Steppes
			[234] = true,		-- Dire Maul
			[1423] = true,		-- Eastern Plaguelands
			[1448] = true,		-- Felwood
			[1944] = true,		-- Hellfire Peninsula
			[1451] = true,		-- Silithus
			[1449] = true,		-- Un'Goro Crater
			[1422] = true,		-- Western Plaguelands
			[1946] = true,		-- Zangarmarsh
			[233] = true,		-- Zul'Gurub
		},
	},
	[13467] = {
		name = LHerbs("Icecap"),
		itemID = 13467,
		minLevel = 270,
		zones = {
			[1452] = true,		-- Winterspring
		},
	},
	[13465] = {
		name = LHerbs("Mountain Silversage"),
		itemID = 13465,
		minLevel = 280,
		zones = {
			[1419] = true,		-- Blasted Lands
			[1428] = true,		-- Burning Steppes
			[1423] = true,		-- Eastern Plaguelands
			[1448] = true,		-- Felwood
			[1944] = true,		-- Hellfire Peninsula
			[1451] = true,		-- Silithus
			[1449] = true,		-- Un'Goro Crater
			[1422] = true,		-- Western Plaguelands
			[1452] = true,		-- Winterspring
			[1946] = true,		-- Zangarmarsh
			[233] = true,		-- Zul'Gurub
		},
	},
	[13466] = {
		name = LHerbs("Sorrowmoss"),
		itemID = 13466,
		minLevel = 285,
		zones = {
			[1423] = true,		-- Eastern Plaguelands
			[1435] = true,		-- Swamp of Sorrows
			[1422] = true,		-- Western Plaguelands
		},
	},
	[22785] = {
		name = LHerbs("Felweed"),
		itemID = 22785,
		minLevel = 300,
		zones = {
			[1949] = true,		-- Blade's Edge Mountains
			[1944] = true,		-- Hellfire Peninsula
			[1951] = true,		-- Nagrand
			[1953] = true,		-- Netherstorm
			[1948] = true,		-- Shadowmoon Valley
			[1952] = true,		-- Terokkar Forest
			[266] = true,		-- The Botanica
			[265] = true,		-- The Slave Pens
			[263] = true,		-- The Steamvault
			[262] = true,		-- The Underbog
			[1946] = true,		-- Zangarmarsh
		},
	},
	[13468] = {
		name = LHerbs("Black Lotus"),
		itemID = 13468,
		minLevel = 300,
		zones = {
			[1428] = true,		-- Burning Steppes
			[1423] = true,		-- Eastern Plaguelands
			[1451] = true,		-- Silithus
			[1452] = true,		-- Winterspring
		},
	},
	[22786] = {
		name = LHerbs("Dreaming Glory"),
		itemID = 22786,
		minLevel = 315,
		zones = {
			[1949] = true,		-- Blade's Edge Mountains
			[1944] = true,		-- Hellfire Peninsula
			[1951] = true,		-- Nagrand
			[1953] = true,		-- Netherstorm
			[1948] = true,		-- Shadowmoon Valley
			[1955] = true,		-- Shattrath City
			[1952] = true,		-- Terokkar Forest
			[266] = true,		-- The Botanica
			[1946] = true,		-- Zangarmarsh
		},
	},
	[39970] = {
		name = LHerbs("Firethorn"),
		itemID = 39970,
		minLevel = 325,
		zones = {
			[114] = true,		-- Borean Tundra
		},
	},
	[22789] = {
		name = LHerbs("Terocone"),
		itemID = 22789,
		minLevel = 325,
		zones = {
			[1948] = true,		-- Shadowmoon Valley
			[1952] = true,		-- Terokkar Forest
			[266] = true,		-- The Botanica
		},
	},
	[22787] = {
		name = LHerbs("Ragveil"),
		itemID = 22787,
		minLevel = 325,
		zones = {
			[265] = true,		-- The Slave Pens
			[263] = true,		-- The Steamvault
			[262] = true,		-- The Underbog
			[1946] = true,		-- Zangarmarsh
		},
	},
	[22788] = {
		name = LHerbs("Flame Cap"),
		itemID = 22788,
		minLevel = 335,
		zones = {
			[265] = true,		-- The Slave Pens
			[263] = true,		-- The Steamvault
			[262] = true,		-- The Underbog
			[1946] = true,		-- Zangarmarsh
		},
	},
	[22790] = {
		name = LHerbs("Ancient Lichen"),
		itemID = 22790,
		minLevel = 340,
		zones = {
			[256] = true,		-- Auchenai Crypts
			[272] = true,		-- Mana-Tombs
			[258] = true,		-- Sethekk Halls
			[260] = true,		-- Shadow Labyrinth
			[265] = true,		-- The Slave Pens
			[263] = true,		-- The Steamvault
			[262] = true,		-- The Underbog
		},
	},
	[36901] = {
		name = LHerbs("Goldclover"),
		itemID = 36901,
		minLevel = 350,
		zones = {
			[132] = true,		-- Ahn'kahet: The Old Kingdom
			[157] = true,		-- Azjol-Nerub
			[114] = true,		-- Borean Tundra
			[115] = true,		-- Dragonblight
			[116] = true,		-- Grizzly Hills
			[117] = true,		-- Howling Fjord
			[119] = true,		-- Sholazar Basin
			[147] = true,		-- Ulduar
		},
	},
	[22791] = {
		name = LHerbs("Netherbloom"),
		itemID = 22791,
		minLevel = 350,
		zones = {
			[1953] = true,		-- Netherstorm
			[266] = true,		-- The Botanica
		},
	},
	[22792] = {
		name = LHerbs("Nightmare Vine"),
		itemID = 22792,
		minLevel = 365,
		zones = {
			[1949] = true,		-- Blade's Edge Mountains
			[1944] = true,		-- Hellfire Peninsula
			[1948] = true,		-- Shadowmoon Valley
		},
	},
	[36904] = {
		name = LHerbs("Tiger Lily"),
		itemID = 36904,
		minLevel = 375,
		zones = {
			[132] = true,		-- Ahn'kahet: The Old Kingdom
			[157] = true,		-- Azjol-Nerub
			[114] = true,		-- Borean Tundra
			[116] = true,		-- Grizzly Hills
			[117] = true,		-- Howling Fjord
			[119] = true,		-- Sholazar Basin
		},
	},
	[22793] = {
		name = LHerbs("Mana Thistle"),
		itemID = 22793,
		minLevel = 375,
		zones = {
			[1949] = true,		-- Blade's Edge Mountains
			[1957] = true,		-- Isle of Quel'Danas
			[1951] = true,		-- Nagrand
			[1953] = true,		-- Netherstorm
			[1948] = true,		-- Shadowmoon Valley
			[1952] = true,		-- Terokkar Forest
		},
	},
	[36907] = {
		name = LHerbs("Talandra's Rose"),
		itemID = 36907,
		minLevel = 385,
		zones = {
			[132] = true,		-- Ahn'kahet: The Old Kingdom
			[160] = true,		-- Drak'Tharon Keep
			[153] = true,		-- Gundrak
			[147] = true,		-- Ulduar
			[121] = true,		-- Zul'Drak
		},
	},
	[190173] = {
		name = LHerbs("Frozen Herb"),
		itemID = 190173,
		minLevel = 400,
		zones = {
			[115] = true,		-- Dragonblight
			[1424] = true,		-- Hillsbrad Foothills
			[129] = true,		-- The Nexus
			[123] = true,		-- Wintergrasp
			[121] = true,		-- Zul'Drak
		},
	},
	[36903] = {
		name = LHerbs("Adder's Tongue"),
		itemID = 36903,
		minLevel = 400,
		zones = {
			[160] = true,		-- Drak'Tharon Keep
			[153] = true,		-- Gundrak
			[119] = true,		-- Sholazar Basin
			[147] = true,		-- Ulduar
		},
	},
	[52985] = {
		name = LHerbs("Azshara's Veil"),
		itemID = 52985,
		minLevel = 425,
		zones = {
			[204] = true,		-- Abyssal Depths
			[201] = true,		-- Kelp'thar Forest
			[198] = true,		-- Mount Hyjal
			[205] = true,		-- Shimmering Expanse
			[245] = true,		-- Tol Barad Peninsula
		},
	},
	[52984] = {
		name = LHerbs("Stormvine"),
		itemID = 52984,
		minLevel = 425,
		zones = {
			[204] = true,		-- Abyssal Depths
			[201] = true,		-- Kelp'thar Forest
			[198] = true,		-- Mount Hyjal
			[205] = true,		-- Shimmering Expanse
		},
	},
	[52983] = {
		name = LHerbs("Cinderbloom"),
		itemID = 52983,
		minLevel = 425,
		zones = {
			[207] = true,		-- Deepholm
			[198] = true,		-- Mount Hyjal
			[244] = true,		-- Tol Barad
			[245] = true,		-- Tol Barad Peninsula
			[241] = true,		-- Twilight Highlands
			[249] = true,		-- Uldum
		},
	},
	[36905] = {
		name = LHerbs("Lichbloom"),
		itemID = 36905,
		minLevel = 425,
		zones = {
			[118] = true,		-- Icecrown
			[120] = true,		-- The Storm Peaks
			[147] = true,		-- Ulduar
			[136] = true,		-- Utgarde Pinnacle
			[123] = true,		-- Wintergrasp
		},
	},
	[36906] = {
		name = LHerbs("Icethorn"),
		itemID = 36906,
		minLevel = 435,
		zones = {
			[118] = true,		-- Icecrown
			[142] = true,		-- The Oculus
			[120] = true,		-- The Storm Peaks
			[136] = true,		-- Utgarde Pinnacle
			[123] = true,		-- Wintergrasp
		},
	},
	[36908] = {
		name = LHerbs("Frost Lotus"),
		itemID = 36908,
		minLevel = 450,
		zones = {
			[147] = true,		-- Ulduar
			[123] = true,		-- Wintergrasp
		},
	},
	[52986] = {
		name = LHerbs("Heartblossom"),
		itemID = 52986,
		minLevel = 475,
		zones = {
			[207] = true,		-- Deepholm
		},
	},
	[52988] = {
		name = LHerbs("Whiptail"),
		itemID = 52988,
		minLevel = 500,
		zones = {
			[244] = true,		-- Tol Barad
			[249] = true,		-- Uldum
		},
	},
	[52987] = {
		name = LHerbs("Twilight Jasmine"),
		itemID = 52987,
		minLevel = 525,
		zones = {
			[241] = true,		-- Twilight Highlands
		},
	},
}


local herbsByZone = {
	-- Abyssal Depths
	[204] = {
		[52985] = {
			name = LHerbs("Azshara's Veil"),
			itemID = 52985,
			minLevel = 425,
		},
		[52984] = {
			name = LHerbs("Stormvine"),
			itemID = 52984,
			minLevel = 425,
		},
	},
	-- Ahn'kahet: The Old Kingdom
	[132] = {
		[36901] = {
			name = LHerbs("Goldclover"),
			itemID = 36901,
			minLevel = 350,
		},
		[36907] = {
			name = LHerbs("Talandra's Rose"),
			itemID = 36907,
			minLevel = 385,
		},
		[36904] = {
			name = LHerbs("Tiger Lily"),
			itemID = 36904,
			minLevel = 375,
		},
	},
	-- Alterac Valley
	[1459] = {
		[8839] = {
			name = LHerbs("Blindweed"),
			itemID = 8839,
			minLevel = 235,
		},
		[13463] = {
			name = LHerbs("Dreamfoil"),
			itemID = 13463,
			minLevel = 270,
		},
		[3818] = {
			name = LHerbs("Fadeleaf"),
			itemID = 3818,
			minLevel = 150,
		},
		[8845] = {
			name = LHerbs("Ghost Mushroom"),
			itemID = 8845,
			minLevel = 245,
		},
		[3369] = {
			name = LHerbs("Grave Moss"),
			itemID = 3369,
			minLevel = 105,
		},
		[8846] = {
			name = LHerbs("Gromsblood"),
			itemID = 8846,
			minLevel = 250,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
	},
	-- Arathi Highlands
	[1417] = {
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 85,
		},
		[3818] = {
			name = LHerbs("Fadeleaf"),
			itemID = 3818,
			minLevel = 150,
		},
		[3821] = {
			name = LHerbs("Goldthorn"),
			itemID = 3821,
			minLevel = 150,
		},
		[3369] = {
			name = LHerbs("Grave Moss"),
			itemID = 3369,
			minLevel = 105,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 160,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
		[3357] = {
			name = LHerbs("Liferoot"),
			itemID = 3357,
			minLevel = 150,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[3355] = {
			name = LHerbs("Wild Steelbloom"),
			itemID = 3355,
			minLevel = 115,
		},
	},
	-- Ashenvale
	[1440] = {
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 85,
		},
		[8846] = {
			name = LHerbs("Gromsblood"),
			itemID = 8846,
			minLevel = 250,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
		[3357] = {
			name = LHerbs("Liferoot"),
			itemID = 3357,
			minLevel = 150,
		},
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
		[8831] = {
			name = LHerbs("Purple Lotus"),
			itemID = 8831,
			minLevel = 210,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[3355] = {
			name = LHerbs("Wild Steelbloom"),
			itemID = 3355,
			minLevel = 115,
		},
	},
	-- Auchenai Crypts
	[256] = {
		[22790] = {
			name = LHerbs("Ancient Lichen"),
			itemID = 22790,
			minLevel = 340,
		},
	},
	-- Azjol-Nerub
	[157] = {
		[36901] = {
			name = LHerbs("Goldclover"),
			itemID = 36901,
			minLevel = 350,
		},
		[36904] = {
			name = LHerbs("Tiger Lily"),
			itemID = 36904,
			minLevel = 375,
		},
	},
	-- Azshara
	[1447] = {
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
		[2447] = {
			name = LHerbs("Peacebloom"),
			itemID = 2447,
			minLevel = 1,
		},
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
			minLevel = 1,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
	},
	-- Azuremyst Isle
	[1943] = {
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[2447] = {
			name = LHerbs("Peacebloom"),
			itemID = 2447,
			minLevel = 1,
		},
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
			minLevel = 1,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
	},
	-- Badlands
	[1418] = {
		[3819] = {
			name = LHerbs("Dragon's Teeth"),
			itemID = 3819,
			minLevel = 195,
		},
		[3818] = {
			name = LHerbs("Fadeleaf"),
			itemID = 3818,
			minLevel = 150,
		},
		[4625] = {
			name = LHerbs("Firebloom"),
			itemID = 4625,
			minLevel = 205,
		},
		[13464] = {
			name = LHerbs("Golden Sansam"),
			itemID = 13464,
			minLevel = 260,
		},
		[3821] = {
			name = LHerbs("Goldthorn"),
			itemID = 3821,
			minLevel = 150,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 160,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
		[8831] = {
			name = LHerbs("Purple Lotus"),
			itemID = 8831,
			minLevel = 210,
		},
		[8838] = {
			name = LHerbs("Sungrass"),
			itemID = 8838,
			minLevel = 230,
		},
		[3355] = {
			name = LHerbs("Wild Steelbloom"),
			itemID = 3355,
			minLevel = 115,
		},
	},
	-- Blackfathom Deeps
	[221] = {
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 85,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
	},
	-- Blade's Edge Mountains
	[1949] = {
		[22786] = {
			name = LHerbs("Dreaming Glory"),
			itemID = 22786,
			minLevel = 315,
		},
		[22785] = {
			name = LHerbs("Felweed"),
			itemID = 22785,
			minLevel = 300,
		},
		[22793] = {
			name = LHerbs("Mana Thistle"),
			itemID = 22793,
			minLevel = 375,
		},
		[22792] = {
			name = LHerbs("Nightmare Vine"),
			itemID = 22792,
			minLevel = 365,
		},
	},
	-- Blasted Lands
	[1419] = {
		[13463] = {
			name = LHerbs("Dreamfoil"),
			itemID = 13463,
			minLevel = 270,
		},
		[4625] = {
			name = LHerbs("Firebloom"),
			itemID = 4625,
			minLevel = 205,
		},
		[13464] = {
			name = LHerbs("Golden Sansam"),
			itemID = 13464,
			minLevel = 260,
		},
		[8846] = {
			name = LHerbs("Gromsblood"),
			itemID = 8846,
			minLevel = 250,
		},
		[13465] = {
			name = LHerbs("Mountain Silversage"),
			itemID = 13465,
			minLevel = 280,
		},
		[8838] = {
			name = LHerbs("Sungrass"),
			itemID = 8838,
			minLevel = 230,
		},
	},
	-- Bloodmyst Isle
	[1950] = {
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 85,
		},
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
		[2447] = {
			name = LHerbs("Peacebloom"),
			itemID = 2447,
			minLevel = 1,
		},
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
			minLevel = 1,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
	},
	-- Borean Tundra
	[114] = {
		[39970] = {
			name = LHerbs("Firethorn"),
			itemID = 39970,
			minLevel = 325,
		},
		[36901] = {
			name = LHerbs("Goldclover"),
			itemID = 36901,
			minLevel = 350,
		},
		[36904] = {
			name = LHerbs("Tiger Lily"),
			itemID = 36904,
			minLevel = 375,
		},
	},
	-- Burning Steppes
	[1428] = {
		[13468] = {
			name = LHerbs("Black Lotus"),
			itemID = 13468,
			minLevel = 300,
		},
		[13463] = {
			name = LHerbs("Dreamfoil"),
			itemID = 13463,
			minLevel = 270,
		},
		[4625] = {
			name = LHerbs("Firebloom"),
			itemID = 4625,
			minLevel = 205,
		},
		[13464] = {
			name = LHerbs("Golden Sansam"),
			itemID = 13464,
			minLevel = 260,
		},
		[13465] = {
			name = LHerbs("Mountain Silversage"),
			itemID = 13465,
			minLevel = 280,
		},
		[8838] = {
			name = LHerbs("Sungrass"),
			itemID = 8838,
			minLevel = 230,
		},
	},
	-- Darkshore
	[1439] = {
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 85,
		},
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
		[2447] = {
			name = LHerbs("Peacebloom"),
			itemID = 2447,
			minLevel = 1,
		},
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
			minLevel = 1,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
	},
	-- Deepholm
	[207] = {
		[52983] = {
			name = LHerbs("Cinderbloom"),
			itemID = 52983,
			minLevel = 425,
		},
		[52986] = {
			name = LHerbs("Heartblossom"),
			itemID = 52986,
			minLevel = 475,
		},
	},
	-- Desolace
	[1443] = {
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 85,
		},
		[8845] = {
			name = LHerbs("Ghost Mushroom"),
			itemID = 8845,
			minLevel = 245,
		},
		[3821] = {
			name = LHerbs("Goldthorn"),
			itemID = 3821,
			minLevel = 150,
		},
		[3369] = {
			name = LHerbs("Grave Moss"),
			itemID = 3369,
			minLevel = 105,
		},
		[8846] = {
			name = LHerbs("Gromsblood"),
			itemID = 8846,
			minLevel = 250,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 160,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
		[3357] = {
			name = LHerbs("Liferoot"),
			itemID = 3357,
			minLevel = 150,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[3355] = {
			name = LHerbs("Wild Steelbloom"),
			itemID = 3355,
			minLevel = 115,
		},
	},
	-- Dire Maul
	[234] = {
		[13463] = {
			name = LHerbs("Dreamfoil"),
			itemID = 13463,
			minLevel = 270,
		},
		[8845] = {
			name = LHerbs("Ghost Mushroom"),
			itemID = 8845,
			minLevel = 245,
		},
		[8846] = {
			name = LHerbs("Gromsblood"),
			itemID = 8846,
			minLevel = 250,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 160,
		},
		[8838] = {
			name = LHerbs("Sungrass"),
			itemID = 8838,
			minLevel = 230,
		},
	},
	-- Dragonblight
	[115] = {
		[190173] = {
			name = LHerbs("Frozen Herb"),
			itemID = 190173,
			minLevel = 400,
		},
		[36901] = {
			name = LHerbs("Goldclover"),
			itemID = 36901,
			minLevel = 350,
		},
	},
	-- Drak'Tharon Keep
	[160] = {
		[36903] = {
			name = LHerbs("Adder's Tongue"),
			itemID = 36903,
			minLevel = 400,
		},
		[36907] = {
			name = LHerbs("Talandra's Rose"),
			itemID = 36907,
			minLevel = 385,
		},
	},
	-- Dun Morogh
	[1426] = {
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[2447] = {
			name = LHerbs("Peacebloom"),
			itemID = 2447,
			minLevel = 1,
		},
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
			minLevel = 1,
		},
	},
	-- Durotar
	[1411] = {
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
		[2447] = {
			name = LHerbs("Peacebloom"),
			itemID = 2447,
			minLevel = 1,
		},
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
			minLevel = 1,
		},
	},
	-- Duskwood
	[1431] = {
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 85,
		},
		[3369] = {
			name = LHerbs("Grave Moss"),
			itemID = 3369,
			minLevel = 105,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
		[3355] = {
			name = LHerbs("Wild Steelbloom"),
			itemID = 3355,
			minLevel = 115,
		},
	},
	-- Dustwallow Marsh
	[1445] = {
		[3818] = {
			name = LHerbs("Fadeleaf"),
			itemID = 3818,
			minLevel = 150,
		},
		[3821] = {
			name = LHerbs("Goldthorn"),
			itemID = 3821,
			minLevel = 150,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 160,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
		[3357] = {
			name = LHerbs("Liferoot"),
			itemID = 3357,
			minLevel = 150,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
	},
	-- Eastern Plaguelands
	[1423] = {
		[8836] = {
			name = LHerbs("Arthas' Tears"),
			itemID = 8836,
			minLevel = 220,
		},
		[13468] = {
			name = LHerbs("Black Lotus"),
			itemID = 13468,
			minLevel = 300,
		},
		[13463] = {
			name = LHerbs("Dreamfoil"),
			itemID = 13463,
			minLevel = 270,
		},
		[13464] = {
			name = LHerbs("Golden Sansam"),
			itemID = 13464,
			minLevel = 260,
		},
		[3369] = {
			name = LHerbs("Grave Moss"),
			itemID = 3369,
			minLevel = 105,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 160,
		},
		[3357] = {
			name = LHerbs("Liferoot"),
			itemID = 3357,
			minLevel = 150,
		},
		[13465] = {
			name = LHerbs("Mountain Silversage"),
			itemID = 13465,
			minLevel = 280,
		},
		[13466] = {
			name = LHerbs("Sorrowmoss"),
			itemID = 13466,
			minLevel = 285,
		},
		[8838] = {
			name = LHerbs("Sungrass"),
			itemID = 8838,
			minLevel = 230,
		},
	},
	-- Elwynn Forest
	[1429] = {
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[2447] = {
			name = LHerbs("Peacebloom"),
			itemID = 2447,
			minLevel = 1,
		},
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
			minLevel = 1,
		},
	},
	-- Eversong Woods
	[1941] = {
		[22710] = {
			name = LHerbs("Bloodthistle"),
			itemID = 22710,
			minLevel = 1,
		},
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[2447] = {
			name = LHerbs("Peacebloom"),
			itemID = 2447,
			minLevel = 1,
		},
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
			minLevel = 1,
		},
	},
	-- Felwood
	[1448] = {
		[8836] = {
			name = LHerbs("Arthas' Tears"),
			itemID = 8836,
			minLevel = 220,
		},
		[13463] = {
			name = LHerbs("Dreamfoil"),
			itemID = 13463,
			minLevel = 270,
		},
		[13464] = {
			name = LHerbs("Golden Sansam"),
			itemID = 13464,
			minLevel = 260,
		},
		[8846] = {
			name = LHerbs("Gromsblood"),
			itemID = 8846,
			minLevel = 250,
		},
		[13465] = {
			name = LHerbs("Mountain Silversage"),
			itemID = 13465,
			minLevel = 280,
		},
		[8831] = {
			name = LHerbs("Purple Lotus"),
			itemID = 8831,
			minLevel = 210,
		},
		[8838] = {
			name = LHerbs("Sungrass"),
			itemID = 8838,
			minLevel = 230,
		},
	},
	-- Feralas
	[1444] = {
		[8839] = {
			name = LHerbs("Blindweed"),
			itemID = 8839,
			minLevel = 235,
		},
		[3818] = {
			name = LHerbs("Fadeleaf"),
			itemID = 3818,
			minLevel = 150,
		},
		[13464] = {
			name = LHerbs("Golden Sansam"),
			itemID = 13464,
			minLevel = 260,
		},
		[3821] = {
			name = LHerbs("Goldthorn"),
			itemID = 3821,
			minLevel = 150,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 160,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
		[3357] = {
			name = LHerbs("Liferoot"),
			itemID = 3357,
			minLevel = 150,
		},
		[8831] = {
			name = LHerbs("Purple Lotus"),
			itemID = 8831,
			minLevel = 210,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[8838] = {
			name = LHerbs("Sungrass"),
			itemID = 8838,
			minLevel = 230,
		},
	},
	-- Ghostlands
	[1942] = {
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 85,
		},
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
		[2447] = {
			name = LHerbs("Peacebloom"),
			itemID = 2447,
			minLevel = 1,
		},
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
			minLevel = 1,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
	},
	-- Gilneas
	[179] = {
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[2447] = {
			name = LHerbs("Peacebloom"),
			itemID = 2447,
			minLevel = 1,
		},
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
			minLevel = 1,
		},
	},
	-- Grizzly Hills
	[116] = {
		[36901] = {
			name = LHerbs("Goldclover"),
			itemID = 36901,
			minLevel = 350,
		},
		[36904] = {
			name = LHerbs("Tiger Lily"),
			itemID = 36904,
			minLevel = 375,
		},
	},
	-- Gundrak
	[153] = {
		[36903] = {
			name = LHerbs("Adder's Tongue"),
			itemID = 36903,
			minLevel = 400,
		},
		[36907] = {
			name = LHerbs("Talandra's Rose"),
			itemID = 36907,
			minLevel = 385,
		},
	},
	-- Hellfire Peninsula
	[1944] = {
		[13463] = {
			name = LHerbs("Dreamfoil"),
			itemID = 13463,
			minLevel = 270,
		},
		[22786] = {
			name = LHerbs("Dreaming Glory"),
			itemID = 22786,
			minLevel = 315,
		},
		[22785] = {
			name = LHerbs("Felweed"),
			itemID = 22785,
			minLevel = 300,
		},
		[8845] = {
			name = LHerbs("Ghost Mushroom"),
			itemID = 8845,
			minLevel = 245,
		},
		[13464] = {
			name = LHerbs("Golden Sansam"),
			itemID = 13464,
			minLevel = 260,
		},
		[13465] = {
			name = LHerbs("Mountain Silversage"),
			itemID = 13465,
			minLevel = 280,
		},
		[22792] = {
			name = LHerbs("Nightmare Vine"),
			itemID = 22792,
			minLevel = 365,
		},
	},
	-- Hillsbrad Foothills
	[1424] = {
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 85,
		},
		[190173] = {
			name = LHerbs("Frozen Herb"),
			itemID = 190173,
			minLevel = 400,
		},
		[3369] = {
			name = LHerbs("Grave Moss"),
			itemID = 3369,
			minLevel = 105,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 160,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
		[3357] = {
			name = LHerbs("Liferoot"),
			itemID = 3357,
			minLevel = 150,
		},
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[3355] = {
			name = LHerbs("Wild Steelbloom"),
			itemID = 3355,
			minLevel = 115,
		},
	},
	-- Howling Fjord
	[117] = {
		[36901] = {
			name = LHerbs("Goldclover"),
			itemID = 36901,
			minLevel = 350,
		},
		[36904] = {
			name = LHerbs("Tiger Lily"),
			itemID = 36904,
			minLevel = 375,
		},
	},
	-- Icecrown
	[118] = {
		[36906] = {
			name = LHerbs("Icethorn"),
			itemID = 36906,
			minLevel = 435,
		},
		[36905] = {
			name = LHerbs("Lichbloom"),
			itemID = 36905,
			minLevel = 425,
		},
	},
	-- Isle of Quel'Danas
	[1957] = {
		[22793] = {
			name = LHerbs("Mana Thistle"),
			itemID = 22793,
			minLevel = 375,
		},
	},
	-- Kelp'thar Forest
	[201] = {
		[52985] = {
			name = LHerbs("Azshara's Veil"),
			itemID = 52985,
			minLevel = 425,
		},
		[52984] = {
			name = LHerbs("Stormvine"),
			itemID = 52984,
			minLevel = 425,
		},
	},
	-- Loch Modan
	[1432] = {
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 85,
		},
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
		[2447] = {
			name = LHerbs("Peacebloom"),
			itemID = 2447,
			minLevel = 1,
		},
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
			minLevel = 1,
		},
	},
	-- Mana-Tombs
	[272] = {
		[22790] = {
			name = LHerbs("Ancient Lichen"),
			itemID = 22790,
			minLevel = 340,
		},
	},
	-- Maraudon
	[280] = {
		[8839] = {
			name = LHerbs("Blindweed"),
			itemID = 8839,
			minLevel = 235,
		},
		[8845] = {
			name = LHerbs("Ghost Mushroom"),
			itemID = 8845,
			minLevel = 245,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
	},
	-- Mount Hyjal
	[198] = {
		[52985] = {
			name = LHerbs("Azshara's Veil"),
			itemID = 52985,
			minLevel = 425,
		},
		[52983] = {
			name = LHerbs("Cinderbloom"),
			itemID = 52983,
			minLevel = 425,
		},
		[52984] = {
			name = LHerbs("Stormvine"),
			itemID = 52984,
			minLevel = 425,
		},
	},
	-- Mulgore
	[1412] = {
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[2447] = {
			name = LHerbs("Peacebloom"),
			itemID = 2447,
			minLevel = 1,
		},
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
			minLevel = 1,
		},
	},
	-- Nagrand
	[1951] = {
		[22786] = {
			name = LHerbs("Dreaming Glory"),
			itemID = 22786,
			minLevel = 315,
		},
		[22785] = {
			name = LHerbs("Felweed"),
			itemID = 22785,
			minLevel = 300,
		},
		[22793] = {
			name = LHerbs("Mana Thistle"),
			itemID = 22793,
			minLevel = 375,
		},
	},
	-- Netherstorm
	[1953] = {
		[22786] = {
			name = LHerbs("Dreaming Glory"),
			itemID = 22786,
			minLevel = 315,
		},
		[22785] = {
			name = LHerbs("Felweed"),
			itemID = 22785,
			minLevel = 300,
		},
		[13464] = {
			name = LHerbs("Golden Sansam"),
			itemID = 13464,
			minLevel = 260,
		},
		[3357] = {
			name = LHerbs("Liferoot"),
			itemID = 3357,
			minLevel = 150,
		},
		[22793] = {
			name = LHerbs("Mana Thistle"),
			itemID = 22793,
			minLevel = 375,
		},
		[22791] = {
			name = LHerbs("Netherbloom"),
			itemID = 22791,
			minLevel = 350,
		},
	},
	-- Northern Stranglethorn
	[1434] = {
		[3818] = {
			name = LHerbs("Fadeleaf"),
			itemID = 3818,
			minLevel = 150,
		},
		[3821] = {
			name = LHerbs("Goldthorn"),
			itemID = 3821,
			minLevel = 150,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 160,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
		[3357] = {
			name = LHerbs("Liferoot"),
			itemID = 3357,
			minLevel = 150,
		},
		[8831] = {
			name = LHerbs("Purple Lotus"),
			itemID = 8831,
			minLevel = 210,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[3355] = {
			name = LHerbs("Wild Steelbloom"),
			itemID = 3355,
			minLevel = 115,
		},
	},
	-- Razorfen Downs
	[300] = {
		[8836] = {
			name = LHerbs("Arthas' Tears"),
			itemID = 8836,
			minLevel = 220,
		},
		[3821] = {
			name = LHerbs("Goldthorn"),
			itemID = 3821,
			minLevel = 150,
		},
		[3369] = {
			name = LHerbs("Grave Moss"),
			itemID = 3369,
			minLevel = 105,
		},
	},
	-- Razorfen Kraul
	[301] = {
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[3818] = {
			name = LHerbs("Fadeleaf"),
			itemID = 3818,
			minLevel = 150,
		},
	},
	-- Redridge Mountains
	[1433] = {
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 85,
		},
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
	},
	-- Scarlet Monastery
	[302] = {
		[3818] = {
			name = LHerbs("Fadeleaf"),
			itemID = 3818,
			minLevel = 150,
		},
		[3821] = {
			name = LHerbs("Goldthorn"),
			itemID = 3821,
			minLevel = 150,
		},
		[3369] = {
			name = LHerbs("Grave Moss"),
			itemID = 3369,
			minLevel = 105,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
		[3357] = {
			name = LHerbs("Liferoot"),
			itemID = 3357,
			minLevel = 150,
		},
	},
	-- Searing Gorge
	[1427] = {
		[4625] = {
			name = LHerbs("Firebloom"),
			itemID = 4625,
			minLevel = 205,
		},
		[8838] = {
			name = LHerbs("Sungrass"),
			itemID = 8838,
			minLevel = 230,
		},
	},
	-- Sethekk Halls
	[258] = {
		[22790] = {
			name = LHerbs("Ancient Lichen"),
			itemID = 22790,
			minLevel = 340,
		},
	},
	-- Shadow Labyrinth
	[260] = {
		[22790] = {
			name = LHerbs("Ancient Lichen"),
			itemID = 22790,
			minLevel = 340,
		},
	},
	-- Shadowmoon Valley
	[1948] = {
		[22786] = {
			name = LHerbs("Dreaming Glory"),
			itemID = 22786,
			minLevel = 315,
		},
		[22785] = {
			name = LHerbs("Felweed"),
			itemID = 22785,
			minLevel = 300,
		},
		[22793] = {
			name = LHerbs("Mana Thistle"),
			itemID = 22793,
			minLevel = 375,
		},
		[22792] = {
			name = LHerbs("Nightmare Vine"),
			itemID = 22792,
			minLevel = 365,
		},
		[22789] = {
			name = LHerbs("Terocone"),
			itemID = 22789,
			minLevel = 325,
		},
	},
	-- Shattrath City
	[1955] = {
		[22786] = {
			name = LHerbs("Dreaming Glory"),
			itemID = 22786,
			minLevel = 315,
		},
	},
	-- Shimmering Expanse
	[205] = {
		[52985] = {
			name = LHerbs("Azshara's Veil"),
			itemID = 52985,
			minLevel = 425,
		},
		[52984] = {
			name = LHerbs("Stormvine"),
			itemID = 52984,
			minLevel = 425,
		},
	},
	-- Sholazar Basin
	[119] = {
		[36903] = {
			name = LHerbs("Adder's Tongue"),
			itemID = 36903,
			minLevel = 400,
		},
		[36901] = {
			name = LHerbs("Goldclover"),
			itemID = 36901,
			minLevel = 350,
		},
		[36904] = {
			name = LHerbs("Tiger Lily"),
			itemID = 36904,
			minLevel = 375,
		},
	},
	-- Silithus
	[1451] = {
		[13468] = {
			name = LHerbs("Black Lotus"),
			itemID = 13468,
			minLevel = 300,
		},
		[13463] = {
			name = LHerbs("Dreamfoil"),
			itemID = 13463,
			minLevel = 270,
		},
		[13464] = {
			name = LHerbs("Golden Sansam"),
			itemID = 13464,
			minLevel = 260,
		},
		[13465] = {
			name = LHerbs("Mountain Silversage"),
			itemID = 13465,
			minLevel = 280,
		},
		[8838] = {
			name = LHerbs("Sungrass"),
			itemID = 8838,
			minLevel = 230,
		},
	},
	-- Silverpine Forest
	[1421] = {
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 85,
		},
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[3357] = {
			name = LHerbs("Liferoot"),
			itemID = 3357,
			minLevel = 150,
		},
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
		[2447] = {
			name = LHerbs("Peacebloom"),
			itemID = 2447,
			minLevel = 1,
		},
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
			minLevel = 1,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
	},
	-- Southern Barrens
	[199] = {
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 160,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
		[3357] = {
			name = LHerbs("Liferoot"),
			itemID = 3357,
			minLevel = 150,
		},
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
	},
	-- Stonetalon Mountains
	[1442] = {
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 85,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
	},
	-- Stranglethorn Vale
	[224] = {
		[3818] = {
			name = LHerbs("Fadeleaf"),
			itemID = 3818,
			minLevel = 150,
		},
		[3821] = {
			name = LHerbs("Goldthorn"),
			itemID = 3821,
			minLevel = 150,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 160,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
		[3357] = {
			name = LHerbs("Liferoot"),
			itemID = 3357,
			minLevel = 150,
		},
		[8831] = {
			name = LHerbs("Purple Lotus"),
			itemID = 8831,
			minLevel = 210,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[3355] = {
			name = LHerbs("Wild Steelbloom"),
			itemID = 3355,
			minLevel = 115,
		},
	},
	-- Swamp of Sorrows
	[1435] = {
		[8839] = {
			name = LHerbs("Blindweed"),
			itemID = 8839,
			minLevel = 235,
		},
		[3818] = {
			name = LHerbs("Fadeleaf"),
			itemID = 3818,
			minLevel = 150,
		},
		[13464] = {
			name = LHerbs("Golden Sansam"),
			itemID = 13464,
			minLevel = 260,
		},
		[3821] = {
			name = LHerbs("Goldthorn"),
			itemID = 3821,
			minLevel = 150,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 160,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
		[3357] = {
			name = LHerbs("Liferoot"),
			itemID = 3357,
			minLevel = 150,
		},
		[13466] = {
			name = LHerbs("Sorrowmoss"),
			itemID = 13466,
			minLevel = 285,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
	},
	-- Tanaris
	[1446] = {
		[4625] = {
			name = LHerbs("Firebloom"),
			itemID = 4625,
			minLevel = 205,
		},
		[8831] = {
			name = LHerbs("Purple Lotus"),
			itemID = 8831,
			minLevel = 210,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[8838] = {
			name = LHerbs("Sungrass"),
			itemID = 8838,
			minLevel = 230,
		},
	},
	-- Teldrassil
	[1438] = {
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
		[2447] = {
			name = LHerbs("Peacebloom"),
			itemID = 2447,
			minLevel = 1,
		},
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
			minLevel = 1,
		},
	},
	-- Terokkar Forest
	[1952] = {
		[22786] = {
			name = LHerbs("Dreaming Glory"),
			itemID = 22786,
			minLevel = 315,
		},
		[22785] = {
			name = LHerbs("Felweed"),
			itemID = 22785,
			minLevel = 300,
		},
		[22793] = {
			name = LHerbs("Mana Thistle"),
			itemID = 22793,
			minLevel = 375,
		},
		[22789] = {
			name = LHerbs("Terocone"),
			itemID = 22789,
			minLevel = 325,
		},
	},
	-- The Barrens
	[1413] = {
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 85,
		},
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[3369] = {
			name = LHerbs("Grave Moss"),
			itemID = 3369,
			minLevel = 105,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
		[2447] = {
			name = LHerbs("Peacebloom"),
			itemID = 2447,
			minLevel = 1,
		},
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
			minLevel = 1,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[3355] = {
			name = LHerbs("Wild Steelbloom"),
			itemID = 3355,
			minLevel = 115,
		},
	},
	-- The Botanica
	[266] = {
		[22786] = {
			name = LHerbs("Dreaming Glory"),
			itemID = 22786,
			minLevel = 315,
		},
		[22785] = {
			name = LHerbs("Felweed"),
			itemID = 22785,
			minLevel = 300,
		},
		[22791] = {
			name = LHerbs("Netherbloom"),
			itemID = 22791,
			minLevel = 350,
		},
		[22789] = {
			name = LHerbs("Terocone"),
			itemID = 22789,
			minLevel = 325,
		},
	},
	-- The Cape of Stranglethorn
	[210] = {
		[3818] = {
			name = LHerbs("Fadeleaf"),
			itemID = 3818,
			minLevel = 150,
		},
		[3821] = {
			name = LHerbs("Goldthorn"),
			itemID = 3821,
			minLevel = 150,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 160,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
	},
	-- The Hinterlands
	[1425] = {
		[8839] = {
			name = LHerbs("Blindweed"),
			itemID = 8839,
			minLevel = 235,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 85,
		},
		[3818] = {
			name = LHerbs("Fadeleaf"),
			itemID = 3818,
			minLevel = 150,
		},
		[8845] = {
			name = LHerbs("Ghost Mushroom"),
			itemID = 8845,
			minLevel = 245,
		},
		[13464] = {
			name = LHerbs("Golden Sansam"),
			itemID = 13464,
			minLevel = 260,
		},
		[3821] = {
			name = LHerbs("Goldthorn"),
			itemID = 3821,
			minLevel = 150,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 160,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
		[3357] = {
			name = LHerbs("Liferoot"),
			itemID = 3357,
			minLevel = 150,
		},
		[8831] = {
			name = LHerbs("Purple Lotus"),
			itemID = 8831,
			minLevel = 210,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[8838] = {
			name = LHerbs("Sungrass"),
			itemID = 8838,
			minLevel = 230,
		},
		[3355] = {
			name = LHerbs("Wild Steelbloom"),
			itemID = 3355,
			minLevel = 115,
		},
	},
	-- The Lost Isles
	[174] = {
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[2447] = {
			name = LHerbs("Peacebloom"),
			itemID = 2447,
			minLevel = 1,
		},
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
			minLevel = 1,
		},
	},
	-- The Nexus
	[129] = {
		[190173] = {
			name = LHerbs("Frozen Herb"),
			itemID = 190173,
			minLevel = 400,
		},
	},
	-- The Oculus
	[142] = {
		[36906] = {
			name = LHerbs("Icethorn"),
			itemID = 36906,
			minLevel = 435,
		},
	},
	-- The Slave Pens
	[265] = {
		[22790] = {
			name = LHerbs("Ancient Lichen"),
			itemID = 22790,
			minLevel = 340,
		},
		[22785] = {
			name = LHerbs("Felweed"),
			itemID = 22785,
			minLevel = 300,
		},
		[22788] = {
			name = LHerbs("Flame Cap"),
			itemID = 22788,
			minLevel = 335,
		},
		[22787] = {
			name = LHerbs("Ragveil"),
			itemID = 22787,
			minLevel = 325,
		},
	},
	-- The Steamvault
	[263] = {
		[22790] = {
			name = LHerbs("Ancient Lichen"),
			itemID = 22790,
			minLevel = 340,
		},
		[22785] = {
			name = LHerbs("Felweed"),
			itemID = 22785,
			minLevel = 300,
		},
		[22788] = {
			name = LHerbs("Flame Cap"),
			itemID = 22788,
			minLevel = 335,
		},
		[22787] = {
			name = LHerbs("Ragveil"),
			itemID = 22787,
			minLevel = 325,
		},
	},
	-- The Storm Peaks
	[120] = {
		[36906] = {
			name = LHerbs("Icethorn"),
			itemID = 36906,
			minLevel = 435,
		},
		[36905] = {
			name = LHerbs("Lichbloom"),
			itemID = 36905,
			minLevel = 425,
		},
	},
	-- The Underbog
	[262] = {
		[22790] = {
			name = LHerbs("Ancient Lichen"),
			itemID = 22790,
			minLevel = 340,
		},
		[22785] = {
			name = LHerbs("Felweed"),
			itemID = 22785,
			minLevel = 300,
		},
		[22788] = {
			name = LHerbs("Flame Cap"),
			itemID = 22788,
			minLevel = 335,
		},
		[22787] = {
			name = LHerbs("Ragveil"),
			itemID = 22787,
			minLevel = 325,
		},
	},
	-- Thousand Needles
	[1441] = {
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 85,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
		[3357] = {
			name = LHerbs("Liferoot"),
			itemID = 3357,
			minLevel = 150,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[8838] = {
			name = LHerbs("Sungrass"),
			itemID = 8838,
			minLevel = 230,
		},
		[3355] = {
			name = LHerbs("Wild Steelbloom"),
			itemID = 3355,
			minLevel = 115,
		},
	},
	-- Tirisfal Glades
	[1420] = {
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[2447] = {
			name = LHerbs("Peacebloom"),
			itemID = 2447,
			minLevel = 1,
		},
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
			minLevel = 1,
		},
	},
	-- Tol Barad
	[244] = {
		[52983] = {
			name = LHerbs("Cinderbloom"),
			itemID = 52983,
			minLevel = 425,
		},
		[52988] = {
			name = LHerbs("Whiptail"),
			itemID = 52988,
			minLevel = 500,
		},
	},
	-- Tol Barad Peninsula
	[245] = {
		[52985] = {
			name = LHerbs("Azshara's Veil"),
			itemID = 52985,
			minLevel = 425,
		},
		[52983] = {
			name = LHerbs("Cinderbloom"),
			itemID = 52983,
			minLevel = 425,
		},
	},
	-- Twilight Highlands
	[241] = {
		[52983] = {
			name = LHerbs("Cinderbloom"),
			itemID = 52983,
			minLevel = 425,
		},
		[52987] = {
			name = LHerbs("Twilight Jasmine"),
			itemID = 52987,
			minLevel = 525,
		},
	},
	-- Ulduar
	[147] = {
		[36903] = {
			name = LHerbs("Adder's Tongue"),
			itemID = 36903,
			minLevel = 400,
		},
		[36908] = {
			name = LHerbs("Frost Lotus"),
			itemID = 36908,
			minLevel = 450,
		},
		[36901] = {
			name = LHerbs("Goldclover"),
			itemID = 36901,
			minLevel = 350,
		},
		[36905] = {
			name = LHerbs("Lichbloom"),
			itemID = 36905,
			minLevel = 425,
		},
		[36905] = {
			name = LHerbs("Lichbloom"),
			itemID = 36905,
			minLevel = 425,
		},
		[36907] = {
			name = LHerbs("Talandra's Rose"),
			itemID = 36907,
			minLevel = 385,
		},
	},
	-- Uldum
	[249] = {
		[52983] = {
			name = LHerbs("Cinderbloom"),
			itemID = 52983,
			minLevel = 425,
		},
		[52988] = {
			name = LHerbs("Whiptail"),
			itemID = 52988,
			minLevel = 500,
		},
	},
	-- Un'Goro Crater
	[1449] = {
		[8839] = {
			name = LHerbs("Blindweed"),
			itemID = 8839,
			minLevel = 235,
		},
		[13463] = {
			name = LHerbs("Dreamfoil"),
			itemID = 13463,
			minLevel = 270,
		},
		[8845] = {
			name = LHerbs("Ghost Mushroom"),
			itemID = 8845,
			minLevel = 245,
		},
		[13464] = {
			name = LHerbs("Golden Sansam"),
			itemID = 13464,
			minLevel = 260,
		},
		[13465] = {
			name = LHerbs("Mountain Silversage"),
			itemID = 13465,
			minLevel = 280,
		},
		[8838] = {
			name = LHerbs("Sungrass"),
			itemID = 8838,
			minLevel = 230,
		},
	},
	-- Utgarde Pinnacle
	[136] = {
		[36906] = {
			name = LHerbs("Icethorn"),
			itemID = 36906,
			minLevel = 435,
		},
		[36905] = {
			name = LHerbs("Lichbloom"),
			itemID = 36905,
			minLevel = 425,
		},
	},
	-- Wailing Caverns
	[279] = {
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 85,
		},
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
		[3357] = {
			name = LHerbs("Liferoot"),
			itemID = 3357,
			minLevel = 150,
		},
	},
	-- Western Plaguelands
	[1422] = {
		[8836] = {
			name = LHerbs("Arthas' Tears"),
			itemID = 8836,
			minLevel = 220,
		},
		[8839] = {
			name = LHerbs("Blindweed"),
			itemID = 8839,
			minLevel = 235,
		},
		[13463] = {
			name = LHerbs("Dreamfoil"),
			itemID = 13463,
			minLevel = 270,
		},
		[3818] = {
			name = LHerbs("Fadeleaf"),
			itemID = 3818,
			minLevel = 150,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 160,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
		[3357] = {
			name = LHerbs("Liferoot"),
			itemID = 3357,
			minLevel = 150,
		},
		[13465] = {
			name = LHerbs("Mountain Silversage"),
			itemID = 13465,
			minLevel = 280,
		},
		[13466] = {
			name = LHerbs("Sorrowmoss"),
			itemID = 13466,
			minLevel = 285,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[8838] = {
			name = LHerbs("Sungrass"),
			itemID = 8838,
			minLevel = 230,
		},
	},
	-- Westfall
	[1436] = {
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 85,
		},
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
		[2447] = {
			name = LHerbs("Peacebloom"),
			itemID = 2447,
			minLevel = 1,
		},
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
			minLevel = 1,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
	},
	-- Wetlands
	[1437] = {
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 85,
		},
		[3369] = {
			name = LHerbs("Grave Moss"),
			itemID = 3369,
			minLevel = 105,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
		[3357] = {
			name = LHerbs("Liferoot"),
			itemID = 3357,
			minLevel = 150,
		},
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[3355] = {
			name = LHerbs("Wild Steelbloom"),
			itemID = 3355,
			minLevel = 115,
		},
	},
	-- Wintergrasp
	[123] = {
		[36908] = {
			name = LHerbs("Frost Lotus"),
			itemID = 36908,
			minLevel = 450,
		},
		[190173] = {
			name = LHerbs("Frozen Herb"),
			itemID = 190173,
			minLevel = 400,
		},
		[36906] = {
			name = LHerbs("Icethorn"),
			itemID = 36906,
			minLevel = 435,
		},
		[36905] = {
			name = LHerbs("Lichbloom"),
			itemID = 36905,
			minLevel = 425,
		},
	},
	-- Winterspring
	[1452] = {
		[13468] = {
			name = LHerbs("Black Lotus"),
			itemID = 13468,
			minLevel = 300,
		},
		[13467] = {
			name = LHerbs("Icecap"),
			itemID = 13467,
			minLevel = 270,
		},
		[13465] = {
			name = LHerbs("Mountain Silversage"),
			itemID = 13465,
			minLevel = 280,
		},
	},
	-- Zangarmarsh
	[1946] = {
		[8839] = {
			name = LHerbs("Blindweed"),
			itemID = 8839,
			minLevel = 235,
		},
		[13463] = {
			name = LHerbs("Dreamfoil"),
			itemID = 13463,
			minLevel = 270,
		},
		[22786] = {
			name = LHerbs("Dreaming Glory"),
			itemID = 22786,
			minLevel = 315,
		},
		[22785] = {
			name = LHerbs("Felweed"),
			itemID = 22785,
			minLevel = 300,
		},
		[22788] = {
			name = LHerbs("Flame Cap"),
			itemID = 22788,
			minLevel = 335,
		},
		[8845] = {
			name = LHerbs("Ghost Mushroom"),
			itemID = 8845,
			minLevel = 245,
		},
		[13464] = {
			name = LHerbs("Golden Sansam"),
			itemID = 13464,
			minLevel = 260,
		},
		[13465] = {
			name = LHerbs("Mountain Silversage"),
			itemID = 13465,
			minLevel = 280,
		},
		[22787] = {
			name = LHerbs("Ragveil"),
			itemID = 22787,
			minLevel = 325,
		},
	},
	-- Zul'Drak
	[121] = {
		[190173] = {
			name = LHerbs("Frozen Herb"),
			itemID = 190173,
			minLevel = 400,
		},
		[36907] = {
			name = LHerbs("Talandra's Rose"),
			itemID = 36907,
			minLevel = 385,
		},
	},
	-- Zul'Gurub
	[233] = {
		[13463] = {
			name = LHerbs("Dreamfoil"),
			itemID = 13463,
			minLevel = 270,
		},
		[13464] = {
			name = LHerbs("Golden Sansam"),
			itemID = 13464,
			minLevel = 260,
		},
		[13465] = {
			name = LHerbs("Mountain Silversage"),
			itemID = 13465,
			minLevel = 280,
		},
		[8831] = {
			name = LHerbs("Purple Lotus"),
			itemID = 8831,
			minLevel = 210,
		},
		[8838] = {
			name = LHerbs("Sungrass"),
			itemID = 8838,
			minLevel = 230,
		},
	},
}




--------------------------------------------------------------------------------------------------------
--                                           HERB FUNCTIONS                                           --
--------------------------------------------------------------------------------------------------------


-- Returns for the specified herb:
--  - name
--  - itemID
--  - minLevel
--  - zones; table: k = mapID
function Tourist:GetHerb(herbItemID)
	return herbs[herbItemID]
end

-- Returns an r, g and b value indicating the gathering difficulty of the specified herb
function Tourist:GetHerbSkillColor(herbItemID, currentSkill)
	local herb = Tourist:GetHerb(herbItemID)
	if herb then
		return Tourist:GetGatheringSkillColor(herb.minLevel, currentSkill)
	else
		-- White
		return 1, 1, 1
	end
end

local function herbSorter(a, b)
	return a.minLevel < b.minLevel
end

-- Iterates through all standard herbs, returning for each herb:
--  - name
--  - itemID
--  - minLevel
--  - zones; table: k = mapID
function Tourist:IterateHerbs()
	for k in pairs(t) do
		t[k] = nil
	end
	for k, v in pairs(herbs) do
		t[#t+1] = v  -- v contains all data including k
	end
	table.sort(t, herbSorter)
	t.n = 0
	return myiter, t, nil
end

-- Iterates through all standard herbs within the specified zone, returning for each herb:
--  - name
--  - itemID
--  - minLevel
function Tourist:IterateHerbsByZone(mapID)
	local zoneHerbs = herbsByZone[mapID]
	if type(zoneHerbs) == "table" then
		for k in pairs(t) do
			t[k] = nil
		end
		for k, v in pairs(zoneHerbs) do
			t[#t+1] = v  -- v contains all data including k
		end
		table.sort(t, herbSorter)
		t.n = 0
		return myiter, t, nil
	else
		return retOne, zoneHerbs, nil
	end
end

-- Iterates through the mapIDs of the zones in which the specified herb can be found
function Tourist:IterateZonesByHerb(herbItemID)
	local herb, zones
	herb = Tourist:GetHerb(herbItemID)
	if herb then zones = herb.zones end

	if not zones then
		return retNil
	elseif type(zones) == "table" then
		for k in pairs(t) do
			t[k] = nil
		end
		for k, v in pairs(zones) do
			t[#t+1] = k
		end
		table.sort(t, mysort)
		t.n = 0
		return myiter, t, nil
	else
		return retOne, zones, nil
	end
end

-- Returns true if there are any standard herb nodes in the zone
function Tourist:DoesZoneHaveHerbs(zone)
	local mapID = Tourist:GetZoneMapID(zone) or zone
	return not not herbsByZone[mapID]
end

--------------------------------------------------------------------------------------------------------
--                                        MINING TRANSLATIONS                                         --
--------------------------------------------------------------------------------------------------------

-- Pulled from GatherMate2 Classic (except the ores)
local miningTranslations = {
	koKR = {
		["Adamantite Deposit"] = "아다만타이트 광맥",
		["Adamantite Ore"] = "아다만타이트 광석",
		["Cobalt Deposit"] = "코발트 광맥",
		["Cobalt Ore"] = "코발트 광석",
		["Copper Ore"] = "구리 광석",
		["Copper Vein"] = "구리 광맥",
		["Dark Iron Deposit"] = "검은무쇠 광맥",
		["Dark Iron Ore"] = "검은 무쇠 광석",
		["Fel Iron Deposit"] = "지옥무쇠 광맥",
		["Fel Iron Ore"] = "지옥무쇠 광석",
		["Gold Ore"] = "금 광석",
		["Gold Vein"] = "금 광맥",
		["Hakkari Thorium Vein"] = "토륨 광맥",
		["Iron Deposit"] = "철 광맥",
		["Iron Ore"] = "철광석",
		["Khorium Ore"] = "코륨 광석",
		["Khorium Vein"] = "코륨 광맥",
		["Mithril Deposit"] = "미스릴 광맥",
		["Mithril Ore"] = "미스릴 광석",
		["Ooze Covered Gold Vein"] = "진흙으로 덮인 금 광맥",
		["Ooze Covered Mithril Deposit"] = "진흙으로 덮인 미스릴 광맥",
		["Ooze Covered Rich Thorium Vein"] = "진흙으로 덮인 풍부한 토륨 광맥",
		["Ooze Covered Silver Vein"] = "진흙으로 덮인 은 광맥",
		["Ooze Covered Truesilver Deposit"] = "진흙으로 덮인 진은 광맥",
		["Ooze Covered Thorium Vein"] = "진흙으로 덮인 토륨 광맥",
		["Pure Saronite Deposit"] = "순수한 사로나이트 광맥",
		["Rich Adamantite Deposit"] = "풍부한 아다만타이트 광맥",
		["Rich Cobalt Deposit"] = "풍부한 코발트 광맥",
		["Rich Saronite Deposit"] = "풍부한 사로나이트 광맥",
		["Rich Thorium Vein"] = "풍부한 토륨 광맥",
		["Saronite Deposit"] = "사로나이트 광맥",
		["Saronite Ore"] = "사로나이트 광석",
		["Silver Ore"] = "은 광석",
		["Silver Vein"] = "은 광맥",
		["Small Thorium Vein"] = "작은 토륨 광맥",
		["Thorium Ore"] = "토륨 광석",
		["Tin Ore"] = "주석 광석",
		["Tin Vein"] = "주석 광맥",
		["Titanium Ore"] = "티타늄 광석",
		["Titanium Vein"] = "티타늄 광맥",
		["Truesilver Deposit"] = "진은 광맥",
		["Truesilver Ore"] = "진은 광석",
		["Elementium Ore"] = "엘레멘티움 광석",
		["Elementium Vein"] = "엘레멘티움 광맥",
		["Obsidium Deposit"] = "흑요암 광맥",
		["Obsidium Ore"] = "흑요암 광석",
		["Pyrite Deposit"] = "황철석 광맥",
		["Pyrite Ore"] = "황철석 광석",
		["Rich Elementium Vein"] = "풍부한 엘레멘티움 광맥",
		["Rich Obsidium Deposit"] = "풍부한 흑요암 광맥",
		["Rich Pyrite Deposit"] = "풍부한 황철석 광맥",
	},
	deDE = {
		["Adamantite Deposit"] = "Adamantitvorkommen",
		["Adamantite Ore"] = "Adamantiterz",
		["Cobalt Deposit"] = "Kobaltvorkommen",
		["Cobalt Ore"] = "Kobaltertz",
		["Copper Ore"] = "Kupfererz",
		["Copper Vein"] = "Kupfervorkommen",
		["Dark Iron Deposit"] = "Dunkeleisenablagerung",
		["Dark Iron Ore"] = "Dunkeleisenerz",
		["Fel Iron Deposit"] = "Teufelseisenvorkommen",
		["Fel Iron Ore"] = "Teufelseisenerz",
		["Gold Ore"] = "Golderz",
		["Gold Vein"] = "Goldvorkommen",
		["Hakkari Thorium Vein"] = "Hakkari Thoriumvorkommen",
		["Iron Deposit"] = "Eisenvorkommen",
		["Iron Ore"] = "Eisenerz",
		["Khorium Ore"] = "Khoriumerz",
		["Khorium Vein"] = "Khoriumader",
		["Mithril Deposit"] = "Mithrilablagerung",
		["Mithril Ore"] = "Mithrilerz",
		["Ooze Covered Gold Vein"] = "Schlammbedecktes Goldvorkommen",
		["Ooze Covered Mithril Deposit"] = "Schlammbedeckte Mithrilablagerung",
		["Ooze Covered Rich Thorium Vein"] = "Schlammbedecktes reiches Thoriumvorkommen",
		["Ooze Covered Silver Vein"] = "Schlammbedecktes Silbervorkommen",
		["Ooze Covered Truesilver Deposit"] = "Schlammbedecktes Echtsilbervorkommen",
		["Ooze Covered Thorium Vein"] = "Schlammbedeckte Thoriumader",
		["Pure Saronite Deposit"] = "Reine Saronitablagerung",
		["Rich Adamantite Deposit"] = "Reiches Adamantitvorkommen",
		["Rich Cobalt Deposit"] = "Reiches Kobaltvorkommen",
		["Rich Saronite Deposit"] = "Reiches Saronitvorkommen",
		["Rich Thorium Vein"] = "Reiches Thoriumvorkommen",
		["Saronite Deposit"] = "Saronitvorkommen",
		["Saronite Ore"] = "Saronitertz",
		["Silver Ore"] = "Silbererz",
		["Silver Vein"] = "Silbervorkommen",
		["Small Thorium Vein"] = "Kleines Thoriumvorkommen",
		["Thorium Ore"] = "Thoriumerz",
		["Tin Ore"] = "Zinnerz",
		["Tin Vein"] = "Zinnvorkommen",
		["Titanium Ore"] = "Titanertz",
		["Titanium Vein"] = "Titanader",
		["Truesilver Deposit"] = "Echtsilbervorkommen",
		["Truesilver Ore"] = "Echtsilbererz",
		["Elementium Ore"] = "Elementiumerz",
		["Elementium Vein"] = "Elementiumader",
		["Obsidium Deposit"] = "Obsidiumvorkommen",
		["Obsidium Ore"] = "Obsidiumerz",
		["Pyrite Deposit"] = "Pyritvorkommen",
		["Pyrite Ore"] = "Pyriterz",
		["Rich Elementium Vein"] = "Reiche Elementiumader",
		["Rich Obsidium Deposit"] = "Reiches Obsidiumvorkommen",
		["Rich Pyrite Deposit"] = "Reiches Pyritvorkommen",
	},
	frFR = {
		["Adamantite Deposit"] = "Gisement d'adamantite",
		["Adamantite Ore"] = "Minerai d'adamantite",
		["Cobalt Deposit"] = "Gisement de cobalt",
		["Cobalt Ore"] = "Minerai de cobalt",
		["Copper Ore"] = "Minerai de cuivre",
		["Copper Vein"] = "Filon de cuivre",
		["Dark Iron Deposit"] = "Gisement de sombrefer",
		["Dark Iron Ore"] = "Minerai de sombrefer",
		["Fel Iron Deposit"] = "Gisement de gangrefer",
		["Fel Iron Ore"] = "Minerai de gangrefer",
		["Gold Ore"] = "Minerai d'or",
		["Gold Vein"] = "Filon d'or",
		["Hakkari Thorium Vein"] = "Hakkari filon de thorium",
		["Iron Deposit"] = "Gisement de fer",
		["Iron Ore"] = "Minerai de fer",
		["Khorium Ore"] = "Minerai de khorium",
		["Khorium Vein"] = "Filon de khorium",
		["Mithril Deposit"] = "Gisement de mithril",
		["Mithril Ore"] = "Minerai de mithril",
		["Ooze Covered Gold Vein"] = "Filon d'or couvert de limon",
		["Ooze Covered Mithril Deposit"] = "Gisement de mithril couvert de vase",
		["Ooze Covered Rich Thorium Vein"] = "Filon de thorium riche couvert de limon",
		["Ooze Covered Silver Vein"] = "Filon d'argent couvert de limon",
		["Ooze Covered Truesilver Deposit"] = "Gisement de vrai-argent couvert de vase",
		["Ooze Covered Thorium Vein"] = "Filon de thorium couvert de limon",
		["Pure Saronite Deposit"] = "Gisement de saronite pure",
		["Rich Adamantite Deposit"] = "Gisement d'adamantite riche",
		["Rich Cobalt Deposit"] = "Gisement de cobalt riche",
		["Rich Saronite Deposit"] = "Gisement de saronite riche",
		["Rich Thorium Vein"] = "Filon de thorium riche",
		["Saronite Deposit"] = "Gisement de saronite",
		["Saronite Ore"] = "Minerai de saronite",
		["Silver Ore"] = "Minerai d'argent",
		["Silver Vein"] = "Filon d'argent",
		["Small Thorium Vein"] = "Petit filon de thorium",
		["Thorium Ore"] = "Minerai de thorium",
		["Tin Ore"] = "Minerai d'étain",
		["Tin Vein"] = "Filon d'étain",
		["Titanium Ore"] = "Minerai de titane",
		["Titanium Vein"] = "Veine de titane",
		["Truesilver Deposit"] = "Gisement de vrai-argent",
		["Truesilver Ore"] = "Minerai de vrai-argent",
		["Elementium Ore"] = "Minerai d'élémentium",
		["Elementium Vein"] = "Filon d'élémentium",
		["Obsidium Deposit"] = "Gisement d'obsidium",
		["Obsidium Ore"] = "Minerai d'obsidium",
		["Pyrite Deposit"] = "Gisement de pyrite",
		["Pyrite Ore"] = "Minerai de pyrite",
		["Rich Elementium Vein"] = "Riche filon d'élémentium",
		["Rich Obsidium Deposit"] = "Riche gisement d'obsidienne",
		["Rich Pyrite Deposit"] = "Riche gisement de pyrite",
	},
	esES = {
		["Adamantite Deposit"] = "Depósito de adamantita",
		["Adamantite Ore"] = "Mena de adamantita",
		["Cobalt Deposit"] = "Depósito de cobalto",
		["Cobalt Ore"] = "Mineral de cobalto",
		["Copper Ore"] = "Mineral de cobre",
		["Copper Vein"] = "Filón de cobre",
		["Dark Iron Deposit"] = "Depósito de hierro negro",
		["Dark Iron Ore"] = "Mineral de hierro negro",
		["Fel Iron Deposit"] = "Depósito de hierro vil",
		["Fel Iron Ore"] = "Mena de hierro vil",
		["Gold Ore"] = "Mineral de oro",
		["Gold Vein"] = "Filón de oro",
		["Hakkari Thorium Vein"] = "Filón Hakkari de torio",
		["Iron Deposit"] = "Depósito de hierro",
		["Iron Ore"] = "Mineral de hierro negro",
		["Khorium Ore"] = "Mena de korio",
		["Khorium Vein"] = "Filón de korio",
		["Mithril Deposit"] = "Depósito de mitril",
		["Mithril Ore"] = "Mineral de mitril",
		["Ooze Covered Gold Vein"] = "Filón de oro cubierto de moco",
		["Ooze Covered Mithril Deposit"] = "Filón de mitril cubierto de moco",
		["Ooze Covered Rich Thorium Vein"] = "Filón de torio enriquecido cubierto de moco",
		["Ooze Covered Silver Vein"] = "Filón de plata cubierto de moco",
		["Ooze Covered Truesilver Deposit"] = "Filón de veraplata cubierta de moco",
		["Ooze Covered Thorium Vein"] = "Filón de torio cubierto de moco",
		["Pure Saronite Deposit"] = "Deposito de Saronita Puro",
		["Rich Adamantite Deposit"] = "Depósito rico en adamantita",
		["Rich Cobalt Deposit"] = "Depósito de cobalto rico",
		["Rich Saronite Deposit"] = "Depósito de saronita rico",
		["Rich Thorium Vein"] = "Filón de torio enriquecido",
		["Saronite Deposit"] = "Depósito de saronita",
		["Saronite Ore"] = "Mineral de saronita",
		["Silver Ore"] = "Mineral de plata",
		["Silver Vein"] = "Filón de plata",
		["Small Thorium Vein"] = "Filón pequeño de torio",
		["Thorium Ore"] = "Mineral de torio",
		["Tin Ore"] = "Mineral de estaño",
		["Tin Vein"] = "Filón de estaño",
		["Titanium Ore"] = "Mineral de titanio",
		["Titanium Vein"] = "Filón de titanio",
		["Truesilver Deposit"] = "Depósito de veraplata",
		["Truesilver Ore"] = "Mineral de veraplata",
		["Elementium Ore"] = "Mineral de elementium",
		["Elementium Vein"] = "Filón de elementium",
		["Obsidium Deposit"] = "Depósito de obsidium",
		["Obsidium Ore"] = "Mineral de obsidium",
		["Pyrite Deposit"] = "Depósito de pirita",
		["Pyrite Ore"] = "Mineral de pirita",
		["Rich Elementium Vein"] = "Filón de elementium rico",
		["Rich Obsidium Deposit"] = "Depósito de obsidium rico",
		["Rich Pyrite Deposit"] = "Depósito de pirita rico",
	},
	esMX = {
		["Adamantite Deposit"] = "Depósito de adamantita",
		["Adamantite Ore"] = "Mena de adamantita",
		["Cobalt Deposit"] = "Depósito de cobalto",
		["Cobalt Ore"] = "Mineral de cobalto",
		["Copper Ore"] = "Mineral de cobre",
		["Copper Vein"] = "Filón de cobre",
		["Dark Iron Deposit"] = "Depósito de hierro negro",
		["Dark Iron Ore"] = "Mineral de hierro negro",
		["Fel Iron Deposit"] = "Depósito de hierro vil",
		["Fel Iron Ore"] = "Mena de hierro vil",
		["Gold Ore"] = "Mineral de oro",
		["Gold Vein"] = "Filón de oro",
		["Hakkari Thorium Vein"] = "Filón Hakkari de torio",
		["Iron Deposit"] = "Depósito de hierro",
		["Iron Ore"] = "Mineral de hierro negro",
		["Khorium Ore"] = "Mena de korio",
		["Khorium Vein"] = "Filón de korio",
		["Mithril Deposit"] = "Depósito de mitril",
		["Mithril Ore"] = "Mineral de mitril",
		["Ooze Covered Gold Vein"] = "Filón de oro cubierto de moco",
		["Ooze Covered Mithril Deposit"] = "Filón de mitril cubierto de moco",
		["Ooze Covered Rich Thorium Vein"] = "Filón de torio enriquecido cubierto de moco",
		["Ooze Covered Silver Vein"] = "Filón de plata cubierto de moco",
		["Ooze Covered Truesilver Deposit"] = "Filón de veraplata cubierta de moco",
		["Ooze Covered Thorium Vein"] = "Filón de torio cubierto de moco",
		["Pure Saronite Deposit"] = "Deposito de Saronita Puro",
		["Rich Adamantite Deposit"] = "Depósito rico en adamantita",
		["Rich Cobalt Deposit"] = "Depósito de cobalto rico",
		["Rich Saronite Deposit"] = "Depósito de saronita rico",
		["Rich Thorium Vein"] = "Filón de torio enriquecido",
		["Saronite Deposit"] = "Depósito de saronita",
		["Saronite Ore"] = "Mineral de saronita",
		["Silver Ore"] = "Mineral de plata",
		["Silver Vein"] = "Filón de plata",
		["Small Thorium Vein"] = "Filón pequeño de torio",
		["Thorium Ore"] = "Mineral de torio",
		["Tin Ore"] = "Mineral de estaño",
		["Tin Vein"] = "Filón de estaño",
		["Titanium Ore"] = "Mineral de titanio",
		["Titanium Vein"] = "Filón de titanio",
		["Truesilver Deposit"] = "Depósito de veraplata",
		["Truesilver Ore"] = "Mineral de veraplata",
		["Elementium Ore"] = "Mineral de elementium",
		["Elementium Vein"] = "Filón de elementium",
		["Obsidium Deposit"] = "Depósito de obsidium",
		["Obsidium Ore"] = "Mineral de obsidium",
		["Pyrite Deposit"] = "Depósito de pirita",
		["Pyrite Ore"] = "Mineral de pirita",
		["Rich Elementium Vein"] = "Filón de elementium rico",
		["Rich Obsidium Deposit"] = "Depósito de obsidium rico",
		["Rich Pyrite Deposit"] = "Depósito de pirita rico",
	},
	itIT = {
		["Adamantite Deposit"] = "Deposito di Adamantite",
		["Adamantite Ore"] = "Minerale di Adamantite",
		["Cobalt Deposit"] = "Deposito di Cobalto",
		["Cobalt Ore"] = "Minerale di Cobalto",
		["Copper Ore"] = "Minerale di Rame",
		["Copper Vein"] = "Vena di Rame",
		["Dark Iron Deposit"] = "Deposito di Ferroscuro",
		["Dark Iron Ore"] = "Minerale di Ferroscuro",
		["Fel Iron Deposit"] = "Deposito di Vilferro",
		["Fel Iron Ore"] = "Minerale di Vilferro",
		["Gold Ore"] = "Minerale d'Oro",
		["Gold Vein"] = "Vena d'Oro",
		["Hakkari Thorium Vein"] = "Vena Hakkari di Torio",
		["Iron Deposit"] = "Deposito di Ferro",
		["Iron Ore"] = "Minerale di Ferro",
		["Khorium Ore"] = "Minerale di Korio",
		["Khorium Vein"] = "Vena di Korio",
		["Mithril Deposit"] = "Deposito di Mithril",
		["Mithril Ore"] = "Minerale di Mithril",
		["Ooze Covered Gold Vein"] = "Vena d'Oro Coperta di Melma",
		["Ooze Covered Mithril Deposit"] = "Vena di Mithril Coperta di Melma",
		["Ooze Covered Rich Thorium Vein"] = "Vena Ricca di Torio Coperta di Melma",
		["Ooze Covered Silver Vein"] = "Vena d'Argento Coperta di Melma",
		["Ooze Covered Truesilver Deposit"] = "Deposito di Verargento Coperto di Melma",
		["Ooze Covered Thorium Vein"] = "Vena di Torio Coperta di Melma",
		["Pure Saronite Deposit"] = "Deposito di Minerale di Saronite pura",
		["Rich Adamantite Deposit"] = "Deposito Ricco di Adamantite",
		["Rich Cobalt Deposit"] = "Deposito Ricco di Cobalto",
		["Rich Saronite Deposit"] = "Deposito Ricco di Saronite",
		["Rich Thorium Vein"] = "Vena Ricca di Torio",
		["Saronite Deposit"] = "Deposito di Saronite",	
		["Saronite Ore"] = "Minerale di Saronite",
		["Silver Ore"] = "Minerale d'Argento",
		["Silver Vein"] = "Vena d'Argento",
		["Small Thorium Vein"] = "Vena Piccola di Torio",
		["Thorium Ore"] = "Minerale di Torio",
		["Tin Ore"] = "Minerale di Stagno",
		["Tin Vein"] = "Vena di Stagno",
		["Titanium Ore"] = "Minerale di Titanio",
		["Titanium Vein"] = "Vena di Titanio",
		["Truesilver Deposit"] = "Deposito di Verargento",
		["Truesilver Ore"] = "Minerale di Verargento",
		["Elementium Ore"] = "Minerale d'Elementio",
		["Elementium Vein"] = "Vena d'Elementio",
		["Obsidium Deposit"] = "Deposito d'Obsidio",
		["Obsidium Ore"] = "Minerale d'Obsido",
		["Pyrite Deposit"] = "Deposito di Pirite",
		["Pyrite Ore"] = "Minerale di Pirite",
		["Rich Elementium Vein"] = "Vena Ricca di Elementio",
		["Rich Obsidium Deposit"] = "Deposito Ricco d'Obsidio",
		["Rich Pyrite Deposit"] = "Deposito Ricco di Pirite"
	},
	ptBR = {
		["Adamantite Deposit"] = "Depósito de Adamantita",
		["Adamantite Ore"] = "Minério de Adamantita",
		["Cobalt Deposit"] = "Depósito de Cobalto",
		["Cobalt Ore"] = "Minério de Cobalto",
		["Copper Ore"] = "Minério de Cobre",
		["Copper Vein"] = "Veio de Cobre",
		["Dark Iron Deposit"] = "Depósito de Ferro Negro",
		["Dark Iron Ore"] = "Minério de Ferro Negro",
		["Fel Iron Deposit"] = "Depósito de Ferrovil",
		["Fel Iron Ore"] = "Minério de Ferrovil",
		["Gold Ore"] = "Minério de Ouro",
		["Gold Vein"] = "Veio de Ouro",
		["Hakkari Thorium Vein"] = "Veio de Tório Hakkari",
		["Iron Deposit"] = "Depósito de Ferro",
		["Iron Ore"] = "Minério de Ferro",
		["Khorium Ore"] = "Minério de Kório",
		["Khorium Vein"] = "Veio de Kório",
		["Mithril Deposit"] = "Depósito de Mithril",
		["Mithril Ore"] = "Minério de Mithril",
		["Ooze Covered Gold Vein"] = "Veio de Ouro Coberto de Gosma",
		["Ooze Covered Mithril Deposit"] = "Depósito de Mithril Coberto de Gosma",
		["Ooze Covered Rich Thorium Vein"] = "Veio de Tório Abundante Coberto de Gosma",
		["Ooze Covered Silver Vein"] = "Veio de Prata Coberto de Gosma",
		["Ooze Covered Truesilver Deposit"] = "Depósito de Veraprata Coberto de Gosma",
		["Ooze Covered Thorium Vein"] = "Veio de Tório Coberto de Gosma",
		["Pure Saronite Deposit"] = "Depósito de Saronita Pura",
		["Rich Adamantite Deposit"] = "Depósito de Adamantita Abundante",
		["Rich Cobalt Deposit"] = "Depósito de Cobalto Abundante",
		["Rich Saronite Deposit"] = "Depósito de Saronita Abundante",
		["Rich Thorium Vein"] = "Veio de Tório Abundante",
		["Saronite Deposit"] = "Depósito de Saronita",
		["Saronite Ore"] = "Minério de Saronita",
		["Silver Ore"] = "Minério de Prata",
		["Silver Vein"] = "Veio de Prata",
		["Small Thorium Vein"] = "Veio de Tório Pequeno",
		["Thorium Ore"] = "Minério de Tório",
		["Tin Ore"] = "Minério de Estanho",
		["Tin Vein"] = "Veio de Estanho",
		["Titanium Ore"] = "Minério de Titânio",
		["Titanium Vein"] = "Veio de Titânio",
		["Truesilver Deposit"] = "Depósito de Veraprata",
		["Truesilver Ore"] = "Minério de Veraprata",
		["Elementium Ore"] = "Minério de Elemêntio",
		["Elementium Vein"] = "Veio de Elemêntio",
		["Obsidium Deposit"] = "Depósito de Obsídio",
		["Obsidium Ore"] = "Minério de Obsídio",
		["Pyrite Deposit"] = "Depósito de Pirita",
		["Pyrite Ore"] = "Minério de Pirita",
		["Rich Elementium Vein"] = "Veio de Elemêntio Abundante",
		["Rich Obsidium Deposit"] = "Depósito de Obsídio Abundante",
		["Rich Pyrite Deposit"] = "Depósito de Pirita Abundante",
	},
	zhTW = {
		["Adamantite Deposit"] = "堅鋼礦床",
		["Adamantite Ore"] = "堅鋼礦石",
		["Cobalt Deposit"] = "鈷藍礦床",
		["Cobalt Ore"] = "鈷藍礦石",
		["Copper Ore"] = "銅礦",
		["Copper Vein"] = "銅礦脈",
		["Dark Iron Deposit"] = "黑鐵礦床",
		["Dark Iron Ore"] = "黑鐵礦",
		["Fel Iron Deposit"] = "魔鐵礦床",
		["Fel Iron Ore"] = "魔鐵礦石",
		["Gold Ore"] = "金礦",	
		["Gold Vein"] = "金礦脈",
		["Hakkari Thorium Vein"] = "瑟銀礦脈",
		["Iron Deposit"] = "鐵礦床",	
		["Iron Ore"] = "鐵礦",	
		["Khorium Ore"] = "克銀礦石",	
		["Khorium Vein"] = "克銀礦脈",
		["Mithril Deposit"] = "秘銀礦床",
		["Mithril Ore"] = "秘銀礦石",	
		["Ooze Covered Gold Vein"] = "軟泥覆蓋的金礦脈",
		["Ooze Covered Mithril Deposit"] = "軟泥覆蓋的秘銀礦床",
		["Ooze Covered Rich Thorium Vein"] = "軟泥覆蓋的富瑟銀礦脈",
		["Ooze Covered Silver Vein"] = "軟泥覆蓋的銀礦脈",
		["Ooze Covered Truesilver Deposit"] = "軟泥覆蓋的真銀礦床",
		["Ooze Covered Thorium Vein"] = "軟泥覆蓋的瑟銀礦脈",
		["Pure Saronite Deposit"] = "純淨薩鋼礦床",
		["Rich Adamantite Deposit"] = "豐沃的堅鋼礦床",
		["Rich Cobalt Deposit"] = "豐沃的鈷藍礦床",
		["Rich Saronite Deposit"] = "豐沃的薩鋼礦床",
		["Rich Thorium Vein"] = "富瑟銀礦脈",
		["Saronite Deposit"] = "薩鋼礦床",
		["Saronite Ore"] = "薩鋼礦石",
		["Silver Ore"] = "銀礦石",
		["Silver Vein"] = "銀礦脈",
		["Small Thorium Vein"] = "瑟銀礦脈",
		["Thorium Ore"] = "釷礦石",
		["Tin Ore"] = "錫礦",
		["Tin Vein"] = "錫礦脈",
		["Titanium Ore"] = "泰坦鋼礦石",
		["Titanium Vein"] = "泰坦鋼礦脈",
		["Truesilver Deposit"] = "真銀礦床",
		["Truesilver Ore"] = "真銀礦石",
		["Elementium Ore"] = "源質礦石",
		["Elementium Vein"] = "源質礦脈",
		["Obsidium Deposit"] = "黑曜石塊",
		["Obsidium Ore"] = "黑曜石礦石",
		["Pyrite Deposit"] = "黃鐵礦床",
		["Pyrite Ore"] = "黃鐵礦礦石",
		["Rich Elementium Vein"] = "豐沃的源質礦脈",
		["Rich Obsidium Deposit"] = "豐沃的黑曜石塊",
		["Rich Pyrite Deposit"] = "豐沃的黃鐵礦床",
	},
	zhCN = {
		["Adamantite Deposit"] = "精金矿脉",
		["Adamantite Ore"] = "精金矿石",
		["Cobalt Deposit"] = "钴矿脉",
		["Cobalt Ore"] = "钴矿",
		["Copper Ore"] = "铜矿",
		["Copper Vein"] = "铜矿",
		["Dark Iron Deposit"] = "黑铁矿脉",
		["Dark Iron Ore"] = "黑铁矿",
		["Fel Iron Deposit"] = "魔铁矿脉",
		["Fel Iron Ore"] = "魔铁矿石",
		["Gold Ore"] = "金矿",
		["Gold Vein"] = "金矿石",
		["Hakkari Thorium Vein"] = "瑟银矿脉",
		["Iron Deposit"] = "铁矿石",
		["Iron Ore"] = "铁矿",
		["Khorium Ore"] = "氪金矿石",
		["Khorium Vein"] = "氪金矿脉",
		["Mithril Deposit"] = "秘银矿脉",
		["Mithril Ore"] = "秘银矿",
		["Ooze Covered Gold Vein"] = "软泥覆盖的金矿脉",
		["Ooze Covered Mithril Deposit"] = "软泥覆盖的秘银矿脉",
		["Ooze Covered Rich Thorium Vein"] = "软泥覆盖的富瑟银矿脉",
		["Ooze Covered Silver Vein"] = "软泥覆盖的银矿脉",
		["Ooze Covered Truesilver Deposit"] = "软泥覆盖的真银矿脉",
		["Ooze Covered Thorium Vein"] = "软泥覆盖的瑟银矿脉",
		["Pure Saronite Deposit"] = "纯净的萨隆邪铁矿脉",
		["Rich Adamantite Deposit"] = "富精金矿脉",
		["Rich Cobalt Deposit"] = "富钴矿脉",
		["Rich Saronite Deposit"] = "富萨隆邪铁矿脉",
		["Rich Thorium Vein"] = "富瑟银矿",
		["Saronite Deposit"] = "萨隆邪铁矿脉",
		["Saronite Ore"] = "萨龙石",
		["Silver Ore"] = "银矿",
		["Silver Vein"] = "银矿",
		["Small Thorium Vein"] = "瑟银矿脉",
		["Thorium Ore"] = "钍矿",
		["Tin Ore"] = "锡矿",
		["Tin Vein"] = "锡矿",
		["Titanium Ore"] = "钛矿石",
		["Titanium Vein"] = "锡矿",
		["Truesilver Deposit"] = "真银矿石",
		["Truesilver Ore"] = "真银矿",
		["Elementium Ore"] = "元素矿石",
		["Elementium Vein"] = "源质矿",
		["Obsidium Deposit"] = "黑曜石碎块",
		["Obsidium Ore"] = "黑曜石矿石",
		["Pyrite Deposit"] = "燃铁矿脉",
		["Pyrite Ore"] = "黄铁矿矿石",
		["Rich Elementium Vein"] = "富源质矿",
		["Rich Obsidium Deposit"] = "巨型黑曜石石板",
		["Rich Pyrite Deposit"] = "富燃铁矿脉",
	},
}

local function LMining(tag)
	if miningTranslations[GAME_LOCALE] then
		return miningTranslations[GAME_LOCALE][tag] or tag
	else
		return tag
	end
end

--------------------------------------------------------------------------------------------------------
--                                            MINING DATA                                             --
--------------------------------------------------------------------------------------------------------

-- Some Classic and TBC node types are represented by multiple object IDs within a single zone.
-- This table maps these IDs to the most common one
-- 
-- (source: WowHead)
local miningNodeIDMapping = {
	[3763] = 1731,    -- Copper 
	[103713] = 1731,
	[181248] = 1731,
	[2054] = 1732,    -- Tin 
	[3764] = 1732,
	[181249] = 1732,
	[103711] = 1732,
	[105569] = 1733,  -- Silver
	[181109] = 1734,  -- Gold
	[103710] = 1735,  -- Iron
	[103712] = 1735,
	[150079] = 2040,  -- Mithril
	[176645] = 2040,
	[150081] = 2047,  -- Truesilver
	[181108] = 2047,
	[150082] = 324,   -- Small Thorium
	[176644] = 175404,  -- Rich Thorium
}


local miningNodes = {
	[1731] = {
		nodeName = LMining("Copper Vein"),
		nodeObjectID = 1731,
		oreName = LMining("Copper Ore"),
		oreItemID = 2770,
		minLevel = 1,
		zones = {
			[1440] = true,		-- Ashenvale
			[1447] = true,		-- Azshara
			[1943] = true,		-- Azuremyst Isle
			[1950] = true,		-- Bloodmyst Isle
			[1439] = true,		-- Darkshore
			[1443] = true,		-- Desolace
			[1426] = true,		-- Dun Morogh
			[1411] = true,		-- Durotar
			[1431] = true,		-- Duskwood
			[1429] = true,		-- Elwynn Forest
			[1941] = true,		-- Eversong Woods
			[1942] = true,		-- Ghostlands
			[179] = true,		-- Gilneas
			[1424] = true,		-- Hillsbrad Foothills
			[1432] = true,		-- Loch Modan
			[1412] = true,		-- Mulgore
			[1433] = true,		-- Redridge Mountains
			[1421] = true,		-- Silverpine Forest
			[199] = true,		-- Southern Barrens
			[1442] = true,		-- Stonetalon Mountains
			[1413] = true,		-- The Barrens
			[291] = true,		-- The Deadmines
			[174] = true,		-- The Lost Isles
			[1441] = true,		-- Thousand Needles
			[1420] = true,		-- Tirisfal Glades
			[279] = true,		-- Wailing Caverns
			[1436] = true,		-- Westfall
			[1437] = true,		-- Wetlands
		},
	},
	[2055] = {
		nodeName = LMining("Copper Vein"),
		nodeObjectID = 2055,
		oreName = LMining("Copper Ore"),
		oreItemID = 2770,
		minLevel = 1,
		zones = {
			[1433] = true,		-- Redridge Mountains
		},
	},
	[1732] = {
		nodeName = LMining("Tin Vein"),
		nodeObjectID = 1732,
		oreName = LMining("Tin Ore"),
		oreItemID = 2771,
		minLevel = 50,
		zones = {
			[1417] = true,		-- Arathi Highlands
			[1440] = true,		-- Ashenvale
			[1447] = true,		-- Azshara
			[221] = true,		-- Blackfathom Deeps
			[1950] = true,		-- Bloodmyst Isle
			[1439] = true,		-- Darkshore
			[1443] = true,		-- Desolace
			[1431] = true,		-- Duskwood
			[1445] = true,		-- Dustwallow Marsh
			[1942] = true,		-- Ghostlands
			[1424] = true,		-- Hillsbrad Foothills
			[1432] = true,		-- Loch Modan
			[1434] = true,		-- Northern Stranglethorn
			[1433] = true,		-- Redridge Mountains
			[1421] = true,		-- Silverpine Forest
			[1442] = true,		-- Stonetalon Mountains
			[224] = true,		-- Stranglethorn Vale
			[1413] = true,		-- The Barrens
			[291] = true,		-- The Deadmines
			[1425] = true,		-- The Hinterlands
			[1441] = true,		-- Thousand Needles
			[279] = true,		-- Wailing Caverns
			[1436] = true,		-- Westfall
			[1437] = true,		-- Wetlands
		},
	},
	[1733] = {
		nodeName = LMining("Silver Vein"),
		nodeObjectID = 1733,
		oreName = LMining("Silver Ore"),
		oreItemID = 2775,
		minLevel = 65,
		zones = {
			[1417] = true,		-- Arathi Highlands
			[1440] = true,		-- Ashenvale
			[1418] = true,		-- Badlands
			[221] = true,		-- Blackfathom Deeps
			[1950] = true,		-- Bloodmyst Isle
			[1439] = true,		-- Darkshore
			[1443] = true,		-- Desolace
			[1431] = true,		-- Duskwood
			[1445] = true,		-- Dustwallow Marsh
			[1444] = true,		-- Feralas
			[1942] = true,		-- Ghostlands
			[1424] = true,		-- Hillsbrad Foothills
			[1432] = true,		-- Loch Modan
			[1434] = true,		-- Northern Stranglethorn
			[301] = true,		-- Razorfen Kraul
			[1433] = true,		-- Redridge Mountains
			[1427] = true,		-- Searing Gorge
			[1421] = true,		-- Silverpine Forest
			[199] = true,		-- Southern Barrens
			[1442] = true,		-- Stonetalon Mountains
			[224] = true,		-- Stranglethorn Vale
			[1435] = true,		-- Swamp of Sorrows
			[1446] = true,		-- Tanaris
			[1413] = true,		-- The Barrens
			[210] = true,		-- The Cape of Stranglethorn
			[291] = true,		-- The Deadmines
			[1425] = true,		-- The Hinterlands
			[1441] = true,		-- Thousand Needles
			[230] = true,		-- Uldaman
			[279] = true,		-- Wailing Caverns
			[1436] = true,		-- Westfall
			[1437] = true,		-- Wetlands
		},
	},
	[73940] = {
		nodeName = LMining("Ooze Covered Silver Vein"),
		nodeObjectID = 73940,
		oreName = LMining("Silver Ore"),
		oreItemID = 2775,
		minLevel = 65,
		zones = {
			[1441] = true,		-- Thousand Needles
		},
	},
	[1735] = {
		nodeName = LMining("Iron Deposit"),
		nodeObjectID = 1735,
		oreName = LMining("Iron Ore"),
		oreItemID = 2772,
		minLevel = 100,
		zones = {
			[1417] = true,		-- Arathi Highlands
			[1440] = true,		-- Ashenvale
			[1418] = true,		-- Badlands
			[1443] = true,		-- Desolace
			[1431] = true,		-- Duskwood
			[1445] = true,		-- Dustwallow Marsh
			[1423] = true,		-- Eastern Plaguelands
			[1444] = true,		-- Feralas
			[1424] = true,		-- Hillsbrad Foothills
			[1434] = true,		-- Northern Stranglethorn
			[1427] = true,		-- Searing Gorge
			[199] = true,		-- Southern Barrens
			[1442] = true,		-- Stonetalon Mountains
			[224] = true,		-- Stranglethorn Vale
			[1435] = true,		-- Swamp of Sorrows
			[1446] = true,		-- Tanaris
			[210] = true,		-- The Cape of Stranglethorn
			[1425] = true,		-- The Hinterlands
			[1441] = true,		-- Thousand Needles
			[1422] = true,		-- Western Plaguelands
			[1437] = true,		-- Wetlands
		},
	},
	[1734] = {
		nodeName = LMining("Gold Vein"),
		nodeObjectID = 1734,
		oreName = LMining("Gold Ore"),
		oreItemID = 2776,
		minLevel = 115,
		zones = {
			[1417] = true,		-- Arathi Highlands
			[1440] = true,		-- Ashenvale
			[1447] = true,		-- Azshara
			[1418] = true,		-- Badlands
			[1419] = true,		-- Blasted Lands
			[1428] = true,		-- Burning Steppes
			[1443] = true,		-- Desolace
			[1431] = true,		-- Duskwood
			[1445] = true,		-- Dustwallow Marsh
			[1423] = true,		-- Eastern Plaguelands
			[1448] = true,		-- Felwood
			[1444] = true,		-- Feralas
			[1424] = true,		-- Hillsbrad Foothills
			[280] = true,		-- Maraudon
			[1434] = true,		-- Northern Stranglethorn
			[301] = true,		-- Razorfen Kraul
			[1427] = true,		-- Searing Gorge
			[1451] = true,		-- Silithus
			[199] = true,		-- Southern Barrens
			[1442] = true,		-- Stonetalon Mountains
			[224] = true,		-- Stranglethorn Vale
			[1435] = true,		-- Swamp of Sorrows
			[1446] = true,		-- Tanaris
			[210] = true,		-- The Cape of Stranglethorn
			[1425] = true,		-- The Hinterlands
			[1441] = true,		-- Thousand Needles
			[230] = true,		-- Uldaman
			[1449] = true,		-- Un'Goro Crater
			[1422] = true,		-- Western Plaguelands
			[1437] = true,		-- Wetlands
			[1452] = true,		-- Winterspring
		},
	},
	[150080] = {
		nodeName = LMining("Gold Vein"),
		nodeObjectID = 150080,
		oreName = LMining("Gold Ore"),
		oreItemID = 2776,
		minLevel = 115,
		zones = {
			[1419] = true,		-- Blasted Lands
		},
	},
	[73941] = {
		nodeName = LMining("Ooze Covered Gold Vein"),
		nodeObjectID = 73941,
		oreName = LMining("Gold Ore"),
		oreItemID = 2776,
		minLevel = 115,
		zones = {
			[1444] = true,		-- Feralas
			[1441] = true,		-- Thousand Needles
		},
	},
	[2040] = {
		nodeName = LMining("Mithril Deposit"),
		nodeObjectID = 2040,
		oreName = LMining("Mithril Ore"),
		oreItemID = 3858,
		minLevel = 150,
		zones = {
			[1459] = true,		-- Alterac Valley
			[1417] = true,		-- Arathi Highlands
			[1418] = true,		-- Badlands
			[1419] = true,		-- Blasted Lands
			[1428] = true,		-- Burning Steppes
			[1443] = true,		-- Desolace
			[1445] = true,		-- Dustwallow Marsh
			[1423] = true,		-- Eastern Plaguelands
			[1448] = true,		-- Felwood
			[1444] = true,		-- Feralas
			[1424] = true,		-- Hillsbrad Foothills
			[280] = true,		-- Maraudon
			[1434] = true,		-- Northern Stranglethorn
			[1427] = true,		-- Searing Gorge
			[1451] = true,		-- Silithus
			[1442] = true,		-- Stonetalon Mountains
			[224] = true,		-- Stranglethorn Vale
			[1435] = true,		-- Swamp of Sorrows
			[1446] = true,		-- Tanaris
			[1425] = true,		-- The Hinterlands
			[1441] = true,		-- Thousand Needles
			[230] = true,		-- Uldaman
			[1449] = true,		-- Un'Goro Crater
			[1422] = true,		-- Western Plaguelands
			[1452] = true,		-- Winterspring
		},
	},
	[123310] = {
		nodeName = LMining("Ooze Covered Mithril Deposit"),
		nodeObjectID = 123310,
		oreName = LMining("Mithril Ore"),
		oreItemID = 3858,
		minLevel = 150,
		zones = {
			[1444] = true,		-- Feralas
			[1441] = true,		-- Thousand Needles
		},
	},
	[2047] = {
		nodeName = LMining("Truesilver Deposit"),
		nodeObjectID = 2047,
		oreName = LMining("Truesilver Ore"),
		oreItemID = 7911,
		minLevel = 165,
		zones = {
			[1417] = true,		-- Arathi Highlands
			[1447] = true,		-- Azshara
			[1418] = true,		-- Badlands
			[1419] = true,		-- Blasted Lands
			[1428] = true,		-- Burning Steppes
			[1443] = true,		-- Desolace
			[1445] = true,		-- Dustwallow Marsh
			[1423] = true,		-- Eastern Plaguelands
			[1448] = true,		-- Felwood
			[1444] = true,		-- Feralas
			[1424] = true,		-- Hillsbrad Foothills
			[280] = true,		-- Maraudon
			[1434] = true,		-- Northern Stranglethorn
			[1427] = true,		-- Searing Gorge
			[1451] = true,		-- Silithus
			[1442] = true,		-- Stonetalon Mountains
			[224] = true,		-- Stranglethorn Vale
			[1435] = true,		-- Swamp of Sorrows
			[1446] = true,		-- Tanaris
			[1425] = true,		-- The Hinterlands
			[1441] = true,		-- Thousand Needles
			[230] = true,		-- Uldaman
			[1449] = true,		-- Un'Goro Crater
			[1422] = true,		-- Western Plaguelands
			[1452] = true,		-- Winterspring
		},
	},
	[123309] = {
		nodeName = LMining("Ooze Covered Truesilver Deposit"),
		nodeObjectID = 123309,
		oreName = LMining("Truesilver Ore"),
		oreItemID = 7911,
		minLevel = 165,
		zones = {
			[1444] = true,		-- Feralas
			[1451] = true,		-- Silithus
			[1449] = true,		-- Un'Goro Crater
		},
	},
	[165658] = {
		nodeName = LMining("Dark Iron Deposit"),
		nodeObjectID = 165658,
		oreName = LMining("Dark Iron Ore"),
		oreItemID = 11370,
		minLevel = 175,
		zones = {
			[1459] = true,		-- Alterac Valley
			[1461] = true,		-- Arathi Basin
			[242] = true,		-- Blackrock Depths
			[1428] = true,		-- Burning Steppes
			[232] = true,		-- Molten Core
			[1427] = true,		-- Searing Gorge
		},
	},
	[324] = {
		nodeName = LMining("Small Thorium Vein"),
		nodeObjectID = 324,
		oreName = LMining("Thorium Ore"),
		oreItemID = 10620,
		minLevel = 200,
		zones = {
			[1419] = true,		-- Blasted Lands
			[1428] = true,		-- Burning Steppes
			[1423] = true,		-- Eastern Plaguelands
			[1444] = true,		-- Feralas
			[1427] = true,		-- Searing Gorge
			[1451] = true,		-- Silithus
			[1435] = true,		-- Swamp of Sorrows
			[1446] = true,		-- Tanaris
			[1425] = true,		-- The Hinterlands
			[1449] = true,		-- Un'Goro Crater
			[1422] = true,		-- Western Plaguelands
			[1452] = true,		-- Winterspring
		},
	},
	[176643] = {
		nodeName = LMining("Small Thorium Vein"),
		nodeObjectID = 176643,
		oreName = LMining("Thorium Ore"),
		oreItemID = 10620,
		minLevel = 200,
		zones = {
			[1448] = true,		-- Felwood
		},
	},
	[123848] = {
		nodeName = LMining("Ooze Covered Thorium Vein"),
		nodeObjectID = 123848,
		oreName = LMining("Thorium Ore"),
		oreItemID = 10620,
		minLevel = 200,
		zones = {
			[1444] = true,		-- Feralas
			[1449] = true,		-- Un'Goro Crater
		},
	},
	[175404] = {
		nodeName = LMining("Rich Thorium Vein"),
		nodeObjectID = 175404,
		oreName = LMining("Thorium Ore"),
		oreItemID = 10620,
		minLevel = 215,
		zones = {
			[1459] = true,		-- Alterac Valley
			[1419] = true,		-- Blasted Lands
			[1428] = true,		-- Burning Steppes
			[234] = true,		-- Dire Maul
			[1423] = true,		-- Eastern Plaguelands
			[1451] = true,		-- Silithus
			[1435] = true,		-- Swamp of Sorrows
			[1449] = true,		-- Un'Goro Crater
			[1422] = true,		-- Western Plaguelands
			[1452] = true,		-- Winterspring
		},
	},
	[177388] = {
		nodeName = LMining("Ooze Covered Rich Thorium Vein"),
		nodeObjectID = 177388,
		oreName = LMining("Thorium Ore"),
		oreItemID = 10620,
		minLevel = 215,
		zones = {
			[1451] = true,		-- Silithus
		},
	},
	[180215] = {
		nodeName = LMining("Hakkari Thorium Vein"),
		nodeObjectID = 180215,
		oreName = LMining("Thorium Ore"),
		oreItemID = 10620,
		minLevel = 215,
		zones = {
			[233] = true,		-- Zul'Gurub
		},
	},
	[181555] = {
		nodeName = LMining("Fel Iron Deposit"),
		nodeObjectID = 181555,
		oreName = LMining("Fel Iron Ore"),
		oreItemID = 23424,
		minLevel = 275,
		zones = {
			[1949] = true,		-- Blade's Edge Mountains
			[1944] = true,		-- Hellfire Peninsula
			[1951] = true,		-- Nagrand
			[1953] = true,		-- Netherstorm
			[1948] = true,		-- Shadowmoon Valley
			[1952] = true,		-- Terokkar Forest
			[263] = true,		-- The Steamvault
			[1946] = true,		-- Zangarmarsh
		},
	},
	[181556] = {
		nodeName = LMining("Adamantite Deposit"),
		nodeObjectID = 181556,
		oreName = LMining("Adamantite Ore"),
		oreItemID = 23425,
		minLevel = 325,
		zones = {
			[256] = true,		-- Auchenai Crypts
			[1949] = true,		-- Blade's Edge Mountains
			[1957] = true,		-- Isle of Quel'Danas
			[272] = true,		-- Mana-Tombs
			[1951] = true,		-- Nagrand
			[1953] = true,		-- Netherstorm
			[258] = true,		-- Sethekk Halls
			[260] = true,		-- Shadow Labyrinth
			[1948] = true,		-- Shadowmoon Valley
			[1952] = true,		-- Terokkar Forest
			[265] = true,		-- The Slave Pens
			[263] = true,		-- The Steamvault
			[262] = true,		-- The Underbog
			[1946] = true,		-- Zangarmarsh
		},
	},
	[181569] = {
		nodeName = LMining("Rich Adamantite Deposit"),
		nodeObjectID = 181569,
		oreName = LMining("Adamantite Ore"),
		oreItemID = 23425,
		minLevel = 350,
		zones = {
			[256] = true,		-- Auchenai Crypts
			[1949] = true,		-- Blade's Edge Mountains
			[1957] = true,		-- Isle of Quel'Danas
			[272] = true,		-- Mana-Tombs
			[1953] = true,		-- Netherstorm
			[258] = true,		-- Sethekk Halls
			[260] = true,		-- Shadow Labyrinth
			[1948] = true,		-- Shadowmoon Valley
			[1952] = true,		-- Terokkar Forest
			[265] = true,		-- The Slave Pens
			[262] = true,		-- The Underbog
		},
	},
	[189978] = {
		nodeName = LMining("Cobalt Deposit"),
		nodeObjectID = 189978,
		oreName = LMining("Cobalt Ore"),
		oreItemID = 36909,
		minLevel = 350,
		zones = {
			[114] = true,		-- Borean Tundra
			[115] = true,		-- Dragonblight
			[116] = true,		-- Grizzly Hills
			[117] = true,		-- Howling Fjord
			[120] = true,		-- The Storm Peaks
			[133] = true,		-- Utgarde Keep
			[121] = true,		-- Zul'Drak
		},
	},
	[181570] = {
		nodeName = LMining("Rich Adamantite Deposit"),
		nodeObjectID = 181570,
		oreName = LMining("Adamantite Ore"),
		oreItemID = 23425,
		minLevel = 350,
		zones = {
			[1951] = true,		-- Nagrand
		},
	},
	[181557] = {
		nodeName = LMining("Khorium Vein"),
		nodeObjectID = 181557,
		oreName = LMining("Khorium Ore"),
		oreItemID = 23426,
		minLevel = 375,
		zones = {
			[256] = true,		-- Auchenai Crypts
			[1949] = true,		-- Blade's Edge Mountains
			[1944] = true,		-- Hellfire Peninsula
			[1957] = true,		-- Isle of Quel'Danas
			[272] = true,		-- Mana-Tombs
			[1951] = true,		-- Nagrand
			[1953] = true,		-- Netherstorm
			[258] = true,		-- Sethekk Halls
			[260] = true,		-- Shadow Labyrinth
			[1948] = true,		-- Shadowmoon Valley
			[1952] = true,		-- Terokkar Forest
			[265] = true,		-- The Slave Pens
			[263] = true,		-- The Steamvault
			[262] = true,		-- The Underbog
			[1946] = true,		-- Zangarmarsh
		},
	},
	[189979] = {
		nodeName = LMining("Rich Cobalt Deposit"),
		nodeObjectID = 189979,
		oreName = LMining("Cobalt Ore"),
		oreItemID = 36909,
		minLevel = 375,
		zones = {
			[114] = true,		-- Borean Tundra
			[115] = true,		-- Dragonblight
			[116] = true,		-- Grizzly Hills
			[117] = true,		-- Howling Fjord
			[120] = true,		-- The Storm Peaks
			[133] = true,		-- Utgarde Keep
			[121] = true,		-- Zul'Drak
		},
	},
	[189980] = {
		nodeName = LMining("Saronite Deposit"),
		nodeObjectID = 189980,
		oreName = LMining("Saronite Ore"),
		oreItemID = 36912,
		minLevel = 400,
		zones = {
			[127] = true,		-- Crystalsong Forest
			[115] = true,		-- Dragonblight
			[140] = true,		-- Halls of Stone
			[118] = true,		-- Icecrown
			[119] = true,		-- Sholazar Basin
			[120] = true,		-- The Storm Peaks
			[123] = true,		-- Wintergrasp
			[121] = true,		-- Zul'Drak
		},
	},
	[202736] = {
		nodeName = LMining("Obsidium Deposit"),
		nodeObjectID = 202736,
		oreName = LMining("Obsidium Ore"),
		oreItemID = 53038,
		minLevel = 425,
		zones = {
			[204] = true,		-- Abyssal Depths
			[207] = true,		-- Deepholm
			[201] = true,		-- Kelp'thar Forest
			[198] = true,		-- Mount Hyjal
			[205] = true,		-- Shimmering Expanse
		},
	},
	[189981] = {
		nodeName = LMining("Rich Saronite Deposit"),
		nodeObjectID = 189981,
		oreName = LMining("Saronite Ore"),
		oreItemID = 36912,
		minLevel = 425,
		zones = {
			[127] = true,		-- Crystalsong Forest
			[115] = true,		-- Dragonblight
			[140] = true,		-- Halls of Stone
			[118] = true,		-- Icecrown
			[119] = true,		-- Sholazar Basin
			[120] = true,		-- The Storm Peaks
			[123] = true,		-- Wintergrasp
		},
	},
	[191133] = {
		nodeName = LMining("Titanium Vein"),
		nodeObjectID = 191133,
		oreName = LMining("Titanium Ore"),
		oreItemID = 36910,
		minLevel = 450,
		zones = {
			[127] = true,		-- Crystalsong Forest
			[115] = true,		-- Dragonblight
			[140] = true,		-- Halls of Stone
			[118] = true,		-- Icecrown
			[119] = true,		-- Sholazar Basin
			[120] = true,		-- The Storm Peaks
			[123] = true,		-- Wintergrasp
		},
	},
	[202739] = {
		nodeName = LMining("Rich Obsidium Deposit"),
		nodeObjectID = 202739,
		oreName = LMining("Obsidium Ore"),
		oreItemID = 53038,
		minLevel = 450,
		zones = {
			[207] = true,		-- Deepholm
		},
	},
	[195036] = {
		nodeName = LMining("Pure Saronite Deposit"),
		nodeObjectID = 195036,
		oreName = LMining("Saronite Ore"),
		oreItemID = 36912,
		minLevel = 450,
		zones = {
			[147] = true,		-- Ulduar
		},
	},
	[202738] = {
		nodeName = LMining("Elementium Vein"),
		nodeObjectID = 202738,
		oreName = LMining("Elementium Ore"),
		oreItemID = 52185,
		minLevel = 475,
		zones = {
			[207] = true,		-- Deepholm
			[244] = true,		-- Tol Barad
			[245] = true,		-- Tol Barad Peninsula
			[241] = true,		-- Twilight Highlands
			[249] = true,		-- Uldum
		},
	},
	[202741] = {
		nodeName = LMining("Rich Elementium Vein"),
		nodeObjectID = 202741,
		oreName = LMining("Elementium Ore"),
		oreItemID = 52185,
		minLevel = 500,
		zones = {
			[207] = true,		-- Deepholm
			[244] = true,		-- Tol Barad
			[245] = true,		-- Tol Barad Peninsula
			[241] = true,		-- Twilight Highlands
			[249] = true,		-- Uldum
		},
	},
	[202737] = {
		nodeName = LMining("Pyrite Deposit"),
		nodeObjectID = 202737,
		oreName = LMining("Pyrite Ore"),
		oreItemID = 52183,
		minLevel = 500,
		zones = {
			[241] = true,		-- Twilight Highlands
			[249] = true,		-- Uldum
		},
	},
	[202740] = {
		nodeName = LMining("Rich Pyrite Deposit"),
		nodeObjectID = 202740,
		oreName = LMining("Pyrite Ore"),
		oreItemID = 52183,
		minLevel = 525,
		zones = {
			[244] = true,		-- Tol Barad
			[245] = true,		-- Tol Barad Peninsula
		},
	},
}




local miningNodesByZone = {
	-- Abyssal Depths
	[204] = {
		[202736] = {
			nodeName = LMining("Obsidium Deposit"),
			nodeObjectID = 202736,
			oreName = LMining("Obsidium Ore"),
			oreItemID = 53038,
			minLevel = 425,
		},
	},
	-- Alterac Valley
	[1459] = {
		[165658] = {
			nodeName = LMining("Dark Iron Deposit"),
			nodeObjectID = 165658,
			oreName = LMining("Dark Iron Ore"),
			oreItemID = 11370,
			minLevel = 175,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[175404] = {
			nodeName = LMining("Rich Thorium Vein"),
			nodeObjectID = 175404,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 215,
		},
	},
	-- Arathi Basin
	[1461] = {
		[165658] = {
			nodeName = LMining("Dark Iron Deposit"),
			nodeObjectID = 165658,
			oreName = LMining("Dark Iron Ore"),
			oreItemID = 11370,
			minLevel = 175,
		},
	},
	-- Arathi Highlands
	[1417] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 100,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Ashenvale
	[1440] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 100,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
	},
	-- Auchenai Crypts
	[256] = {
		[181556] = {
			nodeName = LMining("Adamantite Deposit"),
			nodeObjectID = 181556,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 325,
		},
		[181569] = {
			nodeName = LMining("Rich Adamantite Deposit"),
			nodeObjectID = 181569,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 350,
		},
		[181557] = {
			nodeName = LMining("Khorium Vein"),
			nodeObjectID = 181557,
			oreName = LMining("Khorium Ore"),
			oreItemID = 23426,
			minLevel = 375,
		},
	},
	-- Azshara
	[1447] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Azuremyst Isle
	[1943] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
	},
	-- Badlands
	[1418] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 100,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Blackfathom Deeps
	[221] = {
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
	},
	-- Blackrock Depths
	[242] = {
		[165658] = {
			nodeName = LMining("Dark Iron Deposit"),
			nodeObjectID = 165658,
			oreName = LMining("Dark Iron Ore"),
			oreItemID = 11370,
			minLevel = 175,
		},
	},
	-- Blade's Edge Mountains
	[1949] = {
		[181556] = {
			nodeName = LMining("Adamantite Deposit"),
			nodeObjectID = 181556,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 325,
		},
		[181569] = {
			nodeName = LMining("Rich Adamantite Deposit"),
			nodeObjectID = 181569,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 350,
		},
		[181555] = {
			nodeName = LMining("Fel Iron Deposit"),
			nodeObjectID = 181555,
			oreName = LMining("Fel Iron Ore"),
			oreItemID = 23424,
			minLevel = 275,
		},
		[181557] = {
			nodeName = LMining("Khorium Vein"),
			nodeObjectID = 181557,
			oreName = LMining("Khorium Ore"),
			oreItemID = 23426,
			minLevel = 375,
		},
	},
	-- Blasted Lands
	[1419] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[150080] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 150080,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[175404] = {
			nodeName = LMining("Rich Thorium Vein"),
			nodeObjectID = 175404,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 215,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 200,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Bloodmyst Isle
	[1950] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
	},
	-- Borean Tundra
	[114] = {
		[189978] = {
			nodeName = LMining("Cobalt Deposit"),
			nodeObjectID = 189978,
			oreName = LMining("Cobalt Ore"),
			oreItemID = 36909,
			minLevel = 350,
		},
		[189979] = {
			nodeName = LMining("Rich Cobalt Deposit"),
			nodeObjectID = 189979,
			oreName = LMining("Cobalt Ore"),
			oreItemID = 36909,
			minLevel = 375,
		},
	},
	-- Burning Steppes
	[1428] = {
		[165658] = {
			nodeName = LMining("Dark Iron Deposit"),
			nodeObjectID = 165658,
			oreName = LMining("Dark Iron Ore"),
			oreItemID = 11370,
			minLevel = 175,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[175404] = {
			nodeName = LMining("Rich Thorium Vein"),
			nodeObjectID = 175404,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 215,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 200,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Crystalsong Forest
	[127] = {
		[189981] = {
			nodeName = LMining("Rich Saronite Deposit"),
			nodeObjectID = 189981,
			oreName = LMining("Saronite Ore"),
			oreItemID = 36912,
			minLevel = 425,
		},
		[189980] = {
			nodeName = LMining("Saronite Deposit"),
			nodeObjectID = 189980,
			oreName = LMining("Saronite Ore"),
			oreItemID = 36912,
			minLevel = 400,
		},
		[191133] = {
			nodeName = LMining("Titanium Vein"),
			nodeObjectID = 191133,
			oreName = LMining("Titanium Ore"),
			oreItemID = 36910,
			minLevel = 450,
		},
	},
	-- Darkshore
	[1439] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
	},
	-- Deepholm
	[207] = {
		[202738] = {
			nodeName = LMining("Elementium Vein"),
			nodeObjectID = 202738,
			oreName = LMining("Elementium Ore"),
			oreItemID = 52185,
			minLevel = 475,
		},
		[202741] = {
			nodeName = LMining("Rich Elementium Vein"),
			nodeObjectID = 202741,
			oreName = LMining("Elementium Ore"),
			oreItemID = 52185,
			minLevel = 500,
		},
		[202736] = {
			nodeName = LMining("Obsidium Deposit"),
			nodeObjectID = 202736,
			oreName = LMining("Obsidium Ore"),
			oreItemID = 53038,
			minLevel = 425,
		},
		[202739] = {
			nodeName = LMining("Rich Obsidium Deposit"),
			nodeObjectID = 202739,
			oreName = LMining("Obsidium Ore"),
			oreItemID = 53038,
			minLevel = 450,
		},
	},
	-- Desolace
	[1443] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 100,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Dire Maul
	[234] = {
		[175404] = {
			nodeName = LMining("Rich Thorium Vein"),
			nodeObjectID = 175404,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 215,
		},
	},
	-- Dragonblight
	[115] = {
		[189978] = {
			nodeName = LMining("Cobalt Deposit"),
			nodeObjectID = 189978,
			oreName = LMining("Cobalt Ore"),
			oreItemID = 36909,
			minLevel = 350,
		},
		[189979] = {
			nodeName = LMining("Rich Cobalt Deposit"),
			nodeObjectID = 189979,
			oreName = LMining("Cobalt Ore"),
			oreItemID = 36909,
			minLevel = 375,
		},
		[189981] = {
			nodeName = LMining("Rich Saronite Deposit"),
			nodeObjectID = 189981,
			oreName = LMining("Saronite Ore"),
			oreItemID = 36912,
			minLevel = 425,
		},
		[189980] = {
			nodeName = LMining("Saronite Deposit"),
			nodeObjectID = 189980,
			oreName = LMining("Saronite Ore"),
			oreItemID = 36912,
			minLevel = 400,
		},
		[191133] = {
			nodeName = LMining("Titanium Vein"),
			nodeObjectID = 191133,
			oreName = LMining("Titanium Ore"),
			oreItemID = 36910,
			minLevel = 450,
		},
	},
	-- Dun Morogh
	[1426] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
	},
	-- Durotar
	[1411] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
	},
	-- Duskwood
	[1431] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 100,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
	},
	-- Dustwallow Marsh
	[1445] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 100,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Eastern Plaguelands
	[1423] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 100,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[175404] = {
			nodeName = LMining("Rich Thorium Vein"),
			nodeObjectID = 175404,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 215,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 200,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Elwynn Forest
	[1429] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
	},
	-- Eversong Woods
	[1941] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
	},
	-- Felwood
	[1448] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[176643] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 176643,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 200,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Feralas
	[1444] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[73941] = {
			nodeName = LMining("Ooze Covered Gold Vein"),
			nodeObjectID = 73941,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 100,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[123310] = {
			nodeName = LMining("Ooze Covered Mithril Deposit"),
			nodeObjectID = 123310,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[123848] = {
			nodeName = LMining("Ooze Covered Thorium Vein"),
			nodeObjectID = 123848,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 200,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 200,
		},
		[123309] = {
			nodeName = LMining("Ooze Covered Truesilver Deposit"),
			nodeObjectID = 123309,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Ghostlands
	[1942] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
	},
	-- Gilneas
	[179] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
	},
	-- Grizzly Hills
	[116] = {
		[189978] = {
			nodeName = LMining("Cobalt Deposit"),
			nodeObjectID = 189978,
			oreName = LMining("Cobalt Ore"),
			oreItemID = 36909,
			minLevel = 350,
		},
		[189979] = {
			nodeName = LMining("Rich Cobalt Deposit"),
			nodeObjectID = 189979,
			oreName = LMining("Cobalt Ore"),
			oreItemID = 36909,
			minLevel = 375,
		},
	},
	-- Halls of Stone
	[140] = {
		[189981] = {
			nodeName = LMining("Rich Saronite Deposit"),
			nodeObjectID = 189981,
			oreName = LMining("Saronite Ore"),
			oreItemID = 36912,
			minLevel = 425,
		},
		[189980] = {
			nodeName = LMining("Saronite Deposit"),
			nodeObjectID = 189980,
			oreName = LMining("Saronite Ore"),
			oreItemID = 36912,
			minLevel = 400,
		},
		[191133] = {
			nodeName = LMining("Titanium Vein"),
			nodeObjectID = 191133,
			oreName = LMining("Titanium Ore"),
			oreItemID = 36910,
			minLevel = 450,
		},
	},
	-- Hellfire Peninsula
	[1944] = {
		[181555] = {
			nodeName = LMining("Fel Iron Deposit"),
			nodeObjectID = 181555,
			oreName = LMining("Fel Iron Ore"),
			oreItemID = 23424,
			minLevel = 275,
		},
		[181557] = {
			nodeName = LMining("Khorium Vein"),
			nodeObjectID = 181557,
			oreName = LMining("Khorium Ore"),
			oreItemID = 23426,
			minLevel = 375,
		},
	},
	-- Hillsbrad Foothills
	[1424] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 100,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Howling Fjord
	[117] = {
		[189978] = {
			nodeName = LMining("Cobalt Deposit"),
			nodeObjectID = 189978,
			oreName = LMining("Cobalt Ore"),
			oreItemID = 36909,
			minLevel = 350,
		},
		[189979] = {
			nodeName = LMining("Rich Cobalt Deposit"),
			nodeObjectID = 189979,
			oreName = LMining("Cobalt Ore"),
			oreItemID = 36909,
			minLevel = 375,
		},
	},
	-- Icecrown
	[118] = {
		[189981] = {
			nodeName = LMining("Rich Saronite Deposit"),
			nodeObjectID = 189981,
			oreName = LMining("Saronite Ore"),
			oreItemID = 36912,
			minLevel = 425,
		},
		[189980] = {
			nodeName = LMining("Saronite Deposit"),
			nodeObjectID = 189980,
			oreName = LMining("Saronite Ore"),
			oreItemID = 36912,
			minLevel = 400,
		},
		[191133] = {
			nodeName = LMining("Titanium Vein"),
			nodeObjectID = 191133,
			oreName = LMining("Titanium Ore"),
			oreItemID = 36910,
			minLevel = 450,
		},
	},
	-- Isle of Quel'Danas
	[1957] = {
		[181556] = {
			nodeName = LMining("Adamantite Deposit"),
			nodeObjectID = 181556,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 325,
		},
		[181569] = {
			nodeName = LMining("Rich Adamantite Deposit"),
			nodeObjectID = 181569,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 350,
		},
		[181557] = {
			nodeName = LMining("Khorium Vein"),
			nodeObjectID = 181557,
			oreName = LMining("Khorium Ore"),
			oreItemID = 23426,
			minLevel = 375,
		},
	},
	-- Kelp'thar Forest
	[201] = {
		[202736] = {
			nodeName = LMining("Obsidium Deposit"),
			nodeObjectID = 202736,
			oreName = LMining("Obsidium Ore"),
			oreItemID = 53038,
			minLevel = 425,
		},
	},
	-- Loch Modan
	[1432] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
	},
	-- Mana-Tombs
	[272] = {
		[181556] = {
			nodeName = LMining("Adamantite Deposit"),
			nodeObjectID = 181556,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 325,
		},
		[181569] = {
			nodeName = LMining("Rich Adamantite Deposit"),
			nodeObjectID = 181569,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 350,
		},
		[181557] = {
			nodeName = LMining("Khorium Vein"),
			nodeObjectID = 181557,
			oreName = LMining("Khorium Ore"),
			oreItemID = 23426,
			minLevel = 375,
		},
	},
	-- Maraudon
	[280] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Molten Core
	[232] = {
		[165658] = {
			nodeName = LMining("Dark Iron Deposit"),
			nodeObjectID = 165658,
			oreName = LMining("Dark Iron Ore"),
			oreItemID = 11370,
			minLevel = 175,
		},
	},
	-- Mount Hyjal
	[198] = {
		[202736] = {
			nodeName = LMining("Obsidium Deposit"),
			nodeObjectID = 202736,
			oreName = LMining("Obsidium Ore"),
			oreItemID = 53038,
			minLevel = 425,
		},
	},
	-- Mulgore
	[1412] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
	},
	-- Nagrand
	[1951] = {
		[181556] = {
			nodeName = LMining("Adamantite Deposit"),
			nodeObjectID = 181556,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 325,
		},
		[181570] = {
			nodeName = LMining("Rich Adamantite Deposit"),
			nodeObjectID = 181570,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 350,
		},
		[181555] = {
			nodeName = LMining("Fel Iron Deposit"),
			nodeObjectID = 181555,
			oreName = LMining("Fel Iron Ore"),
			oreItemID = 23424,
			minLevel = 275,
		},
		[181557] = {
			nodeName = LMining("Khorium Vein"),
			nodeObjectID = 181557,
			oreName = LMining("Khorium Ore"),
			oreItemID = 23426,
			minLevel = 375,
		},
	},
	-- Netherstorm
	[1953] = {
		[181556] = {
			nodeName = LMining("Adamantite Deposit"),
			nodeObjectID = 181556,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 325,
		},
		[181569] = {
			nodeName = LMining("Rich Adamantite Deposit"),
			nodeObjectID = 181569,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 350,
		},
		[181555] = {
			nodeName = LMining("Fel Iron Deposit"),
			nodeObjectID = 181555,
			oreName = LMining("Fel Iron Ore"),
			oreItemID = 23424,
			minLevel = 275,
		},
		[181557] = {
			nodeName = LMining("Khorium Vein"),
			nodeObjectID = 181557,
			oreName = LMining("Khorium Ore"),
			oreItemID = 23426,
			minLevel = 375,
		},
	},
	-- Northern Stranglethorn
	[1434] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 100,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Razorfen Kraul
	[301] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
	},
	-- Redridge Mountains
	[1433] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[2055] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 2055,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
	},
	-- Searing Gorge
	[1427] = {
		[165658] = {
			nodeName = LMining("Dark Iron Deposit"),
			nodeObjectID = 165658,
			oreName = LMining("Dark Iron Ore"),
			oreItemID = 11370,
			minLevel = 175,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 100,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 200,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Sethekk Halls
	[258] = {
		[181556] = {
			nodeName = LMining("Adamantite Deposit"),
			nodeObjectID = 181556,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 325,
		},
		[181569] = {
			nodeName = LMining("Rich Adamantite Deposit"),
			nodeObjectID = 181569,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 350,
		},
		[181557] = {
			nodeName = LMining("Khorium Vein"),
			nodeObjectID = 181557,
			oreName = LMining("Khorium Ore"),
			oreItemID = 23426,
			minLevel = 375,
		},
	},
	-- Shadow Labyrinth
	[260] = {
		[181556] = {
			nodeName = LMining("Adamantite Deposit"),
			nodeObjectID = 181556,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 325,
		},
		[181569] = {
			nodeName = LMining("Rich Adamantite Deposit"),
			nodeObjectID = 181569,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 350,
		},
		[181557] = {
			nodeName = LMining("Khorium Vein"),
			nodeObjectID = 181557,
			oreName = LMining("Khorium Ore"),
			oreItemID = 23426,
			minLevel = 375,
		},
	},
	-- Shadowmoon Valley
	[1948] = {
		[181556] = {
			nodeName = LMining("Adamantite Deposit"),
			nodeObjectID = 181556,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 325,
		},
		[181569] = {
			nodeName = LMining("Rich Adamantite Deposit"),
			nodeObjectID = 181569,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 350,
		},
		[181555] = {
			nodeName = LMining("Fel Iron Deposit"),
			nodeObjectID = 181555,
			oreName = LMining("Fel Iron Ore"),
			oreItemID = 23424,
			minLevel = 275,
		},
		[181557] = {
			nodeName = LMining("Khorium Vein"),
			nodeObjectID = 181557,
			oreName = LMining("Khorium Ore"),
			oreItemID = 23426,
			minLevel = 375,
		},
	},
	-- Shimmering Expanse
	[205] = {
		[202736] = {
			nodeName = LMining("Obsidium Deposit"),
			nodeObjectID = 202736,
			oreName = LMining("Obsidium Ore"),
			oreItemID = 53038,
			minLevel = 425,
		},
	},
	-- Sholazar Basin
	[119] = {
		[189981] = {
			nodeName = LMining("Rich Saronite Deposit"),
			nodeObjectID = 189981,
			oreName = LMining("Saronite Ore"),
			oreItemID = 36912,
			minLevel = 425,
		},
		[189980] = {
			nodeName = LMining("Saronite Deposit"),
			nodeObjectID = 189980,
			oreName = LMining("Saronite Ore"),
			oreItemID = 36912,
			minLevel = 400,
		},
		[191133] = {
			nodeName = LMining("Titanium Vein"),
			nodeObjectID = 191133,
			oreName = LMining("Titanium Ore"),
			oreItemID = 36910,
			minLevel = 450,
		},
	},
	-- Silithus
	[1451] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[177388] = {
			nodeName = LMining("Ooze Covered Rich Thorium Vein"),
			nodeObjectID = 177388,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 215,
		},
		[175404] = {
			nodeName = LMining("Rich Thorium Vein"),
			nodeObjectID = 175404,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 215,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 200,
		},
		[123309] = {
			nodeName = LMining("Ooze Covered Truesilver Deposit"),
			nodeObjectID = 123309,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Silverpine Forest
	[1421] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
	},
	-- Southern Barrens
	[199] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 100,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
	},
	-- Stonetalon Mountains
	[1442] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 100,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Stranglethorn Vale
	[224] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 100,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Swamp of Sorrows
	[1435] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 100,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[175404] = {
			nodeName = LMining("Rich Thorium Vein"),
			nodeObjectID = 175404,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 215,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 200,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Tanaris
	[1446] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 100,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 200,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Terokkar Forest
	[1952] = {
		[181556] = {
			nodeName = LMining("Adamantite Deposit"),
			nodeObjectID = 181556,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 325,
		},
		[181569] = {
			nodeName = LMining("Rich Adamantite Deposit"),
			nodeObjectID = 181569,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 350,
		},
		[181555] = {
			nodeName = LMining("Fel Iron Deposit"),
			nodeObjectID = 181555,
			oreName = LMining("Fel Iron Ore"),
			oreItemID = 23424,
			minLevel = 275,
		},
		[181557] = {
			nodeName = LMining("Khorium Vein"),
			nodeObjectID = 181557,
			oreName = LMining("Khorium Ore"),
			oreItemID = 23426,
			minLevel = 375,
		},
	},
	-- The Barrens
	[1413] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
	},
	-- The Cape of Stranglethorn
	[210] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 100,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
	},
	-- The Deadmines
	[291] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
	},
	-- The Hinterlands
	[1425] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 100,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 200,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- The Lost Isles
	[174] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
	},
	-- The Slave Pens
	[265] = {
		[181556] = {
			nodeName = LMining("Adamantite Deposit"),
			nodeObjectID = 181556,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 325,
		},
		[181569] = {
			nodeName = LMining("Rich Adamantite Deposit"),
			nodeObjectID = 181569,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 350,
		},
		[181557] = {
			nodeName = LMining("Khorium Vein"),
			nodeObjectID = 181557,
			oreName = LMining("Khorium Ore"),
			oreItemID = 23426,
			minLevel = 375,
		},
	},
	-- The Steamvault
	[263] = {
		[181556] = {
			nodeName = LMining("Adamantite Deposit"),
			nodeObjectID = 181556,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 325,
		},
		[181555] = {
			nodeName = LMining("Fel Iron Deposit"),
			nodeObjectID = 181555,
			oreName = LMining("Fel Iron Ore"),
			oreItemID = 23424,
			minLevel = 275,
		},
		[181557] = {
			nodeName = LMining("Khorium Vein"),
			nodeObjectID = 181557,
			oreName = LMining("Khorium Ore"),
			oreItemID = 23426,
			minLevel = 375,
		},
	},
	-- The Storm Peaks
	[120] = {
		[189978] = {
			nodeName = LMining("Cobalt Deposit"),
			nodeObjectID = 189978,
			oreName = LMining("Cobalt Ore"),
			oreItemID = 36909,
			minLevel = 350,
		},
		[189979] = {
			nodeName = LMining("Rich Cobalt Deposit"),
			nodeObjectID = 189979,
			oreName = LMining("Cobalt Ore"),
			oreItemID = 36909,
			minLevel = 375,
		},
		[189981] = {
			nodeName = LMining("Rich Saronite Deposit"),
			nodeObjectID = 189981,
			oreName = LMining("Saronite Ore"),
			oreItemID = 36912,
			minLevel = 425,
		},
		[189980] = {
			nodeName = LMining("Saronite Deposit"),
			nodeObjectID = 189980,
			oreName = LMining("Saronite Ore"),
			oreItemID = 36912,
			minLevel = 400,
		},
		[191133] = {
			nodeName = LMining("Titanium Vein"),
			nodeObjectID = 191133,
			oreName = LMining("Titanium Ore"),
			oreItemID = 36910,
			minLevel = 450,
		},
	},
	-- The Underbog
	[262] = {
		[181556] = {
			nodeName = LMining("Adamantite Deposit"),
			nodeObjectID = 181556,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 325,
		},
		[181569] = {
			nodeName = LMining("Rich Adamantite Deposit"),
			nodeObjectID = 181569,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 350,
		},
		[181557] = {
			nodeName = LMining("Khorium Vein"),
			nodeObjectID = 181557,
			oreName = LMining("Khorium Ore"),
			oreItemID = 23426,
			minLevel = 375,
		},
	},
	-- Thousand Needles
	[1441] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[73941] = {
			nodeName = LMining("Ooze Covered Gold Vein"),
			nodeObjectID = 73941,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 100,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[123310] = {
			nodeName = LMining("Ooze Covered Mithril Deposit"),
			nodeObjectID = 123310,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[73940] = {
			nodeName = LMining("Ooze Covered Silver Vein"),
			nodeObjectID = 73940,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Tirisfal Glades
	[1420] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
	},
	-- Tol Barad
	[244] = {
		[202738] = {
			nodeName = LMining("Elementium Vein"),
			nodeObjectID = 202738,
			oreName = LMining("Elementium Ore"),
			oreItemID = 52185,
			minLevel = 475,
		},
		[202741] = {
			nodeName = LMining("Rich Elementium Vein"),
			nodeObjectID = 202741,
			oreName = LMining("Elementium Ore"),
			oreItemID = 52185,
			minLevel = 500,
		},
		[202740] = {
			nodeName = LMining("Rich Pyrite Deposit"),
			nodeObjectID = 202740,
			oreName = LMining("Pyrite Ore"),
			oreItemID = 52183,
			minLevel = 525,
		},
	},
	-- Tol Barad Peninsula
	[245] = {
		[202738] = {
			nodeName = LMining("Elementium Vein"),
			nodeObjectID = 202738,
			oreName = LMining("Elementium Ore"),
			oreItemID = 52185,
			minLevel = 475,
		},
		[202741] = {
			nodeName = LMining("Rich Elementium Vein"),
			nodeObjectID = 202741,
			oreName = LMining("Elementium Ore"),
			oreItemID = 52185,
			minLevel = 500,
		},
		[202740] = {
			nodeName = LMining("Rich Pyrite Deposit"),
			nodeObjectID = 202740,
			oreName = LMining("Pyrite Ore"),
			oreItemID = 52183,
			minLevel = 525,
		},
	},
	-- Twilight Highlands
	[241] = {
		[202738] = {
			nodeName = LMining("Elementium Vein"),
			nodeObjectID = 202738,
			oreName = LMining("Elementium Ore"),
			oreItemID = 52185,
			minLevel = 475,
		},
		[202741] = {
			nodeName = LMining("Rich Elementium Vein"),
			nodeObjectID = 202741,
			oreName = LMining("Elementium Ore"),
			oreItemID = 52185,
			minLevel = 500,
		},
		[202737] = {
			nodeName = LMining("Pyrite Deposit"),
			nodeObjectID = 202737,
			oreName = LMining("Pyrite Ore"),
			oreItemID = 52183,
			minLevel = 500,
		},
	},
	-- Uldaman
	[230] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Ulduar
	[147] = {
		[195036] = {
			nodeName = LMining("Pure Saronite Deposit"),
			nodeObjectID = 195036,
			oreName = LMining("Saronite Ore"),
			oreItemID = 36912,
			minLevel = 450,
		},
	},
	-- Uldum
	[249] = {
		[202738] = {
			nodeName = LMining("Elementium Vein"),
			nodeObjectID = 202738,
			oreName = LMining("Elementium Ore"),
			oreItemID = 52185,
			minLevel = 475,
		},
		[202741] = {
			nodeName = LMining("Rich Elementium Vein"),
			nodeObjectID = 202741,
			oreName = LMining("Elementium Ore"),
			oreItemID = 52185,
			minLevel = 500,
		},
		[202737] = {
			nodeName = LMining("Pyrite Deposit"),
			nodeObjectID = 202737,
			oreName = LMining("Pyrite Ore"),
			oreItemID = 52183,
			minLevel = 500,
		},
	},
	-- Un'Goro Crater
	[1449] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[123848] = {
			nodeName = LMining("Ooze Covered Thorium Vein"),
			nodeObjectID = 123848,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 200,
		},
		[175404] = {
			nodeName = LMining("Rich Thorium Vein"),
			nodeObjectID = 175404,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 215,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 200,
		},
		[123309] = {
			nodeName = LMining("Ooze Covered Truesilver Deposit"),
			nodeObjectID = 123309,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Utgarde Keep
	[133] = {
		[189978] = {
			nodeName = LMining("Cobalt Deposit"),
			nodeObjectID = 189978,
			oreName = LMining("Cobalt Ore"),
			oreItemID = 36909,
			minLevel = 350,
		},
		[189979] = {
			nodeName = LMining("Rich Cobalt Deposit"),
			nodeObjectID = 189979,
			oreName = LMining("Cobalt Ore"),
			oreItemID = 36909,
			minLevel = 375,
		},
	},
	-- Wailing Caverns
	[279] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
	},
	-- Western Plaguelands
	[1422] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 100,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[175404] = {
			nodeName = LMining("Rich Thorium Vein"),
			nodeObjectID = 175404,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 215,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 200,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Westfall
	[1436] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
	},
	-- Wetlands
	[1437] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 100,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 65,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 50,
		},
	},
	-- Wintergrasp
	[123] = {
		[189981] = {
			nodeName = LMining("Rich Saronite Deposit"),
			nodeObjectID = 189981,
			oreName = LMining("Saronite Ore"),
			oreItemID = 36912,
			minLevel = 425,
		},
		[189980] = {
			nodeName = LMining("Saronite Deposit"),
			nodeObjectID = 189980,
			oreName = LMining("Saronite Ore"),
			oreItemID = 36912,
			minLevel = 400,
		},
		[191133] = {
			nodeName = LMining("Titanium Vein"),
			nodeObjectID = 191133,
			oreName = LMining("Titanium Ore"),
			oreItemID = 36910,
			minLevel = 450,
		},
	},
	-- Winterspring
	[1452] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 115,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 150,
		},
		[175404] = {
			nodeName = LMining("Rich Thorium Vein"),
			nodeObjectID = 175404,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 215,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 200,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 165,
		},
	},
	-- Zangarmarsh
	[1946] = {
		[181556] = {
			nodeName = LMining("Adamantite Deposit"),
			nodeObjectID = 181556,
			oreName = LMining("Adamantite Ore"),
			oreItemID = 23425,
			minLevel = 325,
		},
		[181555] = {
			nodeName = LMining("Fel Iron Deposit"),
			nodeObjectID = 181555,
			oreName = LMining("Fel Iron Ore"),
			oreItemID = 23424,
			minLevel = 275,
		},
		[181557] = {
			nodeName = LMining("Khorium Vein"),
			nodeObjectID = 181557,
			oreName = LMining("Khorium Ore"),
			oreItemID = 23426,
			minLevel = 375,
		},
	},
	-- Zul'Drak
	[121] = {
		[189978] = {
			nodeName = LMining("Cobalt Deposit"),
			nodeObjectID = 189978,
			oreName = LMining("Cobalt Ore"),
			oreItemID = 36909,
			minLevel = 350,
		},
		[189979] = {
			nodeName = LMining("Rich Cobalt Deposit"),
			nodeObjectID = 189979,
			oreName = LMining("Cobalt Ore"),
			oreItemID = 36909,
			minLevel = 375,
		},
		[189980] = {
			nodeName = LMining("Saronite Deposit"),
			nodeObjectID = 189980,
			oreName = LMining("Saronite Ore"),
			oreItemID = 36912,
			minLevel = 400,
		},
	},
	-- Zul'Gurub
	[233] = {
		[180215] = {
			nodeName = LMining("Hakkari Thorium Vein"),
			nodeObjectID = 180215,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 215,
		},
	},
}



--------------------------------------------------------------------------------------------------------
--                                          MINING FUNCTIONS                                          --
--------------------------------------------------------------------------------------------------------

-- Returns for the specified mining node:
--  - nodeName
--  - nodeObjectID
--  - oreName
--  - oreItemID
--  - minLevel
--  - zones; table: k = mapID 
function Tourist:GetMiningNode(nodeObjectID)
	-- Some mining nodes have different IDs, i.e. because they drop different secondary items.
	-- LibTourist only uses the most common nodeType; use the mapping table to find it
	nodeObjectID = miningNodeIDMapping[nodeObjectID] or nodeObjectID
	return miningNodes[nodeObjectID]
end

-- Returns an r, g and b value indicating the mining difficulty of the specified mining node
function Tourist:GetMiningSkillColor(nodeObjectID, currentSkill)
	local node = Tourist:GetMiningNode(nodeObjectID)
	if node then
		return Tourist:GetGatheringSkillColor(node.minLevel, currentSkill)
	else
		-- White
		return 1, 1, 1
	end
end

local function miningNodeSorter(a, b)
	return a.minLevel < b.minLevel
end

-- Iterates through all standard mining nodes, returning for each node:
--  - nodeName
--  - nodeObjectID
--  - oreName
--  - oreItemID
--  - minLevel
--  - zones; table: k = mapID
function Tourist:IterateMiningNodes()
	for k in pairs(t) do
		t[k] = nil
	end
	for k, v in pairs(miningNodes) do
		t[#t+1] = v  -- v contains all data including k
	end
	table.sort(t, miningNodeSorter)
	t.n = 0
	return myiter, t, nil
end

-- Iterates through all standard mining nodes within the specified zone, returning for each node:
--  - nodeName
--  - nodeObjectID
--  - oreName
--  - oreItemID
--  - minLevel
function Tourist:IterateMiningNodesByZone(mapID)
	local zoneMiningNodes = miningNodesByZone[mapID]
	if type(zoneMiningNodes) == "table" then
		for k in pairs(t) do
			t[k] = nil
		end
		for k, v in pairs(zoneMiningNodes) do
			t[#t+1] = v  -- v contains all data including k
		end
		table.sort(t, miningNodeSorter)
		t.n = 0
		return myiter, t, nil
	else
		return retOne, zoneMiningNodes, nil
	end
end

-- Iterates through the mapIDs of the zones in which the specified mining node can be found
function Tourist:IterateZonesByMiningNode(miningNodeObjectID)
	local miningNode, zones
	miningNode = Tourist:GetMiningNode(miningNodeObjectID)
	if miningNode then zones = miningNode.zones end

	if not zones then
		return retNil
	elseif type(zones) == "table" then
		for k in pairs(t) do
			t[k] = nil
		end
		for k, v in pairs(zones) do
			t[#t+1] = k
		end
		table.sort(t, mysort)
		t.n = 0
		return myiter, t, nil
	else
		return retOne, zones, nil
	end
end

-- Returns true if there are any standard mining nodes in the zone
function Tourist:DoesZoneHaveMiningNodes(zone)
	local mapID = Tourist:GetZoneMapID(zone) or zone
	return not not miningNodesByZone[mapID]
end



--------------------------------------------------------------------------------------------------------
--                                                CORE                                                --
--------------------------------------------------------------------------------------------------------

	trace("Tourist: Initializing continents...")
	local continentNames = Tourist:GetMapContinentsAlt()
	continentNames[947] = "Azeroth"

	local counter = 0

	for continentMapID, continentName in pairs(continentNames) do
		trace("Tourist: Processing Continent "..tostring(continentMapID)..": "..continentName.."...")

		if zones[continentName] then
			-- Set MapID
			zones[continentName].zoneMapID = continentMapID
			-- Get map art ID
			zones[continentName].texture = C_Map.GetMapArtID(continentMapID)
			-- Get map size in yards
			local cWidth = HBD:GetZoneSize(continentMapID)
			if not cWidth then
				trace("|r|cffff4422! -- Tourist:|r No size data for "..tostring(continentName))
			end
			if cWidth == 0 then
				trace("|r|cffff4422! -- Tourist:|r Size is zero for "..tostring(continentName))
			end
			zones[continentName].yards = cWidth or 0
			--trace("Tourist: Continent size in yards for "..tostring(continentName).." ("..tostring(continentMapID).."): "..tostring(round(zones[continentName].yards, 2)))
		else
			-- Unknown Continent
			trace("|r|cffff4422! -- Tourist:|r TODO: Add Continent '"..tostring(continentName).."' ("..tostring(continentMapID)..")")
		end

		counter = counter + 1
	end
	trace("Tourist: Processed "..tostring(counter).." continents")

	trace("Tourist: Initializing zones...")
	local doneZones = {}
	local mapZones = {}
	local uniqueZoneName
	local minLvl, maxLvl, minPetLvl, maxPetLvl
	local counter2 = 0
	counter = 0

	for continentMapID, continentName in pairs(continentNames) do
		trace("Tourist: Initializing zones for "..tostring(continentName).." (MapID "..tostring(continentMapID)..")...")

		mapZones = Tourist:GetMapZonesAlt(continentMapID)
		counter = 0
		for zoneMapID, zoneName in pairs(mapZones) do
			-- Add mapIDs to lookup table
			zoneMapIDtoContinentMapID[zoneMapID] = continentMapID

			-- Check for duplicate on continent name + zone name
			if not doneZones[continentName.."."..zoneName] then
				if zones[zoneName] then
					-- Set zone mapID
					zones[zoneName].zoneMapID = zoneMapID
					-- Get zone texture ID
					zones[zoneName].texture = C_Map.GetMapArtID(continentMapID)
					-- Get zone player levels
					minLvl, maxLvl = C_Map.GetMapLevels(zoneMapID)
					
					-- Do some tracing to detect mismatches
					if minLvl and minLvl > 0 and maxLvl and maxLvl > 0 and (zones[zoneName].low ~= minLvl or zones[zoneName].high ~= maxLvl) then
						-- C_Map has level data which differs from LT's, or LT has no data
						trace("|r|cffffa500! -- Tourist:|r Diff level data for "..tostring(zoneName)..": LT = "..tostring(zones[zoneName].low).."-"..tostring(zones[zoneName].high)..", WoW = "..tostring(minLvl).."-"..tostring(maxLvl) )
					end
					if (not minLvl and not maxLvl) or (minLvl + maxLvl == 0) then
						-- No data or 0s from C_Map
						if zones[zoneName].low and zones[zoneName].low > 0 then
							-- however, LT expects data
							trace("|r|cffffa500! -- Tourist:|r No level data for "..tostring(zoneName).." ("..tostring(continentName).."), using "..tostring(zones[zoneName].low).."-"..tostring(zones[zoneName].high) )
						end
					end
					
					-- If C_Map provides level data, use it instead of hard coded values
					if minLvl and minLvl > 0 then zones[zoneName].low = minLvl end
					if maxLvl and maxLvl > 0 then zones[zoneName].high = maxLvl end

					-- Get map size
					local zWidth = HBD:GetZoneSize(zoneMapID)
					if not zWidth then
						trace("|r|cffff4422! -- Tourist:|r No size data for "..tostring(zoneName).." ("..tostring(continentName)..")" )
					end
					if zWidth == 0 then
						trace("|r|cffff4422! -- Tourist:|r Size is zero for "..tostring(zoneName).." ("..tostring(continentName)..")" )
					end
					if zWidth ~= 0 or not zones[zoneName].yards then
						-- Make sure the size is always set (even if it's 0) but don't overwrite any hardcoded values if the size is 0
						zones[zoneName].yards = zWidth
					end
				else
					trace("|r|cffff4422! -- Tourist:|r TODO: Add zone "..tostring(zoneName).." (to "..tostring(continentName)..")" )
				end

				doneZones[continentName.."."..zoneName] = true
			else
				trace("|r|cffff4422! -- Tourist:|r Duplicate zone: "..tostring(zoneName).." [ID "..tostring(zoneMapID).."] (at "..tostring(continentName)..")" )
			end
			counter = counter + 1
		end -- zone loop

		trace( "Tourist: Processed "..tostring(counter).." zones for "..tostring(continentName) )
		counter2 = counter2 + counter
	end -- continent loop

	trace("Tourist: Finished initializing "..tostring(counter2).." zones")







	trace("Tourist: Filling lookup tables...")

	-- Fill the lookup tables
	for k,v in pairs(zones) do
		lows[k] = v.low or 0
		highs[k] = v.high or 0
		continents[k] = v.continent or UNKNOWN
		instances[k] = v.instances
		paths[k] = v.paths or false
		flightnodes[k] = v.flightnodes or false
		types[k] = v.type or "Zone"
		groupSizes[k] = v.groupSize
		groupMinSizes[k] = v.groupMinSize
		groupMaxSizes[k] = v.groupMaxSize
		groupAltSizes[k] = v.altGroupSize
		factions[k] = v.faction
		yardWidths[k] = v.yards
		yardHeights[k] = v.yards and v.yards * 2/3 or nil
		fishing_low[k] = v.fishing_low
		fishing_high[k] = v.fishing_high
		textures[k] = v.texture
		complexOfInstance[k] = v.complex
		zoneComplexes[k] = v.complexes
		if v.texture then
			textures_rev[v.texture] = k
		end
		zoneMapIDs[k] = v.zoneMapID
		if v.entrancePortal then
			entrancePortals_zone[k] = v.entrancePortal[1]
			entrancePortals_x[k] = v.entrancePortal[2]
			entrancePortals_y[k] = v.entrancePortal[3]
		end
		if v.flightnodes then
			for nodeID in pairs(v.flightnodes) do
				if not FlightnodeLookupTable[nodeID] then
					FlightnodeLookupTable[nodeID] = true
				end
			end
		end
	end

	trace("Tourist: Built Flightnode lookup table: "..tostring(tablelength(FlightnodeLookupTable)).." nodes.")

	zones = nil

	trace("Tourist: LibTourist Classic initialized, loaded by "..tostring(addonName))

	PLAYER_LEVEL_UP(Tourist)
end

return Tourist

