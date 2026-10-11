# H.E.X. visibility checkpoint — September23

Status: C1 is a verified local human-review candidate. Human acceptance is pending;
performance and multiplayer are not accepted. The broader game objective is incomplete.

Authoritative checkout: `C:\Users\sende\Projects\hex`, dirty main at
`1559a566e33255c59337c5963f1c3c685d757f1f`; origin GeneralGroovy/hex.
Frozen runtime candidate: **p55-ede24ea44158**, protocol55 / SessionSnapshot21 /
HexWorldSnapshot3 / chemistry3 / envelope1. See `freeze.json` for exact source hashes.
The selected checkpoint pointer is unchanged. Original FLUX is untouched.
The final source-only identity recheck passes for all 2,793 production records;
the final current-state/scope check passes with zero issues. Its legacy delivery
section still reports old pinned artifacts missing from this HEX checkout. That
is not new evidence of their availability and does not promote this candidate;
the explicitly verified operational fallback is the September21 Loom package below.

## Implemented C1

The original opaque-wall tangent quad cut through its own surface and darkened
the visible wall. The correction subtracts each exact owning polygon from its
shadow. Other blockers still shade that surface; Hexes retain their exact six faces.

Unseen pixels are replaced with an opaque cached copy of static campus terrain,
tinted to66% brightness. This shows terrain without exposing live projectiles,
chemistry or actors through an alpha overlay. Static solids are overwritten before
shadows. Physical Hex interiors are overwritten and only the current active cover
regions are redrawn from the existing presenter; unrelated material layers remain
concealed. Blocker shadows run after the28-world-unit range feather, preventing
bright overlap halos. The feather changes static brightness, never visibility alpha.

All masks and texture UV use the same snapped camera transform. Missing/dead
viewpoints fail closed; the missing-local draw return now performs the opaque
replacement. Existing actor/cue LOS and the living viewpoint-body exception remain.
No simulation, strengths, costs, durations, map scale, collision or wire fields changed.
This is local presentation concealment; snapshots still carry same-build world state.

The backdrop is rendered once per configured campus instance at3072x2304. Its
RGBA8 color storage is nominally27MiB before driver/framebuffer overhead. This is
not a measured GPU allocation or performance improvement claim. The isolated
Hex-practice field uses its opaque neutral ground fallback instead of a wrong campus.

## Verification ledger

- Baseline: `wall-before-v1` freshly captures12 native frames on preserved
  p55-a0952919d4d5. Historical Full157/803905 is not new-source validation.
- Development: focused-v1 PASS6 suites/935 assertions/zero stderr; native
  wall-after-v1 PASS12 frames with authority preservation. Its embedded identity
  predates final cover/alignment edits and is development-only.
- Development Full-v1 PASS157 suites/804121 assertions, zero stderr, import,
  asset audit and120Hz configured boot. Import created the new script UID; it is
  not the final frozen identity.
- Full-v2 FAILED before engine execution: documentation status fell below the
  required header window. Explicit current status was restored; the failed receipt
  remains. Runtime was not changed by that documentation correction.
- **Final Full-v3 PASS:** 157 suites / 804,121 assertions, zero failures/stderr,
  import, asset audit and 120 Hz configured boot on `p55-ede24ea44158` (222,126 ms).
- **Final exact-PCK wall capture PASS:** 12 native frames, all three sizes in
  normal/reduced modes and a 64-step ordinary simulation movement sequence sampled
  at steps 0/32/64. Drawing preserved authority. Root and independent visual reviewer
  inspected the rendered images; this is not human approval or full motion acceptance.
- **Final source and exact-PCK pixel captures PASS:** each has 31 canary cases plus
  the cover-surface oracle / 165 assertions / zero failures/stderr. Eight wall bearings,
  50/75/100 zoom, normal/reduced effects, fractional cameras, out-of-range,
  inside-wall, dead/missing observer and synthetic cover removal are covered, but
  not their complete Cartesian product. Hidden sampled crops change zero pixels;
  clear and removed-cover controls visibly change. Active Fortify versus removed
  terrain differs by 1,538 pixels in a 49x49 crop. The surface remains visible while
  activity behind it is concealed. Exact authority and fixture state are restored.
  Source-v2 and PCK surface crop hashes match.
