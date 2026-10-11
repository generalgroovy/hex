# H.E.X. viewport material submission candidate — September 23

Status: D8 TEST-ONLY experiment COMPLETE; production integration DEFERRED after
three refinement passes because dense-scene CPU draw cost still regresses.
Production and the verified
Windows package remain frozen at p55-1b26a51136d1. Launch
`exports/hex-render-frame-20260923/windows/PLAY-HEX.cmd` for current solo review.
The single queue remains `.agent/OVERHAUL-IMPLEMENTATION.md`.

Hypothesis: suppressing only wholly offscreen material drawing after complete
preparation and semantic edge counting can reduce synchronous CPU draw cost
without changing any visible pixel, returned result, cover data or authority.
Source basis: `../hex-render-frame-20260923/offscreen-draw-audit.md`.

Acceptance requires exact full-frame RGBA8 comparison against the actual frozen
presenter, source/identity stability and authority/ownership equality. Cover
repaint, complete edge counts, full validation and all whole-hex regions remain
intact. Rectangle propagation is local to the draw call and uses the inverse of
the exact snapped Bootstrap transform. Conservative inclusive bounds must
retain viewport edges, corners, current material extents, normal/reduced modes
and50/75/100%zoom. Apron, stone and outer rim are unchanged. Synthetic boundary
pixel fixtures are separate from legal eight-actor timing workloads.

Run balanced native before/after measurements only after those comparisons
pass. Keep raw samples, all misses/outliers and representative images. No GPU,
cadence, allocation, capacity, networking or human acceptance follows from a
faster isolated drawing path. At most three refinement passes per candidate.

Root owns baseline/evidence, the single queue, all engine execution and the
integration decision. Sol High authored the test-only candidate/harness/profiler
and relinquished source ownership to root before execution; its exact handoff
and pre-root bytes are preserved. Root completed targeted fixture corrections
and the final candidate refinement. Astra High independently reviews code,
receipts and actual captures. Workers preserve others' changes and run no engine.

`baseline.json` preserves44 protected hashes and seven relevant source originals.
No production, gameplay, interface, artwork, profile, fallback, checkpoint,
publication or installer changes are part of this test-only slice.

Draft static review found the five copied drawing loops preserve production
behavior after removing cull/diagnostic additions. Before the first engine run,
refinement1 addresses test validity: exclude diagnostic callbacks from timing,
use an actually overflowing bound, warm native frames consistently, align
synthetic active ticks, compare complete prepared/cover data on both arms, and
prove that boundary-crossing material pixels are visible rather than hidden by
POV terrain. Public fallback, district-base and strict sample completeness also
needed explicit coverage. Those draft corrections preceded the frozen v1 run;
they do not substitute for the executed results below. See `review.md`,
`implementation-handoff.md` and each attempt's source freeze.

## Executed evidence and decision

V1 compiled and ran but FAILED:1,319 checks/six failures. Its23 completed native
image pairs matched, but missing cast-level synthetic coverage made Water
positive controls and boundary-fixture completeness fail. Timing was NOT_RUN.
Original sources, partial case dictionaries, logs and14 saved images remain in
`attempts/v1/`. V2 adds only matching synthetic cast `coverage`/`cells` fields.

V2 PASS2,970 checks/zero failures/stderr:103 analytic boundary/fail-open controls,
three public fallback controls,55 native full-frame RGBA controls and four legal
paid timing cases with40 samples/arm,320 measured draws. The normal/reduced
distributed median improves4.839/5.188ms; dense reduced/normal worsens0.776/0.940ms.
Dense normal p95 worsens9.451ms. V2 is preserved in `attempts/v2/` and is not the
final live prototype.

V3 is the final refinement: after complete preparation/validation/cover
extraction, exact-base courts compute canonical cell visibility once per call.
Generic/subclass courts retain per-region fail-open checks. If every cell is
visible and diagnostics are disabled, helpers call the original submission
functions. No cross-call cache or authority change is introduced.

V3 PASS2,970 checks/zero failures/stderr on the same matrix/order. Independent
artifact arithmetic is in `audit-v3.json`; `refinement-equivalence.json` verifies
all55 native RGBA hashes, prepared/cover/region data and four paid fixtures match
v2. All nine saved before/after pairs also match both PNG and decoded RGBA bytes.
All160 candidate present samples exceed16.667ms. This is a frozen draw diagnostic,
not the evolving stress gate,120Hz capacity, GPU timing or allocation measurement.

| Legal view | CPU total draw p50, current → candidate | CPU total draw p95, current → candidate |
| --- | ---: | ---: |
| Distributed normal |25.052 →19.891ms|29.270 →22.693ms|
| Distributed reduced |24.740 →20.597ms|29.884 →22.944ms|
| Dense reduced |30.072 →30.703ms|31.868 →33.405ms|
| Dense normal |30.593 →31.102ms|33.738 →34.080ms|

These are matched comparisons within v3; do not compare absolute v2 and v3
timings as another matched speedup. Each arm retains the same tick160 paid
eight-actor workload, topology, admissions, quantities and authority hash.
Presentation elapsed includes render completion and must not be added to draw
or interpreted as a separate nonoverlapping cost. Backend: Windows Godot4.7.1,
Compatibility OpenGL ES3 through ANGLE/D3D11 on AMD Radeon graphics; the receipt
records CPU/platform details and all raw tails/outliers.

**Decision: DEFER production integration.** Distributed draws save4.143–5.161ms,
but dense medians still regress0.509–0.631ms and neither workload meets the frame
deadline. After the third refinement, keep this candidate as evidence of that
tradeoff; do not add a hidden scene threshold or lower work/cadence to claim a
pass. Further rendering work needs a different bounded hypothesis directed at
dense cost. D7's constructor remains separately deferred; see its whole-prepare
brief for the API/maintenance tradeoff.

The live prototype SHA is
`042d4a57047241eafb14a054de43c6375a45f522e54d0cef35e5ec5da97e328f`.
Harness SHA:
`0288de2e09227f855aa58c1ff145861e82cf262362175dd885febead6da38180`.
Profiler SHA:
`67ed91ad1e896f73d21adfea9cbcc03a558657be9ee0639ad856bbcbc3cd6e2f`.
Exact source copies, wrapper logs and referenced captures are together in each
attempt. Runtime stays p55-1b26a51136d1;44 protected hashes and seven original
source copies remain unchanged, including selected pointer and fallback builds.

No new Full gate or export was run for these test-only changes. The unchanged
playable source retains its separately sealed D6 Full160/805098 and exact Windows
journey evidence; old checks are not proof of the new test-only prototype.
D8 evolving stress, exact multi-EXE lifecycle, physical input, two-PC/Internet,
GPU/allocation attribution, installer/updater and human visual/feel acceptance
are NOT_RUN. Prior stress/lifecycle failures remain unresolved.

Launch the verified source with `scripts/run.cmd`, or the exact frozen Windows
candidate with `exports/hex-render-frame-20260923/windows/PLAY-HEX.cmd`.
Operational fallback: `exports/hex-hash-20260923/windows/PLAY-HEX.cmd`.
No new package or checkpoint promotion was needed for this unintegrated experiment.
