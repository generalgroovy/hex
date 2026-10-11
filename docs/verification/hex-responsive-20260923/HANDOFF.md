# H.E.X. responsive Wellspring candidate — September 23

Status: preserved verified local Windows review candidate; timing and multiplayer gates FAILED. D2 source integration continues under ../hex-hash-20260923/HANDOFF.md. No release or human approval.
The active queue remains `.agent/OVERHAUL-IMPLEMENTATION.md`. Frozen candidate
**p55-1ce2d09597b3**,2,800 production records, protocol55/SessionSnapshot21/
HexWorldSnapshot3/chemistry3/envelope1. Runtime SHA256:
`1ce2d09597b3ad9554f4966f65efe1fd2f871b7d63dc6ae9efe66645259ec5b6`.

Authoritative checkout is `C:\Users\sende\Projects\hex`, dirty main at
`1559a566e33255c59337c5963f1c3c685d757f1f`, origin GeneralGroovy/hex.
`baseline.json` records the incoming dirty/staged boundary and protected hashes.
The selected pointer and existing profiles/packages remain untouched. Original FLUX
is not this implementation. No percentage cutoff, credit purchase or reset redemption.

## Bounded changes

- Snapshot validation builds one local empty record, validates integer metadata,
  and uses native structural equality for completely empty cells. Nonempty,
  malformed and extra-field records retain the original validation path. No
  persistent cache or changed snapshot/hash/wire semantics.
- Existing Water normal/reduced pixel crests are mapped into authoritative 48px
  cell polygons. Existing full-cell fill, phase, outline, ownership and expiry
  remain. No cast, movement, material or damage budget changes. The two imported
  atlases must match their exact decoded RGBA hashes; alpha-border repair is
  explicitly disabled on these copies. Human style acceptance remains pending.
- Static fog terrain omits proximity-dependent station titles. Live station
  titles retain their ordinary nearby fade. This fixes distant fragments while
  preserving the opaque replacement and strict concealment of live activity.

## Development evidence

- Baseline stage profile: PASS332 correctness assertions, eight actors/40 paid
  ticks/2,766 cells, stable authority and conserved material. This was freshly run
  before the validator edit. Prior C1 receipts remain historical evidence.
- Matched validator ABBA v2: PASS584, 56 samples per implementation/case. AMD
  Ryzen 3 7320U, Windows, Godot4.7.1 headless. Median empty-map time 59.993→26.584ms;
  29-nonempty records 59.083→27.010ms. Synthetic all-nonempty fallback pressure
  58.911→60.943ms (+3.4%). p95 respectively61.892→31.128,61.951→30.649,
  61.804→62.764ms. All samples exceed8.333ms and16.667ms. p99 is the maximum of
  only56samples, not a tail-capacity estimate. Allocations unavailable. Synthetic
  entries are validation pressure, not an admitted gameplay workload.
- Unchanged paid stage after-profile: PASS332, same world/chemistry/topology hashes.
  Five samples: world capture median488.128→406.548ms, preparation344.384→266.051ms,
  chemistry capture144.756→112.486ms; restore277.381→336.074ms. These nonalternating,
  sample-limited stage observations are noisy and overlap; do not sum them or
  attribute all variation to the shortcut. Capacity remains red.
- Fog source capture: PASS27,12native A/B frames,12cache title crops and a positive
  nearby-title control (2,541 changed pixels). Baseline is a reconstructed old
  cache policy in the current renderer, not a separate historical executable.
- Movement source v2: PASS11,601 checks;192independent travel/aim router samples,
  24paid walk→slide→jump/cast routes across three sizes, three focus/rearm and
  three low-Flux cases; saved/remapped J binding. No raw movement-state seeding.
  Actual profile Stamina/radii remain620/660/700 and17/18/19. Diagnostic steps use
  real input routing and simulation, not native frame scheduling/physical controls.
- Import/Fast v3: PASS, exact Water import correction and configured120Hz boot.
- Focused v1: PASS9suites/7,153assertions/zero stderr, including snapshot equivalence,
  malformed cases, ownership/mutation, prediction, Water and visibility.
- Frozen Full v1: PASS158suites/804,750assertions/zero failures/stderr, import,
  asset audit and configured120Hz boot (244,458ms). All production changes are
  frozen in `freeze.json`; this is new-source validation, not the old C1 receipt.
- Water source v4: PASS32native frames/888checks/zero stderr, real paid input,
  launch/travel and terminal commitment at processed tick49/observed tick50.
  Exactly one positive non-trail ground part replaces projectile1000's flight
  allocation, followed through formation/active/decay/natural expiry. Normal and
  reduced screenshots visibly differ from old marks while occupied and match
  exactly after expiry. Initial bench position is arranged; input is scripted.
  Human review of the repeated crest motif remains pending.

Preserved failed attempts: import-v1 stopped at stale source identity before
engine work; ABBA-v1 and movement-source-v1 failed on typed-array harness errors;
Water-v1 rejected transformed transparent RGB before frames; Water-v2 showed
28frames and valid phases/pixel controls but failed its impact-event observation.
The latter event is consumed internally; the capture correction must verify the
actual paid flight-part-to-ground-part transition. Water-v3 then compared creation
with the already incremented tick and failed. V4 captures the actual pre-step tick
and requires exactly one advanced tick; no gameplay behavior changed to pass it.
Failed runs are not acceptance.

## Remaining verification and boundaries

Windows export, executed PCK identity and actual EXE native launch/safe close pass.
Source and exact PCK both pass Water32frames/888checks, station labels27checks/
12frames, visibility31canaries/165checks, movement11,601checks, and Loom
assignment/close/paid cast/save/separate-process restart. Exact-PCK journeys use
the pinned engine with external instrumentation and the frozen pack; the release
EXE itself is tested separately for launch/close and the localhost lifecycle.
Rendered stress and the exact-EXE localhost lifecycle are complete, with failed
capacity/lifecycle gates. Both remain separate from functional or human acceptance.

