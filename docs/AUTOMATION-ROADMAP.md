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
| M2 Addon bridge | Pure Lua serializer, command router, API discovery, compile-only probes | Physical RIFT produces matching structured result | In progress: isolated codec 36/36; no live bridge |
| M3 Windows host | C# .NET10 background host, WPF shell, target validation, clipboard route | Host request/result verified with RIFT; no coordinate drift | Not started |
| M4 Workbridge MCP | Typed LuaPad tools, output schemas, receipts, bounded timeouts | MCP tool -> RIFT -> structured result proven | Not started |
| M5 Telemetry | Snapshots, event buffers, opt-in RR2 read-only source with provenance | Freshness and performance measured | Not started |
| M6 UX | In-game tabs, search, history, professional Windows GUI, UIA IDs | Mouse/keyboard/UIA and screenshot acceptance | Not started |
| M7 Hardening | Reload/restart recovery, multi-client identity, Unicode, fault handling | Repeated physical and regression proof; documented rollback | Not started |

## Ten acceptance scenarios

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

## M1 tasks

- [x] Inspect Preview17 and current Git baseline.
- [x] Create docs/ and contracts/.
- [x] Write v1 JSON envelope schema, request/result/error examples, smoke checker.
- [x] Contract smoke: 3 valid fixtures and 11 negative cases; AJV Draft 2020-12: 3 valid fixtures.
- [x] Existing Preview17 checks: 56/56 structural and 128/128 Lua/Inspector runtime assertions.
- [x] Finalize and commit reviewed M1 contract/design files (2026-11-04).

## M2 first coding slice

- [x] Isolated Lua 5.1 JSON codec and correlated result envelopes (`Bridge/codec.lua`), not loaded in RIFT.
- [x] 36 headless assertions for UTF-8, escaping, errors, bounds and request ID echo; see [M2 codec checkpoint](M2-CODEC-CHECKPOINT-2026-11-04.md).
- [ ] Isolated command router, read-only health/status handler and replay/error semantics.
- [ ] Confirm RIFT slash dispatch callback signature in the physical game.
- [ ] Only then backup/hotcopy, and physically test after separately authorized reload.

## Parallel development lanes after contract freeze

A: In-game Lua/Inspector/router. B: .NET 10 Windows host and UIA. C: Workbridge typed MCP adapter. D: QA, real RIFT acceptance and GUI review. Assign exclusive file ownership to concurrent workers.

## Unresolved evidence questions

- Does RIFT Live provide a reliable addon-to-host route superior to clipboard?
- Which data should come from RIFT Inspect versus separately sourced RR2?
- What payload sizes and sampling rates remain responsive in-game?
- Should Windows dashboard and background host share one process or split after measurement?

Do not equate planned interfaces with working live integrations.
