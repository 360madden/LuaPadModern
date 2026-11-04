# LuaPadModern P1 — automatic startup visibility and addon stacking (Preview 18)

Date: 2026-11-04. Scope: `C:\work\LuaPadModern` source and guarded RIFT deployment.
Status: **source/mock fix complete; physical RIFT acceptance pending**.

## User-visible defect and root cause

- LuaPad was initially invisible because `init()` called `luaPadWindow:SetVisible(false)`, while the successful startup flow never called `showLuaPad()`. The player had to type `/lp`.
- The old `/lp` handler merely changed the window's title and visibility. `luaPadWindow:SetLayer(1)` only ordered that child in its own context; it did not promote the `LuaPadContext` above other addon contexts.
- RIFT has independent context strata and numeric layer ordering. Per RIFT 1.7 notes, native dialog interactions can also mutate context layers after initialization. Raising visibility, context strata/layer, Windows foreground and editor key focus are distinct actions.
- Older screenshots proved a visible editor and a successful `a` character, but did **not** establish automatic stacking over other addons after startup.

## Preview 18 implementation

1. Keep LuaPad hidden while UI widgets, snippet buttons and snippet load finish. On success, **automatically call `showLuaPad()`** and report `READY - editor opened automatically; /lp brings it forward again`. If startup steps fail, retain the diagnostic instead of showing a half-constructed editor.
2. `bringLuaPadForward()` attempts `dialog` strata if the RIFT context supports it. It enumerates bounded `UI.Context` references (depth <= 4, <= 256 nodes), compares peer contexts in the **same actual strata**, then raises the context to a finite layer above peers (minimum 10, maximum 1024). API absence or individual getter failures are protected; it does not use `SetLayer(9999999)`.
3. A **single first-render callback** re-evaluates stacking after other addons have initialized. Uses documented `Command.Event.Attach` and `Command.Event.Detach` with `Event.System.Update.Begin`, plus a one-shot flag even if detachment fails.
4. Existing `/lp` reopens and re-raises after another addon or dialog rearranges layers. Explicit Close still hides LuaPad. Neither auto-open nor layer promotion calls `SetKeyFocus(true)`, sends keys or touches the Windows foreground window.
5. Source version updated from Preview 17 to **2.0.0-preview18**. The RIFT addon remains fully usable manually without the planned Windows/MCP host.

## Verification evidence

| Gate | Preview 18 source result | Live RIFT |
| --- | --- | --- |
| LuaPad + Inspector runtime harness | 141/141 checks, up from 128 | Pending |
| Complete M2 bridge gate | 455/455 checks, strict JSON receipt | Source-only |
| Structural addon gate | 57 checks passed | Source-only |
| M3 .NET 10 host core | 82/82 checks passed | Source-only |
| Bridge contract | 3 valid fixtures + 11 negative cases pass | Source-only |
| Automatic visibility, context strata, peer addon, late addon | Headless mock cases pass | Pending |
| Close, explicit `/lp` reopening/raise, no autofocus | Headless mock cases pass | Pending |

Mock acceptance deliberately injects a dialog addon before LuaPad, a later dialog with a higher layer before the first-frame event, checks first-frame detachment, and raises another dialog after that so `/lp` must bring LuaPad forward again. This covers the original failed workflow in source without pretending the mock is RIFT Live.

## Verified physical AddOns hot-copy (source files only)

- On 2026-11-04 at 08:01 ET, a dry run of `deploy-preview18.ps1` verified the two installed files matched the documented Preview 17 hashes. The guarded `-Apply` then backed up those exact files before replacing them.
- Installed `main.lua`: Preview 17 SHA256 `d4af7af2938901812c80e4ba57bc870d46f06e0f6e0f8397d922828b962098be` → Preview 18 SHA256 `37f2fbe4558e4deb06387ae78dc268d73e648d0558438f9703caac230ee4fd9d`.
- Installed `RiftAddon.toc`: Preview 17 SHA256 `3a7f739103f7ac9837427285573313312be4931c960fb42dde5c929c9c53b562` → Preview 18 SHA256 `0beb6c831fab4547e1f006ec6c31e49249e93481142b97445a6f105aaa34a70a`.
- Independently re-read exact installed file hashes and both backup hashes; all four match expected values. Rollback directory: `C:\work\LuaPadModern\backups\luapad-preview18-before-hotcopy-20261104-080152`.
- **No game foreground activation, keyboard/mouse input, `/reloadui`, process restart or SavedVariables write was performed.** Installed Preview 18 bytes will take effect at next authorized UI reload/normal launch. This is a file-copy success, **not a live stacking pass**.

## Physical deployment and acceptance gate

- Last independently documented physical baseline is Preview 17 (the editor's Enter/Tab and ASCII selected-text behavior passed; rollback copies in `backups/luapad-preview17-before-hotcopy-20261104-0939-nativekeys`). Preserve original addon and account SavedVariables backups.
- Confirm the *current* installed `luapad/main.lua` and `luapad/RiftAddon.toc` hashes before copying. If hashes differ from documented Preview 17, **stop rather than overwrite**.
- **Done:** a bounded backup-and-hot-copy of only those two files succeeded, with independent hash verification and rollback receipt above. Do not run `install-preview.ps1` with RIFT active; it deliberately refuses.
- The updated source will not take effect in the already running game until an **authorized `/reloadui` or the next normal game launch**. Do not take RIFT focus, inject keys or reload without Joey's separate permission.
- After loading Preview 18, confirm the addon appears **without typing `/lp`**; capture a screenshot containing the version/title and competing RRECollector or other addon. Check LuaPad visually on top, Close, `/lp` re-open/top again, and Enter/Tab in an inert editor string.
- Observe behavior with native dialog opening/closing, after game resize/move, and under the exact physical HWND/PID. Distinguish native dialog occlusion from another addon covering LuaPad.
- If any error, bring forward failure, stale text focus, or occlusion regression occurs, capture evidence, return to Preview 17 using the guarded rollback copies, and document the observed result.

## Residual constraints

- Source can use the documented context layer/strata APIs, but it cannot self-prove **pixel-level occlusion**. The Windows host/screenshot gate stays independent.
- RIFT may raise native dialogs later in the session. Preview 18 intentionally re-promotes on `/lp`, rather than running a permanently competing per-frame topmost loop.
- The first-frame listener requires the live RIFT `Command.Event.Attach/Detach` APIs. If unavailable, the immediate show/raise still proceeds and the callback is skipped.
- A competing addon created *after* the first frame can still cover LuaPad if it chooses a higher strata/layer. That requires a future opt-in explicit activation or physical design adjustment; it is not silently claimed fixed.

## References

- RIFT context strata and layer ordering: https://www.seebs.net/rift/pts/frame_setstrata.html and https://www.seebs.net/rift/pts/frame_setlayer.html
- RIFT first frame: https://www.seebs.net/rift/pts/event_system_update_begin.html
- Event attach/detach: https://www.seebs.net/rift/pts/command_event_attach.html and https://www.seebs.net/rift/pts/command_event_detach.html
- Context layer interaction with native dialog (RIFT 1.7): https://www.riftui.com/forums/showthread.php?mode=threaded&p=751
