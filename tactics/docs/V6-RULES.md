# Wellspring Reach: rules 6

The arena grows from 61 to 127 hexes (radius 4 to 6), with movement effort rising from 2 to 3. On the default WELLSPRING seed, three neutral wells at `(0, -4)`, `(0, 0)` and `(0, 4)` pull squads toward separate approaches. Other replayable seeds vary the outer well pair and terrain geography. Deployments are `(-4, 0)`, `(-4, 2)`, `(-4, 4)` and their 180-degree mirrors. Every starting champion can reach a well by a second movement order; none can score on the first movement order.

A generated pair of six-cell raised Earth terraces offer sight and downhill reach, but a rival Fire spell can turn their substrate into Magma. A generated pair of six-cell shallow Water channels offer immediate Steam, Quagmire and other combinations with a single matching spell. Channels have normal movement cost until chemistry changes them; simply standing in Water does not apply Wet. All 127 cells remain accessible. Raised cells cost 2 effort to enter from lower ground. No permanent walls narrow the arena to one route. A single three-hex temporary barrier cannot disconnect any deployment or well from all the others.

Terrain in `lib/arena.ts` is immutable seed-derived geography. Temporary fields preserve that base element, keep the existing finite lifetime and fade back to the original Earth or Water. Wells stay neutral. Saved games validate both immutable geometry and the underlying substrate. `cellElements()` is shared by preview and resolution so reactions on natural terrain are disclosed accurately.

## Replayable procedural seeds

Rules 6 carries a canonical `reach:SEED` map identifier. Seed text is 1–24 ASCII letters, digits or hyphens; surrounding whitespace is removed and letters are uppercased. `confluence` aliases `reach:WELLSPRING`, retaining the original rules-6 default layout. The state stores the canonical seed, so saves, room joins and rematches can reconstruct exactly the same terrain.

Generator v1 is deterministic and tied to rules 6. An FNV-1a seed hash feeds a fixed 32-bit LCG. A bounded connected frontier grows one six-cell inner Earth terrace and another six-cell shallow Water channel, then mirrors each through the origin. The channel chooses a sufficiently large connected component before growth; no unbounded retries are possible. Seeded rotations, growth choices and one of four mirrored outer well placements produce genuinely different layouts. The centre well, 127-cell boundary and deployments remain stable. Natural terrain never creates impassable cells; all wells and starts stay neutral. A bounded cache retains only 64 generated layouts; cached results are immutable.

Two hundred seeds produced 200 distinct layouts in the measured sample and are checked for reproducibility after cache eviction, at least 190 distinct layouts, all four well patterns, symmetry, exactly 12 Earth and 12 Water cells, neutral wells/starts, full connectivity, no opening well capture and a reachable well within two movement budgets for every starter. Seeded save restoration rejects altered geography or a substituted seed. Identical seeded states replay the same sealed plans exactly.

The public-state bot now assigns distinct objectives to its living squad by minimizing total distance over the at-most-six possible well assignments. This avoids the observed behaviour of all three mages choosing the centre merely because each individual step looked nearest. Its Ward threat radius was updated to the ordinary three-hex cast reach. A public movement bounce into an empty well now causes one round of avoiding that exact destination. This breaks the observed loop where two mages repeatedly bounced while remaining outside each other’s spell reach. A prepared Guard-versus-Guard position verifies separate closer approaches. None of these heuristics reads sealed enemy plans.

## Reach and shape

| Spell family | Rules 6 | Tradeoff |
| --- | --- | --- |
| Ordinary targeted spells | Centre reach 3 | Damage and base costs retained |
| Fire Lance, Wind Shear, Prism Lance | Centre reach 5 | Existing lane collateral and recovery retained |
| Flare, Vacuum, Fault Line | Centre reach 4 | Precision/control role retained |
| Immolate | Centre reach 2 | Self damage and commitment retained |
| Slipstream | Self only | No ranged application |
| Tidal Surge | Five-hex crescent | Base cost 4, recovery 2; still hits allies |
| Raise Cairn | Three-hex barrier strip, centre reach 3 | Occupants and wells remain open; Shatter wins simultaneous creation |
| Wildfire, Rainfall, Quake, Blight | Radius 2: 19 hexes | Base cost 5, recovery 3 |
| Maelstrom, Cyclone | Radius 2: 12 outer hexes | Seven inner hexes are safe; base cost 5, recovery 3 |
| Inferno, Eclipse, Sunburst, Sanctuary | Radius 1: 7 hexes | Strong damage or safe allied utility remains compact |

