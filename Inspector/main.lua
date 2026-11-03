--[[
	Project: Inspector
	Version: see RiftAddon.toc
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
local textWindow = Library.LibSimpleWidgets.Window("InspectorTextWindow", context)
local helpWindow = Library.LibSimpleWidgets.Window("InspectorHelpWindow", context)

local reportButtonError = nil

-- Match LuaPad's controls: one pointer host, a two-tone border, hover and press feedback.
local function inspectorButton(name, parent)
  local host = UI.CreateFrame("Frame", name, parent)
  host:SetWidth(100); host:SetHeight(28); host:SetMouseMasking("full")
  local fill = UI.CreateFrame("Frame", name .. "Fill", host)
  fill:SetLayer(0)
  fill:SetPoint("TOPLEFT", host, "TOPLEFT", 1, 1)
  fill:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -1, -1)
  fill:SetMouseMasking("limited")
  local caption = UI.CreateFrame("Text", name .. "Caption", host)
  caption:SetLayer(3); caption:SetPoint("CENTER", host, "CENTER", 0, 0)
  caption:SetFontSize(13); caption:SetWordwrap(false)
  caption:SetFontColor(0.94, 0.96, 0.98, 1); caption:SetMouseMasking("limited")
  local border = {}
  for i = 1, 4 do
    border[i] = UI.CreateFrame("Frame", name .. "Edge" .. i, host)
    border[i]:SetLayer(1); border[i]:SetMouseMasking("limited")
  end
  border[1]:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
  border[1]:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0); border[1]:SetHeight(1)
  border[2]:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, 0)
  border[2]:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0); border[2]:SetHeight(1)
  border[3]:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 1)
  border[3]:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, -1); border[3]:SetWidth(1)
  border[4]:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 1)
  border[4]:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, -1); border[4]:SetWidth(1)
  local hovered, pressed = false, false
  local function repaint()
    if pressed then fill:SetBackgroundColor(0.045, 0.09, 0.126, 1)
    elseif hovered then fill:SetBackgroundColor(0.145, 0.28, 0.33, 0.99)
    else fill:SetBackgroundColor(0.102, 0.19, 0.239, 0.98) end
    local light, dark = pressed and 0.04 or 0.64, pressed and 0.64 or 0.04
    border[1]:SetBackgroundColor(light, light, light, 1)
    border[3]:SetBackgroundColor(light, light, light, 1)
    border[2]:SetBackgroundColor(dark, dark, dark, 1)
    border[4]:SetBackgroundColor(dark, dark, dark, 1)
    caption:SetFontColor(hovered and 0.45 or 0.94, hovered and 0.91 or 0.96, hovered and 1 or 0.98, 1)
    caption:SetPoint("CENTER", host, "CENTER", pressed and 1 or 0, pressed and 1 or 0)
  end
  local mouse = Event.UI.Input.Mouse
  local function attach(event, cb, suffix)
    if event then host:EventAttach(event, cb, name .. suffix) end
  end
  local result = { Event = {} }
  attach(mouse.Cursor and mouse.Cursor.In, function() hovered = true; repaint() end, " hover")
  attach(mouse.Cursor and mouse.Cursor.Out, function() hovered = false; pressed = false; repaint() end, " leave")
  attach(mouse.Left and mouse.Left.Down, function() pressed = true; repaint() end, " down")
  attach(mouse.Left and mouse.Left.Up, function() pressed = false; repaint() end, " up")
  attach(mouse.Left and mouse.Left.Upoutside, function() pressed = false; repaint() end, " cancel")
  attach(mouse.Left and mouse.Left.Click, function()
    if result.Event.LeftPress then
      local ok, err = pcall(result.Event.LeftPress, result.Event)
      if not ok then
        local message = "Inspector button " .. name .. ": " .. tostring(err)
        print(message)
        -- Let users copy UI failures, not only inspect-expression failures.
        if reportButtonError then pcall(reportButtonError, message) end
      end
    end
  end, " click")
  function result:SetText(value) caption:SetText(tostring(value or "")) end
  function result:SetPoint(...) host:SetPoint(...) end
  function result:SetWidth(value) host:SetWidth(value) end
  function result:SetLayer(value) host:SetLayer(value) end
  repaint()
  return result
