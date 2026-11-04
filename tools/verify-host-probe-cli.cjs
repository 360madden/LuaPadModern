"use strict";

// Synthetic, offline Windows/.NET CLI acceptance. It never starts or contacts RIFT.
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const assert = require("node:assert/strict");
const {spawn, spawnSync} = require("node:child_process");

const root = path.resolve(__dirname, "..");
const project = path.join(root, "HostProbe", "LuaPadModern.HostProbe.csproj");
const dll = path.join(root, "HostProbe", "bin", "Release", "net10.0", "LuaPadModern.HostProbe.dll");
const dotnet = process.platform === "win32" ? "dotnet.exe" : "dotnet";
const nonce = "LPB_HOSTCLI_20261104_CASE";
let assertions = 0;
function check(description, condition) {
  assert.equal(condition, true, description);
  assertions++;
}

const build = spawnSync(dotnet, ["build", project, "--configuration", "Release", "--nologo"],
  {cwd: root, encoding: "utf8", windowsHide: true, timeout: 120000,
   maxBuffer: 2 * 1024 * 1024, shell: false});
if (build.error || build.status !== 0) {
  console.error((build.stdout || "") + "\n" + (build.stderr || ""));
  throw new Error("HostProbe .NET build failed");
}
check("host CLI compiled", fs.existsSync(dll));

function command(args) {
  return spawnSync(dotnet, ["exec", dll, ...args],
    {cwd: root, encoding: "utf8", windowsHide: true, timeout: 15000,
     maxBuffer: 512 * 1024, shell: false});
}
const help = command(["--help"]);
check("help returns zero", help.status === 0 && help.stdout.includes("read-only RIFT"));
const lua = command(["--nonce", nonce, "--print-lua"]);
check("inert Lua snippet printed", lua.status === 0 && lua.stdout.includes("LPB_PROBE|"));
check("Lua snippet correlates expected nonce", lua.stdout.includes(nonce));
const invalid = command(["--poll-ms", "25"]);
check("missing nonce rejected", invalid.status === 1);
const invalidNonce = command(["--nonce", "bad!", "--print-lua"]);
check("invalid nonce rejected", invalidNonce.status === 1);
const absent = path.join(os.tmpdir(), "LuaPadModern-never-created-" + process.pid + "-" + Date.now() + ".txt");
check("timeout fixture is absent", !fs.existsSync(absent));
const timed = command(["--nonce", nonce, "--path", absent,
  "--timeout-ms", "1000", "--poll-ms", "25"]);
check("absent log expires without pretending to match",
  timed.status === 2 && timed.stdout.includes('"event":"timeout"'));

async function main() {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), "LuaPadModern-hostcli-"));
  const logFile = path.join(folder, "Log.txt");
  try {
    const child = spawn(dotnet,
      ["exec", dll, "--nonce", nonce, "--path", logFile,
       "--timeout-ms", "10000", "--poll-ms", "25"],
      {cwd: root, windowsHide: true, shell: false, stdio: ["ignore", "pipe", "pipe"]});
    let stdout = "";
    let stderr = "";
    let buffered = "";
    let started = false;
    let match = null;
    const events = [];
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stderr.on("data", chunk => { stderr += chunk; });
    child.stdout.on("data", chunk => {
      stdout += chunk;
      buffered += chunk;
      let end;
      while ((end = buffered.indexOf("\n")) !== -1) {
        const line = buffered.slice(0, end).trim();
        buffered = buffered.slice(end + 1);
        if (!line) continue;
        const event = JSON.parse(line);
        events.push(event.event);
        if (event.event === "started" && !started) {
          started = true;
          fs.writeFileSync(logFile,
            "UNRELATED PRIVATE CHAT SHOULD NEVER APPEAR\nLPB_PROBE|" + nonce + "|1700000000.",
            "utf8");
          setTimeout(() => fs.appendFileSync(logFile, "250\n", "utf8"), 100);
        }
        if (event.event === "matched") match = event;
      }
    });
    const exit = await new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        child.kill();
        reject(new Error("Timed out waiting for synthetic host CLI"));
      }, 15000);
      child.on("error", error => { clearTimeout(timer); reject(error); });
      child.on("close", code => { clearTimeout(timer); resolve(code); });
    });
    check("host CLI exits zero on match", exit === 0);
    check("host CLI recognized new file", events.includes("started") && started);
    check("host CLI matched exact nonce", match && match.nonce === nonce);
    check("host CLI parsed timestamp", match && match.serverEpochSeconds === 1700000000.25);
    check("host CLI does not mislabel latency", match && match.isTrueFlushLatency === false);
    check("host CLI emitted no other game chat", !stdout.includes("UNRELATED PRIVATE CHAT"));
    check("host CLI stderr clean", stderr.trim().length === 0);
    console.log(JSON.stringify({schemaVersion:1,component:"LuaPadModern.HostProbe",
      ok:true,assertions,syntheticOnly:true,gameTouched:false}));
  } finally {
    fs.rmSync(folder, {recursive:true,force:true});
  }
}
main().catch(error => {
  console.error("HostProbe CLI synthetic smoke FAILED: " + String(error));
  process.exitCode = 1;
});
