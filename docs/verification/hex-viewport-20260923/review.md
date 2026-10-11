# Independent D8 viewport submission review

Status: **SEALED DIAGNOSTIC REVIEW â€” final v3 verified; production integration DEFERRED after the final refinement.** Reviewer owns only this document and performs no engine or source edits. D6 production/package remain frozen at p55-1b26a51136d1. Draft findings below are not acceptance.

## Initial candidate and harness inspection

Read the D8 handoff/baseline and prior bounded offscreen audit. Compared all five candidate material loops against current production; after removing only inserted culling/diagnostic lines and comments, their remaining function bodies are exactly equal. Style selection, geometry, marks, draw calls and iteration order are preserved.

The candidate completes court membership and frame preparation, preserves active-material failure checks, and builds the complete cover map before submission filtering. Each helper computes semantic edge counts on its complete region dictionary. Apron, stone and rim remain unchanged. Cover repaint is inherited and unculled; stored cover regions and POV occluders are not filtered. Rectangle propagation is local to the explicit entry and helper calls, with no persistent visibility cache.

The visible rectangle uses the inverse of the exact snapped translation and zoom: `Rect2(-translation / zoom, viewport_size / zoom)`. The Bootstrap harness repeats the actual interpolated-focus/camera-origin computation and uses the viewport's complete size. It does not substitute an unsnapped camera rectangle or infer draw-command transform from a node getter. Candidate timing includes this repeated camera computation; any measured saving must include that overhead rather than silently removing it.

The rejection helper checks finite positive rectangles, finite polygon points, nondegenerate bounds/area and inclusive boundary contact. Invalid/missing/empty/degenerate input fails open. Growth is the source-audited eight world pixels plus one screen pixel in world units. Full native edge/corner/zoom/extreme-mark and cover-repaint comparisons remain required before treating this bound as proven for the exercised fixtures.

## Draft timing finding

Even with `collect_diagnostics=false`, the first draft invokes `_record_retained` or `_record_rejected` for every region; these return immediately for an empty diagnostics dictionary. Requested that the author gate these callbacks before invocation or move counting to an untimed diagnostic pass, so the matched timer contains no per-region diagnostic callbacks. Region serialization/hash setup is already behind `collect_diagnostics`; the profiler must keep it disabled for measured samples.

The profiler was not present during this initial read. Full fixture completeness, alternating orders, authority/source stability, actual native pixels and measured results are **NOT_RUN/unreviewed**. No integration or performance recommendation is made.


## First profiler draft findings (not frozen)

Reviewed the initial 54-pixel-case / 103-analytic-case draft. Four legal matched timing views use frozen paid eight-actor states, typed ABBA/BAAB order, 40 samples/arm, pixel and authority checks outside CPU timers, and pre/post source/identity guards. These are appropriate foundations but the first draft does not yet establish its full coverage claims.

Concrete findings sent to author/root:

- Synthetic fixtures set only `court.current_tick=50`; Bootstrap draws using `world.tick`, initially zero. Products with active_tick=10 therefore need an explicit actual draw-tick fix and phase assertions before active extreme-mark/fortify coverage can be claimed.
- A `draw_cover_surfaces` call count does not prove any active cover region was repainted. Require active-region/selected-cover evidence, plus actual visible positive controls.
- Shifting court origin with forced camera zero can leave material behind opaque POV. Equal frames may then be vacuous. Require material-disabled positive pixel comparisons or a dedicated unobscured synthetic raster canvas, retaining a separate actual Bootstrap POV/cover control.
- Candidate region-hash length alone is not baseline region/cover equality or ownership evidence. Add untimed old/new byte comparisons and an ownership check, or explicitly narrow those claims.
- Normal-campus fixtures use district-base false; the draft has no district-base-true, generic/subclass or malformed-return draw control. These paths require bounded controls before integration coverage is claimed.
- The initial native boundary matrix is Water/normal/100% only. Analytic rectangle tests at other zooms do not establish actual extreme-material and active-cover raster behavior near boundaries. Expand representative native extremes/cover border controls across normal/reduced and supported zooms.
- Timing completeness checks row order/count but does not validate row-to-series identity or summary completeness; add those checks before PASS.

Root separately identified the finite `1e38+1e38` overflow fixture, asymmetric first-frame warmup and loss of partial evidence through `_finish({})`; these remain draft corrections pending re-review. No source or engine changes were made by this reviewer.


