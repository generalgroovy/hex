# D9 native cell-key sorting checkpoint

Status: bounded integration COMPLETE; fresh Windows functional gates PASS,
rendered timing FAILED, broader network and human acceptance OPEN.
Current local review runtime: **p55-dd2ab169dcfa**, protocol55 / SessionSnapshot21.
Launch `exports/hex-native-sort-20260923/windows/PLAY-HEX.cmd` or run
`scripts/run.cmd` from `C:\Users\sende\Projects\hex` for current source.
Operational fallback: `exports/hex-gallery-availability-20260923/windows/PLAY-HEX.cmd`
(E2 **p55-aeefbd4a5e7b**). Its historical receipts remain separate.

Outcome: reduce the complete chemistry state-hash cost while retaining
the exact canonical ordering, bytes, hash, public mutation visibility and
independent mutable ownership. Native lexical String sorting removes script
comparator calls for exact Vector2i keys; unsupported keys retain the old path.
The existing bulk duplication of empty cells is already implemented and is not
a new optimization. D7 and D8 remain deferred separately.

Acceptance: compare actual current public state_hash against the test-only
subclass candidate, including exact bytes against the independent frozen oracle;
negative/reordered/lexicographic positions, empty/small/2766/4096-cell fixtures,
malformed metadata, nested extras, direct mutations and ownership. Measure three
whole-hash workloads using 56 samples per arm and balanced ABBA/BAAB order.
Synthetic all-nonempty pressure is not legal chemistry. Report p50/p95/p99 and
deadline misses without claiming frame, network or capacity acceptance.

Root ran all imports, tests, captures, profiling and exports. Sol owned the two
prototype files, then the production ordering block and existing specialization
suite; ownership returned before each freeze. Astra independently reviewed source
and evidence. The first frozen prototype and first frozen integration passed;
pre-run diagnostic signature/path-guard corrections are recorded in `review.md`.

`baseline.json` rechecks 62 protected hashes, records dirty main and no staged
changes, and preserves five source/document originals. Evidence `.gdignore` was
created before script copies. Selected pointer, user profiles, original assets
and all fallback packages are preserved. A previously visible user game process
exited independently before this slice; it was never stopped by the agent.

Latest measured usage: 97% used / 3% remaining. User cutoff is **1% remaining**;
prepare a safe handoff before reaching it. Never redeem credits or buy usage.

Fresh prototype v1 PASS:1261assertions/zero failures/stderr,42equivalence cases,
one ownership case and three56-sample-per-arm comparisons. Independent review
verified13source hashes,14frozen files,62protected hashes,48balanced blocks and
all336samples/statistics. Legal authority has29active cells and49nonempty records.

| Whole public hash | Previous median ms | Prototype median ms | Reduction |
| --- | ---: | ---: | ---: |
| Empty campus |63.908|47.642|25.45%|
| Legal paid workload |68.323|52.151|23.67%|
| Synthetic all-nonempty |139.778|126.077|9.80%|

All measured calls miss8.333ms and16.667ms. These isolated before/after timings
do not establish capacity. The old-versus-new evidence is frozen in `runs/v1/`.
Production adds native ordering and a local key-array reconstruction while
retaining a single record projection; the additional reconstruction is included
in the fresh integrated measurement below. `integration-baseline.json` preserves
seven originals and58untouched protected hashes.

Production changes only `src/sim/hex/hex_chemistry_world.gd` key ordering plus the
generated identity. The preceding source, single record-projection body and
following source suffix are byte-identical to E2. The specialization suite now
has45direct-production equivalence cases/316checks. Costs, strengths, durations,
chemistry, whole-hex coverage, movement, art, characters, controls and schemas
are unchanged. Package wrapper changes only its generated README-FIRST text.

`integration-freeze-v1/freeze.json` records2,800production records, runtime SHA256
`dd2ab169dcfa6c1290ba7fce6eab1841c92628c90d9dd93a036ae325b32308d5`.
Fresh Focused PASS:8suites/4,759assertions/zero failures or stderr;69,772ms.
Actual integrated profile PASS1,261checks,42equivalence and one ownership case,
14source hashes,48balanced blocks/336raw samples independently recomputed.

