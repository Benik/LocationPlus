--[[
Name: LibTouristClassic-1.0
Revision: $Rev: 243 $
Author(s): Odica, Mishikal1; based on LibTourist-3.0
Documentation: https://www.wowace.com/projects/libtourist-1-0/pages/api-reference
Git: https://repos.wowace.com/wow/libtourist-classic libtourist-classic
Description: A library to provide information about zones and instances for WoW Classic
License: MIT
]]

local MAJOR_VERSION = "LibTouristClassic-1.0"
local MINOR_VERSION = 90000 + tonumber(("$Revision: 240 $"):match("(%d+)"))

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
elseif GetLocale() == "deDE" then
	X_Y_ZEPPELIN = "%s - %s Zeppelin"
	X_Y_BOAT = "%s - %s Schiff"
	X_Y_PORTAL = "%s - %s Portal"
	X_Y_TELEPORT = "%s - %s Teleport"
elseif GetLocale() == "esES" then
	X_Y_ZEPPELIN = "%s - %s Zepelín"
	X_Y_BOAT = "%s - %s Barco"
	X_Y_PORTAL = "%s - %s Portal"
	X_Y_TELEPORT = "%s - %s Teletransportador"
elseif GetLocale() == "esMX" then
	X_Y_ZEPPELIN = "%s - %s Zepelín"
	X_Y_BOAT = "%s - %s Barco"
	X_Y_PORTAL = "%s - %s Portal"
	X_Y_TELEPORT = "%s - %s Teletransportador"
elseif GetLocale() == "itIT" then
	X_Y_ZEPPELIN = "%s - %s Zeppelin"
	X_Y_BOAT = "%s - %s Barca"
	X_Y_PORTAL = "%s - %s Portale"
	X_Y_TELEPORT = "%s - %s Teletrasporto"	
elseif GetLocale() == "ptBR" then
	X_Y_ZEPPELIN = "%s - %s Zepelim"
	X_Y_BOAT = "%s - %s Barco"
	X_Y_PORTAL = "%s - %s Portal"
	X_Y_TELEPORT = "%s - %s Teleporte"
elseif GetLocale() == "ruRU" then
	X_Y_ZEPPELIN = "%s - %s дирижабль"
	X_Y_BOAT = "%s - %s Лодка"
	X_Y_PORTAL = "%s - %s Портал"
	X_Y_TELEPORT = "%s - %s Телепорт"	
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


local flightNodeIgnoreList = {
	-- [57] = "Fishing Village, Teldrassil",
	-- [54] = "Transport, Feathermoon - Feralas",
	-- [35] = "Transport, Orgrimmar Zepplins",
	-- [34] = "Transport, Booty Bay - Ratchet",
	-- [87] = "Crown Guard Tower, Eastern Plaguelands",
	-- [86] = "Eastwall Tower, Eastern Plaguelands",
	-- [85] = "Northpass Tower, Eastern Plaguelands",
	-- [84] = "Plaguewood Tower, Eastern Plaguelands",
	-- [78] = "Naxxramas",
	-- [51] = "Transport, Rut'theran - Auberdine",
	-- [50] = "Transport, Menethil Ships",
	-- [47] = "Transport, Grom'gol - Orgrimmar",
	-- [46] = "Southshore Ferry, Hillsbrad",
	-- [36] = "Generic, World target",
	-- [24] = "Generic, World target for Zeppelin Paths",
	-- [15] = "Eastern Plaguelands",
	-- [9] = "Booty Bay, Stranglethorn",
	-- [3] = "Programmer Isle",
	-- [1] = "Northshire Abbey",
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
}


--------------------------------------------------------------------------------------------------------
--                                            Localization                                            --
--------------------------------------------------------------------------------------------------------

local MapIdLookupTable = {
    [246] = "The Shattered Halls",
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
    [330] = "Gruul's Lair",
    [331] = "Magtheridon's Lair",
    [332] = "Serpentshrine Cavern",
    [334] = "Tempest Keep",
    [339] = "Black Temple",
    [347] = "Hellfire Ramparts",
    [946] = "Cosmic",
    [947] = "Azeroth",
	[987] = "Outland",
    [1411] = "Durotar",
    [1412] = "Mulgore",
    [1413] = "The Barrens",
    [1414] = "Kalimdor",
    [1415] = "Eastern Kingdoms",
    [1416] = "Alterac Mountains",
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
    [1434] = "Stranglethorn Vale",
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
-- NOTE: The following are InstanceIDs, as Instances do not have a uiMapID in Classic
    [30] = "Alteric Valley",
    [33] = "Shadowfang Keep",
    [34] = "The Stockade",
    [36] = "The Deadmines",
    [43] = "Wailing Caverns",
    [47] = "Razorfen Kraul",
    [48] = "Blackfathom Deeps",
    [70] = "Uldaman",
    [90] = "Gnomeregan",
    [109] = "The Temple of Atal'Hakkar",
    [129] = "Razorfen Downs",
    [189] = "Scarlet Monastery",
    [209] = "Zul'Farrak",
    [229] = "Blackrock Spire",
    [230] = "Blackrock Depths",
    [249] = "Onyxia's Lair",
--	[269] = "Opening of the Dark Portal", -- duplicate with The Arcatraz, above
    [289] = "Scholomance",
    [309] = "Zul'Gurub",
    [329] = "Stratholme",
    [349] = "Maraudon",
    [369] = "Deeprun Tram",
    [389] = "Ragefire Chasm",
    [409] = "Molten Core",
    [429] = "Dire Maul",
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
    [572] = "Ruins of Lordaeron",
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
    [593] = "Transport: Booty Bay to Ratchet",
    [1004] = "Scarlet Monastery",
    [1007] = "Scholomance",
}


-- These zones are known in LibTourist's zones collection but are not returned by C_Map.GetMapInfo.
-- The IDs are the areaIDs as used by C_Map.GetAreaInfo.
local zoneTranslation = {
	enUS = {
		-- Instances
		[5914] = "Dire Maul - East",
		[5913] = "Dire Maul - North",
		[5915] = "Dire Maul - West",
		[2366] = "The Black Morass",
		[2367] = "Old Hillsbrad Foothills",
		[3606] = "Hyjal Summit",
		[4075] = "Sunwell Plateau",
		[4131] = "Magisters' Terrace",
		
		-- Complexes
		[1445] = "Blackrock Mountain",
		[3545] = "Hellfire Citadel",
		[3688] = "Auchindoun",
		[3905] = "Coilfang Reservoir",
		[5695] = "Ahn'Qiraj: The Fallen Kingdom",
		[2300] = "Caverns of Time",
	},
	deDE = {
		-- Instances
		[5914] = "Düsterbruch - Ost",
		[5913] = "Düsterbruch - Nord",
		[5915] = "Düsterbruch - West",
		[2366] = "Der schwarze Morast",
		[2367] = "Vorgebirge des Alten Hügellands",
		[3606] = "Hyjalgipfel",
		[4075] = "Sonnenbrunnenplateau",
		[4131] = "Terrasse der Magister",
		-- Complexes
		[1445] = "Der Schwarzfels",
		[3545] = "Höllenfeuerzitadelle",
		[3688] = "Auchindoun",
		[3905] = "Der Echsenkessel",
		[5695] = "Ahn'Qiraj: Das Gefallene Königreich",
		[2300] = "Höhlen der Zeit",
	},
	esES = {
		-- Instances
		[5914] = "La Masacre: Este",
		[5913] = "La Masacre: Norte",
		[5915] = "La Masacre: Oeste",
		[2366] = "La Ciénaga Negra",
		[2367] = "Antiguas Laderas de Trabalomas",
		[3606] = "La Cima Hyjal",
		[4075] = "Meseta de La Fuente del Sol",
		[4131] = "Bancal del Magister",
		-- Complexes
		[1445] = "Montaña Roca Negra",
		[3545] = "Ciudadela del Fuego Infernal",
		[3688] = "Auchindoun",
		[3905] = "Reserva Colmillo Torcido",
		[5695] = "Ahn'Qiraj: El Reino Caído",
		[2300] = "Cavernas del Tiempo",
	},
	esMX = {
		-- Instances
		[5914] = "La Masacre: Este",
		[5913] = "La Masacre: Norte",
		[5915] = "La Masacre: Oeste",
		[2366] = "La Ciénaga Negra",
		[2367] = "Antiguas Laderas de Trabalomas",
		[3606] = "La Cima Hyjal",
		[4075] = "Meseta de La Fuente del Sol",
		[4131] = "Bancal del Magister",
		-- Complexes
		[1445] = "Montaña Roca Negra",
		[3545] = "Ciudadela del Fuego Infernal",
		[3688] = "Auchindoun",
		[3905] = "Reserva Colmillo Torcido",
		[5695] = "Ahn'Qiraj: El Reino Caído",
		[2300] = "Cavernas del Tiempo",
	},
	frFR = {
		-- Instances
		[5914] = "Haches-Tripes - Est",
		[5913] = "Haches-Tripes - Nord",
		[5915] = "Haches-Tripes - Ouest",
		[2366] = "Le Noir Marécage",
		[2367] = "Contreforts de Hautebrande d'antan",
		[3606] = "Sommet d'Hyjal",
		[4075] = "Plateau du Puits de soleil",
		[4131] = "Terrasse des Magistères",
		-- Complexes
		[1445] = "Mont Rochenoire",
		[3545] = "Citadelle des Flammes infernales",
		[3688] = "Auchindoun",
		[3905] = "Réservoir de Glissecroc",
		[5695] = "Ahn’Qiraj : le royaume Déchu",
		[2300] = "Grottes du temps",
	},
	itIT = {
		-- Instances
		[5914] = "Maglio Infausto - Est",
		[5913] = "Maglio Infausto - Nord",
		[5915] = "Maglio Infausto - Ovest",
		[2366] = "La palude nera",
		[2367] = "Antiche colline pedemontane di Hillsbrad",
		[3606] = "Vertice Hyjal",
		[4075] = "Altopiano del sole",
		[4131] = "Terrazza dei Magistri",
		-- Complexes
		[1445] = "Massiccio Roccianera",
		[3545] = "Cittadella del Fuoco Infernale",
		[3688] = "Auchindoun",
		[3905] = "Bacino degli Spiraguzza",
		[5695] = "Ahn'qiraj: il Regno Perduto",
		[2300] = "Caverne del tempo",
	},
	koKR = {
		-- Instances
		[5914] = "혈투의 전장 - 동쪽",
		[5913] = "혈투의 전장 - 북쪽",
		[5915] = "혈투의 전장 - 서쪽",
		[2366] = "검은늪",
		[2367] = "옛 힐스브래드 구릉지",
		[3606] = "하이잘 정상",
		[4075] = "태양샘 고원",
		[4131] = "마법학자의 정원",
		-- Complexes
		[1445] = "검은바위 산",
		[3545] = "지옥불 성채",
		[3688] = "아킨둔",
		[3905] = "갈퀴송곳니 저수지",
		[5695] = "안퀴라즈: 무너진 왕국",
		[2300] = "시간의 동굴",
	},
	ptBR = {
		-- Instances
		[5914] = "Gládio Cruel – Leste",
		[5913] = "Gládio Cruel – Norte",
		[5915] = "Gládio Cruel – Oeste",
		[2366] = "Lamaçal Negro",
		[2367] = "Antigo Contraforte de Eira dos Montes",
		[3606] = "Pico Hyjal",
		[4075] = "Platô da Nascente do Sol",
		[4131] = "Terraço dos Magísteres",		
		-- Complexes
		[1445] = "Montanha Rocha Negra",
		[3545] = "Cidadela Fogo do Inferno",
		[3688] = "Auchindoun",
		[3905] = "Reservatório Presacurva",
		[5695] = "Ahn'Qiraj: O Reino Derrotado",
		[2300] = "Cavernas do Tempo",
	},
	ruRU = {
		-- Instances
		[5914] = "Забытый город – восток",
		[5913] = "Забытый город – север",
		[5915] = "Забытый город – запад",
		[2366] = "Черные топи",
		[2367] = "Старые предгорья Хилсбрада",
		[3606] = "Вершина Хиджала",
		[4075] = "Плато Солнечного Колодца",
		[4131] = "Терраса Магистров",		
		-- Complexes
		[1445] = "Черная гора",
		[3545] = "Цитадель Адского Пламени",
		[3688] = "Аукиндон",
		[3905] = "Резервуар Кривого Клыка",
		[5695] = "Ан'Кираж: Павшее Королевство",
		[2300] = "Пещеры Времени",
	},
	zhCN = {
		-- Instances
		[5914] = "厄运之槌 - 东",
		[5913] = "厄运之槌 - 北",
		[5915] = "厄运之槌 - 西",
		[2366] = "黑色沼泽",
		[2367] = "旧希尔斯布莱德丘陵",
		[3606] = "海加尔峰",
		[4075] = "太阳之井高地",
		[4131] = "魔导师平台",
		-- Complexes
		[1445] = "黑石山",
		[3545] = "地狱火堡垒",
		[3688] = "奥金顿",
		[3905] = "盘牙水库",
		[5695] = "安其拉：堕落王国",
		[2300] = "时光之穴",
	},
	zhTW = {
		-- Instances
		[5914] = "厄運之槌 - 東方",
		[5913] = "厄運之槌 - 北方",
		[5915] = "厄運之槌 - 西方",
		[2366] = "黑色沼澤",
		[2367] = "希爾斯布萊德丘陵舊址",
		[3606] = "海加爾山",
		[4075] = "太陽之井高地",
		[4131] = "博學者殿堂",
		-- Complexes
		[1445] = "黑石山",
		[3545] = "地獄火堡壘",
		[3688] = "奧齊頓",
		[3905] = "盤牙蓄湖",
		[5695] = "其拉：沒落的王朝",
		[2300] = "時光之穴",
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
				-- Not in lookup
				trace("|r|cffff4422! -- Tourist:|r English name not found in lookup for uiMapID "..tostring(uiMapID).." ("..tostring(localizedZoneName)..")" )
			end
		end
	end

	for instanceID = 1, 2000, 1 do
		localizedZoneName = GetRealZoneText(instanceID);
		if localizedZoneName and localizedZoneName ~= ""  then
			englishZoneName = MapIdLookupTable[instanceID]

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
				trace("|r|cffff4422! -- Tourist:|r English name not found in lookup for instanceID "..tostring(instanceID).." ("..tostring(localizedZoneName)..")" )
			end
		end
	end

	-- Load from zoneTranslation
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
--		cMapID = Tourist:GetContinentMapID(zMapID)
--		cName = MapIdLookupTable[cMapID]
		nodes = C_TaxiMap.GetTaxiNodesForMap(zMapID)

		if nodes ~= nil then
			numNodes = tablelength(nodes)
			if numNodes > 0 then
				for i, node in ipairs(nodes) do
					if not FlightnodeLookupTable[node.nodeID] then
						if not missingNodes[node.nodeID] and not flightNodeIgnoreList[node.nodeID] then
							trace("|r|cffff4422! -- Tourist: Missing flightnode in lookup: "..tostring(node.nodeID).." = "..tostring(node.name))
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
				trace("|r|cffff4422! -- Tourist: Missing flightnode in lookup: "..tostring(node.nodeID).." = "..tostring(node.name))
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
		local zoneName = C_Map.GetMapInfo(uiMapID).name
	    return zoneName
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


-- Formats the minimum and maximum player level for the given zone as "[min]-[max]".
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
		return 1, 0, 0	
	elseif currentSkill < minLevel + 25 + lvl1Corr then
		-- Orange
		return 1, 0.7, 0	
	elseif currentSkill < minLevel + 50 + lvl1Corr then
		-- Yellow
		return 1, 1, 0	
	elseif currentSkill < minLevel + 100 + lvl1Corr then
		-- Green
		return 0, 1, 0	
	else
		-- Gray
		return 0.5, 0.5, 0.5
	end
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
			if types[zone] ~= "Transport" then
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
	return t and t ~= "Instance" and t ~= "Battleground" and t ~= "Transport" and t ~= "Arena" and t ~= "Complex"
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
	return t and t ~= "Transport"
end

function Tourist:IsTransport(zone)
	zone = Tourist:GetMapNameByIDAlt(zone) or zone
	local t = types[zone]
	return t == "Transport"
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

		if types[vertex] == "Transport" then
			price = price * 2
		end

		self[vertex] = price
		return price
	end
})

