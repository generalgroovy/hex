# Element expansion and player teaching

Status: **locally qualified Windows playtest p60-6d80c3bce71e, October 9, 2026.**
Full regression, native review and portable verification passed for the same
source. The preserved qualified fallback is p59-a289f67c1acf.

## What this source implements

- Every nonempty combination of Water, Fire, Air, Earth, Light and Dark across
  Bolt, Heavy, Rapid, Spray, Mantle, Fuse, Split and Rebound: 63 × 8 = 504 spells.
  Ice and Charge are derived effects. The original 24 spell wires/order and
  twelve equipped positions remain stable.
- Six finite, nonstacking hit-status channels. Extra ingredients increase Flux
  cost and shorten status duration; they do not multiply base damage or matter.
  Mixed terminals can form their named field from one paid source. A singleton
  requires a second paid source for its self-reaction.
- Thirty distinct rival signatures earned through clean actual victories. The
  complete Range lends spells temporarily; all 30 sandbox characters remain
  available. Developer participation makes that challenge attempt ineligible
  for a reward, even when toggled off before the result.
- An optional six-step introduction based on real actions, current bindings,
  visible resource recovery and a manually cast mixed spell. It is skippable
  and never supplies input or earns progress for the player.
- Clearer wall contact, elevated character/spell presentation, all-ingredient
  mixed projectile cues, finite status badges and a readable Fuse countdown.
  The engine remains a 2D simulation with depth presentation.

The [combat](combat-design.md), [learning and progression](progression-testing-design.md),
[wall movement](movement-design.md) and [element presentation](element-presentation.md)
records connect each design choice to established examples and state the limits
of that transfer. Magicka supports composable elements, Noita supports varied
delivery and bounded composition, Capcom's practice modes support staged learning
and repeatable testing, and Mega Man supports learning the tool demonstrated by
a defeated enemy. None of those references proves H.E.X.'s particular tuning.

## Ownership and independent review

Three specialist agents worked across combat, movement/presentation, and
world/menu/learning. They reviewed each other's changes. Root owned integration,
state replication, source identity, all engine runs, native inspection and
packaging. Runs were serialized with the existing engine guard and separate
APPDATA directories. Original assets, inherited dirty work, failed evidence and
previous packages remain preserved.

## Concrete corrections found during review

| Finding | Correction |
|---|---|
| Two simultaneous Split parents could compete for the last owner slot; held Mantle/Fuse objects could disappear from optical-capacity accounting. | Reserve admitted children immediately and retain held objects in the real inventory. Shared source matter and damage remain finite. |
| The new wall draw and inherited aerial draw replaced the caller's camera transform. | Submit rotated world-coordinate geometry without resetting the caller. Actual camera/sentinel controls and six native images verify the fix. |
| Long mixture names were too compressed or clipped in the expanded Loom. | Sixteen cards per page, complete wrapped names and separate metadata. All 504 choices and five viewport input transforms are exercised. |
| A planted Fuse's countdown arc was mostly hidden by its body. | A nonflashing segmented bar below the body exposes actual remaining time. Normal/reduced motion and both zooms were reviewed. |
| The introduction obscured the resource bars it asked the player to watch. | Move the guide to a separate upper-left column and use shared drawing/click geometry. Actual font and HUD-overlap checks cover both sizes. |
| The combat HUD displayed a six-element Mantle as WATER / DISABLED. | Show the actual mixture name, all eight delivery families and the compiled cost. Withered now visibly seals Health/Flux, while Stamina remains available. |
| Range selection omitted ingredients, timing, cost and on-hit statuses. | Add live compiled explanations separately from the field effect and its counter; show six singles before progressively larger mixtures. |
| A refused spell change showed its reason behind the modal. | Display the reason inside the Range header; retain the selection for a normal recovery-and-retry path. |
| A redundant Loom hint touched the starter-kit button. | Remove the duplicate hint; the full instruction remains in the subtitle. |
| The four practice shortcut buttons covered the rival and fields during a challenge; the challenge card overlapped a narrow-screen notice. | Hide both shortcut painting and hit areas during challenges; retain shortcut keys and reserve the maximum notice height above the instruction card. |
| All 30 signature encounters inherited the older Oh Tipi duel sign. | Use a dedicated Signature Challenge context in both visible terrain and the static terrain backdrop. |

