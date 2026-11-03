--[[
	Project: Inspector
	Version: 1.0.0
	Author: NerfedWar (http://www.nerfedwar.net - nerfed.war@gmail.com)
	
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

Inspector = {}

local context = UI.CreateContext("InspectorContext")

local helpWindow = Library.LibSimpleWidgets.Window("InspectorHelpWindow", context) 
local helpText = UI.CreateFrame("Text", "InspectorHelpText", helpWindow)
-- Match LuaPad's plain RRE-style controls without the 2012 RiftButton skin.
local function inspectorButton(name, parent)
  local host = UI.CreateFrame("Frame", name, parent)
  host:SetWidth(100); host:SetHeight(28); host:SetMouseMasking("full")
  local fill = UI.CreateFrame("Frame", name .. "Fill", host)
  fill:SetLayer(0)
  fill:SetPoint("TOPLEFT", host, "TOPLEFT", 1, 1)
  fill:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -1, -1)
  fill:SetMouseMasking("limited")
  local caption = UI.CreateFrame("Text", name .. "Caption", host)
  caption:SetLayer(3)
  caption:SetPoint("CENTER", host, "CENTER", 0, 0)
  caption:SetFontSize(13); caption:SetWordwrap(false)
  caption:SetFontColor(0.936, 0.963, 0.977, 1)
  caption:SetMouseMasking("limited")
  local hovered, pressed = false, false
  local function repaint()
    if pressed then fill:SetBackgroundColor(0.045, 0.09, 0.126, 1)
    elseif hovered then fill:SetBackgroundColor(0.145, 0.28, 0.33, 0.99)
    else fill:SetBackgroundColor(0.102, 0.19, 0.239, 0.98) end
    caption:SetFontColor(hovered and 0.45 or 0.94, hovered and 0.91 or 0.96, hovered and 1 or 0.98, 1)
    caption:SetPoint("CENTER", host, "CENTER", pressed and 1 or 0, pressed and 1 or 0)
  end
  local left, cursor = Event.UI.Input.Mouse.Left, Event.UI.Input.Mouse.Cursor
  local function attach(event, action, suffix)
    if event then host:EventAttach(event, action, name .. suffix) end
  end
  local result = { Event = {} }
  attach(cursor and cursor.In, function() hovered = true; repaint() end, " hover")
  attach(cursor and cursor.Out, function() hovered = false; pressed = false; repaint() end, " leave")
  attach(left and left.Down, function() pressed = true; repaint() end, " down")
  attach(left and left.Up, function() pressed = false; repaint() end, " up")
  attach(left and left.Upoutside, function() pressed = false; repaint() end, " cancel")
  attach(left and left.Click, function()
    if result.Event.LeftPress then
      local ok, err = pcall(result.Event.LeftPress, result.Event)
      if not ok then print("Inspector button: " .. tostring(err)) end
    end
  end, " click")
  function result:SetText(value) caption:SetText(tostring(value or "")) end
  function result:SetPoint(...) host:SetPoint(...) end
  repaint()
  return result
end
local helpCloseButton = inspectorButton("InspectorHelpCloseButton", helpWindow)
local helpIcon = UI.CreateFrame("Texture", "InspectorIcon", helpWindow)

local textWindow = Library.LibSimpleWidgets.Window("InspectorTextWindow", context) 
local textField = UI.CreateFrame("RiftTextfield", "InspectorTextField", textWindow)
local inputLabel = UI.CreateFrame("Text", "InspectorInputLabel", textWindow)
local inputField = UI.CreateFrame("RiftTextfield", "InspectorInputField", textWindow)
local depthLabel = UI.CreateFrame("Text", "InspectorDepthLabel", textWindow)
local depthText = UI.CreateFrame("Text", "InspectorDepthField", textWindow)
local depthSlider = UI.CreateFrame("RiftSlider", "InspectorSlider", textWindow)
local closeButton = inspectorButton("InspectorCloseButton", textWindow)
local inspectButton = inspectorButton("InspectorInspectButton", textWindow)
local helpButton = inspectorButton("InspectorHelpButton", textWindow)
	
	
-- Addon initialisation
local function init()

	textWindow:SetVisible(false)
	
	textWindow:SetWidth(800)
	textWindow:SetHeight(600)
	textWindow:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
	textWindow:SetTitle("Inspector")
	textWindow:SetLayer(1)

	textField:SetWidth(750)
	textField:SetHeight(420)
	textField:SetPoint("TOPLEFT", textWindow, "TOPLEFT", 24, 60)
	textField:SetBackgroundColor(0,0,0,0.5)	
	textField:SetText("")
	
	inputLabel:SetWidth(70)
	inputLabel:SetHeight(18)
	inputLabel:SetPoint("BOTTOMLEFT", textWindow, "BOTTOMLEFT", 24, -87)
	inputLabel:SetText("Variable/Table:")	
	
	inputField:SetWidth(670)
	inputField:SetHeight(18)	
	inputField:SetPoint("BOTTOMLEFT", textWindow, "BOTTOMLEFT", 104, -87)
	inputField:SetBackgroundColor(0,0,0,0.8)
	inputField:SetText("")
	-- Inspect only on explicit button press. Evaluating a partial expression on
	-- every keystroke can execute an incomplete function call or flood errors.	
	
	depthLabel:SetWidth(70)
	depthLabel:SetHeight(18)
	depthLabel:SetPoint("BOTTOMLEFT", textWindow, "BOTTOMLEFT", 64, -62)
	depthLabel:SetText("Depth:")	
	
	depthText:SetWidth(50)
	depthText:SetHeight(18)	
	depthText:SetPoint("BOTTOMLEFT", textWindow, "BOTTOMLEFT", 104, -62)
	depthText:SetBackgroundColor(0,0,0,0.8)
	depthText:SetText("1")
	
	depthSlider:SetWidth(610)
	depthSlider:SetPoint("BOTTOMLEFT", textWindow, "BOTTOMLEFT", 164, -54)
	depthSlider:SetRange(0,5)

	depthSlider:SetEnabled(true)
	depthSlider:EventAttach(Event.UI.Slider.Change, function()
		depthText:SetText(tostring(math.max(1, 5 - depthSlider:GetPosition())))
		-- Depth selection updates the label; Inspect runs when the user requests it.
	end, "Inspector depth changed")	
	depthSlider:SetPosition(4)	

	inspectButton:SetText("Inspect")
	inspectButton:SetPoint("BOTTOMLEFT", textWindow, "BOTTOMLEFT", 100, -20)	
	function inspectButton.Event:LeftPress()
		local a = depthText:GetText()	
		Inspector.doInspection(inputField:GetText(), tonumber(a))
	end	
	
	helpButton:SetText("Help")
	helpButton:SetPoint("BOTTOMCENTER", textWindow, "BOTTOMCENTER", 0, -20)	
	function helpButton.Event:LeftPress()
		helpWindow:SetVisible(true)
	end		
	
	closeButton:SetText("Close")
	closeButton:SetPoint("BOTTOMRIGHT", textWindow, "BOTTOMRIGHT", -100, -20)	
	function closeButton.Event:LeftPress()
		textWindow:SetVisible(false)
	end	
end


-- Configures the help window
local function initHelp()

		helpWindow:SetLayer(2)

	-- configure the help window
	helpWindow:SetVisible(false)
	helpWindow:SetWidth(800)
	helpWindow:SetHeight(600)
	helpWindow:SetTitle("Inspector Help")
	helpWindow:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 300, 300)

	-- configure the help text
	helpText:SetWidth(800)
	helpText:SetHeight(600)
	helpText:SetPoint("TOPLEFT", helpWindow, "TOPLEFT", 20, 60)
	helpText:SetFontSize(14)
	helpText:SetText([[
			Inspector provides a quick way to inspect the contents of any LUA variable/table/function. 
	
Usage: 			
	Enter the name of the LUA variable/table/function you want to output and select the
	recursion depth (useful to set this to 1 if you just want ot see the top level
	structure of a LUA table.
	e.g.
		Inspect.Ability.List
			will display: Inspect.Ability.List = function: 0x0ed24bb8
		
		Inspect.Ability.List()
			will display: 
				Inspect.Ability.List().a000000000D674EA0 = true
				Inspect.Ability.List().a000000006F854A06 = true
				Inspect.Ability.List().a0000000006BDD965 = true
				Inspect.Ability.List().a000000002B3964A9 = true
				...

		Inspect.Ability.Detail('a000000000D674EA0')
			will display: 
				Inspect.Ability.Detail('a000000000D674EA0').costPower = 10
				Inspect.Ability.Detail('a000000000D674EA0').cooldown = 10.000000474975
				Inspect.Ability.Detail('a000000000D674EA0').icon = Data/\UI\ability_icons\void_knight-void_a.dds
				Inspect.Ability.Detail('a000000000D674EA0').name = Void
		
	Next Version:
		The next version will include the facility to monitor the values on one or more 
		variables/tables. As these variables/tables update, a new 'monitor' window
		will display the current values.

		NerfedWar
		http://www.nerfedwar.net
		nerfed.war@gmail.com 
	    
	]])
	
	-- create the icon
	helpIcon:SetWidth(64)
	helpIcon:SetHeight(64)
	helpIcon:SetPoint("BOTTOMLEFT", helpWindow, "BOTTOMLEFT", 12, -13)
	helpIcon:SetTexture("Inspector", "small_fangs.png")
	
	-- create the close button and add an event handler to hide the help window when it is presed
	helpCloseButton:SetText("Close")
	helpCloseButton:SetPoint("BOTTOMCENTER", helpWindow, "BOTTOMCENTER", 0, -20)
	function helpCloseButton.Event:LeftPress()
		helpWindow:SetVisible(false)
	end	

end

-- perform the recursive inspection
local temporaryTableDetails = {}
local inspectionNodeCount = 0
local function getTableDetails(obj, objName, targetDepth, previousDepth)
	inspectionNodeCount = inspectionNodeCount + 1
	if inspectionNodeCount > 300 then return "[inspection limited to 300 nodes]\n" end
	local contents = ""
	local currentDepth = previousDepth + 1
	if type(obj) == "table" and (targetDepth == 0 or targetDepth >= currentDepth) then 
		if temporaryTableDetails[tostring(obj)] then
			return "Endless Loop detected on object ["..tostring(objName).."]\n"
		else
			temporaryTableDetails[tostring(obj)] = true
		end
		for k, a in pairs(obj) do
			contents = contents..getTableDetails(a, tostring(objName).."."..tostring(k), targetDepth, currentDepth)
			if #contents > 12000 then
				contents = contents:sub(1, 12000) .. "\n[output truncated]\n"
				break
			end
		end
	else
		contents = tostring(objName).." = "
		if type(obj) == "wstring" then
			contents = contents.."\""..tostring(obj).."\"\n"
		else
			contents = contents..tostring(obj).."\n"
		end
	end
	return contents
end


-- display the inspection window
function Inspector.showInspectionWindow()
	textWindow:SetVisible(true)
end


-- perform the inspection and display the results
function Inspector.doInspection(obj, depth)

	-- check for nil, object concat and blank
	if type(obj) ~= "string" or obj == "" or string.sub(obj, -1) == "." then
		return
	end
	
	-- Accept ordinary Lua expressions including quoted IDs and bracket notation.
	-- The old validator rejected the quoted Detail(...) examples in its own Help.
	if type(obj) ~= "string" or #obj > 400 or obj:find("[\r\n;]") then
		textField:SetText("Enter one Lua expression (up to 400 characters).")
		return
	end
	
	textWindow:SetTitle("Inspector: "..obj)
	
	local loader = type(loadstring) == 'function' and loadstring or load
	if type(loader) ~= 'function' then
		textField:SetText('Lua compiler unavailable in this RIFT environment.')
		return
	end
	local compileOK, compiled, syntaxError = pcall(loader, 'return ' .. obj)
	if not compileOK or not compiled then
		textField:SetText('Syntax error: ' .. tostring(compileOK and syntaxError or compiled))
		return
	end
	local ok, value = pcall(compiled)
	if not ok then
		textField:SetText('Inspection error: ' .. tostring(value))
		return
	end
	local requestedDepth = tonumber(depth) or 1
	requestedDepth = math.max(1, math.min(5, requestedDepth))
	temporaryTableDetails = {}
	inspectionNodeCount = 0
	local cmdOutput = getTableDetails(value, obj, requestedDepth, 0)
	textField:SetText(cmdOutput)
	textWindow:SetVisible(true)

end

-- Register the slash commands
table.insert(Command.Slash.Register("ti"), {Inspector.showInspectionWindow, "Inspector", "Slash command"})


-- initialisation
local ok, err = pcall(init)
if not ok then print('Inspector initialization failed: ' .. tostring(err)) end
local helpOk, helpErr = pcall(initHelp)
if not helpOk then print('Inspector help initialization failed: ' .. tostring(helpErr)) end