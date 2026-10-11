# H.E.X. documentation map

Status: current documentation index, October 11, 2026. The optimized 504-spell
source and locally qualified portable are **p60-be3efd332e1a**. The October 10
performance implementation and qualification batch is complete; dense overlapping
fields still exceed the 60 FPS budget. Source publication excludes local binaries.
The resume owns exact source/package identity; earlier fallbacks retain their own evidence.

Start with the document that owns your question. The repository retains older
designs, experiments and release receipts, but they do not override the current
contract or qualify a newer build.

| Need | Authoritative document |
|---|---|
| Run from source, build, and local portable paths | [Project README](../README.md); [development guide](DEVELOPMENT.md) |
| Source publication and repository cleanup | [October 11 publication record](source-publication-20261011/README.md) |
| Performance changes, measurements and remaining limits | [Implementation report](performance-implementation-20261010.md); [historical diagnosis](performance-assessment-20261010/assessment.md) |
| Controls, first session, mixtures, learning and testing | [Player guide](PLAYER-GUIDE.md) |
| Larger world, compact Menu and thirteen travel destinations | [Player guide](PLAYER-GUIDE.md#find-a-place-and-travel); [map decisions](large-wellspring-evidence-20261009/map-overview.md); [layout](large-wellspring-evidence-20261009/layout-design.md); [environment](large-wellspring-evidence-20261009/environment.md) |
| Physical ground fields for every ingredient set | [Visit the Element Garden](PLAYER-GUIDE.md#walk-the-element-garden); [garden design and evidence](large-wellspring-evidence-20261009/element-garden.md) |
| Current rules, boundaries and architecture | [Specification](../SPECIFICATION.md) |
| Exact current source/package identity and measured limits | [Resume handoff](../.agent/HEX-RESUME.md) |
| Completed implementation and separate acceptance boundaries | [Implementation record](../.agent/OVERHAUL-IMPLEMENTATION.md) |
| Current elemental deliveries, progression and testing | [Specification](../SPECIFICATION.md); [decision record](element-expansion-evidence-20261009/progression-testing-design.md) |
| Preceding six-element and movement checkpoint | [Historical refinement contract](SIX-ELEMENT-DYNAMIC-REFINEMENT.md) |
| Slower animation, jump/flight poses and protection readability | [Animation follow-up](reference-refinement-evidence-20261009/animation-followup.md) |
| Why a design was chosen and what its reference actually supports | [Current expansion decisions](element-expansion-evidence-20261009/integration.md); [identity/movement foundations](REFERENCE-IDENTITY-REFINEMENT.md) |
| Every ancestry and character perk | [Identity field guide](IDENTITY-PERKS.md) |
| What balance means and what remains unproven | [Balance contract](HEX-BALANCE-CONTRACT.md) |
| Reproduce a playtest | [Playtest route](HEX-PLAYTEST.md) |
| Executed checks, failures, corrections and limitations | [Current performance qualification](performance-implementation-20261010.md); [preserved expansion record](element-expansion-evidence-20261009/integration.md); [map evidence](large-wellspring-evidence-20261009/map-overview.md); [preserved animation qualification](reference-refinement-evidence-20261009/animation-followup.md) |

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

Wellspring's candidate map has seven districts and thirteen named destinations.
Esc, controller Back or the single Menu button opens contextual navigation;
M opens the world map, and F4 opens the Compendium. Start remains the gameplay
emote. Offline travel preserves resources, spell cooldowns and the weave;
it requires free exploration and a currently safe arrival. The four new regions
are Tideglass Quays, Verdant Reaches, Basalt Foundry and Starward Terraces.
Element Garden in Tideglass adds 63 physical plots: six alternate raw/self
cycles and 57 mixed cycles show six raw materials and all 63 recipe identities.
The exhibits are harmless and bounded; player spells remain live.

`wind` remains Air's internal identifier. Historical Ice/Charge wire IDs and
eight-style artwork are retained for explicit migration or archive-art checks;
their presence in a file does not make them selectable ingredients. The archive
36-reaction atlas is separate from the live 63-reaction simulation.

## Evidence and history

The final October 10 performance source passed Full v5: **244 suites / 6,880,581
assertions**, with zero failures and stderr. Its final field-rendering pass matched
**614 exact RGBA comparisons**, including actual overlapping paid fields and glow.
The earlier 541 material/HUD and Range comparisons retain their separate evidence.
The final portable passed exact archive and terrain checks and four visible-window
measurements. The current performance report owns source and release measurements,
their distinct scopes, and the remaining frame-time limits.

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
