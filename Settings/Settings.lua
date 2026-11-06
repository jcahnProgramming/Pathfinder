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
		Settings.CreateCheckbox(category, register(key, Settings.VarType.Boolean, name), tooltip)
	end

	-- Map layers -------------------------------------------------------------
	header("Map layers")
	checkbox("showFlightPaths", "Flight paths",
		"Show every flight master. Green = discovered, yellow = available but not discovered, red = never available to this character.")
	checkbox("showDungeons", "Dungeon entrances",
		"Show dungeon entrances, tinted by level range compared to your level.")
	checkbox("showRaids", "Raid entrances",
		"Show raid entrances, tinted by level range compared to your level.")
	checkbox("showCustom", "Custom pins",
		"Show your custom pins. Individual groups can be shown or hidden from the panel on the world map.")

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
