-- Flight path layer: every flight master from C_TaxiMap.GetTaxiNodesForMap, ringed by status.
--   green  = discovered by this character (cached at flight masters, see Core\TaxiCache.lua)
--   yellow = usable by this character but not discovered yet (own faction or neutral)
--   red    = opposite faction, can never be discovered
local _, ns = ...

local FlightPaths = ns:NewModule("FlightPaths")

local TEMPLATE = "PathfinderFlightPinTemplate"
local FACTION = Enum.FlightPathFaction or { Neutral = 0, Horde = 1, Alliance = 2 }

local STATUS = { DISCOVERED = "discovered", AVAILABLE = "available", UNAVAILABLE = "unavailable" }
FlightPaths.STATUS = STATUS

local STATUS_COLOR = {
	[STATUS.DISCOVERED] = { 0.20, 1.00, 0.20 },
	[STATUS.AVAILABLE] = { 1.00, 0.82, 0.00 },
	[STATUS.UNAVAILABLE] = { 1.00, 0.20, 0.20 },
}

local STATUS_TEXT = {
	[STATUS.DISCOVERED] = "Discovered",
	[STATUS.AVAILABLE] = "Not discovered yet",
	[STATUS.UNAVAILABLE] = "Unavailable to your faction",
}

local FALLBACK_ATLAS = {
	[FACTION.Neutral] = "TaxiNode_Neutral",
	[FACTION.Horde] = "TaxiNode_Horde",
	[FACTION.Alliance] = "TaxiNode_Alliance",
}

-- Map types that get flight pins: continents and zones (plus micro/orphan maps such as cities).
local SHOWN_MAP_TYPES = {
	[Enum.UIMapType.Continent] = true,
	[Enum.UIMapType.Zone] = true,
	[Enum.UIMapType.Micro] = true,
	[Enum.UIMapType.Orphan] = true,
}

local function factionName(faction)
	for name, value in pairs(FACTION) do
		if value == faction then return name end
	end
	return tostring(faction)
end

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------
function FlightPaths:GetPlayerFaction()
	local faction = UnitFactionGroup("player")
	return FACTION[faction]
end

function FlightPaths:GetStatus(node)
	if ns.TaxiCache:IsKnown(node.nodeID) then return STATUS.DISCOVERED end
	if node.faction == nil or node.faction == FACTION.Neutral or node.faction == self:GetPlayerFaction() then
		return STATUS.AVAILABLE
	end
	return STATUS.UNAVAILABLE
end

-- Nodes for one map, de-duplicated by nodeID and limited to positions inside the map.
function FlightPaths:GetNodesForMap(mapID)
	local ok, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, mapID)
	local out, seen = {}, {}
	if not ok or type(nodes) ~= "table" then return out end
	for _, node in ipairs(nodes) do
		local id, pos = node.nodeID, node.position
		if id and pos and not seen[id] then
			local x, y = pos.x, pos.y
			if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
				seen[id] = true
				table.insert(out, node)
			end
		end
	end
	return out
end

local function tooltip(tt, data)
	local c = data.color
	tt:AddLine(data.name, 1, 1, 1)
	tt:AddLine(STATUS_TEXT[data.status], c[1], c[2], c[3])
end

function FlightPaths:BuildPinData(node, mapID)
	local status = self:GetStatus(node)
	return {
		mapID = mapID,
		x = node.position.x,
		y = node.position.y,
		name = node.name or "Flight Master",
		nodeID = node.nodeID,
		status = status,
		color = STATUS_COLOR[status],
		atlas = node.atlasName or FALLBACK_ATLAS[node.faction] or FALLBACK_ATLAS[FACTION.Neutral],
		tooltip = tooltip,
	}
end

---------------------------------------------------------------------------
-- World map data provider
---------------------------------------------------------------------------
local Provider = CreateFromMixins(MapCanvasDataProviderMixin)

function Provider:RemoveAllData()
	self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
end

