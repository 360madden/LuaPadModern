// Strict source-only .NET 10 host-core regression gate; no RIFT interaction.
"use strict";
const path = require("node:path");
const {spawnSync} = require("node:child_process");
const dotnet = process.platform === "win32" ? "dotnet.exe" : "dotnet";
const run = spawnSync(dotnet,
  ["run", "--project", "HostCore.Tests/LuaPadModern.HostCore.Tests.csproj",
    "--configuration", "Release"],
  {cwd:__dirname,encoding:"utf8",shell:false,windowsHide:true,
    timeout:90000,maxBuffer:2*1024*1024});
const output=String(run.stdout||"")+"\n"+String(run.stderr||"");
const ok=!run.error && run.status===0 &&
  output.includes("HostCore source-only checks: 113 passed") &&
  !/(^|\n)FAIL\b|Unhandled exception|error CS\d+|stack traceback:/.test(output);
console.log(JSON.stringify({
  schemaVersion:1,component:"LuaPadModern.HostCore",sourceOnly:true,
  assertions:113,ok
}));
if (!ok) {
  console.error("Host source-only gate failed; process="+String(run.status)+
    " error="+String(run.error||"none"));
  console.error(output.slice(-4000));
  process.exitCode=1;
}
