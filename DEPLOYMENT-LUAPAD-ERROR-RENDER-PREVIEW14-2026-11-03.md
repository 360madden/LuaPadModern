# LuaPad bounded error rendering — Preview 14 (2026-11-03)

## Release status
- LuaPad `2.0.0-preview14`; embedded Inspector remains `1.9.0-preview5`.
- Project `C:\work\LuaPadModern`; installed addon `C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns\luapad`.
- Source and installed files hash-verified. **Not yet reloaded in physical RIFT**, and no game focus, input or process operation was performed.

## Reproduced failure and repair
The previous `LuaPad.doRun` runtime error path appended an unbounded traceback to the output Text frame. A mocked error containing 4,000 lines failed the `huge LuaPad error preview bounded` regression; the widget height could grow far beyond the viewport. This differed from Inspector's already-bounded error path.

- `setOutput` now keeps the entire message separately in `lastOutput` for Copy Output, while rendering no more than 12,100 UTF-8-boundary-safe bytes or 300 newlines. A visible notice indicates when content is shortened.
- LuaPad's Copy Output reads `lastOutput` rather than the shortened widget text.
- Consecutive `LuaPad.print` calls and post-print error output read `lastOutput` to avoid mistakenly treating the displayed notice as real program output or losing lines.
- The existing 12,000-byte printed-output history cap remains intact. The separate full-error clipboard behavior applies to errors that are not printed through the history cap.
- Edge cases covered: 4,000-line exception, consecutive 700-line print followed by `tail`, and a multibyte UTF-8 error at the rendering boundary.

## Validation
- Combined Fengari runtime mock: **116/116 assertions passed**; red failure before source change and green afterward.
- Structural validator: **54/54 checks passed**.
- `luaparse@0.3.1`: all **9/9** Lua source files parsed.
- `git diff --check`: no errors (only Git informational line-ending normalization warnings).
- Archive `LuaPad-2.0.0-preview14.zip`: all **16/16** entries matched source SHA256; archive SHA256 `87841264087ee431cfeaaa60ac76b73e5a3f44d76aa9bf246faff4403e2f93d1`.

## Verified guarded hot-copy
- `main.lua` Preview 13 installed SHA256 `dd87c32485174571b9195921e3e48a39221647f8dec95365fcd4441ed325b701` → Preview 14 source/installed SHA256 `54a48364d8ef28cb148e2a3f22bfb7757d3eec0de06d12991544355f1a8b73c2`.
- `RiftAddon.toc` Preview 13 installed SHA256 `469d024d9091caf188f433bf00b8a1c5e3832113f6158f95b4995892130174f6` → Preview 14 source/installed SHA256 `53e37dcc8103baf0b578a38abb0873bb244d002847259452784e7169b378cab9`.
- Verified backup at `C:\work\LuaPadModern\backups\luapad-preview14-before-hotcopy-20261103-183836`. The copy guard rejects unexpected old hashes and attempts rollback on any copy failure.
- Inspector files were not modified in this release.

## Pending manual game gate
When Joey decides it is safe: `/reloadui`; verify `LuaPad v2.0.0-preview14` and `Inspector v1.9.0-preview5`, then test LP-38–LP-40 from `TEST-PLAN.md`. Test moderate error input outside combat, capture any addon errors and confirm full clipboard paste externally. Earlier unaccepted gates remain open. No live RIFT success claim is made.
