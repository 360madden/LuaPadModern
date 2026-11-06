# RIFT MMO addon sandbox and security model — LuaPadModern

Date: 2026-11-06. Owner: Joey Delfierro. Target: physical RIFT Live x64.
Status: **historical API corroborated + local source reviewed; Live capability inventory still pending**.
This is **RIFT MMORPG (Trion/Gamigo) addon Lua**, not a different product named Rift or World of Warcraft.

## Evidence labels

- **H — historical documented:** captured PTS/API documentation; may differ from the installed Live client.
- **S — source observed:** current LuaPadModern source or synthetic tests; not necessarily activated in RIFT.
- **L — Live observed:** physical RIFT screenshot/input or in-game API output with time and identity.
- **U — unverified:** must not be assumed available or absent.
- A callable function's existence does **not** establish permission to call it in every game state.

## Four independent boundaries

1. **Lua addon API sandbox.** Addon code executes in RIFT's Lua environment and sees its supplied `Inspect`, `Event`, `Command`, `UI` and `Utility` surfaces. No Windows filesystem/process/native socket access has been established for RIFT Live addon Lua. Do not confuse the host-side Workbridge/Powershell privileges with addon Lua privileges. Treat `io`/`os`/`package`/socket presence as **U** until a read-only Live check. `loadstring` compiles code inside the same environment; it does not create OS privileges.
2. **Combat/Secure state.** `Inspect.System.Secure()` returns a boolean. `Event.System.Secure.Enter` and `Leave` bracket mode changes (usually combat). On Enter, restricted functions lock **after** the event; on Leave, unlock **before** the event. **H**.
3. **Frame SecureMode.** Frames have `normal` and `restricted` modes. `restricted` permits certain sensitive actions while adding restrictions in secure combat state; it requires a restricted parent and cannot be reverted to `normal`. Ordinary LuaPad UI should remain `normal`. `SetStrata`, `SetLayer`, and `SetPoint` have a historical restriction when applied to restricted frames in the secured environment. **H**.
4. **Transport and external control.** `Command.Message.*` is server-mediated addon-to-addon game-client messaging, not Windows TCP/IPC. `Command.Storage.*` is permissioned, throttled game storage. Clipboard, console/log, SavedVariables and Windows input are distinct channels; none should be called a working real-time host bridge without live receipts. **H/S; some L input receipts**.

## Capability and restriction matrix

