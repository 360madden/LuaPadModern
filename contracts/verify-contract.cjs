// Contract smoke tests (no external dependencies). NOT a complete JSON Schema engine.
// Future host and MCP adapters must validate against bridge-envelope-v1.schema.json.
"use strict";
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const root = __dirname;
const schema = JSON.parse(fs.readFileSync(path.join(root, "bridge-envelope-v1.schema.json"), "utf8"));
const fixture = (name) => JSON.parse(fs.readFileSync(path.join(root, name), "utf8"));
const request = fixture("bridge-request.v1.json");
const result = fixture("bridge-result.v1.json");
const failure = fixture("bridge-error.v1.json");
function valid(x) {
  if (!x || typeof x !== "object" || Array.isArray(x)) return false;
  if (x.protocol !== "luapad-bridge" || x.version !== 1) return false;
  if (!["request", "result", "event"].includes(x.kind)) return false;
  if (typeof x.requestId !== "string" || !/^[A-Za-z0-9][A-Za-z0-9._-]{7,79}$/.test(x.requestId)) return false;
  if (typeof x.sessionId !== "string" || x.sessionId.length < 8 || x.sessionId.length > 96) return false;
  if (typeof x.operation !== "string" || x.operation.length > 64 || !/^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)*$/.test(x.operation)) return false;
  if (!x.source || !["addon", "host", "workbridge"].includes(x.source.component)) return false;
  if (!x.payload || typeof x.payload !== "object" || Array.isArray(x.payload)) return false;
  const keys = Object.keys(schema.properties);
  if (Object.keys(x).some((k) => !keys.includes(k))) return false;
  if (x.kind === "request") return !("status" in x) && !("error" in x);
  if (!["ok", "error", "partial"].includes(x.status)) return false;
  if (!x.meta || typeof x.meta.truncated !== "boolean") return false;
  if (x.meta.evidenceSha256 !== undefined && !/^[0-9a-f]{64}$/.test(x.meta.evidenceSha256)) return false;
  if (x.meta.sourceAgeMs !== undefined && (!Number.isInteger(x.meta.sourceAgeMs) || x.meta.sourceAgeMs < 0)) return false;
  if (x.status === "error") return !!x.error && /^[A-Z][A-Z0-9_]{2,63}$/.test(x.error.code) && typeof x.error.message === "string" && x.error.message.length > 0;
  return !("error" in x);
}
assert.equal(schema.$schema, "https://json-schema.org/draft/2020-12/schema");
assert.equal(schema.$id, "urn:luapadmodern:bridge-envelope:1");
for (const sample of [request, result, failure]) assert.equal(valid(sample), true);
function reject(label, base, edit) {
  const candidate = structuredClone(base);
  edit(candidate);
  assert.equal(valid(candidate), false, label);
}
reject("wrong version", request, (x) => { x.version = 2; });
reject("short request id", request, (x) => { x.requestId = "id"; });
reject("request cannot carry status", request, (x) => { x.status = "ok"; });
reject("unknown operation format", request, (x) => { x.operation = "API Inspect"; });
reject("unknown field", request, (x) => { x.unexpected = true; });
reject("missing result status", result, (x) => { delete x.status; });
reject("missing meta", result, (x) => { delete x.meta; });
reject("error without details", failure, (x) => { delete x.error; });
reject("success with error", result, (x) => { x.error = {code:"BAD_STATE",message:"bad"}; });
reject("invalid evidence hash", result, (x) => { x.meta.evidenceSha256 = "xyz"; });
reject("negative age", result, (x) => { x.meta.sourceAgeMs = -1; });
assert.deepEqual(result.requestId, request.requestId);
assert.deepEqual(result.sessionId, request.sessionId);
assert.deepEqual(result.operation, request.operation);
process.stdout.write("PASS LuaPadModern bridge v1: 3 fixtures and 11 negative contract cases\n");
