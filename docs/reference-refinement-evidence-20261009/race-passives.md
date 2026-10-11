# Twenty-one situational ancestry passives

Status: CATALOG_CANDIDATE. All 21 definitions and positive-window fixtures are written; root owns runtime hooks, integration tests, identity, and playable qualification. No engine was run by this worker. Human usefulness and balance remain unverified. 2026-10-09.

The user explicitly requested a distinct, interesting passive for every race and character using existing controls. `src/content/race_perk_catalog.gd` supplies one ancestry choice, while a separate character catalog supplies personal identity. These are original H.E.X. hypotheses grounded in established mechanisms, not claims that another game's exact percentages work here.

## Mechanisms used as evidence

- [EA's official Apex ability guide](https://help.ea.com/en/articles/apex-legends/abilities/) documents passives tied to existing actions and situations: Bangalore's threatened sprint, Revenant's crouch and climb, Horizon's air control, Octane's health-dependent regeneration, Gibraltar's aiming shield, and Rampart's weapon handling. It also documents finite flight fuel for Valkyrie. This is evidence of shipped contextual identities, not proof of any H.E.X. outcome.
- [Respawn's March 2026 designer notes](https://www.ea.com/games/apex-legends/apex-legends/news/28-1-designers-notes) report declining concentration of dominant squad compositions after multiple changes. They frame viable alternatives as a goal, and describe a momentum passive limited to sustained out-of-combat travel. This is aggregate observational evidence; it cannot attribute success to one passive or justify arbitrary numerical buffs. Their concern about safe channeling becoming exploitable motivates finite, exposed windows here.
- [Respawn's Titanfall controls interview](https://www.gamedeveloper.com/design/designer-interview-getting-i-titanfall-i-s-controls-just-right) describes constrained slide steering/stopping, movement combinations, and internal positive reactions to the slide prototype. This supports meaningful transitions with commitments; it does not establish that H.E.X. needs extra speed or unconstrained aerial mobility.
- [Dave Crooks's Enter the Gungeon interview](https://www.gamedeveloper.com/design/q-a-the-guns-and-dungeons-of-i-enter-the-gungeon-i-) explains the team's preference for reload tension and learning each gun's rhythm. Universal active reload overloaded beginners, so an optional item retained that execution depth. Our transfer is narrower: use an existing spell's repeat cadence to make contextual timing meaningful without adding a button or a global casting lock. This is an original inference from a shipped mechanism and developer-reported experience; it is not evidence that H.E.X. cooldown percentages improve balance.

Each row below identifies the reference mechanism being translated, the proposed player choice, and its cost. A reference supports the shape of the choice. The percentage, resource threshold, fantasy ancestry assignment, and exact compound tradeoff are local design decisions to validate, not borrowed facts.

## Coverage and design decisions

| Race / passive | Situation and benefit | Price or narrow opportunity | Established mechanism translated |
|---|---|---|---|
| Human / Measured Pace | Ordinary walking: Flux and Stamina recovery +10% | Surrenders sprint, crouch and authored-move windows; normal recovery waits remain | Respawn's sustained-travel passive separates repositioning value from fighting power |
| Dwarf / Low Bastion | Ground crouch: damage -7%, knockback -15% | Ground speed -10%; ground hazards still reach it | Revenant's posture identity plus Gibraltar's committed defensive stance |
| Gnome / Charged Focus | At least two-thirds Flux: startup -10% | That spell's cooldown +10%; requires a banked resource | Rampart's handling identity; timing changes leave payload unchanged |
| Hobbit / Last Step | At most one-third Stamina: movement action cost -10% | Incoming damage +5%; no free or refunded action | Octane's health-sensitive opportunity and resource-risk movement |
| Elf / Passing Rhythm | Ordinary walking: acceleration +15% | Moving-cast startup +10%; no top-speed bonus | Titanfall's ordinary movement combined with independent firing commitments |
| Orc / Iron Nerve | Paid cast startup: damage -7% | Ground speed -10%; defense ends at release | Gibraltar's action-gated defense; Respawn's finite channeling protection constraint |
| Troll / Resting Mend | Grounded rest: health recovery +20% | Flux recovery -10%; standing still exposes the reset | Octane's passive regeneration translated into an interruptible recovery choice |
| Minotaur / Committed Stride | Actually paid sprint: knockback -15% | Braking -15%; must accept a longer stopping route | Titanfall's useful motion with reduced stopping freedom |
| Seakin / Slipstream Cast | Active slide: spell startup -10% | Incoming damage +5%; no benefit for ordinary crouch | Titanfall's slide-and-fire composition with a committed travel lane |
| Wyrmborn / Descending Scales | Airborne descent: damage -5% | Air steering -10%; flight and wallrun excluded | Horizon's landing/air-control identity, translated into a less flexible defensive descent |
| Stoneborn / Gathering Weight | Held grounded jump preparation: damage -5%, knockback -15% | Preparation sheds momentum 20% faster; instant taps gain nothing | Gibraltar's defensive action posture and Titanfall's momentum commitment |
| Treefolk / Deep Reserve | At most one-third Flux: Flux recovery +20% | Ground speed -10%; existing recovery waits and suppression remain | Resource-sensitive regeneration and controller reset windows |
| Sylph / Rising Current | Actual upward flight arc: air steering +15% | Movement actions +10% cost; stationary flight excluded | Horizon's air-control passive and Valkyrie's finite airborne resource |
| Undead / Stubborn Ember | At most one-third Health: healing +20% | Flux recovery -15%; ordinary damage delay still applies | Octane's health-dependent passive regeneration |
| Goblin / Exit Burst | Existing cast recovery: ground acceleration +20% | Braking -15%; no higher speed target or shorter cast recovery | Apex's action-sensitive mobility combined with Titanfall's stopping commitment |
| Nymph / Unbroken Flow | At least three-quarters Health: Flux recovery +15% | Incoming damage +5%; a clean hit can remove the window | Health-sensitive regeneration with an opponent-controlled break condition |
| Spiderkin / Wall Weaver | Active wallrun: movement exits cost -15% | Incoming damage +10%; attachment and sustain keep normal prices | Revenant's traversal identity and Titanfall's exposed wall-to-exit chain |
| Vampire / Held Vigor | At least two-thirds Stamina: healing +15% | Stamina recovery -15%; repeated evasions break the reserve | Resource-sensitive recovery; choosing reset over repeated mobility |
| Demon / Last Air Gambit | Airborne after spending dodge: startup -10% | That spell's cooldown +15%; no second dodge is granted | Handling specialization combined with finite air-action commitment |
| Angel / Poised Wings | Active paid held flight: damage -5% | Air steering -10%; finite paid flight still ends normally | Horizon's air-control identity and Valkyrie's finite flight resource |
| Werewolf / Wounded Stride | At most one-third Health: ground target speed +8% | Incoming damage +5%; authored impulse speed unchanged | Bangalore's danger-conditioned repositioning translated into a visible health threshold |

Percentages are single-passive values. Runtime compounds ancestry and character effects within its documented clamp; overlapping benefits are not an excuse for immunity, free actions, elemental bonuses, or extra material. Stamina and Flux triggers use exact integer thirds; the Nymph health trigger uses three-quarters. No passive reads `last_event`, hidden enemy information, an unreplicated counter, or a new key.

Cast startup samples the admission state before payment. That spell's cooldown samples the state at release, then runs that fixed timer; it is not continuously retuned. Gnome can pay below its high-Flux threshold before release and thereby avoid the conditional repeat-cooldown penalty. Demon can land during startup and lose the airborne repeat-cooldown penalty. These are explicit state-at-release timing choices, not guaranteed bundled penalties or hidden captured state. UI descriptions and tests must distinguish the two sampling moments.

Cross-review rejected the initial `cast_recovery_ticks` adjustment because that existing timer does not gate repeat admission. A timing passive must change an actual decision, so the implementation modifies the spell-owned cooldown instead. The integration suite checks actual refusal one tick before its deadline, acceptance at the deadline with full payment, retention when the spell moves between Loom positions, and independent admission of another ready spell. Projectile damage, radius, elemental material, normal cast recovery, and other spell clocks retain their existing behavior.

## Implementation and acceptance

The catalog exposes `definition(ancestry)`, `all()`, and the current 30-character `ancestry_for_wire(wire)` mapping. Public definition dictionaries are deep copies; `raw_definition` is an internal read-only hot-path view. The existing `ChampionCatalog.SUPPORTED_ANCESTRIES` remains authoritative; root must validate equality of all IDs and verify the mapping against actual content. Unknown IDs return no passive.

`tests/support/identity_perk_scenarios.gd` provides test-only positive states for each condition and compatible `&` conjunctions. It is deliberately separate from runtime evaluation. Root must independently check each window, threshold boundary, off-window neutral factor, exact payment, timed cast behavior, hostile-control exclusion, recovery delay, and complete snapshot/prediction continuation. All definitions need a reachable useful effect: a changed dictionary alone does not prove a mechanic works.

Human acceptance is separate: a player should be able to explain when the passive helps and how to punish it after a short practice route. Compare the same spell configuration and body profile with the passive in and out of its window. Reject a passive that rewards safe stalling without a credible contest, has an unobservable drawback, or dominates its alternatives. Aggregate roster diversity and encounter outcomes are later measurements, not established by these static definitions.

## Independent guide review

The movement worker checked `docs/IDENTITY-PERKS.md` against the runtime policy on October 9. Dr. Apex's combined damage factor is 855 permille, knockback 850, and preparation drag 1080; the guide's arithmetic is correct. Biggy Bob's admission and release windows are distinct as described. Faab I Yaina's held-flight and descending windows do not overlap in legal runtime states: active flight fixes vertical velocity at zero, while descent requires a negative value.

Two copy findings were reported to root and the menu worker for coordinated correction, without changing frozen runtime source:

- Waka Aren Si's Quiet Circuit counter still used the former internal-ID-derived name "Nico". Use the current roster display name, Waka Aren Si.
- Juul I Yaina's Last Ember Step window said the dodge was "spent", but its shared condition also requires the air-dodge timer to have ended. Say "after the air-dodge timer ends" or "after a completed air dodge" so players do not expect discounted paid redirects while that dodge remains active.
