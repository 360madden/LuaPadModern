# M3 .NET 10 Windows host core — source-only checkpoint

Date: 2026-11-04. Project: `C:\work\LuaPadModern`.
Status: **source-only foundation**, not a running Windows UI host, not a live clipboard bridge and not an MCP server.

## Scope and evidence

The PC has `.NET SDK 10.0.302`. Created an isolated, dependency-free `net10.0` class library `HostCore/`, a console regression harness `HostCore.Tests/`, and `verify-host.cjs`. Neither the library nor tests import Win32 APIs, inspect a RIFT process, read the actual clipboard, inject input, change foreground focus, install an addon, or call `/reloadui`.

- `BridgeResultValidator.Validate(afterDispatch, beforeDispatch, expected)` checks bounded strict UTF-8 JSON, rejects unchanged clipboard snapshots, ensures exact request/session/operation, `kind=result`, addon source, valid status and error shape, metadata, duplicate keys, unknown envelope fields, and oversized responses (16 KiB).
- `HostReadinessGate.CheckWindow` requires exact PID/process-start/HWND binding, current foreground, non-minimized usable client size, matching planned-vs-immediately-before-input bounds, and fresh ordered observations.
- `HostReadinessGate.CheckEditorInput` additionally requires observed LuaPad visibility, addon-reported editor key focus and separate host screenshot evidence that the editor is not occluded. Nothing asserts occlusion can be inferred from a RIFT addon frame layer.
- The gates return concrete failure codes such as `CLIPBOARD_STALE`, `RESULT_MISMATCH`, `TARGET_CHANGED`, `WINDOW_NOT_FOREGROUND`, `CLIENT_BOUNDS_CHANGED`, `EDITOR_NOT_FOCUSED` and `LUAPAD_OCCLUDED`. They do not attempt to repair focus or reissue uncertain commands.

## Reproducible checks

From `C:\work\LuaPadModern` in PowerShell or CMD:

```powershell
node.exe verify-host.cjs
dotnet.exe run --project HostCore.Tests/LuaPadModern.HostCore.Tests.csproj --configuration Release
node.exe verify-bridge.cjs
```

- HostCore: **82/82** pure managed tests pass.
- Existing M2 bridge/preview: **442/442** Lua and mock assertions passed separately.
- Existing structural gate: **56/56** pass; bridge contract 3 positive/11 negative pass.
- No external NuGet test framework is required; the class library builds against .NET 10. Generated `bin/` and `obj/` are ignored by Git.

## Trust boundaries and honest limitations

1. This is a validator, **not** the component that retrieves clipboard data. A future Windows service/desktop host must sample clipboard before dispatch and after the game command, timestamp it, and pass those samples to the validator. Clipboard contents are not automatically proof of a successful call.
2. `ExpectedResult` must come from host-generated unique IDs, never from the clipboard being validated. A successful parse of a previously displayed result is not a fresh observation.
3. `WindowObservation` and `EditorEvidence` are supplied by future real host discovery, process binding, RIFT `ui.status`, and screenshot/occlusion logic. The tests use fabricated observations and do **not** prove a real HWND can be resolved.
4. The validator enforces the key v1 envelope boundary fields and important schema shapes but does not replace comprehensive external JSON Schema validation for arbitrary future operations. It must not be represented as the whole M3 deliverable.
5. `HostScreenshotOcclusionClear` is a separate host-owned field, not an addon claim. It must be backed by a recent screenshot or equivalent UI check for the exact pinned window, not set to `true` by default.
6. Existing RIFT black-window/minimize behavior on display 3 is exactly why the gate rejects stale client bounds. Recovery/move/resize logic is not part of this checkpoint.

## Next M3 increment

- Implement a concrete Windows process/HWND discovery service that records process start and exact target, with read-only observation tests.
- Build a clipboard transaction coordinator with baseline/new-value sampling, timeout, correlation, and conditional restore only if no external clipboard change occurred. Retain a bounded receipt.
- Establish a deliberately foreground/interaction-gated command dispatcher using verified live callback arguments from the separate M2 game gate.
- Implement the WPF desktop/tray dashboard and stable UI Automation names; keep Workbridge as the MCP coordinator.
- Run physical RIFT acceptance separately, after approval for any game focus, addon hot-copy or reload.

Until those steps, mark M3 as **source-only in progress**, not a working automation connection.
