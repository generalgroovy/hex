# H.E.X. independent combat, systems, AI and balance audit

Date: 2026-10-20. Audited source: `592855cbd88c070683d0c1fdc1fa0eaf235a0514`.

Repository: `C:/Users/sende/Documents/Codex/2026-10-15/ana/outputs/hex-confluence`. Original-cast authority: `C:/Users/sende/Projects/hex`. All `lib/`, `app/`, and `tests/` references below are relative to the hosted repository unless explicitly marked original.

This is analysis and an implementation plan. No runtime files, deployment, build or large test suite were changed or run. Evidence comes from reachable constructors, validators, native resolvers, catalogues, focused diagnostic scripts and selected existing tests. The diagnostic scripts and JSON results are beside this note. The two AI mirror fights are examples, not a balance sample or evidence of human enjoyment.

## Executive judgment

The valuable game already exists: commit a small team to movement and one action, reveal movement first, then watch a shared elemental exchange change both the fighters and the ground. A neutral field can help either side. A projectile can sacrifice its intended hit to form a useful meeting. A coordinated volley crosses protection collectively. These are distinctive, interdependent decisions worth protecting.

The weakest part is consistency between that system and the player's explanation of it. A real spell defeats its own advertised purpose; a core collision rule differs between live modes; broadening almost every aimed spell changed the value of several resource and control channels without equally changing their descriptions or AI valuations. More content would make those faults harder to understand. The highest-value work is a small, fully legible combat slice that establishes authoritative timing, impact, counterplay and decision contracts, then applies those contracts to the existing catalogue.

Keep the action grammar, canonical cast, exact-set chemistry, sealed uncertainty and elimination victory. Do not add another resource, phase, racial passive tree, initiative system, morale system or combination catalogue to answer this audit.

## What is already sound

- **True shared release:** every legality check uses the same post-movement snapshot; newly received control cannot cancel a spell already released. Damage/healing are accumulated before HP changes. Aggregate mitigation rewards coordination without making actor iteration order decide who survives. See `lib/tactics-v22.ts:462–609` and corresponding v20/v18 blocks.
- **Exact elemental sets:** 63 authored nonempty combinations replace their constituent pairs. Steam does not secretly keep Fire damage and Water flooding underneath it. Many higher recipes deliberately trade benefits for liabilities. `lib/combinations-v16.ts:54–137`; field formation `lib/tactics-v22.ts:515–534`.
- **Control has counterplay:** Guard resists force; old Anchored blocks it; Resolve prevents immediate repeated hard control; Clarity and cleansing answer new control. Force vectors combine before capped displacement. `lib/tactics-v22.ts:196–240,598–638`.
- **Prediction is substantially model-backed:** focused damage bands, planned projectile meetings, displacement and enemy reach already use native geometry or shared helpers. Fix contracts at that shared model, not with independent tooltip arithmetic.
- **Progression ownership is explicit:** one teachable spell maps to each defeated enemy type, signatures have creator access/cost advantages, and four configurable slots remain a meaningful constraint. `lib/spells-v20.ts:27–65`; `lib/spells-v11.ts:164–181`.
- **Fair public multiplayer boundaries:** Arena normalizes each of three champions to five affinity points, rejects Story unlock libraries, and validates company/seat ownership. Shared Tower concatenates each participating squad's actual encounter instead of multiplying one player's starter blindly. `lib/character-creation-v17.ts:5–11,28–33`; `lib/tactics-v18.ts:119–137`; `lib/tower-shared-battle-v23.ts:8–23`.
- **Compatibility gates exist:** `spellModel` absence preserves old footprints; Tower/Story projectile replay validation distinguishes old point contacts from current volume contacts. Use those patterns for repairs.

## Confirmed defects and contradictions

### P1 — Sunburst cancels its own advertised Blind on ordinary ground

