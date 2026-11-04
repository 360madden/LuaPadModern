# M2 no-reload RIFT Log.txt tail pilot (2026-11-04)

Status: **working read-only Windows file-tail prototype; 40/40 synthetic regressions and separate two-process append smoke PASS. Actual LuaPad -> RIFT Log.txt flow NOT YET verified in the physical game.**

Repository: C:\work\LuaPadModern

## Why this pilot

RIFT's historical /log command writes non-combat chat text to Log.txt, and community Python tools have tailed it while RIFT runs. Historical RIFT 1.4 notes describe a 0.5-second flush for the *separate combat log*; that interval does **not** prove the non-combat Log.txt flush schedule.

A current read-only Windows inventory checked the four usual OneDrive/local Documents RIFT paths for Log.txt and CombatLog.txt. **All four were absent at approximately 09:38 ET, 2026-11-04.** This neither proves logging is disabled globally nor excludes a custom log path; the config may relocate files. We did not run /log, focus RIFT, or send game input.

## Prototype

- [Watcher](../tools/rift-log-probe.cjs): standard Node.js only; follows an exact configured Log.txt path while RIFT is running and waits if the file is absent.
- [Regression suite](../tools/rift-log-probe-tests.cjs): 40/40 passes for nonce parsing, no stale-log replay, creation, split writes, truncation, UTF-16LE, long-line bounds, no unrelated chat leaks, unknown clock value, transient file errors, split UTF-16 BOM, and header-read retry.
- [Windows two-process smoke](../tools/rift-log-probe-cli-tests.cjs): a **separate Node watcher process** detected a split marker appended to a synthetic file with an observed **94 ms** append-to-detection interval at 25 ms polling (one sample, not a game latency result).
- Never opens the file for writing. Ignores unrelated chat content and outputs only probe metadata/nonce; no actual chat lines.
- Tail reading uses bounded 256 KiB per poll, default 100 ms poll, a 120-second default expiration, and explicit stop/exit code.
- Handles file creation and truncation; reads from zero after creation/reset. Existing files start at EOF by default to avoid confusing older messages with fresh results.
- The payload includes optional Inspect.Time.Server() epoch time. The host calculates **serverClockDeltaMs**, which includes server/host clock offset and timestamp rounding and is **NOT precise flush latency**. True end-to-end timing will need a correlated host-controlled send event or other synchronized observation.
- The watcher does **not** install or enable any LuaPad addon modules, register /lpb, or provide an MCP endpoint. It is a transport *feasibility* probe. Its synthetic file performance cannot prove RIFT's noncombat log flush timing.

## First physical listening-window result

- Workbridge launched `node tools\\rift-log-probe.cjs --nonce LPB_LIVE_20261104_0945 --timeout-ms 120000 --poll-ms 100` from the physical Windows host without focusing RIFT or sending game input.
- The correct default OneDrive Documents path was observed as **absent** at start. The process reported `waiting_for_file` and then exited with code **2 (timeout)** after **120,073 ms**, with **0 appended bytes** and **no marker**.
- This is **inconclusive**, not a failure of the RIFT log API: `/log` had not been observed enabled and no user-executed Lua probe was received during that two-minute window. No game-level flush timing was measured.

## No-reload physical test procedure

1. When Joey is ready and game input is convenient, he manually enters **/log** in RIFT chat. This toggles non-combat logging without /reloadui. Verify that the configured path now exists. Avoid toggling blindly if uncertain of current logging state.
2. Start the watcher from a Windows terminal in C:\work\LuaPadModern (Workbridge can launch this command instead):

       node.exe tools\rift-log-probe.cjs --nonce LPB_TEST_20261104 --timeout-ms 120000

   Override --path "C:\exact\path\Log.txt" if RIFT writes elsewhere. The watcher prints the Lua snippet and a waiting/ready status; it does not take game focus.
3. In the **already-running LuaPad** code editor, paste this code and click **Run** (no addon installation or /reloadui needed):

       local token = "LPB_TEST_20261104"
       local epoch = "unknown"
       if Inspect and Inspect.Time and type(Inspect.Time.Server) == "function" then
         local good, seconds = pcall(Inspect.Time.Server)
         if good and type(seconds) == "number" then
           epoch = string.format("%.3f", seconds)
         end
       end
       local msg = "LPB_PROBE|" .. token .. "|" .. epoch
       local ok, err = pcall(Command.Console.Display, "general", false, msg, false)
       print(ok and ("Sent probe: " .. token) or ("Probe error: " .. tostring(err)))

4. The LuaPad output reports whether Command.Console.Display returned without error. **This alone is not a bridge pass.**
5. Success is a separate **matched** receipt from the Windows watcher before its timeout, from the correct live Log.txt path. Record wall time, file creation, bytes tailed and server clock delta; separately verify whether console output actually appears in non-combat Log.txt.
6. Repeat with distinct nonces, multiple samples and different Windows foreground states (without automated game inputs) before declaring near-real-time reliability. On a failure, preserve the watcher receipt and inspect path, /log state, encoding and console type before adjusting any RIFT settings.

## CLI behavior and interpretation

- --help: usage.
- --print-lua: print the probe Lua script without starting a watcher.
- --nonce: explicit safe ASCII identifier for correlation.
- --path: exact Log.txt location (recommended for custom config).
- --from-start: read existing history (fixture/debug only; not used for live freshness proof).
- Exit code 0: exact matching token observed; 2: timeout; 1: invalid setup; 130: interrupted.
- The reported serverClockDeltaMs must not be presented as measured flush time; if accuracy is not established, report **latency unknown**.

## Next milestones if physical test passes

1. Introduce an explicitly enabled, bounded addon log exporter (disabled by default) with schema/versioned chunks, requestId/sessionId, checksum and backpressure.
2. Implement the watcher in the .NET 10 Windows host and verify real file sharing, rotation, high log volume and background handling.
3. Workbridge adds typed, correlated tool receipts. Slash/UI input stays a separate readiness-gated inbound path; no direct RIFT addon TCP/HTTP API has been established.

## Source references

- RIFT /log utility: https://github.com/Bamux/RiftEventTracker
- RIFT /log voice alerts: https://github.com/Bamux/Rift-Raid-Alert
- Historical addon API: https://github.com/chrisbecke/Igor/wiki/Command.Console.Display
- Inspect.Time.Server Unix seconds: https://github.com/chrisbecke/Igor/wiki/Inspect.Time.Server
- Historical combat-log flush distinction: https://www.gaiscioch.com/tavern/rift_discussion/post_20647.html
