# H.E.X. documentation map

Status: **active development, October 13, 2026**, on
codex/hex-screen-smoothness-20261011. The [active iteration](iteration-20261013/README.md)
owns current source and qualified portable **p61-500be306a26a**. Full, fresh
package/archive, exported terrain and the normal-close lifecycle repeat pass.
The [independent review](iteration-20261013/delivery-review-500be/review.json)
reconciles 3,784 checks, including 265 Full suites / 7,572,978 assertions with
zero failures/stderr and 120 Hz boot. The sustained foreground stress gate stays
open; its last setup expired without Start. The earlier **p60-1e084a50a029**
[portable and qualification](iteration-20261012/README.md) remain preserved.

Use the [current launcher](../exports/hex-iteration-20261013-500be/windows/PLAY-HEX.cmd)
or [Windows x64 ZIP](../exports/hex-iteration-20261013-500be/HEX-p61-500be306a26a-Windows-x64.zip)
(161,186,435 bytes; 153.7 MiB). These local binaries are excluded from Git.
The [foreground record](iteration-20261013/foreground-500be-allsteps/review.json) passes
admission but does not establish sustained 60 FPS. The
[resume](../.agent/HEX-RESUME.md) owns exact identities; the
[single queue](../.agent/OVERHAUL-IMPLEMENTATION.md) owns deferred work.
The [T7 patch archive](iteration-20261012/deferred-t7/README.md) preserves the reviewed
proposal now applied to the qualified p61 portable; it is outside the p60 fallback.

Previous [be680](smoothness-20261012/README.md),
[845f](implementation-20261012/README.md) and
[d8](audit-implementation-20261011/README.md) records and portables are preserved.
Their checks qualify their original bytes. The 845f record owns its 196 UI
captures; current Garden/animation comparisons have their own narrower scope.

Start with the document that owns your question. The repository retains older
designs, experiments and release receipts, but they do not override the current
contract or qualify a newer build.

