# LuaPadModern automation roadmap

Planning baseline: 2026-11-04. Milestone status requires evidence, not merely new source files.

## Priorities

**P1 NOW:** LuaPad must auto-open centered and remain above overlapping addons without `/lp`. Preview 18 auto-open physically PASSED but stacking FAILED in user screenshot. **Joey reported Preview 19 stacking fixed in running RIFT** (no new screenshot); Preview 20 adds centered `UIParent` anchoring and Joey Delfierro title/TOC attribution. **463/463 source/mock bridge checks and guarded Preview 20 AddOns hot-copy passed; live Preview 20 position/title await Joey's authorized `/reloadui` or normal launch.** Do not take game focus or reload without separate permission. See [Preview 20 checkpoint](PREVIEW20-CENTER-AUTHOR-AND-BRIDGE-RESEARCH-2026-11-04.md).

After P1 physical acceptance, resume the prior plan: P0 deterministic AI request/result contract and target binding; P1 event snapshots, telemetry provenance and developer dashboard; P2 performance-tuned streaming/editor features.

## Milestones

| Stage | Deliverables | Exit gate | Status |
| --- | --- | --- | --- |
| M0 Baseline | Preserve Preview17 verified editor behavior and rollback; Preview20 centered startup/title | Physical auto-open/stacking screenshot, centering, Enter/Tab regression | Preview19 stacking user-reported pass; Preview20 guarded installed and mock-verified; live center/title pending |
| M1 Contract | Versioned schema, request IDs, statuses/errors, fixtures, tests, architecture | Contract checks and old tests green; Git commit | Complete (contract-only; not live) |
| M2 Addon bridge | Pure Lua serializer, command router, bounded slash adapter, API discovery, compile-only probes | Physical RIFT produces matching structured result | In progress: 463/463 source/mock assertions; slash registration and live bridge pending; `/log` outbound pilot proposed |
| M3 Windows host | C# .NET10 background host, WPF shell, target validation, clipboard route | Host request/result verified with RIFT; no coordinate drift | In progress: 82/82 pure managed host-core tests; no live host/Win32 link |
| M4 Workbridge MCP | Typed LuaPad tools, output schemas, receipts, bounded timeouts | MCP tool -> RIFT -> structured result proven | Not started |
| M5 Telemetry | Snapshots, event buffers, opt-in RR2 read-only source with provenance | Freshness and performance measured | Not started |
| M6 UX | In-game tabs, search, history, professional Windows GUI, UIA IDs | Mouse/keyboard/UIA and screenshot acceptance | Not started |
| M7 Hardening | Reload/restart recovery, multi-client identity, Unicode, fault handling | Repeated physical and regression proof; documented rollback | Not started |

## Twelve acceptance scenarios

1. Unique RIFT PID/HWND/process-start binding; stale/ambiguous targets rejected.
2. Request/result IDs and sessions match, with source/transport and status.
3. Compile failure distinguished from runtime failure.
4. Stale clipboard data rejected instead of labeled fresh.
5. Resize triggers remeasurement, never an old-coordinate click.
6. Uncertain Lua execution is not replayed without reconciliation.
7. Telemetry records source, age and unavailable fields honestly.
8. Source/mock/bridge/physical tests have separate pass indicators.
9. Windows GUI provides stable UIA control names; in-game custom UI has guarded fallback.
10. No unnoticed game restart, reload or addon install during read-only actions.
11. Preview20 auto-opens centered without /lp, is in front of real competing overlays, and /lp can re-raise it; record layer/strata and physical screenshot. Preview19 overlap is currently a user report, not independently recaptured.
12. In-game RiftTextfield key focus is checked independently from Windows HWND foreground before any automated typing.

## M1 tasks

- [x] Inspect Preview17 and current Git baseline.
- [x] Create docs/ and contracts/.
- [x] Write v1 JSON envelope schema, request/result/error examples, smoke checker.
- [x] Contract smoke: 3 valid fixtures and 11 negative cases; AJV Draft 2020-12: 3 valid fixtures.
- [x] Existing Preview17 checks: 56/56 structural and 128/128 Lua/Inspector runtime assertions.
- [x] Finalize and commit reviewed M1 contract/design files (2026-11-04).

## M2 first coding slice