| Area | API or mechanism | Historical rule, current design constraint | Evidence |
| --- | --- | --- | --- |
| Secure state | `Inspect.System.Secure`; `Event.System.Secure.Enter/Leave` | Query state and observe transitions. Do not equate foreground with noncombat/permission. | H |
| Frame mode | `Frame:SetSecureMode` / `GetSecureMode` | `normal` vs irreversible `restricted`; restricted parent prerequisite. Never casually switch LuaPad frames. | H |
| Frame layout | `Frame:SetLayer/SetStrata/SetPoint` | Restricted frame mutation may be unavailable during Secure state; normal-frame layering still needs live measurement. | H, S |
| Sensitive user events | `Layout:EventMacroSet` | Marked require-secure-frame-and-insecure-environment; not an unrestricted gameplay action from an ordinary button. | H |
| Cursor ability | `Command.Cursor` | Ability cursors allowed only when not in secure mode. | H |
| Editor focus | `RiftTextfield:GetKeyFocus/SetKeyFocus` | Exactly one frame can own key focus; focus must be verified before input. | H, S |
| Editor keys | `RiftTextfield.Event:KeyDown` | Native textfield event receives key as string; Preview 17 physically passed Enter/Tab; Preview 20 carries same handler. | H, L historical, S |
| General key event | `Event.UI.Input.Key.Down` | Requires key focus; generic handler was insufficient for Preview 16 Enter/Tab. | H, L historical |
| Slash commands | `Command.Slash.Register` | Adds event table, returns nil on a built-in slash-name conflict. Runtime callback shapes need Live verification. | H, S |
| Addon lifecycle | `Event.Addon.Load/Startup/Shutdown` | Initialization, addon load and shutdown are different events. | H |
| SavedVariables | `Event.Addon.SavedVariables.Load/Save.Begin/End` | Data flush follows game-managed save lifecycle; no continuous file write guarantee. | H, S |
| Console | `Command.Console.Display` | Bounded line output to a game console; Windows `Log.txt` persistence/flush unverified for LuaPad output. | H, U Live |
| Clipboard | `Command.CopyToClipboard` | LuaPad source uses it; actual Live clipboard bridge and supported payload limits require proof. | S, U Live |
| Addon messaging | `Command.Message.Send/Broadcast/Accept` | Recipient rules; server-accepted ≠ delivered; broadcast may drop; bandwidth throttling. | H |
| Remote game storage | `Command.Storage.Get/Set/List/Clear` | Per-player/guild read/write permissions, server throttle and async receipt. | H |
| Command throttling | `Inspect.Queue.Status`; `Event.Queue.Status` | Queue saturation must be handled; no success inferred from invocation alone. | H |
| Performance | `Inspect.Addon.Cpu`; `Inspect.System.Watchdog`; `Event.System.Error` | CPU/watchdog monitoring; perf warnings/errors and interrupted thread are possible. Avoid long work in one frame. | H |
| Strict mode | `Command.System.Strict` | Deprecated functions/events throw instead of working; do not activate globally during live testing without a reason. | H |
| Runtime introspection | `Inspect.Documentation(item, true)` | Can return machine-readable documentation, but shape may change. Prefer verified runtime inventory to PTS guesses. | H |
| Game data | `Inspect.Unit.Detail/List/Lookup` and unit availability events | Detail visibility varies by availability and unit; no assumption every actor's full data is accessible. | H |
| Direct OS/network APIs | `io`, `os`, `package`, socket/HTTP modules | No direct Windows/file/socket bridge demonstrated from RIFT addon environment. **Not proven absent**; read-only probe needed. | U |
| Host desktop input | Workbridge/WinApp CLI | Runs outside game Lua; must prove pinned HWND/PID/session/foreground, actual editor focus and screenshot. Does not change addon sandbox rules. | L for `/lp` only; focus pending |

## LuaPadModern code audit (2026-11-06)

- `main.lua` creates `UI.CreateContext("LuaPadContext")` and a standard `RiftTextfield`. The window is centered and raised using bounded context/frame layering.
- `showLuaPad()` opens without stealing editor key focus. `inputField.Event:KeyDown` handles Return/Enter/Tab, calls `SetKeyFocus(true)` after receiving its event, and inserts text. This does not prove pre-input focus.
- `LuaPad.doRun` uses `loadstring`/`load` and `xpcall` and restores its `print` hook. It executes editor-provided Lua **inside RIFT's addon runtime**; do not assume arbitrary `Command.*` APIs are allowed during combat or that a protected action succeeds.
- `Bridge/ui_status.lua` is a **source-only**, read-only snapshot of context/window/editor; it is not yet wired to real live frames. Current host readiness rejects focus/occlusion unknowns.
- Current source gates: structural 59/59 and bridge/runtime 483/483 PASS across six suites on 2026-11-06, including 20 read-only security probe assertions. Prior physical Preview 17 Enter/Tab passed; current Preview 20 live centered/reopen passed on 2026-11-06, editor focus still unverified.
- Physical RIFT had temporarily appeared as 1024×671 with UIA x=-32768; the existing focus-only tool restored 1936×1048 at x=-1928 without keyboard/mouse input. A coordinate click requires a **new** geometry/capture gate, never a cached screenshot coordinate.

## Live screenshot receipt — 2026-11-06T07:22:55Z

