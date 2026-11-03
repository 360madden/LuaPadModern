-- Runtime regression harness for Inspector. Simulates documented RIFT widget getters,
-- including Text:GetText() returning (string, boolean) and slider position as number.
-- Run: npm exec --yes --package=fengari-node-cli -- fengari inspector-runtime-tests.lua
local originalPrint = print
local messages, frames, clipboard, passed = {}, {}, nil, 0
print = function(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
  messages[#messages + 1] = table.concat(parts, " ")
end
local function check(name, condition, detail)
  if not condition then
    originalPrint("FAIL " .. name .. (detail and " " .. tostring(detail) or ""))
    error("test failed: " .. name)
  end
  passed = passed + 1
  originalPrint("PASS " .. name)
end
local function frame(kind, name, parent)
  local obj = { _kind = kind, _name = name, _text = "", _visible = true, _events = {}, _parent = parent }
  frames[name] = obj
  function obj:GetName() return self._name end
  function obj:GetParent() return self._parent end
  function obj:SetParent(value) self._parent = value end
  function obj:SetWidth(value) self._width = value end
  function obj:SetHeight(value)
    local previous = self._height
    self._height = value
    if previous ~= value and self._events["layout-size"] then self._events["layout-size"]() end
  end
  function obj:GetHeight() return self._height or 0 end
  function obj:GetWidth() return self._width or 0 end
  function obj:GetTop() return self._top or 0 end
  function obj:GetBackgroundColor() return table.unpack(self._bg or {0,0,0,0}) end
  function obj:SetLayer(value) self._layer = value end
  function obj:SetAlpha(value) self._alpha = value end
  function obj:GetCursor() return self._cursor or #self._text end
  function obj:SetCursor(value) self._cursor = value end
  function obj:SetPoint(...) self._point = { ... } end
  function obj:SetAllPoints(other) self._allPoints = other end
  function obj:SetMouseMasking(value) self._mask = value end
  function obj:SetFontSize(value) self._fontSize = value end
  function obj:SetFontColor(...) self._fontColor = { ... } end
  function obj:SetBackgroundColor(...) self._bg = { ... } end
  function obj:SetWordwrap(value) self._wordwrap = value end
  function obj:SetVisible(value) self._visible = value end
  function obj:GetVisible() return self._visible end
  function obj:SetText(value) self._text = value end
  function obj:GetText()
    if self._kind == "Text" then return self._text, false end
    return self._text
  end
  function obj:SetKeyFocus(value) self._keyfocus = value end
  function obj:SetTitle(value) self._title = value end
  function obj:SetTexture(...) self._texture = { ... } end
  function obj:GetContent() return self end
  function obj:SetBorder(...) self._border = { ... } end
  function obj:SetContent(content) self._content = content end
  function obj:ContentResized() self._contentResizeCount = (self._contentResizeCount or 0) + 1 end
  function obj:SetRange(low, high) self._low, self._high = low, high end
  function obj:SetEnabled(value) self._enabled = value end
  function obj:GetPosition() return self._position end
  function obj:SetPosition(value)
    self._position = value
    if self._events["slider-change"] then self._events["slider-change"]() end
  end
  function obj:EventAttach(event, callback) self._events[event] = callback end
  function obj:Fire(event)
    local cb = assert(self._events[event], self._name .. " missing event " .. event)
    cb()
  end
  return obj
end
UIParent = frame("Frame", "UIParent")
UI = {
  CreateContext = function(name) return frame("Context", name, UIParent) end,
  CreateFrame = function(kind, name, parent) return frame(kind, name, parent) end,
}
Event = { UI = {
  Input = { Mouse = {
    Cursor = { In = "cursor-in", Out = "cursor-out", Move = "cursor-move" },
    Left = { Down = "left-down", Up = "left-up", Upoutside = "left-upoutside", Click = "left-click" },
    Wheel = { Forward = "wheel-forward", Back = "wheel-back" },
  }},
  Slider = { Change = "slider-change" },
  Layout = { Size = "layout-size" },
  Textfield = { Change = "textfield-change" },
}, Addon = { SavedVariables = { Save = { Begin = {} }, Load = { End = {} } } } }
Event.UI.Input.Key = { Down = "key-down" }
Library = { LibSimpleWidgets = {
  Window = function(name, parent) return frame("Window", name, parent) end,
  SetBorder = function(view, ...) view._border = { ... } end,
}}
Inspect = { Addon = { Detail = function(name)
  return { toc = { Version = name == "Inspector" and "1.9.0-preview2" or name == "LuaPad" and "2.0.0-preview8" or "?" } }
end }}
local registered = {}
Command = {
  Slash = { Register = function(name)
    registered[name] = {}
    return registered[name]
  end },
  CopyToClipboard = function(value) clipboard = value; return true end,
}
assert(loadfile("LibSimpleWidgets/scrollview.lua"))()
assert(loadfile("Inspector/main.lua"))()

local output = frames.InspectorOutputText
local input = frames.InspectorInputField
local depth = frames.InspectorDepthField
local slider = frames.InspectorSlider
local inspect = frames.InspectorInspectButton
local copy = frames.InspectorCopyButton
local window = frames.InspectorTextWindow
check("startup message", table.concat(messages, "\n"):find("Inspector v1.9.0%-preview2") ~= nil)
check("version from TOC", window._title == "Inspector v1.9.0-preview2")
check("slash /ti", registered.ti and #registered.ti == 1)
check("scroll view content", frames.InspectorOutputScroll.content == output)
check("results read-only Text", output._kind == "Text")
check("aligned copy control", copy._width == 120)
check("empty initial output", output._text == "")
local scroll = frames.InspectorOutputScroll
check("no scrollbar when content fits exactly", not scroll.scrollbar:GetVisible())
check("zero max offset when content fits", scroll:GetMaxOffset() == 0)
messages = {}
copy:Fire("left-click")
check("empty clipboard warning", table.concat(messages, "\n"):find("Nothing to copy") ~= nil)
check("no copy on empty", clipboard == nil)



messages = {}
input:SetText("Inspect")
slider:SetPosition(3)
check("slider shows integer depth", (depth:GetText()) == "3")
inspect:Fire("left-click")
check("Inspect button no runtime error", #messages == 0, table.concat(messages, "\n"))
check("Inspect expression rendered", output._text:find("Inspect%[Addon%]") ~= nil, output._text)
copy:Fire("left-click")
check("clipboard preserves result", clipboard == output._text and #clipboard > 0)
check("clipboard confirms action", table.concat(messages, "\n"):find("Copied") ~= nil)

messages = {}
input:SetText("this is invalid lua !")
inspect:Fire("left-click")
check("compile errors visible", output._text:find("Syntax error:") ~= nil)
check("compile errors copy", (function() copy:Fire("left-click"); return clipboard == output._text end)())

messages = {}
input:SetText('error("fixture runtime failure")')
inspect:Fire("left-click")
check("runtime errors visible", output._text:find("fixture runtime failure") ~= nil)

local shared = { n = 1 }
InspectorFixture = { first = shared, second = shared }
Inspector.doInspection("InspectorFixture", 3)
check("shared references both visible", output._text:find("%[first%]%[n%] = 1") and output._text:find("%[second%]%[n%] = 1"))
check("shared reference not false cycle", not output._text:find("%[cycle%]"))
InspectorFixture.self = InspectorFixture
Inspector.doInspection("InspectorFixture", 3)
check("real cycle reported", output._text:find("%[cycle%]") ~= nil)
InspectorFixture = {}
for i = 1, 1200 do InspectorFixture[i] = i end
Inspector.doInspection("InspectorFixture", 3)
check("large table bounded", output._text:find("%[inspection limited to 300 nodes%]") ~= nil or output._text:find("%[table keys limited to 300%]") ~= nil)
InspectorFixture = { big = ("X"):rep(14000) }
Inspector.doInspection("InspectorFixture", 3)
check("long output bounded", output._text:find("%[output truncated at 12000 characters%]") ~= nil)
check("overflow makes scrollbar visible", scroll.scrollbar:GetVisible())
check("overflow has positive max offset", scroll:GetMaxOffset() > 0)
scroll:Fire("wheel-back")
check("wheel down advances content", scroll.offset > 0)
scroll:Fire("wheel-forward")
check("wheel up returns content", scroll.offset == 0)
local simulatedMouse = { y = 20, Left = true }
Inspect.Mouse = function() return simulatedMouse end
scroll.scrollbar._top = 0
scroll._top = 0
scroll.scrollbar:Fire("left-down")
simulatedMouse.y = 160
scroll.scrollbar:Fire("cursor-move")
check("scrollbar drag advances content", scroll.offset > 0)
scroll.scrollbar:Fire("left-up")
local stoppedAt = scroll.offset
simulatedMouse.y = 300
scroll.scrollbar:Fire("cursor-move")
check("scrollbar drag stops on mouse-up", scroll.offset == stoppedAt)
Inspect.Mouse = nil


Inspector.doInspection("", 1)
check("blank expression guidance", output._text:find("Enter a Lua expression") ~= nil)
Inspector.doInspection("Inspect.", 1)
check("incomplete expression guidance", output._text:find("one complete Lua expression") ~= nil)
Inspector.doInspection("Inspect; print(1)", 1)
check("semicolon expression refused", output._text:find("one complete Lua expression") ~= nil)
Inspector.doInspection(("x"):rep(401), 1)
check("overlong expression refused", output._text:find("one complete Lua expression") ~= nil)
Inspector.doInspection("1 + 1", 1)
check("numeric scalar expression", output._text:find("1 %+ 1 = 2") ~= nil)
InspectorFixture = { nested = { leaf = "marker" } }
Inspector.doInspection("InspectorFixture", 1)
check("depth 1 does not expand nested", not output._text:find("%[leaf%]"))
Inspector.doInspection("InspectorFixture", 5)
check("depth 5 expands nested", output._text:find("%[nested%]%[leaf%] = marker") ~= nil)
Inspector.doInspection("InspectorFixture", 99)
check("depth clamps above 5", output._text:find("%[nested%]%[leaf%] = marker") ~= nil)
Inspector.doInspection("InspectorFixture", -99)
check("depth clamps below 1", not output._text:find("%[leaf%]"))

messages = {}
local nativeCopy = Command.CopyToClipboard
Command.CopyToClipboard = function() return false end
copy:Fire("left-click")
check("clipboard rejection visible", table.concat(messages, "\n"):find("Copy failed") ~= nil)
Command.CopyToClipboard = nil
messages = {}
copy:Fire("left-click")
check("missing clipboard handled", table.concat(messages, "\n"):find("Clipboard API unavailable") ~= nil)
Command.CopyToClipboard = nativeCopy

InspectorFixture = { score = 10 }
Inspector.doInspection("InspectorFixture", 1)
check("fresh output resets scrolling", frames.InspectorOutputScroll.offset == 0)
check("short result hides scrollbar", not scroll.scrollbar:GetVisible())
scroll:SetShowScrollbar(true)
check("enabling scrollbar respects no-overflow", not scroll.scrollbar:GetVisible())
local savedHeight = output:GetHeight()
output:SetHeight(0)
scroll:ContentResized()
check("zero-height content has zero offset", scroll:GetMaxOffset() == 0)
check("zero-height scrollbar position finite", scroll.scrollbar._point[5] == scroll.scrollbar._point[5])
output:SetHeight(savedHeight)
scroll:ContentResized()
check("result pane stays operable", window:GetVisible() == true)
check("Help text bounded by window", frames.InspectorHelpText._width + frames.InspectorHelpText._point[4] <= frames.InspectorHelpWindow._width and frames.InspectorHelpText._height + frames.InspectorHelpText._point[5] < frames.InspectorHelpWindow._height)
local fill = frames.InspectorInspectButtonFill
local oldColor = fill._bg[1]
inspect:Fire("cursor-in")
check("button hover repaints", fill._bg[1] ~= oldColor)
inspect:Fire("left-down")
check("button depress repaints", fill._bg[1] == 0.045)
inspect:Fire("left-up")
inspect:Fire("cursor-out")
check("button releases correctly", fill._bg[1] == oldColor)

local helpWindow = frames.InspectorHelpWindow
local originalSetVisible = helpWindow.SetVisible
helpWindow.SetVisible = function() error("simulated UI callback failure") end
messages = {}
frames.InspectorHelpButton:Fire("left-click")
check("UI button exception shown in result pane", output._text:find("simulated UI callback failure") ~= nil)
check("UI button exception logged once", #messages == 1)
copy:Fire("left-click")
check("UI button exception copyable", clipboard == output._text)
helpWindow.SetVisible = originalSetVisible

frames.InspectorHelpButton:Fire("left-click")
check("Help opens", frames.InspectorHelpWindow:GetVisible())
frames.InspectorHelpCloseButton:Fire("left-click")
check("Help closes", not frames.InspectorHelpWindow:GetVisible())
frames.InspectorCloseButton:Fire("left-click")
check("Inspector closes", not window:GetVisible())
check("Inspector cases passed", passed >= 55)

-- Load LuaPad with the same real ScrollView to test cross-addon integration.
assert(loadfile("main.lua"))()
local lpOutput = frames.LuaPadOutputField
local lpScroll = frames.LuaPadOutputFieldScroll
check("LuaPad and Inspector initialize together", lpOutput ~= nil and lpScroll.content == lpOutput)
check("LuaPad slash /lp", registered.lp and #registered.lp == 1)
LuaPad.doRun('print(("X"):rep(1500))')
originalPrint("PROBE long output wordwrap=" .. tostring(lpOutput._wordwrap) .. " height=" .. tostring(lpOutput:GetHeight()) .. " maxOffset=" .. tostring(lpScroll:GetMaxOffset()))
check("LuaPad output wraps long lines", lpOutput._wordwrap == true)
check("LuaPad output height accounts for wrapped text", lpOutput:GetHeight() > 150)
check("LuaPad long output scrolls", lpScroll:GetMaxOffset() > 0)
frames.LuaPadCopyOutputButton:Fire("left-click")
check("LuaPad full wrapped output copied", clipboard == lpOutput._text and #clipboard == 1500)
lpScroll.offset = 175
frames.LuaPadHelpButton:Fire("left-click")
check("LuaPad help output visible", lpOutput._text:find("/lp or /luapad") ~= nil)
check("LuaPad Help resets output scroll position", lpScroll.offset == 0)
check("LuaPad Help height grows for multiline text", lpOutput:GetHeight() > 150)
LuaPad.doRun('this is not valid lua !!!')
check("LuaPad compile errors visible", lpOutput._text:find("Syntax error:") ~= nil)
LuaPad.doRun('print("before-error"); error("sample runtime failure")')
check("LuaPad runtime errors visible", lpOutput._text:find("Runtime error:") ~= nil and lpOutput._text:find("sample runtime failure") ~= nil)
check("LuaPad pre-error print preserved", lpOutput._text:find("before%-error") ~= nil)
LuaPad.doRun('print("short")')
check("LuaPad short output resets height", lpOutput:GetHeight() == 150)
check("LuaPad short output hides scrollbar", not lpScroll.scrollbar:GetVisible())
check("LuaPad short output resets offset", lpScroll.offset == 0)
LuaPad.doRun("")
check("LuaPad empty-code guidance", lpOutput._text:find("Please enter some Lua code") ~= nil)

-- Snippet cards should keep a consistent selected state through Save, Load and Clear.
local slot1 = frames.LuaPadSnippetButton1
local editor = frames.LuaPadInputField
slot1:Fire("left-click")
local selectedStyle = { table.unpack(slot1._bg) }
check("snippet slot visually selected", selectedStyle[4] == 1)
editor:SetText('print("fixture slot")')
frames.LuaPadSaveButton:Fire("left-click")
check("snippet Save stores editor contents", LuaPad_Snippets[1] == 'print("fixture slot")')
editor:SetText("temporary replacement")
frames.LuaPadLoadButton:Fire("left-click")
check("snippet Load restores exact code", editor._text == 'print("fixture slot")')
local loadedStyle = slot1._bg
check("snippet selected color consistent after Load", loadedStyle[1] == selectedStyle[1] and loadedStyle[2] == selectedStyle[2] and loadedStyle[3] == selectedStyle[3] and loadedStyle[4] == selectedStyle[4])
frames.LuaPadClearButton:Fire("left-click")
check("snippet Clear removes saved code", LuaPad_Snippets[1] == "")
check("snippet selected slot remains readable", slot1._text:find("Slot 1") ~= nil)
check("snippet captions more readable", slot1._fontSize == 10)
slot1:Fire("cursor-in")
check("snippet hover has visual feedback", slot1._bg[1] == 0.145)
slot1:Fire("left-down")
check("snippet press has recessed visual state", slot1._bg[1] == 0.045)
slot1:Fire("left-up")
slot1:Fire("cursor-out")
check("snippet selected visual state restored", slot1._bg[1] == selectedStyle[1] and slot1._bg[4] == selectedStyle[4])
local slot2 = frames.LuaPadSnippetButton2
slot2:Fire("left-click")
check("selecting another snippet clears previous highlight", slot1._bg[1] == 0.084)
check("new snippet is visibly selected", slot2._bg[1] == selectedStyle[1])
slot2:Fire("left-down")
slot2:Fire("left-upoutside")
check("snippet release outside clears pressed state", slot2._bg[1] == selectedStyle[1])
LuaPad_Snippets[1] = ("LONG"):rep(12)
fillSnippetButtons()
check("long snippet previews stay within card width", #slot1._text <= 20)
check("all cases passed", passed >= 80)
originalPrint(string.format("LuaPad plus Inspector runtime mock: %d assertions passed", passed))
