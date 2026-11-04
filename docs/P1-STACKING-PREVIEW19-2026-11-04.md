# LuaPadModern P1 — physical overlap correction candidate (Preview 19)

Date: 2026-11-04. Project: `C:\work\LuaPadModern`.
Status when first written: **Preview 18 auto-open PASS / stacking FAIL; Preview 19 source and installed-byte PASS; physical visual acceptance then PENDING.** Subsequent outcome recorded below.
Owner priority: P1, ahead of M2–M7 host/MCP features.

## Later Preview 19 in-game outcome (2026-11-04)

Joey explicitly reported **"ok its not below other layers now"** after the stacking revision. This is user-confirmed improvement in the real game and supersedes this document's earlier pending status; no new screenshot was supplied at that moment. He then requested centering and his author credit, delivered as Preview 20 separately; this checkpoint remains the historical Preview 19 release record. Native dialog interactions and focus checks remain open.

## User-supplied physical evidence

At approximately **08:25 ET on 2026-11-04**, Joey supplied a physical RIFT screenshot with the `LuaPad v2.0.0-preview18` editor visible automatically at game startup. The editor was **behind** the `RR2 CAST` panel (left) and the `RiftReader API Readiness` dialog (center); unrelated overlays also remained visible. This directly closes the Preview 18 auto-open question and **fails the stacking release gate**. Nothing in this screenshot proves native editor key focus or full input readiness.

## Read-only competing-addon source findings

| Installed addon source | Relevant observed behavior | Impact |
| --- | --- | --- |
| `BotFight/unit/cast.lua` (lines 42–45) | `UI.CreateContext("BotFightCast")` with `SetStrata("topmost")` | Preview 18 `dialog` context could be behind cast panel |
| `BotFight/unit/rack.lua` (lines 365–371, 391, 409, 457, 474, 483) | Two `topmost` contexts and child-frame layers `999990`, `999991`, `999995` | Raising only LuaPad context was insufficient |
| `RiftReaderApiProbe/readiness.lua` (lines 739–747) | `RiftWindow` titled `RiftReader API Readiness`, `window:SetLayer(999990)` | Direct visual overlap in user's screenshot |
| `RRECollector/ui.lua` (lines 197–199) | A secure reload context uses `SetStrata("topmost")` | Additional topmost peer exists |
| `LibWiki/CopyDialog.lua` (lines 11–12) | `SetStrata("topmost")` | Other addon dialog may compete |
| `RiftReaderValidator` (disabled) | Child `SetLayer(999999)` in source | Reinforces why a floor above one million was selected |

These source findings are a **mechanistic explanation** for the Preview 18 failure; only a new RIFT screenshot can establish whether Preview 19 actually solves it. RIFT strata and frame-layer ordering are distinct from Windows foreground HWND and RiftTextfield key focus.

## Preview 19 implementation

- Prefer `topmost` if returned by the supported `context:GetStrataList()`; fall back to `dialog` where that is the highest supported target.
- Recursively inspect peers under `UI.Context`, including child `GetChildren()` frames, within **7 nested levels / 1024 visited nodes** and without descending into LuaPad's own context.
- Raise LuaPad context layer above observed peer contexts, keeping its former bounded context-layer maximum **4096**.
- Raise LuaPad `RiftWindow` child layer to `max(1000010, highestObservedFrameLayer + 1)` with ceiling **2,000,000**. The measured floor outranks the exact competing `999990–999999` layer values in these installed addons even if child enumeration is missing.
- Preserve existing successful initialization auto-open without `/lp`, one-shot first-render re-raise and explicit `/lp` re-raise; allow Close to hide the window.
- **Do not** call `RiftTextfield:SetKeyFocus(true)` automatically, alter Windows foreground, perform a per-frame z-order fight, simulate clicks or call `/reloadui`.

Potential residual: competing addon controls created later can deliberately select even higher layer values or strata; native dialogs and interaction overlays can behave differently. Measure their overlap separately. The numeric layer is a bounded compatibility workaround, not a pixel-based occlusion detector.

## Source verification gates

