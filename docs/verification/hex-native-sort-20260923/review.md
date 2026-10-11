# D9 independent native cell-key sorting review

Status: **SEALED: BOUNDED D9 INTEGRATION AND EXACT LOCAL WINDOWS FUNCTIONAL ACCEPTANCE PASS; DOCUMENTATION CONSISTENT; RENDERED TIMING FAIL AND BROADER ACCEPTANCE OPEN.** Candidate evidence below is historical pre-integration evidence. Native ordering is now authored in production; the last verified playable fallback remains E2. Reviewer ran no engine and edited only this report.

## Proof and bounded domain

The current `_stable_hash_cells` comparator orders keys by `str(key)` lexically. For exact Vector2i keys that textual representation uniquely identifies the two integer coordinates. Sorting the preformatted String array natively therefore orders the same keys; the inverse lookup recovers the original typed coordinate. Numeric/geometric ordering is not the contract. The collision guard delegates to the original implementation rather than selecting a tie order. Non-Vector2i keys also delegate to `super` before the original typed iteration; this does not broaden unsupported acceptance. Non-Dictionary records and non-String record-key behavior retain the same typed boundaries. Unsupported-key fallback is a source-derived argument, not a passing dynamic rejection fixture.

The body after ordering retains the production empty-record specialization, metadata type conditions, generic compact-record conversion and nested `_stable` behavior. Nested mixed formatted-key ties still take the current generic implementation. No across-call cache is introduced: strings, inverse lookup, empty template and results are function-local. Exact integer formatting avoids locale/natural-sort reinterpretation.

The candidate factory copies exactly the six scalar fields and cells plus seven collections consumed by `_state_hash_bytes`. Recursive Dictionary/Array duplication provides independent mutable ownership within the supported data domain; it is not a promise to clone arbitrary Object/Resource instances in malformed extras. The timed subclass inherits the actual public state_hash/byte pipeline, overriding only cell projection. The production arm calls current `HexChemistryWorld.state_hash`; frozen original bytes/hash are an outside-timer independent oracle, not the measured baseline.

## Draft blockers and test scope

Reported the incompatible `_measure_block` override: parent takes four parameters, draft child five. Rename the child helper/call before engine execution. Root independently caught this and worker is correcting it. Also requested that failures after completed profiling preserve partial raw cases rather than `_finish({})` discarding them.

Inherited 38 equivalence scenarios cover malformed/missing scalar metadata, nested extras, insertion order, empty/nonempty transitions and mutations. Four additions cover single-cell, lexically tricky signed/multi-digit positions, reversed insertion and 4,096 cells. The three timed fixtures additionally prove bytes on 2,766-cell empty/legal-paid/synthetic authority. The draft independent-copy test checks nested mutable ownership and direct mutation; root has requested same-candidate key add/remove/restore coverage before freeze.

Warmup is symmetric; 4 cycles with 4 alternating ABBA/BAAB blocks and 7 unbatched calls per block produce 56 samples per arm per case. Checks/hashes and copying are outside the measured public-hash call. Success guards check exact ordered block identities, positive counts, flattened arrays, all three named cases and before/after source+runtime identity stability. Synthetic all-nonempty data is correctly labeled invalid chemistry. No whole-frame, snapshot-prepare, network or capacity inference is justified.

Final static readiness awaits the worker's corrected frozen handoff. No performance or production-integration recommendation is made before a valid fresh receipt.

## Corrected pre-run seal

Rechecked the released corrections: `_measure_native_block` avoids the incompatible inherited signature; explicit typing/local integer-division annotation addresses the identified warning risks. Same candidate now undergoes cell add, remove/restore and insertion reorder checks against the oracle/current bytes, supplementing independent-copy mutation tests. Partial receipts retain completed case data on ordinary assertion failure. `receipt_path_valid` gates `_finish` writes, so an invalid/out-of-scope/existing output target is not overwritten after preflight failure.

