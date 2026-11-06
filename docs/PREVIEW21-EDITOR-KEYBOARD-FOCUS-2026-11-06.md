# LuaPadModern Preview 21 — explicit editor keyboard focus

Date: 2026-11-06, America/New_York. Owner: Joey Delfierro.
Scope: physical RIFT Live x64; independent of VMware lab addons.
Status: **all Preview 21 editor focus/typing/focus-loss physical acceptance PASS; Windows-host autonomous input readiness remains separate and unverified**.

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

## Physical focus click acceptance — 2026-11-06T07:57:05Z

- Joey deliberately clicked the dark code editor in Preview 21. His supplied screenshot shows a visible caret at the top-left of the empty editor and the status text changed to green `Editor: Focused`.
- Independent Workbridge physical-RIFT capture of the same running process `rift_x64` PID **32156**, HWND **462734**, verified the green `Editor: Focused` text and unchanged centered/front editor. Request `luapad-preview21-focus-click-post-20261106-01`, 1920×1032, SHA-256 `f1531dba40b079cc8413b6b84fb54dfdca93aaacfef785d428375929cda1b0b0`, 07:57:05.774Z. Workbridge injected **no keyboard/mouse input**.
- The green status is reached only when the Live addon queries `RiftTextfield:GetKeyFocus()` and observes `true`. This is **live addon-side focus PASS**; it is not independent host proof that the Windows RIFT window is foreground, nor does a screenshot prove text keys were delivered.
- Follow-up: enter harmless text + Enter/Tab, check loss transition, and independently verify fresh host foreground/bounds at the instant of any future automated input.

## Physical text entry acceptance — 2026-11-06T08:02:12Z

- Following a user click in the editor, Joey manually typed the short A/Enter/B/Tab/C marker. RIFT's rendered text appears in lowercase as two lines, `a` and `b  c`, with a visible two-space indentation before `c`. This verifies the newline and Tab-to-spaces insertion behavior visually; case of the test characters differs from the suggested uppercase sequence, without changing the focus/spacing conclusion.
- Independent Workbridge capture of the exact physical process `rift_x64` PID 32156, HWND 462734: request `luapad-preview21-keys-abc-post-20261106-01`, 1920×1032, captured 08:02:12.789Z, SHA-256 `af75ad919da0c5d6eac831e2fbe424479f04d81112e707baf3729295bdeafe9b`, `inputInjected:false`. LuaPad still displays green `Editor: Focused`.
- **Live PASS** for regular character entry, Enter/newline, Tab/spaces, and retained editor focus across those keys. The screenshot proves visible layout, but exact bytes of the spaces were not read through an in-game API.
- Subsequent focus-loss test also passed (see next section). Marker remains unsaved and can be removed using the editor's normal selection/delete controls.

## Physical focus-loss acceptance — 2026-11-06T08:06:10Z

- Joey deliberately clicked outside LuaPad in the physical RIFT game world. His screenshot shows the status returned from green `Editor: Focused` to blue `Editor: Click to focus`; the two-line `a` and `b  c` marker remains intact and unsaved.
- Independently captured the exact running RIFT process, PID 32156 / HWND 462734, 1920×1032 at 08:06:10.390Z. Request `luapad-preview21-focus-loss-post-20261106-01`, SHA-256 `aa92e409658e70d1445c222b9720a8223747794d2f8da73ff79a9d66543ddff8`, `inputInjected:false`. The indicator is visibly blue `Editor: Click to focus`, and LuaPad remains centered and above other addons.
- **Live PASS:** RIFT native key-focus loss is reflected in the status indicator while editor text is preserved. The prior green state was established through the Live addon `GetKeyFocus()` getter.
- Remaining independent work: host-side exact HWND/foreground + occlusion + runtime focus cross-correlation before automated input. No generic automated input capability is claimed.

## Physical acceptance checklist and remaining host work

- [x] Physical `/reloadui` loads Preview 21 while preserving the RIFT process.
- [x] Centered, unobscured startup and initial blue non-focused indicator.
- [x] Clicking editor turns indicator green; `GetKeyFocus()`-backed state.
- [x] Regular characters, Enter and Tab visually work in Live.
- [x] Clicking outside returns the indicator to blue without changing editor text.
- [x] Prior close then `/lp` reopen/front-order acceptance was verified on Preview 20; Preview 21 preserves the path in mock tests.
- [ ] Read-only runtime focus state bridged to Windows host with independent receipt.
- [ ] Fresh Windows foreground, PID/start/HWND/session, geometry and screenshot occlusion jointly verified at actual input time.
- [ ] Host-controlled safe editor text input after full readiness gates; no generic input capability claimed.
- [ ] Clear the temporary unsaved `a` / `b  c` marker when convenient.

**Scope boundary:** Native addon keyboard focus is now verified. This does not, by itself, authorize the Windows host to send arbitrary keys or establish generic automation readiness.
