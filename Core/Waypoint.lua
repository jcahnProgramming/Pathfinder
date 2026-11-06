-- Native user waypoint, super-tracking, map pin chat links, and the shared pin click conventions:
--   click = set waypoint + arrow, shift-click (chat open) = insert link, ctrl-click = clear waypoint.
local _, ns = ...

local Waypoint = ns:NewModule("Waypoint")

local MAX_DESCEND = 3

---------------------------------------------------------------------------
-- Map helpers
---------------------------------------------------------------------------
function ns:GetContinentForMap(mapID)
	local guard = 0
	while mapID and guard < 10 do
		local info = C_Map.GetMapInfo(mapID)
		if not info then return nil end
		if info.mapType == Enum.UIMapType.Continent then return mapID end
		mapID = info.parentMapID
		guard = guard + 1
	end
end

local function canSet(mapID)
	return mapID and C_Map.CanSetUserWaypointOnMap(mapID)
end

-- Converts a point on one map to the same spot on another map (for example continent -> zone).
local function translate(fromMapID, x, y, toMapID)
	local continentID, worldPos = C_Map.GetWorldPosFromMapPos(fromMapID, CreateVector2D(x, y))
	if not (continentID and worldPos) then return nil end
	local _, mapPos = C_Map.GetMapPosFromWorldPos(continentID, worldPos, toMapID)
	if not mapPos then return nil end
	return mapPos:GetXY()
end

-- Returns a map and coordinates where a user waypoint is allowed. Continent maps usually
-- don't allow one, so this descends into the zone (or city) under the point.
function Waypoint:Resolve(mapID, x, y)
	for _ = 1, MAX_DESCEND do
		if canSet(mapID) then return mapID, x, y end
		local child = C_Map.GetMapInfoAtPosition(mapID, x, y)
		if not child or child.mapID == mapID then break end
		local cx, cy = translate(mapID, x, y, child.mapID)
		if not cx then break end
		mapID, x, y = child.mapID, cx, cy
	end
	if canSet(mapID) then return mapID, x, y end
	return nil
end

---------------------------------------------------------------------------
-- Waypoint actions
---------------------------------------------------------------------------
local function playSound(key)
	local id = SOUNDKIT and SOUNDKIT[key]
	if id then PlaySound(id) end
end

function Waypoint:Set(mapID, x, y)
	local wMap, wx, wy = self:Resolve(mapID, x, y)
	if not wMap then
		ns:Print("A waypoint can't be placed there.")
		return false
	end
	C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(wMap, wx, wy))
	C_SuperTrack.SetSuperTrackedUserWaypoint(true)
	-- Some clients drop super-tracking set in the same frame as the waypoint; re-assert once.
	C_Timer.After(0.1, function()
		if C_Map.HasUserWaypoint() and not C_SuperTrack.IsSuperTrackingUserWaypoint() then
			C_SuperTrack.SetSuperTrackedUserWaypoint(true)
		end
	end)
	playSound("UI_MAP_WAYPOINT_CLICK_TO_PLACE")
	ns:Debug("waypoint set on map %d at %.4f, %.4f", wMap, wx, wy)
	return true
end

function Waypoint:Clear()
	if C_Map.HasUserWaypoint() then
		C_Map.ClearUserWaypoint()
		playSound("UI_MAP_WAYPOINT_REMOVE")
	end
end

function Waypoint.BuildLink(mapID, x, y)
	return ("|cffffff00|Hworldmap:%d:%d:%d|h[%s]|h|r"):format(
		mapID, math.floor(x * 10000 + 0.5), math.floor(y * 10000 + 0.5), MAP_PIN_HYPERLINK or "Map Pin Location")
end

local function activeChatEditBox()
	local get = (ChatFrameUtil and ChatFrameUtil.GetActiveWindow) or ChatEdit_GetActiveWindow
	return get and get()
end

-- Inserts a map pin link into the open chat box. Returns false if no chat box is open.
function Waypoint:InsertLink(mapID, x, y)
	local editBox = activeChatEditBox()
	if not editBox then return false end
	local wMap, wx, wy = self:Resolve(mapID, x, y)
	if not wMap then return false end
	local link = Waypoint.BuildLink(wMap, wx, wy)
	local insert = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
	if insert then
		return insert(link) ~= false
	end
	editBox:Insert(link)
	return true
end

-- Shared click handler for every Pathfinder pin. opts.onCtrlClick overrides the ctrl-click
-- action (custom pins use it for "Remove <name>?"); built-in pins only clear the waypoint.
function Waypoint:HandleClick(button, mapID, x, y, opts)
	if button ~= "LeftButton" then return false end
	if IsControlKeyDown() then
		if opts and opts.onCtrlClick then opts.onCtrlClick() else self:Clear() end
		return true
	end
	if IsShiftKeyDown() and self:InsertLink(mapID, x, y) then
		return true
	end
	return self:Set(mapID, x, y)
end
