# H.E.X. Spell Loom stabilization checkpoint

Status: P0 repair candidate packaged and regression-tested; broader acceptance goal INCOMPLETE.
Date: 2026-09-21. Checkout: `C:\Users\sende\Projects\hex`. Main HEAD remains
`1559a566e33255c59337c5963f1c3c685d757f1f`; local uncommitted changes only.
Runtime candidate: `p55-a0952919d4d5` (protocol 55, 48 px whole cells, 2,766-cell campus).

## Cause and repair

The original offline request applied actor 1's complete weave, then confirmation
compared actor 1 with `SessionTransport.local_entity_id`, which was 0. The valid
confirmation was ignored. Pending Loom input returned before processing Escape,
controller Back or the close button. Its tick-based deadline was checked only
when feedback or state arrived, so an ordinary offline assignment could leave
the modal permanently locked.

The preserved `p55-c7b7694f8d23` PCK reproduced this through Interact, Right and
Enter: authoritative wires changed, the request stayed pending, and Escape
failed. The actual preserved Windows EXE separately reproduced mouse selection
and Assign followed by a failed X-button close. The native EXE test arranged
spawn and opening with capture flags; an injected physical F binding was not
established by the computer-use tool. Source/PCK instrumentation exercised
station Interact itself. These evidence scopes are deliberately separate.
See `loom-baseline-v3.json`, `baseline-modal/blocked-close.jpg` and
`baseline-modal/game.log`.

Bootstrap now binds actor, champion, sequence and transport mode, entity, epoch
and peer context. It checks completion every frame with a 5-second monotonic
deadline, allows closing while pending, prioritizes matching confirmed authority
at the deadline, and never rolls authority back after a UI timeout. Duplicate,
stale and other-actor acknowledgements cannot save a newer transaction. Success,
refusal and save-failure notices distinguish current session state from disk
persistence.

A second red regression showed that removing and restoring a cooling non-legacy
spell reset its cooldown from 7 to 0. CharacterWeavePolicy now refuses that
removal before mutation; retained or swapped spells preserve their cooldown,
and removal succeeds after expiry. Legacy single-slot admission also refuses
active paid casts and uses this policy. Persistence write failure preserves the
usable accepted session weave and previous disk-library memory. Personal profiles
are never used by automated test processes.

## Executed evidence

| Check | Result / scope |
| --- | --- |
| Baseline Loom regression | FAILED as expected: 3 failed assertions out of 46; lock reproduced in the native PCK and actual EXE |
| Baseline cooldown regression | FAILED as expected: 4 failed assertions out of 21; red receipt retained |
| Focused candidate | PASS: 5 suites, 5,354 assertions, zero stderr; acknowledgement, policy, integration, library and editor |
| Real source journey | PASS: assign → confirmation → Escape → move → paid Heavy cast costing 18 Flux → save → separate-process restart; `source-journey-v2/` |
| Character/input journey | PASS: 19 checks covering Water filter, drag to Alt+4, controller selection/assignment/Back, paid cast, Gallery switch and return, and independent disk reload; `character-journey-v1.json` |
| Full | PASS: `full-v3.json`, 157 suites / 803,905 assertions, zero stderr, 257,538 ms. Import and 120 Hz configured boot passed. `full-v1` failed on a misnamed JPEG evidence import; `full-v2` failed on a missing explicit playtest status. Both corrected; failures retained. |
| Windows/PCK/ZIP | PASS: actual EXE automated launch, runtime identity and safe close; exported PCK assign/close/move/paid cast/save/separate-process restart; seven ZIP entries match disk and CRC validation passes. See package `receipt.json`, `packaged-journey/` and `zip-audit.json`. |
| Interactive candidate EXE | INTERRUPTED: user stopped Computer Use before candidate interaction. Existing 300-second watchdog subsequently closed owned PID 103720 and exited with failure. This run does not prove safe close or gameplay; the separate automated export smoke passed. See `candidate-modal/game.log` and `candidate-modal/status.json`. |
| Network lifecycle | Baseline FAILED at 300.939 seconds against unchanged 300-second deadline; fresh candidate NOT_RUN. Multiplayer remains unaccepted. |
| Preservation | Three personal JSON files, index, HEAD and selected pointer unchanged; prior PCK/ZIP hashes match the historical receipt |

The restart in `source-journey-v1` failed only its diagnostic float-versus-integer
JSON comparison; restored IDs were already identical. Version 2 corrects the
oracle without changing persistence. `p0-focused-v1` caught a candidate GDScript
type error; version 2 caught stale generated identity. The retained direct guarded
focused log is the subsequent green run. Final Full passed against frozen runtime
`p55-a0952919d4d5`; subsequent reconciliation changed documentation only. See
`p0-review.md` for independent review. The review's legacy save-feedback ordering
finding was corrected before final Full and packaging.

## Measured performance and unresolved acceptance

Fresh stage profile of an identical paid workload on the 48 px, 2,766-cell map
with eight champions:

- World capture: p50 471.974 ms; p95 556.525 ms.
- World preparation: p95 304.929 ms.
- Chemistry capture: p95 150.843 ms.
- Chemistry restore: p95 333.664 ms.
- World hash: p95 77.951 ms.
- Topology hash: p95 9.328 ms.
- Prediction binding: p95 74.586 ms.

