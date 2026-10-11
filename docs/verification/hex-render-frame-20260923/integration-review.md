# Independent integrated render-frame review

Status: **SEALED — D6 bounded integration complete; correctness, exact-package and preservation review PASSED; rendered timing FAILED and broader acceptance OPEN.** Reviewer changes only this document and performs no engine operations. The sealed D6 prototype review remains historical, not a substitute for validation of integrated production.

## Source and semantic review

Compared `src/presentation/hex_court_presenter.gd` with this milestone's preserved baseline presenter and the frozen D6 candidate. The integration adds the exact-world script preload, replaces only the `draw_ground` view/region construction with `_prepare_frame_bundle`, and adds `_prepare_frame_bundle` plus `_current_frame_bundle`. The rest of the draw body, cover filtering, draw order and helpers are unchanged. Baseline collector, region validation, court membership and selected draw-helper function bodies were also compared exactly.

The specialized path retains the reviewed candidate behavior: a function-local scalar zero-view template; independent view dictionaries; one original `render_regions` call per nonempty layer; original prepared-region validation/copies and footprint ordering; zero-quantity presence; last raw Fire phase; Steam maximum with floor 1000; missing-cell two-field view; complete views with empty regions on failed preparation. No cross-frame cache or geometry/coverage/simulation change is introduced. Direct authority mutations are read anew.

Exact base-script identity restricts specialization. Generic courts, subclasses, material-list mismatch and renderable non-Dictionary cell/layer records return through `_current_frame_bundle`, preserving the old dynamic view dispatch and collector path. The helper relies on `draw_ground`'s existing nonnull/court-method/finite-tick checks and prepared membership; this is consistent with its private call site. The production cast to the base world occurs only after the exact-script guard.

## Production unit coverage

`tests/unit/test_hex_render_frame.gd` calls the actual production `_prepare_frame_bundle`. Its old-path oracle is the preserved candidate's `current_bundle`, not its candidate implementation. That oracle still calls current `_collect_render_regions`; exact comparison establishes that collector and `_prepare_region` remain unchanged from the milestone baseline. The test therefore remains an old-path comparison for this bounded change.

Sixteen completion-counted cases cover phase/fractional tick boundaries, overlapping Fire parts and zero quantity, Steam heat, direct authority mutation/restoration, independent output dictionaries/nested regions/source IDs, renderable malformed cell/layer fallback, region-validation rejection, subclass override preservation, generic duck-typed court and empty occupied membership. Structure and Variant bytes check insertion/order equivalence; authority serialization checks read-only behavior. The derived court's marker field distinguishes its overridden view from base-world specialization. No static parse or semantic blocker was found; fresh focused execution subsequently passed as recorded below.

Static-review source identities:

- Integrated presenter SHA256: `57926b68365d872a71224a52d6560ae9a0c0119f8533cb5a99ee60291da5621a`.
- New production unit suite SHA256: `ff096a9ddc474d855585a253418c05eb09899fbaea8f016f5e82d95c4a8a3457`.
- Frozen test oracle SHA256: `4c2dfc0f78e7980a4b5707a07d7b0e242369d2a884591736dc68b9d6890db949`.

## Evidence boundary

The historical D6 native A/B baseline used `super.draw_ground`; after integration it resolves to the new production implementation. Re-running that script is not a fresh old/new speedup measurement. Integrated focused/full results, actual production native captures, evolving stress and exact Windows artifact acceptance must carry the new source identity and their own receipts. Prior capacity failures and pending physical/human/network gates remain unresolved until relevant new evidence passes.


## Fresh integrated focused evidence

`focused-v2.json` records **PASS: seven requested suites, 2,074 assertions, zero failures and zero-byte stderr**, including the new production render-frame suite's **84 assertions / 16 completion-counted cases**. Independently checked the assertion sum, suite log hash and generated current-state report hash. The log and report identify actual integrated runtime **p55-1b26a51136d1**, SHA256 `1b26a51136d12142fe8c745e334d57af3f73a8ea4244d3ea2ac4bbb004f650b5`, 2,800 production records, candidate generated/not promoted. This is fresh integrated evidence, not the historical prototype run.

`focused-v1.json` and `preflight-attempts.json` retain two failed workflow attempts: the first focused preflight rejected the stale runtime identity and executed **zero suites**; generation without `-Force` refused replacement and preserved the manifest. Neither is counted as a passed test run. Full regression, production native pixel comparison, evolving stress and exact Windows artifact evidence remain pending.


