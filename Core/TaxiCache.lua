-- Per-character cache of discovered flight paths. The client only says which nodes are known
-- while a flight master's map is open, so every TAXIMAP_OPENED is scanned and merged in.
-- Nodes that were never seen in a scan count as "not discovered yet".
local _, ns = ...

local TaxiCache = ns:NewModule("TaxiCache")

local STATE = Enum.FlightPathState or { Current = 0, Reachable = 1, Unreachable = 2 }

function TaxiCache:IsKnown(nodeID)
	return ns.charDB.knownTaxiNodes[nodeID] == true
end

function TaxiCache:CountKnown()
	local n = 0
	for _ in pairs(ns.charDB.knownTaxiNodes) do n = n + 1 end
	return n
end

local function taxiMapIDs()
	local ids, seen = {}, {}
	local function add(id)
		if id and not seen[id] then seen[id] = true; table.insert(ids, id) end
	end
	if GetTaxiMapID then add(GetTaxiMapID()) end
	add(ns:GetContinentForMap(C_Map.GetBestMapForUnit("player")))
	return ids
end

-- Primary source: C_TaxiMap.GetAllTaxiNodes, which only lists nodes this character knows.
-- "Unreachable" nodes are skipped to stay conservative.
local function scanModern(mapIDs, found, stats)
	if not C_TaxiMap.GetAllTaxiNodes then return end
	for _, mapID in ipairs(mapIDs) do
		local ok, nodes = pcall(C_TaxiMap.GetAllTaxiNodes, mapID)
		if ok and type(nodes) == "table" then
			for _, node in ipairs(nodes) do
				stats.returned = stats.returned + 1
				local key = tostring(node.state)
				stats.states[key] = (stats.states[key] or 0) + 1
				if node.nodeID and node.state ~= STATE.Unreachable then
					found[node.nodeID] = true
				end
			end
		end
	end
end

-- Fallback: the legacy taxi frame API, matched to node IDs by name.
local function scanLegacy(mapIDs, found, stats)
	if not (NumTaxiNodes and TaxiNodeName and TaxiNodeGetType) then return end
	local idByName = {}
	for _, mapID in ipairs(mapIDs) do
		local ok, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, mapID)
		if ok and type(nodes) == "table" then
			for _, node in ipairs(nodes) do
				if node.name then idByName[node.name] = node.nodeID end
			end
		end
	end
	for i = 1, NumTaxiNodes() do
		local nodeType = TaxiNodeGetType(i)
		stats.returned = stats.returned + 1
		stats.states[nodeType or "nil"] = (stats.states[nodeType or "nil"] or 0) + 1
		local id = idByName[TaxiNodeName(i)]
		if id and (nodeType == "CURRENT" or nodeType == "REACHABLE") then
			found[id] = true
		end
	end
end

function TaxiCache:Scan()
	local mapIDs = taxiMapIDs()
	local found = {}
	local stats = { returned = 0, states = {}, source = "GetAllTaxiNodes" }

	scanModern(mapIDs, found, stats)
	if next(found) == nil then
		stats.source = "legacy"
		stats.returned, stats.states = 0, {}
		scanLegacy(mapIDs, found, stats)
	end

	local known = ns.charDB.knownTaxiNodes
	local firstScan = ns.charDB.knownTaxiScanned == 0
	local added = 0
	for id in pairs(found) do
		if not known[id] then
			known[id] = true
			added = added + 1
		end
	end

	stats.time = time()
	stats.mapIDs = mapIDs
	stats.added = added
	ns.charDB.lastTaxiScan = stats
	if next(found) ~= nil then ns.charDB.knownTaxiScanned = stats.time end

	ns:Debug("taxi scan via %s: %d returned, %d known, %d new", stats.source, stats.returned, self:CountKnown(), added)
	if added > 0 then
		if firstScan then
			ns:Print("Cached %d known flight paths for this character.", self:CountKnown())
		else
			ns:Print("New flight path cached (%d known).", self:CountKnown())
		end
		ns:Fire("TAXI_CACHE_UPDATED")
	end
end

function TaxiCache:OnEnable()
	ns:RegisterEvent("TAXIMAP_OPENED", function()
		TaxiCache:Scan()
		-- Node data can arrive a moment after the frame opens; scan once more.
		C_Timer.After(0.3, function() TaxiCache:Scan() end)
	end)
end
