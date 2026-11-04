"use strict";
const assert=require("node:assert/strict");
const fs=require("node:fs");
const os=require("node:os");
const path=require("node:path");
const {LogTailProbe,validateNonce,luaProbe,parseArgs}=require("./rift-log-probe.cjs");

const tmp=fs.mkdtempSync(path.join(os.tmpdir(),"luapad-log-probe-test-"));
let passed=0;
const check=(fn)=>{fn();passed++;};
const nonce="LPB_TEST_20261104";
const second=Math.round(Date.now()/1000);
const line="game prefix LPB_PROBE|"+nonce+"|"+second+".250 chat suffix\n";
const filename=n=>path.join(tmp,n+".txt");
try {
  check(()=>assert.equal(validateNonce(nonce),nonce));
  check(()=>assert.throws(()=>validateNonce(""),/nonce/));
  check(()=>assert.throws(()=>validateNonce("bad;print(secret)"),/nonce/));
  check(()=>assert.throws(()=>validateNonce("a".repeat(81)),/nonce/));
  check(()=>assert.match(luaProbe(nonce),/Command\.Console\.Display/));
  check(()=>assert.match(luaProbe(nonce),/Inspect\.Time\.Server/));
  check(()=>assert.deepEqual(parseArgs(["--path","test","--from-start"]),{"path":"test","from-start":true}));
  check(()=>assert.throws(()=>parseArgs(["--wat"]),/Unknown option/));

  const f1=filename("skip-existing");
  fs.writeFileSync(f1,line,"utf8");
  const w1=new LogTailProbe({filePath:f1,nonce});
  check(()=>assert.equal(w1.poll().some(e=>e.event==="matched"),false));
  check(()=>assert.equal(w1.match,null));
  fs.appendFileSync(f1,"unrelated player chat with confidential example\n");
  check(()=>assert.equal(w1.poll().some(e=>e.event==="matched"),false));
  check(()=>assert.ok(w1.appendedBytes>0));
  const prefix="LPB_PROBE|"+nonce+"|";
  fs.appendFileSync(f1,prefix,"utf8");
  check(()=>assert.equal(w1.poll().some(e=>e.event==="matched"),false));
  fs.appendFileSync(f1,second+".125\n","utf8");
  const events=w1.poll();
  check(()=>assert.equal(events.some(e=>e.event==="matched"),true));
  check(()=>assert.equal(w1.match.nonce,nonce));
  check(()=>assert.equal(w1.match.isTrueFlushLatency,false));
  check(()=>assert.equal(typeof w1.match.serverClockDeltaMs,"number"));
  check(()=>assert.equal(JSON.stringify(events).includes("confidential"),false));
  check(()=>assert.deepEqual(w1.poll(),[]));
  w1.close();

  const f2=filename("missing-then-created");
  const w2=new LogTailProbe({filePath:f2,nonce});
  check(()=>assert.deepEqual(w2.poll(),[]));
  fs.writeFileSync(f2,line,"utf8");
  const made=w2.poll();
  check(()=>assert.equal(made.some(e=>e.event==="file_opened"),true));
  check(()=>assert.equal(made.some(e=>e.event==="matched"),true));
  w2.close();

  const f3=filename("truncate");
  fs.writeFileSync(f3,"X".repeat(400)+"\n","utf8");
  const w3=new LogTailProbe({filePath:f3,nonce});
  w3.poll();
  fs.writeFileSync(f3,line,"utf8");
  const reset=w3.poll();
  check(()=>assert.equal(reset.some(e=>e.event==="file_reset"&&e.reason==="truncated"),true));
  check(()=>assert.equal(reset.some(e=>e.event==="matched"),true));
  w3.close();

  const f4=filename("utf16");
  fs.writeFileSync(f4,Buffer.from("\ufeffStarting log\n","utf16le"));
  const w4=new LogTailProbe({filePath:f4,nonce});
  const opened=w4.poll();
  check(()=>assert.equal(opened.some(e=>e.encoding==="utf16le"),true));
  fs.appendFileSync(f4,Buffer.from(line,"utf16le"));
  check(()=>assert.equal(w4.poll().some(e=>e.event==="matched"),true));
  w4.close();

  const f5=filename("from-start");
  fs.writeFileSync(f5,line,"utf8");
  const w5=new LogTailProbe({filePath:f5,nonce,fromStart:true});
  check(()=>assert.equal(w5.poll().some(e=>e.event==="matched"),true));
  w5.close();

  const f6=filename("bounded-chat");
  fs.writeFileSync(f6,"previous\n","utf8");
  const w6=new LogTailProbe({filePath:f6,nonce,maxLineChars:1024});
  w6.poll();
  fs.appendFileSync(f6,"A".repeat(90000)+"\n"+line,"utf8");
  const latest=w6.poll();
  check(()=>assert.equal(latest.some(e=>e.event==="matched"),true));
  check(()=>assert.ok(w6.oversizedLineCount>0));
  check(()=>assert.equal(JSON.stringify(latest).includes("A".repeat(200)),false));
  w6.close();

  const f7=filename("server-clock-unknown");
  fs.writeFileSync(f7,"old\n","utf8");
  const w7=new LogTailProbe({filePath:f7,nonce});
  w7.poll();
  fs.appendFileSync(f7,"LPB_PROBE|"+nonce+"|unknown\n","utf8");
  check(()=>assert.equal(w7.poll().some(e=>e.event==="matched"),true));
  check(()=>assert.equal(w7.match.serverClockDeltaMs,null));
  w7.close();

  console.log(JSON.stringify({schemaVersion:1,ok:true,passed,
    component:"LuaPadModern Log.txt read-only probe",gameTouched:false}));
}finally{
  fs.rmSync(tmp,{recursive:true,force:true});
}