**Actual resolver reproduction:** rank-three Light Haara, Sunburst equipped, flat plain map, caster at (-4,0), guarding enemy at (0,0). Both are ordinary current Tower units. Sunburst spends 3 Flux, has cooldown 2 and a radius-two focused area. The enemy loses 2 HP and receives Clarity, but no Blind. The same cast with Earth under the target leaves Crystal Prism and does apply Blind. Radiant Bolt on plain spends 1 Flux with no cooldown and deals 3 HP after Guard, while also granting Clarity through its Light field.

Evidence: `expert-audit-systems-probes-2026-10-20.mjs` and `.json` beside this note.

Cause: Sunburst promises Blind (`lib/spells-v11.ts:92`), every surviving Light arrival forms Light on plain ground (`lib/combinations-v16.ts:66`), field statuses join direct applications (`lib/tactics-v22.ts:546–552`), and fresh Clarity suppresses Blind in that same batch (`:598–604`). This is not a stochastic miss or an unseen opponent decision. Sunburst is not globally dominated, because other substrates alter the result; its default advertised role is still broken.

**Recommended decision:** preserve the coherent rule that neutral Light ground protects its occupant immediately. Reauthor Sunburst around an existing noncancelled verb with a distinct advanced-spell niche—for example, an enemy-only piercing burst whose purpose is defeating protection. Exact cost/damage needs the slice comparison. If Light-induced Blind is a non-negotiable identity requirement, explicitly redesign field/Clarity timing for the whole system first. Do not quietly special-case this one spell to ignore Clarity, or nerf all Light fields to rescue one description.

**Acceptance:** native resolver and preview agree on plain/Earth/Water/Dark substrates, existing and fresh Clarity, Resolve, cleanse, centre/inner/rim, and all three active engines. The advanced spell has a common, explained board state where choosing it instead of Radiant Bolt is rational after price and cooldown.

### P1 — Arena retains the old projectile collision rule

**Actual current Arena reproduction:** legal Ember from (-2,0) to (2,0), legal Water Jet from (0,-2) to (1,2), same exchange, controlled flat map. Both release. Arena's forecast and native resolver report no meeting. The current volume solver finds contact at fraction 7/13, producing Steam at (0,0). This reproduces the water-through-fire complaint in an active mode.

Evidence: `expert-audit-arena-contact-2026-10-20.mjs` and `.json`; existing narrow-contact fixtures in `tests/projectile-contact-v23.test.ts:17–28`.

Arena imports the exact-centre solver (`lib/tactics-v18.ts:23,434,662–670`); Tower and Story import the volume solver (`lib/tactics-v22.ts:25,493`; `lib/tactics-v20.ts:28,444`). The former only detects exact centre coincidence; the latter checks the entire relative flight with a quarter-hex projectile core.

**Plan:** give new Arena exchanges the same authoritative contact contract, with an explicit replay model gate. Preserve saved historical point-contact outcomes. Test forecast, native resolve, event ordering, renderer timing and restore together. Different-time crossings, parallel neighbouring lanes and shared target arrivals must retain their deliberate noncollision cases.

### P2 — Creature counterplay text is stale after area widening

Puddle says only one nearby ally recovers; Glimmerfin and Smudge say one precise target; Firstbud describes a precise commitment. These spells now pass through the generic focused conversion from aimed hex to radius-two burst: up to nineteen affected cells. See `lib/creature-spells-v20.ts:19,39,72,110`; `lib/spell-profile-v42.ts:12–16`.

Tower profiles the spell, then displays unchanged `counterplay` (`app/components/TowerGameV23.tsx:61`). Story workshop also displays that string (`app/components/CampaignWorkshopV20.tsx:73`). Existing tests check uniqueness and string length, not whether the promised answer works (`tests/creature-spells-v20.test.ts:22`).

**Plan:** derive geometry-sensitive counterplay clauses from the effective profiled spell. Retain authored voice where factual. Add semantic fixtures proving the advertised response actually changes an outcome. A counter should state an opponent's useful response, not merely repeat numbers. Old saves must use their old footprint in this text too.

## Confirmed behaviour with balance risks requiring measurement

### Focused areas changed multiple economies at once