| Check | Evidence |
| --- | --- |
| `node verify-bridge.cjs` | **460/460** passed: 39 codec + 40 UI status + 70 router + 165 slash + 146 LuaPad/Inspector |
| `node verify-preview.cjs` | **57/57** structural checks |
| `node verify-host.cjs` | **82/82** pure managed host-core checks |
| `node contracts/verify-contract.cjs` | Previously **3 valid fixtures / 11 negative cases**; rerun on final release verification |
| Mock stacking cases | Preexisting topmost peer, high-layer child `999995`, readiness pane `999990`, late topmost addon, startup/first frame/`/lp`, explicit close, no implicit key focus |

These are source and headless mock gates. No Windows UI Automation, MCP transport or in-game key injection is claimed.

## Guarded physical AddOns hot-copy

Command run from PowerShell with dry-run first, then explicit `-Apply`:

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\work\LuaPadModern\deploy-preview19.ps1
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\work\LuaPadModern\deploy-preview19.ps1 -Apply
```

The deployment checked the exact Preview 18 installed SHA256 hashes *before* copying. It preserved both originals in a timestamped rollback directory, rechecked them and wrote only `luapad/main.lua` and `luapad/RiftAddon.toc`. Installed files were independently re-read and SHA256 verified after the copy.

| File | Preview 18 / rollback SHA256 | Preview 19 installed/source SHA256 |
| --- | --- | --- |
| `main.lua` | `37f2fbe4558e4deb06387ae78dc268d73e648d0558438f9703caac230ee4fd9d` | `d28a5d84ba2e6b66f1926b0fd9868f2755a2d221ace4781582426d81ba9cd156` |
| `RiftAddon.toc` | `0beb6c831fab4547e1f006ec6c31e49249e93481142b97445a6f105aaa34a70a` | `a70d7ed30db3c008f4ad65bab00a4d87268bf6ddc0d9cf5f50c49ea1a3fe685b` |

Backup path: `C:\work\LuaPadModern\backups\luapad-preview19-before-hotcopy-20261104-083424`.

**No RIFT focus, game keyboard/mouse input, `/reloadui`, game restart or SavedVariables write occurred in this Preview 19 release/deployment workflow.** The running game continues using Preview 18 until Joey independently reloads RIFT UI or normally launches the game.

## Historical follow-up checklist (partly superseded by later user report)

1. **Only when convenient during safe gameplay**, Joey enters `/reloadui` in RIFT or restarts the game normally; no assistant-initiated input without Joey's separate permission.
2. Confirm the title says `LuaPad v2.0.0-preview19` and LuaPad appears automatically **without `/lp`**.
3. Capture a fresh full-client screenshot with `RR2 CAST` and `RiftReader API Readiness` visible. **Pass** only if LuaPad is visually above those addons, with title, toolbar, code editor and output unobscured.
4. Deliberately close LuaPad; use `/lp` to reopen and confirm it returns to front. Test after opening/closing a native game dialog, and with Inspector open.
5. If layering passes, validate a small inert ASCII editor Enter/Tab/selection test and verify focus separately from Windows HWND/foreground. Do not assume visual visibility proves typing is safe.
6. If layering fails or a native dialog becomes unusable, preserve screenshot and version; consult the exact Preview 18 backup hashes before any guarded rollback. Do not blindly overwrite unrelated addon changes or restore SavedVariables.

## Evidence references

- Preview 18 historical checkpoint: [P1-STARTUP-VISIBILITY-STACKING-PREVIEW18-2026-11-04.md](P1-STARTUP-VISIBILITY-STACKING-PREVIEW18-2026-11-04.md)
- UI readiness and focus gate: [UI-FOCUS-AUTOMATION-GATE-2026-11-04.md](UI-FOCUS-AUTOMATION-GATE-2026-11-04.md)
- Historical RIFT API docs: https://www.seebs.net/rift/pts/frame_getstrata.html and https://www.seebs.net/rift/pts/frame_setlayer.html
- Historical RIFT native dialog context ordering notes: https://www.riftui.com/forums/showthread.php?t=217
