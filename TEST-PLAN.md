# LuaPad 2.0 Preview 16 — in-game acceptance checklist

**Target:** physical RIFT Live x64. No VMware. Do not use in combat or during an important session.

## Before test
- [x] Preview 16 guarded two-file hot-copy over Preview 15 verified on the physical PC. Do **not** rerun `install-preview.ps1` during gameplay.
- [ ] Confirm the original LuaPad 1.8 and three account SavedVariables copies remain backed up.
- [x] Run `verify-preview.cjs` from `C:\work\LuaPadModern` (56/56 checks passed) and parse Lua source (9/9 files passed).
- [x] Back up installed Preview 15 `main.lua` and root TOC; hot-copy only those two files with hash verification. Game exit is **not** required for this incremental update.
- [x] Joey performed `/reloadui` and reported testing the Preview 16 Code Editor on 2026-11-04; Enter and Tab were not working properly. Exact on-screen effect and addon errors have not yet been captured.

## Runtime gates
| ID | Action | Expected |
| --- | --- | --- |
| LP-01 | `/lp` in chat | Window title says `LuaPad v2.0.0-preview16`; buttons visible |
| LP-02 | Hover/press Run, Save, Load, Inspect | Visual hover and depression with readable labels |
| LP-03 | Type and run `print("LuaPad OK")` | Output contains exactly the message |
| LP-04 | Type and run `this is not lua !` | Syntax error displayed, no addon crash |
| LP-05 | Type and run `error("test")` | Runtime error displayed, editor still operable |
| LP-06 | Type two lines, paste lines, use Tab | Multiline layout and cursor remain correct |
| LP-07 | Choose an unused snippet slot, Save and Load | Exact code restored |
| LP-08 | Scroll long editor and output text | Wheel/scrollbar work, no click interception |
| LP-09 | Open Inspector and inspect `Inspect` with depth 1 | Bounded result, no freeze |
| LP-10 | Inspect an expression containing a quoted argument | Expression accepted or documented API error |
| LP-11 | Drag window by its border | Window moves; editor remains clickable |
| LP-12 | Close and reopen via `/lp` | No duplicate controls or error |
| LP-13 | Log out/re-enter normally | Saved snippet persists |
| LP-14 | After `/reloadui`, review chat | `[LuaPad v2.0.0-preview16] READY` startup message appears, with no addon errors |
| LP-15 | Run `this is not lua !`, then click Copy Output | Clipboard paste contains full syntax error text |
| LP-16 | Run `error("test")`, then click Copy Output | Clipboard paste contains runtime error and traceback (when API allows) |
| LP-17 | Select Help, then reopen `/lp` | Help and title both show current version from TOC |
| LP-18 | Copy Output with no output | Friendly no-content message; no crash |
| LP-19 | Inspect all seven toolbar actions | One row above editor, even gaps, consistent button skins; no bottom orphan button |
| LP-20 | Inspect Code Snippets heading | Clear separation from Help/Copy Output, no overlapping text |
| LP-21 | Inspect section headings | Code Editor, Output, Code Snippets share consistent size and pale-cyan color |

## Live key-input failure — 2026-11-04 (release blocker)
- **RED / physical RIFT:** After manually using `/reloadui`, Joey reports that neither Enter nor Tab works properly in the LuaPad Code Editor. This overrides the green mock tests; LP-41–LP-46 remain unaccepted.
- **Evidence gap:** Need to distinguish no insertion, wrong insertion, lost focus, duplicate insertion, or a Lua exception. Do not mark any of those as the confirmed symptom without direct observation.
- **Leading code-level hypothesis:** Original LuaPad used `inputField.Event:KeyDown(button)` with ASCII 13/9 and `SetKeyFocus(true)`. Preview 15–16 switched to `inputField:EventAttach(Event.UI.Input.Key.Down, ...)`, a different registration path. The mock harness simulated the latter callback directly and never proved native dispatch.
- **Direct-test prerequisite:** A read-only physical Windows check on 2026-11-04 verified PID 18056 as the exact RIFT client and found its window minimized / not foreground. Before real keyboard or mouse automation, obtain Joey's permission to restore and focus that window and use a scoped input controller; do not interact with gameplay or reload without confirmation.