- Preserve `hex-terrain-v1` as **preliminary concealment evidence only** (31/159).
  Its initial synthetic cover lacked material membership and could not prove visible
  structural redraw. Actual image inspection caught this; the corrected helper
  `d9c75485c0bc33179ed2bc848d80e5facb337a38f537de28bb749fe79f17f561`
  supplies complete metadata and a separate visible-surface oracle. Neither version
  proves a paid cover formation/removal journey or native spectator behavior.
- **Loom regression PASS on source and exact PCK:** ordinary Interact/assignment,
  confirmed twelve positions, Escape close, movement, paid Heavy cast (18 Flux),
  save and separate-process restart restore pass in isolated profiles. The fixture
  arranges the starting position and injects input; this is not physical keyboard or
  controller acceptance. The protected P0 policy and its unit files retain baseline hashes.
- **Windows package PASS:** 2,793-record source identity check, export, executed
  PCK BUILD-STATE, actual EXE automated native launch/safe close and seven-entry
  ZIP-to-payload byte audit. Freeze hashes, index, checkpoint pointer and fallback
  PCK/ZIP remain unchanged. See `package-audit.json` and package receipt.
- **Exact-EXE localhost lifecycle FAILED:** the unchanged 300-second wrapper
  expired at 300,867 ms. Logs confirm connection, authoritative guest movement,
  first-round participation, reserved-identity reconnect, late-spectator following
  and Hearth handoff. The late guest never logged joining Proving Court serial 2
  before the deadline; rematch readiness is not lifecycle completion. All three
  stderr files are empty. No deadline or workload was relaxed and no retry was used
  to select a better result. Receipt: `network/network-design-final-v1.json`; all
  host/guest/late-guest logs are retained. Wrapper-owned processes closed afterward.
  Multiplayer stays experimental and unaccepted. This headless exact-EXE session
  test does not prove rendered spectator visibility, eight-player capacity or two-PC play.

Receipts, referenced logs and images are retained together through `evidence-map.json`.
It records each original path, preserved relative path and SHA256; isolated user-data
profiles are excluded from the documentation copy and retained at their run locations.
All 409 preserved evidence-file hashes were rechecked after curation. Final
source-identity, documentation scope, package/preservation and whitespace checks
pass. There are no staged changes or remaining wrapper-owned Godot processes.

## Final native stress measurement: timing gate red

The unchanged rendered workload completed four runs of 360 frames / 720 authority
ticks each, eight actors, 1280x720 Windows native Compatibility rendering. Its
7,991 diagnostic assertions pass with zero failures and zero draw-time authority
mutations. Normal/reduced modes preserve the same admitted workload and authority.
**All 1,440 frames miss the 16.667 ms presentation budget.** The separately timed
two-tick simulation also exceeds its combined 16.667 ms budget; 120 Hz is configured,
not sustained under this stress. Reduced effects do not resolve the simulation cost.

| Workload | Mode | Frame p50 ms | Frame p95 ms | Frame p99 ms | Draw submission p95 ms | Two-tick simulation p95 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Distributed | Normal | 222.814 | 307.768 | 350.295 | 160.806 | 90.248 |
| Distributed | Reduced | 219.049 | 280.316 | 298.808 | 154.011 | 89.026 |
| Dense Crucible | Reduced | 125.482 | 182.184 | 204.082 | 95.419 | 155.262 |
| Dense Crucible | Normal | 120.057 | 184.772 | 202.087 | 97.380 | 153.920 |

Frame elapsed spans `queue_redraw` through `frame_post_draw`, including scheduling
and render completion. Draw submission is CPU command submission; two simulation
ticks are timed separately. These are not GPU timings and must not be casually summed.
The receipt includes p99/max, deadline misses, requested/admitted/refused work,
events, inventory and render-monitor samples. Overall video-memory monitor peak
is approximately 304.4 MB, not the marginal cost of the terrain backdrop.
There is no matched old-source rendered baseline, so neither a gain nor a regression
caused by this visibility change is established. Hardware/backend are preserved in logs.

## Fresh feasibility measurements

The complete same-map48/32/24 lattice oracle passed25 assertions, preserving
production ordering/hash and18px clearance.48px gives2766 cells;32px gives6495;
24px gives11633. Both smaller lattices exceed4096. Neither was configured as live
authority; no map shrink, cap increase, truncation or changed radius was attempted.
The independent127-cell effect-selection bound also remains a future gate.

