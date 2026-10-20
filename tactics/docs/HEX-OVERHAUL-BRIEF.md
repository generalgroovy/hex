# H.E.X. — design and implementation brief

Apply the judgment, craft and critical standards expected of a multidisciplinary team of world designers, game designers, artists and engineers with decades of shipped-game experience. Do not claim personal credentials. Produce a coherent, working game, not a collection of additional features or a speculative redesign document.

## Start with the undigested material

Play the current build. Read the actual resolution code, spell definitions, AI decisions, save formats, input handlers and rendered interface. Inspect original H.E.X. character and environment atlases, their scale, pivots and animation frames. Trace a player's first five minutes, a complete exchange, a losing fight, a reward decision and a returning multiplayer session. Treat old design documents as historical intent until verified against the running game.

For each problem, show the concrete situation, what the player sees, what the rules actually do, and how the discrepancy damages understanding, agency, expression or pacing. Prioritize problems that repeat during ordinary play. Separate live defects from latent code inconsistencies.

## Protect the identity

H.E.X. is a simultaneous elemental tactics sandbox. Players choose positions and spells; everyone moves, spells travel together, and their collisions and terrain interactions create the exchange. Winning means defeating the opposing team. The delight is making an intentional plan, seeing an unexpected but understandable interaction, and knowing what to try next.

Preserve the original cast, multi-affinity identity, four-spell loadouts plus signature, earned knowledge, procedural seeds, private multiplayer seats and cooperative tower. Keep story progression separate from match balance. Preserve saved games and protocol boundaries. A change that reduces a character to an interchangeable damage number weakens the game even if it simplifies implementation.

## Learn principles, not surface decoration

- Final Fantasy Tactics: expressive party construction, readable silhouettes and meaningful terrain.
- Fire Emblem: consequences visible at the point of commitment, clear unit identity and range information.
- Battle Brothers: material terrain, contextual detail, spatial stakes and practical interface controls.
- Gloomhaven: meaningful commitments, complementary roles and legible resolution of interacting plans.
- Slay the Spire: informed uncertainty, readable route choices and rewards that change subsequent decisions.

Do not copy their art, fiction, rules or interface wholesale. H.E.X.'s simultaneous geometry and elemental chemistry should provide its own reason to play.

## Make one coherent experience

**Gameplay:** Prefer a small set of composable, consistent rules over isolated exceptions. Every element needs an intelligible spatial and temporal personality. Setup, displacement, protection, denial and counterplay must compete with raw damage. Forecasts must reuse combat rules and clearly identify unknown enemy orders. AI may only use public information; it should exploit the same useful interactions offered to players. Defensive plans must have an opportunity cost and battles must conclude fairly.

**Interaction:** Put fighter identity, available actions, queued orders and consequences together. Make the next useful action obvious, preserve undo, and remove repeated clicks that add no decision. Keep important information visible; put secondary explanation on deliberate inspection. Keyboard, mouse and touch must all work. Never silently change an order while changing the camera or inspecting a unit.

**Art:** Use the cast's existing pixel language as the anchor: coherent scale, warm light, grounded feet, readable silhouettes and limited material palettes. Compose environments as places with connected banks, vegetation and convincing solid barriers. A wall must look impassable where it is impassable. Keep the grid subordinate to the world while retaining exact legal targeting. Motion needs a physical reason; scenery does not sway merely to appear alive.

**Animation and sound:** Anticipation, clear contact, follow-through and recovery must explain events. Movement precedes casting; simultaneous casts remain simultaneous. Distinguish projectile travel, collision, impact and lasting field effects. Use restrained, characteristic sound materials with reliable cancellation and loudness limits. Support reduced motion and explicit sound activation.

**Presentation:** Use one visual hierarchy across the mode entry, party creation, route choices, combat and rewards. Give the battlefield the space it needs. Use concise, human text and specific useful labels. Remove slogans, generic enthusiasm, repeated explanations and decoration that competes with decisions.

**Engineering:** Prefer shared pure rule/forecast helpers and scoped presentation components over another global override pile. Preserve deterministic resolution, private orders, idempotent multiplayer commands and storage recovery. Protect existing work. Do not rewrite stable systems merely for novelty.

## Execute and prove

Use specialist agents with explicit file ownership. Compare their findings, resolve disagreements against source and play, then implement connected changes. Review each other's work. Iterate from the browser, not only from code.

Verify scenarios that matter: moving then aiming, revising an order, blocked destinations, friendly fire, crossing projectiles, cover and statuses, frozen terrain, cooperative readiness, replay and saved-game recovery. Compare forecast outputs with actual resolution. Test AI choices against useful and wasteful tactical fixtures. Run relevant regressions, type checks, production build and multiplayer checks. Inspect desktop and phone layouts with real interaction.

Publish the complete validated build to the existing H.E.X. site. Report the exact improvements and their evidence, with remaining limits. Technical checks cannot certify beauty, human enjoyment or commercial success. Those need uncoached observation: can new players predict the exchange, explain a surprise, recover from a mistake, and voluntarily choose another run?

## Current acceptance priorities

1. One clear combat command hierarchy with no forced empty panel.
2. Useful conditional impact forecasts rather than nominal damage promises.
3. World materials and camera scale that support the existing character art.
4. Distinct readable phase transitions, elemental sounds and effects.
5. A concise mode entry that exposes Story, Tower (solo or with friends) and Arena.
6. Save, input, multiplayer and reduced-motion behavior retained and tested.

Reference material consulted: [Final Fantasy Tactics official overview](https://final-fantasy-tactics-the-ivalice-chronicles.square-enix-games.com/en-us), [Fire Emblem: Shadow Dragon manual](https://www.nintendo.com/eu/media/downloads/games_8/emanuals/nintendo_ds_21/Manual_NintendoDS_FireEmblemShadowDragon_EN.pdf), [Battle Brothers interface improvements](https://battlebrothersgame.com/dev-blog-91-miscellaneous-improvements/), [Battle Brothers location environments](https://battlebrothersgame.com/dev-blog-135-location-environments/).
