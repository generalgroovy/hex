# H.E.X. balance and distinctness contract

Status: current design contract, updated October 12, 2026; **not a claim of completed balance**.
The implementation queue remains `.agent/OVERHAUL-IMPLEMENTATION.md`.
[Historical October 7 fix/audit evidence](balance-evidence-20261007/README.md):
its Full and portable gates passed; native Loom information was readable at 1280x720,
but 960x540 small text was degraded in that historical build. The later
[comprehensive reading pass](implementation-20261012/experience.md) supplies
separate compact/200% native evidence; neither establishes complete balance.
The [current handoff](../.agent/HEX-RESUME.md) owns exact qualification and package
status. The [expanded combat record](element-expansion-evidence-20261009/combat-design.md)
and [progression/Range record](element-expansion-evidence-20261009/progression-testing-design.md)
describe the current expansion: **63 nonempty payloads × eight deliveries = 504 spells**,
six on-hit status channels, and 30 learnable signatures. Earlier six-element and
animation passes do not qualify these additions.

Every element, spell, ancestry and champion must earn its place. A legal option
must work independently, offer a recognizable decision, have a meaningful cost
or vulnerability, and remain understandable to its opponent. Synergies deepen
an already useful option; they must not rescue an otherwise useless choice.
Equal viability does not mean equal damage, identical play or mandatory 50%
win rates in every matchup. Cosmetic identity alone does not prove mechanical
uniqueness. A stat bound or a passing test is not a competitive power budget.

## Acceptance by layer

| Layer | Independent usefulness | Distinct decision | Required counter / evidence |
|---|---|---|---|
| Element | A single-element weave can fight using its direct attacks and self-reaction | Pressure, terrain, movement, information or approach niche | No unavoidable permanent denial; paid solo trial plus opponent escape/response |
| Spell | Useful with its own cost, startup, reach, aim and resource cycle | Precision, impact, tracking, interception, approach, delay, branching or bank-shot choice across eight families | One favorable and one unfavorable scenario at comparable resource expenditure; mixtures must justify their added cost |
| On-hit status | A finite follow-up opportunity after an actual damaging hit | Six bounded ingredient effects, independent of terrain reactions | Protected/zero-loss contacts apply none; no stacking slowdown, repeated free shove or infinite damage pool |
| Reaction | Every self/pair is useful without a third cast; larger combinations justify their additional paid setup | Outcome differs in action, geometry, timing or interaction, not just tint | Warning, exact whole-hex authority, phase limits, team/height policy and reproducible counter |
| Size | Small, Middle and Large remain viable | Speed/resource/hurtbox trade-offs | Same wall clearance; equal inputs and complete action tests; no animation-dependent hurtbox |
| Ancestry | No compulsory element or teammate to function | A readable horizontal capability, not a stack of free bonuses | Current flight versus double jump must be tested before new racial mechanics |
| Champion | A useful starter and a reason to choose the identity after customizing the weave | Authored silhouette plus an intelligible mechanical trade-off | No misleading unique-kit claims when stats/capabilities coincide; no silently forced affinity changes |
| Mode | Choices remain useful in Duel, Duos, Trios and FFA | Damage, cover and information can have different values by mode | Team-safe scoring, shared-hazard disclosure, mirrored starts, human opposition |

The Loom covers all 504 definitions, with 30 assigned signatures gated by their
rival victories. The original 24 spells remain available; the offline Range can
loan any definition without earning or saving it. Valid earlier saved signatures
keep their access. All 30 sandbox characters remain selectable. Affinities determine
starter selections, including the strongest/first Heavy; they do **not** discount
live Flux cost or multiply live spell damage. The historical catalog-active
point-discount validator is not a balance benefit for the twelve-slot weave.
Ancestry selects flight or double jump and one of 21 situational race passives.
Each character also has a personal passive, making 30 distinct personal
trigger/effect combinations. These now affect live play through the shared
identity policy; individual and combined balance remains an open playtest gate.
Existing names, affinities, art and stable wire IDs remain protected.

Keep implementation orthogonal: **size supplies the body/resource trade-off;
ancestry supplies a small readable capability; champion supplies identity and
an authored playstyle; element supplies material/chemistry; delivery supplies
the attack decision.** Compose 63 payloads with eight shared delivery rules; do
not write 504 unrelated spells or 30 separate combat systems. Shared family physics can be a useful
learnable grammar; the complete element-plus-delivery action must still earn
its place in a scenario. Do not invent extra rules solely to make every row
numerically different, and do not stack ancestry plus size plus champion bonuses
without accounting for their combined opportunity cost.

## Actual element niches and the intended emphasis

These are current source contracts and design targets. Every element has direct
attacks and one implemented on-hit status. A status requires positive actual
Health loss to a living, unprotected enemy; the hit and its paid cast own the
opportunity. Raw Fire is hazardous; other raw ingredients are setup rather than
damage fields by themselves. A singleton terminal deposits an ingredient; a
mixed terminal can form its named terrain reaction from its finite paid source.

