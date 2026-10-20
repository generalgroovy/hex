# H.E.X. — readable tactical consequences

## Design judgement

H.E.X.'s strongest identity is simultaneous movement followed by simultaneous spellcasting, with projectiles and terrain combining. Its distinguishing decision is not simply which enemy to damage: it is where to place a spell so its centre, outer area, allied volley, travelling projectile and resulting terrain work together. The present work strengthens that decision instead of adding another mode, resource or content layer.

Raw material for this review was the active Story, Tower and Arena resolvers, their public-state AI, replay validation, actual reward construction, shared command interface, pixel atlas alpha channels, and the application's rendered desktop/phone states. Promotional descriptions and previous design documents were not treated as proof of implemented behaviour.

Three implementation agents independently reviewed tactical systems, player decisions, and art integrity. The coordinating agent reviewed the integration, designed the public enemy threat envelope, and owns final verification. Four concurrent lanes use separate files where possible; the shared battlefield renderer has one integration owner.

## Related games: principle, evidence, H.E.X. application

| Source | Principle supported by the source | Application and boundary |
| --- | --- | --- |
| [Into the Breach postmortem, Subset Games / GDC](https://media.gdcvault.com/gdc2019/presentations/Into%20the%20Breach%20Postmortem%20Final.pdf), especially slides 7, 13, 20, 30–36 and 42–44 | Readability and a small decision space are design constraints. Deterministic consequences, displacement and visible future consequences can carry substantial depth. UI difficulties can reveal a problem in a mechanic. | Show conditional shove/contact results and public movement/spell possibilities. H.E.X. keeps hidden simultaneous opponent orders; it does not inherit fully telegraphed enemy attacks or a different victory condition. |
| [Slay the Spire: metrics-driven design and balance, Mega Crit / GDC](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf) | A choice should have a useful role. Metrics need interpretation and player-skill context. Repeated feedback and iteration are essential. | Show the actual changes a Tower reward makes to the current party. Run fixed-seed starter diagnostics and separate their correctness/pacing evidence from human balance. Do not use a single bot win rate to retune champions. |
| [The World of Gloomhaven, Cephalofair](https://cephalofair.com/pages/the-world-of-gloomhaven) | Distinct classes and constrained action commitments create complementary roles. Advancement includes selecting between meaningful alternatives. | Keep four equipped spells, elemental affinities, and signature identity. Broader footprints gain centre/rim tradeoffs instead of making every spell an identical circle; precision displacement and directional shapes remain distinct. This is a design inference, not a claim that Gloomhaven uses H.E.X.'s system. |
| [Fire Emblem: Shadow Dragon manual, Nintendo](https://www.nintendo.com/eu/media/downloads/games_8/emanuals/nintendo_ds_21/Manual_NintendoDS_FireEmblemShadowDragon_EN.pdf), pp. 14–15, 20–21, 24–25 | Movement/attack information, combat forecasts and preparation support informed decisions. | Enemy hover, keyboard focus and touch inspection expose legal movement and ready-spell reach. The envelope includes affected hexes beyond the aim centre and possible movement before casting. Forecasts stay explicitly conditional on unknown movement/Guard. |
| [Battle Brothers: reworked UI, Overhype Studios](https://battlebrothersgame.com/dev-blog-75-progress-update-reworked-ui/), [miscellaneous improvements](https://battlebrothersgame.com/dev-blog-91-miscellaneous-improvements/) | Named status tooltips reduce memorisation. UI and scene scale can be treated separately. Traversable spaces need readable presentation. | Use concise action summaries with detailed inspection. Retain the current atlas style, improve responsive frame addressing, and draw enemy range boundaries rather than another full coloured grid. |
| [Final Fantasy Tactics: The Ivalice Chronicles makeover, developer interview](https://blog.playstation.com/2025/07/21/the-secrets-behind-final-fantasy-tactics-the-ivalice-chronicles-makeover/) | Modern controls and contextual information can improve access to an established tactical system without discarding its identity. | Improve the selected action and reward interfaces around H.E.X.'s existing rules. No job-tree imitation or unrelated rules expansion is needed to make the current game easier to understand. |
| [Dota 2 Character Art Guide, Valve](https://help.steampowered.com/en/faqs/view/0688-7692-4D5A-1935), [Sprite Atlas reference, Unity](https://docs.unity.com/en-us/engine/6000.3/manual/unity2d/sprite/atlas/sprite-atlas-reference) | Silhouette/contrast hierarchy and exact atlas sampling support visual recognition. Padding and filtering matter to pixel boundaries. | Keep H.E.X.'s characters and deliberate particles. Correct only verified visible remnants; reject wrong-dimension atlases and sample each animation frame proportionally at responsive sizes. |

## Findings and implementation

### 1. Spell area must create positioning decisions

Previously a large part of the catalogue used a single affected hex, and existing bursts used uniform power. This made a “bigger” spell mostly a coverage upgrade, with little reason to choose one part of its footprint over another.

New battles opt into the `focused` spell model. Ordinary targeted hex/burst spells become bursts with a radius of at least two. Self casts, deliberately precise tools, lines, fans, walls and rings retain their identities. This preserves the importance of displacement direction and shaped coverage.

Focused damage/healing spells have a deterministic centre bonus, normal inner-ring strength and weaker outer-ring strength. The edge keeps terrain ingredients, but does not apply direct control statuses. This makes centre placement, partial coverage, friendly fire, and field preparation separate considerations. A centre bonus is not a random critical chance.

The same profile is used by actual resolution, AI evaluation, projected volleys and targeting information. Existing saved encounters retain their prior spell model and replay geometry. Newly created encounters use the new model; a save is not silently reinterpreted.

### 2. Public threat should be visible without exposing private plans

The enemy envelope unions every legal destination with every ready spell's affected area from that destination. It includes the current hex, terrain and elevation restrictions, control statuses, current Flux, recovery and area beyond the aim point. It deliberately has no access to either side's submitted plan.

“Spell reach” is an envelope of possibilities, not a promise of damage and not a revealed enemy action. A spell can be support, terrain preparation or harm. Movement and spell reach use distinct boundaries. Repeated inspection caches results for the immutable battle snapshot.

### 3. Displacement consequences were understated

The direct-damage preview could show no spell damage for a useful shove while omitting the actual wall impact or dangerous landing. The new preview uses the authoritative displacement geometry and resistance rules. It reports net forces, blockers, wall impact, ice travel, landing effects and environmental damage separately from direct spell damage.

Enemy Guard is unknown, so the interface shows the two relevant branches. The forecast states its survival/stationary assumptions. It does not pretend to predict the whole exchange or include unknown opposing casts.

### 4. Rewards needed current-party consequences

Generic affinity text hid whether a reward improved damage, healing, reach, Flux cost, status duration, or unlocked an already learned spell. Shared Solo/Friends reward cards now calculate equipped-spell changes and eligible recipients against the actual party. Recovery previews cap healing per fighter and expose unused healing.

This addresses an information failure before changing reward frequencies. Draft diversity and campaign-long build balance require a larger longitudinal player sample; they are not inferred from opening-fight bot diagnostics.

### 5. Art quality needed pixel evidence

Decoded inspection covers all 1,440 animated character frames and 960 original fallback frames. Transparent pixels can contain arbitrary RGB data; that is not a visible defect and should not be “cleaned” by damaging nearby art. Nine isolated dark remnants were verified in six characters. Exact renderer masks remove those nine visible pixels while retaining original asset bytes and intentional particles.

Proportional atlas addressing replaces fixed-pixel assumptions when sprites resize. Atlas loading validates image dimensions and retains the original-art fallback. Tests check nonempty frames, transparent edges, alpha integrity, mask coordinates and unchanged scenery assets.

### 6. Parallel routes must support the actual lobby

New climbs allocate two more regular rooms per floor than the number of players present at launch: three for solo, four for two players, through eight for six. This leaves alternatives even when everyone initially splits. The summit remains a single shared destination.

The launch size is saved with the run. Disconnection, defeat and retirement do not redraw the graph, invalidate a scouted room, or change a submitted choice. Older saves retain their original three-lane routes. Wider seeded paths retain a common next-floor meeting room so squads can regroup after splitting; per-room enemy strength still depends on the squads entering that battle, not the number of available doors.

Each champion still scouts one additional detail per floor, and unrevealed enemy techniques remain uncertain. The map expands horizontally instead of shrinking active hexes below a useful touch size. Stable path letters distinguish rooms with repeated service names. Only the selected room's detailed report is expanded.

## What would establish that the change is right?

- Resolver/preview parity: centre, inner ring, rim, resistance, healing caps, displacement and projectile contact must agree with resolved outcomes.
- Compatibility: pre-change saves and newly focused encounters must restore with their respective geometry; old replay events must remain valid.
- Multiplayer: actual six-seat HTTP rooms must enforce private access, independent choices, shared combat and floor barriers with the same rules as clients.
- Route scaling: launch sizes one through six must produce the expected deterministic width, preserve legacy saves and rejoining paths, and retain room identity through reconnects and retirement.
- Presentation: desktop and narrow phone views must expose the selected action, consequences and touch inspection without clipped primary controls.
- Bounded pacing diagnostics: all seven suggested starters should produce legal decisions and terminate through elimination on fixed seeds. This detects regressions, not human balance.
- Human play: unfamiliar players should be able to explain a queued action, distinguish aim distance from area, identify why a centre hit is stronger, and describe a collision after replay. Repeated voluntary play and varied viable choices are the evidence for enjoyment and depth; automated tests cannot establish either.

Release verification and remaining limitations are recorded separately from this design rationale.
