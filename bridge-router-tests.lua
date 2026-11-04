-- Pure Lua 5.1 route dispatch, replay, error and read-only UI snapshot tests.
local Codec = assert(loadfile("Bridge/codec.lua"))()
local UiStatus = assert(loadfile("Bridge/ui_status.lua"))()
local Router = assert(loadfile("Bridge/router.lua"))()
local passed = 0
local function check(label, ok)
  if not ok then error("FAIL " .. label, 0) end
  passed = passed + 1
  print("PASS " .. label)
end
local function eq(label, actual, expected) check(label, actual == expected) end
local function req(operation,id,session)
  return {
    protocol="luapad-bridge",version=1,kind="request",
    requestId=id or "req-20261104-0001",
    sessionId=session or "winhost-session-20261104",
    operation=operation,source={component="host"},payload={}
  }
end
local count, mutations = 0, 0
local ctx = {_layer=7,_strata="hud"}
function ctx:GetLayer() return self._layer end
function ctx:GetStrata() return self._strata end
function ctx:SetLayer() mutations=mutations+1 end
local win = {_visible=true,_layer=9,_strata="hud"}
function win:GetVisible() return self._visible end
function win:GetLayer() return self._layer end
function win:GetStrata() return self._strata end
function win:GetLeft() return 100 end
function win:GetTop() return 110 end
function win:GetWidth() return 840 end
function win:GetHeight() return 600 end
function win:SetLayer() mutations=mutations+1 end
local editor={_focus=false}
function editor:GetKeyFocus() return self._focus end
function editor:SetKeyFocus() mutations=mutations+1 end
local router = assert(Router.new(Codec,UiStatus, {
  addonVersion="2.0.0-preview17", journalLimit=2,
  getUiRefs=function() count=count+1; return ctx,win,editor end
}))
local healthText,health = router:dispatch(req("health","req-20261104-health"))
check("health structured response", healthText ~= nil and health.status == "ok")
eq("health request correlation", health.requestId,"req-20261104-health")
eq("health source addon",health.source.component,"addon")
eq("health observed router ready",health.payload.routerReady,true)
eq("health never claims live transport",health.payload.liveTransportReady,false)
eq("health does not invent transport",health.meta.transport,nil)
check("health JSON encoded",healthText:find('"routerReady":true',1,true) ~= nil)

local capabilityText,caps = router:dispatch(req("bridge.capabilities","req-20261104-caps"))
check("capabilities structured",capabilityText ~= nil and caps.status=="ok")
eq("capabilities read-only",caps.payload.mode,"read-only")
eq("ui.status exposed in source router",caps.payload.operations[3],"ui.status")
eq("capabilities no live transport",caps.payload.liveTransportReady,false)

local one = req("ui.status","req-20261104-one")
local beforeText,before = router:dispatch(one)
check("ui.status succeeds",beforeText~=nil and before.status=="ok")
eq("snapshot visible",before.payload.windowVisible,true)
eq("snapshot focus false even when visible",before.payload.editorKeyFocus,false)
eq("snapshot context layer",before.payload.contextLayer,7)
eq("snapshot window layer",before.payload.windowLayer,9)
eq("snapshot never assumes occlusion",before.payload.canVerifyOcclusion,false)
eq("snapshot measured bounds",before.payload.windowBounds.width,840)
eq("status read exactly once",count,1)
eq("status never mutates focus/layers",mutations,0)

editor._focus=true
win._layer=20
local replayText,replay = router:dispatch(one)
eq("replay returns exactly cached JSON",replayText,beforeText)
eq("replay retains original observation",replay.payload.editorKeyFocus,false)
eq("replay does not rerun getter",count,1)
local conflict=req("ui.status","req-20261104-one")
conflict.source.component="workbridge"
local conflictText, conflictResult=router:dispatch(conflict)
eq("conflicting duplicate is error",conflictResult.status,"error")
eq("conflicting duplicate code",conflictResult.error.code,"DUPLICATE_REQUEST_CONFLICT")
eq("conflicting duplicate preserves ID",conflictResult.requestId,one.requestId)
eq("conflicting duplicate does not call provider",count,1)
check("conflicting duplicate encoded",conflictText~=nil)

