# H.E.X. expert review and implementation plan

H.E.X. should make a player feel clever for arranging an elemental encounter with a friend, then let both of them understand exactly why it worked. Its strongest foundation is already present: simultaneous commitments, travelling spells, elemental terrain, configurable champions, creatures with complementary roles, and seeded routes that friends can explore together or separately.

The next improvement should concentrate on consistency, consequential choices and communication. The existing catalogue is large enough to support a much better game. More spells, statuses, modes or visual layers would make the current problems harder to solve.

This is an implementation proposal for the hosted tactics game, reviewed on 20 October 2026 against source commit `592855cbd88c070683d0c1fdc1fa0eaf235a0514`. It does not change the published game. Three specialist agents reviewed combat systems; levels, progression and co-op; and presentation, accessibility and audio. The coordinating review covered the playable interface, architecture, research, verification and the integration of those findings. These are specialist perspectives, not claims of human career experience.

## Decisions that should govern the work

1. **Keep simultaneous play as the identity.** Everyone plans, everyone moves, then spells travel and interact together. Presentation may slow or pause an exchange; it must never change the simulation.
2. **Keep elimination as the victory condition.** Terrain, route pressure and enemy composition should produce decisions before closing ground has to end a stalemate.
3. **Keep the original cast and world.** Preserve canonical names, ancestry, appearance and elemental membership. Character creation changes a legal build, not who an established character is.
4. **Keep a small equipped vocabulary.** Four equipped spells and a signature should offer useful alternatives. The full catalogue is discovery space, not homework before the first fight.
5. **Make every important consequence inspectable.** Distinguish a certain effect from a conditional forecast and from an unknown opposing commitment.
6. **Make co-op worthwhile through decisions between players.** Joining and splitting need different advantages, understandable costs, and protection against accidental disruption.
7. **Make the screen readable before adding spectacle.** Characters, target centres, travel, collisions and resulting terrain have a strict visual priority. Quiet space is useful when it separates decisions.
8. **Make improvements reversible and measurable.** Preserve existing saves and invite links. Use fixed encounters, recorded decisions and observed players to decide whether a change helped.

## What a professional review starts from

The useful raw material is the executable rule set, not the feature list. This review inspected reachable route components, combat resolvers, spell and creature data, procedural generation, shared-room state transitions, CSS, animation/audio implementation, original cast data, and the current local production build.

The canonical comparison used the original game's bootstrap-selected `content/champions/foundation_champions_v1.json`, rather than the old poster. All 30 hosted identities retain the original elemental membership. The original three-point allocations have been adapted to this game's five-point budget; that is a documented rules adaptation, not missing characters.

The browser review used the existing `FOCUS42-PLAY` saved encounter without submitting a new turn. It inspected status explanations and the previous-round report at measured CSS viewports of 1440 × 900, 390 × 844 and 790 × 444. Desktop and portrait phone layouts fit horizontally. Compact landscape reproduces overlapping spell text. The observed report is an example of a dense exchange, not a representative sample of all first fights.

The prior release's regression and six-seat HTTP evidence establishes specific working behavior. It does not establish that an unfamiliar person understands the game, that all builds are viable, or that a physical phone runs smoothly. The next development cycle needs that additional evidence.

## Findings that should determine priority

| Priority | Finding and evidence | Player consequence | Response |
| --- | --- | --- | --- |
| P0 | An actual Tower resolver fixture shows Sunburst's Blind canceled by the pure-Light field created by the same cast. On natural Earth, the changed mixture allows Blind to survive. | The defining promise of an expensive control spell depends on an unexplained terrain side effect. | Specify and test status application, protection, cleansing and terrain pulse order before adjusting its numbers. |
| P0 | A legal Ember/Water Jet volley in the current Arena resolver releases both spells but reports no collision. The current Tower/Story contact solver detects a Steam contact for the same trajectories. | The game's central interaction behaves differently between current modes. | Version-gate the corrected Arena contact behavior, with both preview and resolver tests; retain the original interpretation of old replays. |
| P0 | At 790 × 444, Water Jet and Undertow text extends beyond their roughly 44px button boxes; neighboring spell rows overlap. | A core command becomes difficult to read or select in a short window. | Replace conflicting fixed-height rules with a height-aware command layout and readable selected-action details. |
| P1 | Puddle, Glimmerfin, Smudge and Firstbud retain precise/single-target counterplay text although their focused spells now affect an area. | Players can follow the stated counter and still be hit or misunderstand a support spell. | Derive geometry-sensitive descriptions from the effective spell profile and test the advertised counter. |
| P1 | Focused spell damage/healing and some control effects use centre/rim distinctions, while other channels retain broad full strength. | Area size can multiply utility without a corresponding cost, risk or positioning tradeoff. | Give every effect channel an explicit spatial profile and evaluate whole-action value. |
| P1 | The active AI selects movement before fully comparing the cast from each candidate position. | It can miss meaningful movement-plus-spell combinations and provide the wrong balance signal. | Jointly score a bounded set of legal movement and casting candidates using public information. |
| P1 | Six identical squads joining the first room of seed `AUDIT43` produce 12 enemies of only two types. Splitting across the first six doors exposes nine distinct teachings. This probe does not simulate victories. | Joining scales workload but may not supply enough encounter variety or a clear compensating benefit. | Design joined encounter composition and measure safety, cooperation, time and learning against splitting. Preserve valuable split-route discovery. |
| P1 | The observed round report lists net HP/Flux changes and many named fields, but a damage total is not broken into an easily followed chain of causes. | A player can read what changed without understanding which decision caused it. | Introduce one structured consequence record shared by forecast, replay, report and sound. |
| P1 | Tower, Story and Arena have separate active resolvers and different data imports. Existing legacy routes are also intentionally retained. | A fix may reach one mode but leave another with a different expectation. | Publish a behavior matrix, freeze legacy profiles, and extract shared contracts only behind parity tests. |
| P1 | Tower battle cleanup calls `cancel()` on audio; the audio service has a separate `dispose()` that closes its context. | Repeated room visits can retain audio resources. The resulting device impact needs measurement. | Own one clear audio lifecycle, close on unmount, and test repeated room entry/exit. |
| P1 | Instant playback also suppresses combat sound; reduced-motion preference defaults to that playback setting. Sound selection favors alphabetically sorted element names and uses the same cue for any defeat. | A motion preference removes another useful information channel, and important outcomes compete poorly for attention. | Separate motion from audio preferences and prioritize cues by cause, ownership and outcome. |
| P1 | Critical phone information uses 8–10px text, some status targets are 20px high, and fixed layers accumulate across old and new styles. | Fitting the page is being achieved partly by making information harder to read and touch. | Introduce explicit reading sizes, touch targets and information levels rather than shrinking everything. |
| P1 | Detailed pixel champions and trees appear beside flatter procedural creatures and broadly shared compound-effect structures. | The encounter has inconsistent materials and some different reactions are difficult to distinguish. | Use the champions as the reference; first improve a representative creature, terrain transition and non-Steam interaction at actual play size. |
| P2 | A co-op room expires seven days after creation; ordinary saves update its timestamp but do not extend that expiry. | A paused multi-session climb has a fixed recovery window. | Make the retention policy visible and add a tested resume/renewal policy before promising persistent campaigns. |
| P2 | The README still uses Confluence and the former long URL, while the current entry is H.E.X. and routes to a mode selector. | Documentation is an unreliable map of the current product. | Establish one current mode/rules/delivery index and label historical material. |

