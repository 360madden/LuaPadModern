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
- Mock results preceded the physical test. **Preview 17 now also passes physical RIFT Enter/Tab and ASCII selected-text acceptance after a separately authorized `/reloadui`.**

## Installed update
- Source repo: `C:\work\LuaPadModern`.
- Installed addon: `C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns\luapad`.
- Guarded two-file hot-copy updated `main.lua` and root `RiftAddon.toc` only; exact source and installed hashes verified after copy.
- `main.lua`: old `6a92d2e9b40988fcc6ca472236d4332225f2cedec53b4c3313e3708ed14ed037`; new `d4af7af2938901812c80e4ba57bc870d46f06e0f6e0f8397d922828b962098be`.
- `RiftAddon.toc`: old `fa6318a1c4646ff73affb4a2933cc9c617ab72f7e6d5ea8c7e9c540a32d1a042`; new `3a7f739103f7ac9837427285573313312be4931c960fb42dde5c929c9c53b562`.
- Rollback copies: `C:\work\LuaPadModern\backups\luapad-preview17-before-hotcopy-20261104-0939-nativekeys`.
- Release archive: `C:\work\LuaPadModern\LuaPad-2.0.0-preview17.zip`; 16/16 entries source-hash verified; SHA256 `2dec9a1e85e53f482149ecbdd3635e48f2d7d49c3756a5cb302e4c3c49d169e2`.
- Reload authorization changed later in the session: Joey explicitly approved one `/reloadui` and assistant-operated editor tests. The UI reloaded successfully without restarting RIFT.

## Physical Preview 17 acceptance (after authorized /reloadui)
- The assistant closed the Preview 16 LuaPad window, sent `/reloadui` once through the game chat and reopened `/lp`. Screenshot showed `LuaPad v2.0.0-preview17` with no blocking initialization error (SHA256 `fffb5bad875833fea50ec74e424e705d1f5a9b1c4855ea88949505ac4cc2d35b`).
- The assistant clicked inside the blank editor and sent `a`, Enter, `b`, Tab, `c` through guarded Windows input. Screenshot SHA256 `b41d508b4fe84a79c5913de873ede38b9e49e3d825f49b975e52cbf64f5bcee8` shows `a` on line 1 and `b  c` on line 2: newline plus two-space indentation; no duplicate characters.
- Additional ASCII selection test: Ctrl+A, Tab, `Z` replaced all highlighted text with indentation plus `Z`; screenshot SHA256 `d53278725e3297447624ad50e2e4ab7e04d147ddebd0488bf8d32588441441c0`.
- More precise mid-line test: typed `abcd`, selected final `cd` with Shift+Right, sent Enter then `X`; screenshot SHA256 `1d9b79f2b09c16ebf1a3f2c908da99bb39799068ef70e80d73603a2a05f80b1d` shows `ab` on line 1 and `X` on line 2. Ordinary typing and cursor restoration were intact.
- Temporary unsaved test text was cleared by Ctrl+A/Delete; no snippet was saved, no character movement/combat was sent, and RIFT stayed running on PID 18056. Unicode selection indices and a nonselection mid-line Tab insertion remain open test cases.
