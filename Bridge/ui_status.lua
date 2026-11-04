-- LuaPadModern read-only UI observation. Standalone Lua 5.1; not yet loaded by RIFT.
-- This module never calls SetLayer, SetStrata, SetVisible or SetKeyFocus.
local UiStatus = {}

local function read(obj, method, wanted)
  local ok, value = pcall(function()
    if obj == nil then return nil end
    local fn = obj[method]
    if type(fn) ~= "function" then return nil end
    return fn(obj)
  end)
  if not ok or type(value) ~= wanted then return nil, false end
  if wanted == "number" and (value ~= value or value == math.huge or value == -math.huge) then
    return nil, false
  end
  return value, true
end

-- State is a JSON-shaped object with explicit availability, not inferred readiness.
-- The host must independently check the RIFT HWND foreground and physical occlusion.
function UiStatus.capture(context, window, editor)
  local result = {
    canVerifyOcclusion = false,
    availability = {}
  }
  local function field(key, obj, getter, kind)
    local value, available = read(obj, getter, kind)
    result.availability[key] = available
    if available then result[key] = value end
  end
  field("contextLayer", context, "GetLayer", "number")
  field("contextStrata", context, "GetStrata", "string")
  field("windowLayer", window, "GetLayer", "number")
  field("windowStrata", window, "GetStrata", "string")
  field("windowVisible", window, "GetVisible", "boolean")
  field("editorKeyFocus", editor, "GetKeyFocus", "boolean")

  local x, hasX = read(window, "GetLeft", "number")
  local y, hasY = read(window, "GetTop", "number")
  local w, hasW = read(window, "GetWidth", "number")
  local h, hasH = read(window, "GetHeight", "number")
  local boundsAvailable = hasX and hasY and hasW and hasH and w >= 0 and h >= 0
  result.availability.windowBounds = boundsAvailable
  if boundsAvailable then
    result.windowBounds = {left = x, top = y, width = w, height = h}
  end
  return result
end

return UiStatus