## Refinement 1 re-review before first diagnostic

The current draft adds an unobscured native `GroundCanvas`, material-disabled positive controls, active synthetic SimWorld ticks, prepared-region and complete cover-byte comparisons, independent frame ownership, a district-base pixel case, generic/derived/malformed return controls, explicitly gated diagnostic callbacks, expanded source stability and timing row-to-series checks. These address the major initial evidence weaknesses. Native execution remains pending.

Remaining concrete blockers reported to the author/root before a first bounded diagnostic:

1. The derived fallback return control calls district-base drawing on a detached Node2D outside `_draw`; it must use a real draw notification or remain a no-primitive inactive return control.
2. Diagonal boundary `cross` fixtures put only the polygon AABB corner one pixel across both viewport edges. A pointy hex need not intersect that corner at all, so the new positive pixel assertion can fail correctly. Actual polygon/vertex-based corner placement is needed.
3. Failure receipts now retain counters and source identity, but still discard already collected per-case pixel/timing rows. Preserve those partial rows before attempting the diagnostic so a failed positive control remains inspectable.

An initial concern about `_left_crossing_camera` polygon assignment was withdrawn after checking the production API: `whole_cell_polygon` correctly returns PackedVector2Array. These are draft run-readiness findings, not evidence that the candidate itself changes visible pixels. Full integration coverage remains a separate gate.


## Frozen v1 first-attempt readiness

Reviewed only root's targeted fixes after source ownership transfer. The derived return-only control now disables district-base submission and separately prepares full membership to assert the subclass view marker. Corner-crossing fixtures use a deeper actual-polygon crossing, explicitly named `cross-polygon-14px`; straight edges retain their one-pixel crossings. Completed pixel/timing dictionaries now accumulate in run-owned arrays and are included in partial failure receipts.

All **five live/preserved file hashes** in `attempts/v1/freeze.json` match, including candidate, harness, profiler and root supervision/preservation helpers. Frozen profiler SHA256 is `34bb01e383ec326346821991603fc937ee09ffdbae5b86d49db1cfb68118ed01`. Runtime identity remains p55-1b26a51136d1.

**Ready for the first root-owned bounded native diagnostic.** No remaining blocker found in these three targeted fixes. This is run readiness only: actual compilation, positive pixel controls, the complete matrix, source/authority stability and matched timing must still pass. Integration acceptance is explicitly pending; deeper corner crossings are not represented as one-pixel corner coverage.


## Native v1 failure and v2 fixture-only correction

Independently reviewed preserved v1 logs and partial receipt: **FAILED, 1,319 assertions / six failures**, 103 completed analytic cases, 23 completed pixel cases and **zero timing cases**. Every completed baseline/candidate image pair was equal, but both 50% Water positive controls failed; the boundary fixture reported no occupied cell, so the required 55-case completion guard failed. No valid timing or complete pixel-matrix acceptance follows from v1.

The cause is consistent with production membership: `occupied_cells()` reads cast-level `coverage`, while the draft synthetic ingredient helper supplied coverage only inside `ground_parts`. The intended Water/Fire cells were therefore omitted from occupied-only presenter membership. Independently compared v1 with v2: the sole profiler change adds matching cast-level `coverage` and `cells` to `_add_ingredient`. Candidate culling and harness bodies are unchanged. This corrects synthetic fixture membership without changing production or the tested culling algorithm.

Verified the preserved v1 evidence-map artifacts and all five live/preserved v2 freeze hashes. V2 profiler SHA256 is `67ed91ad1e896f73d21adfea9cbcc03a558657be9ee0639ad856bbcbc3cd6e2f`. Production identity remains p55-1b26a51136d1. **V2 execution/result remains pending; no acceptance is inferred from the narrow fix.**


## Verified native v2 result

V2 completed **PASS: 2,970 assertions, zero failures and zero-byte stderr**, with **103 analytic visibility controls, three fallback controls, 55 native pixel controls and four legal timing cases**. Independently verified all 13 recorded source hashes and runtime-manifest hash, both attempts' preserved freeze files, all 18 v1 artifacts and all 22 v2 artifacts. V1 remains a failed pre-timing attempt; its evidence is not folded into the passing v2 totals.

