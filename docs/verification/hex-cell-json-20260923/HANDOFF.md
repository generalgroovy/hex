# D10 cell JSON experiment and cutoff handoff

Status: bounded test-only experiment COMPLETE; production integration DEFERRED.
The verified playable game remains **p55-dd2ab169dcfa** (D9), protocol 55 /
SessionSnapshot 21 / HexWorldSnapshot 3. No D10 runtime or gameplay changes.
Runtime SHA-256: dd2ab169dcfa6c1290ba7fce6eab1841c92628c90d9dd93a036ae325b32308d5.

Work exclusively in `C:\Users\sende\Projects\hex`, origin
`https://github.com/generalgroovy/hex.git`, dirty main at
`1559a566e33255c59337c5963f1c3c685d757f1f`. The default task directory may still
be old FLUX: pass the HEX working directory explicitly to every command.
The single queue is `.agent/OVERHAUL-IMPLEMENTATION.md`; resume entry is
`.agent/HEX-RESUME.md`. Root alone schedules all engine work.

Latest account reading: **98% used / 2% remaining** in the weekly window.
User requested a cutoff at **1% remaining**, superseding earlier no-cutoff rules.
The run stops at this completed checkpoint before that boundary. Start no runtime change that cannot
finish its full gate within the reserve. No reset credit was used or authorized;
no usage was purchased. The overall development goal remains incomplete.

## Outcome and fresh D10 evidence

Outcome sought: reduce complete chemistry hashing cost by emitting canonical
empty-cell JSON without the temporary metadata-array projection. Acceptance
required exact complete bytes/hash, ordering, direct mutation visibility,
independent ownership and matched complete public-hash measurements, including
nonempty pressure. Only the two new test files changed; live production is
unchanged. General string escaping and scalar formatting remain engine-owned.
Unsupported/deep/malformed cells fall back for the entire hash call.

Frozen v1 FAILED: 239 assertions, two fixture failures and a missing-cell script
error; 44/47 equivalence cases and no timed workload. The escaped-data fixture
passed the axial-coordinate bound but exceeded the translated world-point bound.
The corrected v2 uses cell (-2,3), translated point (-1,011,000,1,721,704), and
guards every new geometry result before indexing. No algorithm change between
v1 and v2. Both source freezes and all failed/successful receipts and logs remain.

Fresh v2 PASS: **1,233 assertions, zero failures and empty stderr**; 47 equivalence
cases, one ownership case and three workloads. Exact bounds, Unicode/control/
quote/backslash data, outer hashed lanes, deep whole-call fallback, restoration
and independent nested mutation are covered. There are 56 unbatched samples per
arm/workload, 48 strict ABBA/BAAB blocks and 336 retained raw observations. All
aggregate and block statistics were independently recomputed by the root curator;
read `review.md` for the separate reviewer verdict. Fifteen measured source
hashes, 16 files in each freeze and all 78 baseline protected hashes are retained.

| Complete public hash | Production p50 ms | Candidate p50 ms | Production p95 ms | Candidate p95 ms |
| --- | ---: | ---: | ---: | ---: |
| Empty campus | 46.793 | 42.747 | 57.382 | 71.473 |
| Legal paid field, 29 active cells | 49.943 | 49.564 | 56.006 | 55.830 |
| Synthetic all-nonempty pressure | 125.827 | 226.181 | 147.317 | 240.075 |

The legal median saves only 0.379 ms (0.76%); synthetic dense median regresses
100.354 ms (79.76%). Empty median improves but its tail worsens. Every measured
hash misses both 8.333 ms and 16.667 ms. The synthetic fixture is not legal
chemistry; 56-sample p99 is the maximum, and allocation behavior is unmeasured.
These results do not justify the extra serialization machinery. **Defer production
integration; no third refinement planned.** This is a completed negative-result
experiment, not an optimization added to the game or a capacity pass.

Sources: `tests/support/hex_cell_json_candidate.gd` and
`tests/performance/profile_hex_cell_json_candidate.gd`.
Evidence: `baseline.json`, `freeze-v1/`, `freeze-v2/`, `runs/v1/`, `runs/v2/`,
`implementation-handoff.md`, `review.md` and the final `documentation-seal.json`.
The evidence directory has `.gdignore`; copied scripts must never enter exports.

## Playable build and prior validated evidence

D9 was completed before D10. Its Full passed 160 suites / 805,217 assertions,
with zero failures/stderr, import and 120 Hz boot; Focused passed 8 suites / 4,759.
Exact Windows identity, launch/close, Gallery, character/custom weave, basic and
advanced movement, paid casting, Loom assignment/save/separate-process restore,
Water and terrain journeys, plus the seven-entry ZIP audit passed. All nine
fixed-pose Gallery images matched E2. These are retained D9 receipts, not new D10
Full, packaging, visual or networking runs. D10 changes no production source;
preserved hashes and a fresh source-only current-state check establish continuity.

D9 rendered stress passed 7,991 correctness assertions but missed all 1,440 frame
deadlines. Its integrated legal hash median was 49.300 ms and whole preparation
253.908 ms; those older measurements are context, not this experiment's A/B arm.
The previous full multi-EXE lifecycle failed with resource/allocation/JSON errors;
its cause is unresolved. No inference from the lifetime probe establishes a fix.

**NOT RUN for D10:** new Full gate, imports, rendered capture/stress, networking
fixtures, export or package rebuild. They are unnecessary for an unintegrated
standalone test experiment and must not be described as passing D10 checks.
Physical keyboard/controller feel, two-PC/Internet play, native spectators,
installer/updater, Water style and shared motion human acceptance remain open.
The 36 reaction proposals remain proposals; no new mechanics or skins are approved.

## Launch and next work

Run the exact validated Windows package:
`C:\Users\sende\Projects\hex\exports\hex-native-sort-20260923\windows\PLAY-HEX.cmd`.
For current source, run `scripts/run.cmd` from the HEX checkout. This is a local
solo review checkpoint, not a certified multiplayer or performance release.
Operational fallback:
`exports/hex-gallery-availability-20260923/windows/PLAY-HEX.cmd` (E2 p55-aeefbd4a5e7b).
Preserve E1 v2 and earlier working packages. Do not use the failed E1 v1 package
at `exports/hex-loom-availability-20260923/`.

On resume, read this handoff, SPECIFICATION and the single queue; recheck actual
usage and source identity. D10, D7 and D8 are deferred experiments, not unfinished
production patches. The next performance slice needs a different measured dense-
cost hypothesis or a concrete observed action-availability defect. Do not expand
fields, lifetimes, grid count or content while capacity and acceptance remain open.
Any production edit requires identity regeneration, frozen-source focused and Full
checks, exact Windows journeys, independent review and preserved logs before being
called playable. Test-only prototype improvements do not satisfy that gate.

Keep 48 px / 2,766 cells / 4,096 cap, 120 Hz authority, eight-player same-build
limit, whole-hex coverage, finite paid budgets, 30 IDs / three shared rigs, the
existing sizes, costs, controls and persistent profiles. No commit, push,
publication, installer change, selected-checkpoint promotion or destructive cleanup
occurred. Original art, dirty user work, profiles and fallback packages remain.