P0 means fix before judging a redesigned encounter. P1 means necessary for a coherent next playable milestone. P2 means schedule after the reference encounter succeeds, unless implementation exposes a more urgent failure.

## Principles from related games

These sources support principles. The proposed H.E.X. adaptations are design judgments, not claims that another game's success transfers automatically.

| Primary source | Useful principle | H.E.X. application |
| --- | --- | --- |
| [Into the Breach design postmortem, Matthew Davis, Subset Games](https://media.gdcvault.com/gdc2019/presentations/Into%20the%20Breach%20Postmortem%20Final.pdf) | Readability, limited menus, short experiences and interesting choices were explicit constraints. UI limitations helped expose unnecessary rules. | Make uncertainty comprehensible and inspect consequences at the decision point. Keep hidden simultaneous commitments; do not import fully disclosed enemy orders or a different victory condition. |
| [Slay the Spire metrics and balance, Anthony Giovannetti, Mega Crit](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf) | Every option should have a useful place; metrics require interpretation and player-skill context. | Analyze offered versus chosen rewards, usable versus merely learned spells, and outcomes by starter, seed and experience. Combine data with observed decisions. |
| [Fire Emblem Shadow Dragon manual, Nintendo, printed pp. 16–25](https://www.nintendo.com/eu/media/downloads/games_8/emanuals/nintendo_ds_21/Manual_NintendoDS_FireEmblemShadowDragon_EN.pdf) | Range inspection, preparation and forecasts put tactical information where players need it. | Keep enemy reach inspection. Show actual selected-caster values and conditional impact beside the aim. Make build comparison possible before replacing a spell. |
| [Gloomhaven, Cephalofair](https://cephalofair.com/pages/the-world-of-gloomhaven) | Distinct mercenaries and complementary tactical decisions support cooperation and progression. | Give each signature, creature bond and four-spell kit a recognizable job. Avoid importing hand exhaustion or initiative rules that would obscure simultaneous play. |
| [Battle Brothers tactical combat, Overhype Studios](https://battlebrothersgame.com/tactical-combat/) | Terrain, cover, elevation and enemy-specific abilities change the value of positioning. | Generate meaningful approaches and counters, then decorate the resulting geography. A random biome distribution alone is not a tactical map. |
| [Battle Brothers UI rework, Overhype Studios](https://battlebrothersgame.com/dev-blog-75-progress-update-reworked-ui/) | Materials can connect interface and world; named status tooltips reduce memorization. | Retain restrained parchment and dark framing. Give symbols short names and accessible explanations. Avoid making every panel ornamental. |
| [Final Fantasy Tactics makeover, director Kazutoyo Maehiro](https://blog.playstation.com/2025/07/21/the-secrets-behind-final-fantasy-tactics-the-ivalice-chronicles-makeover/) | Controls, contextual character dialogue and clear presentation help players appreciate an established tactical system. | Improve action flow and situational character expression while keeping the cast. Do not add a large job tree as a substitute for distinct kits. |
| [Environment interaction, Larian Studios](https://larian.com/support/faqs/what-is-environment-interaction_35) | One hero can establish a surface that another exploits; environment changes can redirect a fight. | Make setup, conversion, exploitation and counterplay visible. Define exactly how a projectile recipe differs from a surface recipe. |
| [Xbox accessibility guidelines 101](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101), [103](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/103), [107](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/107), [120](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/120) | Readable text, alternative cues, accessible controls and communication are parts of gameplay. | Scale reading independently of the map; use shape and text as well as color; support keyboard and touch inspection; make cooperation possible without voice chat. These are design references, not an accessibility certification. |

## Review by design discipline

### Core identity and the round structure

**Keep:** private planning, a separate movement phase, simultaneous casting, finite projectile contact, undo before commitment, and elimination. These are the coherent centre of the game.

**Improve:** make the commitment model consistent. A player needs to know whether they are choosing an aim hex, a target that follows a moving actor, a path, or a landing-dependent cast. A failed landing can currently invalidate a cast; that rule needs a visible conditional warning and a replay explanation.

Define one public exchange contract: validate commitments; resolve movement conflicts and travel; release eligible casts; resolve travelling contacts and impacts; apply displacement and field/status consequences in the documented order; settle resources, durations and victory. Audit the existing resolver against this contract before changing order. Timing changes are new rules, not animation fixes.

Keep ordinary planning untimed. Let each player review locally, even if teammates are ready. Shared combat advances when required owners have locked their next orders, not when the fastest viewer finishes an animation. Repeated confirmation screens should not sit between a understood action and its execution.

### Element personalities and advanced elements

Each base element needs a primary tactical verb and a weakness that survives upgrades. The following is a proposed direction to validate against the existing catalogue:

| Element | Primary decisions | Cost or counterweight | Advanced expression |
| --- | --- | --- | --- |
| Fire | Apply pressure, punish a predictable location, turn preparation into a burst. | Exposure and friendly-fire risk; water can change its outcome. | Lightning emphasizes travelling contact and conductive opportunities, not an unconditional damage upgrade. |
| Water | Reshape routes, manage passage, move or restore allies. | Setup can help either side; healing spends tempo and has limited reach. | Ice commits movement along a readable lane with a visible stopping point. |
| Earth | Anchor a position, interrupt routes, use cover and displacement resistance. | Less flexibility after commitment; enemies can flank or redirect. | Metal should add precise structural or conductive behavior, not another generic area blast. |
| Air | Redirect, separate, accelerate and exploit geometry. | Position-sensitive value; weak choices on open, unprepared ground. | Storm extends redirection and pressure across a readable area. |
| Light | Clarify, protect, expose and recover. | Protection should require an appropriate recipient or timing; it must not silently cancel the caster's control promise. | Radiance distinguishes proactive protection, exposure and cleansing. |
| Dark | Deny resources, obscure options and convert vulnerability into pressure. | Needs a setup window and a visible recovery/counter path. | Void extends denial without allowing indefinite action suppression. |

Keep the current affinity budget, maximum three starting elements, six levels and advanced unlock at three. Levels should change useful thresholds, shapes or timing windows within the existing framework. Automatic increases to damage, range, duration and efficiency together risk making affinity too universally valuable.

Do not redefine the original cast's elemental membership. Use canonical presets as readable recommendations and retain legal reconfiguration.

### Elemental combinations and terrain reactions

All 63 nonempty element subsets can remain available. They should be understandable through the same small grammar: **ingredients → contact → transformation → consequence → counter**.

Separate two concepts explicitly: a travelling projectile carries ingredients; a ground cell has a current surface with an expiry and behavior. Inspecting either should identify its source, effective area, duration, allegiance policy and counter. Environmental reactions can affect both sides, but that symmetry must be deliberate.

For every mixture, record one situation where it changes a decision, one cost or risk, one counter and one difference from its simpler subsets. A different name or color is insufficient. High-order mixtures should have a clear dominant behavior and ingredient history available on demand. They should not require six competing animations and six permanent labels on every cell.

Do not add a new reaction queue, secondary elemental resource or arbitrary combo multiplier. First test whether the existing movement, cover, resource, status and displacement channels already express the desired distinctions.

A useful reference interaction is an incoming fire shot intercepted with water: mark the contact point, visibly transform the projectiles, show the resulting steam footprint, and explain the loss or conversion of the original hit. A second move can exploit that cloud or push someone out of it. Every step must have a visible counter; the example is a test scenario, not a promise of a new unverified rule.

Use a precise information contract:

| Information | What the player may see |
| --- | --- |
| Current HP, Flux, statuses, terrain and legal own actions | Exact values from the authoritative snapshot. |
| Own committed plan | Exact intended path, landing and aim; explicitly conditional where simultaneous conflicts can change them. |
| Shared allied draft | Current communicated intentions, labeled as editable until locked. |
| Enemy movement and spell envelope | Legal possibilities from public state; never presented as a predicted attack. |
| Forecast involving unknown orders | Branches or assumptions, not a single guaranteed damage number. |
| Earned scout information | The actual compatible encounter facts, with concealed facts retained. |
| Resolved exchange | Exact events and causes, including why a planned effect failed or changed. |

### Spells, affinity and build balance

Preserve four equipped spells plus a signature and the creator discount. Classify each spell by purpose: pressure, setup, displacement, protection, recovery or denial. A useful four-spell set should normally contain more than one purpose, but the editor must allow deliberate specialization.

Audit whole-action value: centre and rim damage, useful targets, movement denial, forced travel, resource change, status duration, terrain persistence, cooldown and friendly-fire liability. Give each channel a stated centre/inner/rim policy. Precision tools and lines may stay precise even when most area spells have radius two or more.

Build a dominance report that finds apparently interchangeable spells. A dominated result flags a review; it does not automatically delete an enemy's unique teaching. Correct costs, geometry, timing or context so that the teaching has a useful role. Preserve the one-enemy-type-to-one-spell mapping.

Make affinity training show the exact next change for the selected fighter. Keep learned, eligible and equipped distinct. Show why a spell is locked and which existing allocation would make it legal, without silently rebuilding the character.

### Status design and the rules clock

Every status needs five fields: trigger, immediate consequence, active planning window, expiry, and counter. “One round” must have a consistent meaning when applied during an exchange.

The current Clarity contract immediately blocks incoming control, and neutral Light ground can protect either side. Preserve that coherent rule by default. Give Sunburst a distinct role using an existing verb that its own field does not cancel; a protection-piercing burst is a candidate to compare, not a settled balance change. If Light-induced Blind is essential to its identity, explicitly redesign protection/field timing across the system. Do not quietly make one spell ignore Clarity. Test the chosen behavior on different substrates with existing and fresh protection, simultaneous sources and all active mode profiles.

Audit hard-control loops, resource locks, stacking, repeated application and recovery. Preserve tactical interruption while ensuring a player can identify a route out. Present only the statuses that change this decision; the inspector retains the complete state.

### Character design, ancestry and creatures

The canonical cast is a strength. A roster of 30 appearances should produce 30 reasons to care, rather than 30 compulsory rules subsystems.

For each champion, produce a one-page identity sheet: silhouette, temperament, signature job, preferred situation, vulnerable situation, two useful partners and one expressive animation gesture. Keep custom builds free within the established rules. Distinction should come primarily from signatures, creator efficiency and authored defaults before adding new passives.

Creatures need the same clarity. Selection must show elements, actual moves, strength class and exactly what the bond changes. The existing three strength classes and mixed lineages provide enough material. Improve role expression and artwork in batches; do not expand the bestiary until the current roles are recognizably different in play.

Ancestry can inform pose, proportions and small situational behavior. Do not transfer every native bullet-hell passive into a simultaneous tactics game without proving its relevance.

### Enemy AI and encounter direction

Separate **competent decisions** from **difficulty**. A predictable enemy that uses its own kit intelligently is more useful than a poorly coordinated enemy with inflated numbers.

Generate a bounded shortlist of legal move-and-cast pairs. Score damage, useful status application, ally harm, setup exploitation, resource economy, safe position, collapse pressure and teammate overlap. Then coordinate the selected enemy actions so multiple enemies do not waste their entire volley on the same already defeated target or erase each other's useful fields.

Use only public state and enemy-owned plans. Add deterministic intent archetypes such as holding a choke, separating a pair or exploiting a wet route. A visible posture can teach counterplay without revealing the exact sealed action.

Test difficulty through composition, available counters and positioning before HP inflation. Bosses should stress one established rule clearly and provide response windows: separate a protected support pair, escape a displacement trap, or interrupt a field setup. Elites should combine familiar roles; they should not simply contain more visual effects.

Tower currently selects lesser and standard creatures as opponents; greater creatures are available as later recruits but do not appear in its enemy generator. Test a few late-room substitutions using existing greater creatures and an explicit counterplay lesson. This can expose existing three-to-six-element techniques through opposition without increasing catalogue size or simply adding bodies.

Two focused AI mirror fights on seed `FOCUS42-B` lasted 11 and 12 rounds although the first enemy died in round 1. One ended through final collapse. These examples justify investigating the tail after the first defeat, but establish neither its population frequency nor human pacing. Measure that tail separately from first contact and ordinary planning time.

### Map topology and procedural generation

Start generation with the tactical problem, then apply a seeded environment. Use a small family of spatial motifs: a crossing with a safer long route, a broken courtyard with competing elevations, a marsh basin with dry islands, or a broad split approach that reconnects near the fight.

For each generated map, validate walkable connectivity, reachable deployment exits, route costs, line of sight, useful cover and first-contact distance. Require alternatives to a single narrow path. Ensure collision geometry agrees with wall artwork, and show surface changes without making the underlying height unreadable.

Scale active fighting space and approach lanes with participants. Increasing the outer map radius alone can add travel and camera work. Large maps can retain scenic edges while the encounter occupies readable sectors.

Use controlled asymmetry for PvE and measured spawn fairness for Arena. Preserve replayable seeds by versioning the generator; never silently redraw an existing run.

### Tower rooms, scouting and rewards

The current fitted route graph and exact friend destinations are useful foundations. Improve the quality of each branch rather than making the graph larger.

A room preview should communicate the known decision: likely fight style, broad risk, known reward, and remaining uncertainty. Distinguish undiscovered information from an empty or unavailable value. Each champion's scout remains finite; avoid spending it on a repeated fact.

Compare alternatives by the party's actual needs: immediate healing versus a risky lesson, a route that suits current terrain tools versus a more valuable but awkward enemy, or an elite before a known rest. Offer rewards that improve different plans. Avoid three cards that all amount to a small generic power increase.

Keep teaching tied to actual defeated enemies. Split routes may legitimately teach more because they expose more enemy types. Joined routes should compensate through cooperation, encounter opportunities or survival, rather than automatically granting lessons from absent enemies.

Track whether learned spells are eligible, equipped and used before the summit. A full library that rarely changes the four equipped actions is weak progression.

Specific existing structures deserve experiments. Recruitment adds another action each round, while affinity practice adds a point that can later be reassigned; these rewards cannot be balanced by their labels alone. Service floors and repeated lane categories can encourage memorized routes. Seed the rendezvous position and category arrangement within constraints that still guarantee reunion, then measure reachable choice variety. For scouting, preserve one random aspect per champion but favor genuinely new threat, technique or terrain information over a redundant familiar statistic.

### Co-op social design and scale

Maintain separate ownership of squads. Friends should be able to communicate an intention without taking over another person's character.

Use the existing shared draft as the basis for small contextual pings: intended landing, planned conversion, requested target or “hold this lane.” Show ownership on the plan and mark a preview that is based on an ally's uncommitted draft. Do not require free-form chat or external voice to understand a combined volley.

Replace a whole-team unanimity requirement for a local combination with participant-scoped consent only if the existing link mechanic proves too obstructive in play. The interface should identify which actions will interact, who is participating and what they give up. Avoid a new team meter.

Experiment with joined encounters containing distinct existing roles under a controlled threat budget. Compare repeated, partly varied and authored role compositions; do not assume that maximum variety is best. At six players, repeated identical enemies create a lot of actions with little additional information, but replacing every copy with a different teacher could also erase the discovery advantage of splitting.

Freeze the room's seeded identity and every revealed scout fact. Define exactly which additional encounter slots scale with the final participant set; previews must distinguish fixed facts from participant-dependent counts. Joining, changing destination or retiring cannot reroll a revealed teacher or technique. Persist that contract and test scout → join/change/retire → launch → restore before accepting a new composition algorithm.

Keep synchronized floor progression. Let finished players watch, inspect discoveries and prepare legal loadouts while waiting. Measure waiting time before inventing another side activity. Add explicit pause/rejoin information; optional delegated control must be opted into by the squad owner, never silently assigned. Current same-seat recovery is distinct from inviting a replacement player into an active climb. Test missing credentials, a tab closed without retirement, original-seat recovery and expiry as separate cases.

### Campaign, narrative and humor

Use the ordered campaign to teach concepts and establish rival personalities. The early sequence should demonstrate movement, one basic interaction, displacement, a counter and a signature through encounters with visible consequences.

Keep the user's progression from one champion plus creatures to multiple enemy champions. Make later encounters recombine earlier lessons instead of introducing a new exception every time.

Write brief situational lines that reveal character. Treevor might inspect a collapsed wall before returning to the fight; a fire creature can look offended when extinguished. Use an approved voice sheet for names and personalities. Do not fabricate biography from a race label.

Humor belongs in reactions, creature behavior and optional room flavor. Rules, resource costs, failure explanations and network messages must remain literal. Suppress repeated barks and never pause the tactical flow for a joke.

### Onboarding, action flow and quality of life

Give the new player one short, skippable guided encounter using ordinary rules. Teach by asking for an action and then showing its consequence. Do not require reading the full interaction table or mastering the build editor before the first interesting exchange.

The first successful loop should include moving, casting, recognizing one interaction, interpreting a counter and equipping one earned spell. The same instructions must work with mouse, keyboard and touch.

Retain undo, redo, next-unplanned fighter, explicit replacements, save transfer, private invites and reconnect. Improve them rather than rebuilding familiar controls. Highlight an order invalidated by a changed landing. Show allies threatened by an area directly at the aim. Save the player's inspection position and chosen map view when switching between teammates.

### GUI and information hierarchy

Use three information levels:

- **Always visible:** selected fighter, HP/Flux, queued action, current phase, readiness and the next available command.
- **Visible during a decision:** movement cost, cast footprint, affected friends, relevant conditions and certain/conditional effects.
- **On inspection:** full source details, all rules, discovered recipes, history and exact calculations.

On desktop, retain own squad/actions on the left and enemies on the right, with a flexible battlefield between. Enemy panels can shrink to compact rows when few enemies remain. Do not reserve a tall empty rail at the expense of the map.

On phones, use a stable bottom command area and one consistent inspection sheet. Keep primary controls reachable, with large enough hit areas. Move secondary explanations into the selected-action sheet before reducing the type size. For compact landscape, use a separately tested composition rather than inheriting several incompatible width and height overrides.

Initial H.E.X. UI budgets are 16 CSS px for essential explanatory text, 13–14px for compact secondary data, and 44 × 44 CSS px hit areas for frequent actions and inspection controls. Test enlarged text up to 200%. These are proposed product targets, not values borrowed directly from a platform-pixel standard. Small visible icons can have larger hit areas. Keep the primary planning controls visible; allow an intentional detail sheet to scroll rather than compressing its contents into unreadable text.

Use logical board references consistently, but make names, portraits and map highlights the primary way to refer to actors. Coordinates are useful for precision, not as the only explanation of an event.

### Combat feedback, replay and camera

Create a structured consequence record: event identity, actor, source spell, original and final position, collision, affected cells, HP/Flux deltas, status changes, protection/cleansing reasons and duration changes. Forecasts and results should use the same vocabulary and computations where their information permits.

Show a short comic-style result near the affected actor: damage, blocked control, conversion or displacement. Expand the causal chain on demand. Group repeated terrain outcomes by region and consequence; do not announce every hex separately.

Add pause, phase stepping and replay speed to presentation only. Keep simultaneous projectile travel on one shared clock. Important contacts can receive a short emphasis without serializing casts. A local replay must not force all friends to wait for that playback.

Keep map focus under player control. Use a stable encounter view, optional fit-selection and offscreen important-event indicators. Camera motion should explain an event; decorative panning and unrequested zooming undermine planning.

### Art direction and environment

The compact fantasy pixel cast establishes the target. Preserve its proportions, grounded feet and material detail. Environment and creature work should match its pixel scale, outline weight, value grouping, lighting direction and saturation budget.

Create one reviewed style sheet with representative champion, creature, tree, wall, water, terrain transition, projectile, impact and UI icon at actual play sizes. Use the cast and environment needed by the reference encounter first. A technically nonempty atlas is not proof of visual quality.

Prioritize silhouettes and terrain readability. Walls should occupy their blocking footprint. Foreground trees should fade or outline when they obscure a fighter. Elemental surfaces must preserve enough ground shape to read height and routes.

Advance through representative batches, with contact sheets and in-game review at each step. Preserve source pixels and provenance. Stray-pixel checks should distinguish intentional particles from accidental remnants.

The relevant art precedents are [Valve's silhouette and scene-readability work](https://steamcdn-a.akamaihd.net/apps/valve/2007/NPAR07_IllustrativeRenderingInTeamFortress2.pdf), [Riot's VFX education material](https://www.riotgames.com/en/artedu/visual-effects) and [Disney's character-animation process](https://www.disneyanimation.com/process/animation/). Apply recognition, staging and coherent motion to H.E.X.'s own pixels; do not imitate another game's assets or rendering engine.

### Character animation and elemental effects

Apply anticipation, clear poses, timed release, impact and recovery. Feet should follow travel distance; plants and masonry should remain still unless acted on. Living does not mean perpetual swaying.

Use bespoke gesture and timing where it changes personality: a compact hop, a heavy planted cast, a guarded recoil or a distinctive collapse. Do not claim unique animation merely because a common transformation is applied to different sprites.

Elements need recognizable motion signatures: coherent water travel and splash, fire acceleration and breakup, solid earth impact, directional air trails, distinct Light and Dark value behavior. Advanced elements retain the base color family but gain their own icon and movement pattern.

Reserve the strongest contrast for a target centre, a travelling contact and a decisive impact. Persistent fields use quieter loops. A steam cloud can have a readable boundary and sparse interior without obscuring every actor inside.

### Audio and sound design

Fix lifecycle ownership first. Then create an audio hierarchy: critical collision or defeat, selected action, ordinary impact, terrain, ambience. Limit simultaneous voices and merge repeated effects instead of making six-player fights louder by default.

Give each element a recognizable attack and decay character. Tie cues to the same event clock as visuals. Offer independent levels for UI and combat, and a reduced-intensity option; ambience controls follow only if ambience is introduced. Separate motion preference from sound so instant or reduced-motion review retains an optional concise outcome cue. Critical information must also be visible.

The current review inspected scheduling and resource code, not a calibrated listening session. Listening on headphones, small speakers and a phone is a required acceptance step, including repeated dense exchanges and background/resume behavior.

### Accessibility, performance and reliability

Accessibility is part of the command model. Every hover fact needs touch and keyboard access. Use meaningful accessible names, visible focus and manageable map navigation. Color is supplemented by shape, pattern or text. Reduced motion preserves trajectories, phase boundaries and causality.

Measure the actual workload: initial route, selected spell aim, largest shared battle, dense interaction replay, guide opening and repeated room transitions. Record device, viewport, build, frame-time distribution, input latency, memory and network latency. Rendering a phone-sized page on a desktop is not a phone performance measurement.

Retain authoritative server ownership checks, private seat credentials, idempotent action receipts and bounded safe retries. Exercise reconnect, lost acknowledgements, stale drafts, two tabs, expired rooms, retirement and mixed viewing speeds. Shared discovery is a gameplay information policy; client-generated hidden room content is not cryptographic secrecy.

Do not start with an engine rewrite. Extract a shared combat contract and presentation adapter after documenting intentional mode differences. Consolidate active styles and lifecycle ownership in small reviewed changes. Keep legacy saves tied to their original rules and generator versions.

### Production, testing and sustainable scope

Maintain one current backlog, one rules index and one release record. Separate current routes from historical compatibility code in documentation and tooling. Source preservation is valuable; accidental imports from an old mode are not.

Use named adversarial fixtures for rules and geometry, then seeded suites for coverage. Keep browser tests semantic and behavior-based. Use visual checks for overlaps, missing frames and layered effects, and real-device sessions for performance.

The development team should review failed hypotheses and rejected experiments as carefully as successful tests. A polished system that players do not use needs redesign, not another tooltip.

### Audience, session design and product quality

The primary audience is a person who enjoys discovering tactical combinations, alone or with a small group of friends. The first session should communicate that pleasure before presenting the breadth of the catalogue. The public link, private invitation flow and lack of a required account are strengths to protect.

Measure full-run duration and interruption points rather than assume nine floors fit a convenient evening. Reliable save/resume, clear current-floor status and a comprehensible return after a week matter as much as faster animation. Packaging, current documentation and a small changelog should describe the actual game.

Use voluntary replay, friends successfully invited, and reasons for abandoning or continuing as product evidence. “Breakthrough indie hit” is an ambition; sales, retention and demand cannot be inferred from technical test counts or an attractive screenshot. Defer store, monetization and additional-platform work until the core experience earns repeat play.

## The first playable reference encounter

Use an authored pair of legal starting fighters and two or three existing enemy roles on a compact part of a larger seeded map. Include one shallow route, one solid obstruction and two viable approaches. The benchmark loadout deliberately includes pressure, setup and displacement. Preserve unrestricted legal customization in the actual game, then test contrasting custom pairs against this encounter; a kit without displacement cannot be required to demonstrate a displacement plan.

The encounter must support at least three useful plans: direct pressure, positional displacement and an elemental setup. It must contain a clear counter to each. One planned projectile interaction, one terrain conversion and one meaningful status are enough to judge the loop.

Run the same design as solo and as a two-player shared encounter, then scale the composition and space to four and six players. Scale only after the two-player version is understandable. Keep the nine-floor Tower available; this fixture is an internal quality reference, not another public mode.

The complete slice includes choosing the squad, a minimal skippable introduction, inspecting a known risk, planning, resolving, understanding the outcome, learning an enemy spell, deciding whether to equip it and selecting the next route. Its teacher must yield an eligible useful spell for the authored benchmark party. Art, sound and UI must be judged in that complete loop. Generalizing this introduction through the campaign is later work; a comprehension study must not depend on a lesson that has not yet been built.

## Implementation sequence and dependencies

Effort below is relative engineering/content effort, not a delivery date. S means a bounded component or rule; M means several connected components; L means a cross-system change requiring playtesting.

| Work item | Owner | Depends on | Implementation boundary | Acceptance | Effort |
| --- | --- | --- | --- | --- | --- |
| A1 Rules and mode contracts | Systems lead + integration | None | Document phase ordering, effect allegiance, status expiry, mode differences and save profiles. | Every active mode has an explicit behavior matrix; legacy fixtures remain stable. | M |
| A2 Reproduce and repair contradictions | Systems + independent test author | A1 | Sunburst role, Arena projectile contact, stale creature counterplay, protection/duration fixtures and explicit coverage of each effect channel. Resource/force tuning waits for evidence. | No advertised effect silently cancels itself; descriptions/contact/forecast/results match the intended current rules, with old replays preserved. | M |
| A3 Command layout repair | UX engineer + accessibility reviewer | None | Compact landscape overlap, readable phone details, target sizes, selected-action hierarchy. | Core commands readable and reachable at width/height matrix and enlarged text. | M |
| A4 Audio lifecycle | Audio engineer + QA | None | Context ownership, cancel versus disposal, repeated activation. | Repeated room entry/exit leaves no owned live context or scheduled voice. | S |
| A5 Device and workload baseline | Integration + performance/accessibility reviewer | None | Identify supported test devices and capture command, replay, six-seat and repeated-room workloads. | Named devices, exact build and baseline distributions; budgets agreed before increasing effect density or encounter count. | S–M |
| B1 Consequence records | Systems owner + replay/UI owner | A1–A2 | Start with the reference encounter's source/target/HP/status/contact fields; extend to the full grammar after acceptance. | A player can inspect why each supported change occurred; replay events conserve totals. | M then L |
| B2 Reference encounter | Encounter designer | A2–A3, thin B1 | Existing actors, three viable tactical plans, clear counters, terrain and a minimal skippable lesson. | Develop fixtures first; accept the complete loop jointly with the bounded B3 and B4 work through solo/two-player comprehension and decision-quality gates. | M |
| B3 AI action evaluation | AI engineer + systems reviewer | A1–A2 | Bounded joint move/cast scoring and team coordination. | Public-state-only decisions, deterministic replay, useful movement and no unexplained or uncompensated ally harm in named fixtures. | L |
| B4 Art and sound reference batch | Art/VFX/audio owners | A5, B1, B2 fixture | Keep the slice's champions as the quality reference; improve its creature, terrain transition, non-Steam interaction and essential cues first. Extend to six families after acceptance. | Joint B2 gate: readable at actual sizes, coherent style, clear contacts, listening and reduced-motion review within device budgets. | M then L |
| C1 Co-op composition and communication | Co-op + encounter owners | B2–B3 | Participant-owned drafts, local combination consent, role composition, wait/rejoin states. | Two/four/six players can coordinate without voice; joining/splitting each have a useful context. | L |
| C2 Procedural encounter motifs | Level designer + generator engineer | B2–B3 | Topology before decoration, contact distance and deployment checks. | Seeded maps retain alternative approaches and valid deployment at each party size. | L |
| C3 Reward and build usefulness | Progression designer | B2–B3 | Eligible reward comparison, earned teaching use, recovery/training/recruit tradeoffs. | No accidental dead offers; distinct choices change observed plans. | M |
| D1 First-session learning and campaign | UX + narrative/encounter designers | B2, C3 | Skippable ordinary-rule lesson, staged campaign concepts, contextual character moments. | Unfamiliar players complete the first loop and transfer a lesson to a new encounter. | M |
| D2 Remaining cast and creatures | Art + character/encounter designers | B4, C1–C3 | Expand reviewed style/role standards in batches. | Every signature/creature has a use case, counter and recognizable presentation. | L |
| D3 Consolidation and release | Integration + QA | All accepted work | Shared contracts, active CSS cleanup, retention policy, performance budgets, docs. | Old saves/invites work; six-seat fault tests, device checks and exact-build release checks pass. | L |

A1–A5 can begin in parallel across the three specialist lanes, with integration owning the baseline. B1 is a shared contract and needs one owner; downstream teams consume it. Do not let several agents independently modify the large battlefield renderer or the same resolver. The complete B2 loop, with bounded B3 intelligence and B4 presentation, is the first design decision gate. If its learning and tactical choices are weak, revise it before spreading the design across the catalogue.

Release incrementally:

1. **Repair release:** A1–A4, the minimum B1 explanation needed for the reproduced defects, and targeted regressions; A5 records the performance baseline in parallel. Do not wait for new art or the full roadmap to repair a broken spell or unreadable command.
2. **Reference-loop candidate:** B2, a bounded B3 AI pass and the B4 art/sound sample. Test the complete choice → exchange → explanation → reward loop with unfamiliar players before a broad rollout.
3. **Co-op and procedural candidate:** accepted C1–C3 changes, tested at two, four and six seats. Include mixed service/combat floors and one absent player.
4. **Catalogue and campaign solidification:** D1–D3 in small batches. Each release receives compatibility and online/device checks appropriate to its changes. D3 is the final consolidation gate, not a reason to delay earlier safe fixes.

## Agent delegation and review protocol

With four concurrent slots, use one integration owner and three independent lanes. Rotate specialties as dependencies change instead of creating many overlapping edits.

| Stage | Lane 1 | Lane 2 | Lane 3 | Integration owner |
| --- | --- | --- | --- | --- |
| Contracts and repairs | Rules + resolver fixtures | UX + responsive input | Audio lifecycle + presentation audit | Mode matrix, original cast contract, test selection |
| Reference encounter | AI + spell tradeoffs | Encounter + progression | Replay/VFX/art reference | Shared consequence schema and end-to-end integration |
| Co-op and scale | Server/draft/consent | Map topology + encounter budgets | Communication + phone/accessibility | Six-seat scenarios, performance and save compatibility |
| Solidification | Independent systems review | Unfamiliar-player study and analysis | Asset/audio/device review | Release qualification and current documentation |

Every work item has one code owner and a reviewer from another lane. Reviewers check the player's decision and failure path as well as code correctness. A designer must not certify their own balance hypothesis solely with a bot they also tuned.

Use `rg`, TypeScript, small Node resolver fixtures, deterministic seed probes, browser UI inspection, image contact sheets, frame-time profiling and a structured playtest sheet. Use the existing test framework and production Worker for service tests. Keep raw results and the exact source identity with each decision.

## What would show that the result is right

The following are proposed acceptance targets. They are not measurements already achieved.

| Question | Method and sample | Initial gate |
| --- | --- | --- |
| Can people understand a round? | Five unfamiliar players for discovery, repair observed problems, then a fresh cohort on the candidate. Observe without explaining and test transfer to a new example. | On one frozen candidate, at least 4 of 5 distinguish movement/casting, identify a collision's result and explain a health/status cause. Repeat with a larger cohort before generalizing; never pool results across changed builds. |
| Can they act without fighting the UI? | Mouse, keyboard and touch tasks: plan, undo, inspect enemy, inspect status, replace spell, join friend. Record squad selection, instruction and independent planning time separately, including a skipped-lesson path. | No blocked core task; first independent legal plan within three minutes of receiving control after any chosen lesson; no overlapping commands at tested sizes. |
| Is there tactical choice? | Fixed encounters plus open play, with distinct direct/setup/displacement approaches. | At least three plans have a defensible use; players can explain a tradeoff. Repeated selection alone is not proof of dominance. |
| Does joining help without making splitting pointless? | Separate novice and experienced groups at 2, 4 and 6 seats; same seeds and comparable builds. | Both structures are voluntarily used for identifiable reasons. Record clear time, loss, learning and assistance costs; investigate any universal strategy. |
| Is pacing acceptable? | Record planning, playback, travel-only turns, fight rounds and floor waiting separately. | Initially target ordinary fights around 4–7 rounds and a 90th percentile below 10; bosses may be longer. Treat deviations as diagnostic, not an automatic damage buff. |
| Is waiting tolerable? | Observe per-player shared fights and split-floor barriers, including a slower reader; separate intentional inspection/watching from involuntary idle time. | No forced playback-speed agreement. Compare involuntary idle time with the baseline by floor type and player; use 20% only as an investigation trigger in shared combat, not a pass/fail limit for mixed service/combat floors. Preserve synchronized floors and time to understand. |
| Are spells and rewards useful? | Mechanical catalogue coverage plus offer/pick/equip/use records by seed, starter, floor and skill cohort; inspect outliers. | Every definition has an automated legality/effect fixture. Human usefulness is evaluated by representative role/build families first; expand the sample for neglected or dominant options. Duplicate or unusable offers are explicit. |
| Is it visually and audibly readable? | Blind identification tasks, reduced motion, color-difference simulations, actual-size screenshots and listening sessions. | Players recognize six element families, target centre, contact, status and ownership without relying only on color or sound. |
| Does it run well? | Named desktop and real midrange Android/iPhone devices; dense 6-player scene and repeated room transitions. | Set budgets after baseline capture; initial targets are responsive commands under 100ms locally, stable 30fps minimum on supported phones and no accumulating resources. Report p95/p99 stalls, not only averages. |
| Does the online game preserve trust? | Real Worker/D1 with simultaneous actions, packet loss, lost acknowledgements, stale views, refresh, retirement and expiry. | No duplicated reward/action, unauthorized order, missing committed move, broken barrier or silent save reinterpretation. |
| Do people want another run? | Offer an unprompted second seed after the session and record reasons for continuing or stopping. | Repeated voluntary play and expressed tactical intentions inform the next cycle. A ten-person study cannot establish market demand. |

Use local or explicitly opted-in diagnostic records. A compact event schema needs build/rules/generator versions, pseudonymous session, seed, lobby size, room choice, offered/chosen reward, action timing and outcome. It does not need names, chat, private seat keys or unrelated browser data.

Test scripts establish correctness; player observation establishes comprehension; repeated varied play supports balance and enjoyment; performance traces establish device behavior. These are separate release gates.

## Scope boundaries

Do not add another public mode, a larger catalogue, a job tree, an equipment economy, a second team resource, procedural dialogue, permanent stat inflation or a new engine during this cycle. Do not repaint the entire cast before the reference batch is accepted.

Do not force every combination to be stronger than its ingredients. Do not use total affinity as a complete estimate of team strength: action count, geometry, control, recovery and synergy matter. Do not make every enemy action fully predictable merely to simplify a forecast.

The next release should make one complete loop trustworthy, readable and satisfying, then extend that standard through the existing solo and co-op game.

## Evidence and implementation entry points

The [evidence index](expert-review/2026-10-20/README.md) preserves the three independent audits, native diagnostic scripts and results, screenshots and their limitations. These reports contain the detailed source references behind the findings above:

- [Combat, spells, chemistry, AI and balance](expert-review/2026-10-20/expert-audit-systems-2026-10-20.md)
- [Maps, progression, decisions, campaign and cooperation](expert-review/2026-10-20/expert-audit-experience-2026-10-20.md)
- [Art, animation, VFX, audio, interface and accessibility](expert-review/2026-10-20/expert-audit-presentation-2026-10-20.md)

Start source work in the active paths, verifying line numbers against the implementation revision:

| Concern | Current entry points |
| --- | --- |
| Mode rules and contacts | `lib/tactics-v22.ts` (Tower), `lib/tactics-v20.ts` (Story), `lib/tactics-v18.ts` (Arena), `lib/projectile-interception-v20.ts` |
| Spell profiles and truthful counterplay | `lib/spell-profile-v42.ts`, `lib/creature-spells-v20.ts`, `lib/spells-v20.ts`, `lib/combinations-v16.ts` |
| Tower composition, rewards and scouting | `lib/tower-v23.ts`, `lib/tower-shared-battle-v23.ts`, `lib/tower-scouting-actions.ts`, `lib/tower-scouting-state.ts` |
| Co-op lifecycle and synchronization | `lib/tower-rooms-v23.ts`, `app/components/CoopTowerV23.tsx` |
| Battle geometry and presentation | `app/components/PixelBattlefieldV16.tsx`, `app/components/TowerBattleV23.tsx`, `app/components/ElementEffectsV16.tsx`, `app/components/CombatCreatureV19.tsx` |
| Feedback and responsive layout | `lib/feedback-v16.ts`, `app/components/battle-command-v41.css` |

The implementation test matrix must include all seven proposed Tower starters, representative legal custom pairs including two-creature starts, all three active combat modes, current and legacy save profiles, and solo/two/four/six-seat runs. Cross spatial fixtures with timing: near-miss versus real contact, different-time crossings, move-blocked casts, current versus newly applied protection, known versus unknown orders, centre/rim effects and changed terrain. Human studies sample representative builds and suspicious outliers; automated catalogue coverage is a separate requirement.
