# LuaPad Preview 11 / Inspector 1.9.0-preview4: expression parser fix

Date: 2026-11-03, 18:15 Eastern. Host: physical Windows RIFT addon directory.

## Reproduced behavior

Inspector's original input gate blocked any semicolon (`expression:find("[\\r\\n;]")`) before compilation. Legitimate expressions such as `"semi;colon"` and `(function() local n=1; return n+2 end)()` were rejected. A new runtime regression `quoted semicolon allowed` failed on the previous Inspector source.

## Repair

- The input gate still rejects empty, longer-than-400-character, multiline and visibly incomplete dotted expressions.
- It no longer rejects semicolons unconditionally; Lua's own compiler receives `return <expression>` and enforces top-level single-expression syntax.
- A regression checks a quoted semicolon, a semicolon in an anonymous function, and a prohibited top-level separated statement. The rejected extra statement was verified not to execute.
- The Inspector version becomes `1.9.0-preview4`; root LuaPad becomes `2.0.0-preview11`. Earlier Preview 9/10 fixes remain covered.

## Verification

| Gate | Result |
|---|---|
| Combined mock executing actual LuaPad + Inspector + ScrollView Lua | PASS 102/102 assertions |
| Structural checks | PASS 51/51 |
| Lua syntax parsing | PASS 9/9 files |
| Verified ZIP | `C:\work\LuaPadModern\LuaPad-2.0.0-preview11.zip` |
| ZIP content hashes | PASS 16/16 entries match source |
| ZIP SHA256 | `5cc00c7399910fcd9ca665aba268ab5ac59116fe3d7cae31fcfaf424fc916ea8` |

## Three-file incremental update

Target: `C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns\luapad`

Backup: `C:\work\LuaPadModern\backups\luapad-preview11-before-hotcopy-20261103-181515`

All old installed SHA256s and new source SHA256s were verified before copying, original files were backed up and independently hash-verified, and each newly installed file matched its source. The guarded operation includes rollback of changed files on failure.

| File | Previous installed SHA256 | New installed SHA256 |
|---|---|---|
| `RiftAddon.toc` | `5eb158e91de8a25658236c138ca8a3ae3343a2fff9f7aefcb779accb3a7ac5b1` | `426b988ea075b9f6b698dbf9613a10b18383a556a1205319c723c89fab38f942` |
| `Inspector/main.lua` | `a31f722d9342d15d537a1efccb5508de3b3a1aefacb98e20180c7fe030ddfcf4` | `d520c11372e33af8cbe598d143cc36e3431dde2d8576a2b71a6c6e170edde3b1` |
| `Inspector/RiftAddon.toc` | `6f6d684c2f9bdc5a6fba180d40ad59ba0d2462490d47e1c4b48f39715a913697` | `c8a13d074362cea5fd48f9664e076c92b481d2898258be1767fcfb7e5259907f` |

**RIFT was not focused, reloaded, terminated, or otherwise interacted with.** The Lua files remain inactive until Joey's manual `/reloadui` or the game's next normal launch.

## In-game acceptance pending

1. When safe, type `/reloadui` and inspect initialization errors.
2. Verify `/lp` version `2.0.0-preview11` and `/ti` version `1.9.0-preview4`.
3. In Inspector, enter `"semi;colon"` and click Inspect; the output should contain `semi;colon` without a validation error.
4. Inspect `(function() local n=1; return n+2 end)()` and confirm `3`.
5. Inspect `1; print("not executed")`: the Lua compiler should report a syntax error and never execute the second statement.
6. Confirm Copy Output and earlier scrolling/depth controls still work.

To roll back, exit RIFT normally and restore these precise Preview 10 files from the backup. Original LuaPad and account SavedVariables have separate preserved backups.
