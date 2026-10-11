# Independent D6 render-frame candidate review

Status: **COMPLETE — bounded integration recommended.** No remaining blocker found in the corrected test-only preparation and native A/B source or the completed receipts. Reviewer owns only this document, changes no code, and runs no engine operations. At receipt verification, production remained the frozen D2 runtime. This recommendation requires fresh validation of the integrated production implementation; it does not accept capacity, frame cadence or human experience.

## Preparation contract

The candidate is restricted to the exact base `HexChemistryWorld` script. It builds one function-local scalar zero-view template, duplicates that dictionary for each existing cell, and invokes original `render_regions` once for each nonempty material layer. It reuses the original `_prepare_region` validation, polygon conversion, ownership copies and footprint sorting. No cache survives a call, and geometry, coverage, selection and authority are not changed.

The actual current comparison invokes court.view for every prepared presenter cell, then the production `_collect_render_regions`. The candidate preserves field/dictionary insertion order: the initial fire_phase/steam_heat fields, ordered quantity/present keys, presenter-sorted cells, material dictionaries, and sorted prepared footprint rows. Fire phase follows the last raw region before sorting; Steam heat remains max(1000, all raw intensities). Nonempty raw coverage still sets present=true when its summed quantity is zero. Missing authority cells retain the baseline two-field view. If any original region preparation fails, the candidate completes views and returns empty regions, matching baseline result shape.

The first draft skipped non-Dictionary material layers. Review identified that arrays of valid IDs can be rendered by the original base-world loop despite being invalid snapshot authority. Corrected candidate falls back to current_bundle for present non-Dictionary layers and non-Dictionary cell records, preserving that malformed-but-renderable domain. Missing layers still yield zero views. Subclasses are declined by the candidate; the native seam preserves the original generic/subclass draw path.

## Fixtures and preparation benchmark

Twenty-one equivalence cases cover empty occupied-only/full topology, fractional ticks and phase boundaries, overlapping owners/expiry/zero quantities, Fire ordering, Steam maximum heat, missing/extra layers, direct product mutation/restoration, independent output dictionaries/regions/source IDs, stale membership with missing cells, iterable malformed layers/records, and original `_prepare_region` rejection. A separate exact-script assertion checks subclass decline. Completion counts, bundle structure/Variant bytes and source-authority bytes are checked outside timers.

Review also corrected the initial timing fixture's full-topology selection: normal Wellspring uses `_prepare_court(..., false)` and occupied-only membership. Both legal timed fixtures now use that actual selection, assert presenter cell count equals `occupied_cells().size()`, and record the full 2,766-cell authority topology separately. The full empty-topology case remains equivalence coverage, not the timed normal-Wellspring path.

The preparation benchmark uses one identically prepared presenter for both implementations, equal untimed warmups, and alternating ABBA/BAAB cycles: four cycles x two blocks x five samples = **40 samples per implementation/case**. Timing includes one views+prepared-regions bundle only. Topology/cache setup, source checks, comparison/serialization and receipt work are outside timers. The baseline invokes actual view/collect helpers directly; the separate native experiment is needed to measure complete production draw dispatch and its actual cost.

## Native experiment source review

The test-only native presenter calls actual `super.draw_ground` for baseline. Candidate reproduces the production draw body with only the view/region preparation block replaced; cover filtering and inherited draw helper order match production. It retains exact-script specialization and generic/subclass fallback. Both arms share the same presenter instance and topology caches. No production draw implementation is edited.

The native runner reuses the D5 frozen paid fixtures/configuration, with four warmup draws per arm and four alternating ABBA/BAAB cycles of seven draws/block: **56 measured draws per arm across each of four case/mode views**. Each observation requires one draw, nested ground<=draw timers, unchanged authority and complete baseline RGBA8 bytes. Image readback/byte comparison and state hashes are outside timers. Ground and total draw are nested, not additive; presentation elapsed additionally includes scheduling/completion. Eight saved arm images and source hashes are required for the final evidence review.

Headless and native raw receipt checks passed as recorded below. The scope is frozen tick-160 preparation/native A/B, not evolving rendered stress, networking, physical input, capacity or human acceptance. Measured CPU savings and exact output evidence support the bounded integration recommendation.

## Verified headless preparation receipt

`.godot/hex-render-frame-candidate-hash-v1.json` records **PASS: 976 assertions, zero failures, 21 completed equivalence cases, two completed legal profile cases and zero-byte stderr**. All **11 source hashes** match disk. Independently verified all **32 alternating ABBA/BAAB blocks**, five samples/block, 40 samples per implementation/case, flattened arrays, and every min/max/p50/p95/p99 statistic.

Both fixtures retain the full 2,766-cell topology. Actual timed view membership is **57 cells / 64 prepared regions** distributed and **49 cells / 81 regions** dense. The dense fixture's active occupancy is 29, distinct from 49 occupied presentation cells. Tick-160 paid admissions/matter and eight actors match the intended legal workloads.

