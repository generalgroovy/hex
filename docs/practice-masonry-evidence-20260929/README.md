# Practice masonry and idle rendering evidence

Status: Full/native/CPU/Windows-package checks passed, 2026-09-29.
Build `p56-558bf72b754f`; source SHA256
`558bf72b754fe193e981f0bab90d4f33bca4f1e9aa0e7d98e7581ad425cf583b`.

## Scope

Fifteen existing practice obstacles, three presentation-only stone families,
one cached texture per obstacle. No collision/map-authority change. Empty normal
campus field rendering exits only after actual occupied membership is checked;
active fields and standalone court base retain their existing paths.

## Attempts and results

| Receipt | Scope/result |
|---|---|
| `baseline-failed.json`, `baseline-failed.log.err` | Failed diagnostic: stale HUD override lacked preferences parameter; no timing evidence |
| `baseline.json` | Repaired frozen native attribution;2,096 assertions, zero failures; four original/disabled/enabled pixel controls equal |
| `focused-failed.json` | Failed new test's invalid static Script method call; not accepted |
| `focused-walls.json` | Corrected wall/HUD Focused:2 suites,2,515 assertions, zero failures/stderr |
| `idle-identity-failed.json` | Identity guard rejected a source edit after metadata generation; no suites executed; refreshed before final freeze |
| `attribution-before-idle.json` | With new walls, before idle optimization:2,096 assertions, zero failures; nested ground timings do not enter disjoint totals |
| `focused-final.json` | Frozen candidate Focused:3 suites /2,662 assertions, zero failures/stderr; empty draw, current HUD signatures and full bounded wall-cache regressions |
| `attribution-final.json`, `native-equivalence.json` |2,096 assertions; all four native images and authority hashes equal before/after the idle shortcut; three room PNGs also SHA256-identical |
| `full.json`, `suite.log`, `import.log`, `boot-120.log` |172 suites /1,754,688 assertions, zero failures/stderr; import, post-import identity and configured120Hz boot |
| `idle-cpu-failed.log.err` |New diagnostic typed-array error; owned process stopped, no timing evidence |
| `idle-cpu.json`, `idle-cpu.log` |Repaired zero-membership CPU diagnostic:768 samples per arm, alternating order, both effects settings, no authority mutation |
| `package.json`, `export-smoke.log`, `payload-sha256.txt` |Windows source/PCK identity,30-skin admission and native safe close passed; ZIP106,674,545 bytes |

The failed instrumentation and identity attempts are retained deliberately.
Profiling measures synchronous CPU submission in frozen legal tick160 fixtures,
not moving gameplay, GPU throughput, networking or sustained120Hz. The diagnostic
uses existing default actor presentation, not30 full-body skins under load.
The `dense-crucible` fixture has zero active ground cells at this sampled tick;
it is not proof of dense reaction performance or genuinely empty membership.
More precisely, zero active quantity is NOT zero occupied coverage: these stress
fixtures retain records. They do not isolate the new early-exit branch. Their
variable timing differences must not be presented as the shortcut's speedup;
the separate zero-membership microbenchmark measures that branch.

## Isolated idle CPU result

| Arm | p50ms | p95ms | Maximumms |
|---|---:|---:|---:|
| Frozen prior draw body |0.152|0.162|0.205|
| Current empty-membership exit |0.005|0.006|0.015|

All11,337 topology cells remain; occupied membership is actually zero. This
headless microbenchmark executes no graphics commands. It measures a small idle
CPU saving, not the much larger retained-coverage cost, GPU time or whole-game
frame-rate. The native profile's zero-active cells must not be substituted for
zero membership. Formation/decay and low-quantity fields still render normally.

Three native room views were inspected at1280x720 and75% camera zoom. The first
visual candidate and final comparison use actual production drawing following
ordinary simulation movement, not an external concept illustration.

## Remaining gates

Full regressions, final native same-pixel comparison, package identity/art boot
and safe close passed. Human wall/corner readability,
movement feel, color-vision recognition, audio, physical multiplayer, dense
simulation and snapshot timing remain separate open acceptance work.

Cleanup retained only practice-masonry and quality-foundation exports after
verifying both payload/ZIP hashes and boot receipts. Older lively-motion export
was permanently removed:299,618,002 bytes. Its small receipts remain under
`docs/build-retention/hex-lively-motion-20260929/`. No source/original art deleted,
no commit/push/publication or installer/checkpoint-pointer promotion.
