# M3 read-only .NET 10 RIFT Log.txt tailer checkpoint (2026-11-04)

Status: **managed source component complete; 31 new synthetic log-reader assertions PASS. Physical RIFT-to-Log.txt transport is NOT proven.**

## Delivered

- [HostCore/NoncombatLogTailer.cs](../HostCore/NoncombatLogTailer.cs) is an opt-in, single-consumer, read-only C# component for a future Windows host.
- Constructor requires an absolute log path, a bounded ASCII correlation nonce, and a per-poll read budget no greater than 256 KiB. It performs no game input, focus/window operations, file writes, subprocess calls or networking.
- Default first observation of an existing file seeks to EOF to avoid reporting stale chat. If the file was absent, a subsequently created file is read from the beginning. The explicit `fromStart` option is for fixtures and diagnostics, not a proof of fresh events.
- Handles incremental appends, split lines/UTF-8 code points, UTF-16LE with BOM and split code units, truncated files, and common file replacements. Holds a shared read handle compatible with log writes and deletion/rotation.
- Bounds each poll to 256 KiB and a pending line to 8,192 characters. Returns only `WAITING_FOR_FILE`, `WATCHING`, `MATCHED`, or `READ_ERROR`; a match contains the expected nonce and timing metadata, never unrelated log lines.
- `ServerClockDeltaMs` is **not** a valid flush-latency measurement. It includes host/server clock disagreement and timestamp rounding. `IsFlushLatencyMeasurement` is always false.

## Verification

- Added [HostCore.Tests/LogTailTests.cs](../HostCore.Tests/LogTailTests.cs) with 31 synthetic checks for missing/create, nonce isolation, partial line, history suppression, explicit history, unknown timestamp, UTF-8 and UTF-16LE boundaries, replacement/truncation, large lines, invalid parameters and disposal.
- `node verify-host.cjs`: **113/113 PASS** (82 pre-existing host-core + 31 new log reader).
- `node verify-bridge.cjs`: **463/463 PASS**.
- `node tools/rift-log-probe-tests.cjs`: **32/32 PASS**.
- `node tools/rift-log-probe-cli-tests.cjs`: separate synthetic-process marker observed in **91 ms** at 25 ms poll; **not** RIFT latency.
- `node verify-preview.cjs`: structural PASS.
- No RIFT input, UI reload, addon installation or host service changes were made for this M3 slice.

## Physical pilot remains blocked / unknown

- Live Node watcher `LPB_LIVE_20261104_MANUAL1` (10:12–10:16 ET) timed out with no `Log.txt` at the default OneDrive/Documents/RIFT path and 0 appended bytes. Joey left for an appointment before running `/log` or the LuaPad marker; this is **inconclusive**, not a failed RIFT API/flush test.
- Workbridge shared desktop GUI turn remains quarantined from a November 2 screenshot attempt against an **old** RIFT window/PID. Read-only evidence identified the exact lease; the GUI turn was not bypassed, cleared, or retried. The current game was not focused.
- A separate, explicitly coordinated RIFT `/log` + editor Run marker is still required to validate game-to-file transport, destination, encoding, and observed freshness.

## Follow-up boundaries

1. When Joey is available, complete the no-reload physical pilot in [the M2 procedure](M2-LOG-TAIL-NO-RELOAD-PILOT-2026-11-04.md).
2. Once the path/flush behavior is proven, integrate this class into a hosted .NET 10 poll loop with opt-in configuration, cancellation, bounded result queue and explicit retention policy. Do not start background monitoring by default.
3. Before claiming robust same-size/same-timestamp rotation detection, bind file identity using a verified Windows file ID; `CreationTimeUtc` is only a **best-effort** managed replacement signal.
4. Keep inbound UI/clipboard automation separate and gated; a log tail is **outbound only** and cannot grant the RIFT Lua sandbox a network socket.
