# LuaPad 2.0 Preview 3 — in-game acceptance checklist

**Target:** physical RIFT Live x64. No VMware. Do not use in combat or during an important session.

## Before test
- [ ] Preview 3 is hot-copied over Preview 2 on the physical PC. Do **not** rerun `install-preview.ps1` during gameplay.
- [ ] Confirm the original LuaPad 1.8 and three account SavedVariables copies remain backed up.
- [ ] Run `verify-preview.cjs` from `C:\work\LuaPadModern` (27 structural checks expected) and parse Lua source.
- [x] Back up installed Preview 2 `main.lua` and `RiftAddon.toc`; hot-copy only these two files with hash verification. Game exit is **not** required for this incremental update.
- [ ] In RIFT, when safe, type `/reloadui` to load Preview 3. Record screenshot/version and addon errors.

## Runtime gates
| ID | Action | Expected |
| --- | --- | --- |
| LP-01 | `/lp` in chat | Window title says `LuaPad v2.0.0-preview3`; buttons visible |
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
| LP-14 | After `/reloadui`, review chat | `[LuaPad v2.0.0-preview3] READY` startup message appears, with no addon errors |
| LP-15 | Run `this is not lua !`, then click Copy Output | Clipboard paste contains full syntax error text |
| LP-16 | Run `error("test")`, then click Copy Output | Clipboard paste contains runtime error and traceback (when API allows) |
| LP-17 | Select Help, then reopen `/lp` | Help and title both show current version from TOC |
| LP-18 | Copy Output with no output | Friendly no-content message; no crash |
| LP-19 | Inspect all seven toolbar actions | One row above editor, even gaps, consistent button skins; no bottom orphan button |
| LP-20 | Inspect Code Snippets heading | Clear separation from Help/Copy Output, no overlapping text |
| LP-21 | Inspect section headings | Code Editor, Output, Code Snippets share consistent size and pale-cyan color |

## Evidence / acceptance
- Retain a screenshot showing version title and controls.
- Record any Lua errors exactly, including addon and line number.
- Do not mark LP-01..LP-21 passing from a successful copy alone.
- On a failure, exit RIFT normally and run `restore-original.ps1` to recover the original addon. This retains the preview in a separate backup. Restore account SavedVariables separately from the pretest copy if needed. Do not perform rollback while the game is running.
