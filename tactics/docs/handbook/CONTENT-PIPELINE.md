# Content pipeline and extension guide

This guide is for continuing the release-45 web game, inspected on 2026-10-20 at commit `947019572508ad0e20bb1dbbfe19c0ebeeee7148`. Run commands from the web application root (`tactics/` in the combined repository). See [Art and audio](ART-AND-AUDIO.md) for atlas, effect, animation, and sound contracts.

Content is TypeScript data plus native deterministic rules, not an external database or an editor export. Stable IDs are persisted in battles, Tower runs, campaign progress, and online rooms. Before changing a definition, trace the active imports and decide whether an existing saved battle should retain its previous behavior.

## Current source map

| Content | Authority and consumers |
|---|---|
| Canonical champion identity | `lib/roster.ts` is imported from original H.E.X. identity data. `roster-v7.ts` is a separate historical roster layer; `roster-v11.ts` applies the five-point starting allocation, and `roster-v13.ts` adds current tactical descriptions from `character-design-v13.ts`. |
| Champion build rules | `character-creation-v17.ts` validates Arena companies; `campaign-workshop-v20.ts` handles campaign customization; `tower-v23.ts` validates Tower starters and later builds. Do not substitute one mode's validator for another. |
| Base and signature spells | Versioned `spells-v*.ts` form a layered registry. Current Campaign/Tower use `spells-v20.ts`; current Arena still has its native rules/adapter. `spells-v10.ts` contains the authored champion signatures; later layers adjust access, descriptions, scaling, and geometry. |
| Effective battle spell | Native `battleSpell` functions apply the persisted `spellModel`. `spell-profile-v42.ts` owns the opt-in `focused` / `focused-v44` profiles. |
| Creatures | `campaign-creatures-v19.ts` defines identity, class, family, affinities, stats, role, and perks. `campaign-creatures-v20.ts` replaces current combat kits with their authored creature techniques. |
| Creature techniques and teaching | `creature-spells-v20.ts` authors each technique; `spells-v20.ts` maps every champion/creature teacher to its unique spell. |
| Field combinations | `combinations-v16.ts` contains all 63 nonempty subsets of six base elements and their bounded mechanics. Native engines read this data. |
| Ambient inhabitants | `inhabitants-v16.ts` contains 63 species, one per element subset, with intent footprints and counters. They are not interchangeable with recruitable combat actors. |
| Story | `campaign-encounters-v20.ts`, `campaign-profile-v20.ts`, and `story-v20.ts` connect ordered champion encounters, optional creature-learning fights, and rewards. |
| Battle maps | `arena-v17.ts` generates seeded maps for 2–6 deployment sectors; `arena-v7.ts` supplies biome vocabulary. `tower-terrain-v44.ts` adds explicitly versioned Tower terrain motifs. |
| Tower routes, rooms, rewards | `tower-route-map.ts`, `tower-v23.ts`, scouting helpers, `tower-supplies-v45.ts`, and `tower-rooms-v23.ts`. The server, shared battle builder, client, and UI must agree. |
| Presentation and reference | `combat-reference.ts`, `BattleInsightV24.tsx`, `CombatReference.tsx`, `element-presentation.ts`, native host adapters, plus the art/audio modules in the companion guide. |

The registry counts read directly from current exports are **30 champions, 48 base spells, 30 signatures, 93 creature spells, 93 combat creatures, 123 unique enemy teachers, 63 combinations, and 63 ambient inhabitants**. Creatures span 13 body families, with 12 lesser, 27 standard, and 54 greater definitions. “Six spell levels” does not mean six spells per element: there are eight base spells per element across those levels.

Existing tests assert some exact counts. Extend those expectations only when an intentional content addition is wired through all relevant registries. Changing a number in a test does not complete the content.

## Rules and save compatibility before content

The active engine families are Arena `tactics-v18`, Campaign `tactics-v20`, and Tower `tactics-v22`. They present through a shared board, often using a `rulesVersion:16` view adapter. That presentation shape is not permission to resolve the battle with v16 rules.

