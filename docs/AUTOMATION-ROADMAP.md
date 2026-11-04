# LuaPadModern automation roadmap

Planning baseline: 2026-11-04. Milestone status requires evidence, not merely new source files.

## Priorities

**P1 NOW (blocking user priority):** LuaPad opens on RIFT startup without `/lp` and stays above overlapping addons. Preview 18 auto-open/context strata/bounded layer/first-frame fallback and mock coverage are implemented; guarded two-file AddOns hot-copy passed with rollback backups; **an authorized reload and physical acceptance are the next gate**. Do not take game focus or run `/reloadui` without separate permission. See [P1 checkpoint](P1-STARTUP-VISIBILITY-STACKING-PREVIEW18-2026-11-04.md).

After P1 physical acceptance, resume the prior plan: P0 deterministic AI request/result contract and target binding; P1 event snapshots, telemetry provenance and developer dashboard; P2 performance-tuned streaming/editor features.

## Milestones

| Stage | Deliverables | Exit gate | Status |
| --- | --- | --- | --- |
| M0 Baseline | Preserve physically verified Preview17 and backups; prepare Preview18 P1 | Physical auto-open/stacking screenshot, Enter/Tab regression, rollback | Preview18 source/mock and guarded AddOns copy passed; live reload/acceptance pending |
| M1 Contract | Versioned schema, request IDs, statuses/errors, fixtures, tests, architecture | Contract checks and old tests green; Git commit | Complete (contract-only; not live) |
| M2 Addon bridge | Pure Lua serializer, command router, bounded slash adapter, API discovery, compile-only probes | Physical RIFT produces matching structured result | In progress: 455/455 source/mock assertions; slash registration and live bridge pending |
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
11. Preview18 auto-opens without /lp; /lp re-raises the context after another addon/dialog changes its position; record layer/strata and physical screenshot.
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
- [x] Strict no-shell Node test gate: 39 codec + 40 status + 70 router + 165 slash adapter + 141 LuaPad/Inspector runtime = 455/455, with JSON receipt; see [M2 router/focus checkpoint](M2-ROUTER-FOCUS-CHECKPOINT-2026-11-04.md).
- [x] Source-only bounded `/lpb v1 health|caps|status` parser and injected clipboard adapter, with 165 fail-closed tests; see [M2 slash transport pilot](M2-SLASH-TRANSPORT-PILOT-2026-11-04.md). Not registered in RIFT.
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
- [x] Implement bounded context strata/layer raise on auto-open, single first-frame check and `/lp` recovery; 13 new runtime cases (128 → 141). Source-only; live overlap acceptance still pending.
- [ ] Explicit editor-focus operation and live overlap acceptance; preserve keyboard focus on startup.
- [ ] Windows host rejects input if foreground, z-order or editor focus evidence is unverified.

## Parallel development lanes after contract freeze

A: In-game Lua/Inspector/router. B: .NET 10 Windows host and UIA. C: Workbridge typed MCP adapter. D: QA, real RIFT acceptance and GUI review. Assign exclusive file ownership to concurrent workers.

## Unresolved evidence questions

- Does RIFT Live provide a reliable addon-to-host route superior to clipboard?
- Which data should come from RIFT Inspect versus separately sourced RR2?
- What payload sizes and sampling rates remain responsive in-game?
- Should Windows dashboard and background host share one process or split after measurement?

Do not equate planned interfaces with working live integrations.
