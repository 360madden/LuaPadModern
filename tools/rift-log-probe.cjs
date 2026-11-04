"use strict";

// Read-only RIFT noncombat log probe. Never writes to RIFT files, sends game
// input, or prints other chat lines. No third-party Node dependencies.
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const crypto = require("node:crypto");
const {StringDecoder} = require("node:string_decoder");

const PREFIX = "LPB_PROBE|";
const MAX_BYTES_PER_POLL = 256 * 1024;
const MAX_LINE_CHARS = 8192;
const DEFAULT_POLL_MS = 100;
const DEFAULT_TIMEOUT_MS = 120000;

function validateNonce(value) {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{8,80}$/.test(value))
    throw new Error("Probe nonce must be 8-80 ASCII letters/digits/_/-.");
  return value;
}
function newNonce() { return "LPB" + crypto.randomBytes(10).toString("hex"); }

function defaultLogPaths(env=process.env,home=env.USERPROFILE||os.homedir()) {
  // Exact, bounded candidate paths; no user-directory scan or shell invocation.
  // Opt-in replacement candidates support custom folders and hermetic tests.
  const raw=env.LUAPAD_LOG_CANDIDATES;
  if(typeof raw==="string" && raw.length>0) {
    if(raw.length>8192) throw new Error("LUAPAD_LOG_CANDIDATES too long");
    const names=raw.split(path.delimiter).map(s=>s.trim());
    if(names.length<1 || names.length>8 || names.some(s=>
      !s || s.length>2048 || !path.isAbsolute(s) ||
      path.basename(s).toLowerCase()!=="log.txt"))
      throw new Error("LUAPAD_LOG_CANDIDATES requires 1-8 absolute Log.txt paths");
    const seen=new Set();
    return names.filter(name=>{
      const key=path.normalize(name).toLowerCase();
      if(seen.has(key))return false;
      seen.add(key);
      return true;
    });
  }
  const roots=[env.OneDrive,env.OneDriveConsumer,env.OneDriveCommercial,
    path.join(home,"OneDrive"),home];
  const paths=[];
  const seen=new Set();
  for(const root of roots) {
    if(typeof root!=="string" || !root.trim() || !path.isAbsolute(root))continue;
    const candidate=path.join(root,"Documents","RIFT","Log.txt");
    const key=path.normalize(candidate).toLowerCase();
    if(!seen.has(key)){seen.add(key);paths.push(candidate);}
  }
  return paths;
}
function defaultLogPath(env=process.env,home=env.USERPROFILE||os.homedir()) {
  const candidates=defaultLogPaths(env,home);
  return candidates.find(candidate=>fs.existsSync(candidate)) ||
    candidates.find(candidate=>fs.existsSync(path.dirname(candidate))) || candidates[0];
}

function luaProbe(nonce) {
  validateNonce(nonce);
  return [
    'local token = "' + nonce + '"',
    'local epoch = "unknown"',
    'if Inspect and Inspect.Time and type(Inspect.Time.Server) == "function" then',
    '  local good, seconds = pcall(Inspect.Time.Server)',
    '  if good and type(seconds) == "number" then',
    '    epoch = string.format("%.3f", seconds)',
    '  end',
    'end',
    'local msg = "LPB_PROBE|" .. token .. "|" .. epoch',
    'local ok, err = pcall(Command.Console.Display, "general", false, msg, false)',
    'print(ok and ("Sent probe: " .. token) or ("Probe error: " .. tostring(err)))'
  ].join("\n");
}

function statKey(s) {
  return String(s.dev) + ":" + String(s.ino);
}
function detectEncoding(fd) {
  const header = Buffer.alloc(2);
  const got = fs.readSync(fd, header, 0, 2, 0);
  // A one-byte UTF-16 BOM is ambiguous; wait for the complete header.
  if (got < 2) return null;
  if (header[0] === 0xff && header[1] === 0xfe) return "utf16le";
  if (header[0] !== 0 && header[1] === 0) return "utf16le";
  return "utf8";
}

