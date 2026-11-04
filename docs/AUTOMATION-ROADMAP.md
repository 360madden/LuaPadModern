# LuaPadModern automation roadmap

Planning baseline: 2026-11-04. Milestone status requires evidence, not merely new source files.

## Priorities

P0: deterministic AI request/result contract, exact target binding, on-demand API probes, reliable communication.
P1: event snapshots, telemetry provenance, polished developer dashboard, recoverable jobs.
P2: performance-tuned live streaming, advanced editor and debugging integrations.

## Milestones

| Stage | Deliverables | Exit gate | Status |
| --- | --- | --- | --- |
| M0 Baseline | Preserve Preview17 and backups | Verified physical Enter/Tab; Git clean; rollback | Mostly complete; some editor edge cases |
| M1 Contract | Versioned schema, request IDs, statuses/errors, fixtures, tests, architecture | Contract checks and old tests green; Git commit | Complete (contract-only; not live) |
| M2 Addon bridge | Pure Lua serializer, command router, bounded slash adapter, API discovery, compile-only probes | Physical RIFT produces matching structured result | In progress: 442/442 source/mock assertions; slash registration and live bridge pending |
| M3 Windows host | C# .NET10 background host, WPF shell, target validation, clipboard route | Host request/result verified with RIFT; no coordinate drift | Not started |
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
11. /lp can bring LuaPad forward without permanently obscuring other UI, with context strata/layer recorded.
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
- [x] Strict no-shell Node test gate: 39 codec + 40 status + 70 router + 165 slash adapter + 128 existing runtime = 442/442, with JSON receipt; see [M2 router/focus checkpoint](M2-ROUTER-FOCUS-CHECKPOINT-2026-11-04.md).
- [x] Source-only bounded `/lpb v1 health|caps|status` parser and injected clipboard adapter, with 165 fail-closed tests; see [M2 slash transport pilot](M2-SLASH-TRANSPORT-PILOT-2026-11-04.md). Not registered in RIFT.
- [ ] Confirm RIFT slash dispatch callback signature in the physical game.
- [ ] Only then backup/hotcopy, and physically test after separately authorized reload.

## Cross-cutting UI focus gate

- [x] Document source-backed focus/z-order gap in [UI focus and automation gate](UI-FOCUS-AUTOMATION-GATE-2026-11-04.md).
- [x] Implement isolated read-only ui.status snapshot; not yet bound to live RIFT frames and cannot verify actual occlusion.
- [ ] Design bounded raise-on-open action, independently controlled editor focus, and live overlap acceptance.
- [ ] Windows host rejects input if foreground, z-order or editor focus evidence is unverified.

## Parallel development lanes after contract freeze

A: In-game Lua/Inspector/router. B: .NET 10 Windows host and UIA. C: Workbridge typed MCP adapter. D: QA, real RIFT acceptance and GUI review. Assign exclusive file ownership to concurrent workers.

## Unresolved evidence questions

- Does RIFT Live provide a reliable addon-to-host route superior to clipboard?
- Which data should come from RIFT Inspect versus separately sourced RR2?
- What payload sizes and sampling rates remain responsive in-game?
- Should Windows dashboard and background host share one process or split after measurement?

Do not equate planned interfaces with working live integrations.
