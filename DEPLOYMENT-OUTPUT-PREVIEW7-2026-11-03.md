# LuaPad 2.0.0-preview7 — wrapped output and Help scrolling (2026-11-03)

## Scope
This increment fixes LuaPad's own output display; Inspector 1.9.0-preview2 and shared LibSimpleWidgets remain unchanged from Preview6.

## Reproduced defects
The actual `main.lua` failed a new cross-addon Fengari runtime regression: after running `print(("X"):rep(1500))`, the output pane's Text widget did not explicitly wrap words, remained at the 150-pixel minimum height, and had a maximum scroll offset of zero. The text was present but could be clipped on screen. A second regression found that opening Help from scrolled long output retained the previous scroll offset.

## Implementation
- `outputField:SetWordwrap(true)` and an explicit 12-point font for predictable layout.
- New centralized `setOutput` estimates visible lines, accounting for both newline characters and text length at approximately 70 characters per visual row for the 500-pixel output view.
- Explicit ScrollView content resize after rendering, including syntax/runtime diagnostics, captured print, and Help.
- Help resets its scroll position; each Run starts at the top. Copy Output still copies the exact `Text` content.
- Regression harness loads the *actual* shared ScrollView, Inspector and root LuaPad in one mock RIFT environment.

## Validation
- Initial reproduced failure: wordwrap was nil; 1,500-character text kept height 150 and max scroll offset 0.
- After fix: wordwrap true, output height 384 and max scroll offset 234.
- Combined runtime mock: 75/75 assertions passed, including long-line scrolling, exact clipboard content, compile and runtime errors, short-output reset and Help.
- Additional structural/package/Lua syntax checks are release gates, not substitutes for visual in-game acceptance.

## Deployment safety and manual gate
Before copying, validate source and installed SHA256. Only root `main.lua` and `RiftAddon.toc` need replacing. Make a timestamped backup first, check hashes after hot-copy, roll back on any mismatch. Do not focus, close, or reload RIFT. Joey can run `/reloadui` when convenient to load the update.

In game:
1. `/lp` must show `LuaPad v2.0.0-preview7` after `/reloadui`.
2. Run `print(string.rep("Hello ", 250))`. Confirm wrapping, wheel/drag scrolling and no horizontal clipping.
3. Scroll down, click Help; check the Help starts at the top and all lines remain reachable.
4. Click Copy Output on a long result and paste outside RIFT; compare text exactly.
5. Run invalid Lua and `error("test")` to confirm errors still render and copy.
6. `/ti` should still show Inspector v1.9.0-preview2, with the Preview6 scrollbar fixes.

Actual RIFT text wrap, scrollbar geometry and button interactions are not considered verified until Joey tests the live client.

## Preview7 deployment receipt
- Local date: 2026-11-03 (America/New_York).
- ZIP: `LuaPad-2.0.0-preview7.zip`, all 16 entries verified against source SHA256; package SHA256 `d696387e1d3f41e530459e516c46efd73e9efc0179bbb68475ebfe8e5f60156a`.
- Structural checks: 44/44 passed. Combined runtime checks: 75/75 passed. Lua parse: 9/9 passed. `git diff --check` passed with harmless Windows line-ending normalization warnings.
- Active installed addon: `C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns\luapad`.
- Pre-copy two-file backup: `C:\work\LuaPadModern\backups\luapad-preview7-before-hotcopy-20261103-173921`.
- Installed `main.lua` SHA256: `d539a44d260f03fa0aeb7a7d3e20bfa6179e8767c122af2023b67b7d6f059c46`.
- Installed root `RiftAddon.toc` SHA256: `2be8541453d784bb51acba7228fc95ad76c520c669d360b9fcbc9eb203b6ce36`.
- No RIFT focus, process stop, or UI reload was initiated. Joey may run `/reloadui` at a safe time.