`spellAtCell` scales direct damage, healing and statuses, but leaves recharge, theft, drain and force unchanged (`lib/spell-profile-v42.ts:27–35`). Recharge is per friendly recipient (`lib/tactics-v22.ts:570`); theft requests are per enemy (`:572,585–589`); drain healing counts affected enemies taking aggregate volley damage (`:575–578`); force reads the original cast over its full area (`:616`).

Diagnostic bands confirm Essence Theft keeps steal 2 at centre and rim, Inspire keeps recharge 2, Siphon keeps drain 1, and Quiet Circuit keeps recharge 3. This is legal current behaviour, not proof every such spell is overpowered. It is an unmeasured scaling interaction: a small resource spell can affect a much larger shared company at the same action cost. Six-squad Tower expands participants and opponents, but Link offers one qualifying pair and one extra damage across the entire team (`lib/tactics-v22.ts:495–504`). Generic broad benefits can scale faster than the special cooperative mechanic.

Base attack costs can drop to 1 while ordinary recovery is 2 per round. That provides a useful reliable action, but makes “more expensive basic damage” a weak reason to draft an advanced spell. Cost alone is not a sustained constraint on those basic attacks.

**Plan:** classify existing action functions before tuning: pressure, precision/displacement, support, resource transfer and terrain construction. Give each a declared per-cast or per-recipient contract. Keep the requested predominance of broad areas, but do not assume every effect channel should inherit unlimited recipients. Compare 2/3/6-player shared and split encounters. Only then decide whether resource/force channels need band falloff, recipient caps, different price, or a deliberately wide specialist role. Do not weaken cooperation merely because it is strong; require a real positioning/resource trade.

Compare clustering's shared healing/Flux/bonds against exposure to enemy areas, collisions and terrain conversion. If clustering wins every relevant trade, bigger maps alone will not create tactics.

### Temporal chemistry is deeper than its current teaching

The six base personalities exist but identical broad footprints obscure them:

| Element | Existing tactical identity | Emphasis without new content |
| --- | --- | --- |
| Fire / Lightning | Burn, hazardous ground, piercing Wet payoff, self-risk | Pressure now versus delayed payoff; Wet must already exist for bonus damage. |
| Water / Ice | Wet removes Burn, flood slows crossing, freeze creates slides, recovery | Change routes and timing; a safe heal may also create a useful enemy route. |
| Earth / Metal | Rough ground, delayed protection, barriers, piercing and control | Build the next exchange; walls are not universal area shields. |
| Air | Force, Haste/current, angles and ring displacement | Position is the payload; Guard, Anchored, ice and obstacles determine it. |
| Light | Recovery, control protection, next-round Ward, allied-safe attacks | Rescue and protection have different clocks. |
| Dark | Wither, theft after costs, drain, control and recoil | Deny future recovery/resources; choose the right victim and timing. |

Authority: `lib/spells-v11.ts:44–110`, `lib/combinations-v16.ts:60–135`, native resolution below.

Fields union ingredients with new arrivals and renew duration; a new exact phenomenon replaces the old one (`lib/tactics-v22.ts:101–108,515–534`). This is a transformation, not a permanent pile of every pair bonus. Broad repeated painting makes high-order fields easy to refresh. The balance risk is convergence on defensive fields, not a shortage of recipes.

**Plan:** aiming should explain the mechanical delta: adding Earth to Steam creates Hot Spring, exchanging half-damage shelter for rough ground, cover and healing. Generate that delta from actual ingredients and mechanics. Show old field, known resulting field, changed benefit/liability and expiry. Do not imply ingredients can be removed merely by adding another element. Build encounter questions around modifying or waiting out a field, not memorizing sixty-three names.

### Spatial rules need an explicit contract

Movement charges two effort for flood/rough crossings; penalties do not stack with marsh/climbing. Ice carries a whole straight slide for one effort. Landing contention resolves occupancy; a route is not automatically blocked by every actor it passes. These support simultaneous movement but need exact previews (`lib/tactics-v22.ts:243–285`).

