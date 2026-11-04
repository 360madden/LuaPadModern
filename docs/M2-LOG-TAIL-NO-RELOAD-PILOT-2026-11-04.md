# M2 no-reload RIFT Log.txt tail pilot (2026-11-04)

Status: **read-only Windows file-tail prototype; 40/40 existing Node tests, 24/24 Node discovery, 16/16 managed discovery, 15/15 managed CLI tests and two-process append smoke PASS. Actual LuaPad -> RIFT Log.txt flow NOT YET verified in the physical game.**

Repository: C:\work\LuaPadModern

## Why this pilot

RIFT's historical /log command writes non-combat chat text to Log.txt, and community Python tools have tailed it while RIFT runs. Historical RIFT 1.4 notes describe a 0.5-second flush for the *separate combat log*; that interval does **not** prove the non-combat Log.txt flush schedule.

A current read-only Windows inventory checked the four usual OneDrive/local Documents RIFT paths for Log.txt and CombatLog.txt. **All four were absent at approximately 09:38 ET, 2026-11-04.** This neither proves logging is disabled globally nor excludes a custom log path; the config may relocate files. We did not run /log, focus RIFT, or send game input.

## Prototype

- [Watcher](../tools/rift-log-probe.cjs): standard Node.js only; `--path` follows one exact file. Without `--path`, it searches bounded normal/OneDrive Documents candidates, prefers an existing log or RIFT directory, and selects a later-created log if the initial candidate was absent.
- [Regression suite](../tools/rift-log-probe-tests.cjs): 40/40 passes for nonce parsing, no stale-log replay, creation, split writes, truncation, UTF-16LE, long-line bounds, no unrelated chat leaks, unknown clock value, transient file errors, split UTF-16 BOM, and header-read retry.
- [Discovery suite](../tools/verify-log-discovery.cjs): 24/24 synthetic assertions for default and optional custom candidates, late-created initial/alternate files, first-marker retention, existing-history suppression, and explicit-path precedence.
- [.NET HostProbe discovery suite](../tools/verify-host-log-discovery.cjs): 16/16 hermetic assertions; existing .NET HostProbe CLI smoke remains 15/15. The managed probe also honors the redirected Windows Documents Known Folder.
- [Windows two-process smoke](../tools/rift-log-probe-cli-tests.cjs): a **separate Node watcher process** detected a split marker appended to a synthetic file with an observed **94 ms** append-to-detection interval at 25 ms polling (one sample, not a game latency result).
- Never opens the file for writing. Ignores unrelated chat content and outputs only probe metadata/nonce; no actual chat lines.
- Tail reading uses bounded 256 KiB per poll, default 100 ms poll, a 120-second default expiration, and explicit stop/exit code.
- Handles file creation and truncation; reads from zero after creation/reset. Existing files start at EOF by default to avoid confusing older messages with fresh results.
- For custom folders, `LUAPAD_LOG_CANDIDATES` can replace defaults with 1–8 absolute `Log.txt` paths (semicolon-separated on Windows; maximum 2048 characters each and 8192 total). Explicit `--path` overrides this list. Newly created candidate files retain their first marker; an already-existing file does not replay old chat.
- The payload includes optional Inspect.Time.Server() epoch time. The host calculates **serverClockDeltaMs**, which includes server/host clock offset and timestamp rounding and is **NOT precise flush latency**. True end-to-end timing will need a correlated host-controlled send event or other synchronized observation.
- The watcher does **not** install or enable any LuaPad addon modules, register /lpb, or provide an MCP endpoint. It is a transport *feasibility* probe. Its synthetic file performance cannot prove RIFT's noncombat log flush timing.

## Unattended read-only preflight (2026-11-04)

- `node.exe tools\no-reload-pilot-readiness.cjs [--path ABSOLUTE_LOG] [--nonce TOKEN]` performs one bounded metadata/open check and exits. It never reads chat text, starts a watcher, changes `/log`, focuses RIFT, or reloads LuaPad.
- The JSON receipt distinguishes `LOG_MISSING`, `LOG_READABLE`, `NOT_A_FILE`, and `LOG_ACCESS_ERROR`; it always reports `loggingEnabled: "unknown"`, `transportVerified: false`, and `flushLatencyMs: null` until a separately coordinated game test.
- It prints a matching nonce, exact watcher executable/argument array, and matching LuaPad code inside `LUA_PROBE_START`/`LUA_PROBE_END`. A synthetic file writer could forge a matching receipt; physical acceptance also needs a confirmed RIFT file destination and a correlated manual in-game send.
- `node.exe tools\no-reload-pilot-readiness-tests.cjs` passed **21/21 synthetic checks**, including missing/readable/directory/access-denied paths, privacy, safe options, nonce reuse, and evidence-labeling safeguards. Test fixtures did not access RIFT.
- At **13:47 ET** on Nov 4, a read-only host preflight found the then-default candidate `C:\Users\mrkoo\OneDrive\Documents\RIFT\Log.txt` **missing**. This does not establish RIFT logging state or exclude another configured path.

## First physical listening-window result

- Workbridge launched `node tools\\rift-log-probe.cjs --nonce LPB_LIVE_20261104_0945 --timeout-ms 120000 --poll-ms 100` from the physical Windows host without focusing RIFT or sending game input.
- The previously selected default OneDrive Documents candidate was **absent** at start. The process reported `waiting_for_file` and then exited with code **2 (timeout)** after **120,073 ms**, with **0 appended bytes** and **no marker**.
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
5. A credible physical pass requires a confirmed **RIFT-produced Log.txt path**, Joey's correlated manual LuaPad Run in RIFT, and a separate exact **matched** watcher receipt before timeout. A receipt by itself can be forged by a synthetic file writer. Record wall time, file creation, bytes tailed and server clock delta; separately check whether console output appears in the non-combat log.
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
2. Integrate the existing .NET 10 HostProbe into the persistent Windows host and verify real file sharing, rotation, high log volume and background handling.
3. Workbridge adds typed, correlated tool receipts. Slash/UI input stays a separate readiness-gated inbound path; no direct RIFT addon TCP/HTTP API has been established.

## Source references

- RIFT /log utility: https://github.com/Bamux/RiftEventTracker
- RIFT /log voice alerts: https://github.com/Bamux/Rift-Raid-Alert
- Historical addon API: https://github.com/chrisbecke/Igor/wiki/Command.Console.Display
- Inspect.Time.Server Unix seconds: https://github.com/chrisbecke/Igor/wiki/Inspect.Time.Server
- Historical combat-log flush distinction: https://www.gaiscioch.com/tavern/rift_discussion/post_20647.html