## Preview 16 selection replacement acceptance (after /reloadui)
- [ ] LP-44: Highlight two characters in the editor, press Tab, and confirm the selection is replaced by exactly two spaces (not inserted after the highlighted text).
- [ ] LP-45: Highlight two characters, press Enter, and confirm the selection becomes exactly one newline; no duplicate text or persistent selection.
- [ ] LP-46: After LP-44/45, type a normal letter and confirm cursor/selection state is cleared and typing is intact.

## Preview 15 LuaPad editor key handling acceptance (after /reloadui)
- [ ] LP-41: In the LuaPad editor, position the cursor between two letters and press Tab. Exactly two spaces should be inserted at the cursor; characters after it remain intact.
- [ ] LP-42: Place the cursor between two letters and press Enter. Exactly one newline should be inserted at the cursor; text after it moves to the next line.
- [ ] LP-43: Continue typing ordinary letters after Tab/Enter, Save the snippet, then Load. No duplicated characters, misplaced cursor or addon error; the exact newlines and spaces are restored.

## Preview 14 LuaPad error-rendering acceptance (after /reloadui)
- [ ] LP-38: Run `error(("line\\n"):rep(400))`; the output pane stays responsive, shows a shortened-display notice, and scrolls normally.
- [ ] LP-39: Click Copy Output after LP-38 and paste into Notepad; the clipboard contains all 400 lines, beyond the shortened preview.
- [ ] LP-40: Run `print(("line\\n"):rep(400)); print("tail")`; Copy Output still ends with `tail` and UI remains responsive.

## Preview 13 LuaPad UTF-8 acceptance (after /reloadui)
- [ ] LP-35: Run `print(string.rep("€", 5000) .. "X")` in LuaPad. The bounded output ends with `X`, starts on a whole euro character, and does not display a broken replacement glyph at the beginning.
- [ ] LP-36: Save a snippet whose first line is `€€€€€€`, inspect its shortened slot caption, and verify there is no half character/replacement glyph; Load restores all six characters.
- [ ] LP-37: After long Unicode output, run `print("normal")` and confirm output, scroll behavior and Copy Output still function.

## Preview 12 Inspector UTF-8 acceptance (after /reloadui)
- [ ] IP-22: In LuaPad, run `InspectorFixture = { e = string.rep("€", 5000) }` (paste the euro character). Open `/ti`, inspect `InspectorFixture` at depth 1. Truncation notice appears; no broken replacement character appears at the cutoff.
- [ ] IP-23: In Inspector, inspect `error(("X"):rep(12080) .. string.rep("€", 10), 0)`. The shortened display contains only whole euro characters at the end; no replacement glyph.
- [ ] IP-24: Click Inspector Copy Output and paste externally. All ten euro characters remain in the complete error, unmodified. Do not stress-test while in combat.

## Preview 11 Inspector parser acceptance (after /reloadui)
- [ ] IP-19: In `/ti`, inspect `"alpha;beta"`; the string renders with its semicolon instead of an invalid-expression warning.
- [ ] IP-20: Inspect `(function() local n=1; return n+2 end)()`; the result should be `3` with no addon error.
- [ ] IP-21: Inspect `1; print("not executed")`; the Lua compiler rejects it as syntax rather than executing the extra statement.

## Preview 10 nested Run acceptance (after /reloadui)
- [ ] LP-32: Run `LuaPad.doRun([[print("nested")]])`; a Nested Run ignored notice appears and global print continues working.
- [ ] LP-33: Run `print("before"); LuaPad.doRun([[print("nested")]]); print("after")`; both outer lines appear, the nested body does not run, and no addon error occurs.
- [ ] LP-34: Run `print("still working")` afterward; output and Copy Output remain functional.

## Preview 9 Inspector rendering acceptance (after /reloadui)
- [ ] IP-17: `/ti` displays `Inspector v1.9.0-preview5`; use `error(("test\\n"):rep(100))` to inspect a moderate-length multiline exception; the result remains scrollable and responsive.
- [ ] IP-18: Click Copy Output and paste the full error into Notepad. The preview-9 mock also validates an 8,000-line error and explicit shortened-display notice without requiring an extreme live-game test.

