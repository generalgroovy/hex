# Story affinity and team strength

Rules 11 moves affinity growth out of battle and into the persistent story profile. Each distinct encounter's first victory unlocks its signature and raises every character's available affinity budget by one, from five to a maximum of eighteen. Replays, losses, draws, practice and multiplayer do not award affinity. The first thirteen distinct victories reach the point cap; remaining victories still teach their signatures.

Earned points are assigned independently to each character in camp. They can be returned and reassigned freely. Canonical starting points remain fixed, with at most three elements and six points per element. Unspent points are banked and excluded from team strength. Lowering affinity repairs only loadout slots that become illegal. Spell cards and the signature preview use the actual allocation.

An allocation is fixed for the whole match. There is no round-based income or battle training. Equipment may still change before sealing orders, subject to the frozen affinity and learned library; cooldowns survive replacement. Affinity scaling and creator signature discounts retain their rules 10 behavior.

## Story and practice

The browser profile uses `hex-confluence-story-v11` and format 2 with completed encounter IDs and per-character allocations. Existing format 1 story victories migrate into both learned signatures and available affinity. Invalid allocations do not erase valid victories or other characters. The profile is browser-local; storage failures retain the current tab's state and display a warning.

Story opponents have fixed allocations and legal opening kits. In canonical encounter order, each three encounters increase the enemy's per-character budget by one, from five to fourteen (team totals fifteen to forty-two). The challenge screen shows the actual enemy strength. Training the player's team does not secretly scale an encounter. Victory awards require the correct seed, enemy identities, enemy allocations and a valid winning state.

Practice builds the opponent with the same per-character point totals as the selected team. Local duel displays both teams' totals. Neither mode changes story progress. Retrying Story uses the saved camp allocation and repairs the played company's kit. Local and online rematches retain the allocations and legal final kits from that match.

## Friends' matches

- Casual accepts unequal teams and displays both totals and their difference.
- Competitive requires exactly equal total allocated affinity before the second player can join. Different distributions and different characters remain legal.
- Totals are derived by the server from validated allocations. A client-supplied total is not trusted. An unsuccessful join does not consume the open seat; the player may adjust the team and retry with the same join key.
- Invitation previews disclose only status, map, match kind and team totals. Seat keys, names, signature libraries and sealed orders are excluded.
- Match kind, allocations and learned libraries are fixed at entry. Concurrent plans, reconnects and rematches retain the existing sealed-order protocol.

Equal affinity is a strength gauge, not a claim that every composition has an identical win rate. Progress is declared from browser-local saves and is not an authenticated achievement service. Competitive here means equal-budget private matches; it does not add ranked matchmaking, accounts or anti-cheat progression.

## Compatibility and verification

New rooms use protocol/rules 11. Active rules 1–10 rooms continue through their original engines. `/v10` retains the previous local story/practice implementation and save keys. Historical clients read the current room protocol, submit their original combat plans and adopt new rules only after both rematch consents.

Automated coverage lives in `progression-engine-v11.test.ts`, `story-v11.test.ts`, `progression-client-v11.test.ts`, `rooms.test.ts`, `client-session-v11.test.ts`, and the historical regression suites. `http-v11-smoke.mjs` exercises the real Worker/D1 boundary, including unequal casual teams, competitive rejection and corrected retry, invitation privacy, resolution and rematch. Browser QA separately checks camp allocation, saved progress, clear strength comparison, actual play and narrow screens. Passing these checks establishes rule and transport correctness, not human competitive balance.