No remaining static blocker found for one root-owned frozen probe. Expected successful completion is 42 byte/hash equivalence cases, one ownership/mutation case and three whole-public-hash workloads with 56 samples per arm each. Unsupported-shape fallback and arbitrary-object copying limits remain as stated above. Compile, runtime equivalence and measured benefit remain unproven until the fresh run receipt/logs are independently inspected; this is not approval for production integration.

## Fresh v1 receipt audit

Independently inspected `runs/v1/hex-native-sort-candidate-v1.json`, probe log/empty stderr, freeze and audit: **1,261 assertions / zero failures; 42 equivalence cases / one ownership case / three profile cases**. All 13 recorded measured-source hashes, 14 frozen current/preserved files, six indexed run artifacts and 62 baseline protected hashes match. Runtime identity remains E2 `p55-aeefbd4a5e7b`, including unchanged manifest hash. No production edit or package change occurred during this run.

Recomputed every ordered block and statistic: **48 ABBA/BAAB blocks, 336 positive raw samples**, 56 per arm per workload. Each seven-sample block has the required cycle/block/arm identity; flattening reproduces all six aggregate arrays exactly. Block and aggregate min/max/p50/p95/p99 and 8,333/16,667us miss counts agree. Root's audit is consistent with these independent calculations.

| Whole public hash workload | Current p50/p95/p99 (us) | Native candidate p50/p95/p99 (us) | Median reduction |
| --- | --- | --- | --- |
| Production empty, 2,766 cells | 63,908 / 96,931 / 139,437 | 47,642 / 60,870 / 71,150 | 16,266us / 25.45% |
| Legal paid, 29 active cells | 68,323 / 85,814 / 169,150 | 52,151 / 63,681 / 74,319 | 16,172us / 23.67% |
| Synthetic all-nonempty | 139,778 / 146,048 / 155,352 | 126,077 / 132,289 / 152,909 | 13,701us / 9.80% |

The legal fixture retains eight paid admissions, 4,800 paid matter and conservation; its receipt distinguishes **29 active cells from 49 nonempty material records**, with source/product quantities 2,400 each. Synthetic pressure populates all 2,766 records without legal chemistry and is not a capacity workload. Every one of the 336 measured calls exceeds both 8.333ms and 16.667ms thresholds. Outliers remain in the statistics; 56-sample p99 is the maximum. This is a single bounded, sequential-case, headless whole-hash experiment, not an independent-run confidence estimate or rendered/network measurement.

## Integration recommendation and remaining gates

**Recommend a bounded integration of native Vector2i key ordering.** The approximately 16ms legal public-hash median reduction is substantial at the measured operation boundary, unlike prior tiny isolated decoder savings. All three measured workloads improve median/p95/p99, and exact bytes/hash plus ownership/mutation checks pass. No candidate blocker remains; this recommendation does not mean the system meets its frame or simulation budget.

Keep **one production record-projection body**. Factor the key-order operation or build a local sorted key array from the native String order, then run the existing body unchanged. Keep the exact current comparator fallback for unsupported keys or formatted-key collisions, without broader acceptance or cross-call caching. Any extra key-array reconstruction is absent from this measured candidate and must be included in a fresh measurement of the actual integrated public hash; do not substitute the prototype figure for integrated cost.

Freeze/preserve this source and receipt as historical old/new evidence before runtime integration. Once production changes, this profiler's `production_current` arm no longer represents the old code and cannot establish another old/new comparison. Fresh actual-production byte/hash/oracle/mutation validation, appropriate regression suites and newly identified Full/export acceptance are required before offering an integrated package. Current E2 remains the verified playable fallback. No frame, snapshot-prepare, network, allocation, cadence, capacity or human acceptance is inferred.


## Integrated source static review

Compared the current source directly with `integration-baseline-source`, rather than the older Git HEAD. Production SHA-256 at this review is `6a62134d2498ef6205ab798944fe9f00ee34ea342d7d4a07bd5d9f5c48140130`; production-suite SHA-256 is `9ce7785feba8764a37a0d915cbfdd4c44508b947c2d5e8bf63121957e44e962d`. **No static blocker found for the root-owned validation run.**

