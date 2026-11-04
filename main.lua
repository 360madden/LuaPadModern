--[[
	Project: LuaPad
	Current version: RiftAddon.toc (displayed dynamically at runtime)
	Original author: NerfedWar (http://www.nerfedwar.net - nerfed.war@gmail.com)
	LuaPadModern author/maintainer: Joey Delfierro (GitHub 360madden)
	
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
	
]] 
LuaPad = {}

local context = UI.CreateContext("LuaPadContext")
local luaPadWindow = Library.LibSimpleWidgets.Window("LuaPadluaPadWindow", context) 
local scriptList = UI.CreateFrame("Text", "LuaPadScriptList", luaPadWindow)
local scriptListSeperator = UI.CreateFrame("Frame", "LuaPadScriptListSeperator", luaPadWindow)
local outputSeperator = UI.CreateFrame("Frame", "LuaPadOutputSeperator", luaPadWindow)
local inputFieldScroll = Library.LibSimpleWidgets.ScrollView("LuaPadInputFieldScroll", luaPadWindow:GetContent())
local outputFieldScroll = Library.LibSimpleWidgets.ScrollView("LuaPadOutputFieldScroll", luaPadWindow:GetContent())
local inputField = nil
local outputField = nil
local closeButton = UI.CreateFrame("Texture", "LuaPadCloseButton", luaPadWindow)
-- RRECollector-inspired ordinary buttons: no deprecated RiftButton skin.
-- Pointer feedback is handled on a single full-masked host per button.
local function modernButton(name, parent)
  local host = UI.CreateFrame("Frame", name, parent)
  host:SetHeight(28)
  host:SetWidth(100)
  host:SetMouseMasking("full")
  local fill = UI.CreateFrame("Frame", name .. "Fill", host)
  fill:SetLayer(0)
  fill:SetPoint("TOPLEFT", host, "TOPLEFT", 1, 1)
  fill:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -1, -1)
  fill:SetMouseMasking("limited")
  local label = UI.CreateFrame("Text", name .. "Label", host)
  label:SetLayer(3)
  label:SetPoint("CENTER", host, "CENTER", 0, 0)
  label:SetFontSize(13)
  label:SetFontColor(0.94, 0.96, 0.98, 1)
  label:SetWordwrap(false)
  label:SetMouseMasking("limited")
  local border = {}
  for i = 1, 4 do
    border[i] = UI.CreateFrame("Frame", name .. "Edge" .. i, host)
    border[i]:SetLayer(1)
    border[i]:SetMouseMasking("limited")
  end
  border[1]:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
  border[1]:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0)
  border[1]:SetHeight(1)
  border[2]:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, 0)
  border[2]:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
  border[2]:SetHeight(1)
  border[3]:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 1)
  border[3]:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, -1)
  border[3]:SetWidth(1)
  border[4]:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 1)
  border[4]:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, -1)
  border[4]:SetWidth(1)
  local hovered, pressed = false, false
  local function paint()
    if pressed then fill:SetBackgroundColor(0.045, 0.09, 0.126, 1)
    elseif hovered then fill:SetBackgroundColor(0.145, 0.28, 0.33, 0.99)
    else fill:SetBackgroundColor(0.102, 0.19, 0.239, 0.98) end
    local light = pressed and 0.04 or 0.64
    local dark = pressed and 0.64 or 0.04
    border[1]:SetBackgroundColor(light, light, light, 1)
    border[3]:SetBackgroundColor(light, light, light, 1)
    border[2]:SetBackgroundColor(dark, dark, dark, 1)
    border[4]:SetBackgroundColor(dark, dark, dark, 1)
    label:SetFontColor(hovered and 0.45 or 0.94, hovered and 0.91 or 0.96, hovered and 1 or 0.98, 1)
    label:SetPoint("CENTER", host, "CENTER", pressed and 1 or 0, pressed and 1 or 0)
  end
  local mouse = Event.UI.Input.Mouse
  local function attach(event, cb, suffix)
    if event then host:EventAttach(event, cb, name .. suffix) end
  end
  attach(mouse.Cursor and mouse.Cursor.In, function() hovered = true; paint() end, " hover")
  attach(mouse.Cursor and mouse.Cursor.Out, function() hovered = false; pressed = false; paint() end, " leave")
  attach(mouse.Left and mouse.Left.Down, function() pressed = true; paint() end, " down")
  attach(mouse.Left and mouse.Left.Up, function() pressed = false; paint() end, " up")
  attach(mouse.Left and mouse.Left.Upoutside, function() pressed = false; paint() end, " cancel")
  local result = { Event = {} }
  attach(mouse.Left and mouse.Left.Click, function()
    if result.Event.LeftPress then
      local ok, err = pcall(result.Event.LeftPress, result.Event)
      if not ok then print("LuaPad button " .. name .. ": " .. tostring(err)) end
    end
  end, " click")
  function result:SetText(value) label:SetText(tostring(value or "")) end
  function result:SetPoint(...) host:SetPoint(...) end
  function result:SetWidth(value) host:SetWidth(value) end
  function result:SetLayer(value) host:SetLayer(value) end
  paint()
  return result
