-- /pathfinder and /pf
local _, ns = ...

local COMMANDS = {
	{ "", "open the settings panel" },
	{ "api", "run the API availability check and print details" },
	{ "linktest", "test the native map pin chat link (prints locally, sends nothing)" },
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
	elseif cmd == "version" then
		ns:Print("version %s", ns.version)
	else
		printHelp()
	end
end
