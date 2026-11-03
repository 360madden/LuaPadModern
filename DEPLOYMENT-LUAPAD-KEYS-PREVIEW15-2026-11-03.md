# LuaPad editor key callback hardening — Preview 15 (2026-11-03)

## Release
- LuaPad `2.0.0-preview15`, Inspector unchanged at `1.9.0-preview5`.
- Project `C:\work\LuaPadModern`; physical AddOns folder `C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns\luapad`.
- Files hot-copied with hashes and backups; **physical RIFT has not been reloaded**. No game input, focusing, window manipulation, termination, or reload was performed.

## API evidence and reproduced failure
The community RIFT API documentation for `RiftTextfield:EventAttach` describes frame-event callbacks as `(frame, eventHandle, ...eventArgs)`. `Event.UI.Input.Key.Down` supplies the key as its event argument. Source: https://github.com/chrisbecke/Igor/wiki/RIFT-API-Documents (sections `RiftTextfield:EventAttach` and `Event.UI.Input.Key.Down`).

The editor used `function(_, key)` in a frame-attached callback. It treated the event handle as the pressed key and did not recognize `tab` or `return` when the documented three-argument signature arrived. A real-source Fengari regression invoking `editor._events[Event.UI.Input.Key.Down](editor, Event.UI.Input.Key.Down, "tab")` reproduced the failure in red.

Changed handler to `function(_, eventOrKey, extraKey)` and read `extraKey or eventOrKey`, which supports documented three-argument frame events as well as two-argument mocks/clients. Regression checks assert Tab inserts exactly two spaces and moves the cursor, Return inserts exactly one newline, ordinary `q` does not invoke manual insertion, and the two-argument form remains compatible.

**Live-game caveat:** these tests establish the callback argument fix in a RIFT-shaped widget mock, not the native textfield's built-in event propagation or insertion order. Actual duplicate-character behavior must be checked by Joey after manually reloading.

## Validation
- Runtime regression suite: **120/120 assertions passed**, red → green.
- Structural validation: **55/55 checks passed**.
- `luaparse@0.3.1`: **9/9 Lua files passed**.
- `git diff --check`: passed (non-error CRLF normalization warnings).
- Archive `LuaPad-2.0.0-preview15.zip`: **16/16 entry hashes match source**, SHA256 `45a36e050bd1da2b56fed242957ed5110fff129c1c083b187fb5c860c46fede5`.

## Guarded hot-copy
- `main.lua`: old Preview 14 installed SHA256 `54a48364d8ef28cb148e2a3f22bfb7757d3eec0de06d12991544355f1a8b73c2`; new source/installed SHA256 `2785ec9841aa9b4d842057211a654b65a518895afe74abd778d5ee611fcc88fd`.
- `RiftAddon.toc`: old SHA256 `53e37dcc8103baf0b578a38abb0873bb244d002847259452784e7169b378cab9`; new source/installed SHA256 `b7c31851de9c53f70ddca34cec7741e6a0cc0d503bb6a3c6dce202a2f5a3f7a6`.
- Verified rollback at `C:\work\LuaPadModern\backups\luapad-preview15-before-hotcopy-20261103-184647`.
- The guarded update refused unrecognized old hashes, verified backup bytes before overwriting, verified both installed hashes, and would attempt rollback on any error.
- Inspector source/TOC were not modified.

## Pending manual acceptance
At a safe time Joey can enter `/reloadui`, verify LuaPad v2.0.0-preview15, then perform LP-41–LP-43 in `TEST-PLAN.md`. Test Tab/Return **mid-line** and subsequent normal typing. Observe whether native RiftTextfield also inserts a newline; any duplicates require investigation before marking the gate complete. Earlier pending gates remain pending.