Affinity still modifies base cost. High ground adds one centre reach against a lower target. Blind subtracts one, minimum one; self spells remain self-only. Large footprints may extend beyond their aimed centre. Lanes retain every clear tied shortest path, rather than choosing an arbitrary ray. Directional crescents and walls still require one of six explicit axes. Every shape clips at the arena boundary.

Chilled reduces base movement from 3 to 2; Haste adds 1; Rooted overrides both. Scoring remains first to 8 with a lead, with the existing 16-round cap, health, recovery and simultaneous snapshot rules.

## Evidence and limits

`tests/v6-scale.test.ts` checks immutable geometry, symmetry, deployment pacing, route connectivity under every single barrier orientation, status movement budgets, long-range line of sight, selective area costs, all six directional rotations, edge clipping, natural-terrain chemistry and expiry, ally exposure, all 48 spell resolutions, strict save restoration, and exact path parity for the movement-search change. The previous v5 suite now imports the frozen v5 engine and catalogue.

An opening-position Node measurement found the previous per-target movement search cost 35–55 ms for `legalMoves` on the larger arena. Replacing 127 searches with one bounded deterministic Dijkstra search reduced warmed calls to approximately 0.50–0.57 ms in that local measurement. The corresponding AI plan measured 40–62 ms after the change. These are isolated Node timings, not browser frame rates or physical-phone evidence. Exact returned paths and destination order are compared against the old algorithm under normal movement, Haste, Chilled, Rooted, barriers and Quagmire for both seats.

`tests/v6-diagnostic.mjs` and `docs/v6-balance-diagnostic.json` provide the final-source paired match diagnostic on WELLSPRING. `tests/arena-seed-diagnostic.mjs` and `docs/v6-seed-diagnostic.json` add paired full matches on 24 generated seeds. The pre-assignment diagnostic is retained as `docs/v6-balance-before-ai.json`; it exposed excess convergence and collisions before the bounded squad-assignment and revealed-collision correction. Squad assignment alone did not fix the measured pacing problem; the collision-history change was tested separately before rerunning the same fixtures. The diagnostic covers 30 identities, 48 equipped spells, five squad pairs, three deployments, two loadout profiles and two related public-state policies. Seat parity is a correctness property; it is not proof of a balanced human metagame. Bots do not explore every useful barrier or terrain strategy. Prepared positions test those mechanics separately.

| Final diagnostic | WELLSPRING catalogue/default fixtures | 24 generated seeds, default kits |
| --- | ---: | ---: |
| Games | 120 | 48 |
| Wins by seat | 60 / 60 | 24 / 24 |
| Draws | 0 | 0 |
| Round-cap games | 4 | 0 |
| Mean rounds | 10.05 | 9.75 |
| Mean first score | 3.90 | 3.96 |
| Exact mirrored round comparisons | 603 | 234 |
| Fizzles | 0 | 0 |
| Movement/displacement bounces | 2,118 | 744 |

The fixed-map before-AI run recorded 18 round-cap games and 4,500 bounces in the same 120 fixtures. The final run reduces those to 4 and 2,118, respectively, while preserving exact mirrored results. This is evidence that the bounded public-history correction reduces the observed collision loop, not that all tactical choices are optimal. First scoring still averages approximately round 4; approach and combat can occur before scoring. Four fixed-map matches still reach the 16-round cap. Forty-two spells were selected in those fixtures; Backdraft, Tidal Surge, Deep Freeze, Raise Cairn, Veil and Reap were not. Their mechanics are covered by explicit prepared positions or all-spell legal-resolution tests, not by a claim of bot strategic coverage.
