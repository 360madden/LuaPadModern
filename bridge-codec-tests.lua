-- Headless Bridge v1 codec tests; run with Fengari (Lua 5.1-compatible code).
local Codec = assert(loadfile("Bridge/codec.lua"))()
local passed = 0
local function check(name, condition)
  if not condition then error("FAIL " .. name, 0) end
  passed = passed + 1
  print("PASS " .. name)
end
local function equal(name, actual, expected)
  check(name, actual == expected)
end
local encode = Codec.encode
equal("nil", encode(nil), "null")
equal("boolean", encode(true), "true")
equal("number", encode(42.5), "42.5")
equal("empty object", encode({}), "{}")
equal("stable object sort", encode({z=3,a=1}), '{"a":1,"z":3}')
equal("array", encode({"a","b"}), '["a","b"]')
equal("nested", encode({a={1,2},b=false}), '{"a":[1,2],"b":false}')
equal("escape basic", encode({s='a\n"\\\t'}), '{"s":"a\\n\\"\\\\\\t"}')
equal("escape control", encode(string.char(0,1,31)), '"\\u0000\\u0001\\u001f"')
equal("UTF-8 intact", encode("€"), '"€"')
local function rejected(name, val, code, opts)
  local out, err = encode(val, opts)
  check(name, out == nil and err == code)
end
rejected("invalid UTF-8", string.char(0xc3,0x28), "INVALID_UTF8")
rejected("overlong UTF-8", string.char(0xc0,0x80), "INVALID_UTF8")
rejected("unpaired surrogate", string.char(0xed,0xa0,0x80), "INVALID_UTF8")
rejected("nonfinite", math.huge, "NONFINITE_NUMBER")
rejected("unsupported value", function() end, "UNSUPPORTED_TYPE")
rejected("bad table key", {[true]="bad"}, "INVALID_TABLE_KEY")
rejected("sparse array", {[1]="a",[3]="c"}, "SPARSE_ARRAY")
rejected("mixed keys", {[1]="a",k=2}, "MIXED_TABLE_KEYS")
local cyclic = {}; cyclic.self = cyclic
rejected("cycles", cyclic, "CYCLIC_TABLE")
rejected("byte cap", "abcdef", "OUTPUT_TOO_LARGE", {maxBytes=4})
rejected("depth cap", {a={b=true}}, "TOO_DEEP", {maxDepth=1})
rejected("node cap", {a=1,b=2}, "TOO_MANY_NODES", {maxNodes=2})
rejected("invalid limit", 1, "INVALID_LIMIT", {maxBytes=0})
local shared = {val=2}
check("shared noncyclic objects accepted", encode({a=shared,b=shared}) ~= nil)
local req = {requestId="lp-20261104-0001",sessionId="winhost-20261104-a",operation="api.inspect"}
local out, err = Codec.makeResult(req, "ok", {expression="Inspect.Unit.Detail",valueType="function"}, {addonVersion="2.0.0-preview17"})
check("result envelope", err == nil and out.protocol == "luapad-bridge" and out.version == 1
 and out.source.component == "addon" and out.source.addonVersion == "2.0.0-preview17"
 and out.requestId == req.requestId and out.sessionId == req.sessionId
 and out.operation == req.operation and out.meta.truncated == false)
check("result JSON", (encode(out) or ""):find('"requestId":"lp%-20261104%-0001"') ~= nil)
local errorOut, errorErr = Codec.makeResult(req, "error", {}, {error={code="LUA_RUNTIME_ERROR",message="test"}})
check("error envelope", errorErr == nil and errorOut.error.code == "LUA_RUNTIME_ERROR")
check("error JSON", (encode(errorOut) or ""):find('"status":"error"', 1, true) ~= nil)
local missing, missingErr = Codec.makeResult({requestId="bad",sessionId="12345678",operation="health"}, "ok", {})
check("reject invalid request", missing == nil and missingErr == "INVALID_ARGUMENTS")
local bad, badErr = Codec.makeResult(req,"error",{}, {})
check("reject missing error details", bad == nil and badErr == "INVALID_ERROR")
local badStatus, badStatusErr = Codec.makeResult(req,"bogus",{}, {})
check("reject status", badStatus == nil and badStatusErr == "INVALID_STATUS")
local arrayPayload, arrayErr = Codec.makeResult(req,"ok",{"a","b"})
check("reject array payload", arrayPayload == nil and arrayErr == "INVALID_PAYLOAD")
local oversizedVersion, verErr = Codec.makeResult(req,"ok",{}, {addonVersion=string.rep("v",65)})
check("reject oversized version", oversizedVersion == nil and verErr == "INVALID_ARGUMENTS")
local badTrunc, truncErr = Codec.makeResult(req,"ok",{}, {truncated="yes"})
check("reject nonboolean truncated", badTrunc == nil and truncErr == "INVALID_ARGUMENTS")
local longError, longErr = Codec.makeResult(req,"error",{}, {error={code="LUA_RUNTIME_ERROR",message=string.rep("x",2049)}})
check("reject oversized error", longError == nil and longErr == "INVALID_ERROR")
local invalidError, utfErr = Codec.makeResult(req,"error",{}, {error={code="LUA_RUNTIME_ERROR",message=string.char(0xc0,0x80)}})
check("reject invalid UTF-8 in error", invalidError == nil and utfErr == "INVALID_ERROR")
check("transport is not invented before delivery", out.meta.transport == nil)
local copied = assert(Codec.makeResult(req, "ok", {}, {transport="clipboard"}))
check("explicit actual transport is retained", copied.meta.transport == "clipboard")
local badTransport, transportError = Codec.makeResult(req, "ok", {}, {transport="imaginary"})
check("unsupported transport rejected", badTransport == nil and transportError == "INVALID_ARGUMENTS")
print("Bridge v1 codec checks: " .. passed .. " passed")