Line spells cover all tied shortest rays rather than one narrow straight path. Bursts/rings use distance without wall occlusion, so a visible aim in front of a wall can affect occupants behind it (`lib/tactics-v22.ts:305–315,350–378`). This is not automatically wrong, but “wall equals universal cover” is false teaching. Keep current geometry initially and draw it truthfully. Changing occlusion later needs an explicit gameplay decision and compatibility boundary.

## AI and pacing

### What the AI already does well

AI reads public state, not opponents' sealed orders. It includes safe-zone pressure, field values, allied projected volleys, marginal damage through protection, focus-centre opportunities, recent projectile collision avoidance and some constructive allied-clash evaluation. Do not replace it with “nearest target” or call it entirely unaware of cooperation.

### Structural limitations confirmed in source

`lib/tactics-v22.ts:782–1005` (similar active v20/v18 logic) selects movement first and casts second. It reserves landings in sorted actor-ID order, projects positions, then searches casts from only the chosen position. A locally attractive step can discard a superior move-and-cast combination before spell utility is considered. Actor order repeatedly gives the same ally first access to useful squares.

The scorer has no explicit drain-healing utility or value for a wall's blocked route. A wall can score indirectly for occupied allies or fields, but “this barrier prevents an enemy reaching its useful firing point” is not modeled. A hard prohibition on damaging friendly footprints also rules out sacrificial or protected friendly-fire plays irrespective of net advantage. These are reasonable easier-AI safety defaults, but should not replace tactical evaluation at every difficulty. Role strings in `lib/character-design-v13.ts` do not drive different decision policies.

**Plan:** first extract/test action utility over existing forecasts, including drain, displacement endpoint, barriers, resource transfer and counter-fields. Then use a bounded joint search over a few diverse movement candidates and actions per actor. Keep a small beam of team drafts instead of greedily fixing each landing. Evaluate a few public response archetypes—hold, close, flank—not the hidden real order. Use role preferences as tie-breaks, not invented powers. Measure CPU cost on the largest shared battle before increasing breadth.

Acceptance is scenario-based: choose a legal healing angle over an empty aggressive step, value a barrier that closes a route, recognize force-to-hazard, avoid self-defeating Light/control, and sometimes accept controlled allied damage for a clearly superior outcome. Do not assert one exact move on every random map.

### Pacing is still a combat-quality issue despite correct termination

Two fresh actual AI-vs-AI opening fights using seed `FOCUS42-B` were recorded, with standard starters and native AI/resolution. Treevor/Puddle won in round 12: final collapse killed Treevor and the final opponent for 8 damage each; Puddle held the last safe centre. Steezo won in round 11 without collapse damage. The first opponent died in round 1 in both, leaving a long tail. Healing and environmental effects occurred during that tail; absence of generic damage events does not mean nothing happened.

Evidence: `expert-audit-systems-pacing-2026-10-20.mjs` and `.json`. This proves these sequences exist, not their frequency or whether humans would repeat them.

Normal Tower closure starts at round 6, boss closure at 8, with final one-hex safety at 12/14; final damage 8 ensures elimination under unique occupancy. Healing is taxed from rounds 6 and 9 (`lib/tower-endgame-v22.ts:7–15`; `lib/tactics-v22.ts:42,698–705`). This prevents endless defensive fights, but can make the decisive question “who occupies centre?”

**Plan:** retain closure as a transparent failsafe. Diagnose the tail by spell use, healing prevented, zero-net-pressure rounds, target switching and unavailable firing angles before shortening it. Fix action selection and defensive composition first. Measure contact time, turns after first defeat and share of outcomes decided by final collapse, stratified by starters, enemy roles, skill and player count. A proposed normal-room target of roughly 4–6 meaningful exchanges with few final-collapse finishes is a product hypothesis to test, not a measured result or universal limit for six players.

## Character, creature and progression identity

### Canonical cast is intact

The original runtime loads `res://content/champions/foundation_champions_v1.json` (`original src/app/bootstrap.gd:44,423`). Its catalogue validates native elements (`original src/content/champion_catalog.gd:88–115`). This is the authority, not the old poster or an intermediate full-cast candidate.

