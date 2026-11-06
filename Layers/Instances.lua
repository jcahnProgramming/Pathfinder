-- Instances category: dungeon and raid entrance layers, from the static table in Data\Instances.lua.
-- Pins are tinted by how the instance's level range compares to the player's level:
--   red = well above you, orange = a bit above, yellow = at level, green = a bit below, gray = trivial.
local _, ns = ...

local Instances = ns:NewModule("Instances")

local TEMPLATE = "PathfinderInstancePinTemplate"
local TYPE = ns.Data.INSTANCE_TYPE
local LAYER_FOR_TYPE = { [TYPE.DUNGEON] = "showDungeons", [TYPE.RAID] = "showRaids" }

-- Classic quest difficulty colors.
local DIFFICULTY_COLOR = {
	red = { 1.00, 0.10, 0.10 },
	orange = { 1.00, 0.50, 0.25 },
	yellow = { 1.00, 0.82, 0.00 },
	green = { 0.25, 0.75, 0.25 },
	gray = { 0.50, 0.50, 0.50 },
}
Instances.DIFFICULTY_COLOR = DIFFICULTY_COLOR

local ICON = {
	[TYPE.DUNGEON] = { atlas = "Dungeon", texture = "Interface\\Icons\\INV_Misc_Key_14" },
	[TYPE.RAID] = { atlas = "Raid", texture = "Interface\\Icons\\INV_Misc_Head_Dragon_01" },
}

local SHOWN_MAP_TYPES = {
	[Enum.UIMapType.Continent] = true,
	[Enum.UIMapType.Zone] = true,
	[Enum.UIMapType.Micro] = true,
	[Enum.UIMapType.Orphan] = true,
}

-- Two continent-projected entrances closer than this are drawn once (e.g. Blackrock Mountain).
local MERGE_DISTANCE = 0.01

---------------------------------------------------------------------------
-- Difficulty
---------------------------------------------------------------------------
-- Levels past an instance's max level before it turns gray.
local function greenRange()
	if GetQuestGreenRange then
		local ok, value = pcall(GetQuestGreenRange)
		if ok and type(value) == "number" and value > 0 then return value end
	end
	return 5
end

function Instances:GetDifficulty(minLevel, maxLevel, level)
	level = level or UnitLevel("player")
	if level < minLevel - 2 then return "red" end
	if level < minLevel then return "orange" end
	if level <= maxLevel then return "yellow" end
	if level <= maxLevel + greenRange() then return "green" end
	return "gray"
end

local function levelText(entry)
	if not entry.min then return "Level unknown" end
	if entry.min == entry.max then return ("Level %d"):format(entry.min) end
	return ("Levels %d-%d"):format(entry.min, entry.max)
end

---------------------------------------------------------------------------
-- Pin data
---------------------------------------------------------------------------
-- Resolved view of an instance: client level range / type where known, static otherwise.
local function resolve(inst)
	local min, max, source = ns.InstanceInfo:GetLevels(inst)
	local kind, size = ns.InstanceInfo:GetKind(inst)
	return { name = inst.name, type = kind or TYPE.DUNGEON, size = size, min = min, max = max, levelSource = source }
end

local function visibleInstances(site)
	local out = {}
	local showUnreleased = ns:GetSetting("showUnreleasedRaids")
	for _, inst in ipairs(site.instances) do
		-- Instances not (yet) in Forever stay hidden, so merged pins (Blackrock Mountain) list only live ones.
		if showUnreleased or not inst.unreleased then
			local entry = resolve(inst)
			entry.unreleased = inst.unreleased
			if ns:IsLayerShown(LAYER_FOR_TYPE[entry.type]) then table.insert(out, entry) end
		end
	end
	table.sort(out, function(a, b)
		local am, bm = a.min or 999, b.min or 999
		if am ~= bm then return am < bm end
		return (a.max or 999) < (b.max or 999)
	end)
	return out
end

local function difficultyOf(entry)
	if not entry.min then return nil end
	return Instances:GetDifficulty(entry.min, entry.max)
end

-- Site tint: the lowest-level instance that isn't trivial for you; gray if all are; none if unknown.
local function siteDifficulty(list)
	local any = false
	for _, entry in ipairs(list) do
		local d = difficultyOf(entry)
		if d then
			any = true
			if d ~= "gray" then return d end
		end
	end
	return any and "gray" or nil
end

local function iconFor(list)
	local kind = TYPE.RAID
	for _, inst in ipairs(list) do
		if inst.type == TYPE.DUNGEON then kind = TYPE.DUNGEON break end
	end
	local icon = ICON[kind]
	if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(icon.atlas) then
		return icon.atlas, nil
	end
	return nil, icon.texture
end

local projectionCache = {}

-- Where an entrance falls on the displayed map, or nil if it isn't on it. Any map on the same
-- continent works (zone, city, continent), via world coordinates.
local function project(entrance, mapID)
	if entrance.mapID == mapID then return entrance.x, entrance.y end
	local key = ("%d:%.5f:%.5f:%d"):format(entrance.mapID, entrance.x, entrance.y, mapID)
	local cached = projectionCache[key]
	if cached == nil then
		cached = false
		local px, py = ns:TranslateMapPos(entrance.mapID, entrance.x, entrance.y, mapID)
		if px and px >= 0 and px <= 1 and py >= 0 and py <= 1 then cached = { px, py } end
		projectionCache[key] = cached
	end
	if cached then return cached[1], cached[2] end
end

