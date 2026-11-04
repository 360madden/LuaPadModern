"use strict";

// Synthetic candidate-path and late-created alternate-log checks. Never opens RIFT.
const assert=require("node:assert/strict");
const fs=require("node:fs");
const os=require("node:os");
const path=require("node:path");
const {spawn}=require("node:child_process");
const {defaultLogPath,defaultLogPaths}=require("./rift-log-probe.cjs");

const root=fs.mkdtempSync(path.join(os.tmpdir(),"LuaPadModern-log-discovery-"));
const nonce="LPB_DISCOVERY_20261104";
let assertions=0;
function check(name,condition) { assert.equal(condition,true,name); assertions++; }
function logFile(rootDir) { return path.join(rootDir,"Documents","RIFT","Log.txt"); }
function eventLines(target) {
  let buffered="";
  return text=>{
    buffered+=text;
    let e;
    while((e=buffered.indexOf("\n"))!==-1) {
      const line=buffered.slice(0,e).trim();
      buffered=buffered.slice(e+1);
      if(!line.startsWith("{"))continue;
      try {target(JSON.parse(line));}catch(_) { /* Ignore non-JSON Lua source. */ }
    }
  };
}
async function runChild(env,writeAtStarted,extraArgs=[],timeoutMs="3000") {
  const child=spawn(process.execPath,["tools/rift-log-probe.cjs","--nonce",nonce,
    "--timeout-ms",timeoutMs,"--poll-ms","25",...extraArgs],
    {cwd:path.resolve(__dirname,".."),env,windowsHide:true,shell:false,
      stdio:["ignore","pipe","pipe"]});
  const events=[];
  let stderr="";
  let started=false;
  const receive=eventLines(event=>{
    events.push(event);
    if(event.event==="started"&&!started){started=true;writeAtStarted(event);}
  });
  child.stdout.setEncoding("utf8");
  child.stdout.on("data",receive);
  child.stderr.setEncoding("utf8");
  child.stderr.on("data",chunk=>{stderr+=chunk;});
  const exitCode=await new Promise((resolve,reject)=>{
    const timer=setTimeout(()=>{child.kill();reject(new Error("probe child timed out"));},6000);
    child.on("error",error=>{clearTimeout(timer);reject(error);});
    child.on("close",code=>{clearTimeout(timer);resolve(code);});
  });
  return {events,exitCode,stderr};
}
async function main(){
  try{
    const profile=path.join(root,"case1");
    const a=path.join(profile,"OneDriveA");
    const b=path.join(profile,"OneDriveB");
    const env={USERPROFILE:profile,OneDrive:a,OneDriveConsumer:"",OneDriveCommercial:b};
    fs.mkdirSync(path.dirname(logFile(b)),{recursive:true});
    check("prefer existing RIFT directory when logs do not yet exist",defaultLogPath(env,profile)===logFile(b));
    fs.mkdirSync(path.dirname(logFile(a)),{recursive:true});
    fs.writeFileSync(logFile(a),"older unrelated chat\n","utf8");
    check("prefer existing Log.txt over directory-only candidates",defaultLogPath(env,profile)===logFile(a));
    check("candidates include both known OneDrive roots",
      defaultLogPaths(env,profile).includes(logFile(a))&&defaultLogPaths(env,profile).includes(logFile(b)));
    check("candidate paths are deduplicated case-insensitively",
      new Set(defaultLogPaths(env,profile).map(x=>x.toLowerCase())).size===defaultLogPaths(env,profile).length);

    const profile2=path.join(root,"case2");
    const first=path.join(profile2,"OneDriveA");
    const later=path.join(profile2,"OneDriveB");
    const env2={...process.env,USERPROFILE:profile2,OneDrive:first,
      OneDriveConsumer:"",OneDriveCommercial:later};
    const data=await runChild(env2,()=>{
      fs.mkdirSync(path.dirname(logFile(later)),{recursive:true});
      fs.writeFileSync(logFile(later),
        "private chat must never be emitted\nLPB_PROBE|"+nonce+"|1700000000.125\n","utf8");
    });
    const opened=data.events.find(e=>e.event==="started");
    check("baseline starts on the preferred absent candidate",
      opened?.path===logFile(first)&&opened.logExists===false);
    check("late-created alternate candidate selected",
      data.events.some(e=>e.event==="log_path_selected"&&e.path===logFile(later)));
    check("alternate candidate marker matched despite pre-poll append",
      data.events.some(e=>e.event==="matched"&&e.nonce===nonce));
    check("synthetic CLI exits cleanly",data.exitCode===0&&data.stderr.trim().length===0);
    // An explicit --path must never silently switch to other discovered logs.
    const profile3=path.join(root,"case3");
    const explicit=logFile(path.join(profile3,"manual-location"));
    const alternate=path.join(profile3,"OneDriveB");
    const env3={...process.env,USERPROFILE:profile3,
      OneDrive:path.join(profile3,"OneDriveA"),OneDriveConsumer:"",OneDriveCommercial:alternate};
    const explicitOnly=await runChild(env3,()=>{
      fs.mkdirSync(path.dirname(logFile(alternate)),{recursive:true});
      fs.writeFileSync(logFile(alternate),"LPB_PROBE|"+nonce+"|1700000001\n","utf8");
    },["--path",explicit],"1000");
    check("explicit --path remains authoritative",
      explicitOnly.events.find(e=>e.event==="started")?.path===explicit);
    check("explicit --path never autoselects another candidate",
      !explicitOnly.events.some(e=>e.event==="log_path_selected"||e.event==="matched"));
    check("explicit missing file times out normally",explicitOnly.exitCode===2);

    // A pre-existing same-nonce line must not be mistaken for a fresh result.
    const profile4=path.join(root,"case4");
    const historyDrive=path.join(profile4,"OneDriveA");
    fs.mkdirSync(path.dirname(logFile(historyDrive)),{recursive:true});
    fs.writeFileSync(logFile(historyDrive),"LPB_PROBE|"+nonce+"|1700000002\n","utf8");
    const env4={...process.env,USERPROFILE:profile4,OneDrive:historyDrive,
      OneDriveConsumer:"",OneDriveCommercial:path.join(profile4,"OneDriveB")};
    const oldLog=await runChild(env4,()=>{},[],"1000");
    check("pre-existing marker is ignored at initial EOF baseline",
      !oldLog.events.some(e=>e.event==="matched"));
    check("pre-existing marker expires without false success",oldLog.exitCode===2);

    // Explicit candidates replace all default Windows location guesses.
    const profile5=path.join(root,"case5");
    const same=logFile(path.join(profile5,"OneDriveA"));
    const customCandidates=[same,logFile(path.join(profile5,"OneDriveB"))];
    const customEnv={...process.env,USERPROFILE:profile5,LUAPAD_LOG_CANDIDATES:customCandidates.join(path.delimiter)};
    check("explicit candidate environment fully replaces known folders",
      JSON.stringify(defaultLogPaths(customEnv,profile5))===JSON.stringify(customCandidates));
    check("custom candidate case-insensitive dedup preserves first path",
      JSON.stringify(defaultLogPaths({...customEnv,LUAPAD_LOG_CANDIDATES:[same,same.toUpperCase()].join(path.delimiter)},profile5))===JSON.stringify([same]));
    check("relative override candidate rejected",
      (()=>{try{defaultLogPaths({...customEnv,LUAPAD_LOG_CANDIDATES:"relative/Log.txt"},profile5);return false;}catch(_){return true;}})());
    check("non-Log.txt override candidate rejected",
      (()=>{try{defaultLogPaths({...customEnv,LUAPAD_LOG_CANDIDATES:path.join(profile5,"Wrong.txt")},profile5);return false;}catch(_){return true;}})());
    check("more than eight override candidates rejected",
      (()=>{try{defaultLogPaths({...customEnv,LUAPAD_LOG_CANDIDATES:Array(9).fill(same).join(path.delimiter)},profile5);return false;}catch(_){return true;}})());
    const sameCreated=await runChild({...customEnv,LUAPAD_LOG_CANDIDATES:same},()=>{
      fs.mkdirSync(path.dirname(same),{recursive:true});
      fs.writeFileSync(same,"LPB_PROBE|"+nonce+"|1700000003.125\n","utf8");
    });
    check("initial custom candidate path chosen",
      sameCreated.events.find(e=>e.event==="started")?.path===same);
    check("newly created initial file marker is not lost",
      sameCreated.exitCode===0&&sameCreated.events.some(e=>e.event==="matched"&&e.nonce===nonce));

    const profile6=path.join(root,"case6");
    const customA=logFile(path.join(profile6,"OneDriveA"));
    const customB=logFile(path.join(profile6,"OneDriveB"));
    const env6={...process.env,LUAPAD_LOG_CANDIDATES:[customA,customB].join(path.delimiter)};
    const customOther=await runChild(env6,()=>{
      fs.mkdirSync(path.dirname(customB),{recursive:true});
      fs.writeFileSync(customB,"confidential chat\nLPB_PROBE|"+nonce+"|1700000004.125\n","utf8");
    });
    check("custom default baseline starts at first absent candidate",
      customOther.events.find(e=>e.event==="started")?.path===customA);
    check("custom late alternate is selected and marker matched",
      customOther.exitCode===0&&customOther.events.some(e=>e.event==="log_path_selected"&&e.path===customB)&&
      customOther.events.some(e=>e.event==="matched"&&e.nonce===nonce));
    check("custom candidate never leaks adjacent log text",
      !JSON.stringify(customOther.events).includes("confidential chat"));
    // Invalid custom-list configuration cannot override an explicit --path.
    const ignoredBad=await runChild({...env6,LUAPAD_LOG_CANDIDATES:"not/absolute"},()=>{},
      ["--path",path.join(profile6,"manual","Log.txt")],"1000");
    check("invalid candidate override ignored under explicit --path",
      ignoredBad.exitCode===2&&ignoredBad.events.some(e=>e.event==="started")&&!ignoredBad.stderr.trim());

    console.log(JSON.stringify({schemaVersion:1,ok:true,assertions,syntheticOnly:true,
      component:"LuaPadModern log path discovery",gameTouched:false}));
  }finally{fs.rmSync(root,{recursive:true,force:true});}
}
main().catch(error=>{console.error(error);process.exitCode=1;});
