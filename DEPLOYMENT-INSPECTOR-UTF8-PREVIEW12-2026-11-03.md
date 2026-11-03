# Inspector UTF-8 truncation hardening — Preview 12 (2026-11-03)

## Scope and status
- Source: `C:\work\LuaPadModern`; physical RIFT addon: `C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns\luapad`.
- Release: LuaPad `2.0.0-preview12`; Inspector `1.9.0-preview5`.
- Static and mocked-runtime verified; **physical RIFT acceptance remains pending Joey's manual `/reloadui`**. No game input, window focusing, process termination or reload was performed.
- ZIP: `LuaPad-2.0.0-preview12.zip`, SHA256 `d152fde51d6b4e1ad0d57e56c0d16484414dc9171925ce049440437769a701cd`. 16 entries individually checked against source SHA256.

## Reproduced failures and fixes
1. **Table traversal cap**: A value containing 5,000 three-byte euro characters reached the 12,000-byte serialized table limit; ordinary Lua `:sub(1, limit)` cut through a character. Red Fengari regression `bounded Inspector table keeps complete UTF8` failed. Repaired by `utf8BytePrefix(s, left)` to stop at a complete codepoint boundary.
2. **Large-error preview cap**: A 12,080-byte ASCII prefix followed by ten euro characters reached the separate 12,100-byte text display limit; the display cut the second byte of a three-byte codepoint. Red regression `bounded error preview keeps complete UTF8` failed. Repaired using the same helper in `displayOutput`. A separate clipboard regression verifies all ten euro characters and the unshortened error are preserved.
3. The display-shortened notice adds display-only bytes; the regression checks full clipboard integrity directly instead of incorrectly assuming raw clipboard bytes must exceed displayed bytes including that notice.

## Validation
- Combined actual Lua source execution through Fengari mock: **105/105** runtime assertions.
- `node verify-preview.cjs`: **52/52** structural checks.
- `luaparse@0.3.1`: **9/9** Lua source files parsed, zero failures.
- `git diff --check`: no whitespace errors (Git only warned it may normalize test-file LF to CRLF).
- ZIP source matching: **16/16** entry hashes.
- Physical AddOns guarded hot-copy: **3/3** changed files, source/install hashes matched. Preflight installed files exactly matched Preview 11.

## Hot-copy evidence
| File | Preview 11 installed SHA256 | Preview 12 source and installed SHA256 |
| --- | --- | --- |
| `RiftAddon.toc` | `426b988ea075b9f6b698dbf9613a10b18383a556a1205319c723c89fab38f942` | `20f12dcec12a37bd97ecf52a5436182b4e9136c722968e87477037a67773fe44` |
| `Inspector/main.lua` | `d520c11372e33af8cbe598d143cc36e3431dde2d8576a2b71a6c6e170edde3b1` | `6589cd0904337df7799bddc3d28d639d491e2d3af4dc41d9238bd9f0dcfad123` |
| `Inspector/RiftAddon.toc` | `c8a13d074362cea5fd48f9664e076c92b481d2898258be1767fcfb7e5259907f` | `e4f45b4a7ec9141446756c5f2588f04b4e0a90d9d6cef7266839ebc171d924a2` |

- Rollback directory (verified before copying): `C:\work\LuaPadModern\backups\luapad-preview12-before-hotcopy-20261103-182637`.
- Guard rejects any unexpected old hash and automatically attempts to restore from the verified backup if copying fails.
- New code is installed on disk only; it is not in RIFT memory until a user-initiated `/reloadui`.

## Manual acceptance gate
When safe for Joey to reload, use `/reloadui`, open `/ti`, verify Inspector v1.9.0-preview5, and run IP-22–IP-24 in `TEST-PLAN.md` (UTF-8 table output, oversized runtime-error display, and full clipboard). Also check chat for addon exceptions. Do not claim this gate is passed before Joey supplies game evidence.
