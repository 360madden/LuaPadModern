# LuaPadModern Preview 20 — center anchoring, Joey author credit, and outbound bridge research

Date: 2026-11-04. Physical host: RIFT Live x64. Repo: `C:\work\LuaPadModern`.
Status: **source/headless checks PASS; guarded physical AddOns copy PASS; in-game Preview 20 UI acceptance PENDING a separate user-authorized `/reloadui` or normal relaunch**.

## User observation and scope

- Preview 18 automatically opened in the physical client, but its editor was obscured by competing `RR2 CAST` and `RiftReader API Readiness` addon frames.
- Preview 19 promoted the LuaPad context/window above known topmost/high-layer peers.
- Joey later reported **"ok its not below other layers now"**, confirming the practical Preview 19 layering improvement in his running game. No fresh screenshot is claimed for that report.
- Joey then identified **off-center startup placement**, requesting center anchoring and his author credit in the title, addon metadata, and Git commits.
- Additional research question: can a RIFT addon get data to a Windows/Workbridge host without visual automation, SavedVariables, or clipboard?

## Preview 20 implementation

1. Replace fixed `luaPadWindow:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, 100)` with `luaPadWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)`. Existing dimensions are 840 × 600; RIFT's `UIParent` is the live UI root. No OS window position/focus mutation is introduced.
2. Display `LuaPad v2.0.0-preview20 | by Joey Delfierro` on initial UI creation and `/lp` re-open via the shared version-driven title function.
3. In `RiftAddon.toc`, credit `Joey Delfierro (360madden)` as author/maintainer, **retain original LuaPad creator NerfedWar** in provenance and Description, and link Joey's GitHub profile. The existing upstream Email is provenance, not a published maintainer contact.
4. Set **repository-local** Git `user.name` to `Joey Delfierro` for new commits. Git email and all historical commits remain unchanged.
5. Preserve Preview 19 first-frame/topmost/high-layer raising, no startup editor key-focus steal, no game-window activation, and explicit-close behavior.

## Verification

| Check | Evidence |
| --- | --- |
| Preview structural gate | `node verify-preview.cjs`: **59/59 PASS** |
| LuaPad + Inspector mock runtime | **149/149 PASS**; new startup-center and initial/`/lp` title regressions |
| Combined source bridge gate | `node verify-bridge.cjs`: **463/463 PASS** (39 codec + 40 UI + 70 router + 165 slash + 149 runtime) |
| Pure Windows host core | `node verify-host.cjs`: **82/82 PASS** |
| JSON contracts | `node contracts/verify-contract.cjs`: **3 positive fixtures / 11 negative cases PASS** |
| Installed `main.lua` SHA256 | `34bf8d962c700862f655d5c60c58e5a76a01ca8c3c26eb4299e55a38ed5f6e59` |
| Installed `RiftAddon.toc` SHA256 | `b3caba8124274cb744f693f727726edc5cbb3ff38733158eae511bed90a4d11b` |

The `deploy-preview20.ps1` script first dry-runs and checks exact Preview 19 installed/source SHA256 hashes, backs up both files, writes only `luapad/main.lua` and `luapad/RiftAddon.toc` on `-Apply`, then independently checks source/installed hashes. The guarded deployment succeeded.

**Rollback:** `C:\work\LuaPadModern\backups\luapad-preview20-before-hotcopy-20261104-090926`, containing the original Preview 19 pair. No SavedVariables were changed or restored. The assistant did **not** take RIFT focus, send keys/clicks, or execute `/reloadui`. Installed source does not affect currently loaded Lua until Joey reloads the UI or restarts normally.

## Transport research — documented versus physically verified

