-- Native Settings panel (Options > AddOns > Pathfinder). Values live in PathfinderDB.settings.
local _, ns = ...

local SettingsPanel = ns:NewModule("SettingsPanel")

function SettingsPanel:OnInitialize()
	local category, layout = Settings.RegisterVerticalLayoutCategory(ns.title)
	self.category = category

	local store = ns.db.settings
	local defaults = ns.Database.accountDefaults.settings

	local function register(key, varType, name)
		local variable = "PATHFINDER_" .. key
		local setting = Settings.RegisterAddOnSetting(category, variable, key, store, varType, name, defaults[key])
		Settings.SetOnValueChangedCallback(variable, function()
			ns:Fire("SETTING_CHANGED", key, store[key])
		end)
		return setting
	end

	local function header(text)
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
	end

	local function checkbox(key, name, tooltip)
		return Settings.CreateCheckbox(category, register(key, Settings.VarType.Boolean, name), tooltip)
	end

	local function disable(initializer)
		if initializer.AddModifyPredicate then
			initializer:AddModifyPredicate(function() return false end)
		end
	end

	local COMING_SOON = " |cff888888(coming soon)|r"

	-- Layer categories (Core\Categories.lua) ---------------------------------
	for _, cat in ipairs(ns.CATEGORIES) do
		header(cat.label)

		local anyAvailable = cat.available ~= false
		if anyAvailable then
			anyAvailable = false
			for _, layer in ipairs(cat.layers) do
				if layer.available then anyAvailable = true end
			end
		end

		local masterLabel = "Show " .. cat.label:lower() .. " pins" .. (anyAvailable and "" or COMING_SOON)
		local masterInit = checkbox(cat.master, masterLabel, cat.note or ("Turn every " .. cat.label:lower() .. " layer on or off."))
		if not anyAvailable then disable(masterInit) end

		for _, layer in ipairs(cat.layers) do
			local label = layer.label .. (layer.available and "" or COMING_SOON)
			local init = checkbox(layer.key, label, layer.tooltip or (layer.label .. " pins."))
			local available = layer.available
			local master = cat.master
			if init.SetParentInitializer then
				-- Indented under the master toggle; greyed out while the master is off.
				init:SetParentInitializer(masterInit, function() return available and store[master] end)
			elseif not available then
				disable(init)
			end
		end

		-- Instances: queue-only dungeons have no map pin, so list them here (in the debug window).
		if cat.key == "instances" and CreateSettingsButtonInitializer then
			layout:AddInitializer(CreateSettingsButtonInitializer(
				"Instances without a pin yet", "Show list",
				function() ns.WorldData:Report() end,
				"Lists instances whose entrance hasn't been recorded yet, with where to look (from Blizzard's descriptions), plus queue-only dungeons and every recorded entrance (same as /pf entrances). Walk into an instance once and its pin appears.",
				true))
		end
	end

	-- Display ----------------------------------------------------------------
	header("Display")
	checkbox("showOnMinimap", "Show pins on minimap",
		"Show pins on the minimap when they are within its visible range.")

	do
		local setting = register("pinScale", Settings.VarType.Number, "Pin size")
		local options = Settings.CreateSliderOptions(0.5, 2.0, 0.05)
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
			return ("%d%%"):format(math.floor(value * 100 + 0.5))
		end)
		Settings.CreateSlider(category, setting, options, "Scale of all Pathfinder pins.")
	end

	-- Sharing ----------------------------------------------------------------
	header("Sharing")
	do
		local setting = register("incomingShareMode", Settings.VarType.String, "Incoming shared pins")
		local function getOptions()
			local container = Settings.CreateControlTextContainer()
			container:Add(ns.SHARE_MODE.AUTO, "Auto-add to \"Shared with me\"",
				"Pins shared with you are added to the \"Shared with me\" group without asking.")
			container:Add(ns.SHARE_MODE.POPUP, "Ask me (Accept / Decline)",
				"Show a popup with the sender and pin so you can accept or decline.")
			container:Add(ns.SHARE_MODE.TRUSTED, "Ask for friends and guild only",
				"Show the popup only for friends and guild members. Shares from anyone else are ignored.")
			return container:GetData()
		end
		Settings.CreateDropdown(category, setting, getOptions, "What happens when another Pathfinder user shares a pin with you.")
	end

	-- Advanced ---------------------------------------------------------------
	header("Advanced")
	checkbox("apiCheckOnLogin", "Print API check on login",
		"Print a short report of which client APIs Pathfinder can use after each login.")
	checkbox("debug", "Debug messages", "Print extra diagnostic messages to chat.")

	Settings.RegisterAddOnCategory(category)
end

function SettingsPanel:Open()
	if InCombatLockdown() then
		ns:Print("Settings can't be opened in combat.")
		return
	end
	Settings.OpenToCategory(self.category:GetID())
end
