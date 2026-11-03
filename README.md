# LuaPad 2.0 preview 2 (physical-PC RIFT)

Source: copied from installed LuaPad 1.8 on 2026-11-03. Preview 1 was installed to physical RIFT AddOns at approximately 14:58 ET on 2026-11-03, after the game exited normally. Original addon and three account SavedVariables files were backed up. See DEPLOYMENT-2026-11-03.md. Preview 2 is an incremental two-file update that can be copied into the active addon while RIFT remains open; `/reloadui` is needed to load new Lua code.

## Changes
- Replaced six legacy RiftButton controls with ordinary RRECollector-inspired buttons (hover, pressed offset, cyan/dark palette), aligned in one compact top strip. The layer ordering now explicitly matches RRECollector (fill 0, borders 1, caption 3), with cyan hover labels.
- Converted snippet selection and close actions from legacy callbacks to EventAttach.
- Updated Inspector's four controls to the same plain button style.
- Inspector now allows quoted Lua arguments, reports compile/runtime errors, limits traversal to five levels/300 nodes, and uses an explicit Inspect action with a matching 1–5 depth slider.
- Replaced the old window drag fallback that could place a mouse-intercepting overlay over the editor.
- Switched editor keys/text changes, Inspector slider changes and scrollview wheel/layout/scrollbar events to RIFT EventAttach APIs. Inspector now evaluates only when Inspect is pressed, not on each keystroke.
- Removed LibSimpleWidgets' global UI.CreateFrame monkey-patch; both addons use direct widget constructors.
- Handles Lua compile errors separately from protected runtime execution; compiler lookup and compilation are guarded, with traceback if available.
- Makes startup initialization failures visible in RIFT chat instead of silently swallowing them.
- Handles multi-argument print output and bounds editor output length.
- Fixes multiline input height calculations; previews only the first line of saved snippets.
- Replaces unfinished Help placeholder with instructions.
- Uses the known working Environment 4.4 from RRECollector on this physical host.
- Preview 2: **Copy Output** under the output pane copies all displayed output (including syntax/runtime errors) to the Windows clipboard using native `Command.CopyToClipboard`.
- Preview 2: title and Help show `Version` read dynamically from `Inspect.Addon.Detail("LuaPad").toc`, with `RiftAddon.toc` the single source of truth. There is no hardcoded display version.
- Preview 2: initialization posts `[LuaPad v<version>] READY` in game chat, or an error notice if a startup step fails.

## Current limitations / next gates
- Lua syntax parsed successfully for all 9 .lua source files on 2026-11-03 using luaparse 0.3.1 through npm exec (9/9). Syntax validity does not establish RIFT API/runtime compatibility.
- Preview 1 UI and Run were observed in physical RIFT on 2026-11-03: Joey provided a screenshot and confirmed corrected print code runs. This does not verify every UI action or Preview 2's new clipboard/version/chat behavior. Embedded SimpleWindow, RiftTextfield, SimpleScrollView and Inspector dependencies remain.
- Global print interception is scoped to each Run operation and restored afterward; printing was observed in game. Multi-line prints, long output, and traceback remain acceptance tests.
- LuaPad 1.8 is now preserved in a timestamped backup; the preview occupies the single active folder named **luapad**. Do not load two copies simultaneously.
- SavedVariables are account-wide. The guarded installer now creates per-account LuaPad.lua copies before it touches the installed addon (three account files were found on this physical PC). Keep these backups; the rollback script does not silently overwrite live SavedVariables.
- Preview 2's active-game two-file copy is a non-destructive hot update, but the new code only loads after `/reloadui`; avoid reloading UI during critical gameplay.

## Verified preview packages
- **Preview 2**: `verify-preview.cjs` passed 25/25 structural checks; `main.lua` passed `luaparse@0.3.1` syntax parse. These checks do **not** establish in-game API behavior.
- `LuaPad-2.0.0-preview2.zip`: SHA256 `a3be822332e63031d8e1b792b7ff6716a241b69727c2e705443a597224ea160b`. All 15 archived files matched their source SHA256 (15/15, zero mismatches).
- **Preview 2 live hot copy**: installed on 2026-11-03 at 15:18 ET while RIFT was running. `main.lua` and `RiftAddon.toc` matched source hashes after copying. Preview 1's two files are backed up. See `DEPLOYMENT-PREVIEW2-2026-11-03.md`. `/reloadui` and in-game acceptance remain pending.
- **Preview 1 archive**: `LuaPad-2.0.0-preview1.zip` SHA256 `6ba06d8da226196e2cefdb01f82255b7b94302dee20f3acec9cbac3cd8b14c3e`. Its 15 files matched source on initial installation. Preview 1 was verified by Joey in physical RIFT.

## Guarded installation
The full installer remains intended for initial installation with RIFT closed. For the already-installed Preview 1 to Preview 2 update we used a bounded two-file backup-and-hot-copy while RIFT remained running. The optional `install-preview.ps1` was syntax-checked and **executed successfully on 2026-11-03 while RIFT was closed**. It refuses to run while the RIFT process exists, first copies each available `Saved/<account>/SavedVariables/LuaPad.lua` to `backups/LuaPad-SavedVariables-<timestamp>/<account>/`, then moves the original addon to a timestamped backup outside AddOns and copies only addon payload files. Its error handler moves the active AddOns target only after a preview directory was actually created. Do not rerun it while RIFT is active; consult the deployment checkpoint before reinstalling.

## Manual test gate
1. For Preview 2, confirm `main.lua` and `RiftAddon.toc` are backed up and the two-file hot copy hashes match the source; do **not** rerun the guarded full installer.
2. In RIFT type `/reloadui` (no game exit) to load the updated files. Check the chat initialization line states `[LuaPad v2.0.0-preview2] READY`.
3. Type `/lp`: the title should read `LuaPad v2.0.0-preview2`. Reopen and verify it stays in sync.
4. Run `print("LuaPad preview 2 OK")` and confirm the output.
5. Run invalid Lua (e.g. `this is not valid lua !`) and confirm a syntax error; click **Copy Output**, then paste into Notepad or chat and verify the full error text.
6. Run `error("test")`, click **Copy Output** again, and confirm that the traceback/error pastes faithfully.
7. Test Save/Load on an unused slot, Inspect open/close, hover/depress, and window drag. Report screenshots and any defects; tests are not considered passed by copying files alone.

## Rollback
After exiting RIFT normally, run `powershell.exe -NoProfile -File C:\\work\\LuaPadModern\\restore-original.ps1` in PowerShell to restore the original LuaPad directory. The script is not automatic, checks for a running game, moves the preview to a recoverable backup, and refuses to guess when more than one original backup exists. If necessary, supply `-BackupPath 'C:\\work\\LuaPadModern\\backups\\luapad-before-preview-YYYYMMDD-HHMMSS'`. It does **not** restore account SavedVariables: restore your separate saved-variable backup manually if the test changed it. The rollback script passed PowerShell syntax validation but has not been executed.
