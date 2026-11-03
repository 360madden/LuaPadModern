# LuaPad 2.0.0-preview8 — snippet card selection and interaction polish

Date: 2026-11-03, America/New_York.

## Reproduced defect
The cross-addon real-ScrollView Lua harness selected a snippet, saved editor code and loaded it back successfully, but the selected card's color changed from solid teal to nearly transparent green. A regression assertion caught the selection-state mismatch.

## Implementation
- Reuse the same dark blue/teal/cyan palette as the main LuaPad toolbar, with explicit normal, selected, hover and depressed states for all sixteen snippet cards.
- Handle cursor-out and mouse-up-outside to prevent stuck press effects.
- Refresh visual state for the entire set when the selected slot changes; Load no longer overwrites the selection with an unrelated green.
- Increase caption font size from 8 to 10 and shorten first-line preview text to avoid clipping in the approximately 125-pixel-wide cards.
- Preserve per-account saved snippet values, selection semantics and Save/Load/Clear functionality. The changes affect visuals, not data format.

## Regression evidence
- Before fix: test `snippet selected color consistent after Load` failed reliably.
- After fix: Save, Load, Clear, hover, press, release, switching selection and preview truncation all pass in the combined LuaPad + Inspector RIFT widget mock.
- Runtime suite: 89 assertions passing with the actual `LibSimpleWidgets/scrollview.lua`; no actual game behavior inferred.
- Structural, syntax, ZIP and deployment hashes must pass independently before hot-copy.

## Deployment policy
Only root `main.lua` and `RiftAddon.toc` differ in the installed addon. Before copying:
1. Verify both source and currently installed file hashes, and take timestamped recoverable backups.
2. Copy these two files while RIFT remains running, verify SHA256 again and roll back automatically on any mismatch.
3. Do not focus RIFT, close it, reload UI or alter saved variables.
4. Joey decides when to run `/reloadui`; test all five LP-27..LP-31 items from `TEST-PLAN.md`.

## Remaining acceptance
Real-game button hit testing, font legibility and visual layout cannot be established by mocks. In-game screenshots and user acceptance remain pending for Preview8 and earlier previews.

## Preview8 deployment receipt
- Date: 2026-11-03 (America/New_York).
- ZIP: `LuaPad-2.0.0-preview8.zip`; 16/16 entries verified against source SHA256; package SHA256 `07d9c3430c8f9d93803eb5f2863599723dd7599b906847dd5c3d60f9ca38b393`.
- Structural verification: 47/47 passed. Runtime mock with actual ScrollView: 89/89 passed. Lua syntax: 9/9 passed. `git diff --check` passed, aside from routine line-ending warnings.
- Installed addon: `C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns\luapad`.
- Pre-copy backup: `C:\work\LuaPadModern\backups\luapad-preview8-before-hotcopy-20261103-174728`.
- Installed `main.lua` SHA256: `762561d830c93c0c769a27ad2e4e60bdb6a3c100a812a160b7090f7bec5f5997`.
- Installed root `RiftAddon.toc` SHA256: `73026a3d109c21e848692be5edaff7f765940834e6c97ec7e56013bfd3cfbb28`.
- No game focus, shutdown or reload performed. Joey must run `/reloadui` at a convenient time for live acceptance.

