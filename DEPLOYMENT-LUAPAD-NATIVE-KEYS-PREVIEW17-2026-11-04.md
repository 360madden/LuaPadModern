# LuaPad Preview 17 — native Enter/Tab dispatch (2026-11-04)

## Physical RIFT reproduction
- Game: physical RIFT Live x64, PID 18056 / HWND 0x640A18. No VM used.
- User manually loaded Preview 16 with `/reloadui`. Assistant later obtained permission for limited editor mouse/keyboard input, focused the exact RIFT window, opened `/lp` and used guarded Windows key/mouse injection.
- In the Code Editor, typing `a` worked. Sending Enter then `b` resulted in `ab` on one line rather than a newline.
- Sending Tab then `c` resulted in `abc` with no two-space indentation.
- Evidence screenshots (actual 1920x1009 RIFT client): Enter failure SHA256 `10f9dd1e0476912e2b57793dd0d49584c2359ffe71d7adc97cde96994f8367d5`, Tab failure SHA256 `91708e300b595e2d94801585c67262d9225525fa5850a82730df89090693c237`. Captured by `C:\work\Rift API\scripts\rift_visual_gate.ps1`.
- RIFT process was not restarted; no gameplay input, movement, combat or live UI reload occurred during the tests.

## Cause and repair
- Preview 15/16 attached `Event.UI.Input.Key.Down` to a RiftTextfield. Synthetic tests called that callback and passed, but the physical editor did not receive Enter/Tab through that path.
- The original LuaPad registered `function inputField.Event:KeyDown(button)`; the RIFT API lists `RiftTextfield.Event:KeyDown` and `GetEventTable`, which exposes the default `Event` property. Reference: https://www.seebs.net/rift/pts/index.html .
- Preview 17 restores the textfield-native handler, accepting ASCII CR/LF/Tab and named Return/Enter/Tab forms; retains selection replacement and cursor restoration; calls `SetKeyFocus(true)` before replacing text.
- The generic key handler is removed to avoid conflicting or duplicate insertion. The `Event.UI.Textfield.Change` resize callback remains unchanged.

## Source verification
- Structural check: **56/56 PASS** via `node verify-preview.cjs`.
- Fengari combined LuaPad + Inspector runtime mock: **128/128 PASS**, including native `Event:KeyDown` ASCII, named keys, selection replacement and key-focus checks.
- A mock is not physical acceptance. Preview 17 has not been reloaded in the live RIFT process.

## Installed update
- Source repo: `C:\work\LuaPadModern`.
- Installed addon: `C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns\luapad`.
- Guarded two-file hot-copy updated `main.lua` and root `RiftAddon.toc` only; exact source and installed hashes verified after copy.
- `main.lua`: old `6a92d2e9b40988fcc6ca472236d4332225f2cedec53b4c3313e3708ed14ed037`; new `d4af7af2938901812c80e4ba57bc870d46f06e0f6e0f8397d922828b962098be`.
- `RiftAddon.toc`: old `fa6318a1c4646ff73affb4a2933cc9c617ab72f7e6d5ea8c7e9c540a32d1a042`; new `3a7f739103f7ac9837427285573313312be4931c960fb42dde5c929c9c53b562`.
- Rollback copies: `C:\work\LuaPadModern\backups\luapad-preview17-before-hotcopy-20261104-0939-nativekeys`.
- Release archive: `C:\work\LuaPadModern\LuaPad-2.0.0-preview17.zip`; 16/16 entries source-hash verified; SHA256 `2dec9a1e85e53f482149ecbdd3635e48f2d7d49c3756a5cb302e4c3c49d169e2`.
- **No automatic `/reloadui`**: the limited live-test authorization explicitly excluded it. The currently loaded addon remains Preview 16 until the user authorizes or manually performs a reload.

## Next live gate
After a safe, authorized `/reloadui`, verify window title `LuaPad v2.0.0-preview17`; use the same guarded key/mouse input to type `a`, Enter, `b` (two lines), then Tab, `c` (two spaces), and capture screenshots. If this still fails, collect exact `KeyDown` event payloads before another code change. See LP-47 through LP-50 in `TEST-PLAN.md`.