New battles use `CURRENT_SPELL_MODEL`, currently `focused-v44`. Undefined models and the earlier `focused` value preserve earlier behavior. Similar explicit gates protect Tower motifs, supplies, and recorded projectile behavior. If an addition changes existing geometry or outcomes, introduce/version the contract deliberately; do not change a frozen engine or old seeded generator only because its filename looks old.

UI descriptions must be derived from the same effective/native spell used by legality, cost, footprint, projected volley, result calculation, and enemy AI. In particular:

- Read the current battle's saved model, not a global latest default.
- A field recipe replaces or refreshes the complete field according to the native resolver; it is not a pile of independent pair effects.
- Keep movement and target legality separate from a predicted outcome. Hidden opposing orders, or private allied orders in team Arena, can make an exact outcome unavailable.
- Preserve the four distinct configured spells plus the creator's separate signature slot. Use `spellAccess`, `spellCost`, `validateLoadout`, and `availableSpellIds`.
- Keep preview, committed result, replay, and restored result consistent. A text label or effect colour must never create new mechanics.

## Add or revise a champion

1. **Establish identity and stable ID.** Read the original H.E.X. `content/champions/foundation_champions_v1.json` and existing provenance. Preserve exact names, ancestry, body, and identity cues. `scripts/import-roster.mjs <original-root>` maps original `wind` to web `air` and writes `roster.ts` plus `docs/v4-roster-provenance.json`. It does not rebuild every later roster layer.
2. **Trace all roster layers.** Updating only `roster.ts` is insufficient: `roster-v7.ts` contains its own roster data, and current exports flow through v11/v13. If adding a new identity, introduce it coherently in the current registry while retaining historical saves. Keep old IDs valid rather than renaming them in place.
3. **Define a usable tactical kit.** Add a `CHARACTER_DESIGN` entry, legal starter spells, and deliberate upgrade suggestions. Build validators enforce the actual budget and main affinity; run them rather than trusting the proposed list. Current Arena creation spends five points, keeps the canonical primary at least two and highest, allows at most three elements, and caps initial ranks at three. Tower's validator handles later run budgets separately.
4. **Author one signature.** Keep a unique creator ID and spell ID. The creator discount and access rules belong to the spell registry, not the UI. Add the teacher mapping and check that other champions must learn the spell before equipping it. Do not place the creator's signature into its four ordinary loadout slots.
5. **Connect story and rewards.** The ordered Campaign maps champions to legacy story entries and uses roster order to compute chapters, enemy count, affinity, and creature rewards. A bare roster append can break the non-null legacy encounter lookup or silently change progression. Add the appropriate story record and test first/last chapters, unlock ordering, and defeat-to-spell teaching.
6. **Complete presentation.** Add the original atlas, packed animation sheet/audit, character motion profile, and reaction lines. `animation-assets.ts` is generated by the packer. Add a speech victory line as well as defeat/critical/Burn/Flux/fizzle responses. Inspect all views and preserve the original fallback.
7. **Verify cross-maps.** ID → roster → design → original sprite → animated sprite → motion → signature → teacher → story → starter/build. Verify the same ID survives save/restore.

Useful focused suites: `character-creation-v17.test.ts`, `character-craft-v16.test.ts`, `character-motion.test.ts`, `character-animation.test.ts`, `signature-engine-v10.test.ts`, `campaign-progression-v20.test.ts`, `campaign-workshop-v20.test.ts`, and `character-presentation-v45.test.ts`. Some signature tests intentionally target a legacy layer; supplement with active-native engine coverage rather than assuming they prove every current host.

## Add or revise a spell

Start with a tactical decision, a cost, a failure case, and a counter. Use the existing primitives before adding a new status or resolver stage. A spell definition includes identity, base element, branch, level, Flux cost, recovery, targeting range, footprint shape/radius, direct effects, target allegiance, optional self-cost, and possibly field ingredients.

Supported footprints include aimed hex/burst, line, sweep, ring, and wall. Range zero is self-centred but can still have an area. Read native `spellArea`: a line can follow the shortest open rays, a sweep is not a generic circular burst, and a ring excludes its centre. Focused profiles widen eligible shapes and apply centre/inner/rim behavior; precision spells retain their role. Never duplicate shape math in a tooltip or JSX component.

