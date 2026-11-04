-- Headless UI focus/layer observation tests. No RIFT game required.
local Status = assert(loadfile("Bridge/ui_status.lua"))()
local Codec = assert(loadfile("Bridge/codec.lua"))()
local passed = 0
local function check(label, ok)
  if not ok then error("FAIL " .. label, 0) end
  passed = passed + 1
  print("PASS " .. label)
end
local function eq(label, actual, expected)
  check(label, actual == expected)
end

local changed = 0
local function rejectMutation() changed = changed + 1; error("unexpected setter") end
local context = {_layer=1,_strata="hud"}
function context:GetLayer() return self._layer end
function context:GetStrata() return self._strata end
context.SetLayer = rejectMutation
context.SetStrata = rejectMutation
local window = {_visible=false,_layer=1,_strata="hud",_left=100,_top=120,_width=840,_height=600}
function window:GetVisible() return self._visible end
function window:GetLayer() return self._layer end
function window:GetStrata() return self._strata end
function window:GetLeft() return self._left end
function window:GetTop() return self._top end
function window:GetWidth() return self._width end
function window:GetHeight() return self._height end
window.SetVisible = rejectMutation
window.SetLayer = rejectMutation
window.SetStrata = rejectMutation
local editor = {_focus=false}
function editor:GetKeyFocus() return self._focus end
editor.SetKeyFocus = rejectMutation

local s = Status.capture(context,window,editor)
eq("hidden window false is known",s.windowVisible,false)
eq("visible availability is true",s.availability.windowVisible,true)
eq("editor unfocused false is known",s.editorKeyFocus,false)
eq("focus availability is true",s.availability.editorKeyFocus,true)
eq("context layer available",s.contextLayer,1)
eq("context strata available",s.contextStrata,"hud")
eq("window layer available",s.windowLayer,1)
eq("window strata available",s.windowStrata,"hud")
eq("bounds left",s.windowBounds.left,100)
eq("bounds top",s.windowBounds.top,120)
eq("bounds width",s.windowBounds.width,840)
eq("bounds height",s.windowBounds.height,600)
eq("bounds available",s.availability.windowBounds,true)
eq("never claim occlusion verification",s.canVerifyOcclusion,false)
eq("no mutations from status query",changed,0)

window._visible = true
window._layer = 42
context._layer = 99
window._left = 250
window._width = 720
editor._focus = true
local after = Status.capture(context,window,editor)
eq("new visible state",after.windowVisible,true)
eq("new window layer",after.windowLayer,42)
eq("new context layer",after.contextLayer,99)
eq("new position",after.windowBounds.left,250)
eq("new width after resize",after.windowBounds.width,720)
eq("editor focus true",after.editorKeyFocus,true)
eq("focus cannot prove occlusion",after.canVerifyOcclusion,false)
eq("still no mutations",changed,0)

local missing = Status.capture(nil,nil,nil)
eq("missing visible unavailable",missing.availability.windowVisible,false)
eq("missing visible omitted",missing.windowVisible,nil)
eq("missing focus unavailable",missing.availability.editorKeyFocus,false)
eq("missing focus omitted",missing.editorKeyFocus,nil)
eq("missing context layer unavailable",missing.availability.contextLayer,false)
eq("missing window bounds unavailable",missing.availability.windowBounds,false)
eq("missing bounds omitted",missing.windowBounds,nil)
eq("missing occlusion remains unverified",missing.canVerifyOcclusion,false)

local broken = {
  GetLayer = function() error("getter failed") end,
  GetStrata = function() return 7 end,
  GetVisible = function() error("getter failed") end,
  GetLeft = function() return math.huge end,
  GetTop = function() return 0 end,
  GetWidth = function() return -10 end,
  GetHeight = function() return 20 end
}
local bad = Status.capture(broken,broken,broken)
eq("throwing context layer unavailable",bad.availability.contextLayer,false)
eq("wrong-type context strata unavailable",bad.availability.contextStrata,false)
eq("throwing visible unavailable",bad.availability.windowVisible,false)
eq("invalid bound unavailable",bad.availability.windowBounds,false)
eq("editor without getter unavailable",bad.availability.editorKeyFocus,false)
check("no invalid bounds in result",bad.windowBounds == nil)

local cleanJSON, cleanError = Codec.encode(after)
check("snapshot is bounded JSON-shaped",cleanJSON ~= nil and cleanError == nil)
check("snapshot reports false occlusion in JSON",cleanJSON:find('"canVerifyOcclusion":false',1,true) ~= nil)
check("snapshot reports observed focus in JSON",cleanJSON:find('"editorKeyFocus":true',1,true) ~= nil)
print("Read-only UI focus/layer checks: " .. passed .. " passed")
