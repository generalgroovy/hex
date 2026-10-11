# H.E.X. canonical-cell hashing slice — September 23

Status: D2 bounded optimization COMPLETE; Windows functional acceptance PASS,
rendered timing FAILED, complete multiplayer acceptance open. Current solo review export is
`exports/hex-hash-20260923/windows/PLAY-HEX.cmd`, **p55-a9837cac9e8c**.
Previous responsive export remains the operational fallback.
This document is evidence for the existing single queue, not a second plan.

Outcome: reduce full-map chemistry state-hash work without changing canonical
bytes, ordering, snapshots, ownership, mutation visibility or any gameplay rule.
Acceptance requires actual production bytes/hash against the frozen old oracle;
malformed/extras/mutation and paid snapshot/replay regressions; fresh focused and
Full gates; final identity and exact Windows package journeys. Capacity and human
acceptance remain separate. No publication, pointer promotion or installer work.

The preceding test-only prototype passed1,134checks,38equivalence cases and three
complete ABBA/BAAB workloads with56samples per implementation. Its baseline is
the actual pre-integration `HexChemistryWorld.state_hash`, not a slower oracle.
Median old/prototype microseconds: empty77,529/58,752; legal29-active/49-stored
80,370/62,854; synthetic all2,766-nonempty141,873/136,908. All samples exceed8,333
and16,667us. p99 is the sample-limited maximum; allocations are unavailable.
The synthetic case is invalid chemistry used only to measure fallback pressure.
Windows/Godot4.7.1 headless, AMD Ryzen3 7320U/8logical processors. The host is
memory-constrained; one mid-run observation is retained beside the prior receipt.

Independent review verified all10source hashes,48block orders/counts, flattened
samples and all summary percentiles. No supported-domain semantic blocker was
found. Unsupported top-level types retain typed iteration but identical error
timing is not claimed. The candidate holds no cross-call references or cache.
Review and prototype evidence: `../hex-responsive-20260923/hash-candidate-review.md`
and `../hex-responsive-20260923/runs/hex-hash-candidate-responsive-v2.json`.
V1 is preserved as FAILED due to a diagnostic parse error and false PASS line;
the wrapper rejected stderr. V2 added type and completeness guards.

`baseline.json` records the dirty/staged boundary and pre-edit source hashes.
`baseline-source/` preserves exact world, identity, oracle and profiler bytes.
The responsive milestone evidence was sealed by curation v3:497files and22frozen/
protected hashes verified. Its package and profiles remain intact. No old receipt
will be represented as verification of the changed runtime.

Root alone runs every engine command and owns registration, identity, evidence,
queue and this handoff. Sol High owns only the state-hash area of
`src/sim/hex/hex_chemistry_world.gd`, the new unit suite and implementation report.
Astra High independently reviews source and evidence, read-only. All workers must
preserve others' edits. Candidate source will freeze before final validation.

Frozen D2 identity: **p55-a9837cac9e8c**,2,800 production records,
runtime SHA256 `a9837cac9e8cb0d6d938a2dfb3fd6df41b9f403ffc78b8c72f62d9b68c4f1554`.
Protocol55 and SessionSnapshot21 are unchanged. Only the chemistry-world hash
section and generated runtime identity changed in production relative to the
responsive package. `freeze.json` also records the regression/profiler sources.

Fresh Focused v1 PASS:8suites/4,707assertions/zero failures or stderr, including
264new direct-production checks across38equivalence cases, paid snapshot
continuation, prediction, reconciliation and replay. Independent review verified
the focused receipt/log hashes and the unchanged pre-hash runtime source prefix.

Integrated profile v1 PASS1,210checks/zero stderr,38equivalence cases and three
complete56-sample workloads. It compares the integrated runtime with the preserved
prototype; the old runtime is not timed again. Actual integrated p50/p95/p99 us:
empty57,927/66,117/88,786; legal62,361/67,552/154,434;
synthetic134,985/141,742/190,635. All samples exceed both budgets. Preserve the
outliers; no cause is established. All11recorded sources and48block sequences
were independently checked. The old-versus-new evidence remains prototype v2.

Unchanged paid snapshot-stage probe PASS332/zero stderr. World and topology
hashes equal the preceding candidate. Five-sample medians: world capture375.373ms,
world prepare258.944ms, chemistry capture104.651ms, chemistry restore246.382ms,
prediction bind77.855ms. Prepare max494ms. These sequential stage observations
are non-additive and insufficient to attribute all changes or certify capacity.