end
local loadButton = modernButton("LuaPadLoadButton", luaPadWindow)
local saveButton = modernButton("LuaPadSaveButton", luaPadWindow)
local delButton = modernButton("LuaPadClearButton", luaPadWindow)
local runButton = modernButton("LuaPadRunButton", luaPadWindow)
local helpButton = modernButton("LuaPadHelpButton", luaPadWindow)
local inspectButton = modernButton("LuaPadInspectButton", luaPadWindow)
local copyOutputButton = modernButton("LuaPadCopyOutputButton", luaPadWindow)


local label1 = UI.CreateFrame("Text", "LuaPadLabel1", luaPadWindow)
local label2 = UI.CreateFrame("Text", "LuaPadLabel2", luaPadWindow)
local label3 = UI.CreateFrame("Text", "LuaPadLabel3", luaPadWindow)
	
local snippetButtons = {}
local snippetRepaints = {}
local selectedSnippet = nil

local origPrint = nil

local isRunning = false

-- The TOC is the single source of truth for the displayed addon version.
local function currentVersion()
	local detailFn = Inspect and Inspect.Addon and Inspect.Addon.Detail
	if type(detailFn) == "function" then
		local ok, detail = pcall(detailFn, "LuaPad")
		if ok and type(detail) == "table" and type(detail.toc) == "table" then
			local version = detail.toc.Version or detail.toc.version
			if version ~= nil and tostring(version) ~= "" then return tostring(version) end
		end
	end
	return "unknown"
end

local function currentTitle()
	return "LuaPad v" .. currentVersion() .. " | by Joey Delfierro"
end

-- RIFT's Lua 5.1 string indices are bytes, not UTF-8 characters. Trim
-- preview text only at complete codepoint boundaries.
local function utf8BytePrefix(value, maxBytes)
	if #value <= maxBytes then return value end
	local start = maxBytes
	while start > 0 do
		local byte = value:byte(start)
		if byte < 128 or byte >= 192 then
			local width = byte < 128 and 1 or byte < 224 and 2 or byte < 240 and 3 or byte < 248 and 4 or 1
			if start + width - 1 > maxBytes then return value:sub(1, start - 1) end
			break
		end
		start = start - 1
	end
	return value:sub(1, maxBytes)
end

local function utf8ByteSuffix(value, maxBytes)
	if #value <= maxBytes then return value end
	local first = #value - maxBytes + 1
	while first <= #value do
		local byte = value:byte(first)
		if byte < 128 or byte >= 192 then break end
		first = first + 1
	end
	return value:sub(first)
end

