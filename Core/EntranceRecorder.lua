-- Automatic entrance detection: when the player walks from the open world into a dungeon or raid,
-- their last outdoor position is recorded as that instance's entrance (Core\WorldData.lua).
--
-- A recording is made only when all of these hold; anything unclear is skipped, not guessed:
--   * a fresh outdoor position was taken at the moment the loading screen started (<= FRESH_SECONDS)
--   * the player wasn't moving faster than running/riding just before (no blink-in, no teleport)
--   * the instance wasn't entered through the group finder (LFG dungeon ID / IsInLFGDungeon)
--   * no summon was offered shortly before
--   * for instances with a static entrance, the point is within SANITY_YARDS of one of them
--   * it isn't a login or /reload
-- Group-finder entries are counted so instances that are only ever queued into can be listed as
-- "Group finder only".
local _, ns = ...

local EntranceRecorder = ns:NewModule("EntranceRecorder")

local SAMPLE_INTERVAL = 1.0
local FRESH_SECONDS = 3
local MAX_SPEED_YARDS_PER_SEC = 25 -- faster than any mount on the ground; above this = teleport
local SUMMON_WINDOW_SECONDS = 180
local SANITY_YARDS = 800

local INSTANCE_KIND = { party = "dungeon", raid = "raid" }

local samples = {}      -- last two outdoor samples, newest first
local loadingStart      -- GetTime() when the latest loading screen began
local loadingSample     -- outdoor sample taken at that moment
local summonOfferedAt   -- GetTime() of the latest summon offer

---------------------------------------------------------------------------
-- Outdoor sampling
---------------------------------------------------------------------------
local function takeSample()
	if IsInInstance() then return nil end
	local mapID = C_Map.GetBestMapForUnit("player")
	if not mapID then return nil end
	local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
	if not ok or not pos then return nil end
	if issecretvalue and issecretvalue(pos) then return nil end
	local x, y = pos:GetXY()
	if not x or not y or (x == 0 and y == 0) then return nil end
	local continentID, wx, wy = ns:GetWorldPos(mapID, x, y)
	return { mapID = mapID, x = x, y = y, continentID = continentID, wx = wx, wy = wy, t = GetTime() }
end

local function pushSample()
	local s = takeSample()
	if s then
		samples[2] = samples[1]
		samples[1] = s
	end
	return s
end

---------------------------------------------------------------------------
-- Entering an instance
---------------------------------------------------------------------------
local function staticSanity(instanceMapID, sample)
	-- Find the static site for this instance map ID; if it has static entrances, the point must be near one.
	for _, site in ipairs(ns.Data.Instances) do
		for _, id in ipairs(ns.WorldData.SiteMapIDs(site)) do
			if id == instanceMapID and #site.entrances > 0 then
				local best = math.huge
				for _, e in ipairs(site.entrances) do
					local c, x, y = ns:GetWorldPos(e[1], e[2] / 100, e[3] / 100)
					best = math.min(best, ns.YardsBetween(c, x, y, sample.continentID, sample.wx, sample.wy))
				end
				if best > SANITY_YARDS then
					return false, ("%s yd from every known entrance of %s"):format(best == math.huge and "unknown distance" or ("%.0f"):format(best), site.name)
				end
				return true
			end
		end
	end
	return true
end

local function evaluate(isInitialLogin, isReloadingUi)
	local inInstance, instanceType = IsInInstance()
	if not inInstance then return end
	local kind = INSTANCE_KIND[instanceType]
	if not kind then return end -- battlegrounds, arenas, scenarios

	local name, _, _, _, _, _, _, instanceMapID, _, lfgDungeonID = GetInstanceInfo()
	if not instanceMapID then return end
	local W = ns.WorldData

	if isInitialLogin or isReloadingUi then
		W:Log(instanceMapID, name, "skipped", "login or reload inside the instance")
		return
	end

	local viaGroupFinder = (lfgDungeonID and lfgDungeonID > 0) or (IsInLFGDungeon and IsInLFGDungeon())
	if viaGroupFinder then
		W:RecordGroupFinderEntry(instanceMapID, name, kind)
		W:Log(instanceMapID, name, "skipped", "entered through the group finder (LFG dungeon " .. tostring(lfgDungeonID) .. ")")
		return
	end

	local sample = loadingSample
	if not (sample and loadingStart) then
		W:Log(instanceMapID, name, "skipped", "no outdoor position from the moment the loading screen started")
		return
	end
	if loadingStart - sample.t > FRESH_SECONDS then
		W:Log(instanceMapID, name, "skipped", ("last outdoor position was %.1fs old"):format(loadingStart - sample.t))
		return
	end
	if summonOfferedAt and loadingStart - summonOfferedAt < SUMMON_WINDOW_SECONDS then
		W:Log(instanceMapID, name, "skipped", "a summon was offered shortly before")
		return
	end

	local prev = samples[2]
	if prev and prev ~= sample then
		local dt = sample.t - prev.t
		local d = ns.YardsBetween(prev.continentID, prev.wx, prev.wy, sample.continentID, sample.wx, sample.wy)
		if dt > 0 and dt < 5 and d / dt > MAX_SPEED_YARDS_PER_SEC then
			W:Log(instanceMapID, name, "skipped", ("moved %.0f yd in %.1fs just before (teleport?)"):format(d, dt))
			return
		end
	end

	local sane, why = staticSanity(instanceMapID, sample)
	if not sane then
		W:Log(instanceMapID, name, "skipped", why)
		return
	end

	local cluster, how = W:RecordEntrance(instanceMapID, name, kind, sample.mapID, sample.x, sample.y)
	if not cluster then
		W:Log(instanceMapID, name, "skipped", how)
		return
	end
	W:Log(instanceMapID, name, "recorded", ("%s, %s %.1f %.1f"):format(how, tostring(sample.mapID), sample.x * 100, sample.y * 100))
	if how == "new entrance" then
		ns:Print("Recorded the entrance to %s.", name or "this instance")
	end
	ns:Fire("ENTRANCES_UPDATED")
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function EntranceRecorder:OnEnable()
	C_Timer.NewTicker(SAMPLE_INTERVAL, pushSample)

	ns:RegisterEvent("LOADING_SCREEN_ENABLED", function()
		loadingStart = GetTime()
		-- Position is still readable at the start of the loading screen; take the freshest one possible.
		loadingSample = pushSample() or samples[1]
	end)

	ns:RegisterEvent("CONFIRM_SUMMON", function()
		summonOfferedAt = GetTime()
	end)

	ns:RegisterEvent("PLAYER_ENTERING_WORLD", function(isInitialLogin, isReloadingUi)
		-- GetInstanceInfo can lag the event slightly.
		C_Timer.After(1, function()
			local ok, err = pcall(evaluate, isInitialLogin, isReloadingUi)
			if not ok then geterrorhandler()(err) end
			loadingStart, loadingSample = nil, nil
		end)
	end)
end