class LogTailProbe {
  constructor(options) {
    this.filePath = path.resolve(options.filePath);
    this.nonce = validateNonce(options.nonce);
    this.fromStart = !!options.fromStart;
    this.maxLineChars = Math.max(128, options.maxLineChars || MAX_LINE_CHARS);
    this.opened = false;
    this.fileKey = null;
    this.fileHandle = null;
    this.offset = 0;
    this.partial = "";
    this.decoder = null;
    this.encoding = null;
    this.match = null;
    this.appendedBytes = 0;
    this.oversizedLineCount = 0;
    this.needReadBeginning = false;
  }
  close() {
    if (this.fileHandle !== null) {
      try { fs.closeSync(this.fileHandle); } catch (_) { }
      this.fileHandle = null;
    }
  }
  resetStream() {
    this.close();
    this.opened = false;
    this.fileKey = null;
    this.offset = 0;
    this.partial = "";
    this.decoder = null;
    this.encoding = null;
  }
  readLine(line, observedAtMs) {
    if (this.match || !line.includes(PREFIX + this.nonce + "|")) return null;
    const start = line.indexOf(PREFIX + this.nonce + "|");
    const value = line.slice(start + PREFIX.length + this.nonce.length + 1);
    const epochMatch = /^([0-9]+(?:\.[0-9]+)?)/.exec(value);
    const epochSeconds = epochMatch ? Number(epochMatch[1]) : null;
    // Server time is a different computer's clock and may be rounded.
    const validEpoch = epochSeconds !== null && Number.isFinite(epochSeconds) &&
      epochSeconds >= 1500000000 && epochSeconds < 4200000000;
    this.match = {
      event:"matched",nonce:this.nonce,
      observedAt:new Date(observedAtMs).toISOString(),
      serverEpochSeconds:validEpoch ? epochSeconds : null,
      serverClockDeltaMs:validEpoch ? Math.round(observedAtMs - epochSeconds * 1000) : null,
      isTrueFlushLatency:false,
      note:"Server clock delta includes server/host clock offset and timestamp rounding; not a precise log flush measurement.",
      totalAppendedBytes:this.appendedBytes
    };
    return this.match;
  }
  acceptText(text, observedAtMs, events) {
    this.partial += text;
    let nl;
    while ((nl = this.partial.indexOf("\n")) !== -1) {
      const line = this.partial.slice(0,nl).replace(/\r$/, "");
      this.partial = this.partial.slice(nl+1);
      const matched = this.readLine(line, observedAtMs);
      if (matched) events.push(matched);
      if (this.match) return;
    }
    if (this.partial.length > this.maxLineChars) {
      this.oversizedLineCount += 1;
      this.partial = this.partial.slice(-this.maxLineChars);
    }
  }
  poll(nowMs=Date.now()) {
    if (this.match) return [];
    const events=[];
    let info;
    try {
      info = fs.statSync(this.filePath);
      if (!info.isFile()) throw new Error("Not a regular file");
    } catch (e) {
      if (e.code && e.code !== "ENOENT") {
        events.push({event:"read_error",code:String(e.code)});
      }
      if (this.opened) {
        this.resetStream();
        events.push({event:"file_disappeared"});
      }
      this.needReadBeginning = true;
      return events;
    }
    const key = statKey(info);
    if (this.opened && (key !== this.fileKey || info.size < this.offset)) {
      const why = key !== this.fileKey ? "replaced" : "truncated";
      this.resetStream();
      this.needReadBeginning = true;
      events.push({event:"file_reset",reason:why});
    }
    if (!this.opened) {
      try {
        this.fileHandle = fs.openSync(this.filePath,"r");
        this.fileKey = key;
        this.encoding = detectEncoding(this.fileHandle);
        this.decoder = this.encoding === null ? null : new StringDecoder(this.encoding);
        // Do not replay an existing chat history. New/replaced files must
        // instead be read from byte zero so their first marker is not missed.
        this.offset = (this.fromStart || this.needReadBeginning || info.size < 2) ? 0 : info.size;
        this.needReadBeginning = false;
        this.opened = true;
        events.push({event:"file_opened",offset:this.offset,encoding:this.encoding,
          size:info.size});
      } catch(e) {
        this.resetStream();
        this.needReadBeginning = true;
        events.push({event:"read_error",code:String(e.code||"OPEN_FAILED")});
        return events;
      }
    }
    if (this.decoder === null) {
      if (info.size < 2) return events;
      try {
        this.encoding = detectEncoding(this.fileHandle);
        if (this.encoding === null) return events;
        this.decoder = new StringDecoder(this.encoding);
      } catch(e) {
        this.resetStream();
        this.needReadBeginning = true;
        events.push({event:"read_error",code:String(e.code||"READ_FAILED")});
        return events;
      }
    }
    if (info.size <= this.offset) return events;
    const data = Buffer.allocUnsafe(Math.min(64*1024,MAX_BYTES_PER_POLL));
    let budget=MAX_BYTES_PER_POLL;
    while (this.offset < info.size && budget > 0 && !this.match) {
      const ask = Math.min(data.length, info.size-this.offset,budget);
      let n;
      try { n = fs.readSync(this.fileHandle,data,0,ask,this.offset); }
      catch(e) {
        events.push({event:"read_error",code:String(e.code||"READ_FAILED")});
        this.resetStream();
        this.needReadBeginning = true;
        return events;
      }
      if (n === 0) break;
      this.offset += n;
      budget -= n;
      this.appendedBytes += n;
      const decoded = this.decoder.write(data.subarray(0,n));
      this.acceptText(decoded,nowMs,events);
    }
    return events;
  }
}

