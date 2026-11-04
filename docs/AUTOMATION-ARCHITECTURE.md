# LuaPadModern automation architecture

Status: Architecture and contract draft, 2026-11-04. This document describes a target system, not already-implemented live capabilities.

## Mission

A polished RIFT Lua development environment, optimized for human developers and AI/Workbridge automation. LuaPad stays useful without the Windows host. Workbridge remains the MCP coordinator instead of being replaced.

## Verified foundation

- RIFT LuaPad v2.0.0-preview17: editor Enter/Tab and ASCII selection physically verified.
- Addon already has editor/Run, Inspector, snippets, output, native clipboard copy, slash commands, startup notices.
- Workbridge reads/writes the Windows Git repo and runs developer commands; Windows desktop window discovery/screenshot tools exist.
- RIFT API documentation lists Inspect, Command, events and saved-variable hooks, but a general Lua network listener/arbitrary file streaming is not established. Treat such transport as unproven.
- WinApp UI Automation should target the planned native Windows dashboard. Custom-drawn RIFT controls may require pinned HWND, screenshots, guarded mouse/keys.

## Components and ownership

1. **RIFT LuaPad addon (Lua 5.1):** API exploration, script execution, bounded serialization, event sampling, output and in-game GUI. It does not host MCP.
2. **Windows Automation Host (planned C#/.NET 10 + WPF):** exact RIFT identity, request/session/queue state, clipboard transfer, timeout/recovery, evidence, timestamping and dashboard/tray operation.
3. **Workbridge (existing):** MCP typed tools, AI job receipts and cross-repository orchestration. Add a narrow LuaPad host adapter, not a competing Workbridge.
4. **Optional RR2 read-only telemetry:** an explicitly identified alternative source only where addon API delivery is insufficient. Never silently misattribute it.

## Data/control flow

Request: AI/MCP -> Workbridge -> Windows Host -> exact verified game window -> short, versioned LuaPad command.

Result: LuaPad API/Run -> structured envelope -> verified game-to-host transport (M2 pilot: clipboard through existing Copy Output) -> host validates IDs and timestamps -> MCP structured result.

High-frequency streaming requires separate proof; clipboard is a starting route for deliberate queries, not a proven high-frequency telemetry channel.

## Bridge v1 contract

Source of truth: ../contracts/bridge-envelope-v1.schema.json and examples beside it.

- protocol = luapad-bridge; version = 1; kind = request, result or event.
- operation uses stable lowercase dotted text; payload is an object.
- Host generates requestId and sessionId; addon echoes them unchanged.
- Requests have no status/error. Results/events have status (ok, error, partial) and meta.truncated.
- Error includes machine-readable code and human-readable message.
- Initial error taxonomy: INVALID_ARGUMENTS, UNSUPPORTED_OPERATION, UNSUPPORTED_VERSION, TARGET_UNAVAILABLE, TARGET_CHANGED, GAME_NOT_READY, LUA_COMPILE_ERROR, LUA_RUNTIME_ERROR, RESULT_MISMATCH, TRANSPORT_TIMEOUT, CLIPBOARD_CHANGED, OUTPUT_TRUNCATED, INTERNAL_ERROR.
- Windows host adds receipt time, transport, evidence hash and source-age metadata; these are not in-game measurements.
- Check exact response requestId/sessionId/operation; reject stale, ambiguous or incomplete results.
- Do not automatically repeat an uncertain non-idempotent Lua execution.
- Preserve UTF-8 and size limits. No silent partial JSON parsing.
- Envelope is transport-independent; the future Workbridge adapter exposes MCP-compatible typed tools.

## Proposed operations

| Operation | Owner | Notes |
| --- | --- | --- |
| health | addon + host | readiness/version |
| api.search | addon | API catalog discovery |
| api.inspect | addon | expression evaluation can invoke an API |
| lua.validate | addon | compile only |
| lua.execute | addon | run code; no blind retries |
| telemetry.snapshot | addon or separately attributed RR2 | bounded, source-tagged |
| events.read | addon | buffered events |
| output.read | addon/host | read execution output |
| ui.capture | host | screenshot and PID/HWND evidence |

No tool is advertised as live-capable before physical acceptance.

## Windows user experience

WPF desktop dashboard: connection status, searchable API browser, script history, event/telemetry panes, job queue, diagnostics, stable UI Automation IDs, optional minimized/tray operation. No console flashes at boot. In-game LuaPad remains a well-designed draggable editor with no distracting floating buttons.

## Reliability

States: queued -> target-verified -> dispatched -> awaiting-result -> validated, or terminal rejected/timeout/unknown.

- Pin exact PID/HWND/process start and verify game readiness before input.
- Re-measure after resize, minimize or reload.
- Preserve clipboard contents when practical, but only restore if user/another process has not changed it.
- Record request ID, target, outcome, elapsed time, and evidence; bound diagnostics.
- Keep code tests, simulated widget tests, host tests and physical RIFT tests distinct.
- Never imply a physical pass from mock tests or source-copy receipts.
- Game focus, UI reload and installed-addon update are distinct operations.

## M1 scope

M1 creates schemas, examples, smoke tests and architecture docs. It does not touch RIFT main.lua, TOC, installed AddOns, or gameplay.

## Primary references

- Historical RIFT addon API: https://www.seebs.net/rift/pts/index.html
- MCP typed tools/structured results: https://modelcontextprotocol.io/specification/2025-11-25/server/tools
- Microsoft WinApp UI Automation: https://learn.microsoft.com/windows/apps/dev-tools/winapp-cli/ui-automation