For an existing base or signature spell, find its authored layer and current wrappers before editing. A global change can affect old matches through the import chain. For a new primitive, explicitly update:

- Type and validation, access/cost, effective affinity scaling, and saved model compatibility.
- Native execution in all intended modes, including timing of statuses, Ward/cover, cleanse/dispel, self-damage, displacement, healing, drain, and field formation.
- `planned-volley-v20.ts`, `planning-forecast-v20.ts`, `target-impact-v41.ts`, and Arena's `arena-presentation-v44.ts` where applicable.
- AI valuation and legality through the active engine; do not only teach the UI the new spell.
- Reference rows and action details, exact field before/after explanation, event causes, and visual identity through `spell.branch`.
- Persistence validation and every affected replay/restore path.

For a creature technique, add an authored entry in `creature-spells-v20.ts`. Entries currently locate their creator by creature name; changing that name without the technique entry will fail. Prefer preserving the ID and update the name-based cross-reference intentionally. Its generated spell ID is `creature_spell:<creature-id>`. `spells-v20.ts` supplies one-to-one teacher maps and immutable current definitions.

Test cases should cover unaffordable casting, insufficient affinity, learned versus unlearned access, recovery, centre/inner/rim values, blocked and zero-damage outcomes, allied/hostile targeting, simultaneous opposing spells meeting before their target, and restored replay. For support effects, test timing: next-round Ward must not absorb an earlier simultaneous hit. For status duration, test actual planning rounds rather than just a displayed number.

Useful suites: `spell-profile-v42.test.ts`, `combat-contract-v44.test.ts`, `target-impact-v41.test.ts`, `projectile-contact-v23.test.ts`, `mixed-projectile-v20.test.ts`, `decision-explanations-v44.test.ts`, `creature-spells-v20.test.ts`, and the relevant Campaign/Tower/Arena native tests.

## Add or revise a creature

There are two related systems:

- An **ambient inhabitant** has a species ID, ingredients, body family, preference, periodic footprint, and counter element. It can affect the map without joining a team.
- A **combat creature** has an actor identity, strength class, role, health/Flux limits, fixed kit, team perk, and teachable technique. Its `championId` is a mechanics proxy, not its displayed species.

Pure combat creatures are authored in `pureEntries` in `campaign-creatures-v19.ts`. Mixed combat creatures are derived from mixed `INHABITANT_SPECIES`, with role/class/perk choices derived from their field. Current v20 kits replace the leading move with the creature's unique technique. Adding an ambient mixed species therefore has wider consequences than adding a decorative model.

Choose an existing body family if it accurately fits. If a new family is necessary, extend the family type, `CreatureBodyV19`, ambient renderer, motion/material-shadow maps, and speech sound mapping. Use the actual creature name, family, elements, class, and perk in cards and inspectors. Never expose its proxy champion race, signature, or configurable champion kit as if those belonged to the creature.

A creature perk requires a different living compatible companion. Current benefits are bounded, require proximity within two hexes of both participants, and matching benefits do not stack. Test death, overlap, range boundaries, multiple compatible companions, and post-effect timing. A reward preview must show the actual perk and moves before the player commits.

Connect acquisition: campaign availability/field encounters, Tower encounter and recruit pools, starter restrictions, and unique spell teaching on defeat. Verify that losing a fight does not accidentally discard techniques the mode is supposed to retain, and that a fixed creature kit cannot be edited as a champion.

Useful suites: `campaign-creatures-v19.test.ts`, `campaign-creature-render-v19.test.ts`, `creature-spells-v20.test.ts`, `campaign-progression-v20.test.ts`, `tower-starters.test.ts`, `tower-reward-preview-v42.test.ts`, and `tower-battle-render-v23.test.ts`.

## Add or revise an elemental combination

All nonempty subsets of Fire, Water, Earth, Air, Light, and Dark already exist: six singles, 15 pairs, 20 triples, 15 quadruples, six quintuples, and one six-element field. There is no unfilled seventh-element slot. A new base element would be a schema/protocol/rules expansion, not a content-row addition.

