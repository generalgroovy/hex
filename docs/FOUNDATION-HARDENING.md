# Existing-system foundation hardening

Status: verified foundation and allocation follow-on; heavy-load120Hz acceptance open.

## Runtime follow-on, 2026-09-08

The active build is now protocol46; see [delivery/practice checkpoint](DELIVERY-PRACTICE-CHECKPOINT.md).
The chronology below describes the previous protocol45 foundation unchanged.
A stage sampler isolated repeated recipe-dictionary allocation in projectile /
reaction containment. Reading the already-validated immutable recipe shape
directly removes that allocation without changing collision geometry or results.

| Repeat | Legal-eight baseline p95 / p99 | Direct shape lookup p95 / p99 |
|---|---|---|
| 1 |18.095 /18.420 ms|11.329 /11.557 ms|
| 2 |17.821 /18.456 ms|11.401 /11.742 ms|

These are headless development simulation ticks using the original legal-eight
Burst workload, not rendered FPS or the new mixed-spell acceptance. All checkpoint
and final hashes, events and network counts matched before/after. Differential
geometry:124,640 assertions; focused chemistry:62,743 assertions. Logs live in
`.godot/runtime-20260908/`. The p95 reduction is approximately36%;166/720 ticks
still exceed8.333ms in the measured post-change run. Performance remains open.
The mixed Heavy/Rapid/Wave profile is now measured in the delivery checkpoint:
p95 19.753 /20.398 ms, with projectile advancement dominant at16.904 /17.575 ms.
Authoritative snapshots remain complete, but peak transient-event overflow is40.
Next: isolate projectile/reaction query costs and prioritize essential transient
cues within the packet bound, comparing equivalence before changing authority.

## Original verified foundation

Status: verified local source checkpoint, 2026-09-07; performance acceptance open.
Authority: Godot source on `main`, protocol45 / snapshot18 / preferences11.
This page supersedes older active-next-step prose without rewriting its evidence.

Later presentation-only follow-on: `PIXEL-ASSET-INTEGRATION.md#visual-readability-2026-09-07`
records Float time feedback, concealment windows, reduced tails, Full85/282089 and
actual rendered captures. This page's earlier counts remain historical evidence;
its measured performance limitation is not resolved by the visual pass.

## Small completed implementation slices

| Slice | Corrected behavior | Contract and regression proof |
|---|---|---|
| Control priority | Mud or a slowing Field cannot cancel an active Launched, Grappled, Charging, Stunned or Rooted timer, forced movement or casting restriction. | No deferred slow queue; fresh contacts work after expiry. Existing slow-to-slow scaling unchanged. All8 directions x5 controls, real Earth/Water Mud after Tideline, real Field contact.163 failures reproduced before the guard;59059 focused assertions pass afterward. |
| Spawn animation continuity | A fresh or replenished authoritative spawn-protection timer resets render history, including an already-alive nearby or same-position airborne character. | No visual travel from the old spawn and no residual Float height. Normal timer countdown resumes interpolation. Real spawn reset,3 bodies x8 directions;120 failures reproduced before the fix;26090 focused presentation assertions pass afterward. |
| Compatibility | Protocol45 separates the control-priority behavior from protocol44 peers. | No wire/snapshot/preference additions. Real ENet mismatch rejection must leave the host roster unchanged. |

No movement speed, jump/Float timing, invulnerability, Stamina/Flux cost, spell
catalog, hit geometry or pixel source asset was retuned. Rendering remains a
consumer of authoritative state. Original reference/art drafts remain preserved.

## Verification ledger