- Physical RIFT `rift_x64` PID 32156 / HWND 462734, class `TWNClientFramework`; verified window capture SHA-256 `09982717b1c87e7fd26ec0904ac7cedb9e67904edc7834875e0c751b53fa5b2d`, 1920×1032. No keyboard or mouse input injected.
- LuaPad v2.0.0-preview20 is visible, centered horizontally and above other panels. The **separate RiftReader API Readiness panel** visibly displays `secure mode: false`; this is a screenshot of that panel's reported state, **not** a direct read of `Inspect.System.Secure()` by the new LuaPad probe.
- That panel also reports `root-frame-focus: unknown`, `native text entry: unknown`, `autonomous input ready: false`. Consequently editor input remains gated. No claim that the read-only sandbox probe ran in physical RIFT.

## Read-only Live capability inventory

Run `tools/rift-sandbox-readonly-probe.lua` manually from LuaPad's editor **only when editor focus is independently confirmed** and no other input modal is present. It invokes `Inspect.System.Secure`, `Inspect.System.Version`, `Inspect.Addon.Current` and one `Inspect.Documentation` lookup behind `pcall`; everything else is inspected by type only. It never calls `os.execute`, `io.open`, `package.loadlib`, `Command.*`, game input or storage.

The probe's output distinguishes `present` from `permitted`. Store the exact client build, screenshot/time, secure state and response before upgrading any historical claim to Live. For a broad full API inventory later, paginate `Inspect.Documentation()` across frames with a watchdog budget; never print or copy hundreds of function descriptions in a single update.

### Live acceptance priorities

1. **Read-only:** run the bounded probe outside combat and record a source-hashed report of available symbols, current secure state/version and documentation result.
2. **Focus:** acquire exact Windows foreground and LuaPad editor focus; read `GetKeyFocus()==true` and capture editor-area proof before any synthetic character.
3. **Keys:** only after focus and bounds gate, test a short marker with Enter/Tab; verify visually and clear the unsaved marker. Never save a snippet or issue gameplay macros as a focus test.
4. **Secure transition:** observe `Inspect.System.Secure()` in an ordinary combat/idle transition only when convenient; no protected mutation during the test.
5. **Transport:** test independently with explicit receipts: console-to-log, clipboard, SavedVariables; game messages/storage are not host channels.

## Primary historical RIFT API references

- [RIFT system security and watchdog](https://www.seebs.net/rift/pts/System_index.html)
- [Frame secure mode](https://www.seebs.net/rift/pts/frame_setsecuremode.html), [layer](https://www.seebs.net/rift/pts/frame_setlayer.html), [strata](https://www.seebs.net/rift/pts/frame_setstrata.html), [anchor](https://www.seebs.net/rift/pts/frame_setpoint.html)
- [Protected macro event](https://www.seebs.net/rift/pts/layout_eventmacroset.html); [cursor rule](https://www.seebs.net/rift/pts/Cursor_index.html)
- [RiftTextfield focus](https://www.seebs.net/rift/pts/rifttextfield_getkeyfocus.html), [setter](https://www.seebs.net/rift/pts/rifttextfield_setkeyfocus.html), [native KeyDown](https://www.seebs.net/rift/pts/rifttextfield_event_keydown.html)
- [UI input events](https://www.seebs.net/rift/pts/UI_index.html), [slash registration](https://www.seebs.net/rift/pts/Slash_index.html), [addon lifecycle](https://www.seebs.net/rift/pts/Addon_index.html)
- [Messages](https://www.seebs.net/rift/pts/Message_index.html), [storage permissions](https://www.seebs.net/rift/pts/Storage_index.html), [queue](https://www.seebs.net/rift/pts/Queue_index.html), [console](https://www.seebs.net/rift/pts/Console_index.html)
- [Client API documentation introspection](https://www.seebs.net/rift/pts/Documentation_index.html); [unit data/availability](https://www.seebs.net/rift/pts/Unit_index.html)

Historical PTS docs reflect a specific older game revision. Some names/types and restrictions may be stale in Live. Cross-check with `Inspect.Documentation`, Live behavior and errors; do not mix in unrelated WoW or modern software named "Rift".
