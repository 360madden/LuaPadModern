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

  // A transient read failure must not turn already-appended bytes into
  // 'history' when the stream is reopened at the next poll.
  const f8=filename("recover-read-error");
  fs.writeFileSync(f8,"history\n","utf8");
  const w8=new LogTailProbe({filePath:f8,nonce});
  w8.poll();
  fs.appendFileSync(f8,line,"utf8");
  const originalRead=fs.readSync;
  let readFailure;
  try {
    fs.readSync=function(fd,...args) {
      if(fd===w8.fileHandle) { const e=new Error("test EACCES");e.code="EACCES";throw e; }
      return originalRead.call(fs,fd,...args);
    };
    readFailure=w8.poll();
  } finally { fs.readSync=originalRead; }
  check(()=>assert.equal(readFailure.some(e=>e.event==="read_error"&&e.code==="EACCES"),true));
  check(()=>assert.equal(w8.poll().some(e=>e.event==="matched"),true));
  w8.close();

  // The same recovery is needed when the initial file open fails.
  const f9=filename("recover-open-error");
  fs.writeFileSync(f9,"history\n","utf8");
  const w9=new LogTailProbe({filePath:f9,nonce});
  const originalOpen=fs.openSync;
  let openFailure;
  try {
    fs.openSync=function(filePath,...args) {
      if(filePath===f9) { const e=new Error("test EACCES");e.code="EACCES";throw e; }
      return originalOpen.call(fs,filePath,...args);
    };
    openFailure=w9.poll();
  } finally { fs.openSync=originalOpen; }
  fs.appendFileSync(f9,line,"utf8");
  check(()=>assert.equal(openFailure.some(e=>e.event==="read_error"&&e.code==="EACCES"),true));
  check(()=>assert.equal(w9.poll().some(e=>e.event==="matched"),true));
  w9.close();

  // A newly created UTF-16 log may expose the BOM one byte at a time.
  const f10=filename("utf16-split-bom");
  fs.writeFileSync(f10,Buffer.from([0xff]));
  const w10=new LogTailProbe({filePath:f10,nonce});
  const partialBom=w10.poll();
  check(()=>assert.equal(partialBom.some(e=>e.event==="file_opened"&&e.encoding===null),true));
  fs.appendFileSync(f10,Buffer.concat([Buffer.from([0xfe]),Buffer.from(line,"utf16le")]));
  check(()=>assert.equal(w10.poll().some(e=>e.event==="matched"),true));
  w10.close();

  // A transient read error during BOM sniffing must be surfaced and retried.
  const f11=filename("utf16-header-read-error");
  fs.writeFileSync(f11,Buffer.concat([Buffer.from([0xff,0xfe]),Buffer.from(line,"utf16le")]));
  const w11=new LogTailProbe({filePath:f11,nonce,fromStart:true});
  const originalHeaderRead=fs.readSync;
  let headerFailure;
  let failHeader=true;
  try {
    fs.readSync=function(fd,...args) {
      if(failHeader&&fd===w11.fileHandle) {
        failHeader=false;
        const e=new Error("test BOM EACCES");e.code="EACCES";throw e;
      }
      return originalHeaderRead.call(fs,fd,...args);
    };
    headerFailure=w11.poll();
  } finally { fs.readSync=originalHeaderRead; }
  check(()=>assert.equal(headerFailure.some(e=>e.event==="read_error"&&e.code==="EACCES"),true));
  check(()=>assert.equal(w11.poll().some(e=>e.event==="matched"),true));
  w11.close();

  console.log(JSON.stringify({schemaVersion:1,ok:true,passed,
    component:"LuaPadModern Log.txt read-only probe",gameTouched:false}));
}finally{
  fs.rmSync(tmp,{recursive:true,force:true});
}
