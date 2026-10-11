# Wellspring map overview

Status: **implemented and locally qualified in p60-6d80c3bce71e, October 9, 2026.**
The [final integration record](../element-expansion-evidence-20261009/integration.md)
links the passed Full/native/package gates. Native map images inspect arrivals,
menus, map pages, garden phases and paid-ground overlaps; they do not establish human wayfinding or full district art acceptance.

## Design evidence and limits

| Decision | Established primary example | H.E.X. transfer and limit |
|---|---|---|
| Select a named place on an overview, then explicitly travel | Bandai Namco's [Elden Ring 101 introduction](https://en.bandainamcoent.eu/elden-ring/news/elden-ring-enter-the-lands-between-101-trailer) describes map-assisted navigation, markers and fast travel to known checkpoints. | Thirteen authored campus arrivals are available in a training world. Selection only highlights; a separate Travel action returns a destination ID for authority validation. H.E.X. deliberately has no discovery grind or checkpoint-rest rewards. |
| Show spatial landmarks and one useful reason to visit | The official [Elden Ring gameplay overview](https://www.bandainamcoent.com/news/elden-ring-introduction-part-3-gameplay-overview) relates different map icons and recognizable terrain shapes to distinct activities. | The overview draws actual district bounds, routes, buildings and arrival points; the selected destination has one authored contextual sentence. Shared district colors correspond to the actual world renderer and confer no combat effect. |
| Keep this enlarged practice world navigable without a persistent cluster of buttons | The same primary examples use the map as a consolidated navigation surface; the user's explicit request calls for extremely compact, nonredundant UI. | One compact Menu leads to Map and existing services. Destination names appear once in a paged list, with matching numbered pins. Eight rows, actual 14 px text and a separate player diamond are local layout hypotheses subject to native review. The sources do not establish those exact sizes or prove faster learning. |

These are documented shipped techniques in an established game, not empirical
causal evidence for H.E.X. navigation quality, player preference or balance.

## Authority and interaction

`WellspringMapModel` deep-copies the validated campus destination metadata. It
converts player fixed coordinates once, resolves the smallest containing
activity area, and produces only `{action: travel, destination_id}`. It never
teleports, refills, equips, advances time or writes preferences/progression.
Bootstrap's navigation controller owns current eligibility and a second lookup
of the trusted arrival point at execution time. Refusal text is visible inside
the map and survives unchanged eligibility refreshes.

Pointer selection on a row or pin is inspection only. Enter/A or the Travel
button explicitly requests the selected destination. Arrows/D-pad and one
selection per deliberate stick tilt navigate; page controls reach the remaining
destinations. Escape/B closes. Root must consume all modal input, including
releases, and apply the existing gameplay handoff guard.

Controller Back now opens the compact Menu directly in free exploration; F4
remains the direct Compendium key. This intentional navigation consolidation
gives controller users the same service menu without adding another widget.
Esc or the single Menu button opens that menu too; M opens the overview directly
when it is not a saved gameplay binding. Challenge exit behavior is retained.
The Compendium retains its read-only behavior. Its Map button, M, and L3 produce
a one-use routing request that Bootstrap consumes. Existing Y detail paging and
the gameplay Start/emote binding remain unchanged.

Current implementation: [read-only model](../../src/app/wellspring_map_model.gd),
[map panel](../../src/presentation/wellspring_map_panel.gd),
[navigation and travel authority](../../src/app/local_navigation_controller.gd),
and [Compendium routing](../../src/presentation/player_compendium.gd).
The [map suite](../../tests/unit/test_wellspring_map.gd) and
[navigation suite](../../tests/unit/test_local_navigation.gd) cover their separate
contracts. [Player controls](../PLAYER-GUIDE.md#find-a-place-and-travel) are the
player-facing reference; this design note does not qualify a package.

## Coverage and remaining gates

The completed `.godot/wellspring-expansion-focus-v4/engine.log` records:

| Suite | Assertions | Failures |
|---|---:|---:|
| `large-world-rendering` | 485 | 0 |
| `local-navigation` | 183 | 0 |
| `wellspring-map` | 895 | 0 |
| `hex-collision-topology` | 1,432 | 0 |
| `hex-snapshot-optimization` | 773 | 0 |
| `wellspring-illustrated-kit` | 2,641 | 0 |
| `sanctum-campus-layout` | 40,241 | 0 |

All seven selected suites passed, totaling 46,650 assertions; its
`engine.log.err` is zero bytes. This is a focused pass, not Full or package
qualification. The preceding `.godot/wellspring-expansion-focus-v3/` run had
three stale assertion failures and 468 bytes of malformed-JSON stderr. The
invalid-file refusal test now uses the loader's quiet parser; malformed content
remains rejected. Both failed outputs are preserved.

Earlier `.godot/wellspring-navigation-focus-v2/engine.log` records these individual
passes; `engine.log.err` is zero bytes:

| Suite | Assertions | Failures |
|---|---:|---:|
| `wellspring-map` | 895 | 0 |
| `player-compendium` | 7,852 | 0 |
| `spell-testing-tools` | 34,537 | 0 |
| `local-navigation` | 182 | 0 |
| `hex-world-definition` | 416,316 | 0 |

The same run's `sanctum-campus-layout` suite recorded 40,227 assertions and four
failures: old canvas width/height, old obstacle count, and an old contextual-copy
source assertion. Its failed receipt remains evidence; these five passing suites
do not turn that run into a passing aggregate or qualify a native/exported build.

The `wellspring-map` suite covers content-derived identities, current activity,
fixed-coordinate conversion, source immutability, requests without arbitrary
coordinates, disabled travel, input parity and stick release thresholds. It
checks all thirteen names/details against actual font metrics at 960×540,
1024×768, 1280×720, 1600×900 and 1920×1080, plus true aspect ratio, distinct pins,
shared pointer geometry and Compendium request consumption. Root owns actual
travel authority tests; movement owns safe authored arrival/route validation.

Independent layout/model review found no concrete static blocker. For the
pre-garden twelve arrivals, the closest marker centers are 26.004 px apart at
960×540 and 38.339 px at 1280×720. Painted markers are 22 px across, so none
overlap; the smallest visible gap is 4.004 px. Two 28 px pointer hit discs overlap
at 960, resolved by nearest center rather than first matching row. This geometric
check alone does not establish text readability; the final native review below
qualifies only the sampled images.
An isolated Range scene uses “Away from Wellspring” and no campus player marker.

The teaching native harness now enters Introduction, Range and Challenges by
clicking the actual Menu and matching action row. It completes the ordinary
zero-delta Bootstrap handoff frames before opening the next menu, records the
new navigation/map/layout/renderer source hashes, and preserves the existing
paid-cast, saved-weave, refusal/retry and tainted-victory assertions. This remains
scripted native UI evidence, not physical input or human acceptance.

The separate map journey's 22 images sample compact menus, map pages
and arrivals in the four new districts at two window sizes and both effects
settings. It does not inspect every landmark or fully traverse each district.
Final-source execution and pixel review passed; the exact v3-to-v2 equivalence
and final receipt are recorded below.

## Final compact UI and terrain follow-up

The later `.godot/wellspring-final-ux-focus-v1/engine.log` passed
`spell-testing-tools` with 34,833 assertions and `large-world-rendering` with
260,234 assertions. Natural map art, illustrated art and pixel-map library
checks also passed. That aggregate run still failed three assertions in a
mistaken architecture-test candidate; its stderr was empty. The candidate was
withdrawn, and the exact original architecture suite then passed 133 assertions
with zero stderr in `.godot/wellspring-architecture-original-v1/`. These are
separate scoped results, not a combined Full pass.

Native teaching v5 had passed 125 checkpoints, 1,516 simulation steps and 24
individually reviewed images. Review then identified unnecessary empty space.
The introduction now measures its current wrapped text with the real font,
keeping the reading anchor and shared Skip hit/draw geometry; it reserves eight
pixels after the text and twelve below Skip. Range's maximum height is 520px;
its existing 508px height at 960×540 is unchanged. Actual-font checks retain all
504 spell explanations, seven list rows, both default/longer bindings and every
lesson state. Independent combat and movement reviews found no concrete blocker.
Teaching v6 subsequently passed and qualified the sampled changed geometry.

Map v2 completed 5,531 checkpoints, 1,656 simulation steps and 22 individually
reviewed images. Its earlier harness-only untyped-command failure is preserved.
The subsequent terrain sampler reduces candidate route/area scans per region
while retaining exact classification and sampled native pixels; [environment
evidence](environment.md#compact-ui-and-cold-region-follow-up) records its tests.
Map v3 subsequently passed for its pre-garden frozen source. Camera v3 independently
passed 44 checks with six images identical to previously inspected v2 pixels.
Neither result establishes every landmark, full district traversal or sustained
performance.

## Historical pre-garden native result and measured comparison

The [historical pre-garden native review](../element-expansion-evidence-20261009/native-review.md)
and [receipt](../element-expansion-evidence-20261009/native/pre-garden-review.json)
record 76 reviewed images and 141 verified source hashes for `p60-6bf50929aa6c`.
Teaching v6 passed 125 checkpoints/1,516 steps: nine changed images were
individually viewed and fifteen match previously viewed v5 pixels. Map v3 passed
5,531 checkpoints/1,656 steps; all 22 images exactly match individually reviewed
v2 pixels. Camera's six images also match v2; wallrun's eight and delivery's
sixteen retained images have reverified hashes. Saved bytes and travel resource,
weave and cooldown invariants passed their scripted journey checks.

The [terrain comparison](terrain-optimization-comparison.json) records eight
first-arrival normal views before and after the region sampler: mean capture
settling fell from 2,449.625ms to 737.75ms, 69.9% lower. Eight subsequent cached
views averaged 94.625ms afterward. These sequential local intervals include four
frames plus forced draw/readback; they are not FPS or sustained frame-time
measurements. Cached views also used Reduced Effects, so the comparison does
not isolate an effects-setting benefit. Pixel equality covers these 22 samples;
human wayfinding and complete district traversal remain untested. Full and portable qualification passed; the final integration record links their separate receipts.


## Element Garden follow-up and current gates

[garden focused v2](garden-focused-v2.json) passed four suites / **112,746 assertions**, with zero failures and zero stderr (66,360 exhibition, 993 map, 2,643 illustrated kit and 42,750 layout).

[Element Garden](element-garden.md) adds 63 physical plots in Tideglass, ordered
by ingredient count and stable mask. Six plots alternate raw deposits with their
two-source self reaction; the other 57 show mixed reactions. Across those cycles
the garden presents six raw materials and all 63 recipe identities. Its bounded
61-cell courts use actual material and lifecycle rendering without exposing live
actors to exhibit damage. All visible plots are admitted; at most 63 courts
contain 3,843 cells. Real paid ground is drawn above harmless exhibit pads.

The thirteenth destination, `element-garden`, arrives at (4880,720). Its location
label uses the 288×288 forecourt at (4736,576); the full plot directory still
covers Tideglass. The 288px plot lattice preserves 160px clearance from existing
walls and at least 72px between pad outlines. All previous geometry and travel
records remain exact; the new forecourt contributes the twenty-fourth activity
and the thirty-fourth floor label. No resources, cooldowns or weave are reset.

The [Full v3 interrupted receipt](../element-expansion-evidence-20261009/full-v3-interrupted.json)
records 79 completed suites and zero stderr but no completed Full receipt.
The final native inventory passed: **96 images**, including 42 map/region/garden images (16 garden frames, including 2 real paid-ground overlap views), 24 teaching, six camera, eight wallrun and sixteen delivery images. Full v6 passed all **237 registered suites**; native review and exact portable verification passed separately.

The historical 69.9% reduction in cold arrival capture intervals belongs to
the **pre-garden 22-image** comparison. It neither benchmarks exhibition updates
nor certifies final garden frame time; each sample included four frames and
forced draw/readback. Keep it separate from the forthcoming garden capture.
