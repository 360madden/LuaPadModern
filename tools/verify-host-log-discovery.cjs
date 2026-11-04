"use strict";

// Hermetic .NET HostProbe path-selection tests. Never opens or interacts with RIFT.
const assert=require("node:assert/strict");
const fs=require("node:fs");
const os=require("node:os");
const path=require("node:path");
const {spawn,spawnSync}=require("node:child_process");

const repo=path.resolve(__dirname,"..");
const project=path.join(repo,"HostProbe","LuaPadModern.HostProbe.csproj");
const dll=path.join(repo,"HostProbe","bin","Release","net10.0","LuaPadModern.HostProbe.dll");
const dotnet=process.platform==="win32"?"dotnet.exe":"dotnet";
const nonce="LPB_MANAGED_DISCOVERY_20261104";
const temp=fs.mkdtempSync(path.join(os.tmpdir(),"LuaPadModern-dotnet-discovery-"));
let assertions=0;
function check(label,value){assert.equal(value,true,label);assertions++;}
function cli(extraArgs,env){
  return spawnSync(dotnet,["exec",dll,"--nonce",nonce,...extraArgs],
    {cwd:repo,env,windowsHide:true,shell:false,encoding:"utf8",timeout:15000,maxBuffer:1024*1024});
}
function logFile(name){return path.join(temp,name,"Log.txt");}

async function watch(paths,{explicit,envOverride,onStarted,timeoutMs=1200}={}){
  const env={...process.env,LUAPAD_LOG_CANDIDATES:envOverride??paths.join(path.delimiter)};
  const args=["exec",dll,"--nonce",nonce,"--timeout-ms",String(timeoutMs),"--poll-ms","25"];
  if(explicit)args.push("--path",explicit);
  const child=spawn(dotnet,args,{cwd:repo,env,windowsHide:true,shell:false,
    stdio:["ignore","pipe","pipe"]});
  let stdout="",stderr="",buffer="",hasStarted=false;
  const events=[];
  child.stdout.setEncoding("utf8");
  child.stderr.setEncoding("utf8");
  child.stderr.on("data",chunk=>{stderr+=chunk;});
  child.stdout.on("data",chunk=>{
    stdout+=chunk;buffer+=chunk;
    let index;
    while((index=buffer.indexOf("\n"))!==-1){
      const line=buffer.slice(0,index).trim();buffer=buffer.slice(index+1);
      if(!line.startsWith("{"))continue;
      const event=JSON.parse(line);events.push(event);
      if(event.event==="started"&&!hasStarted){
        hasStarted=true;
        if(onStarted)onStarted(event);
      }
    }
  });
  const code=await new Promise((resolve,reject)=>{
    const guard=setTimeout(()=>{child.kill();reject(new Error("HostProbe child timeout"));},8000);
    child.on("error",error=>{clearTimeout(guard);reject(error);});
    child.on("close",exit=>{clearTimeout(guard);resolve(exit);});
  });
  return {code,events,stdout,stderr};
}

async function main(){
  try{
    const built=spawnSync(dotnet,["build",project,"--configuration","Release","--nologo"],
      {cwd:repo,encoding:"utf8",windowsHide:true,shell:false,timeout:120000,maxBuffer:2*1024*1024});
    if(built.error||built.status!==0){
      throw new Error("HostProbe Release build failed: "+String(built.stderr||built.stdout||built.error));
    }
    check("managed host probe compiles",fs.existsSync(dll));

    const first=logFile("first");
    const alternate=logFile("alternate");
    const picked=await watch([first,alternate],{onStarted:()=>{
      fs.mkdirSync(path.dirname(alternate),{recursive:true});
      fs.writeFileSync(alternate,
        "SECRET_SYNTHETIC_CHAT_DO_NOT_PRINT\nLPB_PROBE|"+nonce+"|1700000000.125\n","utf8");
    }});
    check("managed override replaces default list, first absent path chosen",
      picked.events.find(e=>e.event==="started")?.path===first);
    check("managed host auto-selects newly created alternate path",
      picked.events.some(e=>e.event==="log_path_selected"&&e.path===alternate&&e.reason==="new_file"));
    check("managed alternate matches appended nonce",
      picked.code===0&&picked.events.some(e=>e.event==="matched"&&e.nonce===nonce));
    check("managed host never emits unrelated log text",
      !picked.stdout.includes("SECRET_SYNTHETIC_CHAT"));
    check("managed alternate has no CLI errors",picked.stderr.trim()==="");

    const same=logFile("same");
    const created=await watch([same],{onStarted:()=>{
      fs.mkdirSync(path.dirname(same),{recursive:true});
      fs.writeFileSync(same,"LPB_PROBE|"+nonce+"|1700000001.250\n","utf8");
    }});
    check("managed initial custom path selected",
      created.events.find(e=>e.event==="started")?.path===same);
    check("managed newly-created initial file preserves first marker",
      created.code===0&&created.events.some(e=>e.event==="matched"&&e.nonce===nonce));

    const old=logFile("old-history");
    fs.mkdirSync(path.dirname(old),{recursive:true});
    fs.writeFileSync(old,"LPB_PROBE|"+nonce+"|1700000002.500\n","utf8");
    const suppressed=await watch([old]);
    check("managed baseline ignores same-nonce old history",
      suppressed.code===2&&!suppressed.events.some(e=>e.event==="matched"));
    check("managed old history times out",suppressed.events.some(e=>e.event==="timeout"));

    const manual=logFile("explicit");
    const ignored=logFile("ignored-alternate");
    const explicitResult=await watch([first,ignored],{explicit:manual,
      envOverride:"invalid/relative",onStarted:()=>{
        fs.mkdirSync(path.dirname(ignored),{recursive:true});
        fs.writeFileSync(ignored,"LPB_PROBE|"+nonce+"|1700000003.750\n","utf8");
      }});
    check("managed explicit --path takes precedence over invalid env override",
      explicitResult.events.find(e=>e.event==="started")?.path===manual&&
      explicitResult.stderr.trim()==="");
    check("managed explicit path never switches to another file",
      explicitResult.code===2&&!explicitResult.events.some(e=>e.event==="log_path_selected"||e.event==="matched"));

    const invalidEnv={...process.env,LUAPAD_LOG_CANDIDATES:"relative/Log.txt"};
    const invalid=cli(["--print-lua"],invalidEnv);
    check("managed invalid relative candidate rejected",invalid.status===1);
    const wrongName=cli(["--print-lua"],{...invalidEnv,LUAPAD_LOG_CANDIDATES:logFile("wrong").replace(/Log\.txt$/,"Wrong.txt")});
    check("managed non-Log.txt candidate rejected",wrongName.status===1);
    const excessive=cli(["--print-lua"],{...invalidEnv,
      LUAPAD_LOG_CANDIDATES:Array(9).fill(first).join(path.delimiter)});
    check("managed candidate count bound enforced",excessive.status===1);
    const overrideExplicit=cli(["--path",manual,"--print-lua"],invalidEnv);
    check("managed explicit --path ignores invalid override even for Lua printing",
      overrideExplicit.status===0&&overrideExplicit.stdout.includes(nonce));

    console.log(JSON.stringify({schemaVersion:1,component:"LuaPadModern managed log discovery",
      ok:true,assertions,syntheticOnly:true,gameTouched:false}));
  }finally{fs.rmSync(temp,{recursive:true,force:true});}
}
main().catch(error=>{console.error("Managed discovery test FAILED: "+String(error));process.exitCode=1;});

