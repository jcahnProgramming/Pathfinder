-- Probes which map/waypoint/taxi/journal APIs this client actually exposes and how well they work.
-- The full report is also saved to PathfinderDB.apiReport so it can be inspected outside the game.
local _, ns = ...

local APICheck = ns:NewModule("APICheck")

local OK, PARTIAL, MISSING = "ok", "partial", "missing"
local STATUS_TEXT = {
	[OK] = "|cff33ff33OK|r",
	[PARTIAL] = "|cffffcc00PARTIAL|r",
	[MISSING] = "|cffff3333MISSING|r",
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function resolve(path)
	local t = _G
	for part in path:gmatch("[^%.]+") do
		if type(t) ~= "table" then return nil end
		t = t[part]
	end
	return t
end

local function isSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

-- Copies a value into plain SavedVariables-safe data (no functions, bounded depth, secrets masked).
local function sanitize(value, depth)
	depth = depth or 0
	if isSecret(value) then return "<secret>" end
	local t = type(value)
	if t == "number" or t == "boolean" then
		return value
	elseif t == "string" then
		return value:sub(1, 200)
	elseif t == "table" and depth < 3 then
		local out = {}
		for k, v in pairs(value) do
			if type(k) == "string" or type(k) == "number" then
				local s = sanitize(v, depth + 1)
				if s ~= nil then out[k] = s end
			end
		end
		return out
	end
	return nil
end

local function missingFrom(paths)
	local missing = {}
	for _, path in ipairs(paths) do
		if resolve(path) == nil then table.insert(missing, path) end
	end
	return missing
end

local function call(fn, ...)
	local ok, a, b = pcall(fn, ...)
	if not ok then return false, a end
	return true, a, b
end

local function mapName(mapID)
	local info = mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
	return info and info.name or ("map " .. tostring(mapID))
end

---------------------------------------------------------------------------
-- 1. Native user waypoint + super-tracking arrow
---------------------------------------------------------------------------
local function checkWaypoint()
	local result = { id = "waypoint", label = "1. User waypoint + arrow" }
	local core = missingFrom({
		"C_Map.SetUserWaypoint",
		"C_SuperTrack.SetSuperTrackedUserWaypoint",
		"UiMapPoint.CreateFromCoordinates",
	})
	local extra = missingFrom({
		"C_Map.CanSetUserWaypointOnMap",
		"C_Map.ClearUserWaypoint",
		"C_Map.HasUserWaypoint",
		"C_Map.GetUserWaypoint",
		"C_SuperTrack.IsSuperTrackingUserWaypoint",
	})
	result.missing = { core = core, extra = extra }

	if #core > 0 then
		result.status = MISSING
		result.detail = "missing: " .. table.concat(core, ", ")
		return result
	end

	local mapID = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	local canSet
	if mapID and C_Map.CanSetUserWaypointOnMap then
		local ok, value = call(C_Map.CanSetUserWaypointOnMap, mapID)
		canSet = ok and value or false
	end
	result.data = { playerMapID = mapID, canSetOnPlayerMap = canSet }

	if #extra > 0 or canSet == false then
		result.status = PARTIAL
	else
		result.status = OK
	end
	result.detail = ("can set on %s (%s): %s%s"):format(
		mapName(mapID), tostring(mapID), canSet and "yes" or "no",
		#extra > 0 and ("; missing " .. table.concat(extra, ", ")) or "")
	return result
end

---------------------------------------------------------------------------
-- 2. Flight master positions + faction
---------------------------------------------------------------------------
local TAXI_TEST_MAPS = { 1415, 1414, 1429, 1411, 1434, 1446 } -- EK, Kalimdor, Elwynn, Durotar, STV, Tanaris

local function checkTaxi()
	local result = { id = "taxi", label = "2. C_TaxiMap.GetTaxiNodesForMap" }
	local fn = C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap
	if not fn then
		result.status = MISSING
		result.detail = "not present; will use static flight master table"
		return result
	end

	local total, withFaction, factions, perMap, samples = 0, 0, {}, {}, {}
	for _, mapID in ipairs(TAXI_TEST_MAPS) do
		local ok, nodes = call(fn, mapID)
		local count = 0
		if ok and type(nodes) == "table" then
			for _, node in ipairs(nodes) do
				count = count + 1
				if node.faction ~= nil and not isSecret(node.faction) then
					withFaction = withFaction + 1
					local key = tostring(node.faction)
					factions[key] = (factions[key] or 0) + 1
				end
				if #samples < 4 then table.insert(samples, sanitize(node)) end
			end
		end
		perMap[mapID] = ok and count or ("error: " .. tostring(nodes))
		total = total + count
	end

	result.data = {
		perMap = perMap,
		factionCounts = factions,
		samples = samples,
		hasGetAllTaxiNodes = C_TaxiMap.GetAllTaxiNodes ~= nil,
		enumFlightPathFaction = sanitize(Enum and Enum.FlightPathFaction),
		enumFlightPathState = sanitize(Enum and Enum.FlightPathState),
	}

	if total == 0 then
		result.status = PARTIAL
		result.detail = "present but returned 0 nodes; will use static flight master table"
	elseif withFaction < total then
		result.status = PARTIAL
		result.detail = ("%d nodes, only %d with faction; static faction data needed"):format(total, withFaction)
	else
		result.status = OK
		local parts = {}
		for k, v in pairs(factions) do table.insert(parts, k .. "=" .. v) end
		table.sort(parts)
		result.detail = ("%d nodes across test maps (faction %s)"):format(total, table.concat(parts, " "))
	end
	return result
end

---------------------------------------------------------------------------
-- 3. Dungeon / raid entrances
---------------------------------------------------------------------------
-- Zones that contain classic instance entrances, plus both continents.
local ENTRANCE_TEST_MAPS = {
	1415, 1414,         -- continents
	1436,               -- Westfall: The Deadmines
	1420,               -- Tirisfal: Scarlet Monastery
	1418,               -- Badlands: Uldaman
	1428, 1427,         -- Burning Steppes / Searing Gorge: Blackrock Mountain
	1434,               -- Stranglethorn: Zul'Gurub
	1446,               -- Tanaris: Zul'Farrak
	1445,               -- Dustwallow: Onyxia's Lair
	1451,               -- Silithus: Ahn'Qiraj
	1423,               -- Eastern Plaguelands: Stratholme / Naxxramas
}

local function checkEntrances()
	local result = { id = "entrances", label = "3. C_EncounterJournal.GetDungeonEntrancesForMap" }
	local fn = C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap
	if not fn then
		result.status = MISSING
		result.detail = "not present; will use static entrance table"
		return result
	end

	local total, zonesWithData, perMap, samples = 0, 0, {}, {}
	for _, mapID in ipairs(ENTRANCE_TEST_MAPS) do
		local ok, entrances = call(fn, mapID)
		local count = 0
		if ok and type(entrances) == "table" then
			for _, entrance in ipairs(entrances) do
				count = count + 1
				if #samples < 6 then
					local s = sanitize(entrance) or {}
					s._mapID = mapID
					table.insert(samples, s)
				end
			end
		end
		if count > 0 and mapID ~= 1415 and mapID ~= 1414 then zonesWithData = zonesWithData + 1 end
		perMap[mapID] = ok and count or ("error: " .. tostring(entrances))
		total = total + count
	end
	result.data = {
		perMap = perMap,
		samples = samples,
		hasEJ_GetInstanceInfo = EJ_GetInstanceInfo ~= nil,
	}

	local zoneCount = #ENTRANCE_TEST_MAPS - 2
	if total == 0 then
		result.status = PARTIAL
		result.detail = "present but returned 0 entrances; will use static entrance table"
	elseif zonesWithData < zoneCount then
		result.status = PARTIAL
		result.detail = ("%d entrances; only %d/%d test zones returned data"):format(total, zonesWithData, zoneCount)
	else
		result.status = OK
		result.detail = ("%d entrances across %d test zones (level ranges still come from static data)"):format(total, zoneCount)
	end
	return result
end

---------------------------------------------------------------------------
-- 4. User-waypoint chat hyperlink
---------------------------------------------------------------------------
local function buildManualLink(mapID, x, y)
	return ns.Waypoint.BuildLink(mapID, x, y)
end

local function checkHyperlink(previous)
	local result = { id = "hyperlink", label = "4. User-waypoint chat hyperlink" }
	local fn = C_Map and C_Map.GetUserWaypointHyperlink
	local prevData = previous and previous.data or {}
	result.data = { linkTest = prevData.linkTest }
	if not fn then
		result.status = MISSING
		result.detail = "C_Map.GetUserWaypointHyperlink not present; will build |Hworldmap| links manually"
		return result
	end

	if C_Map.HasUserWaypoint and C_Map.HasUserWaypoint() then
		local ok, link = call(fn)
		if ok and type(link) == "string" and link ~= "" and not isSecret(link) then
			result.status = OK
			result.data.currentLink = link:gsub("|", "||")
			result.detail = "works: " .. link
			return result
		end
	end

	if prevData.linkTest and prevData.linkTest.ok then
		result.status = OK
		result.detail = "verified by /pf linktest"
	else
		result.status = PARTIAL
		result.detail = "function present, not yet verified; run |cffffff00/pf linktest|r"
	end
	return result
end

---------------------------------------------------------------------------
-- Supporting APIs (informational, used by later phases)
---------------------------------------------------------------------------
local SUPPORT_GROUPS = {
	{ label = "MapCanvas", paths = { "WorldMapFrame.AddDataProvider", "MapCanvasDataProviderMixin", "MapCanvasPinMixin" } },
	{ label = "Minimap math", paths = { "C_Map.GetPlayerMapPosition", "C_Map.GetWorldPosFromMapPos", "Minimap.GetZoom" } },
	{ label = "Minimap radius", paths = { "C_Minimap.GetViewRadius" } },
	{ label = "Addon messages", paths = { "C_ChatInfo.RegisterAddonMessagePrefix", "C_ChatInfo.SendAddonMessage" } },
	{ label = "Chat lockdown check", paths = { "C_ChatInfo.InChatMessagingLockdown" } },
	{ label = "Settings panel", paths = { "Settings.RegisterVerticalLayoutCategory", "Settings.RegisterAddOnSetting", "Settings.CreateDropdown" } },
	{ label = "Friends/guild", paths = { "C_FriendList.IsFriend", "C_BattleNet.GetFriendAccountInfo", "C_GuildInfo.MemberExistsByName" } },
	{ label = "Secret values", paths = { "issecretvalue" } },
	{ label = "Native flight map pins", paths = { "FlightPointDataProviderMixin" } },
	{ label = "Native entrance pins", paths = { "DungeonEntranceDataProviderMixin" } },
}

local function checkSupport()
	local out = {}
	for _, group in ipairs(SUPPORT_GROUPS) do
		local missing = missingFrom(group.paths)
		local status = #missing == 0 and OK or (#missing == #group.paths and MISSING or PARTIAL)
		table.insert(out, { label = group.label, status = status, missing = missing })
	end
	return out
end

---------------------------------------------------------------------------
-- Run + report
---------------------------------------------------------------------------
function APICheck:Run()
	local previous = {}
	for _, r in ipairs((ns.db.apiReport and ns.db.apiReport.results) or {}) do previous[r.id] = r end

	local version, build, _, interface = GetBuildInfo()
	local report = {
		time = time(),
		addonVersion = ns.version,
		client = { version = version, build = build, interface = interface, projectID = WOW_PROJECT_ID },
		results = {
			checkWaypoint(),
			checkTaxi(),
			checkEntrances(),
			checkHyperlink(previous.hyperlink),
		},
		support = checkSupport(),
	}
	ns.db.apiReport = report
	self.report = report
	return report
end

function APICheck:Get(id)
	for _, r in ipairs((self.report and self.report.results) or {}) do
		if r.id == id then return r end
	end
end

-- verbose = /pf api (full report to the debug window); otherwise the short login summary in chat.
function APICheck:PrintReport(verbose)
	local report = self.report or self:Run()
	local c = report.client
	local out = ns:NewReport(("v%s API check (client %s build %s, interface %s)"):format(
		ns.version, tostring(c.version), tostring(c.build), tostring(c.interface)))
	for _, r in ipairs(report.results) do
		out:Add("%s: %s  |cffaaaaaa%s|r", r.label, STATUS_TEXT[r.status], r.detail or "")
	end

	if verbose then
		out:Add("")
		out:Add("Supporting APIs:")
		for _, s in ipairs(report.support) do
			local extra = #s.missing > 0 and ("  missing " .. table.concat(s.missing, ", ")) or ""
			out:Add("  - %s: %s%s", s.label, STATUS_TEXT[s.status], extra)
		end
		out:Add("")
		out:Add("Full data is saved to PathfinderDB.apiReport on /reload or logout.")
		out:ToWindow()
	else
		local bad = 0
		for _, s in ipairs(report.support) do if s.status ~= OK then bad = bad + 1 end end
		out:Add("Supporting APIs: %d/%d OK. Type |cffffff00/pf api|r for details.", #report.support - bad, #report.support)
		out:ToChat()
	end
end

-- Sets a temporary waypoint at the player, prints the native hyperlink next to a manually
-- built one, then restores whatever waypoint the player had before.
function APICheck:LinkTest()
	local fn = C_Map and C_Map.GetUserWaypointHyperlink
	if not (fn and C_Map.SetUserWaypoint and UiMapPoint) then
		ns:Print("Link test: native waypoint/hyperlink API missing.")
		return
	end

	local mapID = C_Map.GetBestMapForUnit("player")
	local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
	if not pos or isSecret(pos) or not C_Map.CanSetUserWaypointOnMap(mapID) then
		ns:Print("Link test: can't place a waypoint here. Try again outdoors in a normal zone.")
		return
	end
	local x, y = pos:GetXY()

	local hadWaypoint = C_Map.HasUserWaypoint() and C_Map.GetUserWaypoint()
	local wasTracking = C_SuperTrack.IsSuperTrackingUserWaypoint and C_SuperTrack.IsSuperTrackingUserWaypoint()

	C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
	local ok, link = call(fn)

	if hadWaypoint then
		C_Map.SetUserWaypoint(hadWaypoint)
		if wasTracking then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
	else
		C_Map.ClearUserWaypoint()
	end

	local manual = buildManualLink(mapID, x, y)
	local works = ok and type(link) == "string" and link ~= "" and not isSecret(link)

	local out = ns:NewReport("Link test (nothing was sent)")
	out:Add("Native link: %s", works and "OK" or ("FAILED " .. tostring(link)))
	if works then out:Add("  raw: %s", link) end
	out:Add("Manual link raw: %s", manual)
	out:Add("Both links were also printed in chat, since links can only be clicked there.")
	out:ToWindow()
	-- The links themselves must stay in chat to be clickable.
	if works then DEFAULT_CHAT_FRAME:AddMessage("  Native: " .. link) end
	DEFAULT_CHAT_FRAME:AddMessage("  Manual: " .. manual)

	local r = self:Get("hyperlink")
	if r then
		r.data = r.data or {}
		r.data.linkTest = {
			ok = works,
			native = works and link:gsub("|", "||") or nil,
			manual = manual:gsub("|", "||"),
		}
		if works then
			r.status = OK
			r.detail = "verified by /pf linktest"
		end
	end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
local ranOnce = false
function APICheck:OnEnable()
	ns:RegisterEvent("PLAYER_ENTERING_WORLD", function()
		if ranOnce then return end
		ranOnce = true
		-- Give the map system a moment to settle after the loading screen.
		C_Timer.After(2, function()
			APICheck:Run()
			if ns:GetSetting("apiCheckOnLogin") then APICheck:PrintReport(false) end
		end)
	end)
end
