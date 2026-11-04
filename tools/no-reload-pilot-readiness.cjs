"use strict";

// Single-shot, read-only preparation for Joey's manual no-reload RIFT log pilot.
// This process only stats/opens the selected path. It never reads chat lines,
// launches a watcher, sends game input, changes /log, or reloads LuaPad.
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const {validateNonce, luaProbe, defaultLogPath} = require("./rift-log-probe.cjs");

function parseArgs(argv) {
  const result = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--help") { result.help = true; continue; }
    if (arg !== "--path" && arg !== "--nonce")
      throw new Error("Unknown option: " + arg);
    if (!argv[i + 1] || argv[i + 1].startsWith("--"))
      throw new Error("Missing value for " + arg);
    if (result[arg.slice(2)] !== undefined)
      throw new Error("Duplicate option: " + arg);
    result[arg.slice(2)] = argv[++i];
  }
  return result;
}

function probePath(filePath) {
  try {
    const info = fs.statSync(filePath);
    if (!info.isFile()) return {status:"NOT_A_FILE"};
    const handle = fs.openSync(filePath, "r");
    try {
      return {
        status:"LOG_READABLE",
        sizeBytes:info.size,
        modifiedAtUtc:info.mtime.toISOString()
      };
    } finally {
      fs.closeSync(handle);
    }
  } catch (error) {
    if (error.code === "ENOENT") return {status:"LOG_MISSING"};
    return {status:"LOG_ACCESS_ERROR",code:String(error.code || "UNKNOWN")};
  }
}

function runCli(argv) {
  let options;
  try {
    options = parseArgs(argv);
    if (options.help) {
      console.log("node tools/no-reload-pilot-readiness.cjs [--path ABSOLUTE_LOG_TXT] [--nonce TOKEN]");
      console.log("Read-only one-shot preflight. Does not activate /log or run a watcher.");
      return 0;
    }
    const filePath = options.path || defaultLogPath();
    if (!path.isAbsolute(filePath))
      throw new Error("Log path must be absolute.");
    const nonce = validateNonce(options.nonce || "LPB" + crypto.randomBytes(12).toString("hex"));
    const observation = probePath(filePath);
    console.log(JSON.stringify({
      schemaVersion:1,
      event:"no_reload_preflight",
      at:new Date().toISOString(),
      path:filePath,
      nonce,
      ...observation,
      gameTouched:false,
      watcherStarted:false,
      loggingEnabled:"unknown",
      transportVerified:false,
      flushLatencyMs:null,
      nextManualSteps:[
        "When convenient, verify whether /log is already enabled; do not toggle blindly.",
        "Start the read-only watcher with the exact executable/arguments below.",
        "Paste the printed Lua snippet into the existing LuaPad editor and press Run.",
        "An exact watcher match is necessary, not sufficient: confirm the RIFT log path and correlate with a manual in-game send."
      ],
      watchCommand:{
        executable:process.platform === "win32" ? "node.exe" : "node",
        args:["tools/rift-log-probe.cjs","--path",filePath,"--nonce",nonce,"--timeout-ms","120000"]
      }
    }));
    console.log("LUA_PROBE_START\n" + luaProbe(nonce) + "\nLUA_PROBE_END");
    return 0;
  } catch (error) {
    console.error("Read-only preflight setup failed: " + error.message);
    return 1;
  }
}

if (require.main === module) process.exitCode = runCli(process.argv.slice(2));
module.exports = {parseArgs, probePath, runCli};
