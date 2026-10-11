# Magic glow and movement flow

Status: source checkpoint verified; human playtest pending. Build
`p57-6d73bc53d52a`, 3,113 production records, protocol 57 / snapshot 23.
Runtime SHA-256: `6d73bc53d52a772cbf5d4bce52e1fa20572ac993ae549d7c464a36bfdae00691`.
Native review is partial keyframe acceptance, not a continuous-motion claim.

## Player-facing changes

| Change | Contract |
|---|---|
| Magic glow | Element-colored projectile cores, cast/contact accents and inset active-hex highlights; no lights, bloom, particles or expanded threat geometry |
| Character wakes | Short neutral pixel strokes behind actual displayed movement; stronger with speed/slide/dodge, no body ghosts, gameplay residue or projectile tails |
| Recovery chaining | A fresh Jump press in the final 100 ms of forced recovery can survive until legal control returns, like other buffered movement; no early admission, free action or shortened commitment |

The user explicitly requested movement trails again. The earlier blanket trail
ban is superseded for character presentation only. Existing M1–M3 movement,
resource, field-footprint and Steam fixes remain in scope for regression checks.

## Implementation boundaries

Wakes use the same displayed actor anchor as the body, including interpolation,
prediction correction and jump lift. Active pixel/wireframe heights are
58 / 63 / 68 px. Sampling is at most 40 Hz per actor, with eight tracks and six
segments per track, 120–180 ms lifetime and 16 px segment length. Current sight
checks cover the stroke interior; hidden/culled/respawned/teleported actors,
menus, Reduced Effects and long pauses clear history. No simulation state is
written by either presentation helper. Each segment has a dark edge beneath a
light core, capped at 96 draw submissions across all eight visible actors.

Normal projectile/cue glow is at most three small polygons; Reduced Effects
retains one dim core. Active-hex decoration is capped at 48 regions / 96 inset
polygons per draw and is disabled in Reduced Effects. Formation, expiry, holes,
zero intensity and essential warning/boundary cues remain separate. These
source bounds are not measured frame-time or dense-load acceptance.

## Validation ledger

| Gate | Result |
|---|---|
| Initial import | Passed, no stderr |
| Focused v1 | FAILED: all 15 suites had zero assertion failures, but the new surface glow used a draw-context-only API in the existing retained-surface path |
| Repair | Surface glow now uses the same retained RenderingServer submission approach as HexMaterialSurface; no validation was disabled |
| Focused v2 | Passed: 15 suites / 292,808 assertions / zero stderr; before final trail-contrast tuning |
| Native capture harness repairs | Movement v1 rejected an untyped command-array fixture; Magic v1 rejected hiding the main window. Corrected typed commands and minimized native SubViewport readback; failed logs retained |
| Native v3 visual review | Nine movement cases and 32 spells passed scripted capture; [review](visual-review-v3.json) rejected at-a-glance trail contrast despite correct cleanup/alignment. Dark/light strokes were strengthened without longer history |
| Initial Full attempt | INTERRUPTED after import/identity and partial suite progress to address native contrast review. Not counted as passing; [partial logs](interrupted-full/suite.log) preserved |
| Final native | Passed scripted capture on `p57-6d73bc53d52a`: [nine movement cases](movement-final/receipt.json), [32 paid spells plus active Fire](magic-final/receipt.json); 26 retained PNGs, no stderr |
| Final visual review | [Partial keyframe acceptance](visual-review.json): safe, aligned and restrained accents; walking wakes and Rapid release remain subtle. No claim of conspicuous trails, universal glow readability or continuous-motion acceptance |
| Actual movement-input journeys | Passed on final source: 12 routes / 7,547 checks; three sizes each for flight, double jump, dodge/fast-fall and wall actions |
| Full / import / source identity / configured 120 Hz boot | [Passed](full/receipt.json): 221 suites / 3,987,828 assertions, zero failures/stderr, isolated profile restored; [suite](full/suite.log) and [boot](full/boot-120.log) |
| Final documentation guards | Current-scope check, dependency-guard self-test (105 assertions), generated README pointer check, summary regression (45 assertions) and scoped whitespace check passed |
| Human feel, dense performance, physical Internet | NOT_RUN; existing acceptance limits remain |

Root owns all engines and integration. Three scoped workers handled magic,
movement wakes and recovery buffering, then cross-reviewed each other's work.
Source changes were frozen before each gate; failed evidence is preserved.
Original artwork, protected dirty edits and retained packages are untouched.
No export, installer, checkpoint promotion, commit, push or publication occurred.

Final native rendering used minimized root windows and forced SubViewport
readback of the production scene, not desktop screenshots. The root Window's
`visible` flag remains true; it is not described as a hidden-window guarantee.
The 26 retained images include two explicitly synthetic spell-helper boards.
Final spell images are byte-identical to the earlier reviewed set; all six
final movement images were directly reviewed after contrast tuning. Native
captures do not measure sustained frame time or physical input latency.

Cleanup removed only twenty byte-identical intermediate magic PNG copies from
`magic/`; its earlier receipt remains, and identical images are retained in
`magic-final/`. Earlier movement contrast images remain because they differ and
explain the failed visual review. All owned engines are closed and the engine
guard is released. No user assets, packages or unrelated dirty work were removed.

## Human check

From the repository, run `scripts\run.cmd --pixel-cast`. Compare walking,
sprinting and sliding with S. Wayne, Oh Tipi and Red Baron; trails should follow
travel, not aim, disappear quickly at rest and vanish in menus/Reduced Effects.
Try Bolt/Heavy/Rapid/Spray and compare normal/reduced spell effects. Glowing
material must not imply additional range. Practice Slide → tap Jump → air dodge
with direction changes: costs, momentum, legal commitments and cancellation
should remain predictable. The fresh late-recovery buffer needs human timing
feedback; static screenshots do not prove animation feel.
