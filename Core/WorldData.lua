-- Account-wide world data store: things observed in the world, as opposed to the player's own custom
-- pins. Phase 7's realm sync will exchange this data (never custom pins), so every observation keeps
-- its reporter and the two-reporter trust rule can be applied later.
--
-- PathfinderDB.world = {
--   schema = 1,
--   entrances = {
--     [instanceMapID] = {
--       name, kind ("dungeon" | "raid"),
--       clusters = { { mapID, x, y, continentID, wx, wy, count, first, last, reporters = { [charKey] = n } } },
--       walkIns = n, groupFinderEntries = n, lastEntered = time,
--     },
--   },
--   log = { { time, instanceMapID, name, result, reason }, ... }   -- newest last, capped
-- }
local _, ns = ...

local WorldData = ns:NewModule("WorldData")

local CLUSTER_RADIUS_YARDS = 40   -- recordings closer than this are the same entrance
local QUEUE_ONLY_MIN_ENTRIES = 2  -- group-finder entries (and zero walk-ins) before "Group finder only"
local LOG_MAX = 40
WorldData.STATIC_DIFF_YARDS = 30  -- recorded vs static distance worth reporting

function WorldData:OnInitialize()
	self.db = ns.db.world
end

function ns:GetCharacterKey()
	local name = UnitName("player") or "?"
	local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName() or "?"
	return name .. "-" .. realm
end

---------------------------------------------------------------------------
-- Geometry
---------------------------------------------------------------------------
-- World position (continentID, x, y in yards) of a point on a map.
function ns:GetWorldPos(mapID, x, y)
	if not (mapID and x and y and C_Map.GetWorldPosFromMapPos) then return nil end
	local ok, continentID, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
	if not ok or not continentID or not pos then return nil end
	local wx, wy = pos:GetXY()
	return continentID, wx, wy
end

local function yardsBetween(c1, x1, y1, c2, x2, y2)
	if not (c1 and c2) or c1 ~= c2 then return math.huge end
	local dx, dy = x1 - x2, y1 - y2
	return math.sqrt(dx * dx + dy * dy)
end
ns.YardsBetween = yardsBetween

---------------------------------------------------------------------------
-- Entrances
---------------------------------------------------------------------------
local function entry(instanceMapID, name, kind)
	local e = WorldData.db.entrances[instanceMapID]
	if not e then
		e = { clusters = {}, walkIns = 0, groupFinderEntries = 0 }
		WorldData.db.entrances[instanceMapID] = e
	end
	if name then e.name = name end
	if kind then e.kind = kind end
	return e
end

-- Records one walk-in: merges it into the nearest cluster within CLUSTER_RADIUS_YARDS or starts a new one.
function WorldData:RecordEntrance(instanceMapID, name, kind, mapID, x, y)
	local continentID, wx, wy = ns:GetWorldPos(mapID, x, y)
	if not continentID then return nil, "no world position for the outdoor point" end

	local e = entry(instanceMapID, name, kind)
	local now, who = time(), ns:GetCharacterKey()
	e.walkIns = (e.walkIns or 0) + 1
	e.lastEntered = now

	local best, bestDist
	for _, c in ipairs(e.clusters) do
		local d = yardsBetween(continentID, wx, wy, c.continentID, c.wx, c.wy)
		if d <= CLUSTER_RADIUS_YARDS and (not bestDist or d < bestDist) then best, bestDist = c, d end
	end

	if best then
		-- Running mean keeps the cluster centred on its recordings.
		local n = best.count + 1
		best.wx = best.wx + (wx - best.wx) / n
		best.wy = best.wy + (wy - best.wy) / n
		if best.mapID == mapID then
			best.x = best.x + (x - best.x) / n
			best.y = best.y + (y - best.y) / n
		end
		best.count, best.last = n, now
		best.reporters[who] = (best.reporters[who] or 0) + 1
		return best, "added to existing entrance"
	end

	local c = {
		mapID = mapID, x = x, y = y, continentID = continentID, wx = wx, wy = wy,
		count = 1, first = now, last = now, reporters = { [who] = 1 },
	}
	table.insert(e.clusters, c)
	return c, "new entrance"
end

