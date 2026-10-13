# Sustained trail preparation experiment — withdrawn

The current preflight candidate is **withdrawn without a canonical change**. It avoids work on quiet ticks but increases actual-emission costs in both native processes and both invocation orders. Root and both independent reviewers agreed that this tradeoff conflicts with the casting-smoothness priority. No second trail implementation is opened by this result.

Functional correctness passed 12,576 checks; native forward/reverse each passed 23,163 checks, all with empty stderr and unchanged watched sources. One 960-tick finite episode contains 69 paid admissions (59 Rapid and five per Mantle owner), 41,400 matter paid, 38 trails, 612 boundaries with two Mantle owners and an unrelated flight, and 34 late sampled positive boundaries. Every command/state/emission row matches the canonical-checked counted trajectory, strict packets/events/conservation remain equal, and no resources or timers were granted during play.

Each process retains 24 warmup ticks and 936 measured ticks. The table pools the two processes; all raw per-process/order distributions and largest outliers remain in analysis.json.

| Exact pre-emitter stratum | Rows | Emitter mean, before → candidate (µs) | Paired median delta (µs) | Emitter p95, before → candidate (µs) |
|---|---:|---:|---:|---:|
| all | 1872 | 152.863 → 126.676 | -25.0 | 496 → 488 |
| no_sample | 1468 | 84.101 → 45.072 | -28.0 | 153 → 82 |
| sampled | 404 | 402.723 → 423.198 | +12.0 | 1024 → 1063 |
| actual_emission | 76 | 889.592 → 980.184 | +44.0 | 1690 → 1871 |
| late_sampled_emission | 68 | 881.559 → 999.794 | +44.0 | 1651 → 1871 |
| sampled_no_emission | 328 | 289.912 → 294.140 | +10.0 | 504 → 488 |
| owner_cap_predicate | 146 | 303.747 → 310.322 | +7.0 | 504 → 484 |

The 76 actual-emission samples increase from 889.592 to 980.184µs on average, with a +44µs paired median. Their emitter means worsen by +45.053µs in the forward process and +136.132µs in reverse, and by +79.921/+101.263µs in the two invocation-order strata. Late sampled positive rows worsen by +118.235µs on average. Whole-step p95 for actual emissions rises 5,806→7,460µs. These slower positive rows are retained, not trimmed as outliers.

Overall whole-step means are slightly lower, but their order strata reverse sign: candidate-first +88.947µs versus reference-first −194.520µs. This remains a confounded whole-step result, not a broad speedup. The nested emitter clock is part of the whole-step clock and must not be added to it. This is one temporally correlated episode per process, so no confidence interval, human-feel, frame-rate or dominant-bottleneck claim is made.

The 146 sampled owner-cap predicates across both processes are reported separately; they are not proof that the cap was the sole reason no trail emitted. No global-cap row occurred naturally. The original prepared legacy cap, allowance and refusal controls remain separate and unchanged.

The first functional-a stopped before gameplay because two copied legacy controls used CRLF while the exact source guard expected LF. Its source checkpoint, receipt and logs are preserved under functional-failed-1. Only those two ignored copies were normalized, with independent review; the guard, assertions, driver and candidate were unchanged. The fixed source checkpoint README/manifest preserve their original pre-run wording.

This archive includes exact ignored sources, root wrapper, all successful receipts/logs, the failed source/guard evidence, technical independent numeric review and this independent analysis. It does not adopt the candidate or alter production source.
