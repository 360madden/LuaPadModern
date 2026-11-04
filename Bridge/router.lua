-- LuaPadModern v1 request router. Pure Lua 5.1; source-only until RIFT integration.
-- This module does not register slash commands, write files or execute arbitrary Lua.
local Router = {}

local function validLimit(value, minimum, maximum)
  return type(value) == "number" and value == math.floor(value)
    and value >= minimum and value <= maximum
end

function Router.new(codec, uiStatus, options)
  if type(codec) ~= "table" or type(codec.makeResult) ~= "function"
    or type(codec.encode) ~= "function" then return nil, "INVALID_CODEC" end
  if uiStatus ~= nil and (type(uiStatus) ~= "table"
    or type(uiStatus.capture) ~= "function") then return nil, "INVALID_UI_STATUS" end
  options = options or {}
  if type(options) ~= "table" then return nil, "INVALID_OPTIONS" end

  local journalLimit = options.journalLimit or 64
  local requestBytes = options.requestBytes or 8192
  local resultBytes = options.resultBytes or 16384
  if not validLimit(journalLimit, 1, 128)
    or not validLimit(requestBytes, 256, 16384)
    or not validLimit(resultBytes, 512, 65536)
    or (options.getUiRefs ~= nil and type(options.getUiRefs) ~= "function")
    or (options.transportReady ~= nil and type(options.transportReady) ~= "boolean")
  then return nil, "INVALID_OPTIONS" end

  local version = options.addonVersion or "unknown"
  local sample = {requestId="router-probe-0001",sessionId="router-start",operation="health"}
  if not codec.makeResult(sample, "ok", {}, {addonVersion=version}) then
    return nil, "INVALID_OPTIONS"
  end
  local journal, order = {}, {}
  local operations = {"health", "bridge.capabilities"}
  if uiStatus then operations[#operations+1] = "ui.status" end

  local function render(req, status, payload, code, message, truncated)
    local opts = {addonVersion=version, truncated=truncated == true}
    if status == "error" then opts.error = {code=code, message=message} end
    local envelope, err = codec.makeResult(req, status, payload, opts)
    if not envelope then return nil, err end
    local json, jsonErr = codec.encode(envelope, {maxBytes=resultBytes})
    if json then return json, envelope end
    if jsonErr ~= "OUTPUT_TOO_LARGE" then return nil, jsonErr end
    local fallback = assert(codec.makeResult(req, "error", {}, {
      addonVersion=version, truncated=true,
      error={code="OUTPUT_TRUNCATED",message="Response exceeds the configured JSON byte limit"}
    }))
    return codec.encode(fallback, {maxBytes=resultBytes}), fallback
  end
  local function reject(req, code, message)
    return render(req, "error", {}, code, message)
  end
  local function remember(req, signature, json, envelope)
    local bucket = journal[req.sessionId]
    if not bucket then bucket = {}; journal[req.sessionId] = bucket end
    bucket[req.requestId] = {signature=signature,json=json,envelope=envelope}
    order[#order + 1] = {session=req.sessionId,id=req.requestId}
    if #order > journalLimit then
      local oldest = table.remove(order, 1)
      local previous = journal[oldest.session]
      if previous then
        previous[oldest.id] = nil
        if next(previous) == nil then journal[oldest.session] = nil end
      end
    end
  end

  local instance = {}
  function instance:dispatch(req)
    -- Missing/broken correlation IDs cannot be reported as a valid result.
    if type(req) ~= "table" or not codec.makeResult(req, "ok", {}) then
      return nil, "INVALID_ARGUMENTS"
    end
    if req.protocol ~= "luapad-bridge" or req.version ~= 1 then
      return reject(req, "UNSUPPORTED_VERSION", "Expected luapad-bridge v1")
    end
    if req.kind ~= "request" or req.status ~= nil or req.error ~= nil
      or type(req.source) ~= "table" or type(req.payload) ~= "table"
    then return reject(req, "INVALID_ARGUMENTS", "Expected a request envelope") end
    local allowedTop = {protocol=true,version=true,kind=true,requestId=true,
      sessionId=true,operation=true,source=true,payload=true,meta=true}
    for key in pairs(req) do
      if not allowedTop[key] then
        return reject(req, "INVALID_ARGUMENTS", "Unexpected request envelope field")
      end
    end
    local source = req.source.component
    if source ~= "host" and source ~= "workbridge" and source ~= "addon" then
      return reject(req, "INVALID_ARGUMENTS", "Request source component is invalid")
    end
    for key, value in pairs(req.source) do
      if key ~= "component" and key ~= "clientTag" and key ~= "addonVersion" then
        return reject(req, "INVALID_ARGUMENTS", "Unexpected request source field")
      end
      if key == "clientTag" and (type(value) ~= "string" or #value > 128) then
        return reject(req, "INVALID_ARGUMENTS", "Invalid clientTag")
      end
      if key == "addonVersion" and (type(value) ~= "string" or #value > 64) then
        return reject(req, "INVALID_ARGUMENTS", "Invalid addonVersion")
      end
    end
    if req.meta ~= nil then
      if type(req.meta) ~= "table" or type(req.meta.truncated) ~= "boolean" then
        return reject(req, "INVALID_ARGUMENTS", "Invalid request metadata")
      end
      local metaKeys = {truncated=true, transport=true, receivedAtUtc=true,
        evidenceSha256=true, sourceAgeMs=true, chunkIndex=true, chunkTotal=true}
      for key in pairs(req.meta) do
        if not metaKeys[key] then return reject(req, "INVALID_ARGUMENTS", "Unexpected metadata field") end
      end
    end
    for key in pairs(req.payload) do
      if type(key) ~= "string" then
        return reject(req, "INVALID_ARGUMENTS", "Payload must be a JSON object")
      end
    end
    -- Deterministic canonical signature, bounded before any handler is entered.
    local signature, signatureErr = codec.encode({
      operation=req.operation, payload=req.payload, source=req.source
    }, {maxBytes=requestBytes, maxDepth=10, maxNodes=1024})
    if not signature then
      return reject(req, "INVALID_ARGUMENTS", "Request failed bounded JSON validation: " .. tostring(signatureErr))
    end
    local seen = journal[req.sessionId]
    seen = seen and seen[req.requestId]
    if seen then
      if seen.signature == signature then return seen.json, seen.envelope end
      return reject(req, "DUPLICATE_REQUEST_CONFLICT",
        "This session/requestId was already used with different content")
    end
    local json, envelope
    if next(req.payload) ~= nil then
      json, envelope = reject(req, "INVALID_ARGUMENTS", "This operation requires an empty payload")
    elseif req.operation == "health" then
      json, envelope = render(req, "ok", {
        routerReady=true, liveTransportReady=options.transportReady == true,
        addonVersion=version, bridgeVersion=1
      })
    elseif req.operation == "bridge.capabilities" then
      json, envelope = render(req, "ok", {
        operations=operations, mode="read-only", liveTransportReady=options.transportReady == true
      })
    elseif req.operation == "ui.status" and uiStatus then
      if type(options.getUiRefs) ~= "function" then
        json, envelope = reject(req, "GAME_NOT_READY", "UI frame references are not bound")
      else
        local ok, context, window, editor = pcall(options.getUiRefs)
        if not ok then
          json, envelope = reject(req, "INTERNAL_ERROR", "UI reference discovery failed")
        elseif context == nil and window == nil and editor == nil then
          json, envelope = reject(req, "GAME_NOT_READY", "LuaPad frames are unavailable")
        else
          local captured, state = pcall(uiStatus.capture, context, window, editor)
          if not captured then
            json, envelope = reject(req, "INTERNAL_ERROR", "UI observation failed")
          else
            json, envelope = render(req, "ok", state)
          end
        end
      end
    else
      json, envelope = reject(req, "UNSUPPORTED_OPERATION", "This operation is not available")
    end
    if json then remember(req, signature, json, envelope) end
    return json, envelope
  end
  return instance
end

return Router
