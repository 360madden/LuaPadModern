-- Headless regression for tools/rift-sandbox-readonly-probe.lua.
-- Dangerous-looking APIs are present but must never be invoked.
local passed = 0
local function check(label, condition)
  assert(condition, "FAIL " .. label)
  passed = passed + 1
end
local realPrint = print
local records = {}
local function run()
  local before = #records
  print = function(s) records[#records + 1] = tostring(s) end
  local ok, err = pcall(dofile, "tools/rift-sandbox-readonly-probe.lua")
  print = realPrint
  assert(ok, tostring(err))
  return table.concat(records, "\n", before + 1)
end
local calls = 0
local function forbidden()
  calls = calls + 1
  error("dangerous API invoked")
end
_G.io = { open = forbidden }
_G.os = { execute = forbidden }
_G.package = { loadlib = forbidden }
_G.socket = { tcp = forbidden }
_G.Command = {
  System = { Strict = forbidden, Watchdog = { Quiet = forbidden } },
  Console = { Display = forbidden },
  CopyToClipboard = forbidden,
  Slash = { Register = forbidden },
  Message = { Send = forbidden, Broadcast = forbidden },
  Storage = { Get = forbidden, Set = forbidden },
}
_G.Event = { System = { Secure = { Enter = {}, Leave = {} } }, UI = { Input = { Key = { Down = {}, Focus = { Gain = {} } } } } }
_G.UI = { CreateContext = forbidden, CreateFrame = forbidden }
local secureValue = false
_G.Inspect = {
  System = {
    Secure = function() return secureValue end,
    Version = function() return { external = "1.0.0", internal = "build-123", build = 456 } end,
  },
  Addon = { Current = function() return "LuaPad" end },
  Documentation = function(name, parseable)
    check("only selected documentation key", name == "Inspect.System.Secure")
    check("machine-readable mode requested", parseable == true)
    return { disabled = false }
  end,
  Queue = { Status = forbidden },
}
local first = run()
check("read-only banner", first:find("mode=read-only-symbol-types", 1, true) ~= nil)
check("secure mode false reported", first:find("environmentSecure=false", 1, true) ~= nil)
check("loaded addon attributed", first:find("addonCurrent=LuaPad", 1, true) ~= nil)
check("version fields bounded", first:find("version.external=1.0.0", 1, true) ~= nil)
check("documentation result", first:find("documentation.readonly=table", 1, true) ~= nil)
check("documentation disabled false", first:find("documentation.disabled=false", 1, true) ~= nil)
check("OS APIs only inspected", first:find("type:os.execute=function", 1, true) ~= nil)
check("message API only inspected", first:find("type:Command.Message.Send=function", 1, true) ~= nil)
check("completion labels presence not permission", first:find("complete=presence-is-not-permission", 1, true) ~= nil)
check("no dangerous function executed", calls == 0)
secureValue = true
local second = run()
check("secure mode true reported", second:find("environmentSecure=true", 1, true) ~= nil)
check("still no dangerous call", calls == 0)
_G.Inspect = nil
local absent = run()
check("unavailable secure mode explicit", absent:find("environmentSecure=unknown", 1, true) ~= nil)
check("unavailable documentation explicit", absent:find("documentation.readonly=unavailable", 1, true) ~= nil)
check("unavailable version explicit", absent:find("version=unavailable", 1, true) ~= nil)
check("no dangerous call after absent mode", calls == 0)
realPrint("Read-only RIFT addon sandbox probe: " .. passed .. " assertions passed")
