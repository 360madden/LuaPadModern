-- LuaPad 2.0 compatibility patch for LibSimpleWidgets.Window.
-- The 2012 fallback created a full-window drag overlay which could intercept editor clicks.
-- Attach dragging only to the native window border. Never create a full-screen hit target.
local function attachDrag(window)
  local ok, border = pcall(window.GetBorder, window)
  if not ok or not border or type(border.EventAttach) ~= "function" then return end
  local input = Event and Event.UI and Event.UI.Input and Event.UI.Input.Mouse
  local left = input and input.Left
  local cursor = input and input.Cursor
  if not left or not left.Down or not left.Up then return end
  local dragging, dx, dy = false, 0, 0
  local function mouse()
    local good, state = pcall(Inspect.Mouse)
    if good and type(state) == "table" and type(state.x) == "number"
      and type(state.y) == "number" then return state end
    return nil
  end
  local function begin()
    local m = mouse()
    if not m then return end
    dx, dy = m.x - window:GetLeft(), m.y - window:GetTop()
    dragging = true
  end
  local function move()
    if not dragging then return end
    local m = mouse()
    if not m or m.Left ~= true then dragging = false; return end
    local x, y = m.x - dx, m.y - dy
    local maxX = math.max(0, UIParent:GetWidth() - window:GetWidth())
    local maxY = math.max(0, UIParent:GetHeight() - 35)
    x, y = math.max(0, math.min(x, maxX)), math.max(0, math.min(y, maxY))
    window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
  end
  border:EventAttach(left.Down, begin, "LuaPad drag begin")
  border:EventAttach(left.Up, function() dragging = false end, "LuaPad drag end")
  if left.Upoutside then
    border:EventAttach(left.Upoutside, function() dragging = false end, "LuaPad drag cancel")
  end
  local globalMove = Event.Mouse and Event.Mouse.Move
  local attach = Command and Command.Event and Command.Event.Attach
  local attached = false
  if globalMove and type(attach) == "function" then
    local success, result = pcall(attach, globalMove, move, "LuaPad global drag")
    attached = success and result ~= false
  end
  if not attached and cursor and cursor.Move then
    border:EventAttach(cursor.Move, move, "LuaPad border drag")
  end
end

function Library.LibSimpleWidgets.Window(name, parent)
  local window = UI.CreateFrame("RiftWindow", name, parent)
  local ok, reason = pcall(attachDrag, window)
  if not ok and type(print) == "function" then
    print("LuaPad window drag disabled: " .. tostring(reason))
  end
  return window
end