| Need | Authoritative document |
|---|---|
| Current implementation, reviews and qualification | [October 13 iteration](iteration-20261013/README.md); [preserved qualified checkpoint](iteration-20261012/README.md); [preceding comprehensive implementation](implementation-20261012/README.md) |
| Current design goals, implemented capabilities and acceptance gaps | [Game design overview](CORE-GAME-DESIGN.md) |
| Earlier presentation implementation, cross-reviews and recorded checks | [October 11 presentation checkpoint](presentation-checkpoint-20261011/README.md) |
| Run from source, build, and local portable paths | [Project README](../README.md); [development guide](DEVELOPMENT.md) |
| Source publication and repository cleanup | [October 11 publication record](source-publication-20261011/README.md) |
| Current performance qualification and earlier measurements | [Current source foreground review](iteration-20261013/foreground-500be-allsteps/review.json); [current attribution and limits](iteration-20261013/technical.md); [prior portable source record](iteration-20261012/foreground-current-record.json); [preceding measurements](smoothness-20261012/performance.md); [historical diagnosis](performance-assessment-20261010/assessment.md) |
| Controls, first session, mixtures, learning and testing | [Player guide](PLAYER-GUIDE.md) |
| Larger world, compact Menu and thirteen travel destinations | [Player guide](PLAYER-GUIDE.md#find-a-place-and-travel); [map decisions](large-wellspring-evidence-20261009/map-overview.md); [layout](large-wellspring-evidence-20261009/layout-design.md); [environment](large-wellspring-evidence-20261009/environment.md) |
| Physical ground fields for every ingredient set | [Visit the Element Garden](PLAYER-GUIDE.md#walk-the-element-garden); [garden design and evidence](large-wellspring-evidence-20261009/element-garden.md) |
| Current rules, boundaries and architecture | [Specification](../SPECIFICATION.md) |
| Exact current source/package identity and measured limits | [Resume handoff](../.agent/HEX-RESUME.md) |
| Current task and remaining qualification when work resumes | [Single implementation queue](../.agent/OVERHAUL-IMPLEMENTATION.md) |
| Current elemental deliveries, progression and testing | [Specification](../SPECIFICATION.md); [decision record](element-expansion-evidence-20261009/progression-testing-design.md) |
| Preceding six-element and movement checkpoint | [Historical refinement contract](SIX-ELEMENT-DYNAMIC-REFINEMENT.md) |
| Slower animation, jump/flight poses and protection readability | [Current experience implementation and evidence](implementation-20261012/experience.md); [earlier animation follow-up](reference-refinement-evidence-20261009/animation-followup.md) |
| Why a design was chosen and what its reference actually supports | [Current design basis](implementation-20261012/README.md#design-basis-and-acceptance); [Design principles and adaptations](../SPECIFICATION.md#reference-game-adaptations); [expansion decisions](element-expansion-evidence-20261009/integration.md); [historical identity/movement foundations](REFERENCE-IDENTITY-REFINEMENT.md) |
| Every ancestry and character perk | [Identity field guide](IDENTITY-PERKS.md) |
| What balance means and what remains unproven | [Balance contract](HEX-BALANCE-CONTRACT.md) |
| Reproduce a playtest | [Playtest route](HEX-PLAYTEST.md) |
| Executed checks, failures, corrections and limitations | [Current October 13 checks](iteration-20261013/README.md); [preserved October 12 checkpoint](iteration-20261012/README.md); [preserved d8 audit](audit-implementation-20261011/README.md#qualification); [earlier checkpoint](presentation-checkpoint-20261011/README.md#validation); [previous performance qualification](performance-implementation-20261010.md); [preserved expansion record](element-expansion-evidence-20261009/integration.md); [map evidence](large-wellspring-evidence-20261009/map-overview.md); [preserved animation qualification](reference-refinement-evidence-20261009/animation-followup.md) |

## Current vocabulary

The playable elements are **Water, Fire, Air, Earth, Light and Dark**. Ice is
derived from Water; Charge is derived from Fire. Every nonempty set of these
ingredients can be delivered in eight forms: 63 × 8 = 504 spells,
with twelve equipped positions. The preserved p59 package has the earlier 24.
Chemistry has 63 outcomes: six self-pairs,
15 distinct pairs, 20 triples, 15 groups of four, six groups of five and one
all-six combination. There are 30 playable profiles and 21 ancestries, each with
its own situational passive through the existing controls.

Thirty signature spells are earned through clean rival victories. The Range
temporarily permits all spells; developer overrides do not grant earned progress.
All 30 sandbox characters are already available. The optional introduction is
skippable and observes real actions rather than spending or equipping for the player.

Wellspring's implemented map has seven districts and thirteen named destinations.
During free play, Esc, controller Back or the single Menu button opens contextual navigation;
M opens the world map, and F4 opens the Compendium. Start remains the gameplay
emote. Offline travel preserves resources, spell cooldowns and the weave;
it requires free exploration and a currently safe arrival. The four new regions
are Tideglass Quays, Verdant Reaches, Basalt Foundry and Starward Terraces.
Element Garden in Tideglass adds 63 physical plots: six alternate raw/self
cycles and 57 mixed cycles show six raw materials and all 63 recipe identities.
The exhibits are harmless and bounded; player spells remain live.

Reading layouts support up to 200% text, including Gallery and Compendium.
Their compact Options view opens with O, pointer or controller Back; Back
returns to reading and B closes. The ingredient picker visibly marks its focus.
The [experience ledger](implementation-20261012/experience.md) preserves earlier
196-frame native captures, the failed Full attempts, and the subsequent 13-suite
repair pass of 1,967,421 assertions. The final selected/comparison spell names and
Aim cue label passed their final four-suite / 185,185-assertion focused gate and
refreshed 196-frame native capture. Physical
input and first-time comprehension remain separate acceptance work.

`wind` remains Air's internal identifier. Historical Ice/Charge wire IDs and
eight-style artwork are retained for explicit migration or archive-art checks;
their presence in a file does not make them selectable ingredients. The archive
36-reaction atlas is separate from the live 63-reaction simulation.

## Evidence and history

The earlier presentation checkpoint records a Full attempt with two outdated
sight assertions failing, followed by a corrected focused run. Combined coverage
is **247 suites / 7,051,951 final assertions**, with zero remaining failures;
it is **not a clean Full rerun**. Its Linux native fixtures establish their
sampled rendering only. The preserved d8 audit has separate Windows native UI,
character and gameplay measurements in its [record](audit-implementation-20261011/README.md).
The [October 12 implementation record](implementation-20261012/README.md) owns
current source checks and qualification. Clean Full and final focused/native UI
checks and separate package/terrain/lifecycle gates passed for `p60-845f85b5253e`.
The lifecycle fixture retained the same isolated preferences, recorded five normal
closes with empty stderr, and accepted 12 paid Fire and 12 paid all-six Mantle
casts with no refusals. It does not test physical input, earned progression,
damaged-save recovery, replay export or FPS. The subsequent
[smoothness measurements](smoothness-20261012/performance.md) have a qualified
845f baseline and qualified full/light-observer runs on the intermediate
`p60-46fca721f60d` source. The slower isolated ground-rendering experiment was
subsequently withdrawn; those runs do not qualify final source
`p60-be680e20d70e`. Its [clean Full regression](smoothness-20261012/full-final.json)
passed, while its foreground attempt expired before Start and produced no
gameplay measurements. Measured improvements do not yet establish sustained 60 FPS. Retained campus
drawing remains an opt-in `--retained-campus` experiment; these immediate-renderer
results do not qualify it.
Physical input/listening acceptance remains separate. The
[resume](../.agent/HEX-RESUME.md) and [single queue](../.agent/OVERHAUL-IMPLEMENTATION.md)
keep the current state and next checks together.

The final October 10 performance source passed Full v5: **244 suites / 6,880,581
assertions**, with zero failures and stderr. Its final field-rendering pass matched
**614 exact RGBA comparisons**, including actual overlapping paid fields and glow.
The earlier 541 material/HUD and Range comparisons retain their separate evidence.
The final portable passed exact archive and terrain checks and four visible-window
measurements. The October 10 performance report owns those previous source and
portable measurements, their distinct scopes and remaining frame-time limits.

The preceding October 9 Garden/expansion run passed 112,746 focused assertions;
its Full v3 was interrupted and Full v6 passed 237 suites. Its 96-image native
review and package qualification remain historical evidence for that older
build. The earlier 76-image review and 69.9% terrain interval reduction are
explicitly pre-Garden evidence.

- A source change is implemented when its code exists. It is qualified only by
  the completed checks recorded for that source. A failed, interrupted or
  partially selected run is never a completed Full pass.
- A native capture proves the sampled rendering after visual inspection. It
  does not establish physical input feel, human balance or sustained frame time.
- A local Windows export is a local playtest artifact. The player guide records
  its launch path and limitations; export alone is not a public release.
- `current-checkpoint.json` is the preserved **September FLUX delivery pointer**.
  Its name is historical. It is not the current H.E.X. launch recommendation;
  use the player guide and resume handoff above.
- Dated checkpoint documents, `archive/`, historical evidence and `.agent/archive/`
  retain earlier decisions and failure records. Former plans link forward to
  the single implementation record. Do not restart them as parallel work queues.
- Redundant backlog, continuous-entry and visual-gate redirects were removed on
  October 11; the still-linked cast-continuation redirect remains. Their
  [exact archived copies and receipt](../.agent/archive/element-expansion-20261009/archive-receipt.json)
  retain history without importing obsolete build IDs, paused states or quota
  cutoffs. `.agent/memory.md` remains an untouched historical project journal;
  the current resume owns active state.
- The former [eight-element reaction contract](ELEMENT-REACTIONS-FIRST-EIGHT.md)
  and [first-eight delivery contract](SPELLCASTING-DELIVERY-FOUNDATIONS.md) now
  forward to byte-preserved archive copies. They retain provenance, not active rules.

## Maintaining the project

Update the specification when the contract changes, the player guide when a
player-facing action changes, and the integration evidence when checks execute.
Keep work status in the single queue and source/package status in the resume.
Preserve user changes, original art, known working packages and failed-run
evidence. Do not copy a historical pass onto a changed source identity.
