# Chemistry P3 checkpoint — 2026-09-12

Status: preserved verified fallback; Overnight P48 is now selected by the current pointer.
Fresh Full, captures, portable/PCK/raw boot and exact-export localhost passed.
P1 and all prior working builds remain available as fallbacks.

Playable: [flux2.exe](../exports/windows-chemistry-p3-p47-20260912/windows/flux2.exe)
with its adjacent PCK, or extract the complete
[portable ZIP](../exports/windows-chemistry-p3-p47-20260912/release/FLUX2-Windows-x86_64.zip).
PCK SHA-256: `0cd84bcf2874fdfc791abf970a9ab8f7ff697c3aacbf87a45134f88d914f289c`.
ZIP SHA-256: `957856f3c878ca5ff6b6843728ce0bcda5da2de6d03eb5da03b3f079f89d2d28`.

| Newly executed milestone evidence | Result |
|---|---|
| Full | 98 suites /691,064 assertions; zero failures/stderr |
| Native gameplay | 221 fresh frames, byte-identical to P1; actual paid actions and draw-state checks |
| Source freeze | 3,103 scoped inputs unchanged through export |
| Packaging | Exact new EXE/PCK/ZIP, packed source and hidden standalone boot passed |
| Localhost | Exact exported game passed host/join, reconciliation, round, late join, return/rematch and host stewardship |
| Pointer | Exact payload and receipt bytes verified; P3 selected |

[Portable receipt](evidence/windows-chemistry-p3-p47-20260912/checkpoint.json),
[localhost receipt](evidence/p3-chemistry-loop-20260912/same-export-receipt.json),
[source delta](evidence/p3-chemistry-loop-20260912/source-delta.json) and
[capture comparison](evidence/p3-chemistry-loop-20260912/integrated-image-comparison.json)
retain the evidence. Full/Focused receipts are preserved with referenced logs
and reports; failed attempts and earlier known-working builds are retained.

P3 caches five unchanged left-deposit values during the original exhaustive
chemistry pair scan. It preserves all live right-side checks, pair order,
source consumption, recipes, geometry, costs/caps, events and reaction IDs.
Q intent, Rampart, Frostway and Capacitor remain as in the verified P1 build.
No spatial index, gameplay rule, new art or simulation-rate change is added.

Repeated real-map p95 is14.160/14.065ms versus matched P1before15.478/16.346
and restored control15.943/16.243. Synthetic results are mixed: first candidate
15.380/14.699ms, second13.739/13.480, baseline14.232/14.001 and control14.604/
13.627. Every repeat is retained. W4 remains **FAILED** against8.333ms; the final
real-map run still misses408–415 of720 deadlines and reaches61.849ms maximum.

The corrected isolated chemistry fixture improves sparse, fully clustered and
near-clustered medians/p95, with unchanged two-input medians. That mechanism
check is distinct from integrated gameplay performance. Static-memory counters
rise548 bytes, peak counters6,452 bytes; allocation rates and causes are unknown.
See the [complete performance report](evidence/p3-chemistry-loop-20260912/performance-results.md).

Source SHA-256:
`d7e3b5aa669b0f29b97a5588753c0a0be1472c868af2990c7b0b911492701653`.
Main HEAD remains `a1aa02807626823d0fbc1e25e75441ca3b7f4d36`; work is dirty,
uncommitted and unpublished. P1, Q, consolidation, M2b and M2a builds are retained.

Independent review found the fields immutable throughout admission, compared
all335-record world inventories and sixteen repeats, and verified exact state,
ordered event/ID traces, checkpoints, expiry and zero legal gaps. The direct
89-case oracle passes4,125 assertions. Focused4/84,932 and asset-pack20,482 pass.
The milestone freezes3,103 inputs; three scoped files differ from P1, plus the
separately backed-up source-authority snapshot and generated QA report.

P2 was rejected for clustered performance regression and restored completely
before P3 began. Its candidates, defective preliminary micro digests and corrected
control evidence remain in the [P2 decision](evidence/p2-pair-index-20260912/decision.md).
None of those candidates is included in this P3 source. P1's verified portable
remains a fallback. Historical receipts do not substitute for P3 validation.

Short playtest: combine two separate paid casts in the Crucible; compare Charge
Capacitor's warning/lane/discharge with Ice Frostway and Earth Rampart. Repeat
directional airborne Q, neutral Q while coasting, and Float-to-neutral-Q across
three sizes and normal/reduced effects. Gameplay should match P1. Use the same
complete portable on both PCs; physical friend play remains a separate gate.

Human movement/warning feel, physical controller/two-PC play, installer/updater
and sustained rendered120 FPS remain unaccepted. Original art and known-working
builds are preserved. No publication, installer retry or security change occurred.

The next stage-attribution pass completed on this exact P3 source: real-map
chemistry p95 6.295/6.191ms and projectiles7.181/6.281ms; synthetic chemistry
3.791/3.753ms and projectiles7.776/7.799ms. These nested timings are not additive.
All335 source records and state/event/ID traces match the verified candidate.
See [P4 results](evidence/p4-stage-attribution-20260912/results.json).

P5 subsequently refreshed the projectile diagnostic and passed six repeats /
134,158 assertions across real-map mixed, synthetic mixed and Field opening.
The two diagnostic files changed; all production runtime and playable P3 bytes
remain unchanged. Exact real/synthetic traces match P4. Independent source and
raw-evidence review passed. See the [P5 decision and timing table](evidence/p5-projectile-attribution-20260912/decision.md).

The earlier Full/capture/export/localhost receipts above belong to P3's milestone;
P5 adds diagnostic and local snapshot-codec evidence only. It adds no new build,
rendered-performance, physical two-PC or human-acceptance claim. Event overflow
remains explicit and no projectile split was exercised in the new probes.

P6 then split resolution attribution and passed six repeats /134,158 assertions
with exact P5 traces and unchanged3,103-input freeze. Edgeweave accounted for
most measured resolution work. See the [P6 decision](evidence/p6-resolution-attribution-20260912/decision.md).

P7 tested a direct projectile eligibility query to avoid a defensive definition
copy. Source review, Focused3/37,508 and exact workload behavior passed, but a
fixed ABBA confirmation failed the required performance tradeoff. All five
owned files were restored exactly. P6 observation is retained; P3 gameplay,
assets and playable files remain unchanged. No new build was exported. See the
[P7 rejection and preserved results](evidence/p7-projectile-eligibility-20260912/decision.md).

Work is paused at the requested safe playtest point, with P3 selected. The
[single queue](../.agent/OVERHAUL-IMPLEMENTATION.md) next points to current
chemistry-interaction cost investigation using P5's real-map measurements and
prior rejection evidence. W4 remains open; content growth, rendered performance,
physical two-PC/controller play and human acceptance retain their separate gates.