end

local outputHeading = UI.CreateFrame("Text", "InspectorOutputHeading", textWindow)
local outputScroll = Library.LibSimpleWidgets.ScrollView("InspectorOutputScroll", textWindow:GetContent())
local outputText = UI.CreateFrame("Text", "InspectorOutputText", outputScroll)
local inputLabel = UI.CreateFrame("Text", "InspectorInputLabel", textWindow)
local inputField = UI.CreateFrame("RiftTextfield", "InspectorInputField", textWindow)
local depthLabel = UI.CreateFrame("Text", "InspectorDepthLabel", textWindow)
local depthText = UI.CreateFrame("Text", "InspectorDepthField", textWindow)
local depthSlider = UI.CreateFrame("RiftSlider", "InspectorSlider", textWindow)
local copyButton = inspectorButton("InspectorCopyButton", textWindow)
local inspectButton = inspectorButton("InspectorInspectButton", textWindow)
local helpButton = inspectorButton("InspectorHelpButton", textWindow)
local closeButton = inspectorButton("InspectorCloseButton", textWindow)
local helpText = UI.CreateFrame("Text", "InspectorHelpText", helpWindow)
local helpCloseButton = inspectorButton("InspectorHelpCloseButton", helpWindow)

local lastOutput = ""
local function currentVersion()
  local detailFn = Inspect and Inspect.Addon and Inspect.Addon.Detail
  if type(detailFn) == "function" then
    local ok, detail = pcall(detailFn, "Inspector")
    if ok and type(detail) == "table" and type(detail.toc) == "table" then
      local version = detail.toc.Version or detail.toc.version
      if version ~= nil and tostring(version) ~= "" then return tostring(version) end
    end
  end
  return "unknown"
end

