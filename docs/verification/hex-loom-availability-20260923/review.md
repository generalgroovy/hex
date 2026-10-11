# E1 independent review â€” contextual Loom availability

Status: **FINAL BOUNDED REVIEW PASS.** No remaining static, evidence-integrity or inspected visual blocker for E1 contextual Loom availability. Recommend the verified E1 v2 Windows artifact as the new local solo test candidate, retaining D6 as fallback. Reviewer ran no engine and edited only this report. This is not checkpoint promotion, human acceptance, capacity or multiplayer approval.

## Frozen source

Reviewed the seven changed source/unit files against preserved originals. Bootstrap SHA-256 is `838c42d202e7fc04f5396d44f627c806849e9b9270427ae3b049a329fa6aeafc`; development runtime is `p55-c5d0f6accb97`.

- `_session_request_refusal_reason` extracts the prior authoritative admission operation unchanged and is shared by authority and advisory UI. Whole-weave admission still permits Spell Loom or Gallery, and preserves the isolated offline Hex Court exception. Server-side request shape, champion identity, expected-weave equality and actual application remain revalidated.
- `CharacterWeavePolicy.can_apply` and `blocking_cooling_wire` preserve the old validation-before-mutation rule. Removed cooling non-legacy spells are refused; retained spell movement, independent legacy aliases and cooldown identity remain unchanged. No spell catalog, balance, cost or unlock gate was introduced.
- Ordinary assignment builds the same duplicated weave and swap through `requested_wire_ids`. Shared submission gating covers keyboard, controller, click and drag routes without changing their input dispatch. All 32 spell browsing, filters and starter preparation remain available while location/action/round/cooldown prevents final assignment. The pre-existing pending input quarantine still permits closing without revoking a sent request; it does not promise browsing during that interval.
- The draft stale-preview issue is resolved: explicit `starter_context` checks current champion and expected weave before painting/submitting Apply. Ordinary and automatic saved-weave restoration use the default false context, so an unrelated open preview does not impose its snapshot guard. Sequence exhaustion also paints a reason matching the existing submission guard.
- Independently compared complete function text: `_handle_spell_loom_input`, `_complete_pending_weave`, `_matches_pending_weave_feedback`, `_ingest_session_feedback`, `_try_restore_client_weave` and `_close_spell_loom_editor` are unchanged from preserved baseline. Acknowledgement identity, confirmed-state saving, timeout, late confirmation and close-without-revocation behavior are retained.

## Regression and native evidence

Read fresh `focused-v1.json`: **5 suites / 5,277 assertions / zero failures**. The new inherited Bootstrap test checks station and Gallery admission, remote refusal, round/action/dead states, cooling removal, stale preview, pending request, sequence exhaustion and offline Hex exception. Existing acknowledgement tests cover wrong/late/duplicate feedback, timeout, session/character invalidation and saving only confirmed matching authority. These are local engine tests, not remote-session proof.

The first native baseline was insufficient for ACTIVE-round coverage: its empty-participant SessionRound decoded to the fallback HEARTH state. Candidate after-v1 correctly exposed this fixture problem and is retained as **FAILED: 3 of 65 assertions; 10 captured frames**. It is not a production-policy failure or a passing candidate receipt. The baseline-v1 active-round row is superseded.

Read the corrected journey source and both v2 receipts. Two participant score records plus an explicit decoded-ACTIVE assertion now establish the round fixture. Baseline **before-v2 PASS 53 checks / 9 frames** positively observes matching authority refusal events for the previously enabled actions. Candidate **after-v2 PASS 78 checks / 10 frames** verifies unavailable input sends no sequence, creates no authority event, leaves actor/pending state unchanged, and neither creates nor rewrites the saved weave. Eligible assignment confirms Water Heavy in slot 1, preserves Flux during assignment, saves, permits closing and resumed movement, and begins a real slot-input cast spending **18,000 raw units = 18 Flux**.

Independently verified every indexed preserved artifact for before-v2 (13), failed after-v1 (14) and after-v2 (14); all hashes match. Read receipts, retained failure messages, source and zero-error run results. Fresh candidate receipt identifies `p55-c5d0f6accb97`.