local function refresh(provider)
	provider:RemoveAllData()
	if not ns:IsLayerShown("showFlightPaths") then return end

	local map = provider:GetMap()
	local mapID = map:GetMapID()
	local info = mapID and C_Map.GetMapInfo(mapID)
	if not info or not SHOWN_MAP_TYPES[info.mapType] then return end

	ns:SafeAcquirePins(map, TEMPLATE, FlightPaths:GetNodesForMap(mapID), function(node)
		return FlightPaths:BuildPinData(node, mapID)
	end)
end

local refreshErrorShown = false
function Provider:RefreshAllData()
	-- Never let a Pathfinder error break Blizzard's map refresh.
	local ok, err = pcall(refresh, self)
	if not ok and not refreshErrorShown then
		refreshErrorShown = true
		ns:Print("|cffff3333flight path layer error (shown once). Please report:|r %s", tostring(err))
	end
end

function FlightPaths:Refresh()
	local map = Provider:GetMap()
	if map and map:IsShown() then Provider:RefreshAllData() end
end

function FlightPaths:OnEnable()
	ns:OnWorldMapReady(function(worldMap)
		worldMap:AddDataProvider(Provider)
	end)

	ns:On("SETTING_CHANGED", function(key)
		if key == "pinScale" or ns:AffectsLayer("showFlightPaths", key) then FlightPaths:Refresh() end
	end)
	ns:On("TAXI_CACHE_UPDATED", function() FlightPaths:Refresh() end)
end

---------------------------------------------------------------------------
-- /pf taxi: sanity check of faction mapping, cache, and status counts
---------------------------------------------------------------------------
function FlightPaths:PrintDebug()
	local out = ns:NewReport("Flight path check")
	local enumParts = {}
	for name, value in pairs(FACTION) do table.insert(enumParts, ("%d = %s"):format(value, name)) end
	table.sort(enumParts)
	local source = Enum.FlightPathFaction and "Enum.FlightPathFaction" or "built-in fallback"
	out:Add("Faction enum (%s): %s", source, table.concat(enumParts, ", "))

	local playerFaction = UnitFactionGroup("player")
	out:Add("You: %s (enum %s). Known flight paths cached: %d.",
		tostring(playerFaction), tostring(self:GetPlayerFaction()), ns.TaxiCache:CountKnown())

	local scan = ns.charDB.lastTaxiScan
	if scan then
		local states = {}
		for k, v in pairs(scan.states or {}) do table.insert(states, k .. "=" .. v) end
		table.sort(states)
		out:Add("Last flight-master scan (%s): %d nodes returned, states %s, %d new.",
			tostring(scan.source), scan.returned or 0, #states > 0 and table.concat(states, " ") or "none", scan.added or 0)
	else
		out:Add("No flight-master scan yet. Open any flight master's map to cache known paths.")
	end

	local continent = ns:GetContinentForMap(C_Map.GetBestMapForUnit("player"))
	if not continent then
		out:Add("Can't determine your continent here.")
		out:ToWindow()
		return
	end
	local nodes = self:GetNodesForMap(continent)
	local counts, samples = {}, {}
	for _, node in ipairs(nodes) do
		local status = self:GetStatus(node)
		counts[status] = (counts[status] or 0) + 1
		local f = node.faction or -1
		samples[f] = samples[f] or {}
		if #samples[f] < 2 then table.insert(samples[f], node) end
	end
	out:Add("%s: %d nodes, %d discovered, %d not discovered, %d unavailable.",
		C_Map.GetMapInfo(continent).name, #nodes, counts[STATUS.DISCOVERED] or 0, counts[STATUS.AVAILABLE] or 0, counts[STATUS.UNAVAILABLE] or 0)

	for _, f in ipairs({ FACTION.Neutral, FACTION.Horde, FACTION.Alliance }) do
		for _, node in ipairs(samples[f] or {}) do
			out:Add("  #%d %s: faction %d (%s), atlas %s -> %s",
				node.nodeID, node.name or "?", node.faction, factionName(node.faction), tostring(node.atlasName),
				STATUS_TEXT[self:GetStatus(node)])
		end
	end
	out:ToWindow()
end