## Preview 8 snippet-card acceptance (after /reloadui)
- [ ] LP-27: Click Slot 1, then Load and Save; selected highlight remains the same teal color (no translucent green).
- [ ] LP-28: Hover a snippet card; its background brightens. Press/release; it visibly depresses then returns.
- [ ] LP-29: Move off a held card and release; it must not remain stuck in pressed styling.
- [ ] LP-30: Select Slot 2 after Slot 1; only Slot 2 remains highlighted.
- [ ] LP-31: Check 10-point snippet text and truncation on saved long first lines; card labels remain readable without overflow.

## Preview 7 output rendering acceptance (after /reloadui)
- [ ] LP-22: Run `print(string.rep("Hello ", 250))`; confirm word-wrapped output and a usable scrollbar, not horizontal clipping.
- [ ] LP-23: Drag/scroll output down, click Help, and confirm Help starts at the top and its final line can be reached.
- [ ] LP-24: Copy the long printed output and compare it with the original text, including whitespace.
- [ ] LP-25: After long output, run `print("short")` and confirm the scrollbar disappears and the output starts at the top.
- [ ] LP-26: Test syntax/runtime errors after a long output and confirm Copy Output still contains them.

## Preview 6 shared-scrollbar and Inspector acceptance (after /reloadui)
- [ ] IP-13: Empty or exactly viewport-height inspection text does not show a scrollbar.
- [ ] IP-14: Long output shows a scrollbar and wheel down/up moves content in both directions.
- [ ] IP-15: Dragging the scrollbar changes position; releasing the mouse stops dragging. Returning to short output resets scroll offset to 0.
- [ ] IP-16: LuaPad main editor/output scroll areas continue to work after shared LibSimpleWidgets scrollbar patch.
- [ ] IP-00: Preview 5 fixes the reproduced Inspector button exception at `Inspector/main.lua:214` by reading numeric depth from the slider. Click Inspect several times; check NO more `tonumber` boolean-base errors appear in RIFT chat. Test errors now render in the copyable result pane.
- [ ] IP-01: /ti opens centered Inspector with title `Inspector v1.9.0-preview5`; /lp title displays `LuaPad v2.0.0-preview16`.
- [ ] IP-02: Output pane, input label, depth control, Inspect/Help/Close and Copy Output do not overlap or fall outside 800x600 window.
- [ ] IP-03: Help fits entirely within 650x430 window; close/reopen works.
- [ ] IP-04: Depth moves 1,2,3,4,5 from left to right; result expansion corresponds to setting.
- [ ] IP-05: Inspect `Inspect` at depth 1; scroll long results with wheel and scrollbar.
- [ ] IP-06: Inspect `Inspect.???`, then Copy Output; paste exact syntax error outside the game.
- [ ] IP-07: Inspect `error("inspector test")`, then Copy Output; paste runtime error.
- [ ] IP-08: LuaPad: `InspectorFixture = {first={n=1}}; InspectorFixture.second=InspectorFixture.first`. Inspector: `InspectorFixture` depth 3 shows both first.n and second.n without false [cycle].
- [ ] IP-09: LuaPad: `InspectorFixture.self=InspectorFixture`. Inspector: same expression depth 3 yields [cycle] for self.
- [ ] IP-10: Chat after reload prints Inspector and LuaPad exact preview versions once, without initialization errors.
- [ ] IP-11: Press Copy Output with empty output and inspect blank expression; no addon crash and clear message.
- [ ] IP-12: UI stays open after errors and game remains playable. This is a manual gate, not statically verified.

## Evidence / acceptance
- Retain a screenshot showing version title and controls.
- Record any Lua errors exactly, including addon and line number.
- Do not mark LP-01..LP-21 passing from a successful copy alone.
- On a failure, exit RIFT normally and run `restore-original.ps1` to recover the original addon. This retains the preview in a separate backup. Restore account SavedVariables separately from the pretest copy if needed. Do not perform rollback while the game is running.