| Element | Solo/self-reaction niche now | Emphasis to preserve / develop | Clear cost or counter |
|---|---|---|---|
| Water | Frostway's first contact damages and slows ordinary ground travel/projectiles; Water Spray launches | Timing and movement choice | Slide/air evade ground slowdown; leave the field; short Spray reach |
| Earth | Rampart creates destructible shot and movement cover | Reshape routes and create movement opportunities | Finite health/life, alternate angle, caster also blocked |
| Fire | Raw burn and Conflagration pressure; Fire/Air Arcstorm supplies derived Charge | Exposure, area denial and warned discharge | Shared self/ally burn, ignition warning, escape/cooling |
| Air | Vortex moves grounded actors tangentially | Route manipulation and spacing | Open center, jump/leave; no invented projectile redirection |
| Light | Radiance damages/reveals; optical combinations | Information pressure and readable precision | Finite zone/life; avoid pulses; no unimplemented heal/invulnerability |
| Dark | Larger Bolt, Umbral delayed pressure/concealment | Approach and occupation mindgames | Occupation delay, movement reveal and visible close silhouettes |

## Eight delivery choices and six on-hit effects

| Family | Decision to preserve | Cost or answer to demonstrate |
|---|---|---|
| Bolt | Focused aimed pressure | Travel time, aim and cover |
| Heavy | Deliberate impact and high reaction strength | Slower preparation/travel, large visible body, cover and height |
| Rapid | Frequent small tracking shots | Every shot pays; low strength and recovery downtime matter |
| Spray | Immediate close fan and interception | Short reach, clipped rays and low per-target damage |
| Mantle | Approach for touch damage while leaving finite paid trail pieces | 1.4 s lifetime, one touch per enemy, 16 Health shared direct pool; it is not armor |
| Fuse | Plant an area threat after travel | Full 600 ms warning, cover/height checks, 20 Health shared direct blast pool |
| Split | Commit to two diverging branches after ten flight ticks at 120 Hz (77 ms authored, rounded to 83.3 ms) | Splits once; divides the original direct damage and material; capacity can postpone it |
| Rebound | Use a wall angle to change approach | At most two banks; no homing, extra damage, material or lifetime |

Additional ingredients add 15% of the family's base Flux cost each, rounded
upward to a whole Flux. They do not multiply direct damage, strength or material.
Status duration declines from 1,000 ms for a singleton to 600 ms for all six.
These are tuning hypotheses. Compare equal paid expenditure and useful outcomes,
not just the number of ingredients or the largest theoretical hit.

| Ingredient status | Actual follow-up | Bound to countercheck |
|---|---|---|
| Earth: Fractured Focus | Future cast preparation is 8% longer | Does not retime an already paid cast or its cooldown |
| Fire: Burning | Damage from one finite pool | At most 2.4 Health from a hit; refresh replaces a pool rather than adding stacks; protection stops pulses |
| Water: Chilled | Ordinary ground target speed is 88% | Shares the stronger terrain/Chill reduction; separate timed control slows still apply. Air steering stays unchanged |
| Air: Gusted | One directional base 80 px/s shove when the window begins; active push-resistance/vulnerability passives scale that impulse | No stun; refreshing an active window cannot shove again |
| Light: Revealed | Makes the target available to visibility rules | Solid walls still occlude; no through-wall targeting claim |
| Dark: Withered | Blocks otherwise ready Health/Flux recovery | Stamina recovery and ordinary wait clocks remain separate |

Status damage creates neither further statuses nor matter. Terrain reactions have
their own published rules: for example, a Light–Dark compound can block all
resource recovery, while the Dark on-hit status blocks only Health and Flux.
All damaging reaction fields share finite funding across victims and descendants.

The [combat evidence](element-expansion-evidence-20261009/combat-design.md)
links the primary Magicka composition, Noita trigger/bounce and Gungeon rhythm
examples behind this structure. The [progression evidence](element-expansion-evidence-20261009/progression-testing-design.md)
links Mega Man's earned-enemy-weapon loop and Street Fighter's tutorial/training
separation. These examples justify techniques to test, not H.E.X.'s exact numbers
or a claim that all 504 choices are equally strong.

## Earlier audit findings

The following table records the October 7 pre-six audit and its follow-up fixes.
Its old spell counts, reaction roles and prices are historical; current effective
values come from compiled source and the new six-element reference.

