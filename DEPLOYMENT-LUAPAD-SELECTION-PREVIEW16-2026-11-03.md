# LuaPad selection replacement — Preview 16 (2026-11-03)

## Release
- LuaPad `2.0.0-preview16`; Inspector remains `1.9.0-preview5`.
- Source repo: `C:\work\LuaPadModern`.
- Physical installed addon: `C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns\luapad`.
- Two-file guarded hot-copy succeeded; **no RIFT game input, focus change, client restart, or /reloadui was performed**.

## Defect and API evidence
RIFT's documented `RiftTextfield:GetSelection()` returns the selected text's zero-based `begin, end` bounds in the same format as `GetCursor()`. The original editor's manual Tab/Enter insertion always used only `GetCursor()` and `GetText()`, so inserting with an active selection retained the selected characters rather than replacing them. Reference: https://github.com/chrisbecke/Igor/wiki/RIFT-API-Documents (RiftTextfield:GetSelection, :SetSelection, :GetCursor).

The real-source Fengari harness modeled `SetSelection(1,3)` on text `abcd` and fired the documented three-argument Tab frame event. It **failed in red** on `Tab replaces highlighted text` with the previous implementation.

The handler now reads valid selection bounds, replaces the range for Tab (two spaces) or Return (one newline), explicitly clears the selection, and sets the cursor immediately after the inserted text. Without a selection the prior behavior is retained. Invalid or absent selection methods fall back to cursor insertion.

## Validation
- Red regression reproduced before repair.
- Combined LuaPad + Inspector runtime harness: **124/124 assertions passed**, including four new selected-text checks.
- Structural verifier: **56/56** checks passed.
- `luaparse@0.3.1`: **9/9 addon Lua files** parsed.
- `git diff --check`: passed (nonerror LF/CRLF conversion warnings).
- ZIP `LuaPad-2.0.0-preview16.zip`: **16/16 entries** SHA256-match repo source; archive SHA256 `3f09bb3a6211259099d53b16797bb77ff73271caa934020c6fd1ae3398f0d18c`.

## Guarded installation
- `main.lua`: installed Preview 15 hash `2785ec9841aa9b4d842057211a654b65a518895afe74abd778d5ee611fcc88fd`; updated repo and installed hash `6a92d2e9b40988fcc6ca472236d4332225f2cedec53b4c3313e3708ed14ed037`.
- `RiftAddon.toc`: installed Preview 15 hash `b7c31851de9c53f70ddca34cec7741e6a0cc0d503bb6a3c6dce202a2f5a3f7a6`; updated repo and installed hash `fa6318a1c4646ff73affb4a2933cc9c617ab72f7e6d5ea8c7e9c540a32d1a042`.
- Rollback backup: `C:\work\LuaPadModern\backups\luapad-preview16-before-hotcopy-20261103-185700`; verified two old-file hashes before overwrite.
- Installer preflight refused mismatched source or target hashes and verified both installed files after copying.
- Inspector and LibSimpleWidgets installed files were not changed.

## Pending manual RIFT acceptance
When safe, Joey must enter `/reloadui` to load Preview 16. See LP-41–LP-46 in `TEST-PLAN.md`. Verify that native RIFT does not duplicate Tab/Return insertion, selection replacement removes the selected bytes, the cursor is correctly positioned, and ordinary typing continues. Test selected text near multibyte Unicode separately; the original API reference does not specify byte-vs-character indexing, so no physical Unicode selection claim is made. Earlier manual gates remain open.
