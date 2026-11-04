# M2 checkpoint — read-only router and UI-focus evidence
Date: 2026-11-04. Status: source-only, no changes to active RIFT addon or installed AddOns.

## Scope completed

- Bridge/codec.lua: deterministic Lua 5.1 JSON and structured-result encoder. The encoder no longer preemptively claims clipboard transport before an actual delivery route is selected.
- Bridge/router.lua: bounded allowlist of health, bridge.capabilities and ui.status. All other operations, including lua.execute, return UNSUPPORTED_OPERATION.
- Bridge/ui_status.lua: read-only snapshot from RIFT context, window and editor getters. Reports visibility, independent strata/layers, editor key focus, bounds and field availability. Does not call setters or claim occlusion proof.
- bridge-codec-tests.lua, bridge-router-tests.lua, ui-status-tests.lua: pure Lua 5.1-compatible mocks.
- verify-bridge.cjs: Windows Node runner with fixed known tests, bounded child jobs, no shell launch, pass-summary validation and machine-readable JSON receipt. Rejects Fengari output containing FAIL/stack traceback even when the child exits with code zero.
- docs/UI-FOCUS-AUTOMATION-GATE-2026-11-04.md: source diagnosis and physical acceptance matrix.

## Results verified on the configured Windows host

Command: node.exe verify-bridge.cjs (working directory C:\work\LuaPadModern)

| Suite | Assertions | Result |
| --- | ---: | --- |
| Bridge codec | 39 | PASS |
| Read-only UI probe | 40 | PASS |
| Router request/replay/errors | 70 | PASS |
| Existing LuaPad/Inspector runtime | 128 | PASS |
| **Total** | **277** | **PASS** |

Other checks:
- node.exe verify-preview.cjs: 56 structural checks passed (source-only).
- node.exe contracts/verify-contract.cjs: 3 valid fixtures and 11 negative cases passed.
- Previous M1 AJV Draft 2020-12 validation of all 3 fixtures remains documented; it was not repeated for this checkpoint.
- A test failed during development due to an incorrect journal-eviction assumption; the test was corrected and passed. This incident motivated the strict exit/sentinel gate.

## Read-only operations, as implemented in source

| Operation | What it returns | Conditions |
| --- | --- | --- |
| health | routerReady, bridgeVersion, addonVersion, liveTransportReady | Router table loaded; transportReady is false unless deliberately configured |
| bridge.capabilities | supported operation names, read-only mode, transport readiness | No game frames required |
| ui.status | RIFT-observed window/context layers, strata, bounds, visibility, editor focus, availability | UI frame references must be bound; returns GAME_NOT_READY otherwise |

- Each valid request must carry protocol/version/kind, host-owned requestId and sessionId, source and an object payload. Unknown fields and unsupported operations are rejected.
- Per-session requestId replay returns the recorded JSON result without re-reading UI state; a same-ID/different-request conflict returns DUPLICATE_REQUEST_CONFLICT.
- Journal bounded to 64 recent requests by default; request JSON max 8 KiB, result max 16 KiB by default. Excess results become bounded OUTPUT_TRUNCATED error JSON.
- Request/result IDs, source attribution and error codes are deterministic. No automatic script execution and no blind retries of uncertain operations.

## Known limitations and safety gates

- Modules are not referenced by RiftAddon.toc or main.lua and have not run in physical RIFT.
- The router accepts Lua request tables but has no inbound JSON parser or slash-command adapter. Host-to-game transport remains unproven.
- No RIFT Lua client code changes, hotcopy, /reloadui, mouse clicks or foreground changes were made in this checkpoint.
- ui.status does not tell whether another addon physically covers LuaPad. The Windows host needs verified HWND and screenshot evidence.
- Default /lp opens the LuaPad window but does not guarantee context/window promotion or editor key focus. See the separate focus gate; actual precedence with other addons requires live measurement.
- The RIFT patch-era docs are evidence of API definitions, not proof of the current client's exact semantics.

## Next milestones

1. Confirm live RIFT slash callback signature and discover context strata/layer methods using a small read-only probe.
2. Design a bounded text command syntax with host-generated request IDs; decide how JSON request payloads enter RIFT given Lua 5.1 sandbox constraints.
3. Integrate modules in a new addon preview, after verifying TOC ordering and rollback backup. Keep all other addons and SavedVariables intact.
4. Test physical /lp stacking versus other addons and native dialogs; verify GetKeyFocus and keyboard behavior, measured across window moves/resizes.
5. Implement a Windows host readiness gate and then expose Workbridge typed health/status tools. Do not advertise live until full round-trip request/response is observed.

No physical UI acceptance is claimed by this source checkpoint.
