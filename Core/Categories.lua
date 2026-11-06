-- Layer categories. Drives the Settings panel and layer visibility.
-- Each category has a master toggle; each layer inside has its own toggle.
-- available = false marks a layer that's planned but not built yet ("coming soon").
local _, ns = ...

local function trainer(profession)
	return { key = "showTrainer" .. profession:gsub("%s", ""), label = profession, available = false }
end

ns.CATEGORIES = {
	{
		key = "travel", label = "Travel", master = "showTravel",
		layers = {
			{ key = "showFlightPaths", label = "Flight paths", available = true,
				tooltip = "Every flight master. Green = discovered, yellow = available but not discovered, red = never available to this character." },
			{ key = "showZeppelins", label = "Zeppelins", available = false },
			{ key = "showBoats", label = "Boats", available = false },
			{ key = "showPortals", label = "Portals", available = false },
		},
	},
	{
		key = "instances", label = "Instances", master = "showInstances",
		layers = {
			{ key = "showDungeons", label = "Dungeons", available = true,
				tooltip = "Dungeon entrances, tinted by level range compared to your level." },
			{ key = "showRaids", label = "Raids", available = true,
				tooltip = "Raid entrances, tinted by level range compared to your level." },
		},
	},
	{
		key = "services", label = "Services", master = "showServices",
		layers = {
			{ key = "showBanks", label = "Banks", available = false },
			{ key = "showAuctioneers", label = "Auctioneers", available = false },
			{ key = "showInnkeepers", label = "Innkeepers", available = false },
			{ key = "showTransmog", label = "Transmog", available = false },
		},
	},
	{
		key = "trainers", label = "Trainers", master = "showTrainers",
		layers = {
			trainer("Alchemy"), trainer("Blacksmithing"), trainer("Enchanting"), trainer("Engineering"),
			trainer("Herbalism"), trainer("Leatherworking"), trainer("Mining"), trainer("Skinning"),
			trainer("Tailoring"), trainer("Cooking"), trainer("First Aid"), trainer("Fishing"),
		},
	},
	{
		key = "custom", label = "Custom", master = "showCustom", available = false,
		note = "Your own pins. Each group can be shown or hidden from the panel on the world map.",
		layers = {},
	},
}

-- layer key -> category
local categoryOfLayer = {}
for _, category in ipairs(ns.CATEGORIES) do
	for _, layer in ipairs(category.layers) do
		categoryOfLayer[layer.key] = category
	end
end

-- Default for every category/layer toggle: on.
function ns:GetCategoryDefaults()
	local defaults = {}
	for _, category in ipairs(ns.CATEGORIES) do
		defaults[category.master] = true
		for _, layer in ipairs(category.layers) do defaults[layer.key] = true end
	end
	return defaults
end

function ns:IsLayerShown(layerKey)
	local settings = ns.db.settings
	local category = categoryOfLayer[layerKey]
	if category and not settings[category.master] then return false end
	return settings[layerKey] and true or false
end

-- True if a change to settingKey can change whether layerKey is shown.
function ns:AffectsLayer(layerKey, settingKey)
	if settingKey == layerKey then return true end
	local category = categoryOfLayer[layerKey]
	return category ~= nil and category.master == settingKey
end
