-- What the client says about instances, used on top of the static table in Data\Instances.lua:
--   * C_LFGList activities (group browser) give real suggested level ranges. Where one matches a
--     static instance, its range is used and the static range stays as fallback.
--   * GetLFGDungeonInfo gives one recommended level per instance, plus type and group size.
--   * Both lists are the authority for which Forever-only candidate sites exist: a candidate is
--     drawn only once the client lists an instance with its name.
-- /pf levels writes the full comparison to the debug window and PathfinderDB.levelProbe.
local _, ns = ...

local InstanceInfo = ns:NewModule("InstanceInfo")

local LFG_SCAN_MAX_ID = 3500
local LEVEL_DIFF_REPORT = 3

-- LFG constants (GetLFGDungeonInfo typeID / subtypeID). On Forever, typeID 4 entries are zones
-- (e.g. Riverglades, Mount Hyjal) and typeID 5 are battlegrounds.
local TYPEID_ZONE, TYPEID_BATTLEGROUND, TYPEID_RANDOM = 4, 5, 6
local SUBTYPE_HEROIC, SUBTYPE_RAID, SUBTYPE_SCENARIO = 2, 3, 4

local VARIANT_PATTERNS = {
	"heroic", "random", "timewalk", "holiday", "mythic", "looking for raid", "daily", "weekly",
	"test", "deprecated", "unused", "%(old%)", "%[ph%]", "placeholder",
}
local NON_INSTANCE_CATEGORIES = { "pvp", "battleground", "arena", "custom", "quest", "world", "skirmish", "rated" }

local function isSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function normalize(name)
	if type(name) ~= "string" or isSecret(name) then return nil end
	local s = name:lower():gsub("^the ", "")
	s = s:gsub("[^%a]", "")
	return s ~= "" and s or nil
end
ns.NormalizeInstanceName = normalize

