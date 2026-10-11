# Quality-foundation evidence

Status: final Full and local Windows packaging passed, 2026-09-29; human acceptance pending.

Identity: `p56-0da6c02de87d`, protocol 56 / schema 22, 2,944 canonical runtime
records. The preserved pre-change baseline is `p56-2073879eeeb7`.

## Fresh results so far

| Receipt | Result and exact scope |
|---|---|
| `focused.json` | 3 suites / 575,749 assertions, zero failures/stderr; no import in Focused tier |
| `full.json`, `import.log`, `suite.log`, `boot.log` | 172 suites / 1,754,524 assertions, zero failures/stderr; import, post-import source identity and configured 120 Hz boot passed |
| `normal.log`, `reduced.log`, `roster.log` | 336 native motion frames + five 30-character boards; no authority mutation |
| `motion-equivalence.json` | All 341 corresponding PNG SHA256 hashes equal the previous-build raw captures; not merely sparse/dense candidate self-comparison |
| `combat-native.json`, `combat.log` | Seven reactions formed from fourteen real paid Bolts; 42 normal/reduced formation/active/decay frames; conservation and exact selection verified |
| `playground-native.json`, `playground.log` | Three actual Wellspring practice-room views after ordinary movement |
| `pose-*.json` and logs | All CPU measurements retained, including the slow post-capture run; not a rendered-frame or whole-game gate |
| `package.json`, `export-smoke.log`, `payload-sha256.txt` | Final Windows export, matching PCK identity, 30-skin admission and native safe close passed |

The lead actually inspected the 13 PNGs preserved under `native/`: all seven
normal active reactions; Arcflash formation and active Reduced Effects; Radiance
decay; Chain Courtyard, Cover Garden and Open Laboratory. Changes are restrained
readability improvements, not a completed environment-art overhaul. Room sparsity,
simple obstacle art and repeated effect-tile structure remain future art work.
Earlier native motion pictures are unchanged and remain in the lively-motion
evidence folder; they are not duplicated here.

## Pose CPU measurements

Eight actors, 240 warmup + 720 measured batches / 7,680 total queries per run.
Dynamic stride and cast envelopes, identical test workload. Sparse runs deform
1,014 vertices versus 2,312 for the untrimmed stream: 56.14% fewer vertices, with
no coarsening of any retained visible triangle.

| Run | p50 ms | p95 ms | Maximum ms |
|---|---:|---:|---:|
| Fresh original build baseline | 5.627 | 6.755 | 9.473 |
| Candidate sparse 1 | 4.031 | 5.724 | 8.763 |
| Candidate dense control 1 | 4.207 | 4.773 | 7.660 |
| Candidate dense control 2 | 4.234 | 4.924 | 10.228 |
| Candidate sparse 2 | 3.732 | 4.381 | 6.189 |
| Candidate after native capture | 5.894 | 10.743 | 53.439 |

The dense control uses candidate precompiled binding data with original full
topology. It isolates topology, not every old/new implementation difference.
Run order was sparse1/dense1/dense2/sparse2; the post-capture measurement is later.
Structural work reduction and independent exact native output are verified.
Median reductions in the isolated tests are encouraging, but noisy tails and the
slow final run prohibit a sustained frame-rate or universal speedup claim.
Simulation, snapshots, GPU completion and network work are outside these timers.

## Review and ownership

Two disjoint implementation agents owned only static ground + tests and material
motifs + tests. Lead owned character skinning, integration, engine execution and
evidence. A separate read-only reviewer found no scoped correctness blocker.
Review added an A -> B -> A unequal-facing stream-topology regression; this was
added after Focused and passed in final Full. All imports, suites,
profiles, captures and exports are serialized by the lead.

Original assets, existing dirty work and both accepted packages remain preserved.
No commit, push, installer, publication or historical checkpoint-pointer promotion.

Cleanup: verified two-build pruning removed the older UX export (299,613,249
bytes); small receipts are archived. A separate request to remove the 341
hash-identical generated PNG duplicates under `.godot` was blocked by command
policy before execution. Those diagnostic copies remain; no deletion is claimed.
No alternate deletion route was attempted. Per-file comparison hashes are also
preserved in `motion-frame-hashes.json`.