Viewed native after-v2 away Assign, away starter Apply, stale preview, pending, ACTIVE round, cooling removal and confirmed frames, plus the preserved away baseline. Disabled controls are visibly muted, reasons fit the panel, starter rows and Cancel remain visible, and confirmed assignment restores the active action with the correct Tide Shell slot. This is a bounded automated visual inspection, not human acceptance or every resolution/input-device check.

All ten policy-query rows contain 128 samples. Recomputed nearest-rank medians span **1â€“89 microseconds**, p95 **2â€“119 microseconds**, maximum **336 microseconds**. This times only repeated advisory helper calls inside an open modal; it excludes proposal construction, drawing, simulation, transport and frame cadence. It cannot establish frame-rate, capacity or multiplayer performance.

## Remaining limits and recommendation

The frozen implementation and exact v2 Windows package pass the bounded E1 review; final evidence is recorded below. The source native journey arranges positions, action locks, round and pending state, then injects production UI events. It does not establish physical input, real network lifecycle, all character/spell-slot combinations, human feel or capacity. The journey's saved-file existence assertion is complemented by existing acknowledgement/persistence tests; the fresh exact packaged restart journey below now verifies all twelve restored wires.

## Package-v1 failure and bounded repair

Independently read `full-v1.json`: **160 suites / 805,129 assertions / zero failures and stderr**, import/asset audit and 120 Hz boot completed, 243,972 ms. Its `package_and_installer` flag is false; this passing source result does not validate the following export.

The first exact E1 EXE failed to parse Bootstrap and hit the root-owned 120-second smoke watchdog. The preserved `class-cache-failed-v1.cfg` resolves CharacterWeavePolicy, SpellLoomEditor and SpellLoomPresenter to verbatim `docs/verification/hex-loom-availability-20260923/final-freeze-v1/source/...` files. Export excludes `docs/*`; `exports/hex-loom-availability-20260923/logs/export-smoke.log.err` reports the corresponding unavailable global types and cascading Bootstrap parse failure. `FAILED-VALIDATION.txt` correctly marks this artifact unusable and points to the prior verified D6 fallback. No successful E1 package receipt is established by this attempt.

The evidence root now contains `.gdignore`, excluding all nested verbatim historical scripts from Godot discovery. This repairs the duplicate-class import source without changing production code. The existing canonical class-cache checker compares exact declared source paths and throws for wrong, missing, duplicate or unexpected entries. The final wrapper invokes the checker immediately after export, before runtime-state inspection or EXE launch. Its fresh report passes all 151 canonical classes with zero violations. Subsequent exact EXE smoke also passes, supplying the packaged-runtime check beyond the working-cache inspection.

## Final v2 source, package and journey acceptance

Final runtime: **p55-c5d0f6accb97**, canonical production SHA-256 `c5d0f6accb97756c003bf3e72203b430883a178c745342c9b269864be5e91619`, 2,800 records. Protocol 55 and snapshot schema 21 remain unchanged. Verified all ten `final-freeze-v2` files against both current files and preserved bytes. The four production files retain the reviewed hashes; the package repair changes the wrapper and evidence import boundary, not runtime behavior.

| Fresh validation | Independently inspected result |
| --- | --- |
| Full-v2 | PASS 160 suites / 805,129 assertions / zero failures and stderr; import, registry, asset audit and 120 Hz boot; 225,352 ms |
| Exact Windows EXE | Export and native identity/safe-close smoke pass; both stderr files empty; post-export registry 151/151, zero violations |
| Exact PCK availability | PASS 78 checks / 10 frames; six blocked paths preserve authority/save state without a request; correct runtime identity |
| Source versus PCK Loom visuals | All 10 frames match dimensions, decoded RGBA bytes and PNG hashes; independently recomputed |
| Basic movement/paid casting | PASS 27 cases / 11,601 checks, 192 router samples; arranged profiles/anchor with production input and simulation |
| Advanced movement | PASS 9 cases / 5,909 checks; route and physical/network limits retained |
| Loom persistence | Interact/open, exact assignment, confirmation/save, Escape, movement and paid Water Heavy pass; separate process restores all 12 expected wires |
| Paid Water lifecycle | PASS 32 frames / 888 checks, real paid action and seven lifecycle stages; no direct effect injection |
| Opaque terrain visibility | PASS 31 native cases / 165 assertions / zero failures, including visible positive controls and cover surface oracle |

Read the final-v2 serial orchestration to confirm these journeys target `exports/hex-loom-availability-20260923-v2/windows/hex.pck`. Checked associated receipts and relevant log completions; preserved availability, Water, terrain, basic and advanced journey stderr files are empty. Viewed the exact-PCK Water active-normal frame; material remains within the rendered hex field. Earlier Loom visual findings transfer to the final package through independently established 10/10 exact-pixel comparison.

Verified artifact integrity independently:

- All **260** indexed preserved evidence files match SHA-256.
- All **53** frozen/protected current files match, including prior fallbacks and checkpoint/index boundaries.
- All **7** ZIP entries match both package-audit hashes and loose payload files; PCK and ZIP hashes match the delivery receipt.
- All **20** modal timing rows (10 source plus 10 PCK states, 128 samples each) reproduce recorded p50/p95/p99 from raw samples. PCK p50 spans 1–86 microseconds and p95 2–118 microseconds; these are advisory-helper-only timings.

Verified launch: `exports/hex-loom-availability-20260923-v2/windows/PLAY-HEX.cmd`.

PCK SHA-256: `8102d44fae3d79040bb54e111462e8bf3dbdc5ba1c465ea7f5a9861720014057`.

ZIP SHA-256: `a380edd4dfa51a99293b77fb70042a6bd08ae3c64da6e68cc1b84322c20631d9`.

The failed v1 native fixture and failed v1 export remain preserved and explicitly failed/limited. Good v2 evidence does not retroactively validate either attempt. D6 `exports/hex-render-frame-20260923/windows/PLAY-HEX.cmd` remains the verified fallback. Selected checkpoint and Git index remain unchanged; no installer, publication or promotion is approved by this review.

## Final limits

E1 fixes the inspected misleading final actions and keeps browsing/preview available subject to existing pending-request quarantine. This review does not certify every character, spell/slot combination, window scale, physical controller/keyboard, remote client recovery or human feel. Exact multi-EXE lifecycle and physical two-PC network acceptance are **NOT_RUN** in E1; the prior resource/allocation failure is not cleared. Full includes its existing local suites, not that separate lifecycle. No fresh E1 stress-capacity acceptance was performed, and helper microseconds do not clear previously red rendered deadlines. No D7/D8 experimental geometry or viewport candidate was promoted. Final human visual/input approval remains open.

## Final documentation consistency seal

Read the completed current E1 claims in `README.md`, `docs/HEX-PLAYTEST.md`, `.agent/HEX-RESUME.md`, `.agent/OVERHAUL-IMPLEMENTATION.md` and this milestone's `HANDOFF.md`. **PASS: no material inconsistency requiring a correction.** They identify E1 `p55-c5d0f6accb97`, the successful `hex-loom-availability-20260923-v2` launcher, D6 fallback, Full 160/805129 and source/PCK 78-check/10-frame acceptance consistently with the verified evidence. The detailed handoff distinguishes pinned-engine exact-PCK journeys from the native exported EXE smoke and retains both failed v1 histories.

The updated documents keep historical performance gains separate from E1, explicitly leave dense capacity and multi-EXE/physical networking unaccepted, retain D7/D8 integration deferrals, and do not claim an installer, publication or selected-pointer promotion. The README's preserved generated pointer block is explicitly the unchanged historical selected delivery; its current E1 review-candidate path is separately stated. Player-facing playtest steps are requests for human review, not claims that physical input or every option has been certified. Browsing/preview statements are subject to the existing pending-request quarantine documented in this review; close may still be followed by late confirmation.

This closes the pending documentation review. No new engine or artifact audit was run for this documentation-only seal, and no file other than this review was edited.