-- Keep the full diagnostic available for clipboard while bounding the widget
-- rendering cost. Runtime errors can contain thousands of newline characters.
local lastOutput = ""
local MAX_RENDER_BYTES, MAX_RENDER_NEWLINES = 12100, 300
local function setOutput(message, resetScroll)
	if not outputField then return end
	if resetScroll then outputFieldScroll.offset = 0 end
	lastOutput = tostring(message or "")
	local rendered = utf8BytePrefix(lastOutput, MAX_RENDER_BYTES)
	local shortened = #rendered < #lastOutput
	local newlineCount, startAt = 0, 1
	while true do
		local lineEnd = rendered:find("\n", startAt, true)
		if not lineEnd then break end
		newlineCount = newlineCount + 1
		if newlineCount >= MAX_RENDER_NEWLINES and lineEnd < #rendered then
			rendered = rendered:sub(1, lineEnd)
			shortened = true
			break
		end
		startAt = lineEnd + 1
	end
	if shortened then rendered = rendered .. "\n[Display shortened; Copy Output includes full text.]" end
	outputField:SetText(rendered)
	local visualLines = 0
	for line in (rendered .. "\n"):gmatch("(.-)\n") do
		visualLines = visualLines + math.max(1, math.ceil(#line / 70))
	end
	outputField:SetHeight(math.max(150, visualLines * 17 + 10))
	outputFieldScroll:ContentResized()
end

-- Addon initialisation
local function init()

	luaPadWindow:SetVisible(false)
	
	luaPadWindow:SetWidth(840)
	luaPadWindow:SetHeight(600)
	-- Center relative to RIFT's UI parent; the anchor follows client resizes.
	luaPadWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	luaPadWindow:SetTitle(currentTitle())
	luaPadWindow:SetLayer(1)
	luaPadWindow:SetAlpha(0.98)
	
	scriptListSeperator:SetWidth(2)
	scriptListSeperator:SetBackgroundColor(0,0,0,0.5)
	scriptListSeperator:SetHeight(542)
	scriptListSeperator:SetPoint("TOPRIGHT", luaPadWindow, "TOPRIGHT", -294, 46)
	
	outputSeperator:SetWidth(530)
	outputSeperator:SetBackgroundColor(0,0,0,0.5)
	outputSeperator:SetHeight(2)
	outputSeperator:SetPoint("LEFTCENTER", luaPadWindow, "LEFTCENTER", 14, 100)	
	
	scriptList:SetWidth(280)
	scriptList:SetHeight(480)
	scriptList:SetPoint("TOPRIGHT", luaPadWindow, "TOPRIGHT", -12, 60)	
	scriptList:SetLayer(1)
	
	inputFieldScroll:SetWidth(500)
	inputFieldScroll:SetHeight(292)
	inputFieldScroll:SetBorder(1,1,1,1,0.2)
	inputFieldScroll:SetPoint("TOPLEFT", luaPadWindow, "TOPLEFT", 32, 105)
	inputField = UI.CreateFrame("RiftTextfield", "LuaPadInputField", inputFieldScroll)
	inputField:SetBackgroundColor(0,0,0,0.5)
	inputField:SetHeight(292)
	inputField:SetText("")
	inputFieldScroll:SetContent(inputField)
	
	outputFieldScroll:SetWidth(500)
	outputFieldScroll:SetHeight(150)
	outputFieldScroll:SetBorder(1,1,1,1,0.2)
	outputFieldScroll:SetPoint("TOPLEFT", luaPadWindow, "TOPLEFT", 32, 418)
	outputField = UI.CreateFrame("Text", "LuaPadOutputField", outputFieldScroll)
	outputField:SetBackgroundColor(0,0,0,0.5)
	outputField:SetFontSize(12)
	outputField:SetWordwrap(true)
	outputField:SetHeight(150)
	outputFieldScroll:SetContent(outputField)
	
	-- The physical RiftTextfield consumes Enter/Tab before the generic
	-- Event.UI.Input.Key.Down callback. Use its native KeyDown event table,
	-- matching the original LuaPad input registration.
	function inputField.Event:KeyDown(button)
		local insert
		if type(button) == "string" then
			local code = button:byte(1)
			local named = button:lower()
			if code == 13 or code == 10 or named == "return" or named == "enter" then
				insert = "\n"
			elseif code == 9 or named == "tab" then
				insert = "  "
			end
		end
		if not insert then return end
		local txt = inputField:GetText() or ""
		local fromPos = inputField:GetCursor() or #txt
		local toPos = fromPos
		-- Preserve Preview 16 selection-replacement behavior.
		if type(inputField.GetSelection) == "function" then
			local beginPos, endPos = inputField:GetSelection()
			if type(beginPos) == "number" and type(endPos) == "number"
				and beginPos >= 0 and beginPos < endPos and endPos <= #txt then
				fromPos, toPos = beginPos, endPos
			end
		end
		inputField:SetKeyFocus(true)
		inputField:SetText(txt:sub(1, fromPos) .. insert .. txt:sub(toPos + 1))
		if type(inputField.SetSelection) == "function" then inputField:SetSelection() end
		inputField:SetCursor(fromPos + #insert)
	end
	inputField:EventAttach(Event.UI.Textfield.Change, function()
		local _, newlineCount = (inputField:GetText() or ""):gsub("\n", "\n")
		inputField:SetHeight(math.max(16 * (newlineCount + 1), 292))
	end, "LuaPad editor changed")	
	
	-- Register actions; their captions, dimensions and placement are centralized below.
	function loadButton.Event:LeftPress()
		loadSnippet()
	end
	function saveButton.Event:LeftPress()
		saveSnippet()
	end
	function delButton.Event:LeftPress()
		clearSnippet()
	end
	function runButton.Event:LeftPress()
		LuaPad.doRun(inputField:GetText())
	end
	function inspectButton.Event:LeftPress()
		Inspector.showInspectionWindow()
	end
	function helpButton.Event:LeftPress()
		setOutput("LuaPad v" .. currentVersion() .. "\n/lp or /luapad: show editor\nRun: compile and execute code\nInspect: open object inspector\nSelect a snippet slot, then Save or Load.\nClear empties the selected snippet slot.\nSyntax and runtime errors appear here.\nCopy Output: copies the output text to the Windows clipboard.\nStart with: print(Inspect and type(Inspect))", true)
	end

	-- RIFT provides a native clipboard command. Copy the displayed output in one click.
	function copyOutputButton.Event:LeftPress()
		local content = lastOutput
		content = tostring(content or "")
		if content == "" then
			print("LuaPad: Nothing in the output pane to copy.")
			return
		end
		if not Command or type(Command.CopyToClipboard) ~= "function" then
			print("LuaPad: Clipboard API unavailable in this RIFT client.")
			return
		end
		local ok, copied = pcall(Command.CopyToClipboard, content)
		if ok and copied ~= false then
			print("LuaPad: Output copied to clipboard (" .. #content .. " bytes).")
		else
			print("LuaPad: Copy failed: " .. tostring(copied))
		end
	end

	-- All seven actions share one 500px-wide toolbar, exactly aligned to the editor.
	-- The fixed gap and widths keep Copy Output in the same visual language.
	local toolbar = {
		{ runButton, "Run", 58 },
		{ inspectButton, "Inspect", 68 },
		{ saveButton, "Save", 58 },
		{ loadButton, "Load", 58 },
		{ delButton, "Clear", 58 },
		{ helpButton, "Help", 58 },
		{ copyOutputButton, "Copy Output", 112 },
	}
	local toolbarX = 32
	for _, item in ipairs(toolbar) do
		local control, caption, width = item[1], item[2], item[3]
		control:SetText(caption)
		control:SetWidth(width)
		control:SetPoint("TOPLEFT", luaPadWindow, "TOPLEFT", toolbarX, 48)
		control:SetLayer(2)
		toolbarX = toolbarX + width + 5
	end

	closeButton:SetTexture("LuaPad", "close.png")
	closeButton:SetPoint("TOPRIGHT", luaPadWindow, "TOPRIGHT", -8, 16)	
	closeButton:SetMouseMasking("full")
	closeButton:EventAttach(Event.UI.Input.Mouse.Left.Click, function()
		inputField:SetKeyFocus(false)
		luaPadWindow:SetVisible(false)
	end, "LuaPad close")		
	
	label1:SetPoint("TOPLEFT", luaPadWindow, "TOPLEFT", 30, 86)	
	label1:SetText("Code Editor")
	label1:SetFontSize(12)
	label1:SetFontColor(0.73,0.88,0.92,1)
	
	label2:SetPoint("TOPLEFT", luaPadWindow, "TOPLEFT", 30, 400)	
	label2:SetText("Output")
	label2:SetFontSize(12)
	label2:SetFontColor(0.73,0.88,0.92,1)
	
	label3:SetPoint("TOPLEFT", luaPadWindow, "TOPLEFT", 554, 48)
	label3:SetText("Code Snippets")
	label3:SetFontSize(12)
	label3:SetFontColor(0.73,0.88,0.92,1)
	
end


-- RIFT addon strata outrank numerical layers in lower strata. Installed
-- BotFight/LibWiki controls use "topmost", while the API Readiness window
-- uses layer 999990. Preview 18's "dialog" + window layer 1 was insufficient.
local function bringLuaPadForward()
	local targetStrata = "topmost"
	if type(context.GetStrataList) == "function" then
		local ok, available = pcall(context.GetStrataList, context)
		if ok and type(available) == "table" then
			targetStrata = nil
			for _, name in ipairs(available) do
				if name == "topmost" then targetStrata = name; break end
				if name == "dialog" then targetStrata = name end
			end
		end
	end
	if targetStrata and type(context.SetStrata) == "function" then
		pcall(context.SetStrata, context, targetStrata)
	end

	-- UI.Context[addon][name][index] contains peer contexts; an addon may
	-- also assign extremely high layers to a child RiftWindow (the installed
	-- RiftReaderApiProbe and BotFight panels do). Sample both with a hard work
	-- budget and never traverse our own context/editor hierarchy.
	local ourStrata
	if type(context.GetStrata) == "function" then
		local ok, strata = pcall(context.GetStrata, context)
		if ok and type(strata) == "string" then ourStrata = strata end
	end
	local highestContext, highestFrame, traversed, seen = 0, 0, 0, {}
	local function visit(node, depth)
		if depth > 7 or traversed >= 1024 then return end
		local kind = type(node)
		if kind ~= "table" and kind ~= "userdata" or seen[node] then return end
		seen[node] = true
		traversed = traversed + 1
		if node == context then return end
		local ok, getterLayer, getterStrata, getterChildren = pcall(function()
			return node.GetLayer, node.GetStrata, node.GetChildren
		end)
		if ok and type(getterLayer) == "function" and type(getterStrata) == "function" then
			local gotLayer, layer = pcall(getterLayer, node)
			local gotStrata, strata = pcall(getterStrata, node)
			if gotLayer and gotStrata and strata == ourStrata
				and type(layer) == "number" and layer == layer
				and layer >= 0 and layer < 2000000 then
				highestFrame = math.max(highestFrame, math.floor(layer))
				if layer < 4096 then highestContext = math.max(highestContext, math.floor(layer)) end
			end
			if type(getterChildren) == "function" then
				local gotChildren, children = pcall(getterChildren, node)
				if gotChildren and type(children) == "table" then
					for _, child in pairs(children) do visit(child, depth + 1) end
				end
			end
			return
		end
		if kind == "table" then
			for _, child in pairs(node) do visit(child, depth + 1) end
		end
	end
	if type(UI.Context) == "table" then visit(UI.Context, 0) end

	local ours = 0
	if type(context.GetLayer) == "function" then
		local ok, layer = pcall(context.GetLayer, context)
		if ok and type(layer) == "number" and layer == layer and layer >= 0 then
			ours = layer
		end
	end
	local neededContext = math.min(4096, math.max(10, highestContext + 1))
	if ours < neededContext and type(context.SetLayer) == "function" then
		pcall(context.SetLayer, context, neededContext)
	end
	local windowLayer = 0
	if type(luaPadWindow.GetLayer) == "function" then
		local ok, layer = pcall(luaPadWindow.GetLayer, luaPadWindow)
		if ok and type(layer) == "number" and layer == layer and layer >= 0 then
			windowLayer = layer
		end
	end
	-- The floor outranks the *observed* 999990-999999 child layers even if
	-- peer child enumeration is unavailable in this client; the cap avoids an
	-- unlimited race with addons that constantly rewrite their layers.
	local neededWindow = math.min(2000000, math.max(1000010, highestFrame + 1))
	if windowLayer < neededWindow and type(luaPadWindow.SetLayer) == "function" then
		pcall(luaPadWindow.SetLayer, luaPadWindow, neededWindow)
	end
end

-- Showing on startup must not steal the user's gameplay keyboard focus.
local function showLuaPad()
	luaPadWindow:SetTitle(currentTitle())
	bringLuaPadForward()
	luaPadWindow:SetVisible(true)
end


local function scheduleFirstFrameRaise()
	-- Other addons can create dialog contexts after our Lua file executes.
	-- Re-evaluate z-order once on the first rendered frame, then detach.
	if not (Event.System and Event.System.Update and Event.System.Update.Begin
		and Command.Event and type(Command.Event.Attach) == "function"
		and type(Command.Event.Detach) == "function") then return end
	local firstFrame, fired = nil, false
	firstFrame = function()
		if fired then return end
		fired = true
		pcall(Command.Event.Detach, Event.System.Update.Begin, firstFrame)
		if luaPadWindow:GetVisible() then bringLuaPadForward() end
	end
	Command.Event.Attach(Event.System.Update.Begin, firstFrame, "LuaPad startup z-order")
end

-- run the code!
function LuaPad.doRun(obj)
	-- A nested Run would replace origPrint with LuaPad.print itself, leaving the
	-- global print hook recursive after the outer execution returns.
	if isRunning then
		LuaPad.print("LuaPad: Nested Run ignored; an editor script is already executing.")
		return
	end
	if( (obj == nil) or (obj == "") ) then
		setOutput('Please enter some Lua code and then press run.')
		return
	end
	isRunning=true
	outputFieldScroll.offset = 0
	setOutput('')
	
	local loader = type(loadstring) == "function" and loadstring or load
	if type(loader) ~= "function" then
		setOutput("Lua code compiler unavailable in this RIFT environment.")
		isRunning = false
		return
	end
	local compileOK, compiled, compileError = pcall(loader, obj)
	if not compileOK or not compiled then
		setOutput("Syntax error: " .. tostring(compileOK and compileError or compiled))
		isRunning = false
		return
	end
	-- Capture output only during this execution; leave global print untouched while idle.
	origPrint = print
	print = LuaPad.print
	local retOK, runtimeError = xpcall(compiled, function(err)
		local trace = type(debug) == "table" and type(debug.traceback) == "function"
			and debug.traceback(tostring(err), 2) or tostring(err)
		return trace
	end)
	print = origPrint
	if not retOK then
		local previous = lastOutput
		setOutput(previous .. "\nRuntime error: " .. tostring(runtimeError))
	end
	isRunning = false
end


-- create the snippet buttons
-- NOTE: Rift Lua has no math.mod (removed after 5.1). Use % instead.
local function createSnippetButtons()
	if snippetButtons[1] then
		return
	end
	local textMargin = 10
	for i=1,16 do
		local text = UI.CreateFrame("Text", "LuaPadSnippetButton" .. tostring(i), scriptList)
		if (i % 2) ~= 0 then
			text:SetPoint("TOPLEFT", scriptList, "TOPLEFT", textMargin, textMargin+(((i/2)*60)-30))
		else
			text:SetPoint("TOPLEFT", scriptList, "TOPLEFT", textMargin+((280-(2*textMargin))/2), textMargin+((((i-1)/2)*60)-30))
		end
		text:SetWidth((270-(2*textMargin))/2)
		text:SetHeight(60-(textMargin/2))
		text:SetBackgroundColor(0.084, 0.148, 0.182, 0.97)
		text:SetFontColor(1,1,1)
		text:SetFontSize(10)
		text:SetWordwrap(false)
		text:SetText('')
		text:SetMouseMasking("full")
		local hovered, pressed = false, false
		local function repaint()
			local selected = selectedSnippet == i
			if pressed then text:SetBackgroundColor(0.045, 0.09, 0.126, 1)
			elseif hovered then text:SetBackgroundColor(0.145, 0.28, 0.33, 0.99)
			elseif selected then text:SetBackgroundColor(0.105, 0.215, 0.276, 1)
			else text:SetBackgroundColor(0.084, 0.148, 0.182, 0.97) end
			text:SetFontColor(selected and 0.47 or 0.94, selected and 0.92 or 0.96, selected and 1 or 0.98, 1)
		end
		snippetButtons[i] = text
		snippetRepaints[i] = repaint
		local mouse = Event.UI.Input.Mouse
		if mouse.Cursor and mouse.Cursor.In then
			text:EventAttach(mouse.Cursor.In, function() hovered = true; repaint() end, "LuaPad snippet hover " .. i)
		end
		if mouse.Cursor and mouse.Cursor.Out then
			text:EventAttach(mouse.Cursor.Out, function() hovered = false; pressed = false; repaint() end, "LuaPad snippet leave " .. i)
		end
		if mouse.Left and mouse.Left.Down then
			text:EventAttach(mouse.Left.Down, function() pressed = true; repaint() end, "LuaPad snippet down " .. i)
		end
		if mouse.Left and mouse.Left.Up then
			text:EventAttach(mouse.Left.Up, function() pressed = false; repaint() end, "LuaPad snippet up " .. i)
		end
		if mouse.Left and mouse.Left.Upoutside then
			text:EventAttach(mouse.Left.Upoutside, function() pressed = false; repaint() end, "LuaPad snippet cancel " .. i)
		end
		text:EventAttach(mouse.Left.Click, function()
			selectedSnippet = i
			for j = 1, 16 do
				if snippetRepaints[j] then snippetRepaints[j]() end
			end
		end, "LuaPad select snippet " .. i)
		repaint()
	end
end

-- Update snippet buttons
function fillSnippetButtons()
	-- Ensure UI exists (SavedVariables.Load.End can race init on some clients).
	if not snippetButtons[1] then
		createSnippetButtons()
	end
	LuaPad_Snippets = LuaPad_Snippets or {}
	for i=1,16 do
		local btn = snippetButtons[i]
		if btn then
			if LuaPad_Snippets[i] then
				local preview = tostring(LuaPad_Snippets[i]):match("[^\r\n]*") or ""
				if #preview > 17 then preview = utf8BytePrefix(preview, 14) .. "..." end
				btn:SetText(preview == "" and ("Slot " .. i .. " (empty)") or (i .. ": " .. preview))
			else
				btn:SetText("Slot " .. i .. " (empty)")
			end
		end
	end
end


-- load a snippet
function loadSnippet()
	if(selectedSnippet) then
		local snippet = LuaPad_Snippets and LuaPad_Snippets[selectedSnippet]
		if snippet then
			inputField:SetText(snippet)
		else
			inputField:SetText("")
		end
		if snippetRepaints[selectedSnippet] then
			snippetRepaints[selectedSnippet]()
		end
	end
end

-- save a snippet
function saveSnippet()
    if not selectedSnippet then return end
	local snippet = inputField:GetText()
	LuaPad_Snippets = LuaPad_Snippets or {}
	LuaPad_Snippets[selectedSnippet]=snippet
	fillSnippetButtons()
end


-- clear a snippet
function clearSnippet()
	if not selectedSnippet then return end
	LuaPad_Snippets = LuaPad_Snippets or {}
	LuaPad_Snippets[selectedSnippet]=''
	fillSnippetButtons()
end


-- save snippets to saved variable
function saveVar(addon)
	if addon == "LuaPad" then
	end
end

local function hookPrint()
	origPrint = print
	print = LuaPad.print
end

-- load snippets from saved variables
function loadVar(addon)
	if addon == "LuaPad" then
		LuaPad_Snippets = LuaPad_Snippets or { }
		-- Defensive: buttons may not exist yet if createSnippetButtons failed
		-- (old math.mod) or Load.End raced ahead of init.
		if not snippetButtons[1] then
			pcall(createSnippetButtons)
		end
		fillSnippetButtons()
		loadSnippet()
	end
end

function LuaPad.print(...)
	if isRunning then
		local parts = {}
		for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
		local previous = lastOutput
		local line = table.concat(parts, "\t")
		local combined = previous == "" and line or previous .. "\n" .. line
		if #combined > 12000 then combined = utf8ByteSuffix(combined, 12000) end
		setOutput(combined)
	elseif type(origPrint) == "function" then
		origPrint(...)
	end
end

-- Register the slash commands
table.insert(Command.Slash.Register("luapad"), {showLuaPad, "LuaPad", "Slash command"})
table.insert(Command.Slash.Register("lp"), {showLuaPad, "LuaPad", "Slash command"})
table.insert(Event.Addon.SavedVariables.Save.Begin, {saveVar, "LuaPad", "Save variables"})
table.insert(Event.Addon.SavedVariables.Load.End, {loadVar, "LuaPad", "Load variables"})

-- initialisation
-- Wrap so a partial UI failure does not leave Load.End unhandled/crashy.
local function startupStep(name, action)
	local ok, err = pcall(action)
	if not ok then
		if type(print) == "function" then print("LuaPad startup " .. name .. " failed: " .. tostring(err)) end
	end
	return ok
end
if startupStep("init", init) then
	local snippetsOk = startupStep("snippets", createSnippetButtons)
	local loadOk = startupStep("load", loadSnippet)
	if snippetsOk and loadOk and startupStep("show", showLuaPad) then
		startupStep("first-frame stacking", scheduleFirstFrameRaise)
		print("[LuaPad v" .. currentVersion() .. "] READY - editor opened automatically; /lp brings it forward again.")
	else
		print("[LuaPad v" .. currentVersion() .. "] Loaded with UI errors. See the messages above.")
	end
end