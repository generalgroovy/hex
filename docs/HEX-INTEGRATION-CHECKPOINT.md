# HEX integration playtest checkpoint

Status: VERIFIED PLAYTEST CANDIDATE; paused for human acceptance. September 20, 2026.

Working directory: `C:\Users\sende\Projects\hex`.
Frozen build: **p54-8cb4def57da9**.
Runtime source SHA256:
`8cb4def57da9552610662b00b09000055860e5f50f29257de84ea2bc776c1c87`.
Godot 4.7.1 Windows; protocol 54 / SessionSnapshot 21 / HexWorldSnapshot 3 /
chemistry 3 / envelope 1. Older peers intentionally fail same-build checks.

## What changed

- Renamed the game and developer launcher to HEX. Flux remains the spell resource.
  Windows preferences and custom weaves keep the explicit legacy
  `Godot/app_userdata/FLUX 2` location. Original FLUX is preserved separately.
- Removed duplicate snapshot work with independent decoded ownership and strict
  malformed-state validation. Local synchronous hash reuse preserves the exact
  canonical bytes; no mutable authority cache was added.
- Added bounded remote clash feedback, including exact contact point, spell wires
  and remaining strengths. Protocol/schema advancement is explicit.
- Steam uses transparent hot vents and authoritative terminal cues, with the same
  whole-cell coverage in normal/reduced modes. Supplied PNGs remain references.
- Spell Loom displays effective keyboard chords for twelve positions and distinct
  empty, unbound and unavailable states. Existing custom loadouts remain intact.
- Source Court, Chemistry / Crucible and Loom / Settings signs clarify existing
  campus routes. No new map geometry or continent was substituted.
- Measured Steam occupation and one isolated gait proposal. No balance values were
  changed; the shorter-stride proposal was rejected and live shared rigs remain.

## Fresh verification

Evidence lives in [the curated archive](verification/hex-integration-20260920/README.md),
with receipts, referenced logs and a SHA256 manifest. Raw local originals remain
under `.godot` and `docs/evidence/hex-integration-20260920`.

| Gate | Fresh result and limit |
| --- | --- |
| Final Full / import / 120 Hz boot | PASS: 157 suites / 776,169 assertions, zero failures/stderr; 240.062 s |
| Focused presentation, Steam and geometry | 8 suites / 5,508 assertions, zero failures/stderr |
| Focused p54 codec, queue and transport | 5 suites / 2,516 assertions, zero failures/stderr |
| Actual client clash apply, cue and deduplication | 1 suite / 35 assertions, zero failures/stderr |
| Production localhost lifecycle | PASS in 256.926 s, unchanged 300 s deadline; source build p54 |
| Matched dense 480-tick workload | PASS 2,253 assertions / zero stderr; capacity still FAILED |
| Native rendered stress profile | PASS 8,131 assertions / zero stderr; normal/reduced authority identical; performance FAILED |
| Final normal/reduced capture | 22 frames, zero stderr, actual paid Steam and current shared bodies |
| Snapshot stage probes | Final 332 assertions / zero stderr; intermediate p53 optimization preserves authority hashes |
| Steam occupation measurement | 1,101 assertions / zero stderr; unchanged coefficients |
| Isolated animation A/B pilot | 14 frames from a legal 160-tick trace; rejected for live promotion, intermediate p53 source |
| Windows portable export and actual EXE safe close | PASS: exact PCK build identity, native EXE launch and safe close; zero stderr; ZIP payload hashes verified |

The localhost run uses three real processes and verifies join, round one, late
join as spectator, exact-actor reconnect, Return to Hearth, round two and
reason-bearing administrative release with reservation revocation. It verifies
source execution, not physical two-PC play or the package's network lifecycle.

The Full suites include paid casting, interception, finite accounting and all ten
first-four pairs in both input orders through three trigger paths. Focused tests
and old FLUX results are not substitutes for that final gate.

Failed evidence remains labeled: the baseline lifecycle timed out; the first
stage baseline emitted diagnostic stderr after timing; initial capture fixtures
and README/count checks failed before correction. Historical selected P48 receipts
validate their original package only. No selected checkpoint was promoted.

## Performance and remaining limitations

