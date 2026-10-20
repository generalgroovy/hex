# Tower v23 model verification

v23 separates each player's climb from the multiplayer lobby. A player starts with any two distinct choices from 30 configurable champions or 12 lesser creatures. Suggested pairs are editable. Champions use five starting affinity points and four legal spells plus their signature; creatures retain their canonical two-point kits. The party can recruit a third fighter. Both starting champions stay protected, while creatures and later recruits may be replaced.

The run/session format is 3 and the storage key is `hex-confluence-tower-v23`. Combat remains the frozen `tactics-v22.ts` normal solo resolver; the v22 models and existing save formats were not edited. A multiplayer seat owns one complete v23 session, with independent route, battle, wounds and rewards. Lobby capacity, floor synchronization and spectating are integration concerns tested separately by their owners.

Enemy tiers use immutable starting affinity totals of 4, 7 or 10, never current HP or earned growth. Canonical stronger enemies meet two-champion starts; creature starts have lighter later support tiers. The four-point first ordinary encounter contains one attacking lesser creature, while floor 2 and elite encounters retain two. Creature-only parties receive real recruitment choices where spell/affinity rewards would otherwise be empty. Tuition costs the current first fighter 2 HP and requires at least 3 HP. Checkpoint sharing merges valid known spell IDs only: no automatic healing, affinity or equipment changes, and ordinary affinity/access requirements still apply.

## Bounded actual combat

Every observed battle used actual public-state AI plans, the simultaneous resolver, strict restoration and normal room/reward APIs. No winner or HP was fabricated. One full climb per starting affinity total used SQUADS1; additional opening checks used SQUADS2 and SQUADS3.

| Starting affinity | Representative pair | Opening rounds SQUADS1 / 2 / 3 | Opening wins | Full SQUADS1 outcome | Full-climb rounds |
| ---: | --- | --- | ---: | --- | ---: |
| 4 | Cinder + Puddle | 4 / 12 / 7 | 2/3 | Cleared | 39 |
| 7 | Oh Tipi + Cinder | 4 / 6 / 10 | 3/3 | Lost floor 9 | 31 |
| 10 | Oh Tipi + Treevor | 10 / 7 / 8 | 3/3 | Lost floor 7 | 39 |

The initial creature-only openings took 12 / 12 / 12 rounds. After the narrow introductory-encounter adjustment they took 4 / 12 / 7; its full climb shortened from 50 to 39 rounds. The mixed and champion pair codepaths were unchanged, so their existing observations were retained with their original source hashes. The complete affected creature suite was rerun against the final source. [Raw compact evidence](tower-v23-balance.json) preserves both passes and labels this distinction explicitly.

Across the applicable nine cases, there are 23 actual battles, 8/9 opening victories, an opening median of 7 rounds, one ending exchange containing collapse damage, and no 18-round battle. These small samples do not establish equal difficulty or a population win rate: creature-only SQUADS2 still loses at 12 rounds, the mixed pair loses its sampled boss, and the double-champion pair loses on floor 7. Not every possible pair, build or route was combat-tested.

## Regression evidence

- `node --test tests/tower-model-v23.test.ts`: 9/9 passed on final source.
- Scoped strict TypeScript compilation of the model and test passed.
- All 435 distinct authored champion pairs validate, and all 12 lesser creatures can occupy the first slot beside a champion. Tests cover exact budgets, duplicate/advanced-creature rejection, first-floor editing, founder protection, third-slot recruitment/replacement, full-health creature rewards, tuition, immutable scaling, 216 seed/floor/lane enemy previews, checkpoint library sharing, v22 save isolation and actual bounded combat in all three affinity bands.
- Source hashes accompany each evidence pass. `lib/tower-v22.ts`, `lib/tactics-v22.ts` and `lib/tower-endgame-v22.ts` have no diff in this change.

These tests establish model behavior and reproduce the observed pacing. They do not measure human enjoyment, readable animation, mobile performance, network resilience or six-person usability; those require separate integration and playtest evidence.
