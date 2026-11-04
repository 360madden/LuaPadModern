# M2 checkpoint — isolated Lua bridge codec

Date: 2026-11-04. Development-only module; RIFT addon deployment has NOT changed.

## Files

- Bridge/codec.lua: pure Lua 5.1 codec and correlated result envelope builder.
- bridge-codec-tests.lua: headless runtime assertions executed with Fengari.

## Verified implementation

- Deterministic JSON key ordering, string/control escapes, Unicode UTF-8 preservation.
- JSON objects/contiguous arrays, booleans, numbers, null.
- Explicit failures for invalid UTF-8, non-finite numbers, unsupported value/key types, sparse/mixed arrays, cycles, excessive depth/nodes/bytes.
- Host-owned requestId, sessionId and operation echoed into result; fixed component=addon source.
- Successful/error/partial status encoding with optional addon version, bounded error messages and truncation flag.
- Bound output options: maxBytes default 16 KiB (max 64 KiB), maxDepth default 12 (max 32), maxNodes default 2048 (max 10000).

## Test receipt

- Fengari bridge-codec-tests.lua: 36/36 assertions passed (M2 first slice).
- Preview17 structural 56/56 and combined LuaPad/Inspector mock 128/128 passed during M1.
- JSON Schema Draft 2020-12: 3 example envelopes accepted by AJV during M1.
- No claim that the newly generated live result has been tested inside RIFT, nor that a Windows/MCP transport exists yet.

## Intentional exclusions

- Bridge/codec.lua is not referenced by RiftAddon.toc or main.lua. It causes no runtime behavior changes.
- No slash router yet; command callback/argument behavior must be proven against actual RIFT Live.
- No JSON decoder yet; decide minimal inbound transport from measured command/input constraints.
- No high-frequency telemetry, native network transport, or filesystem write assumed.
- JSON encoder only accepts JSON-shaped tables. Arbitrary Inspect tables containing function/table keys must be explicitly normalized before serialization.
- An empty Lua table is represented as an empty JSON object (not an array). Use a supported explicit list wrapper later if empty array distinction is required.

## Next gate: command router

1. Add isolated router with only built-in health/capabilities handlers, no script execution by default.
2. Verify request ID/session preservation and replay behavior with mock tests.
3. Test RIFT slash-command callback signature and minimal human-visible status path.
4. After backup, version bump and exact-file hotcopy, request a separately authorized in-game UI reload and capture live proof.
5. Only then expose the command through the Windows host and Workbridge tools.
