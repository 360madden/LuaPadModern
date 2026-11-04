# M2 slash-command transport pilot — source checkpoint

Date: 2026-11-04
Scope: `C:\work\LuaPadModern` source only. No active RIFT AddOns copy, TOC change, slash registration, focus action, game keypress or /reloadui.

## Result

An isolated Lua 5.1 `Bridge/slash.lua` adapter parses a deliberately small slash-command grammar into the existing `Bridge/router.lua` read-only request envelope. It returns a correlated JSON result through an **injected** copy function. The host must independently validate the actual clipboard bytes and request/session IDs.

Planned command text (not registered in RIFT yet):

```
/lpb v1 health req-20261104-0001 winhost-session-20261104
/lpb v1 caps req-20261104-0002 winhost-session-20261104
/lpb v1 status req-20261104-0003 winhost-session-20261104
```

| Verb | Router operation | Effect |
| --- | --- | --- |
| `health` | `health` | Read-only bridge readiness summary; does **not** claim live host link |
| `caps` | `bridge.capabilities` | Available operations and `read-only` mode |
| `status` | `ui.status` | Read-only RIFT context/window/editor facts; occlusion **not** verified |

No arbitrary Lua text or JSON payload is accepted through this command. The parser requires four whitespace-delimited tokens, `v1`, one of those three verbs, and host-owned request/session IDs. Total command text is capped at 256 bytes, request ID at 80 bytes and session ID at 96 bytes. Newlines, NUL, unsupported commands and malformed identity are rejected before routing.

## Delivery and readiness truth

- The source module does **not** call `Command.Slash.Register`. Actual RIFT slash callback arguments are unverified, so `adapter.callback` currently accepts **exactly one string argument** and rejects other callback shapes. This is a **prototype**, not a working `/lpb` command in the game.
- The adapter injects a `copy(json)` function intended for `Command.CopyToClipboard`, but does not invoke the game API until separately integrated. A successful call only creates a local `copyApiInvoked` receipt, **not** a claim that the Windows clipboard actually contains the result.
- On malformed syntax, router exceptions, missing/mismatched result identities, non-result status, oversized output or clipboard exceptions/explicit `false`, no successful receipt is produced. Input and source-only status operations never mutate RIFT UI focus, strata or layers.
- The router still reports `liveTransportReady=false` by default and emits no fictitious `meta.transport` field. `ui.status` still reports `canVerifyOcclusion=false`.
- Native clipboard APIs may return `nil` even without throwing. That is recorded as an invocation, not proof of delivery. The host must check clipboard content after the call.

## Host-side acceptance contract (M3)

The Windows host should:

1. Pin exact RIFT process PID, process start and HWND. Reject ambiguous clients or changed targets.
2. Generate a unique request ID and session ID; track one bounded in-flight read-only command.
3. Record clipboard pre-state, send the command only after Windows foreground, game size and RIFT input readiness gates are met. If coordinates are used, remeasure immediately.
4. Read clipboard after dispatch and parse JSON with the v1 schema; verify protocol, kind, version, request ID, session ID, operation and addon source. Reject unchanged/stale/wrong-ID bytes, non-JSON, truncated or oversized response. Do not infer success from the command being typed.
5. For `ui.status`, keep window foreground/screenshot/occlusion evidence **separate** from addon-observed layer and editor focus. Do not type in LuaPad unless all gates independently pass.
6. Timeout with an explicit uncertain result. Never silently replay an arbitrary Lua execution command; this prototype has no such command.

## Headless verification

`node.exe verify-bridge.cjs`: **442/442** assertions across five suites:

| Suite | Assertions |
| --- | ---: |
| Pure Lua v1 codec | 39 |
| Read-only UI status | 40 |
| Router dispatch/replay | 70 |
| Source-only slash adapter, callback errors, clipboard/result correlation | 165 |
| Existing LuaPad + Inspector runtime mock | 128 |

`node.exe verify-preview.cjs`: all 56 structural checks green.
`node.exe contracts/verify-contract.cjs`: three positive and eleven negative cases green.

Fengari may exit with code 0 despite a Lua traceback. `verify-bridge.cjs` explicitly requires each suite's exact PASS summary and rejects traceback output. Source/mock success is not a physical RIFT pass.

## Historical RIFT API evidence

- The [Archimedes addon implementation](https://repos.curseforge.com/rift/archimedes/comparison/9f0cd7ae1c86/core.lua) registers its slash handler with `Command.Slash.Register` and defines `function Archimedes.SlashHandler(args)`, treating `args` as text.
- The [Rift Meter addon source](https://gist.github.com/Bamux/6bc1062bf3ad49887c9bec642e471271) uses `Command.Event.Attach(Command.Slash.Register(...), Events.SlashHandler, ...)` and declares `function Events:SlashHandler(params)`, a colon-method form with an implicit receiver. This does not establish the exact raw callback shape for the present live RIFT client.
- [RIFT API docs](https://www.seebs.net/rift/pts/index.html) describe slash registration returning an event table. Neither historical style is a substitute for the live gate; the prototype deliberately requires one trailing argument string until measured.

## Next gate

1. Confirm physical `Command.Slash.Register` callback argument shape with a tiny diagnostic handler and bounded notice, without disturbing other slash handlers.
2. Only after explicit approval for focus/reload, make backup and hash-verified copy to the active addon; register a distinct `/lpb` command; rerun gates.
3. Verify one read-only health request, host clipboard correlation, `ui.status`, and another-addon overlap and editor focus with screenshots. If callback or clipboard behavior differs, keep the bridge disabled and correct the adapter.
4. Then implement the .NET 10 Windows host and typed Workbridge MCP tools; do not mark M2 complete until the physical result is proven.
