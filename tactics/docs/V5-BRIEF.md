# Confluence: clearer decisions, deeper positioning

## Optimized prompt

Improve Confluence as a simultaneous-turn tactical game in the original H.E.X. world. Increase the quality and readability of decisions rather than the volume of content. Preserve its charming parchment and pixel-art identity, three-character squads, four configurable spells, public game link and private remote matches.

Start from the original H.E.X. character and element data, the actual resolver, representative board positions, and observed desktop/phone play. Verify every character's affinity strengths against the raw source. Do not treat a historical illustration or a design summary as rules authority.

Make the battlefield the visual priority. Keep the selected character, four spells, costs, movement and commit controls together. Use quiet range indicators, a distinct complete spell footprint, and an unmistakable target marker. Surface information that changes the current decision; put explanations and history in accessible disclosures. At a measured 390-by-844 phone viewport, the basic select–aim–confirm–lock flow should not require scrolling between its controls. Avoid horizontal overflow at 320 pixels.

Enlarge the battlefield enough to create meaningful flanks, contested approaches and elevation choices without adding empty travel turns. Differentiate existing spells through single hexes, lanes, bursts, hollow rings, directional sweeps and barrier strips. Use the same deterministic geometry for preview and resolution. Show ally exposure, possible elemental combinations and movement-dependent risk before committing. Never present hidden enemy orders as known outcomes.

Deepen positioning, coordinated attacks, displacement, protection and terrain denial while retaining simultaneous resolution and readable counterplay. Give fresh starter loadouts a useful multihex spell. Keep custom loadouts intact. Improve the practice opponent's avoidable planning failures using only public information; do not confuse bot performance with human balance.

Keep existing saves and remote matches on their original rules. Test exact footprints, edge clipping, six-way rotations, mirrored seats, ally repositioning, barrier travel/sight, simultaneous interactions, private plans, retries and version transitions. Verify actual pointer and keyboard interaction in a browser at desktop and phone sizes. Publish the tested result and report precisely what changed, the evidence that supports it, and what still needs human playtesting.

## Implemented scope

The new rules are v5: a radius-four arena (61 cells, up from 37), with three separated wells and four symmetric raised flank cells. Deployments, movement effort, score target and round cap stay the same. Tidal Surge becomes a three-hex directional sweep; Raise Cairn becomes a three-hex barrier strip with a higher cost and recovery. No extra characters, spells, resources or progression systems were added.

The renderer derives its bounds from the map. The new planning tray exposes all four spells and exact target-specific geometry, and requires confirmation after a ground target is previewed. Full plans can still be revised before sealing. Shared terrain, statuses, aggregate damage and secret simultaneous orders remain the tactical foundation.

## Evidence to player benefit

| Evidence | Player benefit | Acceptance |
| --- | --- | --- |
| Original roster JSON plus separate affinity allocation | Characters retain their actual H.E.X. identity | 30 exact matches; source hash recorded in V5-AFFINITIES.md |
| Phone controls were separated by board and explanatory blocks | Less scrolling during a decision | Measured viewport and pointer sequence |
| Existing legal targets did not show candidate coverage | Fewer accidental ally hits; readable combinations | Preview does not change orders; confirm commits the displayed target |
| Small arena compressed approaches | More choices around occupied objectives | 61 mirrored cells; first score and match pacing recorded |
| Existing area geometry was underused by starter kits | Players encounter spatial tactics immediately | Every fresh starter kit includes a native multihex spell |
| Bot casts often depended on contested landings | Practice opponent wastes fewer commitments | Fizzle and bounce counts reported separately; paired deterministic fixtures |
| Rules changes can invalidate old matches | Friends can finish an existing game | Frozen v4 resolver/catalogue and retry/receipt regression tests |

Human playtests remain the standard for learnability, strategic discovery, fair-feeling losses and replay desire. Automated checks establish rules, compatibility and specific tactical consequences; they cannot establish commercial success.
