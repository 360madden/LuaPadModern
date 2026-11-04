"use strict";

// Read-only source/installed candidate comparison for LuaPad Preview 20.
// This cannot prove which Lua code the running RIFT process has loaded.
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const crypto = require("node:crypto");

const projectRoot = path.resolve(__dirname, "..");
const expectedFiles = ["main.lua", "RiftAddon.toc"];
const maxFileBytes = 2 * 1024 * 1024;

function installedCandidates() {
  const home = process.env.USERPROFILE || os.homedir();
  const documentRoots = [
    process.env.OneDrive && path.join(process.env.OneDrive, "Documents"),
    path.join(home, "OneDrive", "Documents"),
    path.join(home, "Documents")
  ].filter(Boolean);
  return [...new Set(documentRoots.map(root => path.resolve(root)))].map(root =>
    path.join(root, "RIFT", "Interface", "AddOns", "luapad"));
}

function parseArgs(args) {
  let installedDir = null;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--help" && args.length === 1) return {help:true};
    if (args[i] !== "--installed-dir" || installedDir !== null || i + 1 >= args.length)
      throw new Error("Usage: node tools/verify-preview20-candidate.cjs [--installed-dir ABSOLUTE_DIR]");
    installedDir = args[++i];
    if (!path.isAbsolute(installedDir))
      throw new Error("--installed-dir must be an absolute path");
  }
  return {installedDir};
}

function sha256(file) {
  const info = fs.statSync(file);
  if (!info.isFile() || info.size > maxFileBytes)
    throw new Error("Refusing non-file or oversized candidate");
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

function checkCandidate(installedDir) {
  const known = installedCandidates();
  const directory = installedDir ||
    known.find(candidate => fs.existsSync(candidate)) || known[0];
  const sourceMain = fs.readFileSync(path.join(projectRoot, "main.lua"), "utf8");
  const toc = fs.readFileSync(path.join(projectRoot, "RiftAddon.toc"), "utf8");
  const sourceReady = /Version\s*=\s*"2\.0\.0-preview20"/.test(toc) &&
    /Author\s*=\s*"Joey Delfierro \(360madden\)/.test(toc) &&
    sourceMain.includes('luaPadWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)') &&
    sourceMain.includes('" | by Joey Delfierro"') &&
    sourceMain.includes('startupStep("show", showLuaPad)');
  const files = expectedFiles.map(name => {
    const source = path.join(projectRoot, name);
    const installed = path.join(directory, name);
    const sourceHash = sha256(source);
    let installedHash = null;
    try {
      installedHash = sha256(installed);
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
    return {name,sourceSha256:sourceHash,installedSha256:installedHash,
      matches:sourceHash === installedHash};
  });
  const installedPresent = files.every(file => file.installedSha256 !== null);
  const allMatch = files.every(file => file.matches);
  return {
    schemaVersion:1,
    component:"LuaPadModern.Preview20Candidate",
    installedDirectory:directory,
    sourcePreview20Ready:sourceReady,
    files,
    status:!sourceReady ? "source_invalid" :
      !installedPresent ? "installed_missing" : allMatch ? "candidate_matches" : "candidate_differs",
    actualRiftRuntimeVerified:false,
    gameTouched:false
  };
}

function main() {
  try {
    const options = parseArgs(process.argv.slice(2));
    if (options.help) {
      console.log("node tools/verify-preview20-candidate.cjs [--installed-dir ABSOLUTE_DIR]");
      console.log("Read-only. Checks deployed files only; not a running RIFT UI acceptance.");
      return;
    }
    const result = checkCandidate(options.installedDir);
    console.log(JSON.stringify(result));
    process.exitCode = result.status === "candidate_matches" ? 0 :
      result.status === "installed_missing" ? 3 : 2;
  } catch (error) {
    console.error("Preview 20 candidate check failed: " + error.message);
    process.exitCode = 1;
  }
}
if (require.main === module) main();
module.exports = {installedCandidates,parseArgs,checkCandidate};
