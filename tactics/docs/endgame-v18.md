# Elimination and closing ground — rules 18

New multiplayer rooms at `/skirmish` use rules 18 and `/api/skirmishes-v18`. Victory means that only one team has living characters. There is no score victory, health comparison, or automatic draw at round 20. A draw requires every remaining character to die in the same exchange.

## Closing ground

Every player sees the same deterministic schedule. The first two-ring contraction occurs at round `playerCount + 8`, with a two-round warning. Subsequent contractions happen every two rounds. Current unsafe ground and the next boundary are distinct; the selected character's planned landing also reports its exposure. The map remains traversable outside the boundary, so a dangerous route or displacement remains a tactical choice.

| Players | Map radius | First closure | Final closure |
| --- | --- | --- | --- |
| 2 | 9 | 10 | 18 |
| 3 | 10 | 11 | 19 |
| 4 | 11 | 12 | 22 |
| 5 | 12 | 13 | 23 |
| 6 | 13 | 14 | 26 |

Outside damage rises with each closure, from 1 through 6. The final closure leaves one safe center hex and deals 8 outside damage. It is applied simultaneously at final landing positions, after spells, healing, displacement and ordinary terrain effects. Guard, Ward and elemental cover cannot reduce it. A character has at most 8 health, no two living characters can share a hex, and the center spring cannot be walled. Therefore the final exchange leaves at most one living character. That produces an elimination victory or a genuine simultaneous wipe, never a draw with surviving opponents.

Larger maps get more approach rounds. Each player still controls three characters with a fixed 15-affinity company budget; all players plan simultaneously. The 90-second planning window and separate movement/casting playback remain unchanged. Disconnected rooms advance only when a connected participant requests the elapsed timeout; this is a bound on resolved rounds, not a guaranteed wall-clock duration when everyone is offline.

## Interface

Room setup uses direct player-count and format buttons. Company slots show identities, affinity budgets and equipped spell icons. Spell selection previews effect, cost, shape and reach. Combat cards show queued actions, and **Next to plan** finds a living character without a chosen spell or Guard. The keyboard supports M (movement), G (Guard), U (undo) and 1–5 (spells), without intercepting typing in fields. Allies and enemy companies have separate groups.

Closing ground uses static pixel cracks, a solid current boundary and a dashed future boundary. Replay retains the previous round's boundary until that exchange has finished. Distant collapse casualties do not pull the combat camera away from the player's company. Fixed scenery stays still.

## Compatibility and checks

Existing rules-17 rooms remain playable at `/skirmish/legacy`. The new API rejects an old code with `LEGACY_MATCH` before consuming a seat; the current screen redirects to the preserved client. Old clients cannot operate a new rules-18 room. Session and draft keys are versioned. Existing story and rules-16 modes remain separate.

Validation covers concurrent seats and sealed plans, retries, rematches, timeout-only matches, strict state restoration, current/future boundary display, landing damage after force and ice, healing and protection stalls, simultaneous deaths, coordinate rotations and seat permutations. Seeded AI simulations are diagnostic evidence about these rules and bots; they do not establish human competitive balance.

## Validation recorded 19 October 2026

- Full regression run: 902 passing tests. After the final bot correction, 50 targeted rules, room, presentation and compatibility tests passed; TypeScript and the production build passed.
- Four frozen-source six-player simulations completed by elimination: WELLSPRING free-for-all round 26, RIVERBEND free-for-all round 24, WELLSPRING teams round 22, and RIVERBEND teams round 14. Across 86 rounds: no draws, illegal plans or failed snapshot restorations. The two FFA cases and WELLSPRING teams had previously ended in complete wipes with the first closing-ground bot policy. The correction changes public-state positioning decisions, not collision rights.
- The built local server completed a six-player match and unanimous rematch: 652 HTTP assertions across 210 requests, plus a 3v3 exchange. Separate preserved-protocol smoke tests passed 126 assertions for rules 17 and 327 for rules 16.
- Browser checks exercised setup, company inspection, reconnect, Guard, next character, keyboard undo/movement/spell selection, a queued move plus cast, remote resolution and review. A local test room was advanced through canonical Guard resolutions to inspect late-round boundaries; only that owned fixture received an extended inspection deadline. This visual fixture is separate from the complete HTTP matches and bot corpus.
- Casting plus a closing-ground warning fits without horizontal overflow at 320×568, 360×640, 844×390 and 1366×768. The two short portrait views retain 134px and 206px of battlefield respectively, with End turn visible. These are browser viewport checks, not physical-device performance measurements.

Reproduce with `node --experimental-strip-types --test tests/*.test.ts`, `node node_modules/typescript/bin/tsc --noEmit`, `node scripts/run-framework.mjs build`, and `node --experimental-strip-types tests/http-v18-smoke.mjs http://127.0.0.1:8787`. The center-collision regression fixture is committed under `tests/fixtures/`.
