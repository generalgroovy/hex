# V3 verification — 2026-10-16

This record covers the simultaneous-plan candidate. [VERIFICATION.md](VERIFICATION.md) retains the earlier alternating playtests. Local source, browser behavior, production build and hosted publication are separate acceptance states.

## Current status

| Check | Evidence at documentation handoff |
|---|---|
| Combined automated suite | **73/73 passed**, reported by the integration owner: 34 retained alternating-engine tests, 17 room/compatibility tests, 22 simultaneous-engine tests |
| Whole-project TypeScript | **Passed**, reported by the integration owner |
| Final simultaneous engine component suite | **22/22 passed**, reported by the engine owner |
| Final engine diagnostic | Completed against the source hash below |
| Development HTTP smoke | **Passed 14 checks** before the final Light damage adjustment; recorded round 9, score 10–5 |
| Final production build | **Passed**, reported by the integration owner after the final UI integration |
| Production Worker HTTP smoke | **Passed on retained Light-2 rules and the current backend**: round 8, score 8–7, Player 1 wins. A later rebuild changed UI only |
| Hosted v3 publication and live checks | **PENDING** — the public URL alone does not identify its currently verified source |
| Narrow browser planning flow | Completed at a 390px CSS frame; details below |
| 320px and hotseat browser checks | **Passed reported scenarios**: saved Player 2 targets/orders restored, both teams lock, resolution shown, then handoff |
| Physical-phone touch and separate-network friend play | **NOT PERFORMED** |

An earlier integrated checkpoint passed 71 tests before the final save-consistency and Light-damage regressions were added. That result is superseded by the final 73-test pass above, rather than being combined with it. The final rules retain Light enemy damage 2 and friendly healing 2. The development HTTP match used the earlier Light value and demonstrates the protocol lifecycle, not final-rule outcome balance.

## Rules, persistence and compatibility coverage

The simultaneous tests cover immutable resolution, default Guard, legal moves and aim, elevation, destination collisions and chains, swaps, simultaneous damage and healing, mixed-element reactions, friendly fire, displacement, terrain lifetime, scoring, respawn timing, AI legality and saved-state validation. The two final save tests enforce round/version and victory/score consistency. Engine-created active states have matching round and resolution version; a terminal resolution advances the version without opening another round.

The 17 room tests execute production SQL against SQLite using the generated D1 schema. Existing authentication, atomic seat claims, alternating action concurrency, expiry, rate limits, old engine parity and local-save checks remain. New tests exercise private first locks, unchanged baseline snapshots, own normalized-plan recovery, four concurrent duplicate submissions, exactly one round resolution, conflicting same-seat orders, foreign-team rejection and delayed requests crossing a rematch.

Plans are stored inside a server-only `state_json` envelope. Snapshots expose `locked` and only the authenticated player's `yourPlan`; they omit opponent plans, fingerprints and previous-resolution receipts. Current plan bodies require `protocolVersion: 3`, `matchId`, `round` and `plan`. Room revisions advance on lock writes while game versions advance on resolved rounds. Rematches generate a new match identity. No D1 schema migration was needed for v3.

Existing v1/v2 rooms remain readable and playable through the Classic interface and their archived engines. Their supported old protocols remain valid for reads/actions. New creation, joining and rematch consent require protocol 3. An old queued rematch consent cannot upgrade a player silently. Local restoration validates the entire saved mode, seat and plans before committing state; rejected data is retained.

Independent source review checked the movement conflict graph, aggregation before Health writes, dead-caster completion, push tie cancellation, symmetric elevation and scoring-before-respawn order. It found no additional simultaneous-resolution blocker. This is source review, not adversarial testing or a human balance result.

## Browser evidence and limits

The supported browser exercised practice planning, selecting a cast target, locking team orders and simultaneous resolution. At an actual **390px CSS frame** with approximately **381px content width**, no horizontal overflow was observed. Current action controls measured approximately **49–61px** high. These measurements describe a desktop browser frame, not a physical phone or a successful device-emulation override.

The implementation now has a fixed narrow-screen action dock, an enlarged board view, a native hotseat handoff dialog that traps focus, and replay that disables planning while preserving zoom. The integration owner also completed a 320px hotseat browser check: a saved Player 2 planning phase restored the correct targets and orders; both teams locked, the round resolved visibly, and the handoff followed. These are browser interaction checks, not physical touchscreen acceptance. The later UI rebuild corrected the round-report label, selected company after resolution and planned-order count.

Review found and the integration owner corrected a late online response entering the wrong mode, partial save restoration before validation, wrong-team selection on a resumed hotseat turn, stale reconnect messages and misleading conflict feedback. The final combined tests and TypeScript pass are recorded above; these fixes are not all claimed as separate browser scenarios.

## Final bounded diagnostic

Artifact: [sim-balance-diagnostic-results.json](../tests/sim-balance-diagnostic-results.json). Reproduce with:

```sh
node --experimental-strip-types tests/sim-balance-diagnostic.ts
```

The artifact identifies `lib/sim.ts` SHA-256 **`2e9d40730540a60c74aef116691ae444cc009d30773e09b326d7b9df92bc4acd`**. It runs all twenty squads in ten complementary pairs, three cyclic deployment orders, two related shallow policies and exchanged seats: 120 deterministic games. Each policy receives the public state, never the other team's pending plan.

- Seat wins: **60 / 60**, no draws and no round-cap games.
- Mirrored physical round-state comparisons: **598 passed**.
- Mean match length: **9.97 rounds**.
- Cast events: **3,366**; fizzles: **498**. These expose limits of shallow movement/range planning rather than human decision quality.

| Squads containing | Wins / games |
|---|---:|
| Oh Tipi / Water | 58 / 120 |
| Wa Bidi / Fire | 66 / 120 |
| Grace Riva / Air | 54 / 120 |
| Treevor / Earth | 62 / 120 |
| Haara / Light | 46 / 120 |
| S. Wayne / Dark | 74 / 120 |

The saved [baseline artifact](../tests/sim-balance-diagnostic-baseline-results.json) precedes one bounded Light comparison. Raising enemy Light damage from 1 to 2 while retaining friendly healing 2 changed Haara-containing squad wins from 36 to 46 of 120 in this fixture. The final value was retained; this is not an isolated causal estimate of champion strength or proof that Light is balanced.

These games are correlated, deterministic and limited to complementary squads, three of six deployment permutations, one board and two related policies. Equal seat wins and mirrored states support implementation symmetry, not equal drafts, expert strategy, human enjoyment or retention. Diagnostic elapsed time is Node runtime, not browser speed, device performance or network latency.

## Outstanding acceptance

Human learning, phone touch, separate-network completion, assistive-technology use, sustained load, voluntary replay and retention have not been established. No commercial-success claim follows from passing tests or symmetric bot fixtures. The bounded next human session is specified in [DESIGN.md](DESIGN.md).

The integration owner should replace the pending hosted row with the final deployment identity and live-check outcome before final handoff. Preserve earlier results and their limits when doing so.

The post-publication receipt is saved beside this source project as "confluence-v3-release.json". It records the exact saved source, deployment status and any subsequent live checks without changing the deployed source snapshot.