Exact comparison confirms that all source preceding `_stable_hash_cells`, the single record-projection body starting at `var result: Array = []`, and the entire following source suffix are unchanged. Only cell-key ordering changes. Exact Vector2i keys are formatted once, sorted with native String ordering and reconstructed into the local original-key array. Non-Vector2i keys or formatting collisions restart from `cells.keys()` and execute the exact preserved comparator. Typed iteration and record boundaries are unchanged. All scratch state remains call-local; clearing/repopulating the independently returned keys array does not mutate the authority Dictionary. No second production projection body, hash cache or persistence/schema change is introduced. Unsupported fallback remains source-reviewed rather than dynamically demonstrated.

The production suite retains all 38 prior cases and adds seven direct-production cases: one cell, signed/multi-digit lexical coordinates, reversed insertion, same-world addition, removal, second insertion reorder, and 4,096-cell topology. The 45-case completion guard fails if a fixture skips. Each case compares exact production bytes and public hash with the frozen original oracle and checks unchanged authority; additional assertions prove mutation visibility and restoration on the same world. The new cases call actual production methods, not the test-only subclass.

`profile_hex_native_sort_integrated.gd` inherits the already reviewed workload, timers, balanced blocks, raw samples and completeness guards; its virtual source collector/completeness guard require 14 hashes including itself. Its final receipt explicitly distinguishes the integrated public hash (including key-array reconstruction) from the preserved native-sort prototype. This run can validate integrated cost and equivalence but cannot supply another pre-change/new-production speedup: the historical v1 candidate receipt remains that comparison. Fresh Focused, integrated profiling, snapshot-stage, Full and exact-package results are pending. No integrated timing or delivered-package claim is made from this static pass.


## Fresh integrated Focused and diagnostic receipt audit

Fresh generated identity is **p55-dd2ab169dcfa**, canonical runtime SHA-256 `dd2ab169dcfa6c1290ba7fce6eab1841c92628c90d9dd93a036ae325b32308d5` (2,800 records, protocol 55, snapshot 21). Independently matched the seven integration-freeze entries both to current files and preserved copies, parsed identity and manifest hash, all 14 measured integration source hashes and all eight snapshot-stage source hashes. The stage receipt itself has no build-identity field; its exact source hashes and the integration freeze associate it with this runtime. No broader package audit was repeated while root's serial validation runs.

Focused-v1 passed **eight suites / 4,759 assertions / zero failures and stderr**, including the actual production specialization suite's 316 checks and 45-case completeness guard, canonical sorting, snapshot optimization/roundtrip, prediction/reconciliation and replay. Receipt counts sum correctly and the referenced suite log hash matches.

Integrated profile passed **1,261 assertions / 42 equivalence cases / one ownership case / three workloads**, zero failures/stderr. Recomputed all **48 ordered ABBA/BAAB blocks and 336 positive raw samples**, their six flattened 56-sample arrays, every block/aggregate statistic and both deadline-miss counts. Results agree with `integrated-audit.json`. Actual production includes the additional key-array reconstruction:

| Actual integrated whole public hash | p50 (us) | p95 (us) | p99/max (us) |
| --- | ---: | ---: | ---: |
| Empty 2,766-cell campus | 44,914 | 47,955 | 50,192 |
| Legal paid / 29 active cells | 49,300 | 53,291 | 56,919 |
| Synthetic all-nonempty | 124,782 | 128,205 | 132,447 |

This is integrated-versus-prototype current-cost evidence. It is **not another old/new measurement**, and figures from separate runs must not be subtracted into a fresh speedup claim. Every integrated and prototype sample still exceeds both 8,333us and 16,667us; the preserved prototype's synthetic 259,535us maximum remains in the receipt. Historical candidate v1 is the matched old/new evidence.

The unchanged snapshot-stage profiler passed **332 checks / zero failures and stderr**. Independently recomputed all eight five-sample stage statistics (40 raw observations). The legal workload's chemistry authority hash, occupancy and tick match the integrated hash workload: 2,766 cells, tick 160, eight actors/admissions, 4,800 paid matter, 29 active cells, source/product quantities 2,400 each. Fresh inclusive p50 stage costs are world hash 52,233us; topology hash 8,791us; chemistry capture 92,016us; world capture 355,528us; blank world 85,671us; chemistry restore 240,422us; world prepare 253,908us; prediction bind 79,244us. The world/chemistry wire sizes remain 7,908/3,216 bytes.

