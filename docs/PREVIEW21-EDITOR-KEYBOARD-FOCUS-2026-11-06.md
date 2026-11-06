# LuaPadModern Preview 21 — explicit editor keyboard focus

Date: 2026-11-06, America/New_York. Owner: Joey Delfierro.
Scope: physical RIFT Live x64; independent of VMware lab addons.
Status: **source/tests PASS; physical installed-byte hot-copy and Joey's /reloadui PASS; centered/initial-unfocused status PASS; click/key-focus acceptance PENDING**.

## User-visible result

- LuaPad still auto-opens centered/front on RIFT startup or /reloadui.
- Startup and ordinary /lp reopen do **not** request keyboard focus, protecting normal game controls.
- A compact, clickable status above the editor reads `Editor: Click to focus`, `Editor: Focused`, or `Editor: Unavailable`.
- A deliberate click on the status or the code-editor body requests `RiftTextfield:SetKeyFocus(true)`. The status turns focused **only after** `GetKeyFocus()` returns true.
- Native focus gain/loss events refresh the status if the installed client supports them. Missing optional focus events or rejected setter calls fail without an unhandled addon exception. On Close, the editor releases key focus.
- `LuaPad.GetEditorFocusStatus()` returns true/false from the actual field when visible; returns nil for hidden or unavailable. This is **addon-side** evidence only. The Windows host must still independently verify RIFT foreground, exact PID/HWND/session, geometry, screenshot occlusion and freshness.
- The existing native `RiftTextfield.Event:KeyDown` Enter/Tab handler is retained. Existing code and SavedVariables formats are unchanged.

## Evidence and regression

- Reproduced a **red** mock test on Preview 20: `FAIL focus badge is visible and labeled`. Fengari may exit 0 even with a Lua stack traceback, so the strict runner checks the output sentinel and absence of errors.
- Preview 21 green mock: `162/162` assertions, including explicit badge/body click, true read-back, lost focus, a throwing/rejected setter, close release, no implicit /lp focus, Enter/Tab and Inspector regressions.
- `node verify-preview.cjs`: 60/60 structural checks PASS.
- `node verify-bridge.cjs`: 496/496 across 6 suites (39 + 40 + 70 + 165 + 162 + 20) PASS.
- `node verify-host.cjs`: 113/113 source-only host checks PASS.
- Historical primary RIFT API: [GetKeyFocus](https://www.seebs.net/rift/pts/rifttextfield_getkeyfocus.html), [SetKeyFocus](https://www.seebs.net/rift/pts/rifttextfield_setkeyfocus.html), [native KeyDown](https://www.seebs.net/rift/pts/rifttextfield_event_keydown.html), [UI focus events](https://www.seebs.net/rift/pts/UI_index.html). The Live client may differ.

## Guarded physical deployment

- Target: `C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns\luapad`.
- Before and installed Preview 20 exact hashes: main.lua `34bf8d962c700862f655d5c60c58e5a76a01ca8c3c26eb4299e55a38ed5f6e59`; RiftAddon.toc `b3caba8124274cb744f693f727726edc5cbb3ff38733158eae511bed90a4d11b`.
- Preview 21 exact hashes: main.lua `3a94c7909e91913c79a1c89d41a5d6ec3098275a9f845d3afb9fde0323fb3e97`; RiftAddon.toc `f136c3feaeea88264342eae8931b32adf0390e47f86007cc8b10fdcda84cc3dd`.
- `deploy-preview21.ps1` default dry-run validated both pairs. A guarded `-Apply` hot-copy backed up and replaced **only** these two files; it did not interact with RIFT or any saved variables.
- Rollback: `C:\work\LuaPadModern\backups\luapad-preview21-before-hotcopy-20261106-024630`.
- The game has not performed /reloadui since this hot-copy. Loaded Live addon remains Preview 20 until next normal UI reload/restart.

## Physical reload acceptance — 2026-11-06T07:49:24Z

- Joey manually performed a physical-RIFT `/reloadui`. This did not restart Windows or the RIFT process.
- Workbridge independently found `rift_x64` PID **32156**, HWND **462734**, class `TWNClientFramework`, window 1936×1048.
- Exact physical screenshot request `luapad-preview21-live-postreload-20261106-01`: 1920×1032 pixels, SHA-256 `50cec251b1c7d4d51a7c15dd98b6526a7bdd15c5890897d2ca415e09783355ea`, captured at 07:49:24.069Z; `inputInjected:false`.
- Screenshot visually confirms `LuaPad v2.0.0-preview21 | by Joey Delfierro`, centered/front over competing panels, with blue `Editor: Click to focus` visible and blank editor/output. **Initial unrequested focus state PASS**.
- This proves the client loaded Preview 21 and displays an unfocused badge. A green focus transition and actual keyboard text remain **unverified** until someone clicks the badge/editor and returns a fresh capture. The host screenshot alone cannot read the RIFT textfield getter.

## Physical acceptance — pending

1. If there is unsaved code in LuaPad, save it first. Execute a normal user `/reloadui` in physical RIFT. Avoid clearing or reusing Workbridge's already-consumed reload singleton; its prior receipt is durable and must not be reset as a workaround.
2. Capture exact physical PID/HWND and screenshot. Check `v2.0.0-preview21`, auto-centered/front window and **unfocused** badge state.
3. With the correct RIFT window foreground, click `Editor: Click to focus` once; confirm the badge turns `Editor: Focused` and record screenshot/time/hash. Separately confirm read-only `LuaPad.GetEditorFocusStatus()` if the in-game console is accessible. The badge alone is not Windows host readiness.
4. Click editor body, enter a short harmless marker, Enter and Tab. Confirm actual editor text and caret semantics; do not select Save or Run. Clear the marker without overwriting any existing snippet.
5. Click another RIFT control to check focus-loss transition and close/reopen via /lp to check no stolen keyboard focus. Re-check visible focus status. Stop on a mismatched version, modal/overlap, stale geometry or unexpected active game controls.

**No generic desktop automation or live keyboard-input readiness is claimed until these receipts pass.**
