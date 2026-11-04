-- LuaPadModern slash transport source-only tests (Lua 5.1 / Fengari).
-- In-game callback wiring and clipboard delivery are intentionally unclaimed.
local Codec = assert(loadfile("Bridge/codec.lua"))()
local UiStatus = assert(loadfile("Bridge/ui_status.lua"))()
local Router = assert(loadfile("Bridge/router.lua"))()
local Slash = assert(loadfile("Bridge/slash.lua"))()
local passed = 0
local function check(label, ok)
  if not ok then error("FAIL " .. label, 0) end
  passed = passed + 1
  print("PASS " .. label)
end
local function eq(label, actual, expected)
  check(label, actual == expected)
end
local id, session = "req-20261104-0001", "winhost-session-20261104"
local function command(verb, identity, hostSession)
  return "v1 " .. verb .. " " .. (identity or id) .. " " .. (hostSession or session)
end

for _, mapping in ipairs({
  {"health", "health"},
  {"caps", "bridge.capabilities"},
  {"status", "ui.status"}
}) do
  local req, err = Slash.parse(command(mapping[1]))
  eq("slash " .. mapping[1] .. " parses", err, nil)
  eq("slash " .. mapping[1] .. " operation mapped", req.operation, mapping[2])
  eq("slash " .. mapping[1] .. " correlation request", req.requestId, id)
  eq("slash " .. mapping[1] .. " correlation session", req.sessionId, session)
  eq("slash " .. mapping[1] .. " source host", req.source.component, "host")
  eq("slash " .. mapping[1] .. " request kind", req.kind, "request")
  eq("slash " .. mapping[1] .. " protocol version", req.version, 1)
  check("slash " .. mapping[1] .. " empty payload", next(req.payload) == nil)
end
local whitespace = assert(Slash.parse(" \t" .. command("health") .. "   "))
eq("leading trailing whitespace accepted", whitespace.operation, "health")
local unusual = assert(Slash.parse(command("status", "A2345678", "S2345678")))
eq("short valid ID supported", unusual.requestId, "A2345678")
eq("short valid session supported", unusual.sessionId, "S2345678")

local invalid = {
  {nil, "INVALID_COMMAND_TEXT"},
  {true, "INVALID_COMMAND_TEXT"},
  {{}, "INVALID_COMMAND_TEXT"},
  {"", "INVALID_COMMAND_TEXT"},
  {"v1", "INVALID_COMMAND_TEXT"},
  {"v1 health", "INVALID_COMMAND_TEXT"},
  {"v1 health req-20261104", "INVALID_COMMAND_TEXT"},
  {command("health") .. " extra", "INVALID_COMMAND_TEXT"},
  {"v2 health " .. id .. " " .. session, "INVALID_COMMAND_TEXT"},
  {command("health"):gsub(" ", "\n", 1), "INVALID_COMMAND_TEXT"},
  {command("health"):gsub(" ", "\r", 1), "INVALID_COMMAND_TEXT"},
  {command("health") .. "\0", "INVALID_COMMAND_TEXT"},
  {string.rep("x", 257), "INVALID_COMMAND_TEXT"},
  {command("run"), "UNSUPPORTED_OPERATION"},
  {command("lua.execute"), "UNSUPPORTED_OPERATION"},
  {command("inspect"), "UNSUPPORTED_OPERATION"},
  {command("health", "short"), "INVALID_IDENTITY"},
  {command("health", string.rep("r", 81)), "INVALID_IDENTITY"},
  {command("health", "-leadingx"), "INVALID_IDENTITY"},
  {command("health", "bad/idtag"), "INVALID_IDENTITY"},
  {command("health", "bad:idtag"), "INVALID_IDENTITY"},
  {command("health", id, "short"), "INVALID_IDENTITY"},
  {command("health", id, string.rep("s", 97)), "INVALID_IDENTITY"},
  {command("health", id, "session/slash"), "INVALID_IDENTITY"}
}
for n, item in ipairs(invalid) do
  local req, err = Slash.parse(item[1])
  eq("invalid input " .. n .. " returns no request", req, nil)
  eq("invalid input " .. n .. " error code", err, item[2])