Stage correctness covers exact authority reconstruction, unchanged source authority, malformed snapshot rejection and unchanged rejected targets. Timers retain the existing allocation boundaries; destination creation is outside restore/bind timers where the named stage does not own it. These are sequential inclusive stages with five samples, so p95/p99 are the maximum and stages cannot be summed as disjoint costs. No matched prior-stage comparison, leak/lifetime proof, full-prepare improvement, socket/network or capacity claim follows.

No blocker found in these fresh gates. **Full, evolving rendered stress and exact Windows package/journeys remain pending independent review.** E2 remains the previously verified playable fallback until that evidence arrives.


## Fresh Full regression receipt

Independently checked `full-v1.json`: **160 suites / 805,217 assertions / zero failures and stderr**, completed in 236,144ms. Summed every suite count and checked every suite reports zero failures. Matched all three referenced import/120Hz-boot/suite log SHA-256 values and the referenced current-state and asset-inventory receipt hashes. The logs confirm import completion, a 120Hz initialized boot, and the final all-suites PASS. Current-state, asset inventory, doctor, import and deterministic suite gates ran.

This Full receipt explicitly reports `package_and_installer: false`; it is not the forthcoming exported-build gate. Stress and package/journey review remain pending the combined final artifact map. No engine was run by this reviewer.


## Fresh evolving rendered stress

Independently checked `.godot/unified-wellspring-render-profile-native-sort-v1.json` and its log/empty stderr: **7,991 correctness assertions / zero failures**, four runs with 360 measured presentation frames and 720 real authority ticks each. All seven measured source hashes match current frozen production and diagnostics. Each case's normal/reduced runs match all 26 non-timing/non-monitor fields, including authority/event trace hashes, sample-end/final hashes, paid admission/refusal accounting, inventory/work totals, cleanup and alive-actor counters. Zero draw-authority mutations were observed at the seven audited checkpoints per run; this is sampled nonmutation checking, not per-frame hashing.

**The rendered timing gate fails: all 1,440 measured presentation frames exceed 16,667us.** Present p50/p95/p99 in milliseconds are:

| Legal evolving workload / mode | p50 | p95 | p99 |
| --- | ---: | ---: | ---: |
| Sustained distributed / normal | 207.389 | 283.614 | 339.325 |
| Sustained distributed / reduced | 209.896 | 294.338 | 537.011 |
| Dense crucible / reduced | 116.704 | 190.572 | 271.116 |
| Dense crucible / normal | 116.577 | 188.231 | 196.265 |

Checked sample counts, monotonic quantiles and consistency with the log. This unchanged profiler records quantiles rather than raw frame arrays, so independent raw percentile recomputation is unavailable for this receipt. The reduced distributed maximum is retained at 660.658ms. Present timing spans scheduling/render completion; CPU draw submission and two-tick simulation have separate timers, with observer hashing/accounting excluded. There is no matched old/new rendered experiment here, GPU attribution, cadence/capacity success or human visual acceptance. Production hash correctness and isolated hash improvements do not resolve this timing failure. Exact Windows package/journey/capture review remains pending.


## Final exact Windows and curated evidence review

**Recommend accepting this bounded integration as the current local solo test candidate. No functional or artifact-integrity blocker remains.** Independently SHA-256 verified all **209 curated artifacts**, all **76 protected/frozen file rows**, package PCK/ZIP, and every one of the **seven ZIP entries against both its recorded hash and the extracted file**. Existing fallback packages, selected checkpoint and index remain protected. The package receipt identifies `p55-dd2ab169dcfa` / runtime SHA `dd2ab169dcfa6c1290ba7fce6eab1841c92628c90d9dd93a036ae325b32308d5`; the exact EXE log confirms this identity, native startup and safe close. Post-export registry check passes 151 canonical/cache entries with zero violations. All final journey/export stderr files are empty.