| Candidate | Addon capability | Windows/Workbridge path | Proof level |
| --- | --- | --- | --- |
| **Console/chat log** | `Command.Console.Display(console, suppressPrefix, text, html)` writes to in-game console; player `/log` produces `Documents\RIFT\Log.txt` | Host tails Log.txt for **outbound** tagged events/results | **Historical primary-source precedent** (RiftEventTracker, Rift Raid Alert); **not yet proven** for LuaPad-generated messages/flushing in RIFT Live |
| **Clipboard** | `Command.CopyToClipboard(text)` already powers LuaPad's Copy Output | Windows host reads clipboard | Existing native addon action; host end-to-end bridge not yet built |
| **SavedVariables** | Game-managed persisted Lua addon state | External process reads after RIFT writes/flushed saves | Durability channel; cannot assume continuous or instantaneous write-through |
| **Addon messages** | `Command.Message.Send/Broadcast`; `Event.Message.Receive` | Other **RIFT game clients/addons** via game service | Documented RIFT server-mediated client communication; **not** a Windows socket/API |
| **Addon storage** | `Command.Storage.Get/Set/List` with storage events | Other game clients subject to permissions/throttling | Documented game-service storage; **not** a local host stream |
| **Slash command** | `Command.Slash.Register` | Windows host may submit short authenticated/correlated commands via exact verified RIFT UI input | Inbound candidate, requires foreground + editor/game chat safety, not direct host networking |
| **HTTP/TCP/UDP sockets** | No general-purpose RIFT addon network API found in current documentation | None established | **Unverified**, do not design as if available |
| **External memory/telemetry reader** | Separate process, not Lua addon | RR2 read-only telemetry identified independently | Possible host-side supplement; does not change Lua sandbox |

**Crucial detail:** LuaPad's `Run` function captures `print` into its own output pane. It does **not** prove that the game writes those `print` calls to `Log.txt`; a separate *opt-in* log export must call the tested RIFT console API explicitly. Avoid sending unbounded code output into normal chat.

## Proposed M2 next slice: opt-in log exporter + host watcher

1. Read-only preflight: locate `Documents\RIFT\Log.txt`, ask Joey to enable game `/log` when convenient, snapshot file size/freshness and test an inert tagged `Command.Console.Display` line; verify it appears in the correct file on the physical client and measure flush delay.
2. If verified, provide LuaPad `bridge.log.enable` + `bridge.log.status` (disabled by default), output chunking with `[LPB:1]`, requestId/sessionId, segment count/sequence/checksum, length caps, low-rate queues and automatic backpressure. No arbitrary chat spam and no silent automatic export of `Run` content.
3. Windows Host watches a specific observed path, handles file rotation/truncation/reloads, reassembles complete frames, validates JSON envelope, checks freshness and idempotency, supplies explicit MCP receipt.
4. Inbound remains gated via short slash/UI commands; correlate request and result ID. Distinguish successful log bytes from successful addon execution. SavedVariables remain fallback checkpoints; clipboard remains an explicit high-volume snapshot route.
5. Only after real latency/throughput and failure tests should `/log` be called a working live Workbridge transport.

## References

- Historical RIFT `Command.Console.Display` and `Command.CopyToClipboard` API: https://github.com/chrisbecke/Igor/wiki/Command.Console.Display
- Historical RIFT `Command.Message.Send` and `Command.Message.Broadcast` API: https://github.com/chrisbecke/Igor/wiki/Command.Message.Send
- Historical RIFT server storage API: https://github.com/chrisbecke/Igor/wiki/Command.Storage.Get
- Addon slash registration: https://github.com/chrisbecke/Igor/wiki/Command.Slash.Register
- Live RIFT log tail watcher project: https://github.com/Bamux/RiftEventTracker
- RIFT combat/event log watcher: https://github.com/Bamux/Rift-Raid-Alert

## Physical acceptance (pending)

On Joey's separately authorized `/reloadui` or next game launch:

1. Confirm title **`LuaPad v2.0.0-preview20 | by Joey Delfierro`**.
2. Confirm editor opens **centered** on the current RIFT UI/screen without `/lp`.
3. Confirm editor remains visually **above competing addons**, including `RR2 CAST` and `RiftReader API Readiness`, and does not steal native dialog inputs.
4. Verify `/lp` reopens and restores title/front order after a deliberate Close; don't assume editor keyboard focus without a direct check.