local newText,newState=router:dispatch(req("ui.status","req-20261104-two"))
eq("new ID refreshes editor focus",newState.payload.editorKeyFocus,true)
eq("new ID refreshes window layer",newState.payload.windowLayer,20)
eq("new ID hits provider once",count,2)
check("new ID response encoded",newText~=nil)
router:dispatch(req("health","req-20261104-third")) -- evicts old ui.status journal entry
local afterEvictionText,afterEviction=router:dispatch(one)
eq("bounded journal evicts old request",count,3)
eq("evicted ID can refresh read-only status",afterEviction.payload.editorKeyFocus,true)
check("eviction response encoded",afterEvictionText~=nil)

local unknownText, unknown=router:dispatch(req("lua.execute","req-20261104-unknown"))
eq("unimplemented execution refused",unknown.error.code,"UNSUPPORTED_OPERATION")
check("unsupported operation result encoded",unknownText~=nil)
local wrongProtocol=req("health","req-20261104-proto")
wrongProtocol.protocol="future-protocol"
local _,badProtocol=router:dispatch(wrongProtocol)
eq("wrong protocol error",badProtocol.error.code,"UNSUPPORTED_VERSION")
local wrongVersion=req("health","req-20261104-version")
wrongVersion.version=2
local _,badVersion=router:dispatch(wrongVersion)
eq("wrong version error",badVersion.error.code,"UNSUPPORTED_VERSION")
local wrongKind=req("health","req-20261104-kind")
wrongKind.kind="event"
local _,badKind=router:dispatch(wrongKind)
eq("wrong kind rejected",badKind.error.code,"INVALID_ARGUMENTS")
local withStatus=req("health","req-20261104-withstatus")
withStatus.status="ok"
local _,badStatus=router:dispatch(withStatus)
eq("request carrying status rejected",badStatus.error.code,"INVALID_ARGUMENTS")
local noSource=req("health","req-20261104-nosource")
noSource.source=nil
local _,badSource=router:dispatch(noSource)
eq("missing source rejected",badSource.error.code,"INVALID_ARGUMENTS")
local noPayload=req("health","req-20261104-nopayload")
noPayload.payload=nil
local _,badPayload=router:dispatch(noPayload)
eq("missing payload rejected",badPayload.error.code,"INVALID_ARGUMENTS")
local badSourceTag=req("health","req-20261104-badtag")
badSourceTag.source.component="foreign"
local _,badTag=router:dispatch(badSourceTag)
eq("unrecognized request source rejected",badTag.error.code,"INVALID_ARGUMENTS")
local extraPayload=req("health","req-20261104-argument")
extraPayload.payload.reason="unsafe"
local _,badArgument=router:dispatch(extraPayload)
eq("unexpected health payload rejected",badArgument.error.code,"INVALID_ARGUMENTS")
local arrayPayload=req("health","req-20261104-array")
arrayPayload.payload={"bad"}
local _,badArray=router:dispatch(arrayPayload)
eq("top-level array payload rejected",badArray.error.code,"INVALID_ARGUMENTS")
local cyc=req("health","req-20261104-cycle")
cyc.payload.self=cyc.payload
local _,badCycle=router:dispatch(cyc)
eq("cyclic payload rejected",badCycle.error.code,"INVALID_ARGUMENTS")
local large=req("health","req-20261104-large")
large.payload.extra=string.rep("z",9000)
local _,tooLarge=router:dispatch(large)
eq("bounded request rejected",tooLarge.error.code,"INVALID_ARGUMENTS")
local extraField=req("health","req-20261104-extra")
extraField.hidden=true
local _,extraneous=router:dispatch(extraField)
eq("unknown top-level request field rejected",extraneous.error.code,"INVALID_ARGUMENTS")
local extraSource=req("health","req-20261104-sourceextra")
extraSource.source.hidden=true
local _,unknownSource=router:dispatch(extraSource)
eq("unknown source field rejected",unknownSource.error.code,"INVALID_ARGUMENTS")
local longTag=req("health","req-20261104-longtag")
longTag.source.clientTag=string.rep("z",129)
local _,tooLongTag=router:dispatch(longTag)
eq("oversized client tag rejected",tooLongTag.error.code,"INVALID_ARGUMENTS")
local missingMetaFlag=req("health","req-20261104-noflag")
missingMetaFlag.meta={}
local _,badMeta=router:dispatch(missingMetaFlag)
eq("metadata without truncated rejected",badMeta.error.code,"INVALID_ARGUMENTS")
local validMeta=req("health","req-20261104-meta")
validMeta.meta={truncated=false}
local _,acceptedMeta=router:dispatch(validMeta)
eq("well-shaped metadata accepted",acceptedMeta.status,"ok")
local extraMeta=req("health","req-20261104-extrameta")
extraMeta.meta={truncated=false,evil=true}
local _,badExtraMeta=router:dispatch(extraMeta)
eq("unknown metadata rejected",badExtraMeta.error.code,"INVALID_ARGUMENTS")
local invalid=req("health","short")
local missingJSON, missingErr=router:dispatch(invalid)
eq("uncorrelatable ID produces no JSON",missingJSON,nil)
eq("uncorrelatable ID error",missingErr,"INVALID_ARGUMENTS")