Current launch: `exports/hex-native-sort-20260923/windows/PLAY-HEX.cmd`. PCK SHA-256 `43a1fd491519deeb54607c7447feb33e8d1491f660e9ca6e61d9767d25c1cc90`; ZIP SHA-256 `78abba7040660e052160c3787e6e74b0997843f473b5f80dd9e410897f8bd903`. E2 `exports/hex-gallery-availability-20260923/windows/PLAY-HEX.cmd` remains the preserved prior fallback.

The preserved serial orchestration targets this exact PCK for the diagnostics; those pinned-engine/PCK journeys are distinct from the actual EXE native smoke. Inspected receipts and all listed check booleans: Gallery **77 checks / nine frames**; character switching/custom-weave return **19 checks**; basic movement/casting **27 cases / 11,601 checks**; advanced movement **nine cases / 5,909 checks**; Water **32 frames / 888 checks**; terrain **31 captures / 165 assertions**, zero failures. Loom opens through Interact, applies the intended 12-wire list, clears pending, saves, closes, permits movement and paid Water Heavy (18,000 raw = 18 Flux); a separate process restores the exact 12 wires. This restart is not a multiplayer lifecycle test.

Independently decoded and compared **all nine exact-PCK Gallery frames against preserved E2 fixed-south-facing frames: 9/9 RGBA and PNG hashes identical**. This qualified pose-controlled regression does not replace E2's preserved original 1/9 uncontrolled comparison. Visually inspected actual D9 ACTIVE and confirmed Gallery frames: the contextual reason and disabled attunement fit, browsing/detail/facing/Close controls remain visible, and confirmation shows the equipped identity and matching status. Also inspected actual normal/reduced active Water, reduced expired Water and a terrain cover-surface frame: bounded full-cell material is visible while active and absent at expiry; these static observations support regression review, not motion/art approval.

The receipt's arranged start positions and state fixtures, physical-input omissions, full identity/direction matrices, live network transitions, paid-cover formation/removal and spectator/information-filtering gaps remain explicit. **Full multi-EXE lifecycle is NOT_RUN for D9**; prior resource/allocation failure under unchanged 300-second configuration is unresolved. Physical two-PC/Internet, controller/human motion/style approval, installer and release capacity are not established. No publication or selected-checkpoint promotion occurred. All 1,440 rendered deadline misses remain a failed performance gate despite functional acceptance and the earlier isolated matched hash improvement.

Final README/player-help/queue/resume/HANDOFF consistency review awaits root's completed documentation signal. Reviewer ran no engine and changed only this report.


## Final documentation consistency seal

Read the completed current claims in `README.md`, `SPECIFICATION.md`, `docs/HEX-PLAYTEST.md`, `.agent/OVERHAUL-IMPLEMENTATION.md`, `.agent/HEX-RESUME.md` and this milestone's `HANDOFF.md`. **No material documentation blocker found.** Current identity/launch, E2 fallback, Full 160/805,217, 209 curated final artifacts plus separately sealed prototype evidence, 76 protected/frozen hashes, controlled Gallery 9/9 equality and exact package digests agree with inspected evidence. The native-sort contract retains a single projection and unsupported fallback. Historical prototype gains and fresh integrated current costs remain distinct.

The handoff correctly labels all 1,440 stress deadline misses, seven sampled draw checks per run, quantiles without raw frame percentile recomputation, inclusive/non-additive stage costs, and no matched rendered gain. Its frame/draw/two-tick p95 table matches the fresh receipt. Current player guidance asks for human review rather than declaring it passed. Full multi-EXE lifecycle is explicitly NOT_RUN, prior resource failure unresolved, broader controls/network/Water/style acceptance open, and no installer/publication/selected-pointer promotion claimed.

The current queue and resume explicitly supersede historical no-cutoff wording with the user's 1%-remaining cutoff and require live usage rechecking. Their latest-known 3%-remaining figure is parent-reported; the reviewer did not query account usage. Historical specification wording is dated and does not override that current instruction. Final recommendation remains bounded local solo acceptance only; performance/capacity acceptance fails. This seals the owned review without source edits or engine execution.
