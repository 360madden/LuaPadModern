-- LuaPadModern Bridge v1. Pure Lua 5.1 serializer/envelope helper.
-- Not loaded by RiftAddon.toc until the separate M2 game-integration gate.
-- Keep this module independent of RIFT widgets, Windows I/O, and Workbridge.
local Codec = {}

local function validUtf8(s)
  local i, n = 1, #s
  while i <= n do
    local b = s:byte(i)
    local width
    if b <= 127 then width = 1
    elseif b >= 194 and b <= 223 then width = 2
    elseif b >= 224 and b <= 239 then width = 3
    elseif b >= 240 and b <= 244 then width = 4
    else return false end
    if i + width - 1 > n then return false end
    if width > 1 then
      local b2 = s:byte(i + 1)
      if b2 < 128 or b2 > 191 then return false end
      if (b == 224 and b2 < 160) or (b == 237 and b2 > 159) then return false end
      if (b == 240 and b2 < 144) or (b == 244 and b2 > 143) then return false end
    end
    for j = 3, width do
      local c = s:byte(i + j - 1)
      if c < 128 or c > 191 then return false end
    end
    i = i + width
  end
  return true
end

local escapes = {
  ['"'] = '\\"',
  ['\\'] = '\\\\',
  ['\b'] = '\\b',
  ['\f'] = '\\f',
  ['\n'] = '\\n',
  ['\r'] = '\\r',
  ['\t'] = '\\t'
}

local function jsonString(s, fail)
  if not validUtf8(s) then fail("INVALID_UTF8") end
  return '"' .. (s:gsub('[%z\1-\31\\"]', function(c)
    return escapes[c] or string.format("\\u%04x", c:byte())
  end)) .. '"'
end