| Preparation-only case | Current p50/p95/p99, us | Candidate p50/p95/p99, us | Median saving, us |
| --- | --- | --- | --- |
| Distributed | 14,904 / 17,428 / 17,914 | 5,314 / 6,311 / 7,128 | 9,590 |
| Dense Crucible | 14,092 / 16,525 / 16,973 | 5,623 / 7,079 / 8,076 | 8,469 |

These are isolated preparation savings. The separate native evidence below establishes measured frozen-state ground/draw savings; neither experiment establishes production capacity acceptance.


## Verified native receipt and images

`.godot/hex-render-frame-native-hash-v1.json` records **PASS: 1,968 assertions, zero failures, zero-byte stderr**, four completed case/mode views and 56 samples per arm/view. Independently verified all **25 source hashes against disk**, every one of **448 measured rows** and its cycle/block/sample/arm ordering, ground<=draw for every row, all **24 flattened timing arrays**, and their reported percentiles/maxima. The four-cycle alternating ABBA/BAAB order and seven samples/block match the source. Checks and image readbacks remain outside the measured draw timers.

All eight saved 1280x720 RGBA8 PNGs match the recorded pixel hashes. In each view, production/candidate **decoded pixel bytes and PNG file bytes are identical**. All four candidate views were inspected visually; exact byte equality binds those inspected frames to their baseline counterparts. All 448 sampled frames also passed baseline byte equality and authority-hash checks. These frozen native-script images do not constitute exported-build or human approval.

The paid tick-160 fixtures retain the same actors, occupancy, topology and world hashes as D5. Distributed world hash is `045c3c50504058e00da430f5bcd624ae7e20dae402c3f700e4f3cb4952cb69be`; dense is `6920447054711abf68fce43a66b56814a0b0a9b085e5e6a9b2119a9bf56291ce`. This is a comparison at those frozen states, not decomposition or replacement of the earlier evolving 720-tick stress evidence.

| View | Ground p50 old → candidate, us | Total draw p50 old → candidate, us | Total draw p95 old → candidate, us | Presentation p50 old → candidate, us | Presentation p99/max old → candidate, us |
| --- | --- | --- | --- | --- | --- |
| Distributed normal | 25,269 → 15,270 | 36,573 → 26,914 | 39,447 → 28,773 | 78,269 → 62,358 | 85,285 → 81,603 |
| Distributed reduced | 25,149 → 15,515 | 36,331 → 27,095 | 47,732 → 35,035 | 78,449 → 62,959 | 102,534 → 96,848 |
| Dense normal | 28,913 → 19,124 | 42,642 → 32,653 | 53,776 → 36,819 | 85,796 → 78,328 | 123,495 → 129,651 |
| Dense reduced | 27,970 → 19,272 | 40,758 → 32,444 | 49,622 → 40,032 | 79,230 → 78,994 | 123,373 → 131,011 |

With 56 samples, the reported nearest-rank p99 is the observed maximum. Dense reduced also has worse candidate ground maximum **40,818 versus 36,019 us** and total-draw maximum **66,150 versus 57,246 us**. Those samples are retained. Its presentation median is nearly unchanged, and both dense views have worse presentation maxima. No causal attribution of these tail samples is established. Timer perturbation is unquantified; presentation elapsed includes scheduling/completion and does not isolate GPU cost.

## Recommendation and historical comparator boundary

Integrate only the tested exact-base-world, function-local preparation specialization, retaining original preparation validation/copies/order and generic/subclass fallback. Median total-draw savings of **8,314–9,989 us** across the four frozen views are worthwhile, and byte-identical frames plus authority checks support this bounded change. No cross-frame cache, geometry, coverage, topology or simulation change is supported by this review.

Candidate total-draw medians remain **26,914–32,653 us**, already above a 16,667-us frame deadline, and presentation medians remain **62,358–78,994 us**. This is no 60/120 Hz, GPU, stress-capacity, physical-input, network or human acceptance. Fresh integrated-production equivalence, regression and native/export evidence must identify the new source and retain the prior red capacity result until a relevant new workload passes.

The native comparator is historical after production changes: its baseline dispatches `super.draw_ground`, which would then invoke the new production implementation. Re-running that unchanged script must not be described as another old/new comparison. Preserve the receipt and exact test/source revisions; validate integration against the frozen oracle and separately capture actual integrated production output.

Recorded historical source identities (all matched disk during independent receipt audit):

- Production presenter: `c31e3637085fac57ec1091cf89944c6fd964dacafb1f86afa569290d9eb44393`.
- Production world: `7582964d1c889f1ceaf5114ff6600eb3ead842318e4cf6db95aed1d82985cb7b`.
- Candidate support: `4c2dfc0f78e7980a4b5707a07d7b0e242369d2a884591736dc68b9d6890db949`.
- Native presenter: `5a94292b0085cfa02637070a240a02f8556dbab2c827fd74a4ff29df0f3d01e7`.
- Native runner: `ef3fea01688d85bb39442ba038a8569303a44b400129b8ed1e5de0b0bfef76b8`.

The receipts retain the remaining source identities and all raw samples. Production integration is recommended, not performed or accepted by this review.
