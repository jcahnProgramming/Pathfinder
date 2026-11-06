-- Shared world map pin behavior for every Pathfinder layer: icon + tinted glow ring, size from
-- settings, tooltip, and the standard click conventions (see docs/ROADMAP.md).
--
-- Layers acquire pins with a data table:
--   { mapID, x, y, atlas | texture, color = {r, g, b}, tooltip = function(tooltip, data), clickOptions }
local _, ns = ...

local BASE_SIZE = 16
local RING_SCALE = 1.7
local GLOW_SCALE = 2.4

ns.MEDIA = "Interface\\AddOns\\" .. ns.name .. "\\Media\\"

PathfinderMapPinMixin = CreateFromMixins(MapCanvasPinMixin)

function PathfinderMapPinMixin:OnLoad()
	self:SetScalingLimits(1, 1.0, 1.2)
	-- Not every frame-level type is guaranteed to exist on this client.
	if not pcall(self.UseFrameLevelType, self, "PIN_FRAME_LEVEL_FLIGHT_POINT") then
		pcall(self.UseFrameLevelType, self, "PIN_FRAME_LEVEL_AREA_POI")
	end
	self.Ring:SetTexture(ns.MEDIA .. "ring")
	self.Glow:SetTexture(ns.MEDIA .. "glow")
end

function PathfinderMapPinMixin:OnAcquired(data)
	self.data = data

	local size = BASE_SIZE * (ns:GetSetting("pinScale") or 1)
	self:SetSize(size, size)
	self.Icon:SetSize(size, size)
	self.Ring:SetSize(size * RING_SCALE, size * RING_SCALE)
	self.Glow:SetSize(size * GLOW_SCALE, size * GLOW_SCALE)

	if data.atlas then
		self.Icon:SetAtlas(data.atlas)
	else
		self.Icon:SetTexture(data.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
	end

	local c = data.color or { 1, 1, 1 }
	self.Ring:SetVertexColor(c[1], c[2], c[3], 1)
	self.Glow:SetVertexColor(c[1], c[2], c[3], 0.55)

	self:SetPosition(data.x, data.y)
end

function PathfinderMapPinMixin:OnReleased()
	self.data = nil
end

-- Mouse methods below are called by MapCanvas's own pin scripts (see MapPinTemplates.xml).
function PathfinderMapPinMixin:OnMouseEnter()
	local data = self.data
	if not data then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if data.tooltip then data.tooltip(GameTooltip, data) end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Click: set waypoint", 0.6, 0.6, 0.6)
	GameTooltip:AddLine("Shift-click: link in chat", 0.6, 0.6, 0.6)
	GameTooltip:AddLine("Ctrl-click: clear waypoint", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

function PathfinderMapPinMixin:OnMouseLeave()
	GameTooltip:Hide()
end

-- Called by MapCanvas only when the mouse is released over the pin.
function PathfinderMapPinMixin:OnMouseClickAction(button)
	local data = self.data
	if not data then return end
	if button == "RightButton" then
		-- Built-in pins pass right-click through to the map (zoom out), like empty map space.
		local map = self:GetMap()
		if map and map.NavigateToParentMap then map:NavigateToParentMap() end
		return
	end
	ns.Waypoint:HandleClick(button, data.mapID, data.x, data.y, data.clickOptions)
end

-- Acquires pins for a data provider without ever letting an error escape into Blizzard's map
-- refresh. The first failure per layer is reported once in chat; the rest of that layer is skipped.
local reported = {}
function ns:SafeAcquirePins(map, template, list, build)
	for i = 1, #list do
		local ok, err = pcall(function() map:AcquirePin(template, build(list[i])) end)
		if not ok then
			if not reported[template] then
				reported[template] = true
				ns:Print("|cffff3333couldn't draw %s pins; this layer is skipped. Please report:|r %s", template, tostring(err))
			end
			return false
		end
	end
	return true
end

-- Runs fn once the world map exists (it is load-on-demand on some clients).
function ns:OnWorldMapReady(fn)
	if WorldMapFrame then
		fn(WorldMapFrame)
		return
	end
	local done = false
	ns:RegisterEvent("ADDON_LOADED", function(name)
		if not done and name == "Blizzard_WorldMap" and WorldMapFrame then
			done = true
			fn(WorldMapFrame)
		end
	end)
end
