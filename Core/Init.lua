-- Pathfinder: namespace, printing, internal callbacks, event dispatch and module lifecycle.
local ADDON_NAME, ns = ...

ns.name = ADDON_NAME
ns.title = "Pathfinder"
ns.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")) or "dev"

---------------------------------------------------------------------------
-- Printing
---------------------------------------------------------------------------
local CHAT_PREFIX = "|cff33ccffPathfinder|r: "

function ns:Print(fmt, ...)
	local msg = select("#", ...) > 0 and fmt:format(...) or tostring(fmt)
	DEFAULT_CHAT_FRAME:AddMessage(CHAT_PREFIX .. msg)
end

function ns:Debug(fmt, ...)
	if ns.db and ns.db.settings.debug then
		ns:Print("|cff888888[debug]|r " .. fmt, ...)
	end
end

---------------------------------------------------------------------------
-- Internal callbacks (addon-wide messages such as SETTING_CHANGED)
---------------------------------------------------------------------------
local listeners = {}

function ns:On(message, fn)
	listeners[message] = listeners[message] or {}
	table.insert(listeners[message], fn)
end

function ns:Fire(message, ...)
	local list = listeners[message]
	if not list then return end
	for i = 1, #list do
		local ok, err = pcall(list[i], ...)
		if not ok then geterrorhandler()(err) end
	end
end

---------------------------------------------------------------------------
-- Game events
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

function ns:RegisterEvent(event, fn)
	if not eventHandlers[event] then
		eventHandlers[event] = {}
		eventFrame:RegisterEvent(event)
	end
	table.insert(eventHandlers[event], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	local list = eventHandlers[event]
	if not list then return end
	for i = 1, #list do
		local ok, err = pcall(list[i], ...)
		if not ok then geterrorhandler()(err) end
	end
end)

---------------------------------------------------------------------------
-- Modules
--   OnInitialize: after SavedVariables are loaded (ADDON_LOADED)
--   OnEnable:     after the player is in the world (PLAYER_LOGIN)
---------------------------------------------------------------------------
ns.modules = {}

function ns:NewModule(name)
	assert(not ns[name], "Pathfinder: module name collision: " .. name)
	local module = { name = name }
	ns[name] = module
	table.insert(ns.modules, module)
	return module
end

local function runAll(method)
	for _, module in ipairs(ns.modules) do
		if module[method] then
			local ok, err = pcall(module[method], module)
			if not ok then geterrorhandler()(err) end
		end
	end
end

local initialized = false
ns:RegisterEvent("ADDON_LOADED", function(loadedName)
	if initialized or loadedName ~= ADDON_NAME then return end
	initialized = true
	runAll("OnInitialize")
end)

ns:RegisterEvent("PLAYER_LOGIN", function()
	runAll("OnEnable")
end)

-- Exposed for the TOC's AddonCompartmentFunc.
function Pathfinder_OnAddonCompartmentClick()
	if ns.SettingsPanel then ns.SettingsPanel:Open() end
end