-- Text is read-only; the scroll view allows inspection without changing the output.
-- Keep the entire bounded result for Copy Output, independent of visible scroll offset.
local function displayOutput(message)
  lastOutput = tostring(message or "")
  outputText:SetText(lastOutput)
  local wrappedLines = 0
  for line in (lastOutput .. "\n"):gmatch("(.-)\n") do
    wrappedLines = wrappedLines + math.max(1, math.ceil(#line / 105))
  end
  outputText:SetHeight(math.max(346, wrappedLines * 17 + 8))
  outputScroll.offset = 0
  outputScroll:ContentResized()
  textWindow:SetVisible(true)
end

reportButtonError = function(message) displayOutput(message) end

local function paintSection(label)
  label:SetFontSize(12)
  label:SetFontColor(0.73, 0.88, 0.92, 1)
  label:SetWordwrap(false)
end

local function init()
  textWindow:SetVisible(false)
  textWindow:SetWidth(800); textWindow:SetHeight(600)
  textWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  textWindow:SetLayer(1)
  textWindow:SetTitle("Inspector v" .. currentVersion())

  paintSection(outputHeading)
  outputHeading:SetText("Inspection Results")
  outputHeading:SetPoint("TOPLEFT", textWindow, "TOPLEFT", 24, 58)

  outputScroll:SetWidth(750); outputScroll:SetHeight(346)
  outputScroll:SetBorder(1, 1, 1, 1, 0.2)
  outputScroll:SetBackgroundColor(0, 0, 0, 0.45)
  outputScroll:SetPoint("TOPLEFT", textWindow, "TOPLEFT", 24, 85)
  outputText:SetFontSize(12)
  outputText:SetFontColor(0.92, 0.95, 0.96, 1)
  outputText:SetWordwrap(true)
  outputText:SetHeight(346)
  outputText:SetText("")
  outputScroll:SetContent(outputText)

  copyButton:SetText("Copy Output"); copyButton:SetWidth(120)
  copyButton:SetPoint("TOPRIGHT", textWindow, "TOPRIGHT", -26, 49)
  function copyButton.Event:LeftPress()
    if lastOutput == "" then print("Inspector: Nothing to copy."); return end
    if not Command or type(Command.CopyToClipboard) ~= "function" then
      print("Inspector: Clipboard API unavailable."); return
    end
    local ok, result = pcall(Command.CopyToClipboard, lastOutput)
    if ok and result ~= false then
      print("Inspector: Copied " .. #lastOutput .. " bytes to clipboard.")
    else
      print("Inspector: Copy failed: " .. tostring(result))
    end
  end

  paintSection(inputLabel)
  inputLabel:SetWidth(110); inputLabel:SetHeight(24)
  inputLabel:SetPoint("TOPLEFT", textWindow, "TOPLEFT", 24, 451)
  inputLabel:SetText("Expression:")
  inputField:SetWidth(633); inputField:SetHeight(24)
  inputField:SetPoint("TOPLEFT", textWindow, "TOPLEFT", 141, 448)
  inputField:SetBackgroundColor(0, 0, 0, 0.8)
  inputField:SetText("")

  paintSection(depthLabel)
  depthLabel:SetWidth(55); depthLabel:SetHeight(24)
  depthLabel:SetPoint("TOPLEFT", textWindow, "TOPLEFT", 24, 491)
  depthLabel:SetText("Depth:")
  depthText:SetWidth(30); depthText:SetHeight(24)
  depthText:SetPoint("TOPLEFT", textWindow, "TOPLEFT", 83, 491)
  depthText:SetText("1")
  depthSlider:SetWidth(648)
  depthSlider:SetPoint("TOPLEFT", textWindow, "TOPLEFT", 126, 498)
  depthSlider:SetRange(1, 5)
  depthSlider:SetEnabled(true)
  depthSlider:EventAttach(Event.UI.Slider.Change, function()
    local value = tonumber(depthSlider:GetPosition()) or 1
    depthText:SetText(tostring(math.max(1, math.min(5, math.floor(value + 0.5)))))
  end, "Inspector depth changed")
  depthSlider:SetPosition(1)

  local actions = {
    { inspectButton, "Inspect", 110 },
    { helpButton, "Help", 100 },
    { closeButton, "Close", 100 },
  }
  local x = 239
  for _, item in ipairs(actions) do
    item[1]:SetText(item[2]); item[1]:SetWidth(item[3])
    item[1]:SetPoint("TOPLEFT", textWindow, "TOPLEFT", x, 544)
    x = x + item[3] + 12
  end
  function inspectButton.Event:LeftPress()
    -- Read the actual slider number. RIFT Text:GetText() returns (text, htmlFlag):
    -- passing both results to tonumber() makes the boolean an invalid base.
    Inspector.doInspection(inputField:GetText(), depthSlider:GetPosition())
  end
  function helpButton.Event:LeftPress() helpWindow:SetVisible(true) end
  function closeButton.Event:LeftPress()
    inputField:SetKeyFocus(false)
    textWindow:SetVisible(false)
  end
end

local function initHelp()
  helpWindow:SetVisible(false)
  helpWindow:SetWidth(650); helpWindow:SetHeight(430); helpWindow:SetLayer(2)
  helpWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  helpWindow:SetTitle("Inspector Help v" .. currentVersion())
  helpText:SetPoint("TOPLEFT", helpWindow, "TOPLEFT", 24, 62)
  helpText:SetWidth(602); helpText:SetHeight(290)
  helpText:SetFontSize(14); helpText:SetWordwrap(true)
  helpText:SetFontColor(0.92, 0.95, 0.96, 1)
  helpText:SetText([[Enter a Lua expression, choose depth 1 to 5, and press Inspect.

Examples:
  Inspect.Ability.List
  Inspect.Ability.List()
  Inspect.Unit.Detail("player")
  Inspector

Depth 1 shows a table's immediate fields; higher depths expand nested tables. Results stop after 300 entries or 12,000 characters. A table that refers to itself displays [cycle]. Shared tables are not mistaken for cycles.

The expression executes in RIFT's Lua environment. Use calls only when you want their effects. Output includes compile/runtime errors and can be copied using Copy Output. Open with /ti or LuaPad's Inspect button.]])
  helpCloseButton:SetText("Close")
  helpCloseButton:SetWidth(110)
  helpCloseButton:SetPoint("TOPLEFT", helpWindow, "TOPLEFT", 270, 371)
  function helpCloseButton.Event:LeftPress() helpWindow:SetVisible(false) end
end

local MAX_NODES, MAX_CHARS = 300, 12000
local function formatValue(root, rootName, depth)
  local parts, characters, nodes, truncated = {}, 0, 0, false
  local visiting = {}
  local function append(s)
    if truncated then return end
    local left = MAX_CHARS - characters
    if #s > left then
      if left > 0 then parts[#parts + 1] = s:sub(1, left) end
      parts[#parts + 1] = "\n[output truncated at 12000 characters]\n"
      truncated = true
      return
    end
    parts[#parts + 1] = s; characters = characters + #s
  end
  local function walk(value, name, level)
    if truncated then return end
    nodes = nodes + 1
    if nodes > MAX_NODES then
      append("[inspection limited to 300 nodes]\n")
      truncated = true
      return
    end
    if type(value) == "table" and level < depth then
      if visiting[value] then
        append(name .. " = [cycle]\n")
        return
      end
      visiting[value] = true
      local keys = {}
      local keysLimited = false
      for key in pairs(value) do
        if #keys >= MAX_NODES then keysLimited = true; break end
        keys[#keys + 1] = key
      end
      table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then return ta < tb end
        return tostring(a) < tostring(b)
      end)
      if #keys == 0 then append(name .. " = {}\n") end
      for _, key in ipairs(keys) do
        walk(value[key], name .. "[" .. tostring(key) .. "]", level + 1)
        if truncated then break end
      end
      if keysLimited and not truncated then append("[table keys limited to 300]\n") end
      visiting[value] = nil
    else
      local rendered = tostring(value)
      if type(value) == "wstring" then rendered = '"' .. rendered .. '"' end
      append(name .. " = " .. rendered .. "\n")
    end
  end
  walk(root, rootName, 0)
  return table.concat(parts)
end

function Inspector.showInspectionWindow()
  textWindow:SetTitle("Inspector v" .. currentVersion())
  textWindow:SetVisible(true)
end

function Inspector.doInspection(expression, depth)
  if type(expression) ~= "string" or expression:match("^%s*$") then
    displayOutput("Enter a Lua expression to inspect.")
    return
  end
  if #expression > 400 or expression:find("[\r\n;]") or expression:match("%.%s*$") then
    displayOutput("Enter one complete Lua expression (max 400 characters, no semicolons).")
    return
  end
  local loader = type(loadstring) == "function" and loadstring or load
  if type(loader) ~= "function" then
    displayOutput("Lua compiler unavailable in this RIFT environment.")
    return
  end
  local compileOK, compiled, syntaxError = pcall(loader, "return " .. expression)
  if not compileOK or not compiled then
    displayOutput("Syntax error: " .. tostring(compileOK and syntaxError or compiled))
    return
  end
  local ok, value = pcall(compiled)
  if not ok then
    displayOutput("Inspection error: " .. tostring(value))
    return
  end
  local requestedDepth = tonumber(depth) or 1
  requestedDepth = math.max(1, math.min(5, math.floor(requestedDepth + 0.5)))
  local formatOK, result = pcall(formatValue, value, expression, requestedDepth)
  if not formatOK then
    displayOutput("Table traversal error: " .. tostring(result))
  else
    displayOutput(result)
  end
end

table.insert(Command.Slash.Register("ti"), { Inspector.showInspectionWindow, "Inspector", "Slash command" })

local ok, err = pcall(init)
if not ok then print("Inspector initialization failed: " .. tostring(err)) end
local helpOk, helpErr = pcall(initHelp)
if not helpOk then print("Inspector help initialization failed: " .. tostring(helpErr)) end
if ok and helpOk then
  print("[Inspector v" .. currentVersion() .. "] READY - type /ti to open")
end