function WorldData:RecordGroupFinderEntry(instanceMapID, name, kind)
	local e = entry(instanceMapID, name, kind)
	e.groupFinderEntries = (e.groupFinderEntries or 0) + 1
	e.lastEntered = time()
end

function WorldData:GetEntrance(instanceMapID)
	return self.db.entrances[instanceMapID]
end

function WorldData:GetClusters(instanceMapID)
	local e = self.db.entrances[instanceMapID]
	return e and e.clusters or {}
end

function WorldData:IsQueueOnly(instanceMapID)
	local e = self.db.entrances[instanceMapID]
	return e ~= nil and #e.clusters == 0 and (e.groupFinderEntries or 0) >= QUEUE_ONLY_MIN_ENTRIES
end

local function siteMapIDs(site)
	local ids, seen = {}, {}
	for _, inst in ipairs(site.instances) do
		for _, id in ipairs(inst.mapIDs or {}) do
			if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
		end
	end
	return ids
end
WorldData.SiteMapIDs = siteMapIDs

-- Normalized names a site answers to (site, instance names, aliases). Used to link recordings of
-- instances whose map ID isn't known yet (Hyjal Summit, The Barrow Deeps).
local nameKeyCache = setmetatable({}, { __mode = "k" })
local function siteNameKeys(site)
	local keys = nameKeyCache[site]
	if keys then return keys end
	keys = {}
	local function add(name)
		local k = ns.NormalizeInstanceName(name)
		if k then keys[k] = true end
	end
	add(site.name)
	for _, inst in ipairs(site.instances) do
		add(inst.name)
		for _, alias in ipairs(inst.aliases or {}) do add(alias) end
	end
	nameKeyCache[site] = keys
	return keys
end

local function siteCoversEntry(site, id, e)
	for _, sid in ipairs(siteMapIDs(site)) do
		if sid == id then return true end
	end
	local k = e.name and ns.NormalizeInstanceName(e.name)
	return k ~= nil and siteNameKeys(site)[k] == true
end

