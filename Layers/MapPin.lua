-- Shared world map pin behavior for every Pathfinder layer: icon + icon-shaped status glow, size
-- from settings, tooltip, and the standard click conventions (see docs/ROADMAP.md).
--
-- Layers acquire pins with a data table:
--   { mapID, x, y, atlas | texture, color = {r, g, b}, tooltip = function(tooltip, data), clickOptions }
local _, ns = ...

local BASE_SIZE = 16
-- The glow is the icon's own silhouette, desaturated, tinted and drawn additively behind it.
-- Two copies give a soft falloff while staying subtle.
local GLOW_INNER_SCALE, GLOW_INNER_ALPHA = 1.28, 0.75
local GLOW_OUTER_SCALE, GLOW_OUTER_ALPHA = 1.55, 0.35

PathfinderMapPinMixin = CreateFromMixins(MapCanvasPinMixin)

function PathfinderMapPinMixin:OnLoad()
	self:SetScalingLimits(1, 1.0, 1.2)
	-- Not every frame-level type is guaranteed to exist on this client.
	if not pcall(self.UseFrameLevelType, self, "PIN_FRAME_LEVEL_FLIGHT_POINT") then
		pcall(self.UseFrameLevelType, self, "PIN_FRAME_LEVEL_AREA_POI")
	end
	self.GlowInner:SetDesaturated(true)
	self.GlowOuter:SetDesaturated(true)
end

local function setArt(texture, data)
	if data.atlas then
		texture:SetAtlas(data.atlas)
	else
		texture:SetTexture(data.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
	end
end

function PathfinderMapPinMixin:OnAcquired(data)
	self.data = data

	local size = BASE_SIZE * (ns:GetSetting("pinScale") or 1) * (data.sizeScale or 1)
	self:SetSize(size, size)
	self.Icon:SetSize(size, size)
	self.GlowInner:SetSize(size * GLOW_INNER_SCALE, size * GLOW_INNER_SCALE)
	self.GlowOuter:SetSize(size * GLOW_OUTER_SCALE, size * GLOW_OUTER_SCALE)

	setArt(self.Icon, data)
	setArt(self.GlowInner, data)
	setArt(self.GlowOuter, data)
	-- SetAtlas can reset desaturation on some clients.
	self.GlowInner:SetDesaturated(true)
	self.GlowOuter:SetDesaturated(true)

	local c = data.color
	local show = c ~= nil
	self.GlowInner:SetShown(show)
	self.GlowOuter:SetShown(show)
	if show then
		self.GlowInner:SetVertexColor(c[1], c[2], c[3], GLOW_INNER_ALPHA)
		self.GlowOuter:SetVertexColor(c[1], c[2], c[3], GLOW_OUTER_ALPHA)
	end

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
	-- data.waypoint = { mapID, x, y } lets a layer target a more precise map than the one displayed.
	local w = data.waypoint
	if w then
		ns.Waypoint:HandleClick(button, w[1], w[2], w[3], data.clickOptions)
	else
		ns.Waypoint:HandleClick(button, data.mapID, data.x, data.y, data.clickOptions)
	end
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
