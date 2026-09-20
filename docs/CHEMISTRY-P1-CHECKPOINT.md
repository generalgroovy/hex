# Chemistry P1 checkpoint — 2026-09-12

Status: local Windows portable verified and selected by the current pointer.
Full, native captures, export, hidden standalone boot and exact-export localhost
all passed. W4 and human acceptance remain open.

P1 rejects already-reserved chemistry cells before an expensive pair visibility
query. This reduces real-map simulation tail time while preserving recipes,
footprints, costs, caps, source consumption, update order, reaction IDs and
events. It retains Q's directional airborne dodge versus neutral vertical
fast fall, Rampart, Frostway and Capacitor. No new gameplay rule or asset is added.

| Newly executed evidence | Result |
|---|---|
| Matched real-map simulation | After-v2 p95 14.709 / 14.299ms; before28.982 / 31.520; restored baseline29.665 / 28.252 |
| Matched synthetic simulation | After-v2 p95 12.598 / 12.973ms; before13.296 / 13.020; mixed earlier/control results retained |
| Correctness | 89-case oracle4,125 assertions; full-workload old-order comparisons42,605 real-map /42,909 synthetic; state, ordered events, IDs and expiry agree |
| Focused / Full | Four relevant suites84,932 assertions; Full98 suites691,064 assertions; zero failures/stderr |
| Native gameplay | 221 fresh frames, byte-identical to Q equivalents; actual paid actions and draw-state checks |
| Source / packaging | 3,103 scoped inputs unchanged through fresh export; exact packed runtime and hidden raw boot passed |
| Localhost / pointer | Exact new portable host/join, reconciliation, round, late join, return/rematch and host stewardship passed; pointer bytes verified |
| Independent review | Production predicate order, differential corpus, metadata/asset hash diff and all20 final timing repeats reviewed |

W4 remains **FAILED** against8.333ms. Real-map p95 improves repeatably, but every
metric does not improve, and synthetic after-v1 repeat2 is noisy at19.852ms.
All repeats, p50/p95/p99/max, deadline misses, source inventories, log hashes,
snapshot and direct integrated timings are retained in the
[performance report](evidence/p1-chemistry-attribution-20260912/performance-results.md).
Static-memory observations increase slightly; transient allocation counts were
not measured. These headless results do not establish sustained rendered120 FPS.

Playable: [flux2.exe](../exports/windows-chemistry-p1-p47-20260912/windows/flux2.exe)
with its adjacent PCK, or extract the complete
[portable ZIP](../exports/windows-chemistry-p1-p47-20260912/release/FLUX2-Windows-x86_64.zip).
PCK SHA-256: `9697b5a56312e8c0b4fd01b0877558803237bc447f40e0cbdb38c5ec277787f8`.
ZIP SHA-256: `1036d0b37783b17ccb1e6a1f69435ec5955b41a72bae4190bf1b678a5758e04b`.
Production chemistry SHA-256:
`8031fe15b2ed1e27c762a1b5857233ba6ad6d98b43bcb4cc9d18e67282ed4c04`.
Main HEAD remains `a1aa02807626823d0fbc1e25e75441ca3b7f4d36`; changes are dirty,
uncommitted and unpublished. The Q, consolidation, M2b and M2a builds remain intact.

[Portable receipt](evidence/windows-chemistry-p1-p47-20260912/checkpoint.json),
[localhost receipt](evidence/p1-chemistry-attribution-20260912/same-export-receipt.json),
[source delta](evidence/p1-chemistry-attribution-20260912/source-delta.json),
[review/rework](evidence/p1-chemistry-attribution-20260912/review-and-rework.md) and
[image comparison](evidence/p1-chemistry-attribution-20260912/integrated-image-comparison.json)
retain exact evidence and limitations. Full and Focused references are copied
together with their logs/reports; failed preliminary diagnostics are preserved.
Q and earlier receipts are historical evidence for those builds, not this source.

Short playtest: in the Crucible, combine two separate paid Charge casts into
Capacitor, cross the lane, observe its warning/discharge/expiry, then compare
Earth+Earth Rampart and Ice+Ice Frostway. Repeat directional and neutral airborne
Q, including Float then neutral Q. Gameplay should behave as in Q; this slice's
expected benefit concerns heavy chemistry simulation cost. Use the same complete
portable on both PCs for friend play and keep that human result separate.

Human movement/warning feel, physical controller and two-PC/internet play,
installer/updater, and sustained rendered120 FPS remain unaccepted. No installer,
security change or publication was attempted. Reduced-height readability and
shared character-template acceptance remain the previously documented open gates.

Subsequent P2 was tested and rejected: the ordered deposit-pair index improved
sparse and sampled real-map cost but regressed clustered states. Exact P1 source
and oracle bytes were restored; no P2 portable was promoted. Its
[decision and failed/passed evidence](evidence/p2-pair-index-20260912/decision.md)
remain available. P1 is still the selected checkpoint.

Next in the [single queue](../.agent/OVERHAUL-IMPLEMENTATION.md): P3 fresh normal
stage attribution on restored P1. If projectiles lead, review and refresh their
diagnostic for current chemistry and real-map geometry before choosing a change.
Map, extra reactions and character asset growth still wait for their performance
and template dependencies.
