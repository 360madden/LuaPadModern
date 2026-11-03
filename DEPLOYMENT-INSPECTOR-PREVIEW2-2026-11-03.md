# Inspector v1.9.0-preview2 / LuaPad v2.0.0-preview5 — 2026-11-03

## User-reported failure (physical RIFT)
After Preview1 installation and /reloadui, clicking Inspector's Inspect button printed repeated chat errors:
  "[Inspector] Inspector button InspectorInspectButton: Inspector/main.lua:214: bad argument #2 to 'tonumber' (number expected, got boolean)"
Joey supplied screenshots showing the error and visible Inspector layout.

## Confirmed root cause
RIFT's Text:GetText() returns TWO values: (string, boolean HTML flag).
The Preview1 handler called:
  Inspector.doInspection(inputField:GetText(), tonumber(depthText:GetText()))
Lua expands all return values of the last function call within argument position, so tonumber received both text and boolean as its two parameters. The second parameter is a numeric conversion base, causing the runtime error. The RiftTextfield getter and RiftSlider:GetPosition() return one value each. API reference: https://github.com/chrisbecke/Igor/wiki/RIFT-API-Documents (Text:GetText, RiftTextfield:GetText, RiftSlider:GetPosition).

Fix: pass depthSlider:GetPosition() as numeric depth directly to Inspector.doInspection, with existing numeric clamp/round in doInspection. The displayed depth label is informational, never reparsed.

## Deeper prevention
- Added a runnable RIFT UI mock using Fengari: inspector-runtime-tests.lua. Its Text:GetText() mock returns (string, false), exactly exposing this Lua multi-return bug.
- Before the fix, the mock reproduced the identical boolean-to-tonumber error at Inspector/main.lua:214; after the fix, Inspect and clipboard work.
- Extended mock tests to cover compile/runtime errors, blank/incomplete inputs, semicolons, depth clamping and expansion, Help and action geometry, hover/press, clipboard unavailable/rejected, zero output, shared-vs-cyclic tables, large table/long output bounding, output scroll reset, closing/reopening.
- Any future inspector button callback exception is now displayed in copyable results and separately logged in chat, rather than trapped only in unselectable chat.
- Verified RIFT Main LuaPad uses Text:GetText in single-result contexts, avoiding the same bug pattern.

## Verification commands
- node verify-preview.cjs
- npm exec --yes --package=luaparse@0.3.1 -- luaparse Inspector/main.lua
- npm exec --yes --package=fengari-node-cli -- fengari inspector-runtime-tests.lua

These tests simulate RIFT APIs; they do NOT prove rendering and live-game compatibility. Runtime screenshot acceptance is still needed.

## Verified release receipt — 16:15 ET
- 46/46 Fengari mock assertions PASS (with documented RIFT Text:GetText two-return behavior); 40/40 structural checks PASS; Inspector Lua syntax PASS.
- The old Preview1 mock reproduced the exact reported boolean-to-tonumber error before modification.
- SHA256 verified archive: LuaPad-2.0.0-preview5.zip, 16/16 entry parity, cad06122b0c0e0631c4b861f5c280c2f83d7b954b41c2df798c2fec8d3f51293.
- Source to physical installed files verified 3/3:
  - Inspector/main.lua: 6441b15e4b8c342e76d7921027484d8bf93c512829abd5061faa4cc3ebd7b428
  - Inspector/RiftAddon.toc: 33048c9d8167d7159b2062b4f065b28f715c9200077edb64e7815ec74b2ae229
  - RiftAddon.toc: b68f70062e9219131b401fedb7821461e73602ab58b29f87027838bdbdcd50c7
- Recoverable backup: C:\work\LuaPadModern\backups\luapad-preview5-before-hotcopy-20261103-161504.
- No game focus, close, reload or capture was initiated; /reloadui remains a manual action and live acceptance is pending.

## Installation safety
Change scope: Inspector/main.lua, Inspector/RiftAddon.toc, root RiftAddon.toc; documentation and test files remain in repository. Back up each installed file, compare original/source hashes, copy three files, then verify installed/source hashes. Leave RIFT running, never focus or reload it from tooling. Joey should use /reloadui when convenient to load the fix. Restore files from timestamped backup if any in-game regression.