## Verification record

Final evidence is recorded here only after the corresponding run completes.
The focused network/HUD run passed five suites, including full dense status
roundtrips through actual compressed/fragmented datagrams and real ENet loopback.
The final focused UI/legacy run passed seven suites: training tools, scaled Loom
handoff, strict wire decode, owned capture, chemistry preparation, sealed snapshots
and producer topology. Final clarity checks passed another four suites (training
tools, Loom handoff, terrain context and duel presentation). The
[54-image native review](native-review.md) combines 30 presentation images and
24 integrated teaching screenshots. The final teaching journey passed 102
checkpoints through 1,516 ordinary simulation steps, including refused loaner,
real recovery/retry, weave preservation, challenge setup and sticky Developer
reward refusal after a real paid victory.

Failed runs remain under `.godot/element-expansion-*`. In particular, native v1
omitted the normal acknowledged-weave completion boundary while automatic
processing was disabled. Native v2 included that boundary but attempted another
loaner before actual cast recovery expired. The repaired harness must advance
ordinary simulation; no timer reset or direct effect injection may make it pass.
Those failures are not accepted end-to-end results.

Full v2 completed all 233 suites but failed672 assertions and emitted377,751 bytes
of stderr. It exposed callbacks against an uninitialized teaching-controller
owner/world, plus stale pre-expansion fixtures: starter tampering targeted an
unused enumeration cache; new delivery positives used the deliberately refusing
non-Hex backend; canonical/prediction rows omitted appended delivery/status data;
historical art/travel loops accidentally included the expanded catalog.

The controller now refuses input and frame/character callbacks until its owner
and world exist, while retaining unconditional transition cleanup. The repaired
fixtures retain independent original-spell controls, genuine authoritative-map
tamper negatives, all 504 paid live-Hex admissions, all 252 new-family non-Hex
refusals, complete prediction restoration and explicit presentation-route
boundaries. Two runtime-aborted subtests had printed zero-failure suite summaries;
their stderr is correctly treated as failure. The full failed receipt and exact
test originals remain preserved. A fresh Full is required after these repairs.

Native teaching v3 completed 91 checkpoints and 1,516 real simulation steps,
but its 24-image review exposed the last Loom/challenge defects above. Full v1
was deliberately interrupted by stopping only its verified owned engine before
editing. Its failed receipt (`Godot exited with code -1`) and logs are retained;
it is not a regression failure or a completed Full qualification.

The initial network failures included obsolete protocol/schema/count/byte-limit
fixtures and an unpacked MTU oracle. Production already compressed/fragmented
reconciliation; the replacement checks every actual datagram against the
unchanged 1,392-byte MTU and restores all 48 status values. Subsequent test-only
repairs preserved explicit rejection and complete-state comparisons. Corrupted
punctuation in eight HUD test literals was repaired to match correct UTF-8
production text, without weakening its font/layout assertions.

## Enlarged Wellspring follow-up

The world is now 6144 x 5376, four times its previous area, with seven districts
and thirteen named arrivals. Tideglass Quays, Verdant Reaches, Basalt Foundry and
Starward Terraces add twenty-four solid wall segments and twelve practice routes.
The existing service/court data remains an exact prefix of the expanded layout.
The independent polygon count and executed topology agree on 59,466 eligible
cells. The expanded axial bound is 384 and the cell cap is 65,536; cast, product,
resource and datagram budgets remain unchanged.