## Exact-EXE localhost lifecycle: FAILED

The unchanged configured300-second run ended with a Windows insufficient-system-
resources error while inspecting the late guest's stderr. Actual wrapper elapsed
time was385,848ms; it did not enforce a clean300s finish under those conditions.
Host stderr contains allocation failures and JSON parse failure; guests also
report JSON parse failures. Host/guest/late-guest stderr sizes are271/404/101bytes.
Logs show join, shared emote, first-round activity, reserved-identity reconnect,
authoritative guest movement and late-spectator following. They do not prove the
complete lifecycle or second-round return. No retry, changed workload or extended
deadline was used to obtain a pass. Receipt and all logs are preserved under
`network/` and `runs/hex-network-responsive-final-v1/`.

On continuation the wrapper handle was gone, all recorded test processes were
absent and the terminal failed receipt existed. The source identity and frozen
file hashes were freshly rechecked as unchanged. The Windows host then reported
602MiB free physical memory out of7,456MiB, and11,739MiB free virtual out of22,304MiB.
That later observation cannot establish peak usage or the original exhaustion's
sole cause. A three-process rerun is not warranted without targeted evidence or
an intervention. Future performance work remains isolated and single-process.

## Fresh rendered cost: timing gate failed

The unchanged four runs of360frames/720authority ticks pass7,991correctness
assertions, with zero stderr and zero draw-time authority mutations. Normal and
reduced modes retain identical admitted workload/state traces. **All1,440frames
miss16.667ms.** No draw or simulation capacity claim is made.

| Workload / mode | Frame p50 ms | Frame p95 ms | Frame p99 ms | Draw submission p95 ms | Two-tick simulation p95 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Distributed / normal |225.273|298.784|367.219|160.092|87.996|
| Distributed / reduced |228.910|294.485|327.684|159.282|88.770|
| Dense Crucible / reduced |119.587|200.114|277.653|100.469|156.829|
| Dense Crucible / normal |117.114|186.784|214.111|99.093|155.893|

Exact values, inventory, requested/admitted/refused work, p99/max, render monitors
and authority hashes are in `runs/unified-wellspring-render-profile-responsive-v1.json`.
The table is copied from that receipt. Frame elapsed
spans queue_redraw through frame_post_draw; draw submission is CPU command work,
and simulation measures two ticks. These timings overlap and must not be summed.
The frame harness uses a16.667ms interval, not a120FPS claim; the authority budget
is8.333ms per tick. This is the current candidate's measured cost, not a matched
old/new Water draw benchmark or proof the validator speeds up gameplay frames.

## Continued bounded work

Follow-on advanced source movement passes5,909checks: three actual sizes each
complete earned Jump→Float→paid cast→release/landing, Float→directional B dodge/
cast→neutral B fastfall, and earned real wall115 contact→V wallrun/cast→outward
detach/landing. Fastfall is free under current rules. No movement mode, height,
velocity or contact is seeded. Exact PCK also passes5,909checks/all nine routes
with zero stderr. These scripted
routes do not certify physical controls, rendered motion or the full direction matrix.

The hash-stage diagnostic passes1,007checks with42samples/stage/case, exact
canonical bytes/hash and unchanged authority. On the legal29-active-cell workload,
canonical-value construction has median39.575ms, compact projection27.719ms,
JSON11.456ms and canonical UTF-8/length-prefix/byte construction plus SHA0.878ms.
That fixture has29active cells but49nonempty stored material cells; it represents
the first40paid ticks/eight Bolt admissions, not the full delivery-family cycle.
The independent reference covers projection; generic canonicalization is shared
with production. Inputs are prepared outside each stage;
the stages and percentiles are non-additive. The next isolated test-only candidate
specializes canonical cell values while retaining exact bytes and fallback behavior.
It is not integrated into this frozen runtime and has no performance claim yet.
Candidate probe v1 FAILED: a Variant-inference parse error disabled the oracle,
and the diagnostic emitted empty cases and a false PASS line. The wrapper rejected
stderr. Its logs/receipt are preserved; a type correction and completion guards
must precede a fresh measured run.
The previous C1 lifecycle failed; no multiplayer acceptance is inherited.
Human motion/style/feel, controller, native spectator, two-PC/Internet,
installer/updater and smaller-grid capacity remain separate open gates.
Thirty identities still use three templates. Proposed reaction redesign is not enacted.

Current Windows launch: `exports/hex-responsive-20260923/windows/PLAY-HEX.cmd`.
PCK SHA256 `db8015fd6cf405067c1517729e760e8c6699aab07de2a2ec225ef006f9df72e1`.
ZIP `exports/hex-responsive-20260923/HEX-p55-1ce2d09597b3-Windows-x64.zip`, SHA256
`29cb32cc43fb8f12f4045dd0f0aa8c848c96df3fc87c838d2b08b4dd5c33f8ce`.
Package integrity/preservation audit passes: all ZIP entries match payload bytes,
and22protected/frozen hashes matched before D2 integration. Curation v3 verified497evidence files,
including the terminal network failure and prototype receipts. Profiles are retained
at their isolated run locations and excluded from documentation copies.

Operational fallback: `exports/hex-visibility-20260923/windows/PLAY-HEX.cmd`;
secondary `exports/hex-loom-fix-20260921/windows/PLAY-HEX.cmd`.
Current development source: run `scripts/run.cmd` from this HEX checkout.
Old EXEs contain their original builds. Do not overwrite or promote them.