## Full v1 registry failure and narrow test-source correction

`full-v1.json` records **FAILED** after successful import: the canonical class-registry guard rejected test-only globals `HexRenderFrameCandidate` and `HexWireDecodeCandidate`. It ran **zero suites / zero assertions**, with zero-byte stderr. This is not a runtime regression-test pass. The registry guard correctly remains enforced.

Independent search of `src` and `tests` found both global names only in their declarations; callers use script preloads. Removing only those unused `class_name` declarations is a suitable narrow fix with no production behavior change. The original prototype files and original freeze must remain preserved, and the modified test-source hashes must be recorded separately. Applied-delta verification and Full v2 subsequently passed, as recorded below.


## Verified registry repair, final freeze and Full v2

Independently compared the two installed helpers with the preserved originals under `baseline-source/tests/support`: each change is **exactly deletion of its first `class_name` line**, with all remaining bytes identical. The before/after hashes in `test-registry-repair.json` match both copies. The frozen oracle now has SHA256 `751390e94fc0a13a11bcab52bf2ceafb67ace5da1396953c1873ffc7175940a7`; its executable body remains the reviewed old-path oracle. The wire helper now has SHA256 `a068d5386ca90ef21cf9589b2e1263ee0e9d84ad9f2f36feff319d80fc5ee880`.

All **13 file hashes in the amended freeze.json** match disk. Its runtime identity equals the preserved `freeze-before-registry-repair.json` identity: **p55-1b26a51136d1**. Production presenter and new production unit-suite hashes remain those recorded above. The registry policy was not weakened.

`full-v2.json` records **PASS: 160 suites, 805,098 assertions, zero failures, zero-byte stderr, 242,542 ms**. Independently verified suite count/assertion sum, every suite's zero-failure result, all three log hashes, and the current-state/asset-inventory report hashes. The fresh gate includes current-state check, asset inventory, doctor, import, deterministic suites and 120-Hz boot. Packaging is explicitly not part of that receipt. This passing Full supersedes the registry failure for final regression status while preserving Full v1 as a failed attempt. Native/stress/artifact evidence remains pending.


## Fresh integrated native output

`.godot/hex-draw-components-render-frame-v1.json` records **2,095 assertions, zero failures and zero-byte stderr**. Independently checked all **23 source hashes**, 128 indexed observation rows, call counts against the preserved D5 fixture, eight component sums plus residual equaling each total draw, and all **44 raw arrays and percentile/max summaries**. The four tick-160 fixtures retain exactly the earlier world hashes, paid accounting, actors, occupancy and topology.

Independently verified the old/new receipt hashes and all **12 images** recorded by `integrated-pixel-equivalence.json`. Every fresh integrated-production PNG is identical to its preserved D5 counterpart in **decoded RGBA bytes and PNG file bytes**. Original/disabled/enabled controls agree within each view. The fresh dense-normal-enabled frame was visually inspected; the image comparison binds it and the other saved views to the previously reviewed baseline. This is actual integrated production output, rather than the historical candidate's copied draw body.

| Fresh integrated view | Total draw p50, us | p95, us | p99/max, us |
| --- | --- | --- | --- |
| Distributed normal | 25,366 | 28,615 | 28,985 |
| Distributed reduced | 25,241 | 32,142 | 32,818 |
| Dense reduced | 32,196 | 41,341 | 41,840 |
| Dense normal | 33,275 | 49,396 | 57,800 |

These are fresh frozen-state observations. Sequential comparison to D5 is **not a new matched speedup measurement**; the sealed D6 alternating candidate experiment remains the measured old/new gain evidence. All these total-draw medians still exceed 16,667 us. Instrumentation perturbation remains unquantified, and frozen CPU draw observations do not establish evolving stress, GPU, cadence, capacity or human acceptance. Evolving stress and exact artifact acceptance remain pending.


## Fresh evolving stress: correctness passed, timing failed

Verified `.godot/unified-wellspring-render-profile-render-frame-v1.json`: **7,991 correctness assertions, zero failures, 1,440 presented frames and zero draw-authority mutations**. All seven source hashes match. Independently checked both receipt hashes and all **25 workload fields across four runs** in `stress-workload-equivalence.json`, including exact traces, final/sample hashes, admission/refusal/event/accounting counters, occupancy, cleanup and draw checks. Workload and cadence match the prior D2 stress; sequential timing observations are not another matched A/B gain.

