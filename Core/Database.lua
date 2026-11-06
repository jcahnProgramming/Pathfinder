-- SavedVariables: defaults, migrations and setting accessors.
--   PathfinderDB      (account)   settings, custom pins, groups, last API report
--   PathfinderCharDB  (character) cached known flight path nodes
local _, ns = ...

local Database = ns:NewModule("Database")

Database.SCHEMA = 1

-- Incoming-share handling modes (see Settings).
ns.SHARE_MODE = {
	AUTO = "auto",       -- auto-add to "Shared with me"
	POPUP = "popup",     -- ask with Accept / Decline (default)
	TRUSTED = "trusted", -- ask for friends and guild members only, ignore everyone else
}

Database.accountDefaults = {
	schema = Database.SCHEMA,
	settings = {
		showFlightPaths = true,
		showDungeons = true,
		showRaids = true,
		showCustom = true,
		showOnMinimap = true,
		pinScale = 1.0,
		incomingShareMode = ns.SHARE_MODE.POPUP,
		apiCheckOnLogin = true,
		debug = false,
	},
	groups = {},   -- [groupID] = { name = string, shown = bool }
	pins = {},     -- [pinID]   = { name, icon, color, mapID, x, y, group }
	nextID = 1,
}

Database.charDefaults = {
	schema = Database.SCHEMA,
	knownTaxiNodes = {},   -- [nodeID] = true, cached whenever a flight map is opened
	knownTaxiScanned = 0,  -- time() of last flight-map scan, 0 = never
}

local function applyDefaults(target, defaults)
	for key, value in pairs(defaults) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then target[key] = {} end
			applyDefaults(target[key], value)
		elseif target[key] == nil or type(target[key]) ~= type(value) then
			target[key] = value
		end
	end
end

local function migrate(db)
	-- No migrations yet. Future schema bumps go here, keyed on db.schema.
	db.schema = Database.SCHEMA
end

function Database:OnInitialize()
	if type(PathfinderDB) ~= "table" then PathfinderDB = {} end
	if type(PathfinderCharDB) ~= "table" then PathfinderCharDB = {} end

	migrate(PathfinderDB)
	migrate(PathfinderCharDB)
	applyDefaults(PathfinderDB, self.accountDefaults)
	applyDefaults(PathfinderCharDB, self.charDefaults)

	ns.db = PathfinderDB
	ns.charDB = PathfinderCharDB
end

function ns:GetSetting(key)
	return ns.db.settings[key]
end

-- For code paths other than the Settings panel (which writes the table itself).
function ns:SetSetting(key, value)
	if ns.db.settings[key] == value then return end
	ns.db.settings[key] = value
	ns:Fire("SETTING_CHANGED", key, value)
end

function ns:NewID()
	local id = ns.db.nextID
	ns.db.nextID = id + 1
	return id
end