All 55 pixel-case labels are unique. Independently checked each case's exact-pixel result, completed diagnostics, per-material full=retained+rejected counts and total sums. All **nine saved baseline/candidate pairs** are identical in decoded RGBA and PNG file bytes and match their receipt pixel hashes. Visually inspected actual gameplay center, direct magma at the left edge, district-base practice and a deliberately blank equal-margin boundary frame. The direct positive controls prevent the corrected target-material cases from passing solely because both arms hid the material behind POV. The analytic controls and direct-native controls remain distinct: straight native edges cross by one pixel; diagonal native corner crossings are honestly labelled 14 pixels.

The receipt establishes the exercised matrix only. Legal Bootstrap views retain actual POV; synthetic direct-canvas views isolate raster behavior and active-cover repaint. A direct repaint is not proof of every opaque-POV cover scenario, and a boolean positive-control field in legal Bootstrap rows does not represent a separate material-disabled comparison. No human or exhaustive phase/material acceptance follows.

Independently recomputed all **320 ordered timing rows**, cycle/block/sample/arm order, 24 raw series and all p50/p95/p99/max summaries. Every arm/view contains 40 samples; ground remains nested within total draw. All timed observations perform byte equality and authority checks outside the CPU timers. The paid tick-160 timing fixtures retain eight actors and the 2,766-cell topology.

| Legal frozen view | Total draw p50 old ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ candidate, us | Total draw p95 old ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ candidate, us | Total draw p99/max old ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ candidate, us |
| --- | --- | --- | --- |
| Distributed normal | 27,187 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ 22,348 | 34,240 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ 27,071 | 41,489 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ 32,263 |
| Distributed reduced | 27,080 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ 21,892 | 31,999 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ 24,835 | 34,661 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ 31,200 |
| Dense reduced | 32,643 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ 33,419 | 35,539 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ 37,083 | 38,243 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ 37,982 |
| Dense normal | 33,393 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ 34,333 | 37,250 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ 46,701 | 52,315 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ 52,907 |

With 40 samples, p99 is the observed maximum. Distributed draw medians improve by 4,839 and 5,188 us, but dense medians regress by **776 and 940 us**, and dense-normal p95 regresses by **9,451 us**. Dense-reduced presentation maximum also worsens from 89,778 to 95,693 us; dense-normal presentation p95 rises from 94,191 to 105,192 us. All samples remain recorded. This mixed result supports **deferring integration of v2**. Candidate total-draw medians are still above 16,667 us; no frame/capacity/network/GPU acceptance is established.

## One final bounded refinement hypothesis

One further test-only refinement is source-justified: after complete frame validation and cover extraction, compute canonical **per-cell visibility once per call** for the exact base-world path and reuse the result across that cell's material regions. The current v2 predicate scans the same whole-cell polygon for each region. Repeated scans are a plausible overhead source, not a measured causal attribution of the dense regression.

Keep the existing per-region fail-open path for generic/uncertain geometry; preserve full semantic edge counting, prepared dictionaries, cover storage/repaint and retained draw order. The optimization must remain function-local with no persistent visibility cache. Preserve v2 source/evidence and rerun the same complete matrix and balanced timing comparison. This is justification for the final bounded experiment only, not a prediction of improved dense timing or permission to integrate without its result. D6 production/package remains unchanged.


## Final refinement 3 static readiness

Reviewed the candidate-only diff against preserved v2. Exact base-world draws construct a local cell-to-visibility index only after full frame preparation and cover extraction. Production `render_regions` obtains each polygon from `whole_cell_polygon(cell)` (Grid vertices plus origin), and presenter `_vertices` uses that same canonical construction and scale; full region validation has already run. For the intended canonical geometry/revision contract, one visibility decision per cell therefore applies to all its material regions.

Generic/subclass callers leave the index empty and retain the existing per-region fail-open predicate. Missing/invalid canonical vertex values also fail open through that predicate. No prepared region or cover data is edited. Each material's edge counts still see the full dictionary. When all prepared cells are visible and diagnostics are disabled, the helper delegates to the inherited unchanged drawing implementation; this bypasses no validation or cover construction. Diagnostics-enabled controls retain complete per-region accounting. The index and shortcut flag are local variables, not persistent cache state.