- [x] Isolated Lua 5.1 JSON codec and correlated result envelopes (`Bridge/codec.lua`), not loaded in RIFT.
- [x] 39 headless assertions for UTF-8, escaping, errors, bounds, request ID echo and honest transport attribution; see [initial M2 codec checkpoint](M2-CODEC-CHECKPOINT-2026-11-04.md).
- [x] Isolated read-only router with health, bridge.capabilities, ui.status, request-ID replay and deterministic error responses.
- [x] Mock RIFT context/window/editor getters: 40/40 status assertions and 70/70 router assertions. No focus/stacking setters called.
- [x] Strict no-shell Node test gate: 39 codec + 40 status + 70 router + 165 slash adapter + 149 LuaPad/Inspector runtime = 463/463, with JSON receipt; see [M2 router/focus checkpoint](M2-ROUTER-FOCUS-CHECKPOINT-2026-11-04.md).
- [x] Source-only bounded `/lpb v1 health|caps|status` parser and injected clipboard adapter, with 165 fail-closed tests; see [M2 slash transport pilot](M2-SLASH-TRANSPORT-PILOT-2026-11-04.md). Not registered in RIFT.
- [x] Implement Windows read-only `Log.txt` watcher and 32/32 synthetic tests (fresh-tail, creation, split writes, truncation, encoding and privacy). Usual physical RIFT log paths absent at read-only check; physical `/log` + LuaPad Run probe pending. See [no-reload pilot](M2-LOG-TAIL-NO-RELOAD-PILOT-2026-11-04.md).
- [ ] Confirm a LuaPad `Command.Console.Display` marker actually enters RIFT noncombat `Log.txt` and measure observed freshness without any addon reload; do not equate combat-log half-second flush with noncombat behavior.
- [ ] Confirm RIFT slash dispatch callback signature in the physical game.
- [ ] Only then backup/hotcopy, and physically test after separately authorized reload.

## M3 Windows host source-only slice

- [x] Confirm local .NET SDK 10.0.302 available.
- [x] Implement pure managed correlated JSON/clipboard freshness verifier with duplicate-key/size checks.
- [x] Implement read-only exact PID/HWND/start-time and fresh-geometry/focus/occlusion readiness gates.
- [x] Strict `node verify-host.cjs`: 82/82 host-core tests; [checkpoint](M3-HOST-CORE-CHECKPOINT-2026-11-04.md).
- [ ] Implement actual Windows process/HWND observer, foreground-aware input dispatch, clipboard sampler/receipts, recovery.
- [ ] WPF desktop/tray shell with stable UI Automation IDs, then physically validate with RIFT.

## Cross-cutting UI focus gate

- [x] Document source-backed focus/z-order gap in [UI focus and automation gate](UI-FOCUS-AUTOMATION-GATE-2026-11-04.md).
- [x] Implement isolated read-only ui.status snapshot; not yet bound to live RIFT frames and cannot verify actual occlusion.
- [x] Preview18: bounded context dialog strata/layer raise on auto-open, first-frame check and `/lp` recovery (128 → 141 mock assertions). Physical screenshot proved auto-open pass but stacking fail.
- [x] Preview19: switch to supported topmost strata, inspect bounded peer child layers, raise LuaPad's window above installed addon 999990–999995 layers, and extend mock coverage (141 → 146). Guarded hot-copy passed; Joey subsequently reported physical overlap corrected.
- [x] Preview20: center the RIFT window within `UIParent`, add `Joey Delfierro` author credit and 3 runtime tests (149); guarded AddOns copy passed. Live new title/centering still pending.
- [ ] Explicit editor-focus operation and live overlap acceptance; preserve keyboard focus on startup.
- [ ] Windows host rejects input if foreground, z-order or editor focus evidence is unverified.

## Parallel development lanes after contract freeze

A: In-game Lua/Inspector/router. B: .NET 10 Windows host and UIA. C: Workbridge typed MCP adapter. D: QA, real RIFT acceptance and GUI review. Assign exclusive file ownership to concurrent workers.

## Unresolved evidence questions

- Can opt-in `Command.Console.Display` output reach `/log` -> RIFT `Log.txt` with bounded latency and usable format? A read-only 32-case Windows watcher is now built, but the physical `Log.txt` was not present at the usual paths. Historical Python tools tail it; LuaPad Run's intercepted `print` must not be assumed to reach the file.
- Do RIFT's server-backed addon messages/storage have any safe use for cross-client collaboration beyond clipboard and SavedVariables? These do **not** directly connect to Workbridge.
- Which data should come from RIFT Inspect versus separately sourced RR2?
- What payload sizes and sampling rates remain responsive in-game?
- Should Windows dashboard and background host share one process or split after measurement?

Do not equate planned interfaces with working live integrations.
