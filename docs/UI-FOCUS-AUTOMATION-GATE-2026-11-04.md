# LuaPadModern UI stacking, keyboard focus and automation readiness
Date: 2026-11-04. Status: source-backed diagnosis and implementation design; **physical overlap acceptance pending**.

## Why this is a bridge concern

Windows foreground activation does not guarantee LuaPad is the top reachable RIFT addon, nor that its code editor receives keyboard input. Three independent states:
1. **Windows client:** exact RIFT PID, HWND, process start and foreground/minimized/window bounds.
2. **RIFT stacking:** LuaPad window visible, its context's strata and layer, relative overlap with other addons/native dialogs.
3. **Editor focus:** the RiftTextfield owns key focus and the selected editing target is known. Focus is not inferred from a click return code.

## Source findings (Preview17)

- main.lua creates UI.CreateContext("LuaPadContext") and a RiftWindow in that context (lines 22-23).
- init() hides LuaPad and sets luaPadWindow:SetLayer(1) (lines 203-210).
- /lp and /luapad call showLuaPad, which only sets title and visible (lines 371-375, 577-579). It does **not** raise the context/window or set editor focus.
- Inspector separately sets textWindow:SetLayer(1) and opens with SetVisible(true); multiple addon contexts can compete for visual priority.
- The editor already calls inputField:SetKeyFocus(true) within its Enter/Tab handler, but opening the window does not explicitly acquire editor focus.
- A Windows read-only discovery on 2026-11-04 found the physical RIFT client as rift_x64/TWNClientFramework; it was not foreground while ChatGPT was in use. This does **not** establish which addon overlaps LuaPad.

Historical RIFT addon API documentation (verify against RIFT Live):
- Frame:SetLayer/GetLayer controls numeric order: https://www.seebs.net/rift/pts/riftwindow_setlayer.html
- Frame:GetStrata, GetStrataList, SetStrata control coarser ordering: https://www.seebs.net/rift/pts/frame_getstrata.html
- Frame:GetKeyFocus / SetKeyFocus manage keyboard focus: https://www.seebs.net/rift/pts/frame_getkeyfocus.html
- RIFT 1.7 release notes say dialog interaction may change context layer order: https://www.riftui.com/forums/showthread.php?t=217

## Proposed source-of-truth API

A read-only addon operation named **ui.status** returns a bounded structured snapshot. Unavailable fields must be marked absent, never invented:

- windowVisible from LuaPad window.
- contextLayer, contextStrata, windowLayer, windowStrata, when available.
- editorKeyFocus from actual RiftTextfield.
- windowBounds (left/top/width/height) at request time.
- canVerifyOcclusion=false initially; LuaPad's own layer cannot guarantee no overlapping UI.
- addonVersion from RIFT TOC, with source addon.

Windows host separately supplies windowForeground, pinned HWND/PID, screenshot evidence, timestamps and UI Automation results. **Do not merge host evidence into addon-observed fields**.

## Activation policy

- User /lp or explicit host ui.ensureReady may request to raise LuaPad. Read-only health and telemetry must not steal focus.
- Measure context layer/strata before changing either. Do not hardcode extreme SetLayer(9999999) or permanent topmost; establish bounded reversible policy using physical tests.
- For explicit editor-input operations, require visible LuaPad, acceptable layer, inputField:SetKeyFocus(true), and read back GetKeyFocus()==true. Confirm Windows foreground HWND before injecting Enter/Tab.
- Screenshot/occlusion is independent: editor key focus alone is insufficient with a modal or overlapping addon.
- Re-measure after move, resize, display change, maximize/restore, or reload UI. Never reuse stale coordinates.
- Fail with WINDOW_NOT_FOREGROUND, LUAPAD_OCCLUDED, EDITOR_NOT_FOCUSED, TARGET_CHANGED or UI_UNVERIFIED, rather than reporting attempted clicks as success.
- If safe, return focus to previous control after explicit input; do not guess or steal focus during polling.

## Physical acceptance matrix

| Scenario | Evidence required | State |
| --- | --- | --- |
| LuaPad opened with another addon above | Before/after screenshot, GetStrata/GetLayer, front order | Pending |
| /lp used after native dialog interaction | Consistent z-order promotion without concealing native dialogs | Pending |
| Editor click, Enter, Tab | Exact HWND foreground; editor focus true; actual text and screenshot | Pending; Preview17 basic keys passed |
| Window resize or move | Fresh client bounds, no old-coordinate action | Pending |
| RIFT loses foreground mid-action | Input aborted and reported; no blind replay | Pending |
| Inspector alongside LuaPad | Predictable stacking and deliberate focus handoff | Pending |
| Reload UI | State invalidated and freshly acquired; no false ready | Pending |

## Implementation order

1. Add mockable ui.status observation without layering mutations.
2. Test hidden/no-focus, visible-but-occluded and foreground-without-editor-focus.
3. Add deliberate ui.activate and ui.focusEditor after verifying actual context semantics, using bounded layers.
4. Add Windows-host readiness gate correlating pinned HWND/PID, addon state and a fresh screenshot.
5. Physically test overlap/key injection before exposing Workbridge tools as live-capable.

This document does not claim the physical RIFT z-order bug is fixed.
