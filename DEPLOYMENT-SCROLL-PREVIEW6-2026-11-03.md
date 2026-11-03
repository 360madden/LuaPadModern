# LuaPad 2.0.0-preview6 — ScrollView edge-case hardening (2026-11-03)

## Scope
The Preview5 in-game Inspector button bug is already fixed. This iteration targets the shared `LibSimpleWidgets/scrollview.lua` used by both LuaPad and Inspector; Inspector's existing version stays 1.9.0-preview2.

## New finding
The real ScrollView used `contentHeight < viewportHeight` to hide the scrollbar. At exact-fit (`contentHeight == viewportHeight`) it incorrectly showed a full-height scrollbar, even though no scroll was possible. The regression test reproduced this against the actual embedded widget implementation. Other latent edge cases:
- `GetMaxOffset()` could return a negative number with shorter content.
- `GetOffsetForScrollbarY()` had a division-by-zero case when view height was zero.
- `PositionScrollbar()` divided by content height with no zero guard.
- `SetShowScrollbar(true)` forced visibility without checking whether overflow existed.
- Wheel events were allowed for exact-fit content.

## Changes
- Hide scrollbars when content height is equal to or less than the view height.
- Clamp max scroll offset to nonnegative.
- Handle zero-height view/content in scrollbar calculations.
- Clamp existing scroll offset after content resize.
- Respect current overflow state when toggling scrollbar visibility.
- Keep wheel movement disabled for equal-height content.

## Regression discipline
The `inspector-runtime-tests.lua` now loads the real `LibSimpleWidgets/scrollview.lua` into its RIFT widget mock (replacing the earlier ScrollView stub), testing wheel up/down, scrollbar drag and release, exact fit, zero height, short/long content, output reset, and all earlier UI/inspection behavior.

## Commands
- `node verify-preview.cjs`
- `npm exec --yes --package=fengari-node-cli -- fengari inspector-runtime-tests.lua`
- Parse all addon .lua source files with `luaparse@0.3.1`.

## Safety
A full reinstall is unnecessary. Incrementally hot-copy only `LibSimpleWidgets/scrollview.lua` and root `RiftAddon.toc` after per-file backups and SHA256 preflight. No RIFT window focus, game close or reload is done by tools. New code loads when Joey chooses `/reloadui`. Actual RIFT visual/scroll acceptance remains unverified until user testing.

## Preview6 deployment receipt
- Date: 2026-11-03 (America/New_York).
- Package: `LuaPad-2.0.0-preview6.zip`, 16 verified entries; SHA256 `242cbbc1caab2d5311a36182dedb27dcf96f2a98b25fb4f3ad53b100175f3c9e`.
- Structural verification: 42/42 passed.
- Runtime verification with real ScrollView: 58/58 passed.
- Lua syntax validation: 9/9 addon Lua files parsed cleanly.
- Git `diff --check`: passed, with only Windows line-ending normalization warnings.
- Installed addon: `C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns\luapad`.
- Backup: `C:\work\LuaPadModern\backups\luapad-preview6-before-hotcopy-20261103-172533`.
- Changed installed `LibSimpleWidgets/scrollview.lua`: SHA256 `1c42b26b99635d40442e6f422f29efbb93c257490cc47d350a0585be27dc3f7b`.
- Changed installed `RiftAddon.toc`: SHA256 `3b0c268d55aa36cf7f3a41ca8a1450bc1fd8db293316f6f9249bd9c9b2290c34`.
- No focus switch, game stop, or reload was initiated. Joey must issue `/reloadui` to activate Preview6 and test Inspector output scrolling, exact-fit, wheel and scrollbar drag manually.

