# LuaPad 2.0 Preview 1 — physical RIFT deployment checkpoint

Date: 2026-11-03, approximately 14:58 America/New_York.

## Deployment
- Game process check: no rift_x64 or rift process at 19:57:46Z.
- Installer: `C:\work\LuaPadModern\install-preview.ps1`, completed with exit code 0.
- Installed path: `C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns\luapad`.
- Original installed addon backup: `C:\work\LuaPadModern\backups\luapad-before-preview-20261103-145801`.
- Three account SavedVariables backups: `C:\work\LuaPadModern\backups\LuaPad-SavedVariables-20261103-145801`.
- SHA-256 matches (project vs installed): `main.lua`, `RiftAddon.toc`, `Inspector/main.lua`, `LibSimpleWidgets/window.lua` — 4/4.
- Backup original `RiftAddon.toc`: present.
- Saved-variable backups: 3/3 files present.
- Installer does not overwrite existing backup on timestamp collision.

## Existing offline validation
- 9/9 Lua syntax parses passed using luaparse 0.3.1.
- 22/22 structural checks passed.
- 15/15 ZIP entries matched project files.

## Pending in-game verification
- Start physical RIFT normally. Enter `/lp`; verify title `LuaPad 2.0 Preview` and visible toolbar.
- Run `print("LuaPad OK")` and confirm output.
- Run syntax/runtime error tests and verify UI remains responsive.
- Check Inspector, mouse hover/press, scrollbar, snippet Save/Load, window drag, persistence; see TEST-PLAN.md.
- Capture screenshot and exact addon error lines for any failure.

## Recovery
After normal RIFT exit only, run `powershell.exe -NoProfile -File C:\work\LuaPadModern\restore-original.ps1`. It restores the original addon backup and retains the preview in a separate folder. SavedVariables are not auto-restored; preserve or restore from the account backups above if needed.

**Do not mark the in-game test complete until the client actually confirms functional operation.**