The unchanged eight-actor/40-paid-tick snapshot-stage diagnostic passed332
assertions with conserved material and stable authority. Five samples only:

| Inclusive stage | p50 ms | p95/max ms |
| --- | ---: | ---: |
| World capture |432.865|504.123|
| World prepare |294.914|296.851|
| Chemistry capture |135.524|140.404|
| Chemistry restore |268.807|286.972|
| World hash |72.269|74.129|
| Prediction bind |70.055|70.571|

These overlapping stages cannot be summed. They do not establish p99 capacity,
120Hz or network acceptance. No snapshot optimization was implemented in C1.

## Design and art decisions

- `reaction-decisions.md`: all36 unordered pairs evaluated against actual stable
  IDs; proposed new mechanics remain approval-gated. Steam→Vaporwave, optical role
  swaps, Frostway→Icewall and Capacitor→Overload are substantive replacements.
- `art-runtime-audit.md`: all30 identities mapped; three58/63/68px shared templates
  are live. Motion existence is not full animation acceptance or30 finished skins.
- `art-comparison/index.html`: accepted-reference/current/staged comparison,
  using preserved existing images. It is not newly integrated production art.
- `runtime-audit.md`: source-backed cost/geometry/contact findings and smallest
  proposed stateless validation optimization with equivalence gates.
- `worker-briefs.md`: exact exclusive ownership and acceptance responsibilities.

Next dependencies are maintained only in `.agent/OVERHAUL-IMPLEMENTATION.md`.
The recommended art pilot is existing Water motifs at48px; human acceptance is
required before expanding the pattern. Reaction redesign needs explicit approval.
The design review's three highest-value additions are shared effect/phase cues,
one paid chemistry rehearsal with an escape/reset route, and explicit visual
complexity budgets. These improve understanding and counterplay before adding
new reaction state, larger arenas or further skins. They are recommendations,
not claims of integrated or human-approved content.

## Launch and remaining gates

Frozen local Windows candidate:

```powershell
& 'C:\Users\sende\Projects\hex\exports\hex-visibility-20260923\windows\PLAY-HEX.cmd'
```

Current source:

```powershell
Set-Location C:\Users\sende\Projects\hex
.\scripts\run.cmd
```

ZIP: `exports/hex-visibility-20260923/HEX-p55-ede24ea44158-Windows-x64.zip`.
Runtime SHA256: `ede24ea441589507badbc536e87b99887048c2b070451f0753b72a1ae98c8ec1`.
PCK SHA256: `d7d0ce0c2fabb7aed377e2f08f72c407d5d5ce7becf31e6a3598b442870b56b8`.
ZIP SHA256: `e314659eb20eee7d23093b62df50a19cd07e5b27eb63f11dad6d151efc0763a3`.

Operational fallback: `exports\hex-loom-fix-20260921\windows\PLAY-HEX.cmd`.
Keep EXE/PCK together; older EXEs contain older source. Profiles keep the compatible
`Godot/app_userdata/FLUX 2` location. Do not reset existing controls or weaves.

For your review, circle the Recovery Grove pavilion, change zoom and effects mode,
and verify that the near wall stays readable while a character behind it disappears.
Form/remove paid Earth cover and check its actual surface and concealment. Repeat
the Spell Loom assignment, close, movement, casting and restart route in
`docs/HEX-PLAYTEST.md`. Record the visible build ID and exact input sequence for issues.

Known cosmetic issue: a static station label can be partly shown at the 720-unit
range edge (a trailing “LOW” from “HOST FARFLOW”). The cached terrain and live
renderer fade static labels differently. This does not expose a hidden actor or
live event; independent review classed it as a follow-up, not a blocker for local review.

Native spectator viewpoint, paid cover lifecycle in this new capture, resize/device
reset, physical keyboard/controller and two-PC/Internet play are NOT_RUN by this
slice. Headless spectator policy tests pass in Full but do not replace native proof.
Human readability/feel, full shared animation, installer/updater, release capacity
and every offered player option remain open. No representative skin or Water motif
has received human approval; 30 identities still use three shared body templates.
No commit, push, publication, installation or selected-pointer promotion occurred.
The user removed the percentage cutoff; no reset credit was redeemed or purchased.