Esc/controller Back opens one compact contextual Menu; M opens the map. Range
tools moved into that menu, replacing its persistent help block and buttons.
Travel resolves a trusted destination again when confirmed, checks current solid
geometry and living occupancy, and clears motion/camera history while preserving
resources, cooldowns, weave and progression. Actual active-mode/action/status
refusals remain visible in the map. Start retains its emote binding.

Reciprocal review caught an undersized wall-art limit and a stale travel directory
after a failed layout reload. Both were repaired. Malformed JSON now returns a
quiet diagnostic through the loader instead of printing a global engine error.
Native terrain regions, wall skins and POV backdrops have explicit allocation
bounds; these are not whole-process memory or frame-rate measurements.

Focused v2 exposed four old smaller-layout expectations. Focused v3 passed the
new map/navigation and topology behavior but retained three stale tests (minimum
viewport size, axial257 rejection and old floor-label count), plus468 stderr bytes
from the malformed-file negative. Focused v4 passed all seven selected suites
with zero failures and zero stderr: large-world-rendering485, local-navigation183,
wellspring-map895, hex-collision-topology1432, hex-snapshot-optimization773,
wellspring-illustrated-kit2641 and sanctum-campus-layout40241 assertions.
The frozen old-domain collision oracle remains unchanged; expanded-domain
acceptance is tested separately. Full qualification remains a separate gate.

The legacy-art focused run also passed both suites (pixel-map-library7921 and
natural-map-kit81 assertions), zero failures/stderr. Its repaired expectations
test actual native chunks and read-only material queries; they no longer demand
a world-sized ground texture. A subsequent proposed architecture-kit fixture
change was based on an incorrect reading of the new landmark ID as its kind.
The actual tideglass-beacon kind is the already-supported attunement_spire.
The proposed test failed three assertions and was withdrawn; the exact original
live-campus test was restored. Both candidate and restoration hashes are retained.

Map native v1 stopped on an untyped command-array error in its harness. Correcting
that call to Array[SimCommand] changed no gameplay code. Map v2 then passed5531
checkpoints through1656 ordinary simulation steps and22 images, all individually
reviewed. Teaching v5 passed125 checkpoints/1516 steps and24 reviewed images.
That review exposed unnecessary empty panel height: the introduction now measures
its current bound text, and the testing panel's maximum height is520px instead
of620px, retaining the existing508px small-window layout. Fresh teaching evidence
is required after those changes. Cold map capture intervals also motivated a
separate exact-output terrain lookup optimization before final qualification.

The final UX focused run passed large-world-rendering260234, spell-testing-tools34833,
natural-map-kit81, wellspring-illustrated-kit2641 and pixel-map-library7921 assertions.
Only the erroneous architecture test above failed; stderr was zero. The terrain
suite compares every132 regions/85840 callback centers against independent retained
algorithms and byte-compares ten native sample regions. The temporary broadphase
retains440 of17820 possible route candidates while preserving authored precedence,
absolute hex ownership and source pixels. Native timing remains a separate gate.

Detailed mechanisms, established-game references and local design hypotheses:
[map and interface](../large-wellspring-evidence-20261009/map-overview.md),
[layout](../large-wellspring-evidence-20261009/layout-design.md) and
[environment rendering](../large-wellspring-evidence-20261009/environment.md).

## Element Garden qualification

[Garden design and authority](../large-wellspring-evidence-20261009/element-garden.md)
records 63 plots, six raw deposits plus all 63 recipe cycles, isolated bounded
courts, actual finite material lifecycles and the thirteenth map destination.
The forecourt label is separate from the full district-sized plot bounds.
The [focused v2 receipt](../large-wellspring-evidence-20261009/garden-focused-v2.json)
contains four passing suites / 112,746 assertions and zero stderr.

