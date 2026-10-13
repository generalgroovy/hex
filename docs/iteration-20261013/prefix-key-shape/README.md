# Prefix-key shape experiment — withdrawn

**Do not apply this prototype.** The exact output checks passed, but the intended
draw-cost improvement did not repeat across processes. The current production
key remains unchanged, and no production patch is proposed.

Both native processes passed **9,077 checks / 22 cases**, including **2,334
direct prefix checks**, with empty stderr. All **88 PNG hashes** were verified;
every plain/candidate pair is identical. The 27 watched source hashes match both
runs and the archived exact bytes. Complete authority, paid sequences, phase/
owner coverage, retained-cache counters and callback order also matched.

| Exact raw receipt | SHA-256 |
| --- | --- |
| [Forward](raw/forward.json) | `a2c5fa2417c02a024e01de8614b1fb5bbe6c91ecf5136dda867d13f1fc68f1d3` |
| [Reverse](raw/reverse.json) | `44db42f62b24f75872deabfd2ec08086a6c59f42817f17e9adafc7d2162d1966` |

The candidate changes only one key-construction block: ordinary unified fields
use four meaningful fields, cinderveil uses five including its current decay
deadline, and legacy retains eight. All actual prefix strings, owner type and
fresh generic-owner serialization, readonly keys, the shared 512-key cap and
cache lifetime remain unchanged. The direct checks exercise interleaved keys,
nested same-object owner mutation, dictionary order, meaningful and irrelevant
field changes, cold misses, warm hits and saturation. Those declared direct
regions are separate from the ordinary paid native trajectories.

The cost pair uses pristine whole-draw timers on the current presenter versus
the inherited candidate. It contains no nested attribution clocks. There are
768 measured pairs, 96 warmup pairs and 20 pixel-only pairs across the two
processes. All measured pairs built **zero new meshes and topologies**. Timed
warmups each built 95 meshes and seven topologies per process, identically in
both arms. First samples are therefore not uniformly cold; persistent caches
and actual build counters remain in the raw record.

Values below are whole `draw_ground_in_view` CPU microseconds. Negative deltas
favor the candidate. Each pooled case has 64 measured pairs, equally split
between processes and actual call orders.

| Case | Plain / candidate pooled mean | Paired mean / median delta | Forward / reverse mean delta | Plain-first / candidate-first mean delta |
| --- | ---: | ---: | ---: | ---: |
| Mantle normal | 7,763.359 / 7,619.859 | −143.500 / −109 | −338.469 / +51.469 | −115.562 / −171.438 |
| Mantle reduced | 7,842.578 / 7,828.719 | −13.859 / +63.5 | −170.094 / +142.375 | +96.438 / −124.156 |
| Dense legacy Fire normal | 10,382.094 / 10,636.172 | +254.078 / +203.5 | +4.063 / +504.094 | +403.906 / +104.250 |

Mantle's target improvement reverses in the second process, including a +120 µs
paired median for reduced Mantle there. Dense legacy Fire's negative control
worsens in both pooled order strata. Its +7,989 µs paired outlier is retained;
so are the target's favorable outliers, including normal Mantle's −5,223 µs.
The result is not explained by rebuilding measured geometry, nor does pixel
correctness establish a useful cost benefit. Do not select the favorable first
process or pooled normal-Mantle mean as an optimization claim.

[review.json](review.json) contains the experience recomputation with every case,
process/order stratum, warmup, quantile and retained-cache delta. Independent
[technical](independent-technical-review.json) and
[gameplay](independent-gameplay-review.json) reviews agree on withdrawal.
The sources, original proposal manifest/README, parser output, wrapper, native
logs, raw receipts and all images are preserved here. The proposal README under
`prepared/` is historical and intentionally retains its original unexecuted
wording. `archive-manifest.json` binds the completed archive.

This is offscreen native CPU submission on finite paid snapshots, not whole
Bootstrap, human counter readability, animation feel, GPU/presentation latency,
foreground frame pacing or FPS qualification. No failed native run occurred;
the experiment is rejected because its measured benefit is not repeatable.