-- A site's entrances: recorded ones where any exist (they replace the static points), else static.
local function siteEntrances(site)
	local out = {}
	local me = ns:GetCharacterKey()
	for _, c in ipairs(ns.WorldData:GetSiteClusters(site)) do
		local others = 0
		for who in pairs(c.reporters or {}) do if who ~= me then others = others + 1 end end
		out[#out + 1] = { mapID = c.mapID, x = c.x, y = c.y, recorded = true, count = c.count,
			mine = c.reporters and c.reporters[me] ~= nil, others = others }
	end
	if #out > 0 then return out end
	for _, e in ipairs(site.entrances) do
		out[#out + 1] = { mapID = e[1], x = e[2] / 100, y = e[3] / 100, label = e[4] }
	end
	return out
end

-- Instances recorded in-game that aren't in the static table become sites of their own.
local function dynamicSites()
	local out = {}
	for _, u in ipairs(ns.WorldData:GetUnknownInstances()) do
		local e = u.entry
		if #e.clusters > 0 then
			local name = e.name or ("Instance " .. u.mapID)
			out[#out + 1] = {
				name = name, entrances = {}, dynamic = true,
				instances = { { name = name, mapIDs = { u.mapID }, type = e.kind == "raid" and TYPE.RAID or TYPE.DUNGEON,
					live = ns.InstanceInfo:LookupName(name) } },
			}
		end
	end
	return out
end

local function tooltip(tt, data)
	tt:AddLine(data.name, 1, 1, 1)
	local single = #data.instances == 1 and data.instances[1].name == data.name
	for _, inst in ipairs(data.instances) do
		local c = DIFFICULTY_COLOR[difficultyOf(inst)] or { 0.8, 0.8, 0.8 }
		local tag = inst.type == TYPE.RAID and (" (Raid%s)"):format(inst.size and (", " .. inst.size) or "") or ""
		if inst.unreleased then tag = tag .. " [not yet in Forever]" end
		if single then
			tt:AddLine(levelText(inst) .. tag, c[1], c[2], c[3])
		else
			tt:AddDoubleLine(inst.name .. tag, levelText(inst), 0.9, 0.9, 0.9, c[1], c[2], c[3])
		end
	end
	local e = data.entrance
	if e.label then tt:AddLine(e.label, 0.7, 0.7, 0.7) end
	if data.attunement then
		tt:AddLine("Requires attunement", 1, 0.5, 0.25)
		tt:AddLine(data.attunement, 0.8, 0.8, 0.8, true)
	end
	if e.recorded then
		local who = e.mine and "Recorded by you" or "Recorded"
		if e.others > 0 then who = who .. (" and %d other player%s"):format(e.others, e.others == 1 and "" or "s") end
		tt:AddLine(("%s (%d time%s)"):format(who, e.count, e.count == 1 and "" or "s"), 0.5, 0.8, 1)
	else
		-- Until an entrance is recorded, the point is approximate: show where to look.
		if data.hint then tt:AddLine(data.hint, 0.7, 0.7, 0.7, true) end
		if data.verify then tt:AddLine("Position not yet verified on Forever", 0.7, 0.7, 0.7) end
	end
end

local function addSitePins(pins, site, mapID)
	local list = visibleInstances(site)
	if #list == 0 then return end
	local placed = {}
	for _, entrance in ipairs(siteEntrances(site)) do
		local x, y = project(entrance, mapID)
		local duplicate = false
		if x then
			for _, p in ipairs(placed) do
				if math.abs(p[1] - x) < MERGE_DISTANCE and math.abs(p[2] - y) < MERGE_DISTANCE then duplicate = true end
			end
		end
		if x and not duplicate then
			table.insert(placed, { x, y })
			local atlas, texture = iconFor(list)
			table.insert(pins, {
				mapID = mapID, x = x, y = y,
				-- Waypoints always use the entrance's own map coordinates.
				waypoint = { entrance.mapID, entrance.x, entrance.y },
				name = site.name,
				instances = list,
				entrance = entrance,
				verify = site.verify,
				hint = site.hint,
				attunement = site.attunement,
				color = DIFFICULTY_COLOR[siteDifficulty(list) or ""],
				atlas = atlas, texture = texture,
				sizeScale = 1.15,
				tooltip = tooltip,
			})
		end
	end
end

function Instances:GetPinsForMap(mapID)
	local pins = {}
	local mapInfo = mapID and C_Map.GetMapInfo(mapID)
	if not mapInfo or not SHOWN_MAP_TYPES[mapInfo.mapType] then return pins end

	for _, site in ipairs(ns.Data.Instances) do
		if ns.InstanceInfo:IsSiteShown(site) then addSitePins(pins, site, mapID) end
	end
	for _, site in ipairs(dynamicSites()) do addSitePins(pins, site, mapID) end
	return pins
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
	local map = provider:GetMap()
	ns:SafeAcquirePins(map, TEMPLATE, Instances:GetPinsForMap(map:GetMapID()), function(data) return data end)
end

local refreshErrorShown = false
function Provider:RefreshAllData()
	-- Never let a Pathfinder error break Blizzard's map refresh.
	local ok, err = pcall(refresh, self)
	if not ok and not refreshErrorShown then
		refreshErrorShown = true
		ns:Print("|cffff3333instance layer error (shown once). Please report:|r %s", tostring(err))
	end
end

function Instances:Refresh()
	local map = Provider:GetMap()
	if map and map:IsShown() then Provider:RefreshAllData() end
end

function Instances:OnEnable()
	ns:OnWorldMapReady(function(worldMap)
		worldMap:AddDataProvider(Provider)
	end)

	ns:On("SETTING_CHANGED", function(key)
		if key == "pinScale" or key == "showUnreleasedRaids" or ns:AffectsLayer("showDungeons", key) or ns:AffectsLayer("showRaids", key) then
			Instances:Refresh()
		end
	end)
	ns:On("INSTANCE_INFO_UPDATED", function() Instances:Refresh() end)
	ns:On("ENTRANCES_UPDATED", function() Instances:Refresh() end)
	ns:RegisterEvent("PLAYER_LEVEL_UP", function()
		-- UnitLevel can lag the event by a frame.
		C_Timer.After(0.5, function() Instances:Refresh() end)
	end)
end
