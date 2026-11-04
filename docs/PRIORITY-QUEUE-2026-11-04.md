# LuaPadModern — three-lane concurrent queue (2026-11-04)

Owner: Joey Delfierro. Repository: `C:\work\LuaPadModern`.

All three priorities were executed in parallel from the same clean baseline. Offline gates are complete, but physical in-game acceptance remains separate.

| Lane | Objective | Exclusive implementation area | Exit gate | State |
| --- | --- | --- | --- | --- |
| Lane A — Log discovery | Resolve actual Windows Documents/RIFT log paths reliably and add offline tests. | Node watcher defaults, HostProbe defaults, new discovery tests | Deterministic fixture tests plus old log/host gates | Offline ready: Node 24/24 + 40/40; .NET discovery 16/16 + CLI 15/15; actual RIFT path unconfirmed |
| Lane B — No-reload pilot | Make an opt-in outbound marker observation reproducible without requiring a UI reload. | Separate pilot harness and M2 pilot instructions | Synthetic end-to-end receipt without game input; physical RIFT receipt tracked separately | Offline ready: 21/21 tests (live transport unverified) |
| Lane C — Center/title | Verify Preview 20 center anchoring, front ordering and `Joey Delfierro` title/TOC. | LuaPad UI source and structural/mock tests | Headless regressions; separate physical screenshot only when authorized | Offline ready: 8/8 tests; installed files match (live visual pending) |

## Coordination rules

- Each worker owns only its assigned source/tests; never overwrite another lane or unrelated user edits.
- No RIFT game focus, input, `/log`, `/reloadui`, active-addon hot-copy, service startup or account SavedVariables mutations during unattended work.
- Source/mock evidence and real RIFT acceptance are separate. A synthetic Log.txt match is **not** proof that RIFT writes the marker.
- Coordinator reviews results, reruns shared regressions (serialize .NET builds that share `HostCore/obj`), commits only verified changes under `Joey Delfierro`, and updates this queue.

## Physical gates held for Joey

- **Lane B:** When convenient, Joey enables `/log` in RIFT (after confirming current toggle state), executes the printed marker in the already-open LuaPad, and compares an exact nonce receipt from the real Log.txt path; no addon reload required.
- **Lane C:** At an authorized normal game launch or `/reloadui`, confirm auto-open centered and topmost, expected title, and editor keyboard focus separately.

