# LuaPad Preview 2 — deployment checkpoint (2026-11-03)

## Outcome

- Physical Windows RIFT client: **running** throughout this deployment.
- Live updated addon folder: `C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns\luapad`.
- Only two files were copied into the active folder: `main.lua` and `RiftAddon.toc`.
- Copy completed at **15:18:16 America/New_York**, 2026-11-03.
- New code will not execute until Joey chooses `/reloadui` in game. **In-game acceptance is pending**.
- No exit, process termination, game input, or change to account SavedVariables was performed.

## Features

1. `main.lua` uses `Inspect.Addon.Detail("LuaPad").toc.Version` as the runtime title/help version source, with fallback to `toc.version` and finally `unknown` if API metadata is unavailable.
2. Window title reads `LuaPad v<metadata version>` both during initialization and on reopening with `/lp`.
3. Startup prints `[LuaPad v<metadata version>] READY - type /lp to open; Copy Output exports errors to clipboard.` in RIFT chat on successful initialization. Startup failures produce a chat warning.
4. A new `Copy Output` button copies displayed output/errors using `Command.CopyToClipboard`, with a chat notice for unavailable clipboard or empty output.

## Recovery assets

- Original LuaPad 1.8 addon: `C:\work\LuaPadModern\backups\luapad-before-preview-20261103-145801`
- Original account SavedVariables: `C:\work\LuaPadModern\backups\LuaPad-SavedVariables-20261103-145801`
- Preview 1 before-hot-copy backup: `C:\work\LuaPadModern\backups\luapad-preview1-before-hotcopy-20261103-151815`
- Previous initial deployment notes: `DEPLOYMENT-2026-11-03.md`

## Checksums

| File | Preview 1 installed before copy | Preview 2 source and installed after copy |
| --- | --- | --- |
| `main.lua` | `dfb4a8f37d5a7c176f35eaadaf10355731f30029c31e385bf30ee9e7931ad06d` | `10816c5ac97d9ee743bce72bc00cca0d00882ff8ef7c098d4b75346235fad1b3` |
| `RiftAddon.toc` | `03814c7887513c1a39ec778b6c6ba03d2a493d19cec32458a04bcdb5bf282157` | `80f37417c7653cc70f740caa64cceb4ab8d38a5159f711814a5d2071679d3e41` |

The hot-copy command verified **both old installed hashes before modification**, backed both up with checksum verification, copied both new files, and independently verified both installed hashes. It was configured to restore the backup if the copy or hash check failed. Command completed with exit code 0.

## Tests

- `node.exe verify-preview.cjs`: **25/25 passed**; exit code 0.
- `npm exec --package=luaparse@0.3.1 -- luaparse main.lua`: **PASS**; exit code 0.
- Zip: `LuaPad-2.0.0-preview2.zip`, SHA256 `a3be822332e63031d8e1b792b7ff6716a241b69727c2e705443a597224ea160b`.
- ZIP/source parity: **15/15 entries matched**, mismatches 0.
- In-game title, chat init, clipboard transfer: **not yet tested**.

## Manual next step

1. In physical RIFT (at a safe gameplay moment), type `/reloadui`.
2. Expect `[LuaPad v2.0.0-preview2] READY` in chat; type `/lp` and verify exact window title.
3. Run `error("LuaPad clipboard test")`, click **Copy Output**, paste into Notepad or ChatGPT. Verify full error content is preserved.
4. If title is `unknown` or error occurs, preserve screenshot/chat and stop. Investigate `Inspect.Addon.Detail("LuaPad")` in that RIFT client.
5. For rollback to Preview 1, use the preserved two-file backup after validating installed Preview 2 hashes; then issue `/reloadui`. This can be done without exiting if both files remain matchable. Full LuaPad 1.8 rollback has separate guarded steps and requires normal game exit.

No in-game acceptance gate is marked passed solely because deployment succeeded.