---------------------------------------------------------------------------
-- Static names
---------------------------------------------------------------------------
-- Every name a static instance can be listed under: its own name, "site + wing", and aliases.
local function staticKeys(site, inst)
	local keys = {}
	local function add(name)
		local key = normalize(name)
		if key then keys[#keys + 1] = key end
	end
	add(inst.name)
	if inst.name ~= site.name then add(site.name .. " " .. inst.name) end
	for _, alias in ipairs(inst.aliases or {}) do add(alias) end
	return keys
end

---------------------------------------------------------------------------
-- Scanning
---------------------------------------------------------------------------
local function lowerMatchesAny(text, patterns)
	text = type(text) == "string" and text:lower() or ""
	for _, pattern in ipairs(patterns) do
		if text:find(pattern) then return pattern end
	end
end

local function categoryName(categoryID)
	if not (categoryID and C_LFGList.GetLfgCategoryInfo) then return nil end
	local ok, info = pcall(C_LFGList.GetLfgCategoryInfo, categoryID)
	return ok and type(info) == "table" and info.name or nil
end

local function scanActivities()
	local out, seen = {}, {}
	if not (C_LFGList and C_LFGList.GetAvailableActivities and C_LFGList.GetActivityInfoTable) then return out end

	-- Query per category as well as unfiltered; some clients only return one category without an argument.
	local queries = { false }
	if C_LFGList.GetAvailableCategories then
		local ok, categories = pcall(C_LFGList.GetAvailableCategories)
		if ok and type(categories) == "table" then
			for _, id in ipairs(categories) do queries[#queries + 1] = id end
		end
	end

	for _, categoryID in ipairs(queries) do
		local ok, activities
		if categoryID then
			ok, activities = pcall(C_LFGList.GetAvailableActivities, categoryID)
		else
			ok, activities = pcall(C_LFGList.GetAvailableActivities)
		end
		if ok and type(activities) == "table" then
			for _, id in ipairs(activities) do
				if not seen[id] then
					seen[id] = true
					local ok2, info = pcall(C_LFGList.GetActivityInfoTable, id)
					if ok2 and type(info) == "table" and type(info.fullName) == "string" then
						out[#out + 1] = {
							kind = "activity", id = id,
							name = info.fullName, shortName = info.shortName,
							categoryID = info.categoryID, category = categoryName(info.categoryID),
							min = info.minLevelSuggestion, max = info.maxLevelSuggestion, minLevel = info.minLevel,
							maxPlayers = info.maxNumPlayers, mapID = info.mapID,
							isPvp = info.isPvpActivity or info.isRatedPvpActivity,
							isHeroic = info.isHeroicActivity, isMythic = info.isMythicActivity or info.isMythicPlusActivity,
						}
					end
				end
			end
		end
	end
	return out
end

local function scanLFGDungeons()
	local out = {}
	if not GetLFGDungeonInfo then return out end
	for id = 1, LFG_SCAN_MAX_ID do
		local ok, name, typeID, subtypeID, minLevel, maxLevel, recLevel, minRec, maxRec,
			expansion, groupID, _, difficulty, maxPlayers, _, isHoliday, _, minPlayers, isTimeWalker,
			_, _, _, lfgMapID = pcall(GetLFGDungeonInfo, id)
		if ok and type(name) == "string" and not isSecret(name) then
			out[#out + 1] = {
				kind = "lfg", id = id, name = name, typeID = typeID, subtypeID = subtypeID,
				minLevel = minLevel, maxLevel = maxLevel, recLevel = recLevel, minRec = minRec, maxRec = maxRec,
				expansion = expansion, groupID = groupID, difficulty = difficulty,
				maxPlayers = maxPlayers, minPlayers = minPlayers,
				isHoliday = isHoliday, isTimeWalker = isTimeWalker, mapID = lfgMapID,
			}
		end
	end
	return out
end

-- Returns a reason string if the entry is a variant/non-instance rather than a distinct instance.
local function variantReason(e)
	if e.kind == "activity" then
		if e.isPvp then return "PvP activity" end
		local cat = lowerMatchesAny(e.category, NON_INSTANCE_CATEGORIES)
		if cat then return ("category: %s"):format(tostring(e.category)) end
		if e.isHeroic then return "heroic" end
		if e.isMythic then return "mythic" end
	else
		if e.isHoliday then return "holiday" end
		if e.typeID == TYPEID_RANDOM then return "random queue" end
		if e.typeID == TYPEID_ZONE then return "zone (type 4)" end
		if e.typeID == TYPEID_BATTLEGROUND then return "battleground (type 5)" end
		if e.subtypeID == SUBTYPE_HEROIC then return "heroic" end
		if e.isTimeWalker then return "timewalking" end
	end
	local pattern = lowerMatchesAny(e.name, VARIANT_PATTERNS)
	if pattern then return ("name contains '%s'"):format(pattern:gsub("%%", "")) end
end

local function isRaid(e)
	if e.kind == "lfg" and e.subtypeID == SUBTYPE_RAID then return true end
	if e.kind == "activity" and lowerMatchesAny(e.category, { "raid" }) then return true end
	return (e.maxPlayers or 0) > 5
end

---------------------------------------------------------------------------
-- Index + apply to static data
---------------------------------------------------------------------------
function InstanceInfo:Scan()
	local activities, dungeons = scanActivities(), scanLFGDungeons()
	local byKey = {} -- normalized name -> { activity = e, lfg = e }

	for _, list in ipairs({ activities, dungeons }) do
		for _, e in ipairs(list) do
			e.variant = variantReason(e)
			e.raid = isRaid(e)
			e.scenario = e.kind == "lfg" and e.subtypeID == SUBTYPE_SCENARIO or nil
			local key = normalize(e.name)
			if key and not e.variant then
				local slot = byKey[key] or {}
				byKey[key] = slot
				if not slot[e.kind] then slot[e.kind] = e else e.duplicateOf = slot[e.kind].id end
			end
		end
	end

	-- Apply to the static table.
	local matched = {}
	-- Every name of an instance contributes: the first activity found supplies the range, the first LFG
	-- entry the type/size, and every hit is marked as matched (e.g. Stratholme's two gate activities).
	for _, site in ipairs(ns.Data.Instances) do
		site.confirmed = nil
		for _, inst in ipairs(site.instances) do
			local live
			for _, key in ipairs(staticKeys(site, inst)) do
				local slot = byKey[key]
				if slot then
					live = live or {}
					live.activity = live.activity or slot.activity
					live.lfg = live.lfg or slot.lfg
					if slot.activity then matched[slot.activity] = true end
					if slot.lfg then matched[slot.lfg] = true end
				end
			end
			inst.live = live
			if live and site.candidate then site.confirmed = true end
		end
	end

	self.byKey = byKey
	self.activities, self.dungeons, self.matched = activities, dungeons, matched
	self.scanned = true
	ns:Fire("INSTANCE_INFO_UPDATED")
end

-- Level range to use for an instance, in order of authority:
--   official (Blizzard's published range) > client group-browser range > static > client recommended level.
function InstanceInfo:GetLevels(inst)
	if inst.official and inst.min then return inst.min, inst.max, "official" end
	local live = inst.live
	local a = live and live.activity
	if a and type(a.min) == "number" and type(a.max) == "number" and a.min > 0 and a.max >= a.min then
		return a.min, a.max, "client"
	end
	if inst.min and inst.min > 0 then return inst.min, inst.max, "static" end
	local l = live and live.lfg
	local rec = l and (l.recLevel or l.minRec or l.minLevel)
	if type(rec) == "number" and rec > 0 then return rec, rec, "client (recommended)" end
	return nil
end

-- Instance type and group size from the client where the static entry doesn't know them.
function InstanceInfo:GetKind(inst)
	local e = inst.live and (inst.live.activity or inst.live.lfg)
	if inst.type and not (inst.unknownType and e) then return inst.type, inst.size end
	if e then return e.raid and ns.Data.INSTANCE_TYPE.RAID or ns.Data.INSTANCE_TYPE.DUNGEON, e.maxPlayers end
	return inst.type, inst.size
end

-- Client data for an instance known only by name (e.g. one recorded in-game but not in the table).
function InstanceInfo:LookupName(name)
	local key = normalize(name)
	return key and self.byKey and self.byKey[key] or nil
end

function InstanceInfo:IsSiteShown(site)
	if site.candidate then return site.confirmed == true or ns.WorldData:SiteHasRecordings(site) end
	return true
end

function InstanceInfo:OnEnable()
	-- Group browser data can take a moment to populate after login.
	C_Timer.After(3, function() InstanceInfo:Scan() end)
end

---------------------------------------------------------------------------
-- /pf levels report
---------------------------------------------------------------------------
local function describe(e)
	local parts = { ("[%s #%d] %s"):format(e.kind == "activity" and "activity" or "lfg", e.id, e.name) }
	if e.kind == "activity" then
		parts[#parts + 1] = ("category %s (%s)"):format(tostring(e.category), tostring(e.categoryID))
		parts[#parts + 1] = ("suggested %s-%s"):format(tostring(e.min), tostring(e.max))
		if e.minLevel and e.minLevel > 0 then parts[#parts + 1] = "min " .. e.minLevel end
	else
		parts[#parts + 1] = ("type %s/%s"):format(tostring(e.typeID), tostring(e.subtypeID))
		parts[#parts + 1] = ("rec %s (range %s-%s)"):format(tostring(e.recLevel), tostring(e.minLevel), tostring(e.maxLevel))
		if e.difficulty then parts[#parts + 1] = "difficulty " .. tostring(e.difficulty) end
	end
	parts[#parts + 1] = (e.raid and "raid" or "dungeon") .. (e.maxPlayers and (", " .. e.maxPlayers .. " players") or "")
	if e.scenario then parts[#parts + 1] = "scenario" end
	if e.mapID then parts[#parts + 1] = "instance map " .. tostring(e.mapID) end
	return table.concat(parts, " | ")
end

function InstanceInfo:Report()
	self:Scan()
	local r = ns:NewReport("Instance levels and client instance list")

	r:Add("Sources: %d group-browser activities, %d LFG dungeon entries, Encounter Journal %s.",
		#self.activities, #self.dungeons, (EJ_GetNumTiers and "present (no level data)") or "missing")

	-- 1. Levels in use per static instance.
	r:Add("")
	r:Add("LEVEL RANGES IN USE. Source order: official (Blizzard's published) > client (group browser) > static (Classic table).")
	r:Add("  Unreleased raids (not yet in Forever) are marked [unreleased].")
	local diffs = {}
	for _, site in ipairs(ns.Data.Instances) do
		if not site.candidate then
			for _, inst in ipairs(site.instances) do
				local full = inst.name == site.name and inst.name or (site.name .. ": " .. inst.name)
				local a = inst.live and inst.live.activity
				local min, max, source = self:GetLevels(inst)
				local client = (a and a.min and a.max) and (a.min .. "-" .. a.max) or "-"
				local flag = ""
				if a and a.min and a.max and inst.min and (math.abs(a.min - inst.min) > LEVEL_DIFF_REPORT or math.abs(a.max - inst.max) > LEVEL_DIFF_REPORT) then
					flag = "   <-- differs by more than " .. LEVEL_DIFF_REPORT
					diffs[#diffs + 1] = full
				end
				r:Add("  %-40s %s %d-%d | client %-7s | using %s-%s, source: %s%s%s", full,
					inst.official and "official" or "static  ", inst.min, inst.max, client,
					tostring(min), tostring(max), tostring(source), inst.unreleased and " [unreleased]" or "", flag)
			end
		end
	end
	r:Add("  Differ by more than %d levels: %s", LEVEL_DIFF_REPORT, #diffs > 0 and table.concat(diffs, ", ") or "none")

	-- 2. Static instances the client doesn't list.
	local unlisted = {}
	for _, site in ipairs(ns.Data.Instances) do
		if not site.candidate then
			for _, inst in ipairs(site.instances) do
				if not inst.live then unlisted[#unlisted + 1] = inst.name end
			end
		end
	end
	r:Add("")
	r:Add("STATIC INSTANCES NOT FOUND IN CLIENT DATA (name mismatch or not listed; raids are never listed): %s",
		#unlisted > 0 and table.concat(unlisted, ", ") or "none")

	-- 2b. Recorded entrances vs the Questie/static points.
	r:Add("")
	r:Add("RECORDED ENTRANCES VS STATIC POINTS (recorded entrances are used where they exist):")
	local anyRecorded = false
	for _, site in ipairs(ns.Data.Instances) do
		for i, c in ipairs(ns.WorldData:GetSiteClusters(site)) do
			anyRecorded = true
			local d = ns.WorldData:DistanceToStatic(site, c)
			local note = d and ("%.0f yd from static point%s"):format(d, d > ns.WorldData.STATIC_DIFF_YARDS and "  <-- differs" or "")
				or "no static point"
			r:Add("  %-28s #%d (%d recording%s): %s", site.name, i, c.count, c.count == 1 and "" or "s", note)
		end
	end
	if not anyRecorded then r:Add("  none recorded yet (/pf entrances)") end

	-- 3. Forever-only candidates.
	r:Add("")
	r:Add("FOREVER CANDIDATE SITES (Questie coordinates; drawn only if the client lists them):")
	for _, site in ipairs(ns.Data.Instances) do
		if site.candidate then
			local inst = site.instances[1]
			local e = inst.live and (inst.live.activity or inst.live.lfg)
			r:Add("  %-28s %s", site.name, site.confirmed and ("CONFIRMED, pin added -> " .. describe(e)) or "not in client data, hidden")
		end
	end

	-- 4. Client entries that don't match anything in the table.
	local real, variants = {}, {}
	for _, list in ipairs({ self.activities, self.dungeons }) do
		for _, e in ipairs(list) do
			if not self.matched[e] then
				if e.variant or e.duplicateOf then variants[#variants + 1] = e else real[#real + 1] = e end
			end
		end
	end
	r:Add("")
	r:Add("UNMATCHED CLIENT ENTRIES - LIKELY REAL INSTANCES (%d). No entrance coordinates yet unless noted:", #real)
	for _, e in ipairs(real) do r:Add("  " .. describe(e)) end
	r:Add("")
	r:Add("UNMATCHED CLIENT ENTRIES - VARIANTS / DUPLICATES / NON-INSTANCE (%d):", #variants)
	for _, e in ipairs(variants) do
		local why = e.variant or ("duplicate of #" .. tostring(e.duplicateOf))
		r:Add("  " .. describe(e) .. "  [" .. why .. "]")
	end

	-- Save everything for offline review.
	local function strip(list)
		local out = {}
		for _, e in ipairs(list) do
			local copy = {}
			for k, v in pairs(e) do if type(v) ~= "table" and type(v) ~= "function" then copy[k] = v end end
			copy.matched = self.matched[e] or nil
			out[#out + 1] = copy
		end
		return out
	end
	ns.db.levelProbe = { time = time(), version = 2, activities = strip(self.activities), lfgDungeons = strip(self.dungeons) }
	r:Add("")
	r:Add("Full data saved to PathfinderDB.levelProbe on /reload or logout.")
	r:ToWindow()
end
