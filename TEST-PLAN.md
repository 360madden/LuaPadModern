# LuaPad 2.0 Preview 1 — in-game acceptance checklist

**Target:** physical RIFT Live x64. No VMware. Do not use in combat or during an important session.

## Before test
- [ ] Exit RIFT normally. Do not kill the process.
- [ ] Preserve the installed `luapad` addon folder and the account SavedVariables.
- [ ] Run `verify-preview.cjs` from `C:\work\LuaPadModern` (22 structural checks expected).
- [ ] Install via `install-preview.ps1` only while RIFT is closed. Script creates a timestamped original-addon backup.
- [ ] Start RIFT normally. Record screenshot/version and any addon errors.

## Runtime gates
| ID | Action | Expected |
| --- | --- | --- |
| LP-01 | `/lp` in chat | Window title says LuaPad 2.0 Preview; buttons visible |
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

## Evidence / acceptance
- Retain a screenshot showing version title and controls.
- Record any Lua errors exactly, including addon and line number.
- Do not mark LP-01..LP-13 passing from a successful install alone.
- On a failure, exit RIFT normally and run `restore-original.ps1` to recover the original addon. This retains the preview in a separate backup. Restore account SavedVariables separately from the pretest copy if needed. Do not perform rollback while the game is running.