A fresh comparison of all 30 identities found no current name, ancestry, body or native-element-membership mismatch after normalizing original `wind` to hosted `air`; both have 21 ancestries. Original 2/1 affinity becomes hosted 3/2; original 1/1/1 becomes 3/1/1. This is a deliberate adaptation from three to five starting points, not drift. Evidence: `expert-audit-canonical-cast-2026-10-20.mjs` and `.json`; hosted `lib/roster-v7.ts`, `lib/roster-v11.ts:33–37`, `lib/roster-v13.ts`.

Do not reimport original numeric totals or rename people to match the poster. Flexible creation can add a third element while preserving the native highest element. Shared HP/movement/Flux baselines keep the rules compact; signatures and meaningful loadouts should carry identity before adding racial subsystems.

### Make existing progression decisions legible

Arena intentionally normalizes companies and rejects Story unlocks (`lib/tactics-v18.ts:125`). It does not import earned Story affinity and merely balance total team affinity. Establish a clear policy instead of implying campaign grinding carries into competition.

A native primary affinity of 2 is legal, but the creator's signature requires 3, so availability omits it until that threshold (`lib/character-creation-v17.ts:8–11`; `lib/spells-v11.ts:173–176`; `lib/spells-v20.ts:61–63`). This is a real build trade the player must see before confirming.

Tower allows between-room rebuilding at the same total affinity budget (`lib/tower-v23.ts:58–64,262–268`). Training named for one element is therefore not irreversible specialization. Preserve requested flexibility and explain the point can be reassigned; show immediate level, cost, damage-band and signature consequences.

### High-order creatures are not reached as Tower opponents

`battleEnemies` samples only lesser and standard creatures on every floor (`lib/tower-v23.ts:114–137`). Greater creatures become recruit options from floor 6 (`:210`), and Story field encounters can use them, but Tower combat generation never selects that class. Tower enemies therefore do not teach the existing three-to-six-element creature techniques through opposition.

This is a reachable-content gap, not a need for more catalogue entries. Add a few curated late-room substitutions: replace one standard foe with an existing greater creature at a controlled encounter budget. Pair it with a clear counterplay lesson, not more bodies or an enormous random pool.

Ambient inhabitant pulse code also exists, but current battle constructors do not populate inhabitants. It must not be counted as a live encounter feature because a helper exists. Keep pulses dormant unless they serve the slice; current fighters can demonstrate the relevant interactions.

## Explicit information and timing contracts

### Known versus unknown during planning

| Information | Commitment to the player |
| --- | --- |
| Current terrain, height, walls, fields/expiry, HP, Flux, statuses, cooldowns, visible kits | Public facts inspectable without guessing. |
| Own movement/action and committed allied draft | Exact legal geometry, own cast area, known allied contact and relevant conditional impact. Refresh when a friend edits. |
| Opponent move/action/Guard and uncommitted allied edits | Unknown. Never render a predicted HP total as guaranteed. |
| Enemy maximum movement/attack reach | An envelope of legal possibilities, not revealed intent or probability. |
| Target damage/force | Name assumptions: present tile, Guard/no Guard when different, known protection, current marks. Do not invent whole-exchange damage. |
| Element reaction | Exact from known arrivals/current field; enemy arrivals or interception can change it. |
| Wall or occupied landing | Separate guaranteed static obstruction from possible moving-unit contention. |
| NPC future pulse | Footprint/counter/timing only when the encounter contains that public mechanic. No sealed-order leakage. |

The player must distinguish “possible,” “committed by us,” and “conditional on the target remaining here” at a glance. Three visual states suffice; another rules menu is unnecessary.

### Status clock and resolution pulse

Authoritative sequence, `lib/tactics-v22.ts:462–724`:

