-- /pathfinder and /pf
local _, ns = ...

local COMMANDS = {
	{ "", "open the settings panel" },
	{ "debug", "open or close the debug window (diagnostic output)" },
	{ "unreleased", "testing only: show or hide raids that aren't in Forever yet" },
	{ "api", "API availability check (debug window)" },
	{ "linktest", "test the native map pin chat link; sends nothing (debug window + chat links)" },
	{ "taxi", "flight path check: faction mapping, cached paths, status counts (debug window)" },
	{ "levels", "instance levels and the client's instance list vs the static table (debug window)" },
	{ "entrances", "recorded instance entrances, queue-only list, recent recording attempts (debug window)" },
	{ "version", "print the addon version" },
	{ "help", "show this list" },
}

local function printHelp()
	ns:Print("v%s commands:", ns.version)
	for _, entry in ipairs(COMMANDS) do
		local cmd = entry[1] == "" and "/pf" or ("/pf " .. entry[1])
		DEFAULT_CHAT_FRAME:AddMessage(("  |cffffff00%s|r - %s"):format(cmd, entry[2]))
	end
end

SLASH_PATHFINDER1 = "/pathfinder"
SLASH_PATHFINDER2 = "/pf"
SlashCmdList.PATHFINDER = function(input)
	local cmd = strtrim(input or ""):lower():match("^(%S*)")

	if cmd == "" then
		ns.SettingsPanel:Open()
	elseif cmd == "api" then
		ns.APICheck:Run()
		ns.APICheck:PrintReport(true)
	elseif cmd == "linktest" then
		ns.APICheck:LinkTest()
	elseif cmd == "taxi" then
		ns.FlightPaths:PrintDebug()
	elseif cmd == "levels" then
		ns.InstanceInfo:Report()
	elseif cmd == "unreleased" then
		ns:SetSetting("showUnreleasedRaids", not ns:GetSetting("showUnreleasedRaids"))
		ns:Print("Unreleased raids (testing only): %s.", ns:GetSetting("showUnreleasedRaids") and "|cff33ff33shown|r" or "hidden")
	elseif cmd == "entrances" then
		ns.WorldData:Report()
	elseif cmd == "debug" then
		ns.DebugWindow:Toggle()
	elseif cmd == "version" then
		ns:Print("version %s", ns.version)
	else
		printHelp()
	end
end
