# H.E.X. release 44

Implementation of the [expert review plan](EXPERT-REVIEW-AND-IMPLEMENTATION-PLAN.md). This record separates executable changes, technical verification, and evidence that still requires players or physical devices.

## Player-facing changes

- New battles use a versioned spell profile. Sunburst has a distinct piercing Light role; old saved battles retain their original spell behavior.
- Arena previews and resolution use the same finite projectile contact model. Exact team outcome previews are withheld when teammates' private orders are unknown; reach, footprints and the player's own queued paths remain visible.
- Enemy decisions compare movement and casting together, including rescue positions, usable recovery, and route-blocking terrain.
- Aiming previews summarize known terrain replacements and explain uncertainty. Round reports expose recorded damage and healing contributions, shared prevention, and final health.
- New Tower runs use crossing, courtyard, and grove encounter motifs. The route preview states each motif's tactical role.
- Cooperative encounter composition varies supporting roles without rerolling facts that scouts already revealed.
- Reward and recruitment previews distinguish useful additions, explicit replacements, and unavailable spells. The first-climb guide is optional.
- Unfinished cooperative rooms renew their seven-day inactivity period on successful authenticated actions. Polling and retrying an already-accepted action do not extend it.
- Spell controls have readable text and flexible heights. Sound, playback, and reduced intensity have separate saved preferences.
- Pause, next-phase stepping, replay speed, and result skipping share one presentation clock. These controls are local, including for spectators; they do not lock orders or advance a cooperative floor. Sound enabled during a replay begins at the current point.
- Completely prevented damage shows “Blocked” rather than a hit pose. Recoil and drain remain distinct in the causal report. Phone reports use stacked character records.
- Creature poses and elemental effects use distinct body and mechanic families. Persistent fields stay quieter than travelling effects and important contacts.

## Compatibility and ownership

The public URL remains `https://hex.onetruepath.chatgpt.site`; private seat credentials remain private. Existing campaigns, Tower saves, legacy encounters, and invitation routes remain supported. New generation and spell behavior are explicitly versioned.

Each implementation lane has one source owner and another reviewer. Systems covers native rules, intelligence, and save contracts; experience covers encounters, rewards, scouting, and cooperative persistence; presentation covers controls, animation, effects, and audio. Integration covers previews, explanations, browser checks, the production Worker, and release packaging.

## Verification

The release process runs the complete native regression suite, TypeScript, a production build, real six-seat same-room and split-room HTTP encounters, and desktop/phone browser checks before publication. The final delivery record identifies the tested commit, archive, test results and deployment separately from this source document.

Development checks already exposed and repaired mismatches in Arena preview geometry, Story workshop spell descriptions, late support promotion, watched-player inspection, and presentation-preference backup.

Strict restoration also caught fully prevented centre healing incorrectly marked as critical. Current events retain their prevention explanation but only mark positive healing as critical. The regression checks the zero-healing case, the positive-healing case, and rejection of forged critical metadata.

### Pacing diagnostic

The [raw eight-party diagnostic](release44-evidence/starter-diagnostic.json) uses seed `FOCUS42-B`, ordinary room-entry APIs, native AI on both sides, and strict restoration after each round. Reproduce with `node --experimental-strip-types tests/balance-v44-diagnostic.mjs`. These are single-seed diagnostic outcomes, not win rates.

| Starting party | Exchanges | Outcome | Closing-ground damage |
| --- | ---: | --- | ---: |
| Oh Tipi | 6 | Won | 0 |
| S. Wayne | 10 | Won | 0 |
| The Red Baron | 4 | Won | 0 |
| Steezo | 5 | Won | 0 |
| Treevor | 12 | Won; champion fell | 24 |
| Oll’ I | 9 | Won | 0 |
| Wa Bidi | 11 | Won | 0 |
| Custom Oh Tipi + Steezo | 7 | Won | 0 |

This sample does **not** meet the plan's provisional ordinary-fight 90th-percentile target below ten exchanges. The Treevor and Wa Bidi tails remain balance investigation cases. The separate reproduced Dusk defensive loop improved from a 12-exchange draw with 24 closing-ground damage to a nine-exchange win with no closing-ground damage and both allies surviving. Its regression retains those outcome checks.

Per-call geometry and spell caches removed the initial multiplicative cost of joint movement/casting search. The final single-seed sample averaged roughly 94–626 ms for both sides' combined plans, with a maximum of 941 ms on the development machine. A separate twelve-against-twelve sample measured 1.89 seconds process CPU against 1.80 seconds for the old search. These are native diagnostic timings under development-machine load, not browser latency or hosted-service performance.

## Evidence boundaries

Native resolver and service tests establish the checked mechanics and protocol behavior. Seeded bot fights are diagnostic samples, not evidence of human difficulty or enjoyment. Desktop browser viewport checks establish layout at those CSS sizes, not physical-phone performance. No unfamiliar-player study, physical-phone performance study, or calibrated listening session has been completed for this release.

The larger plan's human-comprehension, tactical-usefulness, and voluntary-replay gates remain open. They are not converted into completed work by automated test counts.
