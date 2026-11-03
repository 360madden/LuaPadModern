# LuaPad Preview 10: nested Run guard / print-hook recovery

Date: 2026-11-03, 18:08 Eastern. Host: physical Windows RIFT installation.

## Reproduced defect

Before the fix, an editor script executing `LuaPad.doRun('LuaPad.doRun([[print("nested")]])')` caused a nested invocation of `LuaPad.doRun` to overwrite `origPrint` with `LuaPad.print`. When the outer Run completed, global `print` remained replaced with `LuaPad.print`, which could recursively call itself when idle. This was reproduced in the actual LuaPad source loaded by the RIFT runtime mock: `FAIL nested Run restores global print`.

## Fix

- At entry to `LuaPad.doRun`, reject nested execution when `isRunning` is already true.
- Write a friendly `Nested Run ignored` notice to the ongoing output without resetting it.
- Preserve outer before/after print output and ensure a fresh Run works afterward.
- The root LuaPad version is `2.0.0-preview10`; Inspector remains `1.9.0-preview3` and its source/TOC are unchanged from Preview 9.

## Verification

| Gate | Result |
|---|---|
| Combined runtime mock executing actual LuaPad, Inspector and ScrollView Lua | PASS 99/99 assertions |
| Nested Run cleanup, notice, output preservation, subsequent Run | PASS all five new checks |
| Structural package/source checks | PASS 50/50 |
| Lua syntax parsing | PASS 9/9 source files |
| ZIP | `C:\work\LuaPadModern\LuaPad-2.0.0-preview10.zip` |
| ZIP content SHA256 verification | PASS 16/16 entries |
| ZIP SHA256 | `94bf45b3d1a2a8ccb6e61c25a4e21c657727a3230523e8892f7e8904112c4507` |

## Guarded two-file hot-copy

Target: `C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns\luapad`

Each installed Preview 9 SHA256 and new source SHA256 passed preflight. Previous installed files were copied into a rollback folder and hashes checked. New installed copies were verified after copying. The script includes rollback of changed files if a copy or verification fails.

Backup: `C:\work\LuaPadModern\backups\luapad-preview10-before-hotcopy-20261103-180816`

| File | Previous installed SHA256 | New installed SHA256 |
|---|---|---|
| `main.lua` | `762561d830c93c0c769a27ad2e4e60bdb6a3c100a812a160b7090f7bec5f5997` | `1dd1656bfb8844ea6bacb1171a9a256f5719a31f9a67f3fbfdb19444e56cf1c1` |
| `RiftAddon.toc` | `f1522a9e54a38d5127f1ae950061d0a167f2afac6ab046a7fdfa048c4e2ccdd4` | `5eb158e91de8a25658236c138ca8a3ae3343a2fff9f7aefcb779accb3a7ac5b1` |

**No RIFT focus, UI reload, process termination, or live-game interaction occurred.**

## In-game acceptance pending

1. When safe, Joey manually types `/reloadui`.
2. Check `LuaPad v2.0.0-preview10` and `Inspector v1.9.0-preview3`.
3. Run `print("before"); LuaPad.doRun([[print("nested")]]); print("after")` in LuaPad. Expect before, `Nested Run ignored` notice and after; no nested output.
4. Run `print("still working")` next, confirming output and clipboard. Inspect a benign expression via `/ti` as a separate acceptance gate.
5. Confirm no new addon errors. Simulated RIFT widgets are **not** an in-game acceptance test.

Rollback: exit RIFT normally before restoring these exact Preview 9 files from the backup. Do not overwrite saved-variable files. Existing original-LuaPad rollback procedure remains available separately.
