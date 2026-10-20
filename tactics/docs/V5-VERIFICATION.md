# V5 verification — 2026-10-16

This records source/build verification before publication. The delivery receipt beside the exported source archive records the exact published source, Sites version, deployment and subsequent public checks.

## Rules, persistence and compatibility

127 tests pass across the legacy game, v3 simultaneous rules, frozen v4 rules, room service, v5 tactical positions and loadout migration. TypeScript passes with incremental caching disabled. The production Vinext build completes for `/`, `/classic`, `/v3`, `/v4` and the room APIs.

The 12 new v5 rules tests cover all 30 four-spell starter kits, the 61-cell mirrored map, strict restoration, six-way rotation, axial direction, board-edge clipping, high ground and Blind, moving an ally out of a sweep, barriers changing movement and sight, safe wells/occupied cells, simultaneous Shatter, full mirrored/order-array outcomes, failed-landing fizzles, all 48 spells resolving, and the public-state bot's fallback legality.

Three migration tests verify that untouched v4 starter kits acquire the new signature spell, custom/reordered kits remain exact, deliberate v5 kits stay exact, and one damaged kit does not discard another. The v4 loadout storage is retained; v5 saves separately.

Room tests exercise actual SQLite with production SQL, including concurrent locks, duplicate retries, hidden opposing plans, ownership, protocol rejection, mutual rematch and stale-match receipts. Added regressions preserve a pending v4 plan's fingerprint, its 37-cell map, the old single-hex Tidal Surge and old Raise Cairn cost. Frozen v4 engine and catalogue match their prior source after import and line-ending normalization. The compatibility clients negotiate current room versions while retaining their original active rules.

The HTTP scenario passed 19 checks on the local server, playing a complete six-round match (8–3), comparing both players' snapshots, verifying hidden plans and performing a mutual rematch. The same script is used against the published build; its public result belongs in the delivery receipt.

## Paired diagnostic

`v5-balance-diagnostic.json` records exact hashes of the engine, catalogue, roster and diagnostic. Its 120 games cover all characters and equip all spells across a bounded family of five squad pairings, three deployment permutations, two loadout profiles and two related policies.

- Wins: 60 per seat; no draws or round-cap games.
- 432 mirrored round comparisons.
- Average match length: 7.2 rounds; average first score: round 2.
- 3,094 successful casts; 8 fizzles; 1,438 movement bounces.
- 41 of 48 spells used; 80 sweep, 258 lane, 240 burst and 74 ring casts.

This is evidence of deterministic symmetry and pacing in these fixtures. The map, defaults and AI changed together, so comparison with the old fizzle count is descriptive rather than an isolated performance experiment. The bot does not choose Raise Cairn or six other spells in these fixtures. Barrier tactics are established through prepared positions, not AI usage. Human metagame balance, retention and commercial potential remain unmeasured.

## Browser and visual checks

Measured CSS viewports, not only requested device dimensions: 1280×900, 390×844 and 320×844. Browser zoom required compensating the automation viewport setting; document geometry was read back after each change.

- No horizontal overflow at 390 or 320 pixels.
- At 390×844, company selection, board, all four spells, preview/confirmation and Lock fit together. Spell targets measure at least 55px high; Confirm and Cancel measure at least 44px.
- Actual pointer flow: choose the exact `−2,0` ground destination, choose Tidal Surge, preview `−1,0` and its three-hex footprint, confirm and lock. The game advances to round 2 with the correct Water field.
- Preview leaves the prior order unchanged and disables Lock until confirmed/cancelled. Keyboard Enter also previews a target; a self-target shows the ally warning. Cancel restores planning without committing the preview.
- The final SVG ground interaction layer remains above sprites and effects. SSR checks found 61 unique cell controls, one roving tab stop, all cells disabled during resolution, and no aiming overlays during resolution.
- Desktop overview shows all 61 hexes; focus can pan. Decorative trim was corrected after visual inspection found a clipped arch.
- No browser console errors were observed in the tested local flow.

The browser tests are emulated viewport tests, not physical iPhone/Android testing. Actual remote-device latency, long-session performance and human comprehension need subsequent playtesting.

## Independent review

An independent reviewer compared the canonical raw data and later reviewed preview/commit logic, status feedback and version dispatch. Three findings were repaired: v4 rematch negotiation, committed footprint color after selecting another spell, and immediate explanation for Rooted movement. The current original H.E.X. affinity audit is in `V5-AFFINITIES.md`.

## Reproduce

```sh
node node_modules/typescript/bin/tsc --noEmit --incremental false
node --experimental-strip-types --test tests/game.test.ts tests/sim.test.ts tests/tactics.test.ts tests/tactical-positions.test.ts tests/rooms.test.ts tests/v5-depth.test.ts tests/loadouts.test.ts
node --experimental-strip-types tests/v5-diagnostic.mjs docs/v5-balance-diagnostic.json
npm run build
node --experimental-strip-types tests/http-v5-smoke.mjs http://127.0.0.1:8787
```

The diagnostic is intentionally bounded. Repeating it does not substitute for varied human matches. HTTP tests create isolated QA rooms and never print player credentials.
