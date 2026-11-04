"use strict";

// Synthetic-only read-only candidate verification. No game or real AddOns writes.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const {spawnSync} = require("node:child_process");
const project = path.resolve(__dirname, "..");
const script = path.join(__dirname, "verify-preview20-candidate.cjs");
const sourceNames = ["main.lua", "RiftAddon.toc"];
const temp = fs.mkdtempSync(path.join(os.tmpdir(), "luapad-preview20-check-"));
let passed = 0;
function check(name, value) {
  assert.equal(value, true, name);
  passed++;
}
function invoke(args) {
  return spawnSync(process.execPath, [script, ...args], {
    cwd:project,encoding:"utf8",windowsHide:true,shell:false,timeout:15000
  });
}
function inspect(output) { return JSON.parse(output.stdout); }
try {
  const help = invoke(["--help"]);
  check("help exits cleanly", help.status === 0 && help.stdout.includes("Read-only"));
  const bad = invoke(["--installed-dir", "relative-folder"]);
  check("rejects relative installed path", bad.status === 1);
  const installed = path.join(temp, "luapad");
  fs.mkdirSync(installed);
  for (const name of sourceNames)
    fs.copyFileSync(path.join(project,name), path.join(installed,name));
  const exact = invoke(["--installed-dir", installed]);
  const matched = inspect(exact);
  check("exact candidate exits zero", exact.status === 0);
  check("both installed files match source", matched.files.length === 2 &&
    matched.files.every(file => file.matches));
  check("checks preview20 author and centered startup", matched.sourcePreview20Ready === true);
  check("does not claim live runtime acceptance", matched.actualRiftRuntimeVerified === false &&
    matched.gameTouched === false);
  fs.appendFileSync(path.join(installed, "main.lua"), "\n-- synthetic local drift\n");
  const drift = invoke(["--installed-dir", installed]);
  check("drift exits nonzero and identifies file", drift.status === 2 &&
    inspect(drift).files.some(file => file.name === "main.lua" && !file.matches));
  fs.copyFileSync(path.join(project,"main.lua"), path.join(installed,"main.lua"));
  fs.unlinkSync(path.join(installed, "RiftAddon.toc"));
  const missing = invoke(["--installed-dir", installed]);
  check("missing installed file has distinct status", missing.status === 3 &&
    inspect(missing).status === "installed_missing");
  console.log(JSON.stringify({schemaVersion:1,ok:true,passed,
    component:"LuaPadModern Preview20 candidate check",syntheticOnly:true,gameTouched:false}));
} finally {
  fs.rmSync(temp, {recursive:true,force:true});
}
