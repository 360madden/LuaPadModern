"use strict";
// Actual two-process Windows file-append latency smoke (synthetic, NOT RIFT).
const assert=require("node:assert/strict");
const fs=require("node:fs");
const os=require("node:os");
const path=require("node:path");
const {spawn}=require("node:child_process");

async function main() {
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),"lpb-cli-integration-"));
  const filePath=path.join(dir,"Log.txt");
  const nonce="LPB_PROCESS_TEST_20261104";
  const marker="LPB_PROBE|"+nonce+"|"+Math.round(Date.now()/1000)+".250\n";
  const child=spawn(process.execPath,[
    path.join(__dirname,"rift-log-probe.cjs"),
    "--path",filePath,"--nonce",nonce,
    "--timeout-ms","4500","--poll-ms","25"
  ],{stdio:["ignore","pipe","pipe"],windowsHide:true});
  let stdout="",stderr="";
  let createAtMs=0;
  let appends=0;
  let stop=false;
  let didStart=false;
  const received=[];
  const maybeStart=()=>{
    if(didStart || !stdout.includes('"event":"waiting_for_file"'))return;
    didStart=true;
    setTimeout(()=>{
      if(stop)return;
      fs.writeFileSync(filePath,"RIFT prefix "+marker.slice(0,marker.length-2),"utf8");
      createAtMs=Date.now();
      appends++;
      setTimeout(()=>{
        if(stop)return;
        fs.appendFileSync(filePath,marker.slice(marker.length-2),"utf8");
        appends++;
      },55);
    },80);
  };
  child.stdout.on("data",data=>{
    stdout+=data.toString("utf8");
    if(stdout.length>40000)stdout=stdout.slice(-40000);
    maybeStart();
  });
  child.stderr.on("data",data=>{
    stderr+=data.toString("utf8");
    if(stderr.length>4000)stderr=stderr.slice(-4000);
  });
  let timeoutId;
  try {
    const exit=await Promise.race([
      new Promise((resolve,reject)=>{
        child.on("error",reject);
        child.on("close",(code,signal)=>resolve({code,signal}));
      }),
      new Promise((_,reject)=>{timeoutId=setTimeout(()=>reject(new Error("Probe child hung")),6000);})
    ]);
    stop=true;
    assert.equal(exit.code,0,"probe child failed: "+stderr+"\n"+stdout);
    assert.equal(appends,2,"fixture was not appended twice");
    for(const line of stdout.split(/\r?\n/)) {
      if(!line.startsWith("{"))continue;
      try {received.push(JSON.parse(line));}catch(_){}
    }
    const hit=received.find(x=>x.event==="matched");
    assert.ok(hit,"marker was not observed: "+stdout);
    const observedMs=Date.parse(hit.observedAt);
    assert.ok(Number.isFinite(observedMs));
    const observedDelayMs=observedMs-createAtMs;
    assert.ok(observedDelayMs>=0 && observedDelayMs<3000,
      "unexpected local file-tail delay "+observedDelayMs);
    assert.ok(!stdout.includes("RIFT prefix"),"unrelated log text was printed");
    console.log(JSON.stringify({schemaVersion:1,ok:true,
      source:"synthetic multi-process appended file, NOT physical RIFT",
      pollMs:25,appends,observedDelayMs,markerDetected:true}));
  }finally {
    if(timeoutId)clearTimeout(timeoutId);
    if(!stop)child.kill();
    fs.rmSync(dir,{recursive:true,force:true});
  }
}
main().catch(err=>{console.error(err.stack||String(err));process.exitCode=1});