`ELEMENT_ORDER` defines the bit positions. Keep masks, IDs, ingredient membership, and persisted references stable. Each field is one phenomenon with one complete mechanics record; subset reactions do not also run underneath it. Change the current rule only through a deliberate compatibility decision.

The data grammar includes movement type, damage scaling, cover, hazard trigger, healing, Flux, status application, cleanse, spring bonus, and consume. New semantics require native implementation, preview and AI support; a new `shortRule` alone does nothing.

For a changed field, verify formation versus refresh, natural terrain conversion, lifetime/expiration, displacement into/out of the field, environmental damage cap, status protections, both teams, and order independence. Update the matching ambient species/creature technique if its stated behavior would become false. Check the dominant visual family, actual material variant, accessible description, and audio cue rather than assigning appearance by ingredient count.

Useful suites: `combinations-v12.test.ts`, `element-fields-v8.test.ts`, `inhabitants-v12.test.ts`, `reactive-environment-v17.test.ts`, `world-readability-v24.test.ts`, `clash-combat-v16.test.ts`, and active v20/v22 native contract tests. Several historical suites exercise earlier contracts; new behavior needs an explicit current-model fixture.

## Add a map or Tower route/room

Battle maps and Tower route maps are different data.

**Battle map.** `arena-v17.ts` normalizes IDs such as `arena:2:WELLSPRING`. It hashes the full canonical ID and uses a seeded generator; the same accepted ID must preserve geometry. Radius is `playerCount + 7`, with `1 + 3r(r+1)` hexes. Deployment sectors have equal radial distance, distinct camps, and open approaches. Generation repairs disconnected walkable pockets, preserves spring cells, and caches immutable results.

Do not insert `Math.random()` or change random draw order in an existing generator if old map IDs must replay. Add a new versioned suffix/model. Current Tower motifs use `:m44-crossing`, `:m44-courtyard`, and `:m44-grove`; the parser and generator both recognize them. A new motif needs validated syntax, readable terrain stamp, safe deployment/centre, connectivity checks, geometry-aware preview text, and save restoration.

Terrain art is not collision data. Wall edges should visibly join, but a decorative prop must not block a legal cell. Test movement effort, water-to-ice slide stopping, height and cover, shortest firing lines, blocked displacement, and camera bounds alongside connectivity.

**Tower route.** `tower-route-map.ts` creates a nine-floor graph. Normal floor width is `routePlayers + 2` (three solo, eight for six players); the last floor has one boss room. `routePlayers` is captured from occupied seats at launch and persists, rather than changing after disconnects or retirements. Missing legacy values retain the original three-lane layout. Wider graphs retain a lane, a nearby alternative, and a common meeting route.

Room choice uses reachability, not every visible node. In co-op, choosing the same room builds a shared battle; choosing different rooms permits simultaneous separate fights, then waits at the floor barrier. Route changes must preserve both cases, spectators, reconnect, retirement, and the actor-specific visible/scouted information.

Room content and rewards are seeded in `tower-v23.ts`. Merely inserting an item into a shuffled array can alter old runs. Use the existing model gates or add a new gate for new selection behavior. Scouting exposes selected aspects through the public view; do not render hidden full enemies just because the client has a deterministic seed.

Useful suites: `arena-v17.test.ts`, `arena-seeds.test.ts`, `tower-route-map.test.ts`, `tower-route-scaling-v42.test.ts`, `tower-scaling-review-v42.test.ts`, `tower-scouting-service.test.ts`, `tower-shared-battle-v23.test.ts`, `tower-experience-v44.test.ts`, and `tower-transport-v43.test.ts`. HTTP smoke tests provide additional service evidence after the actual app is built; pure graph tests are not multiplayer transport tests.

## Add a Tower charm, scroll, or reward

Release 45 uses `tower-supplies-v45.ts` and the optional persisted `suppliesModel:'v45'`. Charms and scrolls are carried by an actor; transfers/swaps, battle creation, spent-scroll retention, shared battles, reward recipient selection, and restore validation must agree.

