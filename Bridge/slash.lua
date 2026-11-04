-- LuaPadModern slash-command transport pilot (Lua 5.1, source-only).
-- Example intended in-game command:
-- /lpb v1 health req-20261104-0001 winhost-session-20261104
-- Does not register /lpb, inspect the game, or change UI focus by itself.
local Slash = {}
local verbs = {
  health = "health",
  caps = "bridge.capabilities",
  status = "ui.status"
}

local function validToken(value, minLength, maxLength)
  return type(value) == "string" and #value >= minLength
    and #value <= maxLength and value:match("^[A-Za-z0-9._%-]+$") ~= nil
end

-- Returns a Lua bridge request envelope or nil plus an error code.
-- Chat transport deliberately has no arbitrary code or JSON payload entry.
function Slash.parse(args)
  if type(args) ~= "string" or #args > 256
    or args:find("[\r\n%z]") then return nil, "INVALID_COMMAND_TEXT" end
  local parts = {}
  for part in args:gmatch("%S+") do
    parts[#parts + 1] = part
    if #parts > 4 then return nil, "INVALID_COMMAND_TEXT" end
  end
  if #parts ~= 4 or parts[1] ~= "v1" then
    return nil, "INVALID_COMMAND_TEXT"
  end
  local operation = verbs[parts[2]]
  if not operation then return nil, "UNSUPPORTED_OPERATION" end
  local requestId, sessionId = parts[3], parts[4]
  if not validToken(requestId, 8, 80) or not requestId:match("^[A-Za-z0-9]")
    or not validToken(sessionId, 8, 96) then
    return nil, "INVALID_IDENTITY"
  end
  return {
    protocol = "luapad-bridge", version = 1, kind = "request",
    requestId = requestId, sessionId = sessionId,
    operation = operation, source = {component = "host"}, payload = {}
  }, nil
end

-- Adapter depends on an injected clipboard function; RIFT's actual copy
-- permission and the slash event's callback argument shape need live proof.
function Slash.new(router, copy, notify)
  if type(router) ~= "table" or type(router.dispatch) ~= "function"
    or type(copy) ~= "function"
    or (notify ~= nil and type(notify) ~= "function") then
    return nil, "INVALID_ADAPTER_DEPENDENCIES"
  end
  local adapter = {}
  local function notice(message)
    if notify then pcall(notify, message) end
  end
  function adapter:handle(args)
    local req, parseError = Slash.parse(args)
    if not req then
      notice("LuaPad bridge: " .. parseError ..
        ". Usage: /lpb v1 health|caps|status REQUEST_ID SESSION_ID")
      return nil, parseError
    end
    local dispatched, json, result = pcall(router.dispatch, router, req)
    if not dispatched or type(json) ~= "string" or #json == 0
      or #json > 16384 or type(result) ~= "table"
      or result.requestId ~= req.requestId
      or result.sessionId ~= req.sessionId
      or result.operation ~= req.operation
      or result.kind ~= "result"
      or (result.status ~= "ok" and result.status ~= "partial"
        and result.status ~= "error") then
      notice("LuaPad bridge: router result invalid; no clipboard data written.")
      return nil, "ROUTER_FAILED"
    end
    local ok, copied = pcall(copy, json)
    if not ok or copied == false then
      notice("LuaPad bridge: clipboard copy failed for " .. req.requestId)
      return nil, "CLIPBOARD_FAILED"
    end
    -- This records only the addon command's copy API outcome.
    -- The Windows host must still verify the actual clipboard bytes and IDs.
    local receipt = {
      requestId = req.requestId, sessionId = req.sessionId,
      operation = req.operation, status = result.status,
      bytes = #json, copyApiInvoked = true
    }
    notice("LuaPad bridge: " .. req.requestId .. " " .. result.status ..
      " (copy requested, " .. #json .. " bytes)")
    return receipt, nil
  end
  -- The expected argument shape is a single trailing argument string. Never
  -- reinterpret unknown event-table/three-argument shapes as command input.
  function adapter.callback(args, ...)
    if select("#", ...) ~= 0 or type(args) ~= "string" then
      notice("LuaPad bridge: unexpected slash callback argument shape.")
      return nil, "CALLBACK_SHAPE_UNVERIFIED"
    end
    return adapter:handle(args)
  end
  return adapter
end

return Slash