local noUi=assert(Router.new(Codec,nil,{}))
local _,unsupportedUi=noUi:dispatch(req("ui.status","req-20261104-noui"))
eq("unbound UI route unsupported",unsupportedUi.error.code,"UNSUPPORTED_OPERATION")
local unavailable=assert(Router.new(Codec,UiStatus,{}))
local _,notReady=unavailable:dispatch(req("ui.status","req-20261104-notready"))
eq("UI reference absence is explicit",notReady.error.code,"GAME_NOT_READY")
local emptyRef=assert(Router.new(Codec,UiStatus,{getUiRefs=function() return nil,nil,nil end}))
local _,emptyResult=emptyRef:dispatch(req("ui.status","req-20261104-empty"))
eq("all missing frame references rejected",emptyResult.error.code,"GAME_NOT_READY")
local brokenRef=assert(Router.new(Codec,UiStatus,{getUiRefs=function() error("not available") end}))
local _,brokenResult=brokenRef:dispatch(req("ui.status","req-20261104-broken"))
eq("reference callback exception bounded",brokenResult.error.code,"INTERNAL_ERROR")
check("nil codec rejected",Router.new(nil,UiStatus,{})==nil)
check("invalid UI module rejected",Router.new(Codec,{},{})==nil)
check("non-table router options rejected",Router.new(Codec,UiStatus,"bad")==nil)
check("invalid journal cap rejected",Router.new(Codec,UiStatus,{journalLimit=129})==nil)
check("invalid output cap rejected",Router.new(Codec,UiStatus,{resultBytes=100})==nil)
check("invalid addon version rejected",Router.new(Codec,UiStatus,{addonVersion=string.rep("x",65)})==nil)
local hugeUi={capture=function() return {body=string.rep("z",2048)} end}
local oversized=assert(Router.new(Codec,hugeUi,{resultBytes=512,
  getUiRefs=function() return ctx,win,editor end}))
local shortJSON,shortResult=oversized:dispatch(req("ui.status","req-20261104-bigresponse"))
eq("oversized result converted to error",shortResult.error.code,"OUTPUT_TRUNCATED")
eq("oversized result marks truncation",shortResult.meta.truncated,true)
check("oversized result is valid bounded JSON",shortJSON ~= nil and #shortJSON <= 512)
check("still no UI mutations",mutations==0)
print("Bridge v1 router checks: " .. passed .. " passed")