Each stage has five samples. These are inclusive headless timings, not frame,
transport or capacity certification. All 332 correctness assertions passed;
timing is severely over budget. No optimization was integrated, and no timeout,
cap or state validation was weakened. The target remains 120 Hz / 8.333 ms.
The proposed next optimization of the stateless empty-cell validator needs
independent equivalence against the old oracle and a paired timing test.

| Feature | Mode / action | Evidence | Current status |
| --- | --- | --- | --- |
| Representative Loom assignment, drag, controller and close actions | Offline source and packaged PCK | Executed journeys above; controller/drag coverage in source | Newly verified P0 paths; interactive candidate EXE interrupted |
| Spell-owned cooldown and failure recovery | Authority and UI harness | Red-to-green regressions; late/duplicate/context/timeout/write-failure checks | Repaired; physical controller and network-failure feel remain separate |
| Save/restart/Gallery restoration | Isolated offline source | Separate-process restart and 19-check journey | Verified for a representative custom weave |
| 32 spells × 12 positions | Existing editor mapping tests | 4,951 editor assertions cover models, filters and drag | Still exposed; every wire's full paid journey NOT_RUN |
| 30 profiles | Three existing body templates | Representative Gallery switch | Not 30 finished skins or 30 accepted journeys |
| Movement, settings, practice and all menus | Existing implementation | Prior unit/native evidence plus this movement smoke test | P1 shared availability policy and complete end-to-end table unfinished |
| Multiplayer | Host/join/ready/reconnect/spectate/rematch | Baseline FAILED at 300 seconds | Experimental; cannot be called friends-ready |
| New assets | Staged only | 246/246 manifest payload hashes verified | Not integrated into runtime; no exported new-asset acceptance |

## Returned packs

See `assets/HANDOFF.md` and `assets/inventory.json` for each proposal's
accept/adapt/defer/incompatible classification, input hashes, dimensions,
transparency, layouts, original provenance and duplicates. Of 48 old repository
inputs, 39 match and nine changed. Animation copied nine existing body PNGs;
chemistry contains six design experiments and zero PNGs. The map's 64 px
eligibility evidence is incompatible with 48 px; retain layout ideas as proposals.
Six transparent Water/Fire/Steam motif sheets at 64 × 80 need 0.75 cosmetic
sampling clipped to actual authoritative polygons. No new textures, characters,
map or balance changes were integrated in this P0 checkpoint. Previews, concept
art and proposed tests are not acceptance. Original archives and 250 safely
staged files are preserved behind `.gdignore`.

## Launch and focused human route

Candidate launch:
`C:\Users\sende\Projects\hex\exports\hex-loom-fix-20260921\windows\PLAY-HEX.cmd`

Portable ZIP (extract the complete ZIP, then run `PLAY-HEX.cmd`):
`C:\Users\sende\Projects\hex\exports\hex-loom-fix-20260921\HEX-p55-a0952919d4d5-Windows-x64.zip`

Runtime SHA-256: `a0952919d4d5e957130361422a2eb68efb5d0993ad50a747e7a2574c23bcced4`.
PCK SHA-256: `9540681ef8a9bf7b62a6581cab7c608850f1c34dd101d13a3dc6a6009aa9bb2c`.
ZIP SHA-256: `d7655d2988f09ce3fbe98e53f636f37cf87e34fff980b52cef20494c3a63f94f`.
Package receipt: `exports/hex-loom-fix-20260921/receipt.json` from repository root.
All automated journeys used isolated profiles. Ordinary launch uses the existing
compatible personal profile, so human playtest changes will save normally.

Preserve the previous `exports/hex-small-grid-20260921/windows/PLAY-HEX.cmd` and
the protocol 54 `exports/hex-vision-20260920/windows/PLAY-HEX.cmd`.
Never mix runtime builds.

Source launch:

```powershell
Set-Location C:\Users\sende\Projects\hex
.\scripts\run.cmd
```

1. At Spell Loom, assign Tide Shell to slot 1, close, move and cast. Verify the 18 Flux payment.
2. Filter Fire and drag to a Ctrl/Alt slot. Close and press its displayed binding. Swaps must retain 12 unique IDs.
3. Try replacing a cooling spell. Expect atomic refusal until natural expiry, while swapping remains allowed.
4. Switch characters in the Gallery and return, then restart and verify the weave. Report an unsaved notice without resetting the profile.
5. Try rapid assignment, focus loss and Escape. Closing a pending view must not falsely cancel host authority.

## Next smallest slices

1. Finish representative candidate EXE interaction and unchanged same-export
   lifecycle, retaining the interrupted run and existing network failure. Complete
   the P1 shared accepted/temporary/experimental availability policy
   and data-driven coverage of actual requests and paid casts for every enabled
   wire/slot. Retain saved IDs and 12 positions. Honest gating does not replace
   multiplayer engineering.
2. Optimize one measured snapshot validator hotspot while preserving identical
   bytes, malformed-input rejection and mutable ownership, with paired old
   oracles. Retry the unchanged same-export lifecycle. Do not expand simulation load.
3. Integrate Water motifs in normal and reduced modes first, then Fire/Steam
   with per-region heat. Require real native comparisons at default zoom and
   zoomed out, across terrain and density, plus proof of loading in the export.
4. Integrate one body-animation pilot, then one Wellspring area. Do not replace
   the roster or map wholesale.

No commit, push, release, installer/updater, pointer promotion or fallback
replacement. The larger durable goal remains open. Stop before weekly remaining
usage reaches 33%; the latest check was 35%. Further implementation stopped with
a handoff buffer remaining. Do not infer completion from this P0 repair.
