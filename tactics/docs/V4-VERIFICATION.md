# V4 verification — 2026-10-16

This is the source-side prepublication record. The release receipt outside the checkout records the exact published commit, version, deployment and public-origin smoke result. Earlier release records remain separate.

## Scope and provenance

30 canonical characters, four distinct equipped spells per character, 48 spells across six elements, twelve statuses, fifteen functional distinct-element reactions, one battlefield, practice, pass-and-play and two-player private online rooms. Names and affinity points come from the original champion registry; all thirty character atlases were copied byte-for-byte. See `v4-roster-provenance.json`, `../public/pixel/manifest.json`, and `V4-ART.md`. Original H.E.X. source and builds were not modified.

## Automated checks

- **110/110 tests passed**: 34 legacy game, 22 v3 simultaneous, 23 room/persistence, 27 v4 tactics and four independent prepared tactical positions. No failures, skips or cancellations.
- **Full TypeScript check passed** after the final battlefield replay correction.
- **Production build passed** through the project's Vinext/Cloudflare pipeline. The Sites build helper encountered this Windows host's npm shim path error; invoking the installed official npm CLI directly ran the same `build` script successfully. No application or dependency changes were made to work around it.
- **Built Worker HTTP smoke: 19 checks passed** at `http://127.0.0.1:8787`. A complete match resolved eight rounds, final score 6–9, followed by mutual rematch and stale-match rejection.
- No additional D1 migration is required. Existing v1/v2/v3 matches retain their engines. Tests include old sealed-plan hashes and retry receipts, old-client rejection for new matches, and both-player consent before upgrade.

The HTTP checks cover expanded roster creation, forged loadout rejection, public configured kits, default guest kits, authentication, protocol versioning, foreign units, forged/unequipped/missing spells, sealed first lock, identical retries, concurrent second-lock retries, single resolution per round, stale rounds, full match completion, identical peer snapshots, no plan/token leakage, preserved rematch kits and rejection of delayed preceding-match orders.

Commands:

```sh
node node_modules/typescript/bin/tsc --noEmit --incremental false
node --experimental-strip-types --test tests/game.test.ts tests/sim.test.ts tests/tactics.test.ts tests/tactical-positions.test.ts tests/rooms.test.ts
node --experimental-strip-types tests/tactics-diagnostic.mjs docs/v4-balance-diagnostic.json
node --experimental-strip-types tests/http-v4-smoke.mjs http://127.0.0.1:8787
```

## Tactics and symmetry evidence

`TACTICAL-POSITIONS.md` and its executable test establish four bounded comparisons: Ward makes piercing Shatter worth its higher price; affinity changes the affordable well-clearing spell; Burn and Wither reverse the immediate preference between healing and cleansing; Steam can make a threatened well worth holding. These are specific counterexamples to one fixed answer, not proofs of global optimal strategy.

`v4-balance-diagnostic.json` records 120 complete seeded matches: 58 wins per seat, four draws, six games reaching the cap, average 9.15 rounds, and 549 exact mirrored round comparisons. The fixture includes every character, equips every spell across default/custom kits, and uses two related public-state policies. Only 37 spells were actually cast. The bots produced 3,358 casts and 1,300 fizzles, exposing limited movement/targeting judgment. Results support determinism and seat symmetry, not full-catalogue balance or enjoyable pacing.

## Browser interaction evidence

Root IAB checks completed: configure an alternate spell, reject duplicate equipment with visible in-dialog feedback, start practice, move and aim, form Steam using allied Water and Fire, resolve into round two, clear a previous aim when changing the selected spell, and retain the resulting save.

Phone-sized frame checks completed at nominal 320 and 390 CSS pixels (actual document client widths 310 and 381 after scrollbars): no horizontal document overflow, spell configuration, movement, target selection, changed-spell aim clearing, round lock, saved-match resume, separate second-company setup and opaque pass-and-play handoff. These are browser frame checks, not physical-phone tests.

Independent Opera checks at actual 355×767 CSS pixels completed movement and keyboard activation, Water/Fire planning and Steam resolution. Focused hex hit regions measured approximately 72.7×49.6 CSS pixels; pan controls approximately 44×44. No horizontal overflow or console errors in that isolated run. See the art record for rendering details.

Development HMR/proxy warnings occurred during hot reload through the temporary phone fixture. They are not counted as production errors. The final built Worker is tested separately without the development server.

Final production-browser checks passed: original terrain/statuses remain during the movement/cast replay and Steam appears at impact; moving sprites retain their health/Flux bars. IAB created a private room and a separate Opera browser joined it. Both sealed orders, both observed round two, and both recovered their correct seats and fresh plans after reload. The isolated production IAB console had no warnings or errors. This is separate-browser UI evidence on one host, not a separate-network human test.

## Independent review and resulting fixes

Review covered snapshot combat, every used spell-effect property, movement collision/barriers, status timing/expiry, health aggregation, Flux theft, displacement, strict save validation, mode/request epochs, hotseat handoff and remote plan secrecy. No declared spell-effect property lacked an engine implementation.

The review found that wiping the entire friendly team could hide the selected-mage panel containing the lock/rematch controls. A persistent fallback dock now permits an empty recovery plan and rematch. It also clarified Slipstream's Clarity timing. Root interaction checks fixed invisible modal notices and the stale aim left after changing spells. Battlefield review fixed overlapping terrace hit areas and premature display of final terrain/statuses during replay.

## Limits

No claim of strong-human competitive balance, uncoached onboarding, physical-device touch performance, separate-network human play, retention or commercial success is made. The thirty characters are canonical identities and affinity profiles, not thirty independently designed classes; original real-time passives are not ported. Tests do not enumerate every team/loadout pairing. A focused human study is specified in `V4-DESIGN.md`.