-- All recorded clusters for a site: every instance map ID it covers, plus recordings matched by name.
function WorldData:GetSiteClusters(site)
	local out = {}
	for id, e in pairs(self.db.entrances) do
		if siteCoversEntry(site, id, e) then
			for _, c in ipairs(e.clusters) do out[#out + 1] = c end
		end
	end
	return out
end

function WorldData:FindSiteFor(instanceMapID, name)
	local e = { name = name }
	for _, site in ipairs(ns.Data.Instances) do
		if siteCoversEntry(site, instanceMapID, e) then return site end
	end
end

function WorldData:SiteHasRecordings(site)
	return #self:GetSiteClusters(site) > 0
end

-- Recorded instance map IDs that no static site covers (new instances found by walking in).
function WorldData:GetUnknownInstances()
	local out = {}
	for id, e in pairs(self.db.entrances) do
		if not self:FindSiteFor(id, e.name) then out[#out + 1] = { mapID = id, entry = e } end
	end
	table.sort(out, function(a, b) return a.mapID < b.mapID end)
	return out
end

-- Distance in yards from a recorded cluster to the nearest static entrance of a site (nil if none).
function WorldData:DistanceToStatic(site, cluster)
	local best
	for _, s in ipairs(site.entrances) do
		local c, x, y = ns:GetWorldPos(s[1], s[2] / 100, s[3] / 100)
		local d = yardsBetween(c, x, y, cluster.continentID, cluster.wx, cluster.wy)
		if d < math.huge and (not best or d < best) then best = d end
	end
	return best
end

---------------------------------------------------------------------------
-- Log of recording attempts (kept small; shown by /pf entrances)
---------------------------------------------------------------------------
function WorldData:Log(instanceMapID, name, result, reason)
	local log = self.db.log
	log[#log + 1] = { time = time(), instanceMapID = instanceMapID, name = name, result = result, reason = reason }
	while #log > LOG_MAX do table.remove(log, 1) end
	ns:Debug("entrance %s: %s (%s)", result, tostring(name), tostring(reason))
end

---------------------------------------------------------------------------
-- /pf entrances
---------------------------------------------------------------------------
local function mapLabel(mapID)
	local info = mapID and C_Map.GetMapInfo(mapID)
	return ("%s (%s)"):format(info and info.name or "?", tostring(mapID))
end

local function reporterText(reporters)
	local parts = {}
	for who, n in pairs(reporters or {}) do parts[#parts + 1] = n > 1 and (who .. " x" .. n) or who end
	table.sort(parts)
	return table.concat(parts, ", ")
end

function WorldData:Report()
	local r = ns:NewReport("Recorded instance entrances")
	local siteFor = {}
	for id, e in pairs(self.db.entrances) do siteFor[id] = self:FindSiteFor(id, e.name) end

	local ids = {}
	for id in pairs(self.db.entrances) do ids[#ids + 1] = id end
	table.sort(ids)

	r:Add("RECORDED ENTRANCES:")
	local any = false
	for _, id in ipairs(ids) do
		local e = self.db.entrances[id]
		local site = siteFor[id]
		r:Add("  %s [instance map %d, %s]: %d walk-in(s), %d group-finder entr%s%s", e.name or (site and site.name) or "?", id,
			tostring(e.kind), e.walkIns or 0, e.groupFinderEntries or 0, (e.groupFinderEntries or 0) == 1 and "y" or "ies",
			site and "" or "  (not in Pathfinder's table)")
		for i, c in ipairs(e.clusters) do
			any = true
			local diff = ""
			if site then
				local d = self:DistanceToStatic(site, c)
				if d then diff = (" | %.0f yd from static point%s"):format(d, d > self.STATIC_DIFF_YARDS and " <-- differs" or "") end
			end
			r:Add("    #%d %s %.2f, %.2f | %d recording(s), last %s | by %s%s", i, mapLabel(c.mapID), c.x * 100, c.y * 100,
				c.count, date("%Y-%m-%d %H:%M", c.last), reporterText(c.reporters), diff)
		end
	end
	if not any then r:Add("  none yet. Walk into a dungeon or raid to record its entrance.") end

	r:Add("")
	r:Add("QUEUE-ONLY (entered only via group finder, %d+ times): %s", QUEUE_ONLY_MIN_ENTRIES, table.concat(self:GetQueueOnlyNames(), ", "))
	r:Add("")
	r:Add("INSTANCES WITHOUT A PIN YET (walk in once and the entrance is recorded):")
	local missing = self:GetInstancesWithoutPin()
	if #missing == 0 then r:Add("  none") end
	for _, m in ipairs(missing) do
		r:Add("  %-24s %s", m.name, m.hint or "(no location hint)")
		if m.attunement then r:Add("  %-24s Requires attunement: %s", "", m.attunement) end
	end

	r:Add("")
	r:Add("RECENT RECORDING ATTEMPTS (newest last):")
	if #self.db.log == 0 then r:Add("  none") end
	for _, l in ipairs(self.db.log) do
		r:Add("  %s  %-26s %-8s %s", date("%m-%d %H:%M:%S", l.time), tostring(l.name), l.result, l.reason or "")
	end
	r:ToWindow()
end

function WorldData:GetQueueOnlyNames()
	local out = {}
	for id, e in pairs(self.db.entrances) do
		if self:IsQueueOnly(id) then out[#out + 1] = e.name or tostring(id) end
	end
	table.sort(out)
	if #out == 0 then out[1] = "none" end
	return out
end

-- Live sites with no static point and nothing recorded, with Blizzard's location hint.
-- Unreleased raids are left out unless "/pf unreleased" is on.
function WorldData:GetInstancesWithoutPin()
	local out = {}
	local showUnreleased = ns:GetSetting("showUnreleasedRaids")
	for _, site in ipairs(ns.Data.Instances) do
		if not site.candidate and #site.entrances == 0 and not self:SiteHasRecordings(site) then
			local live, queueOnly = false, false
			for _, inst in ipairs(site.instances) do
				if showUnreleased or not inst.unreleased then live = true end
			end
			for _, id in ipairs(siteMapIDs(site)) do if self:IsQueueOnly(id) then queueOnly = true end end
			if live and not queueOnly then
				out[#out + 1] = { name = site.name, hint = site.hint, attunement = site.attunement }
			end
		end
	end
	return out
end
