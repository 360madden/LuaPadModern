"use strict";

// Synthetic fixtures only: no RIFT process, AddOns, or SavedVariables touched.
const assert=require("node:assert/strict");
const fs=require("node:fs");
const os=require("node:os");
const path=require("node:path");
const {spawnSync}=require("node:child_process");
const {probePath}=require("./no-reload-pilot-readiness.cjs");

const cli=path.join(__dirname,"no-reload-pilot-readiness.cjs");
const tmp=fs.mkdtempSync(path.join(os.tmpdir(),"luapad-noreload-preflight-"));
const nonce="LPB_PREFLIGHT_TEST_20261104";
const run=args=>spawnSync(process.execPath,[cli,...args],{
  cwd:path.resolve(__dirname,".."),encoding:"utf8",windowsHide:true,
  shell:false,timeout:10000,maxBuffer:512*1024
});
const firstJson=result=>JSON.parse(result.stdout.split(/\r?\n/)[0]);
let passed=0;
const check=(description,condition)=>{assert.equal(condition,true,description);passed++;};
try {
  const help=run(["--help"]);
  check("help succeeds",help.status===0&&help.stdout.includes("Read-only one-shot"));
  const missing=path.join(tmp,"not-created.txt");
  const absent=run(["--path",missing,"--nonce",nonce]);
  const a=firstJson(absent);
  check("missing log is an inconclusive preflight, not failure",
    absent.status===0&&a.status==="LOG_MISSING");
  check("missing log does not imply transport worked",
    a.transportVerified===false&&a.loggingEnabled==="unknown"&&a.flushLatencyMs===null);
  check("preflight never starts watcher or touches game",
    a.gameTouched===false&&a.watcherStarted===false);
  check("watch command keeps nonce and exact path",
    a.watchCommand.args.includes(missing)&&a.watchCommand.args.includes(nonce));
  check("Lua snippet uses same nonce",
    absent.stdout.includes('local token = "'+nonce+'"')&&absent.stdout.includes("LUA_PROBE_END"));

  const existing=path.join(tmp,"Log with spaces.txt");
  const privateChat="UNRELATED_PRIVATE_CHAT_DO_NOT_LEAK\n";
  fs.writeFileSync(existing,privateChat,"utf8");
  const present=run(["--path",existing,"--nonce",nonce]);
  const p=firstJson(present);
  check("existing file readable",present.status===0&&p.status==="LOG_READABLE");
  check("existing file metadata reported without reading chat",
    p.sizeBytes===Buffer.byteLength(privateChat)&&Boolean(Date.parse(p.modifiedAtUtc)));
  check("private chat absent from all output",
    !present.stdout.includes("UNRELATED_PRIVATE_CHAT_DO_NOT_LEAK"));
  check("log access check is read-only",fs.readFileSync(existing,"utf8")===privateChat);
  check("manual actions do not claim console sender called",
    p.nextManualSteps.some(x=>x.includes("manual")||x.includes("Paste"))&&p.transportVerified===false);
  check("watcher match alone is insufficient to attribute a live send",
    p.nextManualSteps.some(x=>x.includes("necessary, not sufficient")&&x.includes("manual in-game send")));

  const dir=run(["--path",tmp,"--nonce",nonce]);
  check("directory is not reported as a log file",firstJson(dir).status==="NOT_A_FILE");
  check("direct metadata check agrees",probePath(existing).status==="LOG_READABLE");
  const originalOpen=fs.openSync;
  try {
    fs.openSync=function(file,...args) {
      if(file===existing) { const error=new Error("locked");error.code="EACCES";throw error; }
      return originalOpen.call(fs,file,...args);
    };
    const denied=probePath(existing);
    check("read-denied file reports code, not a false ready state",
      denied.status==="LOG_ACCESS_ERROR"&&denied.code==="EACCES");
  } finally { fs.openSync=originalOpen; }
  check("bad nonce rejected without launching a watcher",
    run(["--path",existing,"--nonce","BAD!"]).status===1);
  check("relative path rejected",
    run(["--path","relative-log.txt","--nonce",nonce]).status===1);
  check("missing option value rejected",
    run(["--path",existing,"--nonce"]).status===1);
  check("duplicate nonce rejected",
    run(["--path",existing,"--nonce",nonce,"--nonce",nonce]).status===1);
  check("unknown option rejected",run(["--focus-rift"]).status===1);

  const generated=firstJson(run(["--path",missing]));
  check("generated nonce is safe and reusable",
    /^[A-Za-z0-9_-]{8,80}$/.test(generated.nonce) &&
    generated.watchCommand.args.includes(generated.nonce));

  console.log(JSON.stringify({schemaVersion:1,component:"LuaPadModern no-reload preflight",
    ok:true,passed,syntheticOnly:true,gameTouched:false}));
}finally {
  fs.rmSync(tmp,{recursive:true,force:true});
}