A scroll is one cast at zero Flux, without an affinity requirement, using printed strength. It is not an extra permanent learned spell. Preserve its explicit order/event marker through legality, projected interactions, native resolution, replay, and restoration. The board's `spellForCast` adapter must receive the recorded boolean during replay.

Use the actual reward recipient and show what will be replaced. Check that neither changing a party slot nor finishing a shared encounter duplicates a supply or resurrects a spent scroll. Relevant suites: `tower-supplies-v45.test.ts`, `tower-supplies-service-v45.test.ts`, and `tower-supplies-render-v45.test.ts`.

## Accepted raw-art input manifest

The handoff bundles these exact accepted inputs under `asset-sources/frames/`; see [the asset-source README](../../asset-sources/README.md). Names come from the accepted per-character audits, not an earlier prompt batch:

| Directory | Files |
|---|---|
| `raw-a/` | `djonah_thaan-corrected.png`, `dr_apex.png`, `fluup.png`, `grace_reava.png`, `haara.png`, `ha_rekt.png`, `leaf_hidden.png`, `nico_lai.png`, `oh_tipi.png`, `oll_i.png`, `red_baron.png`, `spai_si.png`, `steezo.png`, `s_wayne.png`, `treevor_mason.png`, `wa_bidi.png` |
| `raw-b/` | `ba_djoh.png`, `biggy_bob.png`, `donnok.png`, `faab_i_yaina.png`, `fimu_yashiha.png`, `grimm_bow.png`, `hesus_christo.png`, `h_le_ne.png`, `jan_wicked.png`, `joh_haynes.png`, `juul_i_yaina.png`, `luuh_i_zeh.png`, `sai_laas.png`, `urzh.png` |

`asset-sources/environment/reactive-props-v17.png` is the accepted source whose SHA-256 is `f266d4a20d2cd2b903cf413415ee64bbd9baf25b7ce866346a2f32b96a69e410`. The character source hashes are in `docs/animation-assets/*.json`; all 30 matched the available inputs during this pass.

When packing, derive the output ID from the character audit, not blindly from the filename: `djonah_thaan-corrected.png` produces `djonah_thaan.webp`. Juul I Yaina additionally requires `2,4` as the packer's third argument. No other current character audit marks a mirrored packing cel. Preserve the corrected source and flags when recreating the accepted set.

The packers overwrite output files, audit source paths, and the animated-ID list. Use a reviewable working copy and compare hashes/decoded pixels before accepting a re-pack. All 30 accepted character inputs and the accepted environment input were repacked in isolated scratch during this handoff check; all 32 resulting runtime outputs matched the shipped hashes with Node v24.18.0 and Sharp 0.35.4 on Windows. Re-running image generation from a saved prompt is new artwork, not deterministic reconstruction. Do not delete original inputs after producing smaller runtime files.

## Review and validation sequence

1. State the player decision the content adds, its cost/counter, intended mode, and save compatibility.
2. Implement data and native rules; add a focused test with a real state and meaningful expected consequence.
3. Wire native previews, descriptions, AI, teaching/rewards, persistence, and presentation. Audit the cross-maps above.
4. Run the affected native and presentation suites, then type-check/build through the repository's normal verification process.
5. Play the real selection → planning → exchange → review → progression path. Check mouse, keyboard, touch, portrait and short landscape, sound off, reduced motion, local reload, and multiplayer where affected.
6. Review asset contact sheets and in-game silhouettes, not just file hashes. Listen to sound at normal and reduced levels. Record actual CSS viewport dimensions.
7. Update provenance and the release evidence with the exact source revision, commands, failures, and limits. A successful bot diagnostic is not proof of player fun or balance across all tactics.

Example focused invocation:

```sh
node --experimental-strip-types --test --test-concurrency=1 tests/creature-spells-v20.test.ts tests/campaign-progression-v20.test.ts
```

Select the relevant tests; do not treat every old version's test as current gameplay authority. Keep a saved-state fixture for a behavioral change and test both its old model and the new model. The objective is a coherent extension that can be understood, countered, rendered, saved, and replayed—not a catalogue entry that merely compiles.
