# Paid-ground boundary attribution

Both native orders passed **7,188 checks across 22 cases**, with empty stderr.
This is an attribution result; it makes no renderer optimization or FPS claim.
[review.json](review.json) contains the independent recomputation, full per-case
statistics, callback-order strata, cache deltas and paid-state coverage.

The exact executed driver is
`da3ca4ec1ca10770e1cf27de1f4b24edfab34a56a91cabb5f304313a3d830f46` and the
observed presenter is
`af45eadd3a8d0b9353755be01d2d7333f35ad8a913740406907389108d3815cb`.
The preserved production Court is
`3190aa2683205bfdd1ebcc297e1002b3f3e624e4b59a61ecf64b76889733b92c`.
The complete 25-file source set and executed helpers are under `sources/`;
the PowerShell launcher and independent analysis script are under `helpers/`.
Both source sets matched, every source was rechecked, and all 88 PNG hashes
matched their receipts. No failed run was produced by this probe.

| Exact receipt | Checks / cases | SHA-256 |
| --- | --- | --- |
| [Forward](raw/forward.json) | 7,188 / 22 | `ab993b122c5e171bf2c6ab40ce88ca907215ba2577399f02f16fad53cf488769` |
| [Reverse](raw/reverse.json) | 7,188 / 22 | `434c968c50349a7327b8ae1c302d676d0c95ecead04c945e407ecfe8e8cff291` |

Each process measured 12 actual paid snapshot cases, with 32 measured pairs
and four warmup pairs per case. Ten additional pixel controls cover phase,
expiry, re-entry, fractional translation and zoom. The pooled record contains
768 measured pairs, 96 warmup pairs and 20 pixel-control pairs. Normal/reduced
effects, real owner values and material phases remain separate. Presenter
caches persist across cases, so first-use samples are not uniformly cold.

The finite routes used ordinary commands after legal setup: two Fire admissions
including natural expiry and re-entry; twelve Fire admissions; twelve all-six
Mantle attempts (all twelve happened to be admitted); and two Fire owners.
There were no refunds, resource grants or injected phase clocks. Each captured
endpoint passed complete packet restoration, conservation and draw-purity
checks. The two-owner fields are spatially separate; their images do not prove
adjacent-owner boundaries.

| Case | Plain draw mean | Observed draw mean | Bundle | Topology | Outline | Prefix, nested |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Dense Fire, normal | 10.693 ms | 11.208 ms | 3.709 ms | 0.898 ms | 1.517 ms | 0.977 ms |
| Dense Fire, reduced | 9.934 ms | 10.468 ms | 3.578 ms | 0.822 ms | 1.426 ms | 0.908 ms |
| All-six Mantle, normal | 7.394 ms | 7.759 ms | 2.656 ms | 0.533 ms | 1.041 ms | 0.498 ms |
| All-six Mantle, reduced | 7.345 ms | 7.663 ms | 2.675 ms | 0.521 ms | 1.030 ms | 0.483 ms |

Whole draw includes bundle preparation. Bundle, topology and outline are
separate children; prefix runs inside topology/mask work. Mask, point lookup
and submission are inside outline; mesh lookup and actual command submission
are inside submission. These intervals must not be added twice. The additional
clocks and wrappers perturb the observed path: whole-draw mean deltas range
from 47 to 534 microseconds, with substantial order effects. The dense-normal
observed maximum of 22.001 ms and paired +8.922 ms outlier are retained.

Every measured row built zero new meshes and zero new topologies. In the four
large cases above, actual outline command submission was only 35–44
microseconds and mesh lookup was 111–130 microseconds. This does not justify a
new geometry cache. Prefix work is more substantial but includes instrumentation
and shared lookup work; its full duration is not an available speedup.

The next proposed experiment is narrower: shorten only the existing lookup
key for unified materials, retaining current owner serialization and all
meaningful phase/danger/deadline fields. Legacy materials keep the original key.
No prototype or runtime optimization is claimed by this archive. A candidate
would need exact direct-call/mutable-owner equivalence, ordinary paid native
pixels and independent ordered cost measurements before acceptance.

The root reviewer inspected dense Fire, reduced Mantle and the two-owner image;
the experience reviewer inspected normal Mantle, reduced cooling and decaying
Conflagration. The sampled stills show bounded nonblank fields, visible exterior
boundaries and no sampled clipping. All 88 images were hash-checked and every
plain/observed pair passed exact RGBA equality. This is offscreen native Court
submission, not whole Bootstrap, physical-input, animation-feel, human counter
recognition, GPU, presentation-latency or foreground FPS evidence.

The initial archive inventory remains in [archive-manifest.json](archive-manifest.json).
Later review notes and this readable summary are separately bound by
`completion-manifest.json`, preserving the original raw analysis and inventory.
