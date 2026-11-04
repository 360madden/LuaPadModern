// Strict Windows/MCP-friendly LuaPadModern headless test gate.
// Fengari can print a failing Lua traceback while npm reports exit code zero,
// so assert both its summary sentinel and absence of failure output.
"use strict";
const path = require("node:path");
const fs = require("node:fs");
const {spawnSync} = require("node:child_process");
const npmCli = path.join(path.dirname(process.execPath), "node_modules", "npm", "bin", "npm-cli.js");
if (!fs.existsSync(npmCli)) {
  throw new Error("Windows Node.js installation does not expose npm-cli.js at " + npmCli);
}
const suites = [
  ["bridge-codec-tests.lua", 39, "Bridge v1 codec checks: 39 passed"],
  ["ui-status-tests.lua", 40, "Read-only UI focus/layer checks: 40 passed"],
  ["bridge-router-tests.lua", 70, "Bridge v1 router checks: 70 passed"],
  ["bridge-slash-tests.lua", 165, "Source-only slash transport checks: 165 passed"],
  ["inspector-runtime-tests.lua", 141, "LuaPad plus Inspector runtime mock: 141 assertions passed"]
];
let ok = true;
const receipts = [];
for (const [file, assertions, expected] of suites) {
  const runner = spawnSync(process.execPath,
    [npmCli, "exec", "--yes", "--package=fengari-node-cli", "--", "fengari", file],
    {cwd:__dirname, encoding:"utf8", windowsHide:true, shell:false,
      timeout:60000, maxBuffer:2 * 1024 * 1024});
  const output = String(runner.stdout || "") + "\n" + String(runner.stderr || "");
  const success = !runner.error && runner.status === 0
    && output.includes(expected)
    && !/(^|\n)FAIL\b|stack traceback:/.test(output);
  receipts.push({file, assertions, passed:success});
  console.log((success ? "PASS " : "FAIL ") + file + " (" + assertions + " assertions)");
  if (!success) {
    ok = false;
    console.error("Runner status: " + String(runner.status) +
      ", error: " + String(runner.error || "none"));
    console.error(output.slice(-3500));
  }
}
const receipt = {schemaVersion:1,ok,suites:receipts};
console.log(JSON.stringify(receipt));
if (!ok) process.exitCode = 1;
