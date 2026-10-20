# Experience audit: Confluence, rules 12

Independent audit 2 of 4. Source inspected before implementation: active rules-11 client, battlefield, terrain generation, spell/field rules, story, character renderer, audio, CSS, and original H.E.X. runtime art inventory. No browser or human playtest was performed by this auditor. Findings describe source-supported risks, not measured player behaviour.

## Twenty-four areas

| Area | Finding and proposal | Acceptance |
|---|---|---|
| Identity | Simultaneous prediction and changing terrain are the distinctive activity. Let visible landscape changes carry that identity. | New players identify prediction and elemental terrain as the central activity after one encounter. |
| Turn structure | Separate queued-order, aim, action, and review blocks repeat context. Consolidate one character strip, action tray, target readout, and commit control. | Three complete character plans require no secondary panel; one primary commit button per viewport. |
| Tactics | Displacement, guard, frozen routes, and objectives already offer decisions. Preview landings, footprints, and important field consequences spatially. | Preview and deterministic resolution agree, accounting for hidden opponents. |
| Elements | Rules 11 runs constituent pairs underneath larger mixtures. Give each exact subset a bounded named field. | All 63 subsets have identity; permutation does not change outcome; no underlying pair stack. |
| Spells | Full card metadata is useful reference but dense during targeting. Show current cost, shape, and useful consequence first. | Two available actions can be compared without scrolling the board away. |
| Characters and races | Original champion sprites preserve identity. NPCs need anatomy and behaviour, not only recolouring. | Representative creatures remain distinguishable without labels or colour alone. |
| Composition | Affinities and movesets are visible but coverage remains implicit. Offer only actionable, build-dependent hints. | Changing a relevant spell changes its hint; no unsupported optimal-team score. |
| Progression | Story-earned affinity is sound; early setup exposes many concepts at once. Start with a usable company and surface training after rewards. | A new player starts immediately; an earned point is easy to assign. |
| Resources and statuses | Active status consequences are scattered among duplicated identity/resource summaries. Use concise consequence wording. | Players infer movement and spell cost from the selected-character view. |
| Objectives | Scores, well income, affinity, round and phase occupy separate strips. Consolidate score/round/income. | Players can explain who leads and what scores next without the log. |
| Maps | Individual extruded plates and tiny SVG props make the landscape board-like. Use continuous ground, actual exposed cliffs and original environment art. | Equal-height neighbours read as connected land; selectable cells remain usable. |
| Procedural generation | Connected mirrored patches protect fairness but look regular. Use a separate deterministic decoration layer. | Repeated seed reproduces art; art changes do not affect navigation or combat. |
| Balance | Equal affinity is a gauge, not evidence of equal compositions. Bound combination effects and expose tradeoffs. | No unbounded stacked effects or accidental seat-order advantage. |
| Story | Encounters currently pair champions with other champions. Add actual elemental inhabitants to the battlefield alongside them. | Every species occurs in reachable content and affects real encounters. |
| AI | Existing decisions evaluate objectives and spells. NPCs should telegraph simple, recognizable habits. | Repeated behaviour can be anticipated; no hidden-order access. |
| Multiplayer | Private rooms, frozen libraries and versioned engines are valuable. Extend strict state restoration to new materials/entities. | Reconnect and rematch retain exact state and deterministic resolution. |
| Onboarding | The full rules guide is long. Introduce one useful idea at a time through early encounters. | A fresh player intentionally makes a reaction without reading the whole guide. |
| Interface | Identity, affinity, resources and pending orders repeat. Keep who/what/where/consequence as the permanent hierarchy. | Default combat view contains no repeated full selected-character detail. |
| Controls and mobile | Short-height CSS shrinks the rules-11 battlefield to148px. Reclaim space from duplicate metadata and details. |320x568 and390x844 support targeting, reachable actions and no horizontal overflow. |
| Visuals and animation | Character motion/material effects exist, but no environment atlases were shipped. Reuse the original Wellspring v3 art with grounded depth and canopy fade. | Characters and targets stay visible; scale/light match; reduced motion stays legible. |
| Audio | Existing tones mostly transpose a small shared vocabulary. Give materials distinct envelopes, frequencies and timbres. | Major materials are audibly differentiated; busy resolutions remain bounded. |
| Accessibility | Focus, reduced motion and keyboard controls exist. Preserve texture/shape distinctions and readable concise text. | Keyboard-only and grayscale/reduced-motion play retain tactical information. |
| Pacing and replayability |63 recipes risk more memorization than decisions. Stage discovery and limit active creatures per encounter. | Later encounters deepen choices without excessive catalogue reading. |
| Validation | Automated checks cannot prove fun or intuition. Combine rule tests with real viewport interaction and fresh-player observation. | Players explain outcomes, recover mistaken orders, and want to try another tactic. |

## Five priorities agreed for implementation

1. Continuous landscape using existing Wellspring props/surfaces, exposed cliffs and biome-safe decoration.
2. Consolidated combat hierarchy that gives the board more space.
3. Canonical bounded exact-subset recipes shared across engine, preview, AI and reference.
4. Actual story inhabitants with visible intent and ways to interrupt.
5. Determinism, save/room compatibility, small-screen usability, and honest distinction between automated evidence and human enjoyment.

## Art provenance and local implementation evidence

The original `assets/environment/wellspring_v3/{props,surfaces}.png` files were copied intact into `public/pixel/environment/`. Its manifest records byte hashes, original provenance, grid and foot anchor. Original H.E.X. files were not modified. Assets remain presentation-only.

The renderer now uses equal-height continuous ground; cliff faces occur only on camera-facing lower-neighbour or outer-boundary edges. Trees occur only on forest cover, walls only on ruins, and open-ground flowers remain small. Props and characters share depth ordering; canopy fades around current and planned character positions. Creature inspection is independent of order input. Public intent footprints and exact material forecasts include natural ground, known spells, creature pulses and known counterspell interruption.

Focused tests cover edge geometry, decoration determinism and biome semantics, atlas byte/grid identity, natural-ground and creature-aware forecast parity, deliberate freezing, material envelopes, cue order invariance, interrupted-creature feedback, audio activation races and voice cleanup/budget. Browser visual validation and full integration belong to the integration owner; passing these tests alone does not establish visual quality, comfortable phone play or enjoyment.