Final Full v1 PASS:159suites/805,014assertions/zero failures or stderr, asset audit,
import and configured120Hz boot;270,496ms. The included `unified-enet` fixture
passes559assertions using eight localhost transports in one engine process.
That fixture does not prove the complete multi-process executable lifecycle or
physical networking. Reviewer verified suite totals and referenced log hashes.

Exact Windows package identity, executed PCK BUILD-STATE and native EXE launch/
safe close PASS. Exact-PCK basic movement passes11,601checks/27cases and advanced
earned movement5,909checks/nine routes. Loom assignment/close/paid cast/save and
separate-process restart PASS. Water PASS32frames/888checks; station fog labels
PASS12frames/27checks; terrain visibility PASS31canaries/165checks. Each retains
the diagnostic's arranged-start/scripted-input limits. No physical-input or full
rendered-motion acceptance is inferred. Root and Astra reviewed actual exported
frames, including normal/reduced Water, cleared expiry and near/far labels.
Water's repeating crests remain a human style decision, not self-approved art.

PCK SHA256 `72a819c26adef5557bb416a96380ad4a4cd3327096d5f2424777e41d9272deb8`.
ZIP `exports/hex-hash-20260923/HEX-p55-a9837cac9e8c-Windows-x64.zip`, SHA256
`e67e92e1ebabc8b68183d741f0d972b220c0e35c8a77b48fd7f4c9422e69aaaa`.
Final ZIP/preservation audit PASS: all archive entries match actual payload bytes,
28source/protected hashes match, the prior responsive PCK/ZIP are unchanged,
and no staged change exists. Curation v1 preserves223referenced receipts/logs/
images. Isolated profiles remain at their run locations; personal profiles were
not used. Existing fallback packages, original assets and selected pointer remain.

Fresh rendered stress completed7,991correctness assertions with zero failures/
stderr and zero draw-authority mutations, but **all1,440frames missed16.667ms**.
Normal/reduced modes retained matched admitted work and authority. These current
source measurements are not a matched before/after rendering comparison.

| Workload / mode | Frame p50 ms | Frame p95 ms | Frame p99 ms | Draw submission p95 ms | Two-tick simulation p95 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Distributed / normal |245.497|331.476|377.237|175.535|98.373|
| Distributed / reduced |241.766|312.498|334.598|169.419|93.115|
| Dense Crucible / reduced |126.320|206.273|273.105|109.859|171.413|
| Dense Crucible / normal |125.330|210.184|257.760|108.949|169.045|

Each row contains360native1280x720frames and720unchanged paid authority ticks.
Frame elapsed, draw submission and two-tick timings overlap and must not be summed.
The presentation fixture's16.667ms deadline does not mean120FPS; authority remains
configured120Hz with an8.333ms tick budget. This gate remains red.

Exact D2 multi-process EXE lifecycle is
NOT_RUN: the prior unchanged300s run ended in system-resource/allocation/JSON
failure; no multi-process retry is used to claim a pass before ownership/cost
diagnosis. Source-level localhost transport regressions above are separate.
Prior responsive stress missed all
1,440frames; its exact-EXE lifecycle failed with OS resource/allocation/JSON errors.
Neither gate passes by optimizing an isolated hash call. Human Water/motion/style,
physical controls, native spectator, two-PC and Internet acceptance remain open.

D3 is now complete as a test-only snapshot lifetime diagnostic. Corrected v2
passes 671 checks across 32 complete repetitions with zero stderr. All 31 actual
superseded-object transitions and the final current objects released at the
asserted weak-reference boundaries. The first iteration has no predecessor.
The source state, snapshot bytes and known 2,766-cell authorities remain exact.
Inclusive capture/prepare/prediction-bind p50 values are 383.143/252.200/94.926 ms;
p95 values are 426.223/299.967/107.451 ms. These are not additive frame timings.
Static memory moves from 67,347,610 to 67,666,026 bytes, with a reported peak of
156,444,897 bytes. Baseline buffers and observation rows remain resident, so the
318,416-byte delta does not establish a leak. This isolated mixed-role process
does not prove actual 60 Hz snapshot cadence, global leak absence, or the cause
of the prior multi-process failure.

