-- Movable, resizable debug window with a selectable/copyable text box (like the Lua error window).
-- Diagnostic commands append their output here; chat only gets a one-line notice.
-- The buffer lives in memory until Clear or /reload.
local _, ns = ...

local DebugWindow = ns:NewModule("DebugWindow")

local buffer = {}
local frame, editBox

---------------------------------------------------------------------------
-- Text cleanup: the edit box shows raw text, so strip UI escape codes and keep pipes literal.
---------------------------------------------------------------------------
local function plain(text)
	text = tostring(text)
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	text = text:gsub("|A.-|a", ""):gsub("|T.-|t", "")
	text = text:gsub("|H.-|h(.-)|h", "%1")
	return (text:gsub("|", "||"))
end

local function render()
	if editBox then editBox:SetText(table.concat(buffer, "\n")) end
end

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------
local function button(parent, text, width, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

local function build()
	frame = CreateFrame("Frame", "PathfinderDebugFrame", UIParent, "BackdropTemplate")
	frame:SetSize(680, 440)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	if frame.SetResizeBounds then frame:SetResizeBounds(420, 220) end
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
	frame:SetBackdropBorderColor(0.4, 0.6, 0.8, 1)
	frame:Hide()
	tinsert(UISpecialFrames, "PathfinderDebugFrame") -- Escape closes it

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 12, -10)
	title:SetText(("Pathfinder %s - debug output"):format(ns.version))

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 0, 0)

	local scroll = CreateFrame("ScrollFrame", "PathfinderDebugScroll", frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 12, -32)
	scroll:SetPoint("BOTTOMRIGHT", -32, 40)

	editBox = CreateFrame("EditBox", nil, scroll)
	editBox:SetMultiLine(true)
	editBox:SetAutoFocus(false)
	editBox:SetFontObject(ChatFontNormal)
	editBox:SetWidth(scroll:GetWidth())
	editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
	-- Read-only: selection and Ctrl+C work, typing is undone.
	editBox:SetScript("OnTextChanged", function(self, userInput)
		if userInput then render() end
	end)
	editBox:SetScript("OnKeyDown", function(self, key)
		if key == "A" and IsControlKeyDown() then self:HighlightText() end
	end)
	scroll:SetScrollChild(editBox)
	scroll:EnableMouse(true)
	scroll:HookScript("OnMouseDown", function() editBox:SetFocus() end)
	scroll:HookScript("OnSizeChanged", function(self, width) editBox:SetWidth(width) end)

	local grip = CreateFrame("Button", nil, frame)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -4, 4)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
	grip:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() end)

	local clear = button(frame, "Clear", 80, function() DebugWindow:Clear() end)
	clear:SetPoint("BOTTOMLEFT", 12, 10)
	local selectAll = button(frame, "Select All", 100, function()
		editBox:SetFocus()
		editBox:HighlightText()
	end)
	selectAll:SetPoint("LEFT", clear, "RIGHT", 6, 0)
	local closeButton = button(frame, "Close", 80, function() frame:Hide() end)
	closeButton:SetPoint("BOTTOMRIGHT", -24, 10)

	render()
end

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------
function DebugWindow:Show()
	if not frame then build() end
	frame:Show()
end

function DebugWindow:Toggle()
	if frame and frame:IsShown() then frame:Hide() else self:Show() end
end

function DebugWindow:Clear()
	wipe(buffer)
	render()
end

function DebugWindow:Append(title, lines)
	if #buffer > 0 then table.insert(buffer, "") end
	table.insert(buffer, ("==== %s  (%s) ===="):format(plain(title), date("%Y-%m-%d %H:%M:%S")))
	for _, line in ipairs(lines) do table.insert(buffer, plain(line)) end
	self:Show()
	render()
	-- Scroll to the newest output.
	C_Timer.After(0, function()
		local scroll = _G.PathfinderDebugScroll
		if scroll then scroll:SetVerticalScroll(scroll:GetVerticalScrollRange()) end
	end)
end

-- Collects lines for one diagnostic command, then sends them to the window (or chat).
function ns:NewReport(title)
	local report = { title = title, lines = {} }
	function report:Add(fmt, ...)
		local line = select("#", ...) > 0 and fmt:format(...) or tostring(fmt)
		table.insert(self.lines, line)
	end
	function report:ToWindow()
		DebugWindow:Append(self.title, self.lines)
		ns:Print("output in debug window (/pf debug).")
	end
	function report:ToChat()
		ns:Print(self.title)
		for _, line in ipairs(self.lines) do DEFAULT_CHAT_FRAME:AddMessage("  " .. line) end
	end
	return report
end