-- This function tries to calculate the most optimal path between alpha and bravo
-- by foot or ground mount, that is, without using a flying mount or a taxi service.
-- The return value is an iteration that gives a travel advice in the form of a list
-- of zones and transports to follow in order to get from alpha to bravo.
-- The function tries to avoid hostile zones by calculating a "price" for each possible
-- route. The price calculation takes zone level, faction and type into account.
-- See metatable above for the 'pricing' mechanism.
function Tourist:IteratePath(alpha, bravo)
	alpha = Tourist:GetMapNameByIDAlt(alpha) or alpha
	bravo = Tourist:GetMapNameByIDAlt(bravo) or bravo

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

	-- TRANSPORT DEFINITIONS ----------------------------------------------------------------

	local transports = {}

	-- Boats
	transports["STRANGLETHORN_BARRENS_BOAT"] = string.format(X_Y_BOAT, BZ["Stranglethorn Vale"], BZ["The Barrens"])
	transports["WETLANDS_DUSTWALLOW_BOAT"] = string.format(X_Y_BOAT, BZ["Wetlands"], BZ["Dustwallow Marsh"])
	transports["WETLANDS_DARKSHORE_BOAT"] = string.format(X_Y_BOAT, BZ["Wetlands"], BZ["Darkshore"])
	-- TBC
	transports["DARKSHORE_TELDRASSIL_BOAT"] = string.format(X_Y_BOAT, BZ["Darkshore"], BZ["Teldrassil"])
	transports["DARKSHORE_AZUREMYST_BOAT"] = string.format(X_Y_BOAT, BZ["Darkshore"], BZ["Azuremyst Isle"])

	-- Zeppelins
	transports["ORGRIMMAR_UNDERCITY_ZEPPELIN"] = string.format(X_Y_ZEPPELIN, BZ["Orgrimmar"], BZ["Undercity"])
	transports["ORGRIMMAR_GROMGOL_ZEPPELIN"] = string.format(X_Y_ZEPPELIN, BZ["Orgrimmar"], BZ["Stranglethorn Vale"])
	transports["UNDERCITY_GROMGOL_ZEPPELIN"] = string.format(X_Y_ZEPPELIN, BZ["Undercity"], BZ["Stranglethorn Vale"])

	-- Portals
	transports["DARNASSUS_TELDRASSIL_PORTAL"] = string.format(X_Y_PORTAL, BZ["Darnassus"], BZ["Teldrassil"])
	-- TBC
	transports["SHATTRATH_IRONFORGE_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["Ironforge"])
	transports["SHATTRATH_STORMWIND_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["Stormwind City"])
	transports["SHATTRATH_DARNASSUS_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["Darnassus"])
	transports["SHATTRATH_ORGRIMMAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["Orgrimmar"])
	transports["SHATTRATH_THUNDERBLUFF_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["Thunder Bluff"])
	transports["SHATTRATH_UNDERCITY_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["Undercity"])
	transports["SHATTRATH_EXODAR_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["The Exodar"])
	transports["SHATTRATH_SILVERMOON_PORTAL"] = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["Silvermoon City"])	

	transports["THE_DARK_PORTAL"] = string.format(X_Y_PORTAL, BZ["Blasted Lands"], BZ["Hellfire Peninsula"])	



	-- Teleports (TBC)
	transports["SILVERMOON_UNDERCITY_TELEPORT"] = string.format(X_Y_TELEPORT, BZ["Silvermoon City"], BZ["Undercity"])


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


	-- TRANSPORTS ---------------------------------------------------------------

	zones[transports["ORGRIMMAR_UNDERCITY_ZEPPELIN"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
			[BZ["Tirisfal Glades"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["ORGRIMMAR_GROMGOL_ZEPPELIN"]] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
			[BZ["Stranglethorn Vale"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["UNDERCITY_GROMGOL_ZEPPELIN"]] = {
		paths = {
			[BZ["Tirisfal Glades"]] = true,
			[BZ["Stranglethorn Vale"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["STRANGLETHORN_BARRENS_BOAT"]] = {
		paths = {
			[BZ["Stranglethorn Vale"]] = true,
			[BZ["The Barrens"]] = true,
		},
		type = "Transport",
	}

	zones[transports["WETLANDS_DARKSHORE_BOAT"]] = {
		paths = {
			[BZ["Wetlands"]] = true,
			[BZ["Darkshore"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["WETLANDS_DUSTWALLOW_BOAT"]] = {
		paths = {
			[BZ["Wetlands"]] = true,
			[BZ["Dustwallow Marsh"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	-- TBC
	zones[transports["SILVERMOON_UNDERCITY_TELEPORT"]] = {
		paths = {
			[BZ["Silvermoon City"]] = true,
			[BZ["Undercity"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}
	
	zones[transports["DARKSHORE_AZUREMYST_BOAT"]] = {
		paths = {
			[BZ["Darkshore"]] = true,
			[BZ["Azuremyst Isle"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	zones[transports["DARKSHORE_TELDRASSIL_BOAT"]] = {
		paths = {
			[BZ["Darkshore"]] = true,
			[BZ["Teldrassil"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[transports["DARNASSUS_TELDRASSIL_PORTAL"]] = {
		paths = {
			[BZ["Darnassus"]] = true,
			[BZ["Teldrassil"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}


	zones[transports["SHATTRATH_DARNASSUS_PORTAL"]] = {
		paths = {
			[BZ["Shattrath City"]] = true,
			[BZ["Darnassus"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	zones[transports["SHATTRATH_EXODAR_PORTAL"]] = {
		paths = {
			[BZ["Shattrath City"]] = true,
			[BZ["The Exodar"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	zones[transports["SHATTRATH_IRONFORGE_PORTAL"]] = {
		paths = {
			[BZ["Shattrath City"]] = true,
			[BZ["Ironforge"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	zones[transports["SHATTRATH_ORGRIMMAR_PORTAL"]] = {
		paths = {
			[BZ["Shattrath City"]] = true,
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}
	
	zones[transports["SHATTRATH_SILVERMOON_PORTAL"]] = {
		paths = {
			[BZ["Shattrath City"]] = true,
			[BZ["Silvermoon City"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}
	
	zones[transports["SHATTRATH_STORMWIND_PORTAL"]] = {
		paths = {
			[BZ["Shattrath City"]] = true,
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	zones[transports["SHATTRATH_THUNDERBLUFF_PORTAL"]] = {
		paths = {
			[BZ["Shattrath City"]] = true,
			[BZ["Thunder Bluff"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}
	
	zones[transports["SHATTRATH_UNDERCITY_PORTAL"]] = {
		paths = {
			[BZ["Shattrath City"]] = true,
			[BZ["Undercity"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[transports["THE_DARK_PORTAL"]] = {
		paths = {
			[BZ["Blasted Lands"]] = true,
			[BZ["Hellfire Peninsula"]] = true,
		},
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
			[transports["SHATTRATH_STORMWIND_PORTAL"]] = true,
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
			[transports["SILVERMOON_UNDERCITY_TELEPORT"]] = true,
			[transports["SHATTRATH_UNDERCITY_PORTAL"]] = true,
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
			[transports["SHATTRATH_IRONFORGE_PORTAL"]] = true,			
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
		high = 12,
		continent = Eastern_Kingdoms,
		instances = BZ["Gnomeregan"],
		paths = {
			[BZ["Gnomeregan"]] = true,
			[BZ["Ironforge"]] = true,
			[BZ["Loch Modan"]] = true,
		},
		flightnodes = {
			[6] = true,      -- Ironforge, Dun Morogh (A)
		},		
		faction = "Alliance",
		fishing_low = 1,
		fishing_high = 25,
	}

	zones[BZ["Elwynn Forest"]] = {
		low = 1,
		high = 12,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Westfall"]] = true,
			[BZ["Redridge Mountains"]] = true,
			[BZ["Stormwind City"]] = true,
			[BZ["Duskwood"]] = true,
		},
		flightnodes = {
			[2] = true,      -- Stormwind, Elwynn (A)
		},		
		faction = "Alliance",
		fishing_low = 1,
		fishing_high = 25,
	}

	zones[BZ["Tirisfal Glades"]] = {
		low = 1,
		high = 12,
		continent = Eastern_Kingdoms,
		instances = BZ["Scarlet Monastery"],
		paths = {
			[BZ["Western Plaguelands"]] = true,
			[BZ["Undercity"]] = true,
			[BZ["Scarlet Monastery"]] = true,
			[transports["ORGRIMMAR_UNDERCITY_ZEPPELIN"]] = true,
			[transports["UNDERCITY_GROMGOL_ZEPPELIN"]] = true,
			[BZ["Silverpine Forest"]] = true,
		},
		flightnodes = {
			[11] = true,     -- Undercity, Tirisfal (H)
		},		
		faction = "Horde",
		fishing_low = 1,
		fishing_high = 25,
	}

	zones[BZ["Westfall"]] = {
		low = 10,
		high = 20,
		continent = Eastern_Kingdoms,
		instances = BZ["The Deadmines"],
		paths = {
			[BZ["Duskwood"]] = true,
			[BZ["Elwynn Forest"]] = true,
			[BZ["The Deadmines"]] = true,
		},
		flightnodes = {
			[4] = true,      -- Sentinel Hill, Westfall (A)
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
		},
        flightnodes = {
            [10] = true,     -- The Sepulcher, Silverpine Forest (H)
        },
		faction = "Horde",
		fishing_low = 1,
		fishing_high = 75,
	}

	zones[BZ["Redridge Mountains"]] = {
		low = 15,
		high = 25,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Burning Steppes"]] = true,
			[BZ["Elwynn Forest"]] = true,
			[BZ["Duskwood"]] = true,
		},
		flightnodes = {
			[5] = true,      -- Lakeshire, Redridge (A)
		},
		faction = "Alliance",
		fishing_low = 55,
		fishing_high = 150,
	}

	zones[BZ["Duskwood"]] = {
		low = 20,
		high = 30,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Redridge Mountains"]] = true,
			[BZ["Stranglethorn Vale"]] = true,
			[BZ["Westfall"]] = true,
			[BZ["Deadwind Pass"]] = true,
			[BZ["Elwynn Forest"]] = true,
		},
		flightnodes = {
			[12] = true,     -- Darkshire, Duskwood (A)
		},
		faction = "Alliance",
		fishing_low = 55,
		fishing_high = 150,
	}

	zones[BZ["Alterac Mountains"]] = {
		low = 30,
		high = 40,
		continent = Eastern_Kingdoms,
		instances = BZ["Alterac Valley"],
		paths = {
            [BZ["Western Plaguelands"]] = true,
			[BZ["Alterac Valley"]] = true,
			[BZ["Hillsbrad Foothills"]] = true,
		},
		fishing_low = 130,
		fishing_high = 225,
	}

	zones[BZ["Hillsbrad Foothills"]] = {
		low = 20,
		high = 30,
		continent = Eastern_Kingdoms,
		paths = {
            [BZ["Alterac Mountains"]] = true,
			[BZ["Alterac Valley"]] = true,
			[BZ["The Hinterlands"]] = true,
			[BZ["Arathi Highlands"]] = true,
			[BZ["Silverpine Forest"]] = true,
		},
		flightnodes = {
			[13] = true,    -- Tarren Mill, Hillsbrad (H)
			[14] = true,    -- Southshore, Hillsbrad (A)
		},
		fishing_low = 55,
		fishing_high = 150,
	}

	zones[BZ["Wetlands"]] = {
		low = 20,
		high = 30,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Arathi Highlands"]] = true,
			[transports["WETLANDS_DUSTWALLOW_BOAT"]] = true,
			[transports["WETLANDS_DARKSHORE_BOAT"]] = true,
			[BZ["Loch Modan"]] = true,
		},
		flightnodes = {
			[7] = true,      -- Menethil Harbor, Wetlands (A)
		},
		fishing_low = 55,
		fishing_high = 150,
	}

	zones[BZ["Arathi Highlands"]] = {
		low = 30,
		high = 40,
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
		},
		fishing_low = 130,
		fishing_high = 225,
	}

	zones[BZ["Stranglethorn Vale"]] = {
		low = 30,
		high = 45,
		continent = Eastern_Kingdoms,
		instances = BZ["Zul'Gurub"],
		paths = {
			[BZ["Duskwood"]] = true,
			[BZ["Zul'Gurub"]] = true,
			[transports["ORGRIMMAR_GROMGOL_ZEPPELIN"]] = true,
			[transports["UNDERCITY_GROMGOL_ZEPPELIN"]] = true,
			[transports["STRANGLETHORN_BARRENS_BOAT"]] = true,
		},
		flightnodes = {
			[18] = true,     -- Booty Bay, Stranglethorn (H)
			[19] = true,     -- Booty Bay, Stranglethorn (A)
			[20] = true,     -- Grom'gol, Stranglethorn (H)
			[195] = true,    -- Rebel Camp, Stranglethorn Vale (A)			
		},
		fishing_low = 130,
		fishing_high = 225,
	}

	zones[BZ["The Hinterlands"]] = {
		low = 40,
		high = 50,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Hillsbrad Foothills"]] = true,
			[BZ["Western Plaguelands"]] = true,
		},
		flightnodes = {
			[43] = true,     -- Aerie Peak, The Hinterlands (A)
			[76] = true,     -- Revantusk Village, The Hinterlands (H)
		},
		fishing_low = 205,
		fishing_high = 300,
	}

	zones[BZ["Western Plaguelands"]] = {
		low = 50,
		high = 60,
		continent = Eastern_Kingdoms,
		instances = BZ["Scholomance"],
		paths = {
			[BZ["The Hinterlands"]] = true,
			[BZ["Eastern Plaguelands"]] = true,
			[BZ["Tirisfal Glades"]] = true,
			[BZ["Scholomance"]] = true,
			[BZ["Alterac Mountains"]] = true,
		},
		flightnodes = {
			[66] = true,     -- Chillwind Camp, Western Plaguelands (A)
		},
		fishing_low = 205,
		fishing_high = 300,
	}

	zones[BZ["Eastern Plaguelands"]] = {
		low = 55,
		high = 60,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Stratholme"]] = true,
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
		},
		type = "PvP Zone",
		fishing_low = 330,
		fishing_high = 425,
	}

	zones[BZ["Badlands"]] = {
		low = 35,
		high = 45,
		continent = Eastern_Kingdoms,
		instances = BZ["Uldaman"],
		paths = {
			[BZ["Uldaman"]] = true,
			[BZ["Searing Gorge"]] = true,
			[BZ["Loch Modan"]] = true,
		},
		flightnodes = {
			[21] = true,     -- Kargath, Badlands (H)
		},
	}

	zones[BZ["Searing Gorge"]] = {
		low = 43,
		high = 50,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Blackrock Depths"]] = true,
			[BZ["Blackwing Lair"]] = true,
			[BZ["Molten Core"]] = true,
			[BZ["Blackrock Spire"]] = true,
		},
		paths = {
			[BZ["Blackrock Mountain"]] = true,
			[BZ["Badlands"]] = true,
			[BZ["Loch Modan"]] = not isHorde and true or nil,
		},
		flightnodes = {
			[75] = true,     -- Thorium Point, Searing Gorge (H)
			[74] = true,     -- Thorium Point, Searing Gorge (A)
		},
		complexes = {
			[BZ["Blackrock Mountain"]] = true,
		},
	}

	zones[BZ["Burning Steppes"]] = {
		low = 50,
		high = 60,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Blackrock Depths"]] = true,
			[BZ["Blackwing Lair"]] = true,
			[BZ["Molten Core"]] = true,
			[BZ["Blackrock Spire"]] = true,
		},
		paths = {
			[BZ["Blackrock Mountain"]] = true,
			[BZ["Redridge Mountains"]] = true,
		},
		flightnodes = {
			[70] = true,     -- Flame Crest, Burning Steppes (H)
			[71] = true,     -- Morgan's Vigil, Burning Steppes (A)
		},
		complexes = {
			[BZ["Blackrock Mountain"]] = true,
		},
		fishing_low = 330,
		fishing_high = 425,
	}

	zones[BZ["Swamp of Sorrows"]] = {
		low = 35,
		high = 45,
		continent = Eastern_Kingdoms,
		instances = BZ["The Temple of Atal'Hakkar"],
		paths = {
			[BZ["Blasted Lands"]] = true,
			[BZ["Deadwind Pass"]] = true,
			[BZ["The Temple of Atal'Hakkar"]] = true,
		},
		flightnodes = {
			[56] = true,     -- Stonard, Swamp of Sorrows (H)
		},
		fishing_low = 130,
		fishing_high = 225,
	}

	zones[BZ["Blasted Lands"]] = {
		low = 47,
		high = 55,
		continent = Eastern_Kingdoms,
		paths = {
			[transports["THE_DARK_PORTAL"]] = true,	
			[BZ["Swamp of Sorrows"]] = true,
		},
		flightnodes = {
			[45] = true,     -- Nethergarde Keep, Blasted Lands (A)
		},
	}

	zones[BZ["Deadwind Pass"]] = {
		low = 55,
		high = 60,
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
			[transports["ORGRIMMAR_GROMGOL_ZEPPELIN"]] = true,
			[transports["ORGRIMMAR_UNDERCITY_ZEPPELIN"]] = true,
			[transports["SHATTRATH_ORGRIMMAR_PORTAL"]] = true,			
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
			[transports["SHATTRATH_THUNDERBLUFF_PORTAL"]] = true,			
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
			[transports["DARNASSUS_TELDRASSIL_PORTAL"]] = true,
			[transports["SHATTRATH_DARNASSUS_PORTAL"]] = true,
		},
		faction = "Alliance",
		type = "City",
		fishing_low = 1,
		fishing_high = 75,
	}

	zones[BZ["Durotar"]] = {
		low = 1,
		high = 12,
		continent = Kalimdor,
		paths = {
			[BZ["The Barrens"]] = true,
			[BZ["Orgrimmar"]] = true,
		},
		flightnodes = {
			[23] = true,     -- Orgrimmar, Durotar (H)
		},		
		faction = "Horde",
		fishing_low = 1,
		fishing_high = 25,
	}

	zones[BZ["Mulgore"]] = {
		low = 1,
		high = 12,
		continent = Kalimdor,
		paths = {
			[BZ["Thunder Bluff"]] = true,
			[BZ["The Barrens"]] = true,
		},
		flightnodes = {
			[22] = true,     -- Thunder Bluff, Mulgore (H)
		},		
		faction = "Horde",
		fishing_low = 1,
		fishing_high = 25,
	}

	zones[BZ["Teldrassil"]] = {
		low = 1,
		high = 12,
		continent = Kalimdor,
		paths = {
			[transports["DARNASSUS_TELDRASSIL_PORTAL"]] = true,
			[transports["DARKSHORE_TELDRASSIL_BOAT"]] = true,
		},
		flightnodes = {
			[27] = true,     -- Rut'theran Village, Teldrassil (A)
		},
		faction = "Alliance",
		fishing_low = 1,
		fishing_high = 25,
	}

	zones[BZ["Azshara"]] = {
		low = 48,
		high = 55,
		continent = Kalimdor,
		paths = {
			[BZ["Ashenvale"]] = true,
		},
		flightnodes = {
			[44] = true, -- Valormok, Azshara (H)
			[64] = true, -- Talrendis Point, Azshara (A)
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
			[transports["WETLANDS_DARKSHORE_BOAT"]] = true,
			[transports["DARKSHORE_TELDRASSIL_BOAT"]] = true,
			[transports["DARKSHORE_AZUREMYST_BOAT"]] = true,
		},
		flightnodes = {
			[26] = true,     -- Auberdine, Darkshore (A)
		},
		faction = "Alliance",
		fishing_low = 1,
		fishing_high = 75,
	}

	zones[BZ["The Barrens"]] = {
		low = 10,
		high = 25,
		continent = Kalimdor,
		instances = {
			[BZ["Wailing Caverns"]] = true,
			[BZ["Warsong Gulch"]] = isHorde and true or nil,
			[BZ["Razorfen Kraul"]] = true,
			[BZ["Razorfen Downs"]] = true,
		},
		paths = {
			[BZ["Ashenvale"]] = true,
			[BZ["Durotar"]] = true,
			[BZ["Orgrimmar"]] = true,
			[BZ["Thousand Needles"]] = true,
			[BZ["Stonetalon Mountains"]] = true,
			[BZ["Mulgore"]] = true,
			[BZ["Wailing Caverns"]] = true,
			[BZ["Warsong Gulch"]] = isHorde and true or nil,
			[BZ["Razorfen Kraul"]] = true,
			[BZ["Razorfen Downs"]] = true,
			[BZ["Dustwallow Marsh"]] = true,
			[transports["STRANGLETHORN_BARRENS_BOAT"]] = true,
		},
		flightnodes = {
			[80] = true,    -- Ratchet, The Barrens (N)
			[25] = true,    -- The Crossroads, The Barrens (H)
			[77] = true,    -- Camp Taurajo, The Barrens (H)
		},
		fishing_low = 1,
		fishing_high = 75,
	}

	zones[BZ["Ashenvale"]] = {
		low = 15,
		high = 30,
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
		},
		fishing_low = 55,
		fishing_high = 150,
	}

	zones[BZ["Stonetalon Mountains"]] = {
		low = 15,
		high = 27,
		continent = Kalimdor,
		paths = {
			[BZ["Desolace"]] = true,
			[BZ["The Barrens"]] = true,
			[BZ["Ashenvale"]] = true,
		},
		flightnodes = {
			[33] = true,     -- Stonetalon Peak, Stonetalon Mountains (A)
			[29] = true,     -- Sun Rock Retreat, Stonetalon Mountains (H)
		},
		fishing_low = 55,
		fishing_high = 150,
	}

	zones[BZ["Desolace"]] = {
		low = 30,
		high = 40,
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
		},
		fishing_low = 130,
		fishing_high = 225,
	}

	zones[BZ["Dustwallow Marsh"]] = {
		low = 35,
		high = 45,
		continent = Kalimdor,
		instances = BZ["Onyxia's Lair"],
		paths = {
			[BZ["Onyxia's Lair"]] = true,
			[BZ["The Barrens"]] = true,
			[transports["WETLANDS_DUSTWALLOW_BOAT"]] = true,
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
		low = 40,
		high = 50,
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
		},
		complexes = {
			[BZ["Dire Maul"]] = true,
		},
		fishing_low = 205,
		fishing_high = 300,
	}

	zones[BZ["Thousand Needles"]] = {
		low = 25,
		high = 35,
		continent = Kalimdor,
		paths = {
			[BZ["Feralas"]] = true,
			[BZ["The Barrens"]] = true,
			[BZ["Tanaris"]] = true,
		},
		flightnodes = {
			[30] = true,     -- Freewind Post, Thousand Needles (H)
		},
		fishing_low = 130,
		fishing_high = 225,
	}

	zones[BZ["Felwood"]] = {
		low = 48,
		high = 55,
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
		},
		fishing_low = 205,
		fishing_high = 300,
	}

	zones[BZ["Tanaris"]] = {
		low = 40,
		high = 50,
		continent = Kalimdor,
		instances = 
		{
			[BZ["Zul'Farrak"]] = true,
			[BZ["Old Hillsbrad Foothills"]] = true,
			[BZ["The Black Morass"]] = true,
			[BZ["Hyjal Summit"]] = true,
		},
		paths = {
			[BZ["Thousand Needles"]] = true,
			[BZ["Un'Goro Crater"]] = true,
			[BZ["Zul'Farrak"]] = true,
			[BZ["Caverns of Time"]] = true,
		},
		flightnodes = {
			[39] = true,     -- Gadgetzan, Tanaris (A)
			[40] = true,     -- Gadgetzan, Tanaris (H)
		},
		complexes = {
			[BZ["Caverns of Time"]] = true,
		},		
		fishing_low = 205,
		fishing_high = 300,
	}

	zones[BZ["Un'Goro Crater"]] = {
		low = 48,
		high = 55,
		continent = Kalimdor,
		paths = {
			[BZ["Silithus"]] = true,
			[BZ["Tanaris"]] = true,
		},
		flightnodes = {
			[79] = true,     -- Marshal's Refuge, Un'Goro Crater (N)
		},
		fishing_low = 205,
		fishing_high = 300,
	}

	zones[BZ["Winterspring"]] = {
		low = 55,
		high = 60,
		continent = Kalimdor,
		paths = {
			[BZ["Felwood"]] = true,
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
		low = 1,
		high = 1,
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
			[transports["SHATTRATH_SILVERMOON_PORTAL"]] = true,
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
			[transports["SHATTRATH_EXODAR_PORTAL"]] = true,
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
			[transports["DARKSHORE_AZUREMYST_BOAT"]] = true,
		},
		flightnodes = {
			[94] = true,    -- The Exodar (A)
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
			[transports["THE_DARK_PORTAL"]] = true,
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
			[124] = true,    -- Wildhammer Stronghold, Shadowmoon Valley (A)
			[123] = true,    -- Shadowmoon Village, Shadowmoon Valley (H)
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
--			[BZ["The Eye"]] = true,
		},
		paths = {
			[BZ["Blade's Edge Mountains"]] = true,
			[BZ["Tempest Keep"]] = true,
		},
		complexes = {
			[BZ["Tempest Keep"]] = true,
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
			[BZ["Magisters' Terrace"]] = true,
			[BZ["Sunwell Plateau"]] = true,
		},
		paths = {
			[BZ["Magisters' Terrace"]] = true,
			[BZ["Sunwell Plateau"]] = true,
		},		
--		flightnodes = {
--			[00] = true,    -- TODO
--		},
		fishing_low = 355,
		fishing_high = 450,
	}





	-- Classic dungeons ------------------------

	zones[BZ["Ragefire Chasm"]] = {
		low = 13,
		high = 18,
		continent = Kalimdor,
		paths = BZ["Orgrimmar"],
		groupMinSize = 5,
		groupMaxSize = 10,
		faction = "Horde",
		type = "Instance",
		entrancePortal = { BZ["Orgrimmar"], 52.8, 49 },
	}

	zones[BZ["The Deadmines"]] = {
		low = 17,
		high = 26,
		continent = Eastern_Kingdoms,
		paths = BZ["Westfall"],
		groupMinSize = 5,
		groupMaxSize = 10,
		faction = "Alliance",
		type = "Instance",
		fishing_low = 1,
		fishing_high = 75,
		entrancePortal = { BZ["Westfall"], 42.6, 72.2 },
	}

	zones[BZ["Shadowfang Keep"]] = {
		low = 22,
		high = 30,
		continent = Eastern_Kingdoms,
		paths = BZ["Silverpine Forest"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		entrancePortal = { BZ["Silverpine Forest"], 44.80, 67.83 },
	}

	zones[BZ["Wailing Caverns"]] = {
		low = 17,
		high = 24,
		continent = Kalimdor,
		paths = BZ["The Barrens"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		fishing_low = 1,
		fishing_high = 75,
		entrancePortal = { BZ["The Barrens"], 42.1, 66.5 },
	}

	zones[BZ["Blackfathom Deeps"]] = {
		low = 24,
		high = 32,
		continent = Kalimdor,
		paths = BZ["Ashenvale"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		fishing_low = 1,
		fishing_high = 75,
		entrancePortal = { BZ["Ashenvale"], 14.6, 15.3 },
	}

	zones[BZ["The Stockade"]] = {
		low = 24,
		high = 32,
		continent = Eastern_Kingdoms,
		paths = BZ["Stormwind City"],
		groupMinSize = 5,
		groupMaxSize = 10,
		faction = "Alliance",
		type = "Instance",
		entrancePortal = { BZ["Stormwind City"], 39.85, 54.30 },
	}

	zones[BZ["Gnomeregan"]] = {
		low = 29,
		high = 38,
		continent = Eastern_Kingdoms,
		paths = BZ["Dun Morogh"],
		groupMinSize = 5,
		groupMaxSize = 10,
		faction = "Alliance",
		type = "Instance",
		entrancePortal = { BZ["Dun Morogh"], 24, 38.9 },
	}

	-- Consists of Graveyard, Library, Armory and Cathedral
	zones[BZ["Scarlet Monastery"]] = {
		low = 34,
		high = 45,
		continent = Eastern_Kingdoms,
		paths = BZ["Tirisfal Glades"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		fishing_low = 130,
		fishing_high = 225,
		entrancePortal = { BZ["Tirisfal Glades"], 85.3, 32.1 },
	}

	zones[BZ["Razorfen Kraul"]] = {
		low = 29,
		high = 38,
		continent = Kalimdor,
		paths = BZ["The Barrens"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		entrancePortal = { BZ["The Barrens"], 40.8, 94.5 },
	}

	zones[BZ["Razorfen Downs"]] = {
		low = 37,
		high = 46,
		continent = Kalimdor,
		paths = BZ["The Barrens"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		entrancePortal = { BZ["The Barrens"], 47.5, 23.7 },
	}

	-- consists of The Wicked Grotto, Foulspore Cavern and Earth Song Falls
	zones[BZ["Maraudon"]] = {
		low = 46,
		high = 55,
		continent = Kalimdor,
		paths = BZ["Desolace"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		fishing_low = 205,
		fishing_high = 300,
		entrancePortal = { BZ["Desolace"], 29, 62.4 },
	}

	zones[BZ["Uldaman"]] = {
		low = 41,
		high = 51,
		continent = Eastern_Kingdoms,
		paths = BZ["Badlands"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		entrancePortal = { BZ["Badlands"], 42.4, 18.6 },
	}

	-- a.k.a. Warpwood Quarter
	zones[BZ["Dire Maul - East"]] = {
		low = 55,
		high = 60,
		continent = Kalimdor,
		paths = BZ["Dire Maul"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		complex = BZ["Dire Maul"],
		entrancePortal = { BZ["Feralas"], 66.7, 34.8 },
	}

	-- a.k.a. Capital Gardens
	zones[BZ["Dire Maul - West"]] = {
		low = 55,
		high = 60,
		continent = Kalimdor,
		paths = BZ["Dire Maul"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		complex = BZ["Dire Maul"],
		entrancePortal = { BZ["Feralas"], 60.3, 30.6 },
	}

	-- a.k.a. Gordok Commons
	zones[BZ["Dire Maul - North"]] = {
		low = 55,
		high = 60,
		continent = Kalimdor,
		paths = BZ["Dire Maul"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		complex = BZ["Dire Maul"],
		entrancePortal = { BZ["Feralas"], 62.5, 24.9 },
	}

	zones[BZ["Scholomance"]] = {
		low = 58,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = BZ["Western Plaguelands"],
		groupSize = 5,
		type = "Instance",
		fishing_low = 330,
		fishing_high = 425,
		entrancePortal = { BZ["Western Plaguelands"], 69.4, 72.8 },
	}

	-- consists of Main Gate and Service Entrance
	zones[BZ["Stratholme"]] = {
		low = 58,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = BZ["Eastern Plaguelands"],
		groupSize = 5,
		type = "Instance",
		fishing_low = 330,
		fishing_high = 425,
		entrancePortal = { BZ["Eastern Plaguelands"], 30.8, 14.4 },
	}

	zones[BZ["Zul'Farrak"]] = {
		low = 42,
		high = 46,
		continent = Kalimdor,
		paths = BZ["Tanaris"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		entrancePortal = { BZ["Tanaris"], 36, 11.7 },
	}

	-- consists of Detention Block and Upper City
	zones[BZ["Blackrock Depths"]] = {
		low = 52,
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
		high = 56,
		continent = Eastern_Kingdoms,
		paths = BZ["Swamp of Sorrows"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		fishing_low = 205,
		fishing_high = 300,
		entrancePortal = { BZ["Swamp of Sorrows"], 70, 54 },
	}

	zones[BZ["Blackrock Spire"]] = {
		low = 55,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Blackrock Mountain"]] = true,
			[BZ["Blackwing Lair"]] = true,
		},
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		complex = BZ["Blackrock Mountain"],
		entrancePortal = { BZ["Burning Steppes"], 29.7, 37.5 },
	}


	



	-- The Burning Crusade Dungeons --------------------------------------


	-- a.k.a The Escape From Durnholde
	zones[BZ["Old Hillsbrad Foothills"]] = {
		low = 66,
		high = 70,
		continent = Kalimdor,
		paths = {
			[BZ["Caverns of Time"]] = true,
		},
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Tanaris"], 66.2, 49.3 },
	}

	-- a.k.a. Opening of the Dark Portal
	zones[BZ["The Black Morass"]] = {
		low = 67,
		high = 70,
		continent = Kalimdor,
		paths = {
			[BZ["Caverns of Time"]] = true,
		},
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Tanaris"], 66.2, 49.3 },
	}

	zones[BZ["Karazhan"]] = {
		low = 70,
		high = 70,
		continent = Eastern_Kingdoms,
		paths = BZ["Deadwind Pass"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		entrancePortal = { BZ["Deadwind Pass"], 40.9, 73.2 },
	}
	
	zones[BZ["Zul'Aman"]] = {
		low = 70,
		high = 70,
		continent = Eastern_Kingdoms,
		paths = BZ["Ghostlands"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		entrancePortal = { BZ["Ghostlands"], 77.7, 63.2 },
	}
	
	-- ---

	zones[BZ["Hellfire Ramparts"]] = {
		low = 60,
		high = 62,
		continent = Outland,
		paths = BZ["Hellfire Citadel"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		complex = BZ["Hellfire Citadel"],
		entrancePortal = { BZ["Hellfire Peninsula"], 47.8, 53.3 },
	}
	
	zones[BZ["The Blood Furnace"]] = {
		low = 61,
		high = 63,
		continent = Outland,
		paths = BZ["Hellfire Citadel"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		complex = BZ["Hellfire Citadel"],
		entrancePortal = { BZ["Hellfire Peninsula"], 46.1, 51.8 },
	}
	
	zones[BZ["The Shattered Halls"]] = {
		low = 70,
		high = 70,
		continent = Outland,
		paths = BZ["Hellfire Citadel"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		complex = BZ["Hellfire Citadel"],
		entrancePortal = { BZ["Hellfire Peninsula"], 47.8, 51.1 },
	}
	
	-- ---
	
	zones[BZ["The Slave Pens"]] = {
		low = 62,
		high = 64,
		continent = Outland,
		paths = BZ["Coilfang Reservoir"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		complex = BZ["Coilfang Reservoir"],
		entrancePortal = { BZ["Zangarmarsh"], 49.0, 36.0 },
	}
	
	zones[BZ["The Underbog"]] = {
		low = 63,
		high = 65,
		continent = Outland,
		paths = BZ["Coilfang Reservoir"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		complex = BZ["Coilfang Reservoir"],
		entrancePortal = { BZ["Zangarmarsh"], 54.0, 43.0 },
	}
	
	zones[BZ["The Steamvault"]] = {
		low = 70,
		high = 70,
		continent = Outland,
		paths = BZ["Coilfang Reservoir"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		complex = BZ["Coilfang Reservoir"],
		entrancePortal = { BZ["Zangarmarsh"], 50.0, 33.0 },
	}
	
	-- ---
	
	zones[BZ["Auchenai Crypts"]] = {
		low = 65,
		high = 67,
		continent = Outland,
		paths = BZ["Auchindoun"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		complex = BZ["Auchindoun"],
		entrancePortal = { BZ["Terokkar Forest"], 35, 65.8 },
	}
	
	zones[BZ["Shadow Labyrinth"]] = {
		low = 70,
		high = 72,
		continent = Outland,
		paths = BZ["Auchindoun"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		complex = BZ["Auchindoun"],
		entrancePortal = { BZ["Terokkar Forest"], 39.6, 65.5 },
	}
	
	zones[BZ["Sethekk Halls"]] = {
		low = 67,
		high = 69,
		continent = Outland,
		paths = BZ["Auchindoun"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		complex = BZ["Auchindoun"],
		entrancePortal = { BZ["Terokkar Forest"], 43.4, 65.4 },
	}
	
	zones[BZ["Mana-Tombs"]] = {
		low = 64,
		high = 66,
		continent = Outland,
		paths = BZ["Auchindoun"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		complex = BZ["Auchindoun"],
		entrancePortal = { BZ["Terokkar Forest"], 39.2, 58.5 },
	}	
	
	-- ---

	zones[BZ["The Mechanar"]] = {
		low = 69,
		high = 70,
		continent = Outland,
		paths = BZ["Tempest Keep"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		complex = BZ["Tempest Keep"],
		entrancePortal = { BZ["Netherstorm"], 76.5, 65.1 },
	}
	
	zones[BZ["The Botanica"]] = {
		low = 70,
		high = 70,
		continent = Outland,
		paths = BZ["Tempest Keep"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		complex = BZ["Tempest Keep"],
		entrancePortal = { BZ["Netherstorm"], 76.5, 65.1 },
	}
	
	zones[BZ["The Arcatraz"]] = {
		low = 70,
		high = 70,
		continent = Outland,
		paths = BZ["Tempest Keep"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		complex = BZ["Tempest Keep"],
		entrancePortal = { BZ["Netherstorm"], 76.5, 65.1 },
	}

	-- TBC 2.4 dungeon
	zones[BZ["Magisters' Terrace"]] = {
		low = 70,
		high = 70,
		continent = Eastern_Kingdoms,
		paths = BZ["Isle of Quel'Danas"],
		groupMinSize = 5,
		groupMaxSize = 10,
		type = "Instance",
		entrancePortal = { BZ["Isle of Quel'Danas"], 61.3, 30.9 },
	}	








	-- Classic Raids -----------------------------

	zones[BZ["Zul'Gurub"]] = {
		low = 60,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = BZ["Stranglethorn Vale"],
		groupSize = 20,
		type = "Instance",
		fishing_low = 205,
		fishing_high = 330,
		entrancePortal = { BZ["Stranglethorn Vale"], 52.2, 17.1 },
	}

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
		low = 60,
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
		low = 60,
		high = 60,
		continent = Kalimdor,
		paths = BZ["Dustwallow Marsh"],
		groupSize = 40,
		type = "Instance",
		entrancePortal = { BZ["Dustwallow Marsh"], 52, 76 },
	}

	zones[BZ["Naxxramas"]] = {
		low = 60,
		high = 60,
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
	
--	zones[BZ["The Eye"]] = {
--		low = 70,
--		high = 70,
--		continent = Outland,
----		paths = BZ["Tempest Keep"],
--		paths = BZ["Netherstorm"],		
--		groupSize = 25,
--		type = "Instance",
----		complex = BZ["Tempest Keep"],
--		entrancePortal = { BZ["Netherstorm"], 76.5, 65.1 },
--	}	
	
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







	-- Classic Battlegrounds --

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
		paths = isHorde and BZ["The Barrens"] or BZ["Ashenvale"],
		groupSize = 10,
		type = "Battleground",
		texture = "WarsongGulch",
	}

	zones[BZ["Alterac Valley"]] = {
		low = 51,
		high = MAX_PLAYER_LEVEL,
		continent = Eastern_Kingdoms,
		paths = BZ["Hillsbrad Foothills"],
		groupSize = 40,
		type = "Battleground",
		texture = "AlteracValley",
	}

	-- The Burning Crusade Battlegrounds --------------------------------------
	
	zones[BZ["Eye of the Storm"]] = {
		low = 61,
		high = 70,
		continent = Outland,
		paths = BZ["Netherstorm"],
		groupSize = 25,
		type = "Battleground",
		texture = "NetherstormArena",
	}
	
	
	
	-- The Burning Crusade Arenas --------------------------------------
	
	zones[BZ["Blade's Edge Arena"]] = {
		low = 70,
		high = 70,
		continent = Outland,
		paths = BZ["Blade's Edge Mountains"],
		type = "Arena",
	}

	zones[BZ["Nagrand Arena"]] = {
		low = 70,
		high = 70,
		continent = Outland,
		paths = BZ["Nagrand"],
		type = "Arena",
	}
	
	zones[BZ["Ruins of Lordaeron"]] = {
		low = 70,
		high = 70,
		continent = Kalimdor,
		paths = BZ["Undercity"],
		type = "Arena",
	}
	





	-- Classic Complexes ---------------------------------------------

	zones[BZ["Dire Maul"]] = {
		low = 36,
		high = 60,
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
		low = 52,
		high = 60,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Blackrock Depths"]] = true,
			[BZ["Blackwing Lair"]] = true,
			[BZ["Molten Core"]] = true,
			[BZ["Blackrock Spire"]] = true,
		},
		paths = {
			[BZ["Burning Steppes"]] = true,
			[BZ["Searing Gorge"]] = true,
			[BZ["Blackwing Lair"]] = true,
			[BZ["Molten Core"]] = true,
			[BZ["Blackrock Depths"]] = true,
			[BZ["Blackrock Spire"]] = true,
		},
		type = "Complex",
		fishing_high = 1, -- lava
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
		low = 66,
		high = 70,
		continent = Kalimdor,
		instances = {
			[BZ["Old Hillsbrad Foothills"]] = true,
			[BZ["The Black Morass"]] = true,
			[BZ["Hyjal Summit"]] = true,
		},
		paths = {
			[BZ["Tanaris"]] = true,
			[BZ["Old Hillsbrad Foothills"]] = true,
			[BZ["The Black Morass"]] = true,
			[BZ["Hyjal Summit"]] = true,
		},
		type = "Complex",
	}
	

	-- No UiMapID available?
	zones[BZ["Hellfire Citadel"]] = {
		low = 60,
		high = 70,
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
		low = 62,
		high = 70,
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
		low = 64,
		high = 70,
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
	
	-- No UiMapID available?
	zones[BZ["Tempest Keep"]] = {
		low = 67,
		high = 70,
		continent = Outland,
		instances = {
			[BZ["The Mechanar"]] = true,
--			[BZ["The Eye"]] = true,
			[BZ["The Botanica"]] = true,
			[BZ["The Arcatraz"]] = true,
		},
		paths = {
			[BZ["Netherstorm"]] = true,
			[BZ["The Mechanar"]] = true,
--			[BZ["The Eye"]] = true,
			[BZ["The Botanica"]] = true,
			[BZ["The Arcatraz"]] = true,
		},
		type = "Complex",	
	}	
	

	







--------------------------------------------------------------------------------------------------------
--                                       HERB TRANSLATIONS                                            --
--------------------------------------------------------------------------------------------------------


-- Thanks to GatherMate2 Classic
local herbTranslations = {
	koKR = {
		["Peacebloom"] = "평온초",
		["Silverleaf"] = "은엽수 덤불",
		["Earthroot"] = "뱀뿌리",
		["Mageroyal"] = "마법초",
		["Briarthorn"] = "찔레가시",
		["Stranglekelp"] = "갈래물풀",
		["Bruiseweed"] = "생채기풀",
		["Wild Steelbloom"] = "야생 철쭉",
		["Grave Moss"] = "무덤이끼",
		["Kingsblood"] = "왕꽃잎풀",
		["Liferoot"] = "생명의 뿌리",
		["Fadeleaf"] = "미명초잎",
		["Goldthorn"] = "황금가시",
		["Khadgar's Whisker"] = "카드가의 수염",
		["Wintersbite"] = "겨울서리풀",
		["Firebloom"] = "화염초",
		["Purple Lotus"] = "보라 연꽃",
		["Arthas' Tears"] = "아서스의 눈물",
		["Sungrass"] = "태양풀",
		["Blindweed"] = "실명초",
		["Ghost Mushroom"] = "유령버섯",
		["Gromsblood"] = "그롬의 피",
		["Golden Sansam"] = "황금 산삼",
		["Dreamfoil"] = "꿈풀",
		["Mountain Silversage"] = "은초롱이",
		["Plaguebloom"] = "역병초",
		["Icecap"] = "얼음송이",
		["Black Lotus"] = "검은 연꽃",
		["Felweed"] = "지옥풀",
		["Dreaming Glory"] = "꿈초롱이",
		["Terocone"] = "테로열매",
		["Ragveil"] = "가림막이버섯",
		["Ancient Lichen"] = "고대 이끼",
		["Netherbloom"] = "황천꽃",
		["Nightmare Vine"] = "악몽의 덩굴",
		["Mana Thistle"] = "마나 엉겅퀴",		
	},
	deDE = {
		["Peacebloom"] = "Friedensblume",
		["Silverleaf"] = "Silberblatt",
		["Earthroot"] = "Erdwurzel",
		["Mageroyal"] = "Maguskönigskraut",
		["Briarthorn"] = "Wilddornrose",
		["Stranglekelp"] = "Würgetang",
		["Bruiseweed"] = "Beulengras",
		["Wild Steelbloom"] = "Wildstahlblume",
		["Grave Moss"] = "Grabmoos",
		["Kingsblood"] = "Königsblut",
		["Liferoot"] = "Lebenswurz",
		["Fadeleaf"] = "Blassblatt",
		["Goldthorn"] = "Golddorn",
		["Khadgar's Whisker"] = "Khadgars Schnurrbart",
		["Wintersbite"] = "Winterbiss",
		["Firebloom"] = "Feuerblüte",
		["Purple Lotus"] = "Lila Lotus",
		["Arthas' Tears"] = "Arthas’ Tränen",
		["Sungrass"] = "Sonnengras",
		["Blindweed"] = "Blindkraut",
		["Ghost Mushroom"] = "Geisterpilz",
		["Gromsblood"] = "Gromsblut",
		["Golden Sansam"] = "Goldener Sansam",
		["Dreamfoil"] = "Traumblatt",
		["Mountain Silversage"] = "Bergsilbersalbei",
		["Plaguebloom"] = "Pestblüte",
		["Icecap"] = "Eiskappe",
		["Black Lotus"] = "Schwarzer Lotus",
		["Felweed"] = "Teufelsgras",
		["Dreaming Glory"] = "Traumwinde",
		["Terocone"] = "Terozapfen",
		["Ragveil"] = "Zottelkappe",
		["Ancient Lichen"] = "Urflechte",
		["Netherbloom"] = "Netherblüte",
		["Nightmare Vine"] = "Alptraumranke",
		["Mana Thistle"] = "Manadistel",		
	},
	frFR = {
		["Peacebloom"] = "Pacifique",
		["Silverleaf"] = "Feuillargent",
		["Earthroot"] = "Terrestrine",
		["Mageroyal"] = "Mage royal",
		["Briarthorn"] = "Eglantine",
		["Stranglekelp"] = "Etouffante",
		["Bruiseweed"] = "Doulourante",
		["Wild Steelbloom"] = "Aciérite sauvage",
		["Grave Moss"] = "Tombeline",
		["Kingsblood"] = "Sang-royal",
		["Liferoot"] = "Vietérule",
		["Fadeleaf"] = "Pâlerette",
		["Goldthorn"] = "Dorépine",
		["Khadgar's Whisker"] = "Moustache de Khadgar",
		["Wintersbite"] = "Hivernale",
		["Firebloom"] = "Fleur de feu",
		["Purple Lotus"] = "Lotus pourpre",
		["Arthas' Tears"] = "Larmes d'Arthas",
		["Sungrass"] = "Soleillette",
		["Blindweed"] = "Aveuglette",
		["Ghost Mushroom"] = "Champignon fantôme",
		["Gromsblood"] = "Gromsang",
		["Golden Sansam"] = "Sansam doré",
		["Dreamfoil"] = "Feuillerêve",
		["Mountain Silversage"] = "Sauge-argent des montagnes",
		["Plaguebloom"] = "Chagrinelle",
		["Icecap"] = "Calot de glace",
		["Black Lotus"] = "Lotus noir",
		["Felweed"] = "Gangrelette",
		["Dreaming Glory"] = "Glaurier",
		["Terocone"] = "Terocône",
		["Ragveil"] = "Voile-misère",
		["Ancient Lichen"] = "Lichen ancien",
		["Netherbloom"] = "Néantine",
		["Nightmare Vine"] = "Cauchemardelle",
		["Mana Thistle"] = "Chardon de mana",		
	},
	esES = {
		["Peacebloom"] = "Flor de paz",
		["Silverleaf"] = "Hojaplata",
		["Earthroot"] = "Raíz de tierra",
		["Mageroyal"] = "Marregal",
		["Briarthorn"] = "Brezospina",
		["Stranglekelp"] = "Alga estranguladora",
		["Bruiseweed"] = "Hierba cardenal",
		["Wild Steelbloom"] = "Acérita salvaje",
		["Grave Moss"] = "Musgo de tumba",
		["Kingsblood"] = "Sangrerregia",
		["Liferoot"] = "Vidarraíz",
		["Fadeleaf"] = "Pálida",
		["Goldthorn"] = "Espina de oro",
		["Khadgar's Whisker"] = "Mostacho de Khadgar",
		["Wintersbite"] = "Ivernalia",
		["Firebloom"] = "Flor de fuego",
		["Purple Lotus"] = "Loto cárdeno",
		["Arthas' Tears"] = "Lágrimas de Arthas",
		["Sungrass"] = "Solea",
		["Blindweed"] = "Carolina",
		["Ghost Mushroom"] = "Champiñón fantasma",
		["Gromsblood"] = "Gromsanguina",
		["Golden Sansam"] = "Sansam dorado",
		["Dreamfoil"] = "Hojasueño",
		["Mountain Silversage"] = "Salviargenta de montaña",
		["Plaguebloom"] = "Flor de peste",
		["Icecap"] = "Setelo",
		["Black Lotus"] = "Loto negro",
		["Felweed"] = "Hierba vil",
		["Dreaming Glory"] = "Gloria de ensueño",
		["Terocone"] = "Teropiña",
		["Ragveil"] = "Velada",
		["Ancient Lichen"] = "Liquen Antiguo",
		["Netherbloom"] = "Flor abisal",
		["Nightmare Vine"] = "Vid pesadilla",
		["Mana Thistle"] = "Cardo de maná",		
	},
	zhTW = {
		["Peacebloom"] = "寧神花",
		["Silverleaf"] = "銀葉草",
		["Earthroot"] = "地根草",
		["Mageroyal"] = "魔皇草",
		["Briarthorn"] = "石南草",
		["Stranglekelp"] = "荊棘藻",
		["Bruiseweed"] = "跌打草",
		["Wild Steelbloom"] = "野鋼花",
		["Grave Moss"] = "墓地苔",
		["Kingsblood"] = "皇血草",
		["Liferoot"] = "活根草",
		["Fadeleaf"] = "枯葉草",
		["Goldthorn"] = "金棘草",
		["Khadgar's Whisker"] = "卡德加的鬍鬚",
		["Wintersbite"] = "冬刺草",
		["Firebloom"] = "火焰花",
		["Purple Lotus"] = "紫蓮花",
		["Arthas' Tears"] = "阿薩斯之淚",
		["Sungrass"] = "太陽草",
		["Blindweed"] = "盲目草",
		["Ghost Mushroom"] = "鬼魂菇",
		["Gromsblood"] = "格羅姆之血",
		["Golden Sansam"] = "黃金蔘",
		["Dreamfoil"] = "夢葉草",
		["Mountain Silversage"] = "山鼠草",
		["Plaguebloom"] = "瘟疫花",
		["Icecap"] = "冰蓋草",
		["Black Lotus"] = "黑蓮花",
		["Felweed"] = "魔獄草",
		["Dreaming Glory"] = "譽夢草",
		["Terocone"] = "泰魯草",
		["Ragveil"] = "拉格維花",
		["Ancient Lichen"] = "古老青苔",
		["Netherbloom"] = "虛空花",
		["Nightmare Vine"] = "夢魘根",
		["Mana Thistle"] = "法力薊",		
	},
	zhCN = {
		["Peacebloom"] = "宁神花",
		["Silverleaf"] = "银叶草",
		["Earthroot"] = "地根草",
		["Mageroyal"] = "魔皇草",
		["Briarthorn"] = "石南草",
		["Stranglekelp"] = "荆棘藻",
		["Bruiseweed"] = "跌打草",
		["Wild Steelbloom"] = "野钢花",
		["Grave Moss"] = "墓地苔",
		["Kingsblood"] = "皇血草",
		["Liferoot"] = "活根草",
		["Fadeleaf"] = "枯叶草",
		["Goldthorn"] = "金棘草",
		["Khadgar's Whisker"] = "卡德加的胡须",
		["Wintersbite"] = "冬刺草",
		["Firebloom"] = "火焰花",
		["Purple Lotus"] = "紫莲花",
		["Arthas' Tears"] = "阿尔萨斯之泪",
		["Sungrass"] = "太阳草",
		["Blindweed"] = "盲目草",
		["Ghost Mushroom"] = "幽灵菇",
		["Gromsblood"] = "格罗姆之血",
		["Golden Sansam"] = "黄金参",
		["Dreamfoil"] = "梦叶草",
		["Mountain Silversage"] = "山鼠草",
		["Plaguebloom"] = "瘟疫花",
		["Icecap"] = "冰盖草",
		["Black Lotus"] = "黑莲花",
		["Felweed"] = "魔草",
		["Dreaming Glory"] = "梦露花",
		["Terocone"] = "泰罗果",
		["Ragveil"] = "邪雾草",
		["Ancient Lichen"] = "远古苔",
		["Netherbloom"] = "虚空花",
		["Nightmare Vine"] = "噩梦藤",
		["Mana Thistle"] = "法力蓟",		
	},
	ruRU = {
		["Peacebloom"] = "Мироцвет",
		["Silverleaf"] = "Сребролист",
		["Earthroot"] = "Земляной корень",
		["Mageroyal"] = "Магороза",
		["Briarthorn"] = "Острошип",
		["Stranglekelp"] = "Удавник",
		["Bruiseweed"] = "Синячник",
		["Wild Steelbloom"] = "Дикий сталецвет",
		["Grave Moss"] = "Могильный мох",
		["Kingsblood"] = "Королевская кровь",
		["Liferoot"] = "Жизнекорень",
		["Fadeleaf"] = "Бледнолист",
		["Goldthorn"] = "Златошип",
		["Khadgar's Whisker"] = "Кадгаров ус",
		["Wintersbite"] = "Морозник",
		["Firebloom"] = "Огнецвет",
		["Purple Lotus"] = "Лиловый лотос",
		["Arthas' Tears"] = "Слезы Артаса",
		["Sungrass"] = "Солнечник",
		["Blindweed"] = "Пастушья сумка",
		["Ghost Mushroom"] = "Призрачная поганка",
		["Gromsblood"] = "Кровь Грома",
		["Golden Sansam"] = "Золотой сансам",
		["Dreamfoil"] = "Снолист",
		["Mountain Silversage"] = "Горный серебряный шалфей",
		["Plaguebloom"] = "Чумоцвет",
		["Icecap"] = "Ледяной зев",
		["Black Lotus"] = "Черный лотос",
		["Felweed"] = "Сквернопля",
		["Dreaming Glory"] = "Сияние грез",
		["Terocone"] = "Терошишка",
		["Ragveil"] = "Кисейница",
		["Ancient Lichen"] = "Древний лишайник",
		["Netherbloom"] = "Пустоцвет",
		["Nightmare Vine"] = "Ползучий кошмарник",
		["Mana Thistle"] = "Манаполох",		
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
			[1439] = true,		-- Darkshore
			[1426] = true,		-- Dun Morogh
			[1411] = true,		-- Durotar
			[1429] = true,		-- Elwynn Forest
			[1432] = true,		-- Loch Modan
			[1412] = true,		-- Mulgore
			[1421] = true,		-- Silverpine Forest
			[1438] = true,		-- Teldrassil
			[1413] = true,		-- The Barrens
			[1420] = true,		-- Tirisfal Glades
			[1436] = true,		-- Westfall
			[1943] = true,		-- Azuremyst Isle
			[1950] = true,		-- Bloodmyst Isle
			[1941] = true,		-- Eversong Woods
			[1942] = true,		-- Ghostlands			
		},
	},
	[765] = {
		name = LHerbs("Silverleaf"),
		itemID = 765,
		minLevel = 1,
		zones = {
			[1439] = true,		-- Darkshore
			[1426] = true,		-- Dun Morogh
			[1411] = true,		-- Durotar
			[1429] = true,		-- Elwynn Forest
			[1432] = true,		-- Loch Modan
			[1412] = true,		-- Mulgore
			[1421] = true,		-- Silverpine Forest
			[1438] = true,		-- Teldrassil
			[1413] = true,		-- The Barrens
			[1420] = true,		-- Tirisfal Glades
			[1436] = true,		-- Westfall
			[1943] = true,		-- Azuremyst Isle
			[1950] = true,		-- Bloodmyst Isle
			[1941] = true,		-- Eversong Woods
			[1942] = true,		-- Ghostlands
		},
	},
	[2449] = {
		name = LHerbs("Earthroot"),
		itemID = 2449,
		minLevel = 15,
		zones = {
			[1439] = true,		-- Darkshore
			[1426] = true,		-- Dun Morogh
			[1411] = true,		-- Durotar
			[1429] = true,		-- Elwynn Forest
			[1432] = true,		-- Loch Modan
			[1412] = true,		-- Mulgore
			[1433] = true,		-- Redridge Mountains
			[1421] = true,		-- Silverpine Forest
			[1438] = true,		-- Teldrassil
			[1413] = true,		-- The Barrens
			[1420] = true,		-- Tirisfal Glades
			[1436] = true,		-- Westfall
			[1943] = true,		-- Azuremyst Isle
			[1950] = true,		-- Bloodmyst Isle
			[1941] = true,		-- Eversong Woods
			[1942] = true,		-- Ghostlands
		},
	},
	[785] = {
		name = LHerbs("Mageroyal"),
		itemID = 785,
		minLevel = 50,
		zones = {
			[1440] = true,		-- Ashenvale
			[1439] = true,		-- Darkshore
			[1411] = true,		-- Durotar
			[1431] = true,		-- Duskwood
			[1424] = true,		-- Hillsbrad Foothills
			[1432] = true,		-- Loch Modan
			[1433] = true,		-- Redridge Mountains
			[1421] = true,		-- Silverpine Forest
			[1442] = true,		-- Stonetalon Mountains
			[1438] = true,		-- Teldrassil
			[1413] = true,		-- The Barrens
			[1436] = true,		-- Westfall
			[1437] = true,		-- Wetlands
			[1950] = true,		-- Bloodmyst Isle
			[1942] = true,		-- Ghostlands
		},
	},
	[2450] = {
		name = LHerbs("Briarthorn"),
		itemID = 2450,
		minLevel = 70,
		zones = {
			[1440] = true,		-- Ashenvale
			[1439] = true,		-- Darkshore
			[1431] = true,		-- Duskwood
			[1424] = true,		-- Hillsbrad Foothills
			[1432] = true,		-- Loch Modan
			[1433] = true,		-- Redridge Mountains
			[1421] = true,		-- Silverpine Forest
			[1442] = true,		-- Stonetalon Mountains
			[1413] = true,		-- The Barrens
			[1436] = true,		-- Westfall
			[1437] = true,		-- Wetlands
			[1950] = true,		-- Bloodmyst Isle
			[1942] = true,		-- Ghostlands
		},
	},
	[3820] = {
		name = LHerbs("Stranglekelp"),
		itemID = 3820,
		minLevel = 85,
		zones = {
			[1440] = true,		-- Ashenvale
			[1439] = true,		-- Darkshore
			[1443] = true,		-- Desolace
			[1445] = true,		-- Dustwallow Marsh
			[1444] = true,		-- Feralas
			[1424] = true,		-- Hillsbrad Foothills
			[1421] = true,		-- Silverpine Forest
			[1434] = true,		-- Stranglethorn Vale
			[1435] = true,		-- Swamp of Sorrows
			[1446] = true,		-- Tanaris
			[1413] = true,		-- The Barrens
			[1425] = true,		-- The Hinterlands
			[1436] = true,		-- Westfall
			[1437] = true,		-- Wetlands
			[1950] = true,		-- Bloodmyst Isle
			[1942] = true,		-- Ghostlands
		},
	},
	[2453] = {
		name = LHerbs("Bruiseweed"),
		itemID = 2453,
		minLevel = 100,
		zones = {
			[1416] = true,		-- Alterac Mountains
			[1417] = true,		-- Arathi Highlands
			[1440] = true,		-- Ashenvale
			[1439] = true,		-- Darkshore
			[1443] = true,		-- Desolace
			[1431] = true,		-- Duskwood
			[1424] = true,		-- Hillsbrad Foothills
			[1432] = true,		-- Loch Modan
			[1433] = true,		-- Redridge Mountains
			[1421] = true,		-- Silverpine Forest
			[1442] = true,		-- Stonetalon Mountains
			[1413] = true,		-- The Barrens
			[1441] = true,		-- Thousand Needles
			[1436] = true,		-- Westfall
			[1437] = true,		-- Wetlands
			[1950] = true,		-- Bloodmyst Isle
			[1942] = true,		-- Ghostlands
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
			[1431] = true,		-- Duskwood
			[1424] = true,		-- Hillsbrad Foothills
			[1442] = true,		-- Stonetalon Mountains
			[1434] = true,		-- Stranglethorn Vale
			[1413] = true,		-- The Barrens
			[1441] = true,		-- Thousand Needles
			[1437] = true,		-- Wetlands
		},
	},
	[3369] = {
		name = LHerbs("Grave Moss"),
		itemID = 3369,
		minLevel = 120,
		zones = {
			[1416] = true,		-- Alterac Mountains
			[1417] = true,		-- Arathi Highlands
			[1443] = true,		-- Desolace
			[1431] = true,		-- Duskwood
			[1423] = true,		-- Eastern Plaguelands
			[1413] = true,		-- The Barrens
			[1437] = true,		-- Wetlands
		},
	},
	[3356] = {
		name = LHerbs("Kingsblood"),
		itemID = 3356,
		minLevel = 125,
		zones = {
			[1416] = true,		-- Alterac Mountains
			[1417] = true,		-- Arathi Highlands
			[1440] = true,		-- Ashenvale
			[1418] = true,		-- Badlands
			[1443] = true,		-- Desolace
			[1431] = true,		-- Duskwood
			[1445] = true,		-- Dustwallow Marsh
			[1424] = true,		-- Hillsbrad Foothills
			[1442] = true,		-- Stonetalon Mountains
			[1434] = true,		-- Stranglethorn Vale
			[1435] = true,		-- Swamp of Sorrows
			[1413] = true,		-- The Barrens
			[1441] = true,		-- Thousand Needles
			[1437] = true,		-- Wetlands
		},
	},
	[3357] = {
		name = LHerbs("Liferoot"),
		itemID = 3357,
		minLevel = 150,
		zones = {
			[1416] = true,		-- Alterac Mountains
			[1417] = true,		-- Arathi Highlands
			[1440] = true,		-- Ashenvale
			[1443] = true,		-- Desolace
			[1445] = true,		-- Dustwallow Marsh
			[1444] = true,		-- Feralas
			[1424] = true,		-- Hillsbrad Foothills
			[1434] = true,		-- Stranglethorn Vale
			[1435] = true,		-- Swamp of Sorrows
			[1425] = true,		-- The Hinterlands
			[1437] = true,		-- Wetlands
		},
	},
	[3818] = {
		name = LHerbs("Fadeleaf"),
		itemID = 3818,
		minLevel = 160,
		zones = {
			[1416] = true,		-- Alterac Mountains
			[1417] = true,		-- Arathi Highlands
			[1418] = true,		-- Badlands
			[1445] = true,		-- Dustwallow Marsh
			[1434] = true,		-- Stranglethorn Vale
			[1435] = true,		-- Swamp of Sorrows
			[1425] = true,		-- The Hinterlands
		},
	},
	[3821] = {
		name = LHerbs("Goldthorn"),
		itemID = 3821,
		minLevel = 170,
		zones = {
			[1416] = true,		-- Alterac Mountains
			[1417] = true,		-- Arathi Highlands
			[1447] = true,		-- Azshara
			[1418] = true,		-- Badlands
			[1445] = true,		-- Dustwallow Marsh
			[1444] = true,		-- Feralas
			[1434] = true,		-- Stranglethorn Vale
			[1435] = true,		-- Swamp of Sorrows
			[1425] = true,		-- The Hinterlands
		},
	},
	[3358] = {
		name = LHerbs("Khadgar's Whisker"),
		itemID = 3358,
		minLevel = 185,
		zones = {
			[1416] = true,		-- Alterac Mountains
			[1417] = true,		-- Arathi Highlands
			[1447] = true,		-- Azshara
			[1418] = true,		-- Badlands
			[1445] = true,		-- Dustwallow Marsh
			[1444] = true,		-- Feralas
			[1434] = true,		-- Stranglethorn Vale
			[1435] = true,		-- Swamp of Sorrows
			[1425] = true,		-- The Hinterlands
		},
	},
	[3819] = {
		name = LHerbs("Wintersbite"),
		itemID = 3819,
		minLevel = 195,
		zones = {
			[1416] = true,		-- Alterac Mountains
		},
	},
	[4625] = {
		name = LHerbs("Firebloom"),
		itemID = 4625,
		minLevel = 205,
		zones = {
			[1418] = true,		-- Badlands
			[1419] = true,		-- Blasted Lands
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
			[1447] = true,		-- Azshara
			[1418] = true,		-- Badlands
			[1444] = true,		-- Feralas
			[1434] = true,		-- Stranglethorn Vale
			[1446] = true,		-- Tanaris
			[1425] = true,		-- The Hinterlands
		},
	},
	[8836] = {
		name = LHerbs("Arthas' Tears"),
		itemID = 8836,
		minLevel = 220,
		zones = {
			[1423] = true,		-- Eastern Plaguelands
			[1448] = true,		-- Felwood
			[1422] = true,		-- Western Plaguelands
		},
	},
	[8838] = {
		name = LHerbs("Sungrass"),
		itemID = 8838,
		minLevel = 230,
		zones = {
			[1447] = true,		-- Azshara
			[1419] = true,		-- Blasted Lands
			[1428] = true,		-- Burning Steppes
			[1423] = true,		-- Eastern Plaguelands
			[1448] = true,		-- Felwood
			[1444] = true,		-- Feralas
			[1451] = true,		-- Silithus
			[1425] = true,		-- The Hinterlands
			[1449] = true,		-- Un'Goro Crater
			[1422] = true,		-- Western Plaguelands
		},
	},
	[8839] = {
		name = LHerbs("Blindweed"),
		itemID = 8839,
		minLevel = 235,
		zones = {
			[1435] = true,		-- Swamp of Sorrows
			[1449] = true,		-- Un'Goro Crater
		},
	},
	[8845] = {
		name = LHerbs("Ghost Mushroom"),
		itemID = 8845,
		minLevel = 245,
		zones = {
			[1443] = true,		-- Desolace
			[1425] = true,		-- The Hinterlands
		},
	},
	[8846] = {
		name = LHerbs("Gromsblood"),
		itemID = 8846,
		minLevel = 250,
		zones = {
			[1440] = true,		-- Ashenvale
			[1419] = true,		-- Blasted Lands
			[1443] = true,		-- Desolace
			[1448] = true,		-- Felwood
		},
	},
	[13464] = {
		name = LHerbs("Golden Sansam"),
		itemID = 13464,
		minLevel = 260,
		zones = {
			[1447] = true,		-- Azshara
			[1428] = true,		-- Burning Steppes
			[1423] = true,		-- Eastern Plaguelands
			[1448] = true,		-- Felwood
			[1444] = true,		-- Feralas
			[1451] = true,		-- Silithus
			[1425] = true,		-- The Hinterlands
			[1449] = true,		-- Un'Goro Crater
		},
	},
	[13463] = {
		name = LHerbs("Dreamfoil"),
		itemID = 13463,
		minLevel = 270,
		zones = {
			[1447] = true,		-- Azshara
			[1428] = true,		-- Burning Steppes
			[1423] = true,		-- Eastern Plaguelands
			[1448] = true,		-- Felwood
			[1451] = true,		-- Silithus
			[1449] = true,		-- Un'Goro Crater
			[1422] = true,		-- Western Plaguelands
	
		},
	},
	[13465] = {
		name = LHerbs("Mountain Silversage"),
		itemID = 13465,
		minLevel = 280,
		zones = {
			[1447] = true,		-- Azshara
			[1428] = true,		-- Burning Steppes
			[1423] = true,		-- Eastern Plaguelands
			[1448] = true,		-- Felwood
			[1451] = true,		-- Silithus
			[1449] = true,		-- Un'Goro Crater
			[1422] = true,		-- Western Plaguelands
			[1452] = true,		-- Winterspring		
		},
	},
	[13466] = {
		name = LHerbs("Plaguebloom"),
		itemID = 13466,
		minLevel = 285,
		zones = {
			[1423] = true,		-- Eastern Plaguelands
			[1448] = true,		-- Felwood
			[1422] = true,		-- Western Plaguelands
		},
	},
	[13467] = {
		name = LHerbs("Icecap"),
		itemID = 13467,
		minLevel = 290,
		zones = {
			[1452] = true,		-- Winterspring
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
	-- TBC Herbs
	[142143] = {
		name = LHerbs("Blindweed"),
		itemID = 142143,
		minLevel = 235,
		zones = {
			[1944] = true,		-- Hellfire Peninsula
			[1946] = true,		-- Zangarmarsh
		},
	},
	[142144] = {
		name = LHerbs("Ghost Mushroom"),
		itemID = 142144,
		minLevel = 245,
		zones = {
			[1944] = true,		-- Hellfire Peninsula
			[1946] = true,		-- Zangarmarsh
		},
	},
	[176583] = {
		name = LHerbs("Golden Sansam"),
		itemID = 176583,
		minLevel = 260,
		zones = {
			[1944] = true,		-- Hellfire Peninsula
			[1946] = true,		-- Zangarmarsh
		},
	},
	[176584] = {
		name = LHerbs("Dreamfoil"),
		itemID = 176584,
		minLevel = 270,
		zones = {
			[1944] = true,		-- Hellfire Peninsula
			[1946] = true,		-- Zangarmarsh
		},
	},
	[176586] = {
		name = LHerbs("Mountain Silversage"),
		itemID = 176586,
		minLevel = 280,
		zones = {
			[1944] = true,		-- Hellfire Peninsula
			[1946] = true,		-- Zangarmarsh
		},
	},
	[181270] = {
		name = LHerbs("Felweed"),
		itemID = 181270,
		minLevel = 300,
		zones = {
			[1949] = true,		-- Blade's Edge Mountains
			[1944] = true,		-- Hellfire Peninsula
			[1951] = true,		-- Nagrand
			[1953] = true,		-- Netherstorm
			[332] = true,		-- Serpentshrine Cavern
			[1948] = true,		-- Shadowmoon Valley
			[1952] = true,		-- Terokkar Forest
			[266] = true,		-- The Botanica
			[265] = true,		-- The Slave Pens
			[263] = true,		-- The Steamvault
			[262] = true,		-- The Underbog
			[1946] = true,		-- Zangarmarsh
		},
	},
	[181271] = {
		name = LHerbs("Dreaming Glory"),
		itemID = 181271,
		minLevel = 315,
		zones = {
			[1949] = true,		-- Blade's Edge Mountains
			[1944] = true,		-- Hellfire Peninsula
			[1951] = true,		-- Nagrand
			[1953] = true,		-- Netherstorm
			[1948] = true,		-- Shadowmoon Valley
			[1952] = true,		-- Terokkar Forest
			[266] = true,		-- The Botanica
			[1946] = true,		-- Zangarmarsh
		},
	},
	[181277] = {
		name = LHerbs("Terocone"),
		itemID = 181277,
		minLevel = 325,
		zones = {
			[1948] = true,		-- Shadowmoon Valley
			[1952] = true,		-- Terokkar Forest
			[266] = true,		-- The Botanica
		},
	},
	[181275] = {
		name = LHerbs("Ragveil"),
		itemID = 181275,
		minLevel = 325,
		zones = {
			[265] = true,		-- The Slave Pens
			[263] = true,		-- The Steamvault
			[262] = true,		-- The Underbog
			[1946] = true,		-- Zangarmarsh
		},
	},
	[181278] = {
		name = LHerbs("Ancient Lichen"),
		itemID = 181278,
		minLevel = 340,
		zones = {
			[256] = true,		-- Auchenai Crypts
			[272] = true,		-- Mana-Tombs
			[332] = true,		-- Serpentshrine Cavern
			[258] = true,		-- Sethekk Halls
			[260] = true,		-- Shadow Labyrinth
			[265] = true,		-- The Slave Pens
			[263] = true,		-- The Steamvault
			[262] = true,		-- The Underbog
		},
	},
	[181279] = {
		name = LHerbs("Netherbloom"),
		itemID = 181279,
		minLevel = 350,
		zones = {
			[1953] = true,		-- Netherstorm
			[266] = true,		-- The Botanica
		},
	},
	[181280] = {
		name = LHerbs("Nightmare Vine"),
		itemID = 181280,
		minLevel = 365,
		zones = {
			[1949] = true,		-- Blade's Edge Mountains
			[1948] = true,		-- Shadowmoon Valley
		},
	},
	[181281] = {
		name = LHerbs("Mana Thistle"),
		itemID = 181281,
		minLevel = 375,
		zones = {
			[1949] = true,		-- Blade's Edge Mountains
			[1951] = true,		-- Nagrand
			[1953] = true,		-- Netherstorm
			[1948] = true,		-- Shadowmoon Valley
			[1952] = true,		-- Terokkar Forest
		},
	},	
}



local herbsByZone = {
	-- Alterac Mountains
	[1416] = {
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 100,
		},
		[3369] = {
			name = LHerbs("Grave Moss"),
			itemID = 3369,
			minLevel = 120,
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
		[3818] = {
			name = LHerbs("Fadeleaf"),
			itemID = 3818,
			minLevel = 160,
		},
		[3821] = {
			name = LHerbs("Goldthorn"),
			itemID = 3821,
			minLevel = 170,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 185,
		},
		[3819] = {
			name = LHerbs("Wintersbite"),
			itemID = 3819,
			minLevel = 195,
		},
	},
	-- Arathi Highlands
	[1417] = {
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 100,
		},
		[3355] = {
			name = LHerbs("Wild Steelbloom"),
			itemID = 3355,
			minLevel = 115,
		},
		[3369] = {
			name = LHerbs("Grave Moss"),
			itemID = 3369,
			minLevel = 120,
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
		[3818] = {
			name = LHerbs("Fadeleaf"),
			itemID = 3818,
			minLevel = 160,
		},
		[3821] = {
			name = LHerbs("Goldthorn"),
			itemID = 3821,
			minLevel = 170,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 185,
		},
	},
	-- Ashenvale
	[1440] = {
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 100,
		},
		[3355] = {
			name = LHerbs("Wild Steelbloom"),
			itemID = 3355,
			minLevel = 115,
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
		[8846] = {
			name = LHerbs("Gromsblood"),
			itemID = 8846,
			minLevel = 250,
		},
	},
	-- Azshara
	[1447] = {
		[3821] = {
			name = LHerbs("Goldthorn"),
			itemID = 3821,
			minLevel = 170,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 185,
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
		[13464] = {
			name = LHerbs("Golden Sansam"),
			itemID = 13464,
			minLevel = 260,
		},
		[13463] = {
			name = LHerbs("Dreamfoil"),
			itemID = 13463,
			minLevel = 270,
		},
		[13465] = {
			name = LHerbs("Mountain Silversage"),
			itemID = 13465,
			minLevel = 280,
		},
	},
	-- Badlands
	[1418] = {
		[3355] = {
			name = LHerbs("Wild Steelbloom"),
			itemID = 3355,
			minLevel = 115,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
		[3818] = {
			name = LHerbs("Fadeleaf"),
			itemID = 3818,
			minLevel = 160,
		},
		[3821] = {
			name = LHerbs("Goldthorn"),
			itemID = 3821,
			minLevel = 170,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 185,
		},
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
	},
	-- Blasted Lands
	[1419] = {
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
		[8846] = {
			name = LHerbs("Gromsblood"),
			itemID = 8846,
			minLevel = 250,
		},
	},
	-- Burning Steppes
	[1428] = {
		[8838] = {
			name = LHerbs("Sungrass"),
			itemID = 8838,
			minLevel = 230,
		},
		[13464] = {
			name = LHerbs("Golden Sansam"),
			itemID = 13464,
			minLevel = 260,
		},
		[13463] = {
			name = LHerbs("Dreamfoil"),
			itemID = 13463,
			minLevel = 270,
		},
		[13465] = {
			name = LHerbs("Mountain Silversage"),
			itemID = 13465,
			minLevel = 280,
		},
		[13468] = {
			name = LHerbs("Black Lotus"),
			itemID = 13468,
			minLevel = 300,
		},
	},
	-- Darkshore
	[1439] = {
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
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 100,
		},
	},
	-- Desolace
	[1443] = {
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 100,
		},
		[3369] = {
			name = LHerbs("Grave Moss"),
			itemID = 3369,
			minLevel = 120,
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
	},
	-- Dun Morogh
	[1426] = {
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
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
	},
	-- Durotar
	[1411] = {
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
	-- Duskwood
	[1431] = {
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 100,
		},
		[3355] = {
			name = LHerbs("Wild Steelbloom"),
			itemID = 3355,
			minLevel = 115,
		},
		[3369] = {
			name = LHerbs("Grave Moss"),
			itemID = 3369,
			minLevel = 120,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
	},
	-- Dustwallow Marsh
	[1445] = {
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
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
		[3818] = {
			name = LHerbs("Fadeleaf"),
			itemID = 3818,
			minLevel = 160,
		},
		[3821] = {
			name = LHerbs("Goldthorn"),
			itemID = 3821,
			minLevel = 170,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 185,
		},
	},
	-- Eastern Plaguelands
	[1423] = {
		[3369] = {
			name = LHerbs("Grave Moss"),
			itemID = 3369,
			minLevel = 120,
		},
		[8836] = {
			name = LHerbs("Arthas' Tears"),
			itemID = 8836,
			minLevel = 220,
		},
		[8838] = {
			name = LHerbs("Sungrass"),
			itemID = 8838,
			minLevel = 230,
		},
		[13464] = {
			name = LHerbs("Golden Sansam"),
			itemID = 13464,
			minLevel = 260,
		},
		[13463] = {
			name = LHerbs("Dreamfoil"),
			itemID = 13463,
			minLevel = 270,
		},
		[13465] = {
			name = LHerbs("Mountain Silversage"),
			itemID = 13465,
			minLevel = 280,
		},
		[13466] = {
			name = LHerbs("Plaguebloom"),
			itemID = 13466,
			minLevel = 285,
		},
		[13468] = {
			name = LHerbs("Black Lotus"),
			itemID = 13468,
			minLevel = 300,
		},
	},
	-- Elwynn Forest
	[1429] = {
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
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
	},
	-- Felwood
	[1448] = {
		[8836] = {
			name = LHerbs("Arthas' Tears"),
			itemID = 8836,
			minLevel = 220,
		},
		[8838] = {
			name = LHerbs("Sungrass"),
			itemID = 8838,
			minLevel = 230,
		},
		[8846] = {
			name = LHerbs("Gromsblood"),
			itemID = 8846,
			minLevel = 250,
		},
		[13464] = {
			name = LHerbs("Golden Sansam"),
			itemID = 13464,
			minLevel = 260,
		},
		[13463] = {
			name = LHerbs("Dreamfoil"),
			itemID = 13463,
			minLevel = 270,
		},
		[13465] = {
			name = LHerbs("Mountain Silversage"),
			itemID = 13465,
			minLevel = 280,
		},
		[13466] = {
			name = LHerbs("Plaguebloom"),
			itemID = 13466,
			minLevel = 285,
		},
	},
	-- Feralas
	[1444] = {
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[3357] = {
			name = LHerbs("Liferoot"),
			itemID = 3357,
			minLevel = 150,
		},
		[3821] = {
			name = LHerbs("Goldthorn"),
			itemID = 3821,
			minLevel = 170,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 185,
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
		[13464] = {
			name = LHerbs("Golden Sansam"),
			itemID = 13464,
			minLevel = 260,
		},
	},
	-- Hillsbrad Foothills
	[1424] = {
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 100,
		},
		[3355] = {
			name = LHerbs("Wild Steelbloom"),
			itemID = 3355,
			minLevel = 115,
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
	-- Loch Modan
	[1432] = {
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
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 100,
		},
	},
	-- Mulgore
	[1412] = {
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
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
	},
	-- Redridge Mountains
	[1433] = {
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
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 100,
		},
	},
	-- Searing Gorge
	[1427] = {
		[4625] = {
			name = LHerbs("Firebloom"),
			itemID = 4625,
			minLevel = 205,
		},
	},
	-- Silithus
	[1451] = {
		[8838] = {
			name = LHerbs("Sungrass"),
			itemID = 8838,
			minLevel = 230,
		},
		[13464] = {
			name = LHerbs("Golden Sansam"),
			itemID = 13464,
			minLevel = 260,
		},
		[13463] = {
			name = LHerbs("Dreamfoil"),
			itemID = 13463,
			minLevel = 270,
		},
		[13465] = {
			name = LHerbs("Mountain Silversage"),
			itemID = 13465,
			minLevel = 280,
		},
		[13468] = {
			name = LHerbs("Black Lotus"),
			itemID = 13468,
			minLevel = 300,
		},
	},
	-- Silverpine Forest
	[1421] = {
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
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 100,
		},
	},
	-- Stonetalon Mountains
	[1442] = {
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 100,
		},
		[3355] = {
			name = LHerbs("Wild Steelbloom"),
			itemID = 3355,
			minLevel = 115,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
	},
	-- Stranglethorn Vale
	[1434] = {
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
		[3818] = {
			name = LHerbs("Fadeleaf"),
			itemID = 3818,
			minLevel = 160,
		},
		[3821] = {
			name = LHerbs("Goldthorn"),
			itemID = 3821,
			minLevel = 170,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 185,
		},
		[8831] = {
			name = LHerbs("Purple Lotus"),
			itemID = 8831,
			minLevel = 210,
		},
	},
	-- Swamp of Sorrows
	[1435] = {
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
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
		[3818] = {
			name = LHerbs("Fadeleaf"),
			itemID = 3818,
			minLevel = 160,
		},
		[3821] = {
			name = LHerbs("Goldthorn"),
			itemID = 3821,
			minLevel = 170,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 185,
		},
		[8839] = {
			name = LHerbs("Blindweed"),
			itemID = 8839,
			minLevel = 235,
		},
	},
	-- Tanaris
	[1446] = {
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
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
	},
	-- Teldrassil
	[1438] = {
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
	-- The Barrens
	[1413] = {
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
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 100,
		},
		[3355] = {
			name = LHerbs("Wild Steelbloom"),
			itemID = 3355,
			minLevel = 115,
		},
		[3369] = {
			name = LHerbs("Grave Moss"),
			itemID = 3369,
			minLevel = 120,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
	},
	-- The Hinterlands
	[1425] = {
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[3357] = {
			name = LHerbs("Liferoot"),
			itemID = 3357,
			minLevel = 150,
		},
		[3818] = {
			name = LHerbs("Fadeleaf"),
			itemID = 3818,
			minLevel = 160,
		},
		[3821] = {
			name = LHerbs("Goldthorn"),
			itemID = 3821,
			minLevel = 170,
		},
		[3358] = {
			name = LHerbs("Khadgar's Whisker"),
			itemID = 3358,
			minLevel = 185,
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
	},
	-- Thousand Needles
	[1441] = {
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 100,
		},
		[3355] = {
			name = LHerbs("Wild Steelbloom"),
			itemID = 3355,
			minLevel = 115,
		},
		[3356] = {
			name = LHerbs("Kingsblood"),
			itemID = 3356,
			minLevel = 125,
		},
	},
	-- Tirisfal Glades
	[1420] = {
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
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
	},
	-- Un'Goro Crater
	[1449] = {
		[8838] = {
			name = LHerbs("Sungrass"),
			itemID = 8838,
			minLevel = 230,
		},
		[8839] = {
			name = LHerbs("Blindweed"),
			itemID = 8839,
			minLevel = 235,
		},
		[13464] = {
			name = LHerbs("Golden Sansam"),
			itemID = 13464,
			minLevel = 260,
		},
		[13463] = {
			name = LHerbs("Dreamfoil"),
			itemID = 13463,
			minLevel = 270,
		},
		[13465] = {
			name = LHerbs("Mountain Silversage"),
			itemID = 13465,
			minLevel = 280,
		},
	},
	-- Western Plaguelands
	[1422] = {
		[8836] = {
			name = LHerbs("Arthas' Tears"),
			itemID = 8836,
			minLevel = 220,
		},
		[8838] = {
			name = LHerbs("Sungrass"),
			itemID = 8838,
			minLevel = 230,
		},
		[13463] = {
			name = LHerbs("Dreamfoil"),
			itemID = 13463,
			minLevel = 270,
		},
		[13465] = {
			name = LHerbs("Mountain Silversage"),
			itemID = 13465,
			minLevel = 280,
		},
		[13466] = {
			name = LHerbs("Plaguebloom"),
			itemID = 13466,
			minLevel = 285,
		},
	},
	-- Westfall
	[1436] = {
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
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 100,
		},
	},
	-- Wetlands
	[1437] = {
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 100,
		},
		[3355] = {
			name = LHerbs("Wild Steelbloom"),
			itemID = 3355,
			minLevel = 115,
		},
		[3369] = {
			name = LHerbs("Grave Moss"),
			itemID = 3369,
			minLevel = 120,
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
	-- Winterspring
	[1452] = {
		[13465] = {
			name = LHerbs("Mountain Silversage"),
			itemID = 13465,
			minLevel = 280,
		},
		[13467] = {
			name = LHerbs("Icecap"),
			itemID = 13467,
			minLevel = 290,
		},
		[13468] = {
			name = LHerbs("Black Lotus"),
			itemID = 13468,
			minLevel = 300,
		},
	},
	-- TBC Zones
	-- Auchenai Crypts
	[256] = {
		[181278] = {
			name = LHerbs("Ancient Lichen"),
			itemID = 181278,
			minLevel = 340,
		},
	},
	-- Azuremyst Isle
	[1943] = {
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
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
	},	
	-- Blade's Edge Mountains
	[1949] = {
		[181270] = {
			name = LHerbs("Felweed"),
			itemID = 181270,
			minLevel = 300,
		},
		[181271] = {
			name = LHerbs("Dreaming Glory"),
			itemID = 181271,
			minLevel = 315,
		},
		[181280] = {
			name = LHerbs("Nightmare Vine"),
			itemID = 181280,
			minLevel = 365,
		},
		[181281] = {
			name = LHerbs("Mana Thistle"),
			itemID = 181281,
			minLevel = 375,
		},
	},
	-- Bloodmyst Isle
	[1950] = {
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
			minLevel = 1,
		},
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 100,
		},
		[2447] = {
			name = LHerbs("Peacebloom"),
			itemID = 2447,
			minLevel = 1,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
	},
	-- Eversong Woods
	[1941] = {
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
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
	},
	-- Ghostlands
	[1942] = {
		[2450] = {
			name = LHerbs("Briarthorn"),
			itemID = 2450,
			minLevel = 70,
		},
		[785] = {
			name = LHerbs("Mageroyal"),
			itemID = 785,
			minLevel = 50,
		},
		[765] = {
			name = LHerbs("Silverleaf"),
			itemID = 765,
			minLevel = 1,
		},
		[2449] = {
			name = LHerbs("Earthroot"),
			itemID = 2449,
			minLevel = 15,
		},
		[2453] = {
			name = LHerbs("Bruiseweed"),
			itemID = 2453,
			minLevel = 100,
		},
		[2447] = {
			name = LHerbs("Peacebloom"),
			itemID = 2447,
			minLevel = 1,
		},
		[3820] = {
			name = LHerbs("Stranglekelp"),
			itemID = 3820,
			minLevel = 85,
		},
	},
	-- Hellfire Peninsula
	[1944] = {
		[181270] = {
			name = LHerbs("Felweed"),
			itemID = 181270,
			minLevel = 300,
		},
		[181271] = {
			name = LHerbs("Dreaming Glory"),
			itemID = 181271,
			minLevel = 315,
		},
		[176584] = {
			name = LHerbs("Dreamfoil"),
			itemID = 176584,
			minLevel = 270,
		},
		[176583] = {
			name = LHerbs("Golden Sansam"),
			itemID = 176583,
			minLevel = 260,
		},
		[176586] = {
			name = LHerbs("Mountain Silversage"),
			itemID = 176586,
			minLevel = 280,
		},
		[142143] = {
			name = LHerbs("Blindweed"),
			itemID = 142143,
			minLevel = 235,
		},
		[142144] = {
			name = LHerbs("Ghost Mushroom"),
			itemID = 142144,
			minLevel = 245,
		},
	},
	-- Mana-Tombs
	[272] = {
		[181278] = {
			name = LHerbs("Ancient Lichen"),
			itemID = 181278,
			minLevel = 340,
		},
	},
	-- Nagrand
	[1951] = {
		[181270] = {
			name = LHerbs("Felweed"),
			itemID = 181270,
			minLevel = 300,
		},
		[181271] = {
			name = LHerbs("Dreaming Glory"),
			itemID = 181271,
			minLevel = 315,
		},
		[181281] = {
			name = LHerbs("Mana Thistle"),
			itemID = 181281,
			minLevel = 375,
		},
	},
	-- Netherstorm
	[1953] = {
		[181270] = {
			name = LHerbs("Felweed"),
			itemID = 181270,
			minLevel = 300,
		},
		[181271] = {
			name = LHerbs("Dreaming Glory"),
			itemID = 181271,
			minLevel = 315,
		},
		[181279] = {
			name = LHerbs("Netherbloom"),
			itemID = 181279,
			minLevel = 350,
		},
		[181281] = {
			name = LHerbs("Mana Thistle"),
			itemID = 181281,
			minLevel = 375,
		},
	},
	-- Serpentshrine Cavern
	[332] = {
		[181270] = {
			name = LHerbs("Felweed"),
			itemID = 181270,
			minLevel = 300,
		},
		[181278] = {
			name = LHerbs("Ancient Lichen"),
			itemID = 181278,
			minLevel = 340,
		},
	},
	-- Sethekk Halls
	[258] = {
		[181278] = {
			name = LHerbs("Ancient Lichen"),
			itemID = 181278,
			minLevel = 340,
		},
	},
	-- Shadow Labyrinth
	[260] = {
		[181278] = {
			name = LHerbs("Ancient Lichen"),
			itemID = 181278,
			minLevel = 340,
		},
	},
	-- Shadowmoon Valley
	[1948] = {
		[181270] = {
			name = LHerbs("Felweed"),
			itemID = 181270,
			minLevel = 300,
		},
		[181271] = {
			name = LHerbs("Dreaming Glory"),
			itemID = 181271,
			minLevel = 315,
		},
		[181277] = {
			name = LHerbs("Terocone"),
			itemID = 181277,
			minLevel = 325,
		},
		[181280] = {
			name = LHerbs("Nightmare Vine"),
			itemID = 181280,
			minLevel = 365,
		},
		[181281] = {
			name = LHerbs("Mana Thistle"),
			itemID = 181281,
			minLevel = 375,
		},
	},
	-- Terokkar Forest
	[1952] = {
		[181270] = {
			name = LHerbs("Felweed"),
			itemID = 181270,
			minLevel = 300,
		},
		[181271] = {
			name = LHerbs("Dreaming Glory"),
			itemID = 181271,
			minLevel = 315,
		},
		[181277] = {
			name = LHerbs("Terocone"),
			itemID = 181277,
			minLevel = 325,
		},
		[181281] = {
			name = LHerbs("Mana Thistle"),
			itemID = 181281,
			minLevel = 375,
		},
	},
	-- The Botanica
	[266] = {
		[181270] = {
			name = LHerbs("Felweed"),
			itemID = 181270,
			minLevel = 300,
		},
		[181271] = {
			name = LHerbs("Dreaming Glory"),
			itemID = 181271,
			minLevel = 315,
		},
		[181277] = {
			name = LHerbs("Terocone"),
			itemID = 181277,
			minLevel = 325,
		},
		[181279] = {
			name = LHerbs("Netherbloom"),
			itemID = 181279,
			minLevel = 350,
		},
	},
	-- The Slave Pens
	[265] = {
		[181270] = {
			name = LHerbs("Felweed"),
			itemID = 181270,
			minLevel = 300,
		},
		[181275] = {
			name = LHerbs("Ragveil"),
			itemID = 181275,
			minLevel = 325,
		},
		[181278] = {
			name = LHerbs("Ancient Lichen"),
			itemID = 181278,
			minLevel = 340,
		},
	},
	-- The Steamvault
	[263] = {
		[181270] = {
			name = LHerbs("Felweed"),
			itemID = 181270,
			minLevel = 300,
		},
		[181275] = {
			name = LHerbs("Ragveil"),
			itemID = 181275,
			minLevel = 325,
		},
		[181278] = {
			name = LHerbs("Ancient Lichen"),
			itemID = 181278,
			minLevel = 340,
		},
	},
	-- The Underbog
	[262] = {
		[181270] = {
			name = LHerbs("Felweed"),
			itemID = 181270,
			minLevel = 300,
		},
		[181275] = {
			name = LHerbs("Ragveil"),
			itemID = 181275,
			minLevel = 325,
		},
		[181278] = {
			name = LHerbs("Ancient Lichen"),
			itemID = 181278,
			minLevel = 340,
		},
	},
	-- Zangarmarsh
	[1946] = {
		[181270] = {
			name = LHerbs("Felweed"),
			itemID = 181270,
			minLevel = 300,
		},
		[181271] = {
			name = LHerbs("Dreaming Glory"),
			itemID = 181271,
			minLevel = 315,
		},
		[181275] = {
			name = LHerbs("Ragveil"),
			itemID = 181275,
			minLevel = 325,
		},
		[176584] = {
			name = LHerbs("Dreamfoil"),
			itemID = 176584,
			minLevel = 270,
		},
		[176583] = {
			name = LHerbs("Golden Sansam"),
			itemID = 176583,
			minLevel = 260,
		},
		[176586] = {
			name = LHerbs("Mountain Silversage"),
			itemID = 176586,
			minLevel = 280,
		},
		[142143] = {
			name = LHerbs("Blindweed"),
			itemID = 142143,
			minLevel = 235,
		},
		[142144] = {
			name = LHerbs("Ghost Mushroom"),
			itemID = 142144,
			minLevel = 245,
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

-- Pulled from GatherMate2 Classic
local miningTranslations = {
	koKR = {
		["Rich Thorium Vein"] = "풍부한 토륨 광맥",
		["Ooze Covered Gold Vein"] = "진흙으로 덮인 금 광맥",
		["Tin Vein"] = "주석 광맥",
		["Copper Vein"] = "구리 광맥",
		["Ooze Covered Rich Thorium Vein"] = "진흙으로 덮인 풍부한 토륨 광맥",
		["Truesilver Deposit"] = "진은 광맥",
		["Dark Iron Deposit"] = "검은무쇠 광맥",
		["Silver Vein"] = "은 광맥",
		["Iron Deposit"] = "철 광맥",
		["Ooze Covered Mithril Deposit"] = "진흙으로 덮인 미스릴 광맥",
		["Ooze Covered Silver Vein"] = "진흙으로 덮인 은 광맥",
		["Gold Vein"] = "금 광맥",
		["Ooze Covered Thorium Vein"] = "진흙으로 덮인 토륨 광맥",
		["Small Thorium Vein"] = "작은 토륨 광맥",
		["Mithril Deposit"] = "미스릴 광맥",
		["Copper Ore"] = "구리 광석",
		["Tin Ore"] = "주석 광석",
		["Silver Ore"] = "은 광석",
		["Iron Ore"] = "철광석",
		["Gold Ore"] = "금 광석",
		["Mithril Ore"] = "미스릴 광석",
		["Truesilver Ore"] = "진은 광석",
		["Dark Iron Ore"] = "검은 무쇠 광석",
		["Thorium Ore"] = "토륨 광석",
		["Fel Iron Deposit"] = "지옥무쇠 광맥",
		["Adamantite Deposit"] = "아다만타이트 광맥",
		["Rich Adamantite Deposit"] = "풍부한 아다만타이트 광맥",
		["Khorium Vein"] = "코륨 광맥",		
		["Fel Iron Ore"] = "지옥무쇠 광석",
		["Adamantite Ore"] = "아다만타이트 광석",
		["Khorium Ore"] = "코륨 광석",
	},
	deDE = {
		["Rich Thorium Vein"] = "Reiches Thoriumvorkommen",
		["Ooze Covered Gold Vein"] = "Schlammbedecktes Goldvorkommen",
		["Tin Vein"] = "Zinnvorkommen",
		["Copper Vein"] = "Kupfervorkommen",
		["Ooze Covered Rich Thorium Vein"] = "Schlammbedecktes reiches Thoriumvorkommen",
		["Truesilver Deposit"] = "Echtsilbervorkommen",
		["Dark Iron Deposit"] = "Dunkeleisenablagerung",
		["Silver Vein"] = "Silbervorkommen",
		["Iron Deposit"] = "Eisenvorkommen",
		["Ooze Covered Mithril Deposit"] = "Schlammbedeckte Mithrilablagerung",
		["Ooze Covered Silver Vein"] = "Schlammbedecktes Silbervorkommen",
		["Gold Vein"] = "Goldvorkommen",
		["Ooze Covered Thorium Vein"] = "Schlammbedeckte Thoriumader",
		["Small Thorium Vein"] = "Kleines Thoriumvorkommen",
		["Mithril Deposit"] = "Mithrilablagerung",
		["Copper Ore"] = "Kupfererz",
		["Tin Ore"] = "Zinnerz",
		["Silver Ore"] = "Silbererz",
		["Iron Ore"] = "Eisenerz",
		["Gold Ore"] = "Golderz",
		["Mithril Ore"] = "Mithrilerz",
		["Truesilver Ore"] = "Echtsilbererz",
		["Dark Iron Ore"] = "Dunkeleisenerz",
		["Thorium Ore"] = "Thoriumerz",
		["Fel Iron Deposit"] = "Teufelseisenvorkommen",
		["Adamantite Deposit"] = "Adamantitvorkommen",
		["Rich Adamantite Deposit"] = "Reiches Adamantitvorkommen",
		["Khorium Vein"] = "Khoriumader",		
		["Fel Iron Ore"] = "Teufelseisenerz",
		["Adamantite Ore"] = "Adamantiterz",
		["Khorium Ore"] = "Khoriumerz",		
	},
	frFR = {
		["Rich Thorium Vein"] = "Riche filon de thorium",
		["Ooze Covered Gold Vein"] = "Filon d'or couvert de limon",
		["Tin Vein"] = "Filon d'étain",
		["Copper Vein"] = "Filon de cuivre",
		["Ooze Covered Rich Thorium Vein"] = "Riche filon de thorium couvert de limon",
		["Truesilver Deposit"] = "Gisement de vrai-argent",
		["Dark Iron Deposit"] = "Gisement de sombrefer",
		["Silver Vein"] = "Filon d'argent",
		["Iron Deposit"] = "Gisement de fer",
		["Ooze Covered Mithril Deposit"] = "Gisement de mithril couvert de vase",
		["Ooze Covered Silver Vein"] = "Filon d'argent couvert de limon",
		["Gold Vein"] = "Filon d'or",
		["Ooze Covered Thorium Vein"] = "Filon de thorium couvert de limon",
		["Small Thorium Vein"] = "Petit filon de thorium",
		["Mithril Deposit"] = "Gisement de mithril",
		["Copper Ore"] = "Minerai de cuivre",
		["Tin Ore"] = "Minerai d'étain",
		["Silver Ore"] = "Minerai d'argent",
		["Iron Ore"] = "Minerai de fer",
		["Gold Ore"] = "Minerai d'or",
		["Mithril Ore"] = "Minerai de mithril",
		["Truesilver Ore"] = "Minerai de vrai-argent",
		["Dark Iron Ore"] = "Minerai de sombrefer",
		["Thorium Ore"] = "Minerai de thorium",
		["Fel Iron Deposit"] = "Gisement de gangrefer",
		["Adamantite Deposit"] = "Gisement d'adamantite",
		["Rich Adamantite Deposit"] = "Riche gisement d'adamantite",
		["Khorium Vein"] = "Filon de khorium",		
		["Fel Iron Ore"] = "Minerai de gangrefer",
		["Adamantite Ore"] = "Minerai d'adamantite",
		["Khorium Ore"] = "Minerai de khorium",		
	},
	esES = {
		["Rich Thorium Vein"] = "Filón de torio enriquecido",
		["Ooze Covered Gold Vein"] = "Filón de oro cubierto de moco",
		["Tin Vein"] = "Filón de estaño",
		["Copper Vein"] = "Filón de cobre",
		["Ooze Covered Rich Thorium Vein"] = "Filón de torio enriquecido cubierto de moco",
		["Truesilver Deposit"] = "Depósito de veraplata",
		["Dark Iron Deposit"] = "Depósito de hierro negro",
		["Silver Vein"] = "Filón de plata",
		["Iron Deposit"] = "Depósito de hierro",
		["Ooze Covered Mithril Deposit"] = "Filón de mitril cubierto de moco",
		["Ooze Covered Silver Vein"] = "Filón de plata cubierto de moco",
		["Gold Vein"] = "Filón de oro",
		["Ooze Covered Thorium Vein"] = "Filón de torio cubierto de moco",
		["Small Thorium Vein"] = "Filón pequeño de torio",
		["Mithril Deposit"] = "Depósito de mitril",
		["Copper Ore"] = "Mineral de cobre",
		["Tin Ore"] = "Mineral de estaño",
		["Silver Ore"] = "Mineral de plata",
		["Iron Ore"] = "Mineral de hierro negro",
		["Gold Ore"] = "Mineral de oro",
		["Mithril Ore"] = "Mineral de mitril",
		["Truesilver Ore"] = "Mineral de veraplata",
		["Dark Iron Ore"] = "Mineral de hierro negro",
		["Thorium Ore"] = "Mineral de torio",
		["Fel Iron Deposit"] = "Depósito de hierro vil",
		["Adamantite Deposit"] = "Depósito de adamantita",
		["Rich Adamantite Deposit"] = "Depósito rico en adamantita",
		["Khorium Vein"] = "Filón de korio",		
		["Fel Iron Ore"] = "Mena de hierro vil",
		["Adamantite Ore"] = "Mena de adamantita",
		["Khorium Ore"] = "Mena de korio",		
	},
	zhTW = {
		["Rich Thorium Vein"] = "富瑟銀礦脈",
		["Ooze Covered Gold Vein"] = "軟泥覆蓋的金礦脈",
		["Tin Vein"] = "錫礦脈",
		["Copper Vein"] = "銅礦脈",
		["Ooze Covered Rich Thorium Vein"] = "軟泥覆蓋的富瑟銀礦脈",
		["Truesilver Deposit"] = "真銀礦床",
		["Dark Iron Deposit"] = "黑鐵礦床",
		["Silver Vein"] = "銀礦脈",
		["Iron Deposit"] = "鐵礦床",
		["Ooze Covered Mithril Deposit"] = "軟泥覆蓋的秘銀礦床",
		["Ooze Covered Silver Vein"] = "軟泥覆蓋的銀礦脈",
		["Gold Vein"] = "金礦脈",
		["Ooze Covered Thorium Vein"] = "軟泥覆蓋的瑟銀礦脈",
		["Small Thorium Vein"] = "瑟銀礦脈",
		["Mithril Deposit"] = "秘銀礦床"	,
		["Copper Ore"] = "銅礦",
		["Tin Ore"] = "錫礦",
		["Silver Ore"] = "銀礦石",
		["Iron Ore"] = "鐵礦",
		["Gold Ore"] = "金礦",
		["Mithril Ore"] = "秘銀礦石",
		["Truesilver Ore"] = "真銀礦石",
		["Dark Iron Ore"] = "黑鐵礦",
		["Thorium Ore"] = "釷礦石",
		["Fel Iron Deposit"] = "魔鐵礦床",
		["Adamantite Deposit"] = "堅鋼礦床",
		["Rich Adamantite Deposit"] = "豐沃的堅鋼礦床",
		["Khorium Vein"] = "克銀礦脈",		
		["Fel Iron Ore"] = "魔鐵礦石",
		["Adamantite Ore"] = "堅鋼礦石",
		["Khorium Ore"] = "克銀礦石",		
	},
	zhCN = {
		["Rich Thorium Vein"] = "富瑟银矿",
		["Ooze Covered Gold Vein"] = "软泥覆盖的金矿脉",
		["Tin Vein"] = "锡矿",
		["Copper Vein"] = "铜矿",
		["Ooze Covered Rich Thorium Vein"] = "软泥覆盖的富瑟银矿脉",
		["Truesilver Deposit"] = "真银矿石",
		["Dark Iron Deposit"] = "黑铁矿脉",
		["Silver Vein"] = "银矿",
		["Iron Deposit"] = "铁矿石",
		["Ooze Covered Mithril Deposit"] = "软泥覆盖的秘银矿脉",
		["Ooze Covered Silver Vein"] = "软泥覆盖的银矿脉",
		["Gold Vein"] = "金矿石",
		["Ooze Covered Thorium Vein"] = "软泥覆盖的瑟银矿脉",
		["Small Thorium Vein"] = "瑟银矿脉",
		["Mithril Deposit"] = "秘银矿脉",
		["Copper Ore"] = "铜矿",
		["Tin Ore"] = "锡矿",
		["Silver Ore"] = "银矿",
		["Iron Ore"] = "铁矿",
		["Gold Ore"] = "金矿",
		["Mithril Ore"] = "秘银矿",
		["Truesilver Ore"] = "真银矿",
		["Dark Iron Ore"] = "黑铁矿",
		["Thorium Ore"] = "钍矿",
		["Fel Iron Deposit"] = "魔铁矿脉",
		["Adamantite Deposit"] = "精金矿脉",
		["Rich Adamantite Deposit"] = "富精金矿脉",
		["Khorium Vein"] = "氪金矿脉",		
		["Fel Iron Ore"] = "魔铁矿石",
		["Adamantite Ore"] = "精金矿石",
		["Khorium Ore"] = "氪金矿石",		
	},
	ruRU = {
		["Rich Thorium Vein"] = "Богатая ториевая жила",
		["Ooze Covered Gold Vein"] = "Покрытая слизью золотая жила",
		["Tin Vein"] = "Оловянная жила",
		["Copper Vein"] = "Медная жила",
		["Ooze Covered Rich Thorium Vein"] = "Покрытая слизью богатая ториевая жила",
		["Truesilver Deposit"] = "Залежи истинного серебра",
		["Dark Iron Deposit"] = "Залежи черного железа",
		["Silver Vein"] = "Серебряная жила",
		["Iron Deposit"] = "Залежи железа",
		["Ooze Covered Mithril Deposit"] = "Покрытые слизью мифриловые залежи",
		["Ooze Covered Silver Vein"] = "Покрытая слизью серебрянная жила",
		["Gold Vein"] = "Золотая жила",
		["Ooze Covered Thorium Vein"] = "Покрытая слизью ториевая жила",
		["Small Thorium Vein"] = "Малая ториевая жила",
		["Mithril Deposit"] = "Мифриловые залежи",
		["Copper Ore"] = "медная руда",
		["Tin Ore"] = "Оловянная руда",
		["Silver Ore"] = "серебряная руда",
		["Iron Ore"] = "железная руда",
		["Gold Ore"] = "Золотая руда",
		["Mithril Ore"] = "мифриловая руда",
		["Truesilver Ore"] = "истинно серебряная руда",
		["Dark Iron Ore"] = "темная железная руда",
		["Thorium Ore"] = "ториевая руда",
		["Fel Iron Deposit"] = "Залежи оскверненного железа",
		["Adamantite Deposit"] = "Залежи адамантита",
		["Rich Adamantite Deposit"] = "Богатые залежи адамантита",
		["Khorium Vein"] = "Кориевая жила",		
		["Fel Iron Ore"] = "Руда оскверненного железа",
		["Adamantite Ore"] = "Адамантитовая руда",
		["Khorium Ore"] = "Кориевая руда",		
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

-- Most node types are represented by multiple object IDs
-- This table maps these IDs to the most common ones
local miningNodeIDMapping = {
	[2055] = 1731,   -- Copper 
	[3763] = 1731,
	[103713] = 1731,
	[103714] = 1731,
	[2054] = 1732,    -- Tin 
	[3764] = 1732,
	[103709] = 1732,
	[105569] = 1733,  -- Silver
	[150080] = 1734,  -- Gold
	[181109] = 1734,
	[103710] = 1735,  -- Iron
	[103712] = 1735,
	[150079] = 2040,  -- Mithril
	[176645] = 2040,
	[150081] = 2047,  -- Truesilver
	[181108] = 2047,
	[150082] = 324,   -- Small Thorium
	[176643] = 324,
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
			[1439] = true,		-- Darkshore
			[1443] = true,		-- Desolace
			[1426] = true,		-- Dun Morogh
			[1411] = true,		-- Durotar
			[1431] = true,		-- Duskwood
			[1429] = true,		-- Elwynn Forest
			[1424] = true,		-- Hillsbrad Foothills
			[1432] = true,		-- Loch Modan
			[1412] = true,		-- Mulgore
			[1433] = true,		-- Redridge Mountains
			[1421] = true,		-- Silverpine Forest
			[1442] = true,		-- Stonetalon Mountains
			[1413] = true,		-- The Barrens
			[1441] = true,		-- Thousand Needles
			[1420] = true,		-- Tirisfal Glades
			[1436] = true,		-- Westfall
			[1437] = true,		-- Wetlands
			[1943] = true,		-- Azuremyst Isle
			[1950] = true,		-- Bloodmyst Isle
			[1941] = true,		-- Eversong Woods
			[1942] = true,		-- Ghostlands			
		},
	},
	[1732] = {
		nodeName = LMining("Tin Vein"),
		nodeObjectID = 1732,
		oreName = LMining("Tin Ore"),
		oreItemID = 2771,
		minLevel = 65,
		zones = {
			[1416] = true,		-- Alterac Mountains
			[1417] = true,		-- Arathi Highlands
			[1440] = true,		-- Ashenvale
			[1439] = true,		-- Darkshore
			[1443] = true,		-- Desolace
			[1431] = true,		-- Duskwood
			[1445] = true,		-- Dustwallow Marsh
			[1424] = true,		-- Hillsbrad Foothills
			[1432] = true,		-- Loch Modan
			[1433] = true,		-- Redridge Mountains
			[1421] = true,		-- Silverpine Forest
			[1442] = true,		-- Stonetalon Mountains
			[1434] = true,		-- Stranglethorn Vale
			[1413] = true,		-- The Barrens
			[1441] = true,		-- Thousand Needles
			[1436] = true,		-- Westfall
			[1437] = true,		-- Wetlands
			[1950] = true,		-- Bloodmyst Isle
			[1942] = true,		-- Ghostlands
		},
	},
	[1733] = {
		nodeName = LMining("Silver Vein"),
		nodeObjectID = 1733,
		oreName = LMining("Silver Ore"),
		oreItemID = 2775,
		minLevel = 75,
		zones = {
			[1416] = true,		-- Alterac Mountains
			[1417] = true,		-- Arathi Highlands
			[1418] = true,		-- Badlands
			[1439] = true,		-- Darkshore
			[1443] = true,		-- Desolace
			[1431] = true,		-- Duskwood
			[1444] = true,		-- Feralas
			[1424] = true,		-- Hillsbrad Foothills
			[1432] = true,		-- Loch Modan
			[1433] = true,		-- Redridge Mountains
			[1421] = true,		-- Silverpine Forest
			[1442] = true,		-- Stonetalon Mountains
			[1434] = true,		-- Stranglethorn Vale
			[1413] = true,		-- The Barrens
			[1441] = true,		-- Thousand Needles
			[1436] = true,		-- Westfall
			[1437] = true,		-- Wetlands
			[1950] = true,		-- Bloodmyst Isle
			[1942] = true,		-- Ghostlands
		},
	},
	[73940] = {
		nodeName = LMining("Ooze Covered Silver Vein"),
		nodeObjectID = 73940,
		oreName = LMining("Silver Ore"),
		oreItemID = 2775,
		minLevel = 75,
		zones = {
			[1441] = true,		-- Thousand Needles
		},
	},
	[1735] = {
		nodeName = LMining("Iron Deposit"),
		nodeObjectID = 1735,
		oreName = LMining("Iron Ore"),
		oreItemID = 2772,
		minLevel = 125,
		zones = {
			[1416] = true,		-- Alterac Mountains
			[1417] = true,		-- Arathi Highlands
			[1440] = true,		-- Ashenvale
			[1418] = true,		-- Badlands
			[1443] = true,		-- Desolace
			[1431] = true,		-- Duskwood
			[1445] = true,		-- Dustwallow Marsh
			[1444] = true,		-- Feralas
			[1424] = true,		-- Hillsbrad Foothills
			[1427] = true,		-- Searing Gorge
			[1442] = true,		-- Stonetalon Mountains
			[1434] = true,		-- Stranglethorn Vale
			[1435] = true,		-- Swamp of Sorrows
			[1446] = true,		-- Tanaris
			[1425] = true,		-- The Hinterlands
			[1441] = true,		-- Thousand Needles
			[1437] = true,		-- Wetlands
		},
	},
	[1734] = {
		nodeName = LMining("Gold Vein"),
		nodeObjectID = 1734,
		oreName = LMining("Gold Ore"),
		oreItemID = 2776,
		minLevel = 155,
		zones = {
			[1416] = true,		-- Alterac Mountains
			[1417] = true,		-- Arathi Highlands
			[1418] = true,		-- Badlands
			[1419] = true,		-- Blasted Lands
			[1443] = true,		-- Desolace
			[1444] = true,		-- Feralas
			[1424] = true,		-- Hillsbrad Foothills
			[1434] = true,		-- Stranglethorn Vale
			[1435] = true,		-- Swamp of Sorrows
			[1446] = true,		-- Tanaris
			[1425] = true,		-- The Hinterlands
			[1441] = true,		-- Thousand Needles
			[1452] = true,		-- Winterspring
		},
	},
	[73941] = {
		nodeName = LMining("Ooze Covered Gold Vein"),
		nodeObjectID = 73941,
		oreName = LMining("Gold Ore"),
		oreItemID = 2776,
		minLevel = 155,
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
		minLevel = 175,
		zones = {
			[1416] = true,		-- Alterac Mountains
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
			[1427] = true,		-- Searing Gorge
			[1451] = true,		-- Silithus
			[1442] = true,		-- Stonetalon Mountains
			[1434] = true,		-- Stranglethorn Vale
			[1435] = true,		-- Swamp of Sorrows
			[1446] = true,		-- Tanaris
			[1425] = true,		-- The Hinterlands
			[1441] = true,		-- Thousand Needles
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
		minLevel = 175,
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
		minLevel = 230,
		zones = {
			[1416] = true,		-- Alterac Mountains
			[1418] = true,		-- Badlands
			[1419] = true,		-- Blasted Lands
			[1423] = true,		-- Eastern Plaguelands
			[1448] = true,		-- Felwood
			[1424] = true,		-- Hillsbrad Foothills
			[1427] = true,		-- Searing Gorge
			[1434] = true,		-- Stranglethorn Vale
			[1446] = true,		-- Tanaris
			[1425] = true,		-- The Hinterlands
			[1449] = true,		-- Un'Goro Crater
			[1422] = true,		-- Western Plaguelands
			[1452] = true,		-- Winterspring
		},
	},
	[165658] = {
		nodeName = LMining("Dark Iron Deposit"),
		nodeObjectID = 165658,
		oreName = LMining("Dark Iron Ore"),
		oreItemID = 11370,
		minLevel = 230,
		zones = {
			[1428] = true,		-- Burning Steppes
			[1427] = true,		-- Searing Gorge
		},
	},
	[324] = {
		nodeName = LMining("Small Thorium Vein"),
		nodeObjectID = 324,
		oreName = LMining("Thorium Ore"),
		oreItemID = 10620,
		minLevel = 245,
		zones = {
			[1419] = true,		-- Blasted Lands
			[1428] = true,		-- Burning Steppes
			[1423] = true,		-- Eastern Plaguelands
			[1448] = true,		-- Felwood
			[1444] = true,		-- Feralas
			[1427] = true,		-- Searing Gorge
			[1451] = true,		-- Silithus
			[1446] = true,		-- Tanaris
			[1425] = true,		-- The Hinterlands
			[1449] = true,		-- Un'Goro Crater
			[1422] = true,		-- Western Plaguelands
			[1452] = true,		-- Winterspring
		},
	},
	[123848] = {
		nodeName = LMining("Ooze Covered Thorium Vein"),
		nodeObjectID = 123848,
		oreName = LMining("Thorium Ore"),
		oreItemID = 10620,
		minLevel = 245,
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
		minLevel = 275,
		zones = {
			[1447] = true,		-- Azshara
			[1428] = true,		-- Burning Steppes
			[1423] = true,		-- Eastern Plaguelands
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
		minLevel = 275,
		zones = {
			[1451] = true,		-- Silithus
		},
	},
	-- TBC Mining Nodes
	[181555] = {
		nodeName = LMining("Fel Iron Deposit"),
		nodeObjectID = 181555,
		oreName = LMining("Fel Iron Ore"),
		oreItemID = 23424,
		minLevel = 300,
		zones = {
			[1949] = true,		-- Blade's Edge Mountains
			[1944] = true,		-- Hellfire Peninsula
			[1951] = true,		-- Nagrand
			[1953] = true,		-- Netherstorm
			[1948] = true,		-- Shadowmoon Valley
			[1952] = true,		-- Terokkar Forest
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
			[1949] = true,		-- Blade's Edge Mountains
			[1951] = true,		-- Nagrand
			[1953] = true,		-- Netherstorm
			[1948] = true,		-- Shadowmoon Valley
			[1952] = true,		-- Terokkar Forest
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
			[1949] = true,		-- Blade's Edge Mountains
			[1951] = true,		-- Nagrand
			[1953] = true,		-- Netherstorm
			[1948] = true,		-- Shadowmoon Valley
			[1952] = true,		-- Terokkar Forest
			[1946] = true,		-- Zangarmarsh
		},
	},
	[181557] = {
		nodeName = LMining("Khorium Vein"),
		nodeObjectID = 181557,
		oreName = LMining("Khorium Ore"),
		oreItemID = 23426,
		minLevel = 375,
		zones = {
			[1949] = true,		-- Blade's Edge Mountains
			[1951] = true,		-- Nagrand
			[1953] = true,		-- Netherstorm
			[1948] = true,		-- Shadowmoon Valley
			[1952] = true,		-- Terokkar Forest
		},
	},	
}



local miningNodesByZone = {
	-- Alterac Mountains
	[1416] = {
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 65,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 75,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 125,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 155,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 230,
		},
	},
	-- Arathi Highlands
	[1417] = {
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 65,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 75,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 125,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 155,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
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
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 65,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 125,
		},
	},
	-- Azshara
	[1447] = {
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
		[175404] = {
			nodeName = LMining("Rich Thorium Vein"),
			nodeObjectID = 175404,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 275,
		},
	},
	-- Badlands
	[1418] = {
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 75,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 125,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 155,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 230,
		},
	},
	-- Blasted Lands
	[1419] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 155,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 230,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 245,
		},
	},
	-- Burning Steppes
	[1428] = {
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
		[165658] = {
			nodeName = LMining("Dark Iron Deposit"),
			nodeObjectID = 165658,
			oreName = LMining("Dark Iron Ore"),
			oreItemID = 11370,
			minLevel = 230,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 245,
		},
		[175404] = {
			nodeName = LMining("Rich Thorium Vein"),
			nodeObjectID = 175404,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 275,
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
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 65,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 75,
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
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 65,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 75,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 125,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 155,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
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
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 65,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 75,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 125,
		},
	},
	-- Dustwallow Marsh
	[1445] = {
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 65,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 125,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
	},
	-- Eastern Plaguelands
	[1423] = {
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 230,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 245,
		},
		[175404] = {
			nodeName = LMining("Rich Thorium Vein"),
			nodeObjectID = 175404,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 275,
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
	-- Felwood
	[1448] = {
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 230,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 245,
		},
	},
	-- Feralas
	[1444] = {
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 75,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 125,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 155,
		},
		[73941] = {
			nodeName = LMining("Ooze Covered Gold Vein"),
			nodeObjectID = 73941,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 155,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
		[123310] = {
			nodeName = LMining("Ooze Covered Mithril Deposit"),
			nodeObjectID = 123310,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 245,
		},
		[123848] = {
			nodeName = LMining("Ooze Covered Thorium Vein"),
			nodeObjectID = 123848,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 245,
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
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 65,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 75,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 125,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 155,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 230,
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
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 65,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 75,
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
	-- Redridge Mountains
	[1433] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 65,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 75,
		},
	},
	-- Searing Gorge
	[1427] = {
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 125,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 230,
		},
		[165658] = {
			nodeName = LMining("Dark Iron Deposit"),
			nodeObjectID = 165658,
			oreName = LMining("Dark Iron Ore"),
			oreItemID = 11370,
			minLevel = 230,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 245,
		},
	},
	-- Silithus
	[1451] = {
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 245,
		},
		[177388] = {
			nodeName = LMining("Ooze Covered Rich Thorium Vein"),
			nodeObjectID = 177388,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 275,
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
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 65,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 75,
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
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 65,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 75,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 125,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
	},
	-- Stranglethorn Vale
	[1434] = {
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 65,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 75,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 125,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 155,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 230,
		},
	},
	-- Swamp of Sorrows
	[1435] = {
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 125,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 155,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
	},
	-- Tanaris
	[1446] = {
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 125,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 155,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 230,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 245,
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
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 65,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 75,
		},
	},
	-- The Hinterlands
	[1425] = {
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 125,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 155,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 230,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 245,
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
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 65,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 75,
		},
		[73940] = {
			nodeName = LMining("Ooze Covered Silver Vein"),
			nodeObjectID = 73940,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 75,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 125,
		},
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 155,
		},
		[73941] = {
			nodeName = LMining("Ooze Covered Gold Vein"),
			nodeObjectID = 73941,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 155,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
		[123310] = {
			nodeName = LMining("Ooze Covered Mithril Deposit"),
			nodeObjectID = 123310,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
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
	-- Un'Goro Crater
	[1449] = {
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 230,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 245,
		},
		[123848] = {
			nodeName = LMining("Ooze Covered Thorium Vein"),
			nodeObjectID = 123848,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 245,
		},
		[175404] = {
			nodeName = LMining("Rich Thorium Vein"),
			nodeObjectID = 175404,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 275,
		},
	},
	-- Western Plaguelands
	[1422] = {
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 230,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 245,
		},
		[175404] = {
			nodeName = LMining("Rich Thorium Vein"),
			nodeObjectID = 175404,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 275,
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
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 65,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 75,
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
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 65,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 75,
		},
		[1735] = {
			nodeName = LMining("Iron Deposit"),
			nodeObjectID = 1735,
			oreName = LMining("Iron Ore"),
			oreItemID = 2772,
			minLevel = 125,
		},
	},
	-- Winterspring
	[1452] = {
		[1734] = {
			nodeName = LMining("Gold Vein"),
			nodeObjectID = 1734,
			oreName = LMining("Gold Ore"),
			oreItemID = 2776,
			minLevel = 155,
		},
		[2040] = {
			nodeName = LMining("Mithril Deposit"),
			nodeObjectID = 2040,
			oreName = LMining("Mithril Ore"),
			oreItemID = 3858,
			minLevel = 175,
		},
		[2047] = {
			nodeName = LMining("Truesilver Deposit"),
			nodeObjectID = 2047,
			oreName = LMining("Truesilver Ore"),
			oreItemID = 7911,
			minLevel = 230,
		},
		[324] = {
			nodeName = LMining("Small Thorium Vein"),
			nodeObjectID = 324,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 245,
		},
		[175404] = {
			nodeName = LMining("Rich Thorium Vein"),
			nodeObjectID = 175404,
			oreName = LMining("Thorium Ore"),
			oreItemID = 10620,
			minLevel = 275,
		},
	},
	-- TBC Zones
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
	-- Blade's Edge Mountains
	[1949] = {
		[181555] = {
			nodeName = LMining("Fel Iron Deposit"),
			nodeObjectID = 181555,
			oreName = LMining("Fel Iron Ore"),
			oreItemID = 23424,
			minLevel = 300,
		},
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
	-- Bloodmyst Isle
	[1950] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 65,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 75,
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
	-- Ghostlands
	[1942] = {
		[1731] = {
			nodeName = LMining("Copper Vein"),
			nodeObjectID = 1731,
			oreName = LMining("Copper Ore"),
			oreItemID = 2770,
			minLevel = 1,
		},
		[1732] = {
			nodeName = LMining("Tin Vein"),
			nodeObjectID = 1732,
			oreName = LMining("Tin Ore"),
			oreItemID = 2771,
			minLevel = 65,
		},
		[1733] = {
			nodeName = LMining("Silver Vein"),
			nodeObjectID = 1733,
			oreName = LMining("Silver Ore"),
			oreItemID = 2775,
			minLevel = 75,
		},
	},	
	-- Hellfire Peninsula
	[1944] = {
		[181555] = {
			nodeName = LMining("Fel Iron Deposit"),
			nodeObjectID = 181555,
			oreName = LMining("Fel Iron Ore"),
			oreItemID = 23424,
			minLevel = 300,
		},
	},
	-- Nagrand
	[1951] = {
		[181555] = {
			nodeName = LMining("Fel Iron Deposit"),
			nodeObjectID = 181555,
			oreName = LMining("Fel Iron Ore"),
			oreItemID = 23424,
			minLevel = 300,
		},
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
	-- Netherstorm
	[1953] = {
		[181555] = {
			nodeName = LMining("Fel Iron Deposit"),
			nodeObjectID = 181555,
			oreName = LMining("Fel Iron Ore"),
			oreItemID = 23424,
			minLevel = 300,
		},
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
		[181555] = {
			nodeName = LMining("Fel Iron Deposit"),
			nodeObjectID = 181555,
			oreName = LMining("Fel Iron Ore"),
			oreItemID = 23424,
			minLevel = 300,
		},
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
	-- Terokkar Forest
	[1952] = {
		[181555] = {
			nodeName = LMining("Fel Iron Deposit"),
			nodeObjectID = 181555,
			oreName = LMining("Fel Iron Ore"),
			oreItemID = 23424,
			minLevel = 300,
		},
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
	-- Zangarmarsh
	[1946] = {
		[181555] = {
			nodeName = LMining("Fel Iron Deposit"),
			nodeObjectID = 181555,
			oreName = LMining("Fel Iron Ore"),
			oreItemID = 23424,
			minLevel = 300,
		},
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
		trace("Processing Continent "..tostring(continentMapID)..": "..continentName.."...")

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

		trace( "Tourist: Processed "..tostring(counter).." zones for "..continentName.." (ID = "..tostring(continentMapID)..")" )
		counter2 = counter2 + counter
	end -- continent loop

	trace("Tourist: Processed "..tostring(counter2).." zones")

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

	trace("LibTourist Classic initialized, loaded by "..tostring(addonName))

	PLAYER_LEVEL_UP(Tourist)
end

return Tourist

