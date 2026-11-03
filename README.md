# LuaPad 2.0 preview 1 (physical-PC RIFT)

Source: copied from installed LuaPad 1.8 on 2026-11-03. This is a separate working copy; no live addon was replaced.

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

## Current limitations / next gates
- Lua syntax parsed successfully for all 9 .lua source files on 2026-11-03 using luaparse 0.3.1 through npm exec (9/9). Syntax validity does not establish RIFT API/runtime compatibility.
- UI runtime has not been observed and existing embedded SimpleWindow, RiftTextfield, SimpleScrollView and Inspector dependencies remain.
- Global print interception is now scoped to each Run operation and restored afterward; the runtime behavior still needs an in-game test.
- Installed LuaPad 1.8 was not modified. The package must be deployed with **folder name luapad** because Identifier is LuaPad and embedded dependencies remain; do not load two copies simultaneously.
- SavedVariables are account-wide. The guarded installer now creates per-account LuaPad.lua copies before it touches the installed addon (three account files were found on this physical PC). Keep these backups; the rollback script does not silently overwrite live SavedVariables.
- Do not test while critical gameplay is in progress.

## Verified preview package
- `verify-preview.cjs`: 22/22 structural checks passed (TOC scripts, metadata, engine/UI invariants). This is **not** a Lua parser or game-runtime test.
- `LuaPad-2.0.0-preview1.zip`: rebuilt after Inspector event/depth fixes. SHA256 `6ba06d8da226196e2cefdb01f82255b7b94302dee20f3acec9cbac3cd8b14c3e`. Its 15 archived files were compared byte-for-byte (SHA256) to the working source: 15/15 match, zero mismatches.
- The live installed addon is unchanged.

## Guarded installation
The optional `install-preview.ps1` was syntax-checked but **not executed**. It refuses to run while the RIFT process exists, first copies each available `Saved/<account>/SavedVariables/LuaPad.lua` to `backups/LuaPad-SavedVariables-<timestamp>/<account>/`, then moves the original addon to a timestamped backup outside AddOns and copies only addon payload files. Its error handler moves the active AddOns target only after a preview directory was actually created. Do not invoke it until a normal game exit.

## Manual test gate
1. At a normal break, exit RIFT cleanly; copy the original installed luapad directory and its account SavedVariables elsewhere.
2. Install the preview as luapad only after removing/disabling the old folder, preserving one active LuaPad.
3. Start RIFT; verify /lp opens a window titled LuaPad 2.0 Preview.
4. Run print("LuaPad preview OK") and confirm output.
5. Run invalid Lua (e.g. `this is not valid lua !`) and confirm a syntax error, then run `error("test")` and confirm runtime error.
6. Test Save/Load on an unused slot and Inspect open/close.
7. Observe hover/depress visuals; screenshot evidence required before declaring UI functional.

## Rollback
After exiting RIFT normally, run `powershell.exe -NoProfile -File C:\\work\\LuaPadModern\\restore-original.ps1` in PowerShell to restore the original LuaPad directory. The script is not automatic, checks for a running game, moves the preview to a recoverable backup, and refuses to guess when more than one original backup exists. If necessary, supply `-BackupPath 'C:\\work\\LuaPadModern\\backups\\luapad-before-preview-YYYYMMDD-HHMMSS'`. It does **not** restore account SavedVariables: restore your separate saved-variable backup manually if the test changed it. The rollback script passed PowerShell syntax validation but has not been executed.