function parseArgs(argv) {
  const opts={};
  for(let i=0;i<argv.length;i++) {
    const arg=argv[i];
    if(arg==="--path" || arg==="--nonce" || arg==="--timeout-ms" || arg==="--poll-ms") {
      if(!argv[i+1]) throw new Error("Missing value for " + arg);
      opts[arg.slice(2)]=argv[++i];
    } else if(arg==="--from-start" || arg==="--print-lua") {
      opts[arg.slice(2)]=true;
    } else if(arg==="--help") {
      opts.help=true;
    } else throw new Error("Unknown option: " + arg);
  }
  return opts;
}
function safeInt(value,def,min,max,name) {
  if(value===undefined) return def;
  const n=Number(value);
  if(!Number.isSafeInteger(n) || n<min || n>max) throw new Error(name+" out of range");
  return n;
}
function runCli() {
  let opts;
  try { opts=parseArgs(process.argv.slice(2)); } catch(e) {
    console.error(e.message);process.exitCode=1;return;
  }
  if(opts.help) {
    console.log("node tools/rift-log-probe.cjs [--path C:\\...\\Log.txt] [--nonce LPB12345678] [--timeout-ms 120000] [--poll-ms 100] [--print-lua] [--from-start]");
    console.log("Read-only. Watches newly appended RIFT log data, never sends game input.");
    console.log("LUAPAD_LOG_CANDIDATES=ABS;ABS replaces defaults (1-8 absolute Log.txt paths). --path overrides.");
    return;
  }
  try {
    const nonce=validateNonce(opts.nonce||newNonce());
    const autoCandidates=opts.path ? [] : defaultLogPaths();
    let filePath=opts.path||defaultLogPath();
    let lookForAlternate=autoCandidates.length>0 && !fs.existsSync(filePath);
    const timeoutMs=safeInt(opts["timeout-ms"],DEFAULT_TIMEOUT_MS,1000,600000,"timeout-ms");
    const pollMs=safeInt(opts["poll-ms"],DEFAULT_POLL_MS,25,1000,"poll-ms");
    const snippet=luaProbe(nonce);
    if(opts["print-lua"]) {console.log(snippet);return;}
    let watcher=new LogTailProbe({filePath,nonce,fromStart:opts["from-start"]});
    const started=Date.now();
    const send=x=>console.log(JSON.stringify(x));
    // Establish the EOF/missing-file baseline before advertising readiness.
    // A sender reacting immediately to "started" must not lose its marker.
    const baselineEvents=watcher.poll();
    send({event:"started",at:new Date(started).toISOString(),
      path:filePath,nonce,pollMs,timeoutMs,logExists:fs.existsSync(filePath),
      message:"Paste the same nonce Lua probe into the already-running LuaPad editor and click Run. Activate /log manually first."});
    console.log("LUA_TEST_START\n"+snippet+"\nLUA_TEST_END");
    let done=false;
    let warnedMissing=false;
    const finish=(status,code)=>{
      if(done)return;done=true;clearInterval(tick);watcher.close();
      send({event:"finished",status,elapsedMs:Date.now()-started,matched:!!watcher.match,
        appendedBytes:watcher.appendedBytes,oversizedLineCount:watcher.oversizedLineCount});
      process.exitCode=code;
    };
    const tick=setInterval(()=>{
      if(Date.now()-started>=timeoutMs){finish("timeout",2);return;}
      // If logging was initially off, select whichever known location first
      // appears. Read its first bytes: the marker may predate this poll.
      if(lookForAlternate && !fs.existsSync(filePath)) {
        const discovered=autoCandidates.find(candidate=>fs.existsSync(candidate));
        if(discovered) {
          const changed=discovered!==filePath;
          watcher.close();
          filePath=discovered;
          // The first marker may be written with the newly created file.
          watcher=new LogTailProbe({filePath,nonce,fromStart:true});
          if(changed) {
            send({event:"log_path_selected",path:filePath,reason:"new_file"});
          }
          lookForAlternate=false;
        }
      }
      if(!watcher.opened && !fs.existsSync(filePath) && !warnedMissing) {
        warnedMissing=true;send({event:"waiting_for_file",path:filePath});
      }
      for(const e of watcher.poll())send(e);
      if(watcher.match)finish("matched",0);
    },pollMs);
    process.on("SIGINT",()=>finish("interrupted",130));
    for(const e of baselineEvents)send(e);
    if(watcher.match)finish("matched",0);
  }catch(e){console.error("Probe setup failed: "+e.message);process.exitCode=1;}
}
if(require.main===module)runCli();
module.exports={LogTailProbe,validateNonce,luaProbe,parseArgs,defaultLogPath,defaultLogPaths};