end

local count, clipboard, notices, uiReads, mutations = 0, nil, {}, 0, 0
local context={GetLayer=function() return 7 end,GetStrata=function() return "hud" end}
context.SetLayer=function() mutations=mutations+1 end
local window={
  GetLayer=function() return 9 end,GetStrata=function() return "hud" end,
  GetVisible=function() return true end,GetLeft=function() return 100 end,
  GetTop=function() return 120 end,GetWidth=function() return 840 end,
  GetHeight=function() return 600 end
}
window.SetVisible=function() mutations=mutations+1 end
local editor={GetKeyFocus=function() return false end}
editor.SetKeyFocus=function() mutations=mutations+1 end
local router=assert(Router.new(Codec, UiStatus, {
  addonVersion="2.0.0-preview17", journalLimit=16,
  getUiRefs=function() uiReads=uiReads+1; return context,window,editor end
}))
local adapter=assert(Slash.new(router,
  function(value) count=count+1; clipboard=value end,
  function(value) notices[#notices+1]=value end))
local receipt, err=adapter:handle(command("health"))
eq("health adapter error absent", err, nil)
eq("health receipt ID", receipt.requestId, id)
eq("health receipt session", receipt.sessionId, session)
eq("health receipt operation", receipt.operation, "health")
eq("health receipt status", receipt.status, "ok")
eq("health copy attempted", receipt.copyApiInvoked, true)
eq("health copy exactly once", count, 1)
eq("health copy receipt byte count", receipt.bytes, #clipboard)
check("health JSON includes correlation ID", clipboard:find('"requestId":"'..id..'"',1,true) ~= nil)
check("health JSON indicates router readiness", clipboard:find('"routerReady":true',1,true) ~= nil)
check("health JSON does not claim live transport", clipboard:find('"liveTransportReady":false',1,true) ~= nil)
check("health JSON has no unverified transport attribution", clipboard:find('"transport"',1,true) == nil)
check("health JSON identifies addon as result source", clipboard:find('"component":"addon"',1,true) ~= nil)
check("health command notification is bounded", #notices[1] < 256)
local first=clipboard
local second, secondError=adapter.callback(command("health"))
eq("callback single string accepted", secondError, nil)
eq("callback returns correlated ID", second.requestId, id)
eq("duplicate replays identical JSON", clipboard, first)
eq("duplicate still counts one new copy", count, 2)

local caps, capsErr=adapter:handle(command("caps", "req-20261104-caps"))
eq("caps no adapter error", capsErr, nil)
eq("caps response status", caps.status, "ok")
eq("caps maps operation", caps.operation, "bridge.capabilities")
check("caps JSON discloses read-only", clipboard:find('"mode":"read-only"',1,true) ~= nil)
eq("caps copied", count, 3)
local status, statusErr=adapter:handle(command("status", "req-20261104-status"))
eq("ui.status no adapter error", statusErr, nil)
eq("ui.status receipt success", status.status, "ok")
eq("ui.status snapshot hit getter", uiReads, 1)
check("ui.status JSON shows false editor focus", clipboard:find('"editorKeyFocus":false',1,true) ~= nil)
check("ui.status JSON denies occlusion verification", clipboard:find('"canVerifyOcclusion":false',1,true) ~= nil)
eq("ui.status has no setter side effects", mutations, 0)
eq("ui.status copied", count, 4)

local beforeInvalid=clipboard
local beforeCount=count
local badReceipt, badErr=adapter:handle(command("run"))
eq("unsupported operation not acknowledged", badReceipt, nil)
eq("unsupported operation error surfaced", badErr, "UNSUPPORTED_OPERATION")
eq("rejected command never overwrites clipboard", clipboard, beforeInvalid)
eq("rejected command never invokes copy", count, beforeCount)
check("error notice includes usage", notices[#notices]:find("Usage:",1,true) ~= nil)
for n,args in ipairs({
  {{}},
  {command("health"),"extra"},
  {"/lpb",command("health")},
  {nil},
  {true},
  {command("health"),{}}
}) do
  local unpackArgs = unpack or table.unpack
  local result, shapeErr=adapter.callback(unpackArgs(args))
  eq("callback shape " .. n .. " no receipt", result, nil)
  eq("callback shape " .. n .. " rejected", shapeErr, "CALLBACK_SHAPE_UNVERIFIED")
end
eq("unexpected callback shape never calls copy", count, beforeCount)
eq("unexpected callback shape leaves clipboard", clipboard, beforeInvalid)

check("reject missing router",Slash.new(nil, function() end)==nil)
check("reject router without dispatch",Slash.new({},function() end)==nil)
check("reject missing copy API",Slash.new(router,nil)==nil)
check("reject nonfunction notify",Slash.new(router,function() end,true)==nil)
local _, noDependencyCode=Slash.new({},function() end)
eq("dependency error code",noDependencyCode,"INVALID_ADAPTER_DEPENDENCIES")
local copyFailures = {
  {function() return false end},
  {function() error("locked") end}
}
for n,copy in ipairs(copyFailures) do
  local a=assert(Slash.new(router,copy[1]))
  local copyReceipt, copyErr=a:handle(command("health", "req-copy-failure-" .. n))
  eq("clipboard failure " .. n .. " no receipt", copyReceipt, nil)
  eq("clipboard failure " .. n .. " code", copyErr, "CLIPBOARD_FAILED")
end
local nilReturn=assert(Slash.new(router,function(value) clipboard=value; return nil end))
local unknownSuccess, unknownErr=nilReturn:handle(command("health","req-copy-nil-return"))
eq("nil-returning native copy accepted as invocation",unknownErr,nil)
eq("nil-returning copy receipt marked API invoked",unknownSuccess.copyApiInvoked,true)
local noticeFailure=assert(Slash.new(router,function() return true end,
  function() error("chat is unavailable") end))
local stillSucceeded, noticeErr=noticeFailure:handle(command("health","req-notice-failure"))
eq("chat notice exception does not block valid reply",noticeErr,nil)
eq("chat notice exception still has receipt",stillSucceeded.status,"ok")

for n, brokenRouter in ipairs({
  {dispatch=function() error("routing failed") end},
  {dispatch=function() return nil,nil end},
  {dispatch=function() return {},{} end},
  {dispatch=function() return string.rep("x",16385),{kind="result",requestId=id,sessionId=session,operation="health",status="ok"} end},
  {dispatch=function() return "{}",{kind="result",requestId="different",sessionId=session,operation="health",status="ok"} end},
  {dispatch=function() return "{}",{kind="result",requestId=id,sessionId="different",operation="health",status="ok"} end},
  {dispatch=function() return "{}",{kind="result",requestId=id,sessionId=session,operation="other",status="ok"} end},
  {dispatch=function() return "{}",{kind="event",requestId=id,sessionId=session,operation="health",status="ok"} end},
  {dispatch=function() return "{}",{kind="result",requestId=id,sessionId=session,operation="health",status="bogus"} end}
}) do
  local called=0
  local a=assert(Slash.new(brokenRouter,function() called=called+1 end))
  local failed, failureCode=a:handle(command("health"))
  eq("bad router " .. n .. " no receipt",failed,nil)
  eq("bad router " .. n .. " error",failureCode,"ROUTER_FAILED")
  eq("bad router " .. n .. " no clipboard",called,0)
end
eq("no UI setters from entire transport suite",mutations,0)
print("Source-only slash transport checks: " .. passed .. " passed")