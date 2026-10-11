# Independent P0 review

Date: 2026-09-21. Read-only review of the current shared-checkout diff in Bootstrap, CharacterWeavePolicy and their three affected unit suites. This report is the only write by this reviewer; no Godot/import/test/capture/profile/export was run.

## Updated gate disposition

**Approved for the bounded ordinary-Loom source repair. Both P1 findings below are resolved in the rechecked source. This is not full milestone or package acceptance.** The original findings remain below as review history.

- Explicit `bool` fixes the parser issue. Legacy equip now checks `ChampionAttunementScript.is_available(state)` before policy application; the acknowledgement suite adds a Bootstrap-handler active-cast refusal regression.
- Independently read `.godot/hex-probe-p0-focused-fast/probe.log`: five suites, 225 + 21 + 100 + 57 + 4,951 = **5,354 assertions**, zero failures; its stderr is zero bytes. This is a direct focused engine receipt, not Full.
- Independently read `source-journey-v2/journey.json` and matching log: actual Interact opening, assignment confirmation with actor 1 / transport ID 0, Escape close, movement and paid wire 181 casting succeed; 18,000 fixed Flux spent. Save is recorded. `restart.json` and the separate restart process log confirm all twelve wires restored. Both stderr files are empty. Starting position is arranged by the harness; this does not establish unaided navigation or physical controller acceptance. The prior float-JSON comparison failure remains retained.
- `_save_confirmed_weave` now exposes a failed save through station notice, fixing the ordinary whole-weave completion route after panel closure. **Residual P2:** legacy REQUEST_SPELL_EQUIP calls it before its own unconditional editor/station success messages; that branch can still overwrite the unsaved notice. Keep this scoped limitation explicit or move the legacy save call after its success messages in a later validated correction. It does not block the ordinary Loom repair.
- Baseline EXE `baseline-modal/game.log` records requested safe quit, local flush and network close. The baseline screenshot and earlier failed ordinary receipt remain retained. No fresh candidate package acceptance is inferred from the old EXE.
- `full-v1.json` currently records FAILED. Broad regression, any subsequent Full, actual candidate EXE/PCK/ZIP, wider spell/slot/drag/controller coverage and multiplayer remain separate lead-owned gates. No ready-for-friends or completed milestone claim is approved here.

## Original findings and their rationale

1. **P1: legacy equip can remove an in-flight paid cast.** `SessionRequestPolicy.validate` applies ChampionAttunement availability to REQUEST_WEAVE_APPLY, but REQUEST_SPELL_EQUIP still has only station-distance admission. Its new Bootstrap path calls CharacterWeavePolicy, whose cooldown check cannot protect a pending non-legacy spell before release starts its cooldown. Removing that wire during startup leaves `CombatSystem._release_cast` unable to store its cooldown, so it aborts the release after Flux was already spent during admission. Require the same active-action availability for the legacy path and regress a request through the Bootstrap handler while a non-legacy cast is pending. The general removed-cooldown guard is otherwise sound and atomic. Reported to lead.

2. **P1: candidate parser gate currently failed.** Retained `p0-focused-v1.json` records FAILED, 7,383 stderr bytes. The root error in its suite stderr is `bootstrap.gd:718`: unable to infer `close_requested` from the event-dependent expression. Cascading inherited-harness errors do not count as passed acknowledgement coverage. Declare the local variable bool and rerun the focused gate. Reported to lead; this report does not claim the failure is still present after subsequent edits.

3. **P2: closed-panel persistence failure needs visible feedback.** The fix correctly permits panel closure while authority remains pending. If a later confirmation completes and the save fails, `_save_confirmed_weave` updates only the hidden editor status; the visible station notice still says the twelve positions applied. Propagate the session-only/unsaved result to the visible station notice, including legacy saves, so players know restart will not preserve that change. Do not undo accepted authority to fix the message.

## Findings already satisfactory in the reviewed design

- Ordinary offline actor 1 can now match its own pending request despite transport local ID 0. The baseline native receipt `loom-baseline-v3.json` independently shows Interact opened the Loom, assignment changed authoritative wires, confirmation stayed pending and Escape failed with precisely that identity pair.
- Pending identity includes actor, champion, monotonically assigned request sequence and mode/local-ID/world-epoch/peer context. Unmatched acknowledgements do not manufacture success. Completion checks actual local authority and the same context before saving.
- Per-frame wall-clock completion removes reliance on successful simulation ticks. Exact acknowledged matching authority takes priority over the UI deadline. Timeout clears UI tracking without reverting the world or claiming authority rejection.
- Escape/controller Back/close-button processing while pending closes the view without cancelling the authority transaction. Closing a starter preview before `close_editor` avoids that method's existing preview-only cancellation branch.
- Cooldown removal validates before mutation; retained/swap spells keep their timers, while absent legacy aliases retain independent timer storage. The new policy regression covers removal, unchanged state on refusal, swap and ordinary expiry.
- Legacy slot/library decoding rejects out-of-range request values before indexing. No concrete malformed-index acceptance bug was found. Keep network type/packet validation and whole-weave expected-state compare unchanged.
- Failed persistence regression preserves accepted session authority, restores prior saved-library memory and checks character switching remains usable. It is a controlled failure test, not proof of a successful actual disk save/restart journey.

## Required evidence after corrections

Lead rerun: focused suites with zero stderr, followed by the ordinary native source journey against the fixed identity. Include actual assignment, filtered wire mapping, drag/drop/swap, safe close, movement/cast, isolated save and process restart. Keep the old native failure and red unit receipts. The pending recovery suite still manually invokes completion; native source coverage must exercise the actual `_process` path. Test late acknowledgement after close and absent acknowledgement through real elapsed wall time, plus malformed/active legacy request refusal.

The preserved baseline cooldown receipt `cooldown-red-v2.json` records four failures in 21 assertions with zero stderr. Its wrapper failure label is generic; the assertion failures are the causal regression evidence. The subsequent candidate receipt is not accepted until its parser failure is resolved and rerun.

No approval of package, multiplayer, broader availability or milestone completion follows from this source review. Same-export lifecycle, frozen Full, actual EXE/PCK/ZIP identity, and every enabled player action retain their own gates.
