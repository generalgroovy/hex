# H.E.X. game design overview

Status: **implemented design overview; qualified portable p61-d6d1bfb9c529.**
The [single queue](../.agent/OVERHAUL-IMPLEMENTATION.md) owns current work.
The [resume](../.agent/HEX-RESUME.md), [delivery pointer](current-delivery.json)
and [qualification](performance-evidence-20261014/stationary-qualification-d6d1/README.md)
own exact identities, checks and acceptance limits. Use the **H.E.X. desktop
shortcut** for player sessions. Preserve the immediate 6459 fallback and older
working builds. Current-build foreground performance and portable FPS remain
unmeasured; the [6459 diagnostic](performance-evidence-20261014/foreground-6459-b/review.json)
is historical.

The [October 15 product assessment](BREAKTHROUGH-ASSESSMENT-20261015.md) prioritizes
a coherent rival → earned signature → next encounter loop. The current source
candidate implements a three-rival Circuit using existing combat/reward authority,
with optional temporary learned-spell use. It is under validation and is not yet
the selected portable. The complete illustrated 2.5D overhaul remains a separate
proposal; player comprehension and voluntary replay still require observation.

The [October 15 overhaul design](OVERHAUL-DESIGN-20261015.md) covers the selected
illustrated 2.5D animated-sprite direction, clear area effects, tall architecture,
real interiors, learning and technical optimization. It is a cross-reviewed
proposal, not a description of changes already implemented. SPECIFICATION.md
continues to own executable gameplay rules.

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
| Smooth play on modest hardware | Bounded terrain residency and worker validation, interpolation, Low/Standard settings, exact Garden selection reuse, staged preparation during fast travel and the qualified stationary movement shortcut. Immediate campus drawing remains the default after moving-view measurements rejected the retained alternative | Current d6d1 foreground performance and portable FPS remain unmeasured. The previous-build 6459 instrumented source diagnostic and isolated stationary-step savings have their own scopes in the resume; neither establishes current smooth gameplay. Whole-workload frame pacing, observer calibration and memory pressure remain open. Full/package qualification is separate |

The [reference adaptations](../SPECIFICATION.md#reference-game-adaptations),
[combat decisions](element-expansion-evidence-20261009/combat-design.md),
[learning and testing decisions](element-expansion-evidence-20261009/progression-testing-design.md)
and [animation decisions](reference-refinement-evidence-20261009/animation-followup.md)
record established precedents, their H.E.X. translations and limits. The
[gameplay](iteration-20261013/gameplay.md),
[experience](iteration-20261013/experience.md) and
[technical](iteration-20261013/technical.md) ledgers record the current
adaptations, independent reviews and evidence. These references support design
choices; tests and content counts alone do not establish fun, balance or smoothness.

Earlier focused gameplay evidence includes 6,159 signature-progression assertions
for the joined route, 1,899 protected-contact assertions and 1,426 Range-scenario
assertions with empty stderr. The protected-contact correction observes a real
swept paid shot crossing during protection; it neither damages the actor nor
changes the shot's trajectory or strength. The preserved be680 source subsequently
passed 261 suites / 7,401,986 assertions and separate portable gates. The preserved
1e084 and 500be builds have their own clean Full and delivery receipts linked
from the iteration record. Subsequent edits require their own appropriate gates.

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