| Finding | Source-grounded result | Consequence / response |
|---|---|---|
| Penumbra cadence defect | Projectile optical contacts overwrote the actor pulse clock | Remove that write; keep once-only optical masks; test 600 ms cadence, paid formation, allies/protection and snapshot continuation |
| Steam cooling defect | Adding paid Water matter could outweigh the old intensity reduction and increase realized scald damage | M2 bounds cooled intensity using exact integer per-cell pressure at every exposure level; preserve all matter, sources, footprint and expiry; require fresh damage and continuation tests |
| Underfunded sprint | A positive Stamina balance could grant a speed tick without covering its fractional debit | M2 requires the complete pending tick payment; refused held retries retain ordinary walking and recovery; no speed or rate rebalance |
| Spell delivery sameness | Eight Heavies, eight Rapids, seven Sprays and four Bolts share their respective direct delivery definitions | Chemistry may distinguish their value; identical delivery is not proof of independently unique spells |
| Reaction setup economy | Rapid pair costs 4 Flux, ordinary Bolt pair 12, Heavy pair 36; most non-core recipes retain authored payload/cover capacity regardless of matched strength | Test paid equal/unequal-strength outcomes before changing each recipe; do not globally multiply utility effects by strength |
| Spray value | Generic Spray: 12 Flux, 7 damage per eligible target, strength 3; generic Bolt: 6 Flux, 9 damage, strength 5 | Fan, instant resolution and interception must demonstrate a real advantage; evaluate 1/2/3 targets and incoming strength before tuning |
| Depleted Rapid trap | Every paid cast resets Flux recovery delay and ramp | Expose burst/rest guidance; compare burst, empty-held and deliberate recovery cycles through the real simulation |
| Champion sameness | Most identities share three core size stat profiles; Grace Riva and Wa Bidi have custom profiles | Report exact shared stat groups; do not mistake starter/appearance variation for 30 independently tuned kits |
| Racial distinction | 21 race passives plus 30 personal passives now use explicit existing-state windows and bounded benefit/tradeoff pairs | Test actual combined choices and counters; catalog uniqueness alone does not prove equal viability |
| Frostway wording | It changes target speed and projectile displacement, not acceleration/braking | Correct the purpose text rather than promising nonexistent slippery handling |

Values above describe the October 7 source audit, not indefinitely sustained DPS
or a win-rate measurement. That earlier catalog included deliberate Water/Fire/Charge/Dark Bolt and Water
Spray overrides. Charge is now a derived Fire technique, not a selectable element. Whole-hex footprint selection is
the active authority; historical family cell-count caps are not live coverage.

## Reproducible balance evidence

The `balance-audit` registered suite builds `.godot/balance-audit.json` from
validated production ability/champion catalogs, compiled spell definitions,
applied isolated actor capabilities and resolved reaction policies. It enumerates
every live choice, source hashes, shared direct-delivery/stat groups and limits.
It is an offline diagnostic; no new per-frame cost, telemetry or balance rule.
The suite tests the report's correctness, **not fairness**. Base recipe damage,
health and capacity are authored values, not observed realized outcomes after
intensity, protection, occupation, interception or linked-source conditions.

Run focused validation with stable suite IDs from `tests/run_all.gd`; refresh
the runtime identity after source changes using the normal project workflow.
Keep diagnostics separate from gameplay acceptance and retain failed controls.
Current focused suite IDs include `elemental-spell-expansion`,
`expanded-spell-network`, `element-delivery-presentation`, `signature-progression`
and `spell-testing-tools`. See the central handoff for their executed results;
this contract does not promote a candidate or replace the human route.

| Next acceptance slice | Required observation before changing numbers |
|---|---|
| Reaction economy | All 21 self/pairs with Rapid/Rapid, Bolt/Bolt, Heavy/Heavy and Heavy/Rapid, then all 42 larger combinations; compare actual debit, surviving strength, shared damage, selected hexes, phases, useful terrain effects and counters |
| Eight family niches | Automated admission/finite-state coverage for all 504 cells; human paid comparisons across eight deliveries and selected singleton/pair/larger payloads. Test cover, 1/2/3 targets, burst/empty/rest and moving opponents; do not claim 504 human trials from catalog enumeration |
| Status follow-up | Each of six effects alone and in mixtures: actual hit, protection, refresh, expiry, regeneration, air/ground distinction and counter; separate status damage from the reaction pool |
| Signatures and Range | All 30 unique assignments; a clean paid victory awards exactly its signature. Developer-tainted, abandoned and duplicate attempts award none. Range loaners never become saved rewards. Same-actor restoration preserves original slots and elapsed cooldowns; ordinary Range exit restores the weave into a fresh world |
| Optional introduction | Movement, rising jump, accepted paid cast, actual Flux recovery, Range entry and mixed paid cast advance their own steps; Skip and menus do not inject actions or change saves |
| Size and air action | Three sizes, flight/double jump, same weave, symmetrical starts, all movement chains; separately measure survivability, target exposure and resource opportunity |
| Identity refinement | One ancestry/character at a time; one readable benefit and real trade-off within tested baseline, no unbounded passive stack or mandatory combo |
| Human acceptance | Short mirrored Duels then Duos/Trios/FFA; capture reason to choose, opponent understanding, dominant loop, frustration and actual resource decisions, not only victories |

Performance and fun are separate gates: preserve deterministic paid ledgers,
same-build networking, readable cues and bounded work. Eight players remain the
supported cap; neither this audit nor balance tests establish dense 120 Hz.
