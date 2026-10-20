# V6 scale and procedural seed verification

This is evidence for the v6 source candidate. The release receipt outside the source repository identifies the saved Sites version, exact source commit, terminal deployment status and subsequent public checks.

## Automated correctness

- All 156 tests passed across classic, simultaneous, tactical-position, room, v5, v6, loadout, battlefield-geometry and seed suites. TypeScript passed without emitting files.
- All 960 original animation frames across 30 champions were alpha-scanned. Sprites remain 192 world pixels high; tiles are 154 by 105. Every frame's foot pixels fit inside its tile with a four-pixel margin. The widest individual body is 117 pixels and feet 91.5 pixels at the rendered scale.
- Shared camera tests cover readable tactical tiles, full-map bounds, edge cliffs, clamped panning and complete effect fitting at desktop and phone dimensions.
- A 200-seed regression sample verifies exact regeneration, distinct layouts, all four well-pair choices, 180-degree symmetry, 127 unique connected cells, 12 Earth and 12 Water cells, clear deployments and reachable two-move objectives. An independent 1,000-seed audit also passed all geometry invariants and produced 1,000 distinct layouts. Cache eviction did not alter regenerated geography; fifty strict saved-state roundtrips passed independently.
- Seeded replay tests reproduce the exact state after four identical sealed exchanges. Invalid saved geography and mismatched substrate are rejected.
- Room tests cover canonical host seeds, ignored guest seed overrides, invalid seeds without writes, seed-preserving rematches, private plans, exactly-once resolution, duplicate retries and existing v5 sealed-plan compatibility.
- All 48 spells resolve legally under v6 and survive strict save restoration. Prepared cases verify five-cell directional crescents, three-cell barriers, 19-cell bursts, 12-cell hollow rings, elevation/Blind reach, friendly exposure, terrain chemistry and expiry to the seeded substrate.
- The bounded movement search retains exact paths and tie-breaking against the earlier per-destination search across status, barrier and terrain cases.

## Practice AI and pacing

The initial 120-game fixture exposed repeated movement collisions into empty wells. The correction assigns three objective approaches and avoids immediately retrying a well landing after a revealed movement bounce. It reads public state and previous public events only.

On the same curated `WELLSPRING` fixture, capped games decreased from 18/120 to 4/120, and movement/displacement bounces from 4,500 to 2,118. The final sample had 60 wins per exchanged seat, no draws, mean length 10.05 rounds and first score at round 3.9. A separate 24-seed paired sample contained 48 games, 24 wins per seat, no draws or caps, mean length 9.75 rounds and first score at round 3.96. Together these supplied 837 mirrored-round checks and zero fizzles. Exact source hashes, fixture descriptions and per-spell use are in `v6-balance-diagnostic.json` and `v6-seed-diagnostic.json`; the initial result is retained in `v6-balance-before-ai.json`.

These are bounded bot fixtures, not a competitive-balance proof. Four long games remain in the reference sample. The bot did not use Tidal Surge or Raise Cairn in that sample; their correctness is established by prepared cases, not simulated popularity. First scoring near round four also needs human pacing feedback.

## Browser interaction

The local browser checks used real UI actions at measured CSS sizes 1280×900, 390×844 and 320×844.

- Entered `RIVER-FRIENDS`, copied its map link, generated another seed, then reopened the link. All 127 preview polygon descriptions reproduced exactly.
- Configured Wildfire, entered practice and previewed all 19 affected hexes. Ally exposure was disclosed. Fit effect framed the full area on desktop and both phone widths.
- At 320px width, confirmed the aim, locked the team and reached round two. The resolution disabled targeting, then restored planning. Fire on seeded Water formed Steam, and Fire on seeded Earth formed Magma.
- No horizontal page overflow was measured at either phone width. Targeting and camera controls measured approximately 44 CSS pixels high.
- Pan controls and a drag moved the camera while preserving the uncommitted Guard plan. Returning to camp after choosing the first Pass & play company unlocked the seed selector for a fresh duel.

This is browser viewport evidence. It does not claim physical iOS/Android touch testing, mobile GPU performance, human onboarding results or commercial success. Pixel source provenance and unchanged character affinities remain documented in earlier art and roster verification.

## Local production runtime

The production build completed successfully. Its local Worker/D1 runtime passed all 23 HTTP checks using `reach:QA-RIVER-42`, including canonical host seed reproduction, guest override rejection, hidden plans, concurrent retries, matching peer snapshots, a complete 12-exchange match ending 8–5, and a mutual rematch with identical seeded geography. Old cross-rematch locks were rejected. Public deployment checks are recorded separately in the release receipt rather than presumed from this local result.