The identical dense workload retains 53 admissions, 43 releases, 72 refusals,
22 products, 20 clashes and 31,800 paid material with exact finite cleanup.
Snapshot capture/wire p95 improved **623.716 to 295.136 ms** and total host p95
**667.246 to 348.571 ms**. Simulation p95 was **62.835 to 69.368 ms**, so there is
no measured simulation gain. The 8.333 ms authoritative budget remains unmet.

Rendered frame p95 was **192.172 / 178.804 ms** for distributed play and
**157.337 / 152.955 ms** for the dense crucible (normal / reduced). All 1,440
measured frames missed 16.667 ms. Render submissions, two-step simulation and
presentation preparation are reported separately; these are not GPU timings.

Bounded event pressure remains visible: 16 of 20 clashes entered an envelope;
four were trimmed before first inclusion. All 76 actionable refusal/block notices
entered an envelope. Inclusion does not prove delivery. The 183 off-wire records
are flow/Conflagration diagnostics whose authority remains in complete snapshots.
No cap was expanded and no demand was removed to obtain the functional pass.

Short repeated Steam visits can hit more global pulse ticks than equal total
continuous contact. Small/Middle/Large results agree; no silent tuning was made.
Shared templates are not 30 completed skins. Held poses are not transition
acceptance. The stride pilot failed to improve maximum modeled foot-contact drift;
slide silhouette, gait contact and human movement/facing acceptance remain open.

**NOT RUN / not accepted:** physical two-PC or Internet connectivity; actual
export multiplayer lifecycle; installer/updater; sustained 120 Hz capacity or
60/120 FPS; human animation, readability, feel and balance acceptance. A new
three-input same-tick contention oracle remains future bounded correctness work.
The [ten-reaction source review](HEX-FIRST-FOUR-REVIEW.md) also records a missing
independent Mistcurrent Fire-suppression oracle and a source-derived Vortex
center-cell coverage concern. Do not rely on an advertised central safe opening;
whole-cell authority may fill it. Firestorm is not countered merely by jumping.
These are explicit limits; no reaction coefficients or footprints were changed.

## Launch and playtest

Use the current source:

```powershell
Set-Location C:\Users\sende\Projects\hex
.\scripts\run.cmd
```

Verified local portable:

- Launcher: [PLAY-HEX.cmd](../exports/hex-p54-20260920/windows/PLAY-HEX.cmd).
- Executable: [hex.exe](../exports/hex-p54-20260920/windows/hex.exe).
- ZIP: [HEX-p54-8cb4def57da9-Windows-x64.zip](../exports/hex-p54-20260920/HEX-p54-8cb4def57da9-Windows-x64.zip).
- Pack SHA256: `edf8feaed319550834f4bc72435f83b22da02106e3fbb4f7bcaff16913052106`.
- ZIP SHA256: `6290f51831708d72fe4b4947133545515a374e4fa11ca88a10a73f1be664931d`.

These package links resolve in the working directory. Payloads are not committed
to Git and no GitHub release was created. The EXE is the unchanged Godot export
template; the PCK and runtime manifest identify this game's changed source.
Extract a portable ZIP before opening `PLAY-HEX.cmd`; keep EXE/PCK together.
Follow [the five-minute playtest](HEX-PLAYTEST.md). Review actual frames in
[the comparison gallery](verification/hex-integration-20260920/review.html).

Same-build host/join (eight players maximum):

```powershell
.\scripts\run.cmd --farflow=host --session-port=24892
.\scripts\run.cmd --farflow=join --join-address=HOST_IP --session-port=24892
```

For the portable, replace `.\scripts\run.cmd` with `.\PLAY-HEX.cmd`.
For raw `hex.exe`, insert `--` before game arguments. In-world Farflow stations
also provide host/join. Physical networking acceptance remains separate.

## Preservation and stop point

The original dirty FLUX checkout remains `C:\Users\sende\Projects\flux`.
Its historical selected P48 EXE/PCK/ZIP hashes were freshly verified unchanged:
`exports/windows-overnight-p48-20260913/windows/flux2.exe` within that original
checkout. This fallback is older gameplay. The copied selected pointer is byte
identical; use this page for HEX candidate paths rather than promoting the pointer.

Source repository: [generalgroovy/hex](https://github.com/generalgroovy/hex).
The user authorized its creation and source push. Git HEAD identifies the source
publication; the runtime build identity remains independent of documentation.
No installer or automatic expansion follows.
Stop here for the user's playtest; human approval must come from the user.
