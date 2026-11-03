# LuaPad output/snippet UTF-8 hardening — Preview 13 (2026-11-03)

## Release
- LuaPad `2.0.0-preview13`, Inspector remains `1.9.0-preview5`.
- Source: `C:\work\LuaPadModern`.
- Installed addon: `C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns\luapad`.
- Physical-game acceptance is **pending Joey's manual `/reloadui`**. No game focusing, inputs, termination or reload were performed.

## Reproduced defects
1. **Output-history UTF-8 split**: LuaPad previously used `combined:sub(-12000)` to retain the last 12,000 bytes. A 15,000-byte stream of three-byte euro characters with trailing `X` began inside a codepoint. Red regression `LuaPad 12000-byte tail keeps complete UTF8` failed. Fixed with `utf8ByteSuffix`, skipping any leading continuation bytes after trimming.
2. **Saved-snippet caption UTF-8 split**: `preview:sub(1, 14)` cuts a 3-byte character at byte 14. A 6-euro-character snippet confirmed this path was vulnerable by source inspection and passes after using `utf8BytePrefix`. A dedicated regression `snippet caption keeps complete UTF8` guards it.

## Verification
- Combined Inspector + LuaPad mock suite: **107/107 assertions**.
- Structural preview verification: **53/53 checks**.
- All **9 Lua files** passed `luaparse@0.3.1`.
- `git diff --check`: passed (non-error CRLF normalization warnings only).
- ZIP `LuaPad-2.0.0-preview13.zip` contains **16/16 hash-matching entries**; ZIP SHA256 `50c7572f8c3c1c7fee074da328c2cc8f15d0ad2b2894f9e83ece67553ca9a4c8`.

## Guarded physical AddOns hot-copy
- `main.lua`: old installed SHA256 `1dd1656bfb8844ea6bacb1171a9a256f5719a31f9a67f3fbfdb19444e56cf1c1` → new source/installed SHA256 `dd87c32485174571b9195921e3e48a39221647f8dec95365fcd4441ed325b701`.
- `RiftAddon.toc`: old installed SHA256 `20f12dcec12a37bd97ecf52a5436182b4e9136c722968e87477037a67773fe44` → new source/installed SHA256 `469d024d9091caf188f433bf00b8a1c5e3832113f6158f95b4995892130174f6`.
- Verified originals backed up at `C:\work\LuaPadModern\backups\luapad-preview13-before-hotcopy-20261103-183122` before overwriting. Guarded copying has automatic restore attempt on failure and rejects mismatched original hashes.
- `Inspector/main.lua` and `Inspector/RiftAddon.toc` left untouched from Preview 12.

## Manual acceptance
After Joey decides `/reloadui` is safe, confirm LuaPad Preview 13 and Inspector Preview 5 titles and perform LP-35, LP-36, LP-37, plus IP-22–IP-24, in `TEST-PLAN.md`. Capture addon errors/screenshots before claiming physical RIFT success.