1. **Planning reads existing states.** Rooted/Chilled/Haste affect movement; Blind affects reach; Concussed affects price. Choose movement and cast or Guard.
2. **All movement resolves.** Landing conflicts can change origins. Validate casts against one post-move snapshot. A blocked landing can fizzle an out-of-reach cast without spending price/cooldown.
3. **All legal spells release and pay.** Old status/cooldown counters tick; new cooldowns are assigned. A released spell survives its caster's defeat in the exchange.
4. **Meetings and field formation.** Intercepted intended hits disappear. Surviving arrivals and existing ingredients form one exact field. Bonuses read existing marks: same-volley Wet does not activate Lightning's bonus.
5. **Direct batch.** Old Ward/Guard mitigate; new Ward does not. Healing and damage net simultaneously. Existing or incoming Wet prevents Burn. Fresh Clarity/cleanse can block incoming control immediately. Theft reads reserves after costs. New effects cannot retroactively change release legality.
6. **Force and final contact.** Old Anchored resists; newly granted Anchored starts next exchange. Sum vectors, apply Guard resistance, resolve collision/ice, then final field contact and capped environmental damage. Crossing a hazard is not the same as occupying it.
7. **Remaining aftermath.** Creature bonds, closure, field duration and recovery resolve, then elimination is decided. New statuses survive into the indicated future planning window.

Expose three visible beats—movement, shared flight, consequences—while the detail model says “now” or “next planning.” Status counters should mean remaining planning windows, not animation ticks. Optional NPC pulses attach to their actual step above; they do not require a new player action phase.

## First vertical slice: prove depth with a small existing encounter

Use a fixed seeded room with **two allies, two baseline foes and an optional third foe only in the harder variation**. Use existing cast identities/kits: Oh Tipi and Steezo or equivalent native kits, a ranged Fire attacker and a simple Earth defender. The variant adds an existing low-strength disruptor. No new champion, resource or recipe.

Build one readable lane between a stone obstruction and a small Water patch. Leave the rest ordinary ground. Author three valid approaches using current geometry:

- **Coordinated pressure:** combine hits to overcome Guard/cover; expose the cost of bunching.
- **Field counterplay:** form Steam to shelter a threatened ally, accepting reduced damage against an enemy occupying it; or move/wait to preserve pressure. Add Earth only in the variant to demonstrate replacement with Hot Spring, not hidden pair stacking.
- **Angle and timing:** crossing Fire/Water shots can meet before their targets; another legal move-and-aim avoids contact. Force can push a non-guarding enemy toward an obstacle/field, while Guard or old Anchored provides a valid response.

The room needs at least two viable plans with different risks; the answer cannot be one memorized combo. Sealed movement uncertainty remains. Enemy maximum reach is public; its actual choice stays hidden. Follow with the existing defeat/learn/reward flow and one clear spell comparison.

**Acceptance before extending the changes:**

- Native fixtures assert contact, field, force landing, clocks, bonuses and restoration; repeat across intended common mode contracts.
- A held enemy and a moved enemy produce appropriately different conditional outcomes. No forecast asserts the unknown move.
- A novice can identify damage sources, why a spell was cancelled, the next effect of Wet/Guard/Ward, and an alternative plan after one replay. Test with people who did not build it.
- A second attempt produces a deliberately different plan for understood reasons, not just faster clicking.
- Record meaningful decisions, idle/zero-pressure turns and encounter time. Decide from that evidence whether tuning or explanation is needed.
- Two-player cooperation creates a useful angle/field opportunity beyond independent attacks; six-player effects and action-value budgets remain legible and bounded.

## Implementation sequence, dependencies and risks