V1 failed to parse four instance-ID declarations; the root added explicit int
types and preserved its failed logs. Installed v2 profiler SHA256 is
`62a1af0111f6a64af824f940bf4036eeec315f2d4b83686302a79c28d7c927d1`.
See `snapshot-lifetime-handoff.md`, the sealed independent
`snapshot-lifetime-review.md`, and `runs/hex-snapshot-lifetime-hash-v2.json`.
Curation v2 preserves 228 evidence files and confirms all 28 frozen/protected
hashes and the prior fallback. `d2-sealed-evidence-map.json` retains the original
223-file D2 seal. A fresh source-identity check confirms unchanged production
identity p55-a9837cac9e8c; no new export was needed for this test-only diagnostic.

D4's test-only strict packed decoder passes 1,105 assertions, 87 equivalence
cases and three complete alternating comparisons with 56 samples per
implementation. Legal paid median decode falls from 162 to 88 microseconds;
p95 falls from 237 to 132 microseconds. Empty median is 31 to 19 microseconds.
The synthetic 268,916-byte capped-lane fixture falls from 48,786 to 24,698
microseconds median, but is explicitly non-gameplay pressure. It does not prove
legal chemistry or capacity. Root defers production integration: the legal
74-microsecond saving is negligible beside the separately measured ~252 ms
prepare call, and no complete-prepare benefit was measured. Preserve the
prototype and `wire-decode-v1.out`; see `wire-decode-handoff.md` and independent
`wire-decode-review.md` for source hashes and detailed scope.

D5 is a test-only native component attribution probe. It compares original,
timers-disabled and timers-enabled complete frames; it preserves the inherited
Bootstrap draw body, authority, assets and whole-hex/fog rules. Eight disjoint
CPU call buckets plus residual distinguish draw costs without claiming GPU
attribution or a before/after optimization. V1 failed before measurement on a
typed-array mode-list assignment; failed source/logs and the owned-process
termination record are preserved. Root corrected that declaration for v2.

Fresh D5 v2 passes 2,095 assertions with zero failures/stderr. Four legal frozen
tick-160 views each provide 32 samples. All twelve original/disabled/enabled
RGBA8 images match within their case/mode; authority hashes match after every
measured draw and control arm. Representative actual frames were inspected.
The one-time static backdrop is excluded from the synchronous timers.

| Frozen scene / mode | Hex ground p50 / p95 ms | Complete draw p50 / p95 ms | Presentation elapsed p50 / p95 ms |
| --- | ---: | ---: | ---: |
| Distributed / normal | 24.861 / 28.016 | 36.057 / 39.646 | 70.457 / 84.707 |
| Distributed / reduced | 25.698 / 31.576 | 37.203 / 45.488 | 80.385 / 93.375 |
| Dense Crucible / reduced | 28.773 / 35.203 | 41.280 / 54.019 | 85.708 / 109.920 |
| Dense Crucible / normal | 28.837 / 31.290 | 42.267 / 44.682 | 82.478 / 98.051 |

Per-frame disjoint buckets plus residual equal total draw. Percentiles cannot
be added; presentation elapsed overlaps drawing and scheduling. Timer overhead
is unquantified. These frozen states do not decompose the earlier evolving
720-tick stress p95 or establish any optimization, GPU attribution or capacity
pass. The sampled whole-hex ground path is the largest CPU bucket. Receipt:
`runs/hex-draw-components-hash-v2.json`; frames and referenced logs are retained
alongside it. See `draw-instrumentation-handoff.md` and the independent
`draw-components-review.md` for scope and review.
The independent review is sealed: all 23 source hashes, 128 row-level samples,
44 timing series and 12 PNGs verified. Curation v3 retains 248 evidence files;
all 28 protected/frozen hashes and the responsive fallback still match.

D6 tests one-call material frame preparation against the existing view-plus-
region collection, targeting exact base-world data only. It must retain exact
prepared values, ordering, phase/owner/expiry semantics and whole-hex geometry,
with no cross-frame cache or alternate coverage implementation. Alternating
timings must justify any integration. Production remains frozen throughout
these diagnostics.
Human Water/style/motion approval does not grant permission to change reactions
or multiply named skins.

Launch exact reviewed Windows build:
`C:\Users\sende\Projects\hex\exports\hex-hash-20260923\windows\PLAY-HEX.cmd`.
For current source run `scripts/run.cmd` from this HEX checkout. Older EXEs retain
their older builds. Operational fallback:
`exports/hex-responsive-20260923/windows/PLAY-HEX.cmd`.