-- Returns (text, nil) or (nil, code). Stable ordering for JSON object keys.
-- Limits prevent a cyclic/large RIFT inspection table from monopolizing Lua.
function Codec.encode(value, options)
  options = options or {}
  if type(options) ~= "table" then return nil, "INVALID_LIMIT" end
  local maxBytes = options.maxBytes or 16384
  local maxDepth = options.maxDepth or 12
  local maxNodes = options.maxNodes or 2048
  if type(maxBytes) ~= "number" or maxBytes % 1 ~= 0 or maxBytes < 2 or maxBytes > 65536
    or type(maxDepth) ~= "number" or maxDepth % 1 ~= 0 or maxDepth < 1 or maxDepth > 32
    or type(maxNodes) ~= "number" or maxNodes % 1 ~= 0 or maxNodes < 1 or maxNodes > 10000
  then return nil, "INVALID_LIMIT" end
  local chunks, size, nodes, seen = {}, 0, 0, {}
  local function fail(code) error(code, 0) end
  local function put(s)
    size = size + #s
    if size > maxBytes then fail("OUTPUT_TOO_LARGE") end
    chunks[#chunks + 1] = s
  end
  local visit
  visit = function(v, depth)
    nodes = nodes + 1
    if nodes > maxNodes then fail("TOO_MANY_NODES") end
    local kind = type(v)
    if kind == "nil" then put("null")
    elseif kind == "boolean" then put(v and "true" or "false")
    elseif kind == "number" then
      if v ~= v or v == math.huge or v == -math.huge then fail("NONFINITE_NUMBER") end
      put(tostring(v))
    elseif kind == "string" then
      if #v > maxBytes then fail("OUTPUT_TOO_LARGE") end
      put(jsonString(v, fail))
    elseif kind == "table" then
      if depth >= maxDepth then fail("TOO_DEEP") end
      if seen[v] then fail("CYCLIC_TABLE") end
      seen[v] = true
      local total, numeric, maximum = 0, 0, 0
      local keys = {}
      for key in pairs(v) do
        total = total + 1
        if type(key) == "number" and key >= 1 and key % 1 == 0 then
          numeric = numeric + 1
          if key > maximum then maximum = key end
        elseif type(key) == "string" then
          keys[#keys + 1] = key
        else
          fail("INVALID_TABLE_KEY")
        end
        if total > maxNodes then fail("TOO_MANY_NODES") end
      end
      if numeric ~= 0 then
        if numeric ~= total then fail("MIXED_TABLE_KEYS") end
        if maximum ~= numeric then fail("SPARSE_ARRAY") end
        put("[")
        for i = 1, numeric do
          if i > 1 then put(",") end
          visit(v[i], depth + 1)
        end
        put("]")
      else
        table.sort(keys)
        put("{")
        for i, key in ipairs(keys) do
          if i > 1 then put(",") end
          put(jsonString(key, fail))
          put(":")
          visit(v[key], depth + 1)
        end
        put("}")
      end
      seen[v] = nil
    else
      fail("UNSUPPORTED_TYPE")
    end
  end
  local ok, err = pcall(visit, value, 0)
  if not ok then return nil, tostring(err) end
  return table.concat(chunks), nil
end

local function requestIdentity(req)
  if type(req) ~= "table" then return false end
  local id, session, op = req.requestId, req.sessionId, req.operation
  if type(id) ~= "string" or #id < 8 or #id > 80
    or not id:match("^[A-Za-z0-9][A-Za-z0-9._-]+$") then return false end
  if type(session) ~= "string" or #session < 8 or #session > 96 then return false end
  if type(op) ~= "string" or #op < 1 or #op > 64
    or not op:match("^[a-z][a-z0-9.]*$")
    or op:find("%.%.") or op:find("%.$") or op:find("%.[^a-z]")
  then return false end
  return true
end

-- Make an addon result bound to host-owned IDs. Does not execute scripts.
function Codec.makeResult(req, status, payload, opts)
  if not requestIdentity(req) then return nil, "INVALID_ARGUMENTS" end
  status = status or "ok"
  if status ~= "ok" and status ~= "partial" and status ~= "error" then
    return nil, "INVALID_STATUS"
  end
  if payload ~= nil then
    if type(payload) ~= "table" then return nil, "INVALID_PAYLOAD" end
    for key in pairs(payload) do
      if type(key) ~= "string" then return nil, "INVALID_PAYLOAD" end
    end
  end
  opts = opts or {}
  if type(opts) ~= "table" then return nil, "INVALID_ARGUMENTS" end
  if opts.truncated ~= nil and type(opts.truncated) ~= "boolean" then return nil, "INVALID_ARGUMENTS" end
  local transports = {clipboard=true, ["win32-input"]=true, uia=true, ipc=true, rr2=true}
  if opts.transport ~= nil and not transports[opts.transport] then return nil, "INVALID_ARGUMENTS" end
  if opts.addonVersion ~= nil and (type(opts.addonVersion) ~= "string"
      or #opts.addonVersion > 64 or not validUtf8(opts.addonVersion)) then
    return nil, "INVALID_ARGUMENTS"
  end
  if status == "error" then
    local err = opts.error
    if type(err) ~= "table" or type(err.code) ~= "string"
      or #err.code < 3 or #err.code > 64 or not err.code:match("^[A-Z][A-Z0-9_]+$")
      or type(err.message) ~= "string" or #err.message < 1
      or #err.message > 2048 or not validUtf8(err.message) then
      return nil, "INVALID_ERROR"
    end
  elseif opts.error ~= nil then
    return nil, "INVALID_ERROR"
  end
  local source = {component = "addon"}
  if type(opts.addonVersion) == "string" then source.addonVersion = opts.addonVersion end
  local envelope = {
    protocol = "luapad-bridge",
    version = 1,
    kind = "result",
    requestId = req.requestId,
    sessionId = req.sessionId,
    operation = req.operation,
    source = source,
    payload = payload or {},
    status = status,
    meta = {truncated = opts.truncated == true}
  }
  -- The encoder cannot know how bytes are delivered. Stamp transport only
  -- after that route has genuinely been selected, not merely anticipated.
  if opts.transport then envelope.meta.transport = opts.transport end
  if status == "error" then
    envelope.error = {code = opts.error.code, message = opts.error.message}
  end
  return envelope, nil
end

return Codec
