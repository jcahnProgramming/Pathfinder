-- Static dungeon and raid data for Eastern Kingdoms and Kalimdor.
-- C_EncounterJournal.GetDungeonEntrancesForMap returns nothing on WoW Forever, so entrances live here
-- until they are replaced by entrances recorded in-game (Core\EntranceRecorder.lua).
--
-- Sites are physical entrances. One site can hold several instances (Blackrock Mountain, the gates of
-- Ahn'Qiraj, Scarlet Monastery's wings) so they share one pin instead of stacking.
--
--   entrances = { { uiMapID, x%, y%, label? }, ... }   static zone-map coordinates (0-100); may be empty
--   instances = { { name, mapIDs, type, min, max, size?, aliases? }, ... }
--     mapIDs  = instance map IDs (GetInstanceInfo's 8th return); ties recorded entrances to instances
--     min/max = fallback level range; the client's group-browser range is used where it exists
--     aliases = other names the client's LFG / group-browser lists use for the instance
--     official = true: min/max are Blizzard's published range and win over client data
--     unreleased = true: not (yet) in Forever; hidden unless "/pf unreleased" is on (testing only)
--   hint       = where to look for the entrance (Blizzard's description); shown until one is recorded
--   attunement = shown in the tooltip when entry needs an attunement
--
-- Sources:
--   Static coordinates: QuestieDB support/Forever/Zones/dungeons.lua (Forever-corrected entrance points).
--     To be replaced by recorded entrances and removed before 1.0 (docs/ROADMAP.md).
--   Level ranges, in order of authority:
--     1. official: Blizzard's published ranges for Forever's new dungeons (news.blizzard.com,
--        "Explore the New Dungeons of World of Warcraft: Forever").
--     2. client: the group browser's suggested range (original dungeons).
--     3. static: classic (Era) recommended ranges below, as fallback.
--   Raids: only Forever's announced launch raids are live (Onyxia's Lair, Hyjal Summit, The Barrow Deeps,
--   opening 2026-12-09). Revisit whenever Blizzard announces new Forever raids.
--
-- candidate = true marks Questie-listed Forever areas the client hasn't confirmed as instances. They
-- are drawn only once the client lists them or an entrance is recorded for their map ID.
local _, ns = ...

ns.Data = ns.Data or {}

local D, R = "dungeon", "raid"
ns.Data.INSTANCE_TYPE = { DUNGEON = D, RAID = R }

ns.Data.Instances = {
	---------------------------------------------------------------------------
	-- Eastern Kingdoms
	---------------------------------------------------------------------------
	{ name = "The Deadmines", entrances = { { 1436, 42.5, 71.7 } }, -- Westfall
		instances = { { name = "The Deadmines", mapIDs = { 36 }, type = D, min = 17, max = 26 } } },

	{ name = "The Stockade", entrances = { { 1453, 52.41, 70.01 } }, -- Stormwind City
		instances = { { name = "The Stockade", mapIDs = { 34 }, aliases = { "Stormwind Stockades", "Stormwind Stockade", "Stockades" },
			type = D, min = 24, max = 32 } } },

	{ name = "Gnomeregan", entrances = { { 1426, 24.3, 39.8 } }, -- Dun Morogh
		instances = { { name = "Gnomeregan", mapIDs = { 90 }, type = D, min = 29, max = 38 } } },

	{ name = "Shadowfang Keep", entrances = { { 1421, 44.8, 67.8 } }, -- Silverpine Forest
		instances = { { name = "Shadowfang Keep", mapIDs = { 33 }, type = D, min = 22, max = 30 } } },

	-- All four wings share instance map 189; LFG #17 "Scarlet Monastery" is the wing group.
	{ name = "Scarlet Monastery", entrances = { { 1420, 82.6, 33.8 } }, -- Tirisfal Glades
		instances = {
			{ name = "Graveyard", mapIDs = { 189 }, aliases = { "Scarlet Monastery" }, type = D, min = 26, max = 36 },
			{ name = "Library", mapIDs = { 189 }, aliases = { "Scarlet Monastery" }, type = D, min = 29, max = 39 },
			{ name = "Armory", mapIDs = { 189 }, aliases = { "Scarlet Monastery" }, type = D, min = 32, max = 42 },
			{ name = "Cathedral", mapIDs = { 189 }, aliases = { "Scarlet Monastery" }, type = D, min = 35, max = 45 },
		} },

	{ name = "Uldaman", entrances = { { 1418, 44.6, 12.1, "Front entrance" }, { 1418, 65.2, 43.5, "Back entrance" } }, -- Badlands
		instances = { { name = "Uldaman", mapIDs = { 70 }, type = D, min = 41, max = 51 } } },

	{ name = "The Temple of Atal'Hakkar", entrances = { { 1435, 69.9, 53.5 } }, -- Swamp of Sorrows
		instances = { { name = "The Temple of Atal'Hakkar", mapIDs = { 109 }, aliases = { "Sunken Temple", "Temple of Atal'Hakkar" },
			type = D, min = 50, max = 56 } } },

	{ name = "Blackrock Mountain", entrances = { { 1427, 34.8, 85.3 }, { 1428, 29.4, 38.3 } }, -- Searing Gorge / Burning Steppes
		instances = {
			{ name = "Blackrock Depths", mapIDs = { 230 }, type = D, min = 52, max = 60 },
			{ name = "Lower Blackrock Spire", mapIDs = { 229 }, type = D, min = 55, max = 60 },
			{ name = "Upper Blackrock Spire", mapIDs = { 229 }, type = D, min = 58, max = 60 },
			{ name = "Molten Core", mapIDs = { 409 }, unreleased = true, type = R, min = 60, max = 60, size = 40 },
			{ name = "Blackwing Lair", mapIDs = { 469 }, unreleased = true, type = R, min = 60, max = 60, size = 40 },
		} },

	{ name = "Zul'Gurub", entrances = { { 1434, 53.89, 17.6 } }, -- Stranglethorn Vale
		instances = { { name = "Zul'Gurub", mapIDs = { 309 }, unreleased = true, type = R, min = 60, max = 60, size = 20 } } },

	{ name = "Scholomance", entrances = { { 1422, 69.7, 73.2 } }, -- Western Plaguelands
		instances = { { name = "Scholomance", mapIDs = { 289 }, type = D, min = 58, max = 60 } } },

	-- Group browser lists both gates (activities #816 and #1603); either supplies the 58-60 range.
	{ name = "Stratholme", entrances = { { 1423, 26.52, 10.36, "Main Gate" }, { 1423, 41.45, 17.74, "Service Gate" } }, -- Eastern Plaguelands
		instances = { { name = "Stratholme", mapIDs = { 329 }, aliases = { "Stratholme (Main Gate)", "Stratholme (Service Gate)" },
			type = D, min = 58, max = 60 } } },

	-- Not confirmed for Forever (unreleased). VERIFY if enabled: Forever may use its own Naxxramas map (2921). The static point is the Era necropolis;
	-- a recorded entrance replaces it.
	{ name = "Naxxramas", entrances = { { 1423, 34.25, 19.45 } }, verify = true, -- Eastern Plaguelands
		instances = { { name = "Naxxramas", mapIDs = { 533, 2921 }, unreleased = true, type = R, min = 60, max = 60, size = 40 } } },

	---------------------------------------------------------------------------
	-- Kalimdor
	---------------------------------------------------------------------------
	{ name = "Ragefire Chasm", entrances = { { 1454, 52.6, 49.0 } }, -- Orgrimmar
		instances = { { name = "Ragefire Chasm", mapIDs = { 389 }, type = D, min = 13, max = 18 } } },

	{ name = "Wailing Caverns", entrances = { { 1413, 46.0, 36.5 } }, -- The Barrens
		instances = { { name = "Wailing Caverns", mapIDs = { 43 }, type = D, min = 17, max = 24 } } },

	{ name = "Blackfathom Deeps", entrances = { { 1440, 14.5, 14.2 } }, -- Ashenvale
		instances = { { name = "Blackfathom Deeps", mapIDs = { 48 }, type = D, min = 24, max = 32 } } },

	{ name = "Razorfen Kraul", entrances = { { 1413, 42.9, 90.2 } }, -- The Barrens
		instances = { { name = "Razorfen Kraul", mapIDs = { 47 }, type = D, min = 29, max = 38 } } },

	{ name = "Razorfen Downs", entrances = { { 1413, 49.0, 93.9 } }, -- The Barrens
		instances = { { name = "Razorfen Downs", mapIDs = { 129 }, type = D, min = 37, max = 46 } } },

	{ name = "Zul'Farrak", entrances = { { 1446, 38.7, 20.1 } }, -- Tanaris
		instances = { { name = "Zul'Farrak", mapIDs = { 209 }, aliases = { "Zul'Farak" }, type = D, min = 44, max = 54 } } },

	{ name = "Maraudon", entrances = { { 1443, 29.1, 62.5 } }, -- Desolace
		instances = { { name = "Maraudon", mapIDs = { 349 }, type = D, min = 46, max = 55 } } },

	-- All three wings share instance map 429.
	{ name = "Dire Maul - North", entrances = { { 1444, 62.5, 24.9 } }, -- Feralas
		instances = { { name = "Dire Maul - North", mapIDs = { 429 }, type = D, min = 57, max = 60 } } },

	{ name = "Dire Maul - West", entrances = { { 1444, 60.3, 30.2 } }, -- Feralas
		instances = { { name = "Dire Maul - West", mapIDs = { 429 }, type = D, min = 57, max = 60 } } },

	{ name = "Dire Maul - East", entrances = { { 1444, 64.8, 30.2 } }, -- Feralas
		instances = { { name = "Dire Maul - East", mapIDs = { 429 }, type = D, min = 55, max = 60 } } },

	{ name = "Onyxia's Lair", entrances = { { 1445, 52.6, 76.8 } }, -- Dustwallow Marsh. Forever launch raid.
		instances = { { name = "Onyxia's Lair", mapIDs = { 249 }, aliases = { "Onyxia" }, type = R, min = 60, max = 60, size = 40 } } },

	{ name = "Gates of Ahn'Qiraj", entrances = { { 1451, 28.6, 92.3 } }, -- Silithus
		instances = {
			{ name = "Ruins of Ahn'Qiraj", mapIDs = { 509 }, unreleased = true, aliases = { "Ahn'Qiraj Ruins", "AQ20" }, type = R, min = 60, max = 60, size = 20 },
			{ name = "Temple of Ahn'Qiraj", mapIDs = { 531 }, unreleased = true, aliases = { "Ahn'Qiraj Temple", "AQ40" }, type = R, min = 60, max = 60, size = 40 },
		} },

	---------------------------------------------------------------------------
	-- Forever's new dungeons. Ranges are Blizzard's published ones (official = true). Hints are Blizzard's
	-- descriptions; sites without static entrances get a pin once an entrance is recorded in-game.
	---------------------------------------------------------------------------
	{ name = "The Hall of Thanes", entrances = {},
		hint = "Beneath Ironforge, Dun Morogh. Horde must travel into Alliance territory.",
		instances = { { name = "The Hall of Thanes", mapIDs = { 3065 }, aliases = { "Hall of Thanes" }, type = D, min = 13, max = 18, official = true } } },

	{ name = "Ruins of Lordaeron", entrances = {},
		hint = "Within the ruined city above the Undercity, Tirisfal Glades.",
		instances = { { name = "Ruins of Lordaeron", mapIDs = { 2999 }, type = D, min = 15, max = 20, official = true } } },

	{ name = "Excavation Site: Wetlands", entrances = { { 1437, 47.79, 56.16 } }, -- Questie point
		hint = "Near Thelgen Rock and Dun Algaz, above Whelgar's Excavation, Wetlands.",
		instances = { { name = "Excavation Site: Wetlands", mapIDs = { 2998 }, type = D, min = 24, max = 29, official = true } } },

	{ name = "City of Dalaran", entrances = { { 1416, 8.46, 59.21 } }, -- Questie point
		hint = "Alterac Mountains, entered through the sewers.",
		attunement = "Alliance: \"An Alarming Request\" (Emissary Jacques, Southshore). Horde: \"Key to the City\" and \"Prison Break-In\" (Magus Wordeen Voidglare, Tarren Mill).",
		instances = { { name = "City of Dalaran", mapIDs = { 2959 }, type = D, min = 28, max = 33, official = true } } },

	{ name = "The Drowned City", entrances = {},
		hint = "Off the coast of Stranglethorn Vale, west of Grom'gol. The entrance is underwater.",
		instances = { { name = "The Drowned City", mapIDs = { 2970 }, type = D, min = 35, max = 40, official = true } } },

	{ name = "Krol'dok Stronghold", entrances = {},
		hint = "Riverglades (new zone).",
		instances = { { name = "Krol'dok Stronghold", mapIDs = { 3039 }, type = D, min = 40, max = 45, official = true } } },

	{ name = "Alcaz Prison", entrances = {},
		hint = "Alcaz Island, Dustwallow Marsh.",
		instances = { { name = "Alcaz Prison", mapIDs = { 2994 }, type = D, min = 48, max = 53, official = true } } },

	-- The Barrow Deeps raid is reached through Blackmaw Hold, so both share this site and its entrance.
	{ name = "Blackmaw Hold", entrances = {},
		hint = "Beyond a long-sealed gate in Azshara. The Barrow Deeps raid is reached through Blackmaw Hold.",
		instances = {
			{ name = "Blackmaw Hold", mapIDs = { 2974 }, type = D, min = 55, max = 60, official = true },
			{ name = "The Barrow Deeps", mapIDs = {}, aliases = { "Barrow Deeps" }, type = R, min = 60, max = 60, size = 10, official = true },
		} },

	{ name = "The Shaper's Terrace", entrances = {},
		hint = "The northern hills of Un'Goro Crater.",
		instances = { { name = "The Shaper's Terrace", mapIDs = { 3001 }, aliases = { "Shaper's Terrace" }, type = D, min = 58, max = 60, official = true } } },

	---------------------------------------------------------------------------
	-- Forever launch raids without coordinates yet (Onyxia's Lair is above; The Barrow Deeps is in Blackmaw Hold).
	---------------------------------------------------------------------------
	{ name = "Hyjal Summit", entrances = {},
		hint = "Mount Hyjal (new zone).",
		instances = { { name = "Hyjal Summit", mapIDs = {}, type = R, min = 60, max = 60, size = 20, official = true } } },

	---------------------------------------------------------------------------
	-- Questie-listed Forever areas the client hasn't confirmed (not drawn unless confirmed or recorded).
	---------------------------------------------------------------------------
	{ name = "Demon Fall Canyon", candidate = true, entrances = { { 1440, 84.7, 74.4 } }, -- Ashenvale
		instances = { { name = "Demon Fall Canyon", mapIDs = { 2784 }, unknownType = true } } },
	{ name = "The Tainted Scar", candidate = true, entrances = { { 1419, 45.3, 55.0 } }, -- Blasted Lands
		instances = { { name = "The Tainted Scar", mapIDs = { 2789 }, unknownType = true } } },
	{ name = "Karazhan Crypts", candidate = true, entrances = { { 1430, 39.99, 74.16 } }, -- Deadwind Pass
		instances = { { name = "Karazhan Crypts", mapIDs = { 2875 }, unknownType = true } } },
	{ name = "Scarlet Enclave", candidate = true, entrances = { { 1423, 60.14, 75.32 } }, -- Eastern Plaguelands
		instances = { { name = "Scarlet Enclave", mapIDs = { 2856 }, unknownType = true } } },
	{ name = "The Burning of Andorhal", candidate = true, entrances = { { 1422, 69.6, 79.6 } }, -- Western Plaguelands
		instances = { { name = "The Burning of Andorhal", mapIDs = { 2807 }, unknownType = true, aliases = { "Burning of Andorhal" } } } },
}

-- Forever zones seen in client data (not instances); noted for Travel/Services coverage later:
-- Riverglades (33-54), Mount Hyjal (55-60).
