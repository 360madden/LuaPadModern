# LuaPad Preview 9 / Inspector 1.9.0-preview3 deployment

Date: 2026-11-03, 17:59 Eastern. Host: physical Windows RIFT installation.

## Reproduced defect and repair

- **RED before fix:** the 8,000-line runtime-error reproduction failed `huge Inspector error preview bounded` because `displayOutput` gave all API/exception text directly to `Text:SetText` and enlarged the text frame proportional to all lines.
- **GREEN after fix:** Inspector preserves `lastOutput` in full for `Command.CopyToClipboard`, but caps visible text to 12,100 bytes / 300 newline breaks; a visible notice explains that the clipboard contains the complete error. This bounds text-frame height while keeping normal table serialization markers visible.
- Existing normal values, 12,000-character traversal cap, scrollbar/drag/wheel, and the root LuaPad interactions remain covered by regression tests.

## Verification

| Gate | Result |
|---|---|
| Combined mock executing the actual Inspector, LuaPad and ScrollView Lua | PASS: 94/94 assertions |
| Structural source/package checks | PASS: 49/49 |
| luaparse syntax checks | PASS: 9/9 Lua source files |
| ZIP package | `C:\work\LuaPadModern\LuaPad-2.0.0-preview9.zip` |
| ZIP entry verification | PASS: 16/16 entries match source SHA256 |
| ZIP SHA256 | `6e40709db750612df90014a4f1d8e63a3ebd336015a808ff08f236627a8416d6` |

## Guarded three-file hot-copy

Target: `C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns\luapad`

Preflight validated old installed SHA256s against Preview 8 and new source SHA256s before creating backups or copying. Each backup file was hash-verified. All three post-copy installed hashes matched their source hashes. Copy handler included rollback of copied files upon error.

Backup: `C:\work\LuaPadModern\backups\luapad-preview9-before-hotcopy-20261103-175936`

| File | Previous installed SHA256 | New installed SHA256 |
|---|---|---|
| `RiftAddon.toc` | `73026a3d109c21e848692be5edaff7f765940834e6c97ec7e56013bfd3cfbb28` | `f1522a9e54a38d5127f1ae950061d0a167f2afac6ab046a7fdfa048c4e2ccdd4` |
| `Inspector/main.lua` | `6441b15e4b8c342e76d7921027484d8bf93c512829abd5061faa4cc3ebd7b428` | `a31f722d9342d15d537a1efccb5508de3b3a1aefacb98e20180c7fe030ddfcf4` |
| `Inspector/RiftAddon.toc` | `33048c9d8167d7159b2062b4f065b28f715c9200077edb64e7815ec74b2ae229` | `6f6d684c2f9bdc5a6fba180d40ad59ba0d2462490d47e1c4b48f39715a913697` |

**RIFT was not focused, reloaded, terminated, or otherwise interacted with.** Copying Lua files does not activate their new code until a user-controlled `/reloadui` or normal next launch.

## Manual acceptance pending

1. When safe, Joey types `/reloadui` in RIFT and checks startup notices.
2. Verify `/lp` title `LuaPad v2.0.0-preview9` and `/ti` title `Inspector v1.9.0-preview3`.
3. In Inspector test `error(("test\\n"):rep(100))`, confirm scrollable error and functional Copy Output; paste full text into Notepad.
4. For giant text, trust the 8,000-line mock regression rather than running an extreme stress expression during gameplay.
5. Confirm no new addon chat errors. The test suite does **not** constitute live RIFT acceptance.

Rollback if necessary: exit RIFT normally before using `restore-original.ps1`, or copy precisely these three backed-up Preview 8 files to their matching AddOns paths after closing RIFT. Preserve account SavedVariables backups separately.