[Full v3](full-v3-interrupted.json) ended after 79 suites without a completed
Full receipt; it is not a pass. The [recorded native review](native/final-review.json) now verifies 96 images and 143 source-hash entries for `p60-6d80c3bce71e`: 42 map/region/garden images, including 16 garden frames and two paid-ground overlap views, plus 24 teaching, six camera, eight wallrun and sixteen delivery images. Full v6 and exact portable verification passed for the final source.
The [76-image pre-garden receipt](native/pre-garden-review.json) remains historical.
The 69.9% cold-terrain reduction measured eight arrivals with 22 unchanged
pre-garden images; it does not measure the final garden workload.

[Full v4](full-v4-interrupted.json) was stopped before suites after native
review found the Garden card overlapping the selected plot near a map edge.
The card now switches sides to keep that plot visible. The
[placement-focused run](../large-wellspring-evidence-20261009/garden-placement-focused.json)
passed 67,190 assertions with zero failures and zero stderr, including all 69
inspection states and sampled positions at both window sizes. This correction
prompted fresh native review and an attempted Full v5 run; neither interrupted
run is counted as a pass.

## Full v5 timeout, fixture correction and bounded supervision

The [Full v5 receipt](full-v5.json) is **failed**, not partial qualification.
Its 1,200-second suite watchdog ended the process after **216 of 237 suites**
and **6,259,369 assertions**. The sole recorded assertion failure was
`hex-playground-panel`: 175 failures from a fixture still clicking the removed
Matrix shortcut. The panel never opened, so its later modal/quarantine checks
cascaded. The test now follows actual Viewport → Menu → Chemistry demos input,
retaining all ten press/release/echo cases, actor/preferences checks and paid-hold
quarantine. No production behavior changed for that repair. Zero stderr does
not erase those failures. The 120 Hz startup gate was not reached.

The 216 recorded `SUITE TIMING` values sum to **1,171,530 ms**; the final twenty
completed suites account for 11,683 ms, ending with `session-snapshot` at 612 ms.
This accounts for most of the suite budget and supports a larger finite rerun
allowance. It does not prove the next unfinished suite was healthy, rule out
slow or stalled work, or justify combining this failed run with a selected tail
into a Full pass. The receipt's 1,432,302 ms total includes other gate work and
must not be mislabeled as the suite's 1,200-second deadline.

The next Full run retains all **237 suites** and every original assertion/error,
warning, import, identity, isolation and startup gate. Only its suite watchdog
in `scripts/test.ps1` increases to **1,800 seconds**. The shared checked-engine
parameter ceiling in `scripts/flux2-common.ps1` was also raised from 1,200 to
1,800 so that argument can be admitted; its default remains **180 seconds**.
Focused, import and boot defaults remain unchanged. The watchdog still kills
its owned child and reports failure at its deadline. The explicit tail/menu
probe is diagnostic evidence only; completion of a fresh unfiltered Full v6
remains required. Neither the larger watchdog nor a completed test suite is a
simulation frame-time budget, sustained-performance result, or proof of health.

## Evidence boundaries

The [22-suite tail diagnostic](tail-diagnostic-v1.json) completed all selected
assertions after Full v5's timeout, including the corrected 1,352-assertion menu
fixture, but the wrapper rejected 2,889 bytes of texture-open stderr. The nymph
preview source and exact imported cache were subsequently found intact with
matching import hashes and unchanged historical timestamps. No test deletion,
resource-pack mount or cache replacement was found. The underlying open failure
is unexplained; neither assertion success nor the source-image fallback turns
that diagnostic into a pass. The [fresh-process catalogue diagnostic](catalog-access-focused.json)
subsequently passed four suites / 1,728 assertions with zero failures and zero
stderr. The [complete Full v6](full-v6.json) then passed all 237 suites / 6,615,478
assertions, including those catalogues, with zero failures and zero stderr.
These clean reruns do not establish the underlying cause of the earlier open error.

Automated admission and conservation tests establish bounded mechanics, not
equal competitive viability or player enjoyment. Native images establish the
sampled rendering, not physical input feel or sustained performance. The
integrated challenge integrity journey suppresses rival commands deliberately
to isolate reward refusal after developer use; it does not beat all 30 AI rivals.