| Order | Work package | Dependency and principal risk | Testable completion |
| --- | --- | --- | --- |
| 1 | Codify timing/contact/information contracts; add failing Sunburst/Arena fixtures. | Replay formats and mode rules; do not freeze a bug into prose. | Every public statement has native evidence and a deliberate legacy policy. |
| 2 | Repair Sunburst role, Arena contact gate and stale counterplay. | Explicit Light decision; no silent historical changes. | Fixtures pass, old saves restore, tooltip/forecast/event agreement. |
| 3 | Extract only proven common pure impact/field/status contracts. | v22/v20/v18 have deliberate differences; a wholesale merge is risky. | Parity fixtures first; each mode retains intended results. |
| 4 | Internally test the small vertical slice; improve movement/flight/consequence feedback. | UX/art consume one consequence model. | Novice comprehension and two successful tactical approaches. |
| 5 | Improve bounded AI move-and-action evaluation; diagnose room tails. | CPU budget, public-only inputs; stronger AI can expose balance faults. | Scenario fixtures and matched old/new diagnostics; six-player latency measured. |
| 6 | Tune area-channel economics and curated late encounters. | Needs slice/AI evidence; bot win rate is not enjoyment. | Role use/impact, starter fairness and shared/split scaling measured separately. |
| 7 | Extend verified contracts over existing content; human playtests. | Catalogue coverage can hide semantic duplication. | Every selectable spell has truthful counterplay, useful niche, correct profile. |

Suggested delegation: systems owns resolver/contracts/compatibility; AI consumes those helpers and owns decision fixtures; UX owns information hierarchy and phase feedback; encounter/balance owns the slice and matched diagnostics; independent review challenges assumptions and old-save paths. Agree APIs and decisions before parallel source edits. Art follows actual geometry/events. Do not assign different agents to independently rewrite each engine.

## What outside the authors would show the result is right

1. **Technical evidence:** failing-then-passing native fixtures, permutation checks, intended mode parity, old/new save corpora, preview-to-resolution agreement and bounded execution time.
2. **Independent comprehension:** blinded first-session observations, short “what happened and why?” probes, and correct predictions on a second similar exchange. A developer finding the tooltip is not an onboarding test.
3. **Decision diversity at comparable strength:** stratified draft/select/use data and counterfactual board examples showing each spell's niche. A low pick rate alone does not invalidate a useful specialist.
4. **Pacing distributions:** contact time, turns after first defeat, zero-pressure turns, final-collapse reliance and decision latency across starters, public seeds and group sizes. Separate human/bot evidence.
5. **Executable counterplay:** an independent tester performs the advertised response and observes its promised consequence. Prose quality cannot substitute for this.

## Relevant primary developer research

- Matthew Davis, [Into the Breach Design Postmortem, GDC 2019](https://media.gdcvault.com/gdc2019/presentations/Into%20the%20Breach%20Postmortem%20Final.pdf), especially slides 7, 12–13, 20, 30–35, 39–44. The developers emphasize readability, deterministic consequences, constrained attack grammar and cutting complexity that does not earn its place. Application: readable possibilities and spatial manipulation. **Limit:** H.E.X. relies on sealed simultaneous decisions; full enemy-intent disclosure would remove part of its identity. Use maximum reach and conditional consequences.
- Anthony Giovannetti, [Slay the Spire: Metrics Driven Design and Balance, GDC 2019](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf), slides 6, 9, 11–15, 20. Cards need niches; expert feedback and quantitative evidence work together; skill segmentation matters. Application: inspect selection, actual use and marginal contribution, then replays. **Limit:** reusable cooldowns and simultaneous fields differ from a deckbuilder's economy.
- Cephalofair, [The World of Gloomhaven](https://cephalofair.com/pages/the-world-of-gloomhaven). Distinct mercenaries, cooperation and progression give a party complementary reasons to act together. Application: express those complementary roles through H.E.X.'s existing move-plus-action structure. **Limit:** this overview is not evidence for detailed card timing; importing initiative, hand exhaustion or a deck would expand scope instead of resolving coherence.
- Overhype Studios, [Dev Blog 80: A New Perk System](https://battlebrothersgame.com/dev-blog-80-progress-update-new-perk-system/). The developers discuss revising perks that removed other decisions' costs and creating meaningful specializations. Application: check whether broad resource recovery erases Flux tradeoffs; do not copy the perk tree.
- Overhype Studios, [Dev Blog 20: Bravery and Morale](https://battlebrothersgame.com/dev-blog-20-bravery-morale/). Readable states connect to concrete combat consequences. Application: explain H.E.X.'s existing status clock. Adding morale is unnecessary.

These sources inform methods; they do not prove H.E.X. is balanced or enjoyable. Concrete defects above come from the current game.
