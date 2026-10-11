# Contact efficiency and clarity: fresh evidence

Candidate `p56-fa6d17ce9f39`, 2,940 runtime records, source SHA256
`fa6d17ce9f39747de8f636a9437adc3a44540f6e8f105a1f77e4d9c2d184471f`.

| Receipt | Result / scope |
|---|---|
| `baseline.json`, `baseline.log` | Before simulation edits; instrumented 8-caster workload, 120 warmup + 720 measured ticks per order |
| `endpoint-candidate.json`, `.log` | Same instrumented workload after endpoint reuse; identical every-tick authority/event fingerprint |
| `final-profile.json`, `.log` | Final lazy candidate, production court/collision (no timing subclasses); correctness/conservation/order checks passed |
| `focused.log` | Ten relevant suites passed; includes original-helper oracle, whole-cell, height, pressure, interception, optics, paid-pair and UI tests |
| `steam/`, `steam.log` | Seven native frames, real paid Water/Fire Bolts forming Steam and actual movement through it; normal/reduced effects |
| `menus/`, `menus.log` | Sixteen native frames: four building directories, child/parent return, filtered Loom and starter preview/cancel |
| `full-gate.json`, `full-gate/` | PASSED: 171 suites / 1,476,258 assertions, zero failures/stderr; import and 120 Hz boot; referenced logs hash-verified before copying |
| `package.json`, `package/` | PASSED: separate Windows export/PCK source identity, 30 skins admitted, isolated native boot and safe close; installer NOT RUN |

## Measurements and equivalence

| Diagnostic | Normal order | Reversed order |
|---|---:|---:|
| Instrumented baseline median / p95 | 7.384 / 19.631 ms | 7.249 / 20.286 ms |
| Instrumented endpoint candidate median / p95 | 5.970 / 18.176 ms | 6.130 / 18.315 ms |
| Final production-class median / p95 | 5.919 / 18.315 ms | 5.914 / 20.027 ms |
| Final ticks exceeding 8.333 ms | 178 / 720 | 182 / 720 |
| Final maximum | 255.474 ms | 242.068 ms |

The matched instrumented late effects block (ticks 600–719) fell from
497,796 / 531,438 microseconds to 303,873 / 315,060 microseconds: about 39–41%
less time **in that component/block**, not a whole-game speedup. The subsequent
lazy refinement avoids doing the new endpoint work when no relevant field is
active. Final results are a separate uninstrumented-class run; timing noise and
instrumentation differ, so do not turn these into an exact FPS promise.

All measured tick states and ordered events match the baseline fingerprint in
both orders: `8c9b2463acaddc48d4a168e981ddd6983c437e7f5ae10a7ed34da93e2269e452`.
Canonical final authority hash:
`266c16706353a9672925934f063606886f1fa24edf6bc22b2f79046380d32954`.
The native-Variant diagnostic trace includes every authority field and all cell
metadata; it is insertion-order-sensitive, test-only, and sampled outside the
step timer. It is not a replacement for the canonical runtime/network hash.
Final source hashes and identity are included in `final-profile.json`. Baseline
manifest identity predates the two independent UI edits; no simulation source
had been changed when that baseline was run.

Paid-workload metrics are unchanged: 66 admitted casts, 107 refusals, 39,600 paid
matter, 37,200 consumed, 1,200 expired, 28 reactions, 4 modifiers, 5,496 exposure
queries; peaks of 19 flights, 20 casts and 23 products. Eight actors use actual
paid production spells, with no refills or raised caps. This is not an extreme
capacity, render/GPU, snapshot, network, physical input or long-soak test.

**120 Hz timing remains FAILED.** The rare expensive ticks remain a priority;
this slice removes repeat work without hiding the remaining bottleneck.

## Visual review and retained limits

All 23 durable PNGs match the hashes in their original capture receipts. The
larger outlined Steam vents are clearer at actual 75% zoom in normal/reduced
effects; the tested crossing retains a readable actor and clean exit. The Loom
subtitle no longer collides with its library heading; four-spell filtering,
twelve-card starter confirmation/cancel and selected parent return are visible.

Steam is still a dense repeated tile motif; unfamiliar-player interpretation,
color-vision differences and dense overlapping fields remain human review items.
Loom attack-family headings are close to the filter row but not overlapping.
Stills do not prove temporal animation quality or all-character readability.

`interrupted-expensive-trace.log` is an intentionally stopped diagnostic, not a
pass: full JSON hashing on every tick was too expensive as a test observer.
Its first order completed, but the two-order receipt did not. The replacement
native encoding completed both orders without altering production behavior.
Original assets, prior packages, dirty changes and historical evidence remain.

## Portable identity

Portable: `exports/hex-contact-clarity-20260928/HEX-p56-fa6d17ce9f39-Windows-x64.zip`
(106,649,985 bytes). Use its `PLAY-HEX.cmd`; keep EXE and PCK together.

| Artifact | SHA256 |
|---|---|
| ZIP | `44bcdbdc1786598585dfd157358dc7f4f078599cf316d95479521cd753f4a12c` |
| PCK | `6a2e0db56c9361c530bfb369f3a29aa9c5c576dc331b8987cbe4525cc792d0f9` |

Receipt paths retain their original run locations for provenance. Durable full
gate copies are under `full-gate/`; native export logs are under `package/`.
No installer/update promotion, human acceptance, rendered performance, physical
two-PC test, commit or push occurred in this slice.
