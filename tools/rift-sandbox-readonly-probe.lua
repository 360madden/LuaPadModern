-- LuaPadModern read-only RIFT addon sandbox inventory, revision 1.
-- Manually paste/run from LuaPad's code editor. NOT in RiftAddon.toc; never auto-runs.
-- No OS, gameplay, storage, cursor, message, clipboard or console API is invoked.
-- Presence of a function is NOT permission to call it in any Secure state.
local function line(label, value)
  print("[LP-SANDBOX/1] " .. label .. "=" .. tostring(value))
end
local function short(value)
  local s = tostring(value == nil and "unknown" or value):gsub("[\r\n\t|]", " ")
  return s:sub(1, 72)
end
local function resolve(dotted)
  local node = _G
  for part in dotted:gmatch("[^.]+") do
    if type(node) ~= "table" then return nil end
    local ok, value = pcall(function() return node[part] end)
    if not ok then return nil end
    node = value
  end
  return node
end
local names = {
  "Inspect.System.Secure", "Event.System.Secure.Enter", "Event.System.Secure.Leave",
  "Inspect.Documentation", "Inspect.System.Version", "Inspect.Addon.Current",
  "Command.System.Strict", "Command.System.Watchdog.Quiet",
  "Command.Console.Display", "Command.CopyToClipboard",
  "Command.Slash.Register", "Command.Message.Send", "Command.Message.Broadcast",
  "Command.Storage.Get", "Command.Storage.Set", "Inspect.Queue.Status",
  "UI.CreateContext", "UI.CreateFrame",
  "Event.UI.Input.Key.Down", "Event.UI.Input.Key.Focus.Gain",
  "io.open", "os.execute", "package.loadlib", "socket.tcp", "require", "loadstring",
}
line("mode", "read-only-symbol-types")
for _, name in ipairs(names) do
  line("type:" .. name, type(resolve(name)))
end
local function safeCall(name)
  local fn = resolve(name)
  if type(fn) ~= "function" then return false, "unavailable" end
  local ok, value = pcall(fn)
  if not ok then return false, "call-error" end
  return true, value
end
local okSecure, secure = safeCall("Inspect.System.Secure")
line("environmentSecure", okSecure and type(secure) == "boolean" and tostring(secure) or "unknown")
local okVersion, version = safeCall("Inspect.System.Version")
if okVersion and type(version) == "table" then
  line("version.external", short(version.external))
  line("version.internal", short(version.internal))
  line("version.build", short(version.build))
else
  line("version", "unavailable")
end
local okAddon, addon = safeCall("Inspect.Addon.Current")
line("addonCurrent", okAddon and short(addon) or "unavailable")
local docs = resolve("Inspect.Documentation")
if type(docs) == "function" then
  local ok, result = pcall(docs, "Inspect.System.Secure", true)
  line("documentation.readonly", ok and type(result) or "call-error")
  if ok and type(result) == "table" then
    line("documentation.disabled", type(result.disabled) == "boolean" and tostring(result.disabled) or "unknown")
  end
else
  line("documentation.readonly", "unavailable")
end
line("complete", "presence-is-not-permission")