**All 1,440 frames exceeded 16,667 us. Capacity remains failed.** Fresh presentation timing:

| Evolving run | Present p50, us | p95, us | p99, us | Maximum, us | Misses |
| --- | --- | --- | --- | --- | --- |
| Distributed normal | 211,695 | 301,223 | 401,104 | 496,761 | 360/360 |
| Distributed reduced | 209,740 | 290,993 | 401,674 | 526,562 | 360/360 |
| Dense reduced | 131,039 | 202,998 | 238,072 | 303,520 | 360/360 |
| Dense normal | 126,031 | 187,711 | 235,284 | 273,307 | 360/360 |

Present elapsed includes scheduling and render completion. These observations establish neither GPU attribution nor acceptable cadence. Frozen preparation/draw savings remain a bounded local improvement within a still-failing complete workload.

## Exact Windows package and scripted journeys

The fresh package receipt identifies **p55-1b26a51136d1**, source SHA256 `1b26a51136d12142fe8c745e334d57af3f73a8ea4244d3ea2ac4bbb004f650b5`, native export launch/source-identity/safe-close smoke, installer **NOT_RUN**, and checkpoint **not promoted**. Independently hashed the actual artifacts:

- PCK: `affbbb58a4b490cdd2b465709bbe45a1225bf9652ae0d19cd717ea6ccec29211`.
- ZIP: `60c7668db7233c76dfd7349d473957aea712742a486a76e530f6f02bee2bfd85`.

Read the fresh PCK journey/capture receipts and logs. Basic movement/cast reports **27 cases / 11,601 passed checks**; advanced movement reports **nine cases / 5,909 passed checks**. The Loom journey opens via interaction, applies all twelve positions, saves, closes with Escape, moves and performs a paid cast; a separate-process restart restores the expected weave. These are scripted application-input checks with arranged starting positions, not physical-control or full navigation proof.

Water capture passes **32 frames / 888 checks**, station-label capture **27 assertions / 12 gameplay frames**, and opaque-terrain capture **31 cases / 165 assertions**. Their runtime identities match the exact integrated package. Independently verified all 32 Water image hashes and 93 terrain capture hashes. Visually inspected representative exact-PCK active reduced Water, expired normal Water, nearby live station title and distant normal station scene. Active Water retains whole-hex fills/motifs; expiry removes the effect; the reviewed title/distant views preserve their intended presentation. This bounded still review does not substitute for human aesthetic or motion acceptance.

The package and scripted outputs supply fresh integration evidence. The exact-EXE network lifecycle remains **NOT_RUN** for this milestone; prior resource-related failure, physical keyboard/controller, two-PC/Internet, human visual/audio and release capacity gates remain unresolved. The final curated evidence-map/protected-file/archive audit subsequently passed, as recorded below.


## Final archive, fallback and documentation audit

Independently rehashed all **262 evidence-map entries**, verifying both the original source artifact and its preserved copy against each recorded digest. Independently rehashed all **40 frozen/protected files** in `preservation-audit.json`, including the Git index, selected checkpoint, current frozen sources, original assets and preserved fallback artifacts. All match. The prior `p55-a9837cac9e8c` package remains the operational fallback; no selected-checkpoint promotion occurred.

Reopened the final Windows ZIP, verified CRC integrity and its exact **seven-entry** set, and compared every entry's bytes/hash with both `package-audit.json` and the exported Windows payload. PCK and ZIP hashes again match the package receipt. This establishes artifact integrity and packaging correspondence; the separately reviewed runtime launch and PCK journeys establish their bounded behavior evidence.

Reviewed the current README, specification amendment, player help, active queue, resume pointers and milestone handoff for material claims. Their current build, launch/fallback paths, passed functional results, failed rendered deadlines, historical prototype boundary, deferred test-only D7 and unimplemented/unmeasured D8 descriptions agree with the reviewed evidence. No material documentation misstatement found.

**Final recommendation: accept D6 as the completed bounded material-frame-preparation integration and retain the exact exported package for local solo review.** This is not checkpoint promotion or release/capacity acceptance. All 1,440 stress deadlines failed; exact multi-EXE lifecycle, physical input, native spectators, two-PC/Internet, installer/updater and human visual/motion/audio acceptance remain unaccepted or NOT_RUN as explicitly recorded. D7 remains a separate test-only candidate with production integration deferred. No engine operation, source/test modification, commit, publication or deployment was performed by this reviewer.