| Actual integrated public hash | p50 ms | p95 ms | p99/max ms |
| --- | ---: | ---: | ---: |
| Empty campus |44.914|47.955|50.192|
| Legal paid workload |49.300|53.291|56.919|
| Synthetic all-nonempty |124.782|128.205|132.447|

This compares integrated production with the preserved prototype and frozen old
byte oracle. It is not another old/new speedup comparison. All hash samples miss
both budgets;56-sample p99 is the maximum. Allocation gains are not measured.

Unchanged paid snapshot-stage probe PASS332/zero stderr. Eight stages have five
observations each. Inclusive medians: world capture355.528ms, prepare253.908ms,
chemistry producer capture92.016ms, restore240.422ms, prediction bind79.244ms.
Stage measurements overlap and are non-additive; these are current costs, not a
matched whole-operation improvement. Source inspection in `next-hash-cost-brief.md`
finds no same-instance redundant hash in whole-world capture/prepare. The small
duplicate in standalone chemistry capture has no current production caller and
is deferred; it would not address these measured costs.

Fresh frozen Full PASS:160suites/805,217assertions/zero failures or stderr,
236,144ms; import, asset audit and configured120Hz boot. Referenced receipt/log
hashes and assertion sums are independently verified. Single-engine localhost
fixtures remain separate from complete executable networking acceptance.

Fresh native rendered stress PASS7,991correctness assertions, zero stderr and
zero authority mutations at seven sampled draw checkpoints per run. Normal and
reduced pairs match26non-timing workload/authority fields. **All1,440frames miss
16.667ms.** The existing profiler stores quantiles rather than raw frame arrays;
counts/order/log consistency are verified, not raw percentile recomputation.

| Workload / mode | Frame p50 ms | p95 ms | p99 ms | Draw p95 ms | Two-tick simulation p95 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Distributed / normal |207.389|283.614|339.325|132.890|90.560|
| Distributed / reduced |209.896|294.338|537.011|134.259|101.046|
| Dense / reduced |116.704|190.572|271.116|92.827|164.422|
| Dense / normal |116.577|188.231|196.265|93.328|163.279|

Each row has360native1280x720frames/720authority ticks on this Windows host.
Elapsed frame, draw and simulation buckets overlap; do not add them. This is not
a matched old/new rendering comparison.16.667ms presentation does not certify
120FPS; authority remains configured120Hz with8.333ms tick budget. Capacity FAILS.

Exact Windows export, canonical class registry, executed PCK identity, native EXE
launch and safe close PASS. Exact PCK journeys: Gallery77checks/9frames; character
switch/return/custom weave19checks; basic movement11,601checks/27cases; advanced
movement5,909checks/9routes; Loom assignment/close/paid18FluxWaterHeavy/save and
separate-process12-wire restart; Water888checks/32frames; terrain165checks/31cases.
All9fixed-pose Gallery RGBA images match the preserved E2 export. Pose/phase/input
fixtures are arranged/scripted; they are not physical-control or live-round proof.
Actual Gallery/Water/terrain captures receive visual review; no human style
approval or thirty completed character skins is implied.

PCK SHA256 `43a1fd491519deeb54607c7447feb33e8d1491f660e9ca6e61d9767d25c1cc90`.
ZIP: `exports/hex-native-sort-20260923/HEX-p55-dd2ab169dcfa-Windows-x64.zip`, SHA256
`78abba7040660e052160c3787e6e74b0997843f473b5f80dd9e410897f8bd903`.
Archive CRC and all7entries match the loose payload. `evidence-map.json` indexes
209final artifacts; `preservation-audit.json` verifies76protected/frozen hashes.
Prototype old/new evidence remains sealed separately in `runs/v1/`. Source and
test freezes, tools, receipts and referenced logs are retained together. Profiles
remain isolated at their original run paths; user profiles were not used.

NOT RUN / OPEN: this exact build's full multi-EXE lifecycle; physical two-PC and
Internet play; native spectator; physical keyboard/controller acceptance;
installer/updater; human Water/style/motion acceptance. The prior unchanged300s
lifecycle resource/allocation/JSON failure remains unresolved. Thirty identities
still use three shared templates;36reaction proposals and smaller-grid growth
remain behind their existing gates. No commit/push/publication, installer change,
destructive cleanup or selected-checkpoint promotion.
