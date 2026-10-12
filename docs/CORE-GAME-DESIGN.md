# H.E.X. game design overview

Status: **stable local October 12, 2026 build p60-1e084a50a029; work paused at the user's request.**
The [iteration record](iteration-20261012/README.md) contains the passed Full
(261 suites / 7,543,825 assertions, zero failures and stderr), matching portable,
terrain and five-case lifecycle gates. The current source also passed sampled
foreground admission; steady 60 FPS remains unachieved. Use the
[current launcher](../exports/hex-iteration-20261012/windows/PLAY-HEX.cmd).
The [be680 fallback](../exports/hex-smoothness-20261012/windows/PLAY-HEX.cmd)
and its [smoothness record](smoothness-20261012/README.md) remain preserved.
The [resume](../.agent/HEX-RESUME.md) owns exact identities; SPECIFICATION.md owns
the gameplay contract. Reviewed [T7 diagnostics](iteration-20261012/deferred-t7)
remain unapplied and outside this qualified build.

H.E.X. combines movement execution, aimed spell combat and finite elemental
terrain. Players learn a small set of actions, then express skill through timing,
route choice, countercasting and combinations.

The [current design contract](../SPECIFICATION.md) is the single authority for
scope and rules. The [player guide](PLAYER-GUIDE.md) explains controls; the
[balance contract](HEX-BALANCE-CONTRACT.md) separates implemented capabilities
from intended viability and uniqueness.

| Design goal | Current implementation | Remaining acceptance |
|---|---|---|
| Easy movement with expressive mastery | Independent travel/aim; finite paid chains, double jump or flight and real wall routes. Optional route cards explain open braking, wall release and combat re-entry using current costs; bounded command tests include real cover and return fire | Human control feel, route usefulness and clear wallrun reads during combat |
| Dynamic, readable bullet-hell pressure | Eight deliveries retain finite paid pressure. Rapid rivals use three 18-tick bursts separated by 30-tick committed-facing gaps; existing shots stay dangerous. Full encounters exercise all eight delivery policies | Encounter tempo, safe-route readability and useful favorable/unfavorable situations; scripted wins do not establish fairness or fun |
| Six useful elements and complete combinations | Water, Fire, Air, Earth, Light and Dark form 63 compositions across Bolt, Heavy, Rapid, Spray, Mantle, Fuse, Split and Rebound: 504 definitions, twelve equipped positions and six on-hit statuses. The shared Inspector compares actual cost/timing and qualified damage information. The current 23-case diagnostic includes paid led Split and legal ricochet hits with miss/blocked controls | All options must justify their cost and have a readable counter; bounded scenarios do not establish sustainable output or all-spell balance |
| Aggressive, situational chemistry | Bounded reactions cover self-pairs and every distinct subset through all six. A source-derived 63-recipe matrix exposes trigger, footprint, timing, counters and simpler-subset differences, including shared ground mechanics. Withered's ready-Flux denial is separated from ground recovery denial | Every recipe needs a useful situation and counterplay; unique names or ingredients do not prove distinct tactical roles |
| Distinct races and characters | Thirty playable identities, twenty-one ancestries and three sizes. All 51 passives have a prepared trigger case that measures an actual movement/resource/combat benefit; casting and inspection share effective-timing policy | Natural activation frequency, isolated contribution of paired passives and combined viability remain open; favorable prepared windows do not prove ordinary usefulness |
| Optional teaching and useful testing | Skippable basics and tactical outcome gates; all 504 spells testable in Range. Garden selection presets its exact mixture; optional Setup controls target motion, paid return fire, authored hurt size and statistics. Developer loaners remain separate from earned progress | First-time understanding and useful practice exercised by players; statistics describe that session rather than a balance ranking |
| Earned single-player progression | All 30 rivals remain selectable. An optional Rapid→Fuse→Rebound lesson route uses real Conservatory, Tideglass and Basalt courts. A joined paid fixture observes introduction, movement chain, mixed hit, protected crossing, three victories, saved rewards and learned releases | These are three lessons, not a complete campaign. Difficulty progression, varied longer runs and human learning transfer remain open |
| A larger, varied world with compact UI | Seven districts, thirteen map travel arrivals and 63 harmless Garden exhibits; optional district practice and authored map cues. Small-window/200% reading views retain selection and expose detail pages; mouse, keyboard and pad share compact actions | Human wayfinding and active-device transitions; native fit/navigation checks and source tests do not alone establish comprehension |
| More dimensional, readable characters and magic | Wall attachment/release use directional poses. Ground characters retain aerial tuck during casting; flyers keep flight bodies with independent hands. Actual protection cues, receiving-surface shadows and a bounded four-voice priority audio batch support feedback | Bespoke authored movement cycles, listening comfort and moving-combat readability remain open |
| Smooth play on modest hardware | Bounded terrain residency, interpolation, Low/Standard settings, exact Garden selection reuse and staged funded/visual preparation during fast travel. Immediate campus drawing remains the default after moving-view measurements rejected the retained alternative | The admitted 1e084 source has Garden/Fire/Mantle p95 engine intervals of 29.420/49.174/51.784 ms; steady 60 FPS remains unachieved. Full/package gates passed separately; smaller preparation peaks do not imply lower total work |

The [reference adaptations](../SPECIFICATION.md#reference-game-adaptations),
[combat decisions](element-expansion-evidence-20261009/combat-design.md),
[learning and testing decisions](element-expansion-evidence-20261009/progression-testing-design.md)
and [animation decisions](reference-refinement-evidence-20261009/animation-followup.md)
record established precedents, their H.E.X. translations and limits. The
[gameplay](implementation-20261012/gameplay.md),
[experience](implementation-20261012/experience.md) and
[technical](implementation-20261012/technical.md) ledgers record the current
adaptations, independent reviews and evidence. These references support design
choices; tests and content counts alone do not establish fun, balance or smoothness.

Earlier focused gameplay evidence includes 6,159 signature-progression assertions
for the joined route, 1,899 protected-contact assertions and 1,426 Range-scenario
assertions with empty stderr. The protected-contact correction observes a real
swept paid shot crossing during protection; it neither damages the actor nor
changes the shot's trajectory or strength. The preserved be680 source subsequently
passed 261 suites / 7,401,986 assertions and separate portable gates. The current
1e084 build has its own clean Full and delivery receipts above; future edits
require fresh qualification.

The **55.65 Fire / 46.74 all-six Mantle reported-FPS means** belong to the
historical `p60-d8e6ea1cd808` portable. Those finite October 11 workloads include
idle periods and do not measure the current candidate. Later d8 baseline attempts
failed the stricter foreground gate and cannot support a candidate speedup claim.

The [implementation record](../.agent/OVERHAUL-IMPLEMENTATION.md) separates
completed work from the current authorized task. Exact source/package identity
and measured limits live in the [resume](../.agent/HEX-RESUME.md).
The [pre-publication overview](archive/source-publication-20261011/CORE-GAME-DESIGN.md)
is retained exactly; its four-family spell description is superseded here.
The [earlier summary](archive/core-docs-20261007/CORE-GAME-DESIGN.md) is archived:
its FLUX title, seven families, fifty-seven spells and older roster are not current.