Candidate SHA256 at this review: `042d4a57047241eafb14a054de43c6375a45f522e54d0cef35e5ec5da97e328f`. Harness/profiler hashes remain their v2 values. **No narrow static run blocker found; ready to freeze and run the final bounded v3 diagnostic.** Actual output and dense-regression results remain pending. This is neither integration approval nor a further-refinement commitment.


## Final v3 receipt and cross-version verification

Independently verified final v3: **2,970 assertions, zero failures/stderr, 103 analytic controls, three fallback controls, 55 native pixel controls and four matched timing views**. All 13 receipt source hashes, runtime-manifest hash, five live/preserved freeze entries and 22 preserved evidence artifacts match. Receipt SHA256 is `c7dbb004647e093f4f728791feef7ee2ffc96f4e726df7972b06d117cafa72b3`.

Recomputed all **320 timing rows**, balanced ABBA/BAAB order, 24 flattened series and every reported p50/p95/p99/max. All 55 pixel-case dictionaries are **exactly equal to v2**, including authority hashes, prepared/cover hashes, visibility counts, camera parameters and pixel digests. All four legal timing workloads also retain exactly their v2 world hashes, paid accounting, occupancy, actor count, topology and output pixels. Thus the final refinement changes measured work without changing the exercised output/workload.

All nine saved v3 baseline/candidate pairs match in decoded RGBA bytes and PNG file bytes. Inspected the actual v3 reduced gameplay, reduced direct-material edge and district-base images; they match the corresponding previously reviewed output. Still-image inspection remains bounded evidence, not human motion/style approval.

| Final v3 legal view | Total draw p50 old â†’ candidate, us | Total draw p95 old â†’ candidate, us | Total draw p99/max old â†’ candidate, us |
| --- | --- | --- | --- |
| Distributed normal | 25,052 â†’ 19,891 | 29,270 â†’ 22,693 | 32,814 â†’ 27,137 |
| Distributed reduced | 24,740 â†’ 20,597 | 29,884 â†’ 22,944 | 30,697 â†’ 25,847 |
| Dense reduced | 30,072 â†’ 30,703 | 31,868 â†’ 33,405 | 32,078 â†’ 34,647 |
| Dense normal | 30,593 â†’ 31,102 | 33,738 â†’ 34,080 | 36,875 â†’ 36,247 |

Final distributed median savings are **5,161 / 4,143 us**. Dense medians still regress by **631 / 509 us**, with both dense p95 values worse. Dense-reduced presentation p50/p95/max rises from **88,655 / 95,141 / 97,832 us** to **89,077 / 99,184 / 103,790 us**; dense-normal rises from **90,710 / 99,956 / 105,262 us** to **91,748 / 100,260 / 112,659 us**. All 160 candidate presentation samples exceed **16,667 us**. No outlier is removed. Separate v2/v3 sequential baselines are not themselves a matched refinement-to-refinement speedup claim.

**Final recommendation: DEFER D8 production integration and stop refinement of this candidate.** Exact output and a distributed-scene CPU benefit are established for the tested frozen matrix, but the intended dense workload still regresses after the final bounded refinement. Keep all attempts as diagnostic evidence and retain D6 p55-1b26a51136d1 as the unchanged playable source/package. No additional algorithm change, integration, engine run, capacity, GPU, network, physical-input or human acceptance is supported by this review. D6's prior complete-workload timing failure remains unchanged.


## Final documentation review and seal

Reviewed the final D8 HANDOFF, single implementation queue and concise resume. Their current D6 launch path (`exports/hex-render-frame-20260923/windows/PLAY-HEX.cmd`), preserved D2 fallback, unchanged p55-1b26a51136d1 identity and no-promotion boundary agree with the reviewed state. They distinguish failed v1/no timing, passing but mixed v2, final v3/deferred integration, frozen native diagnostics versus evolving stress, and historic D6 acceptance versus the unintegrated test-only prototype.

The published v3 numbers, dense-regression rationale, 160/160 candidate presentation misses and explicit stop after final refinement match the receipt. Human/physical/network/installer gates and D8 Full/export/stress NOT_RUN distinctions remain clear. `refinement-equivalence.json` agrees with the independently established exact 55-case and four-workload equality. No material claim or launch-path misstatement found in these documents.

**Review complete and final: preserve D8 as a measured, unintegrated experiment; keep production integration deferred.** The root may now seal this review alongside the final documentation, orchestration tools, source freezes, receipts and captures. No further edits or implementation are requested for this candidate.