Human learning, fun/balance, continuous-motion readability, dedicated animation
art, dense sustained 120 Hz, and physical two-PC/different-home networking remain
separate product acceptance gates. The current historical performance scripts
are explicitly labeled; their p59 oracles cannot qualify this schema.

No commit, push, public deployment, account change or destructive cleanup is part
of this local implementation. The historical FLUX `current-checkpoint.json`
pointer remains unchanged. Current launch instructions belong in the README;
old receipts and design decisions retain their explicitly named historical scope.

## Final qualification and delivery

The [corrected garden placement-focused v2](../large-wellspring-evidence-20261009/garden-placement-focused-v2.json)
passed 67,190 assertions with zero failures/stderr. Its font/height oracle uses
the actual Bootstrap minimum UI scale 1.0 at 960x540, replacing the earlier
incorrect 0.75 assumption. All 69 inspection states and real field lifecycles
remain covered; the correction changes a test oracle, not production behavior.
The original focused receipt and both interrupted Full runs remain historical.

The [fresh Full v6 receipt](full-v6.json) passed **237 suites and
6,615,478 assertions**, zero failures and zero stderr, with clean import,
current scope/asset checks, post-import identity validation and 120 Hz-configured
startup. It ran the complete registry with no inherited suite filter. This is
behavioral regression, not a measured 120 Hz performance result. Its suite
watchdog is a bounded 1,800 seconds; import/boot defaults remain 180 seconds.
The complete unfiltered registry, zero-failure/stderr checks and owned-child
timeout failure remain required. This longer test allowance does not establish
healthy or performant gameplay. The failed [Full v5](full-v5.json) remains
separate evidence: 216 suites, 6,259,369 assertions, 175 obsolete-fixture failures
and the earlier 1,200-second timeout; it is not combined with tail diagnostics.

The [final native review](native-review.md) covers 96 images with
exact source and pixel hashes. The teaching journey passed 125
checkpoints / 1,516 real simulation steps. The enlarged-world journey
passed 6,766 checkpoints / 1,912 steps and captured 42
images of the compact Menu, both map pages, four new district arrivals and Element Garden phases
(16 garden frames, including 2 real paid-ground overlap views),
at two sizes. All thirteen travel destinations were exercised. Arrival images
do not establish full district traversal or every landmark's visual acceptance.

The [portable receipt](../../exports/hex-element-expansion-20261009/receipt.json)
and [independent archive verification](portable-verification.json) establish
native startup/safe close, 30 pixel/action admissions, the exported 504-spell/63-reaction
contract, 9 unique payload checksums, and all 10 decoded ZIP
members matching disk. The complete runtime source identity also passed after
export. The archive is 121.9 MiB.

- Build: `p60-6d80c3bce71e`; protocol 60, SessionSnapshot 24, chemistry/world schema 5.
- Runtime source SHA-256: `6d80c3bce71e9d7eb0fe9246f5f440d304da77f779edfc4054a965732b806e61`.
- PCK SHA-256: `09471becff639270e630b2a1bd8ad9b4e830fc54317ad89caa95a7a6266b8368`.
- ZIP SHA-256: `738f979ebfa5375493ab998c04e52fa468521d69de5adc7f95e6ea666e678208`.
- [Play current build](../../exports/hex-element-expansion-20261009/windows/PLAY-HEX.cmd).
- [Portable ZIP](../../exports/hex-element-expansion-20261009/HEX-p60-6d80c3bce71e-Windows-x64.zip).

Current documentation now separates the executable specification, player guide,
single queue, short resume and evidence. Two obsolete element contracts and four
older continuation/backlog entries point forward; their original bytes and older
qualification remain archived. The historical FLUX pointer and p59 packages are
unchanged. No public release, commit or deployment was performed.
