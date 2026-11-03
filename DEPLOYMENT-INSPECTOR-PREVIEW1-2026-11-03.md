# Inspector preview 1 / LuaPad preview 4 — 2026-11-03

## Scope and design
- Inspector inspected directly in `Inspector/main.lua` and `Inspector/RiftAddon.toc`. Previous deployed Inspector 1.8 had a text field for large results, no clipboard export, a reversed nonintegral depth control, a clipped 800x600 Help text area, inconsistent buttons, silent invalid-input handling, and false cycle flags for shared tables.
- The new Inspector window remains 800x600 and retains public `Inspector.showInspectionWindow()`, `Inspector.doInspection(expression, depth)` and `/ti` integration.
- Results now use a 750x346 masked ScrollView with read-only Text and a unified Copy Output action, backed by exact bounded raw result.
- Header and Help versions are read from `Inspect.Addon.Detail("Inspector").toc.Version`; ready notice prints on init.
- Depth slider maps directly to integer 1..5. Input, result, actions, and Help use explicit non-overlapping bounds.
- Traversal tracks the *active* recursion stack (so shared references are allowed), sorts limited keys, caps scanning 300 keys per table, caps 300 nodes / 12,000 characters, and protects inspection and formatting using `pcall`.
- LuaPad shell version bumped to `2.0.0-preview4`; embedded Inspector version `1.9.0-preview1`.
- SavedVariables were not changed; no account data migrations.

## Validation gates
1. `node verify-preview.cjs` — expected 37 structural checks.
2. `npm exec --yes --package=luaparse@0.3.1 -- luaparse Inspector/main.lua` — syntax only.
3. Source/installed SHA256 for three changed files and parity of archive payloads.
4. Manual in physical RIFT after /reloadui: check `[Inspector v1.9.0-preview1] READY` and `[LuaPad v2.0.0-preview4] READY` in chat; open /ti, inspect `Inspect` at depth 1 and `Inspector` at depth 2.
5. Run syntax error (`Inspect.???`) and runtime error (`error("inspector test")`); copy each result and paste outside RIFT. Check Help fits, depth 1..5 increments normally, horizontal labels don't overlap, scroll 300-line output, and Close / reopen.
6. For shared table: use LuaPad Run to set `InspectorFixture = {first={n=1}}`; `InspectorFixture.second = InspectorFixture.first`; inspect `InspectorFixture` at depth 3. Both fields should render without a false [cycle]. For real cycle: `InspectorFixture.self = InspectorFixture` and inspect again. Expected [cycle].
7. UI feedback is still required from Joey; structural success does not prove actual RIFT widget compatibility.

## Verified deployment receipt (15:53 ET, 2026-11-03)
- `node verify-preview.cjs`: **37/37 PASS**.
- `luaparse@0.3.1 Inspector/main.lua`: **PASS**.
- `LuaPad-2.0.0-preview4.zip`: **16/16 entry SHA256 parity PASS**, SHA256 `94b4317992be1ebb199da18ab2447b475d3dac17af770d3a6306ffb978825f3c`.
- Physical installed three-file preflight hashes matched prior Preview 3. Source and installed SHA256 parity verified post-copy:
  - `Inspector/main.lua`: `daf27aa11c51065f78bc142b08e9d5a7433e21bc69ece4ba1b4dda7f463f4555`
  - `Inspector/RiftAddon.toc`: `0d2f1b27dff27e7245c91cd77f64437a08187aaa8b5ed386eb1abf625c09a35e`
  - `RiftAddon.toc`: `ac3c3c0289cad4f90b38c6e482d14702ffc758e1e118db7c2ddd9ce464c2a259`
- Verified reversible backup at `C:\work\LuaPadModern\backups\luapad-preview4-before-hotcopy-20261103-155337`.
- RIFT was **not** focused, closed, reloaded or captured by tooling. New code is on disk but is not active in the running Lua runtime until Joey types `/reloadui`.
- Manual acceptance tests IP-01 through IP-12 remain pending.

## Safety and rollback
- The physical RIFT client must remain running; no focus, process stop, window capture, or UI reload is initiated by automation.
- Hot-copy only changed source and TOCs after backing up existing installed originals and verifying SHA256; the running Lua VM remains on previous code until Joey types `/reloadui`.
- On failure, revert the three files from the new timestamped backup and /reloadui. Do not touch account SavedVariables.
