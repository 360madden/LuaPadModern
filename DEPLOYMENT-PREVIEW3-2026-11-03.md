# LuaPad Preview 3 — toolbar layout deployment checkpoint

Date: 2026-11-03, 15:26:44 America/New_York.

## User feedback and correction

Joey provided a physical RIFT screenshot of Preview 2. The window title correctly read `LuaPad v2.0.0-preview2` (evidence that metadata-based title worked), but the new Copy Output button was orphaned at the bottom of the window and Code Snippets text overlapped the top Help button. The overall toolbar/header layout lacked consistent alignment.

Preview 3 changes `main.lua` and `RiftAddon.toc` only:

1. One ordered toolbar occupies x=32..532, y=48, aligned to the 500-pixel-wide editor. The seven controls have heights of 28 pixels and share a common `modernButton` constructor: Run 58, Inspect 68, Save 58, Load 58, Clear 58, Help 58, Copy Output 112, with six 5-pixel gaps. Total width `58+68+58+58+58+58+112+6*5 = 500`.
2. `Copy Output` now occupies the top-row end, not y=570 at the window bottom. Its native clipboard implementation remains unchanged.
3. Code Snippets heading anchors at x=554, y=48, leaving at least 22 px between it and the toolbar end. Code Editor, Output, and Code Snippets headings now share a 12-pixel pale-cyan text style.
4. TOC version is `2.0.0-preview3`; title/help/chat read it dynamically from `Inspect.Addon.Detail`, unchanged.

## Safety and deployment

- Physical RIFT process was **running** and was **not stopped, restarted, or focused** by the deployment.
- Installed physical addon: `C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns\luapad`.
- Original 1.8 backup remains at `C:\work\LuaPadModern\backups\luapad-before-preview-20261103-145801`.
- Preview 2 `main.lua` and `RiftAddon.toc` safely backed up to `C:\work\LuaPadModern\backups\luapad-preview2-before-hotcopy-20261103-152644`.
- Hot-copy preflight required installed Preview 2 source checksums; validated Preview 2 backups before copying. Destination checksums after copy exactly matched Preview 3. The command had recovery logic for copy failures.
- No SavedVariables, other addons, VM images, or game state were changed.
- Final code-cleanup hot-copy at 15:30:58 ET removed redundant initial button placements and trailing whitespace without changing the layout or behavior. The initial Preview 3 main.lua was backed up at `C:\work\LuaPadModern\backups\luapad-preview3-before-codecleanup-20261103-153058`; the final main.lua installed hash is recorded below. RIFT remained running.
- `/reloadui` must be issued by Joey in-game to activate Preview 3. Visual acceptance of Preview 3 is **pending**.

| File | Preview 2 before copy | Preview 3 installed and source |
| --- | --- | --- |
| `main.lua` | `10816c5ac97d9ee743bce72bc00cca0d00882ff8ef7c098d4b75346235fad1b3` | `81030e95f23c1f11ec7c9ddfc0fbebd9b4760a650c3348eccf311531d6774c34` |
| `RiftAddon.toc` | `80f37417c7653cc70f740caa64cceb4ab8d38a5159f711814a5d2071679d3e41` | `6964316872bdde7e9eaf34bec489e1309ae499b6011119a0925267d6dcb119e0` |

## Validation

- `node.exe verify-preview.cjs`: 27/27 structural checks passed.
- `luaparse@0.3.1` parsing `main.lua`: PASS.
- `LuaPad-2.0.0-preview3.zip` SHA256 `16798ad85bd3124cfb1594d99a0f8defddc4fe1983cf07c31431d76155e4fb52`.
- 15/15 ZIP contents SHA256 matched source, no mismatch.
- Visual runtime verification of button alignment, hover, clipboard, and startup chat remains pending.

## Next acceptance steps

1. Joey types `/reloadui` without exiting RIFT.
2. Joey types `/lp`, sees `LuaPad v2.0.0-preview3`.
3. Confirm Copy Output is in the top toolbar and all 7 buttons are aligned; snippet heading is unobscured.
4. Run a deliberate Lua error, click Copy Output, paste to verify native clipboard behavior.
5. If regressions occur, preserve the screenshot/error. A hash-guarded two-file revert to the backed-up Preview 2 followed by `/reloadui` is possible without normal game exit. For complete LuaPad 1.8 restoration use the separate guarded restore script only after normal game exit.

Do not mark in-game acceptance as passed from package/deployment checks alone.