| Gate | Evidence / status |
|---|---|
| Focused mechanics | `.godot/runtime-audit/movement-slow-priority-green-20260908.log`:59059 assertions,0 failures/warnings. |
| Focused animation | `.godot/diagnostics/artwork-spawn-motion-after.log`:26090 assertions,0 failures/warnings. |
| Integrated Full +120Hz source boot |85 suites /280218 assertions,0 failures/warnings/stderr,54.2s; `.godot/receipts/foundation-hardening-20260907.json`. Current-state/asset audits pass. |
| Local Farflow host/join |Pass at120Hz on UDP24937: reconciliation, shared HELLO, round transition, late join, rematch and host stewardship; `.godot/farflow-smoke/`. Protocol44 peer refusal is covered by Full's real ENet suite. |
| Baseline legal eight-player probe | `.godot/foundation-solid-20260907/baseline-runtime.log`:8247 assertions, deterministic repeat hashes, zero danger/network gaps and rejected snapshots. Timing does not meet120Hz acceptance. |
| Human animation/feel | Open: the regression proves presentation continuity, not artistic acceptance. |
| Installer/publication | Not rebuilt, committed or pushed in this pass; old protocol44 export is historical evidence, not this build. |

The first integrated attempt rejected the new compatibility fixture's17-character
name before its handshake (the existing limit is15). The fixture was shortened
and Full rerun successfully; validation was not relaxed. A separate pre-existing
UX inconsistency remains: name errors advertise24 characters despite the15 limit.
Fix those strings from the shared constant in a later focused usability slice.

## Performance: measured limit, not a performance claim

The baseline probe uses ordinary paid spells from8 actors, peaks at40 live
projectiles, and includes resulting matter/reaction processing. It samples720
ticks twice. Snapshot serialization and checkpoint hashing are outside its
`SimWorld.step` timer. This is headless development-runtime evidence on this
machine, not rendered FPS, a controlled machine benchmark or a release benchmark.

| Baseline run | Simulation median | p95 | p99 | Ticks exceeding8.333ms |
|---|---:|---:|---:|---:|
| Forward command order |3.480ms|17.476ms|19.359ms|177/720|
| Reversed command order |3.712ms|18.054ms|18.679ms|174/720|

Determinism/network correctness passed; the timing envelope did not. The current
probe does not count peak deposits/reactions or attribute stage time. Candidate
hotspots are exhaustive deposit-pair tests and sampled projectile/reaction
geometry with repeated recipe lookups; Edgeweave also copies projectile metadata
before rejecting ineligible targets. These are source-derived hypotheses, not
measured attribution. Do not claim that40 projectiles are the whole workload.

## Next safe slices

| Order | Bounded task | Acceptance before proceeding |
|---|---|---|
|1|Measure projectile advancement, terminal matter and chemistry stage time; include deposit/reaction counts, normal and admitted-limit loads.|Opt-in diagnostics with no canonical-state changes; repeat hashes and equivalent workload; report dev and release scope separately.|
|2|Optimize only the largest measured allocation/query hotspot; retain existing caps and deterministic ordering.|Same gameplay hashes, no omitted dangers, improved p95/p99 under the same workload; Full and real session gate.|
|3|Review real motion on the map: spawn/reset, walk/slide/jump/Float/dodge and landings for all bodies/directions.|No size/facing pops or opacity errors, accurate paid protection feedback, user acceptance; preserve reusable atlases.|
|4|Revalidate chemistry readability and bounded multiplayer load before content expansion.|All36 existing effects remain active/tested; no new statuses, draft artwork promotion or120FPS guarantee without proof.|

## Test the current source

Run `flux.cmd play` from this repository. Both players must use the same source
revision/protocol45; the old installer/export is not automatically updated.

| Check | Expected observation |
|---|---|
|Wellspring movement|The existing walk, slide, low jump, paid Float, air dodge and wall chains retain their current tuning.|
|Nearby round/spawn reset while elevated|Character immediately appears grounded at the new spawn; no gliding from the previous air position.|
|Tideline through active Mud|Knockback and its casting restriction complete their authored timer; persistent Mud may slow on a fresh contact afterward.|
|Older multiplayer build|Clear incompatible-build refusal; no extra roster slot consumed.|

Continue only while at least75% weekly allowance can remain after tests and
documentation. Leave one green, documented slice rather than partially applying
the next optimization. Do not publish an installer or remote branch implicitly.
