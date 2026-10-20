# Tower scouting and combat reference

## Player decisions

Every battle door starts with a truthful, partial report: one sighted enemy, up to two elemental traces, or a starting terrain quirk. Enemy count, battle/elite/boss risk, reward terms and unavoidable health costs remain public. Sibling doors offer different evidence. Unknown identities, terrain and spell kits are labelled rather than silently omitted. The summit uses the same partial projection.

Each living champion can scout one chosen battle door per floor, at no HP or Flux cost. A scout reveals one deterministic, previously unreported fact: identity, affinity rank, health, an equipped spell, or the starting field. Reloading or changing a build cannot replenish the allowance or reroll the fact. Creatures retain their combat bonds but cannot scout. Safe rooms already disclose their costs and services; no scout is spent there.

Three doors divide a limited champion budget. Concentrating scouts improves knowledge of one fight; spreading them improves the comparison. The fact pool excludes baseline disclosures and permanently reserves at least one actual equipped spell per enemy. If a door has no further scoutable facts, its action disables without spending a champion. The player can use that scout elsewhere. The interface automatically assigns the next available champion to avoid a redundant selection click.

## Co-op and persistence

Co-op shares reports only between identical encounters, fingerprinted from seed, map, field and the complete enemy composition. Squads with different starting strength can face different opposition and must not receive misleading clues. A shared ledger survives fast finishers and clears when the group advances, rather than when the first player claims a reward. Only the acting player's step changes. Another squad's prepared combat turn and private enemy plan remain valid.

Concurrent scouting recalculates against the current ledger after a compare-and-swap retry. Request receipts prevent spending twice. The existing run format and protocol remain compatible; optional scouting state is validated against regenerated canonical facts. No database migration or combat rule change is required. The player-facing uncertainty is not a secrecy boundary against inspecting deterministic client code or replaying a known seed.

## Selection and reference

Solo suggestions appear in this order: Oh Tipi, S. Wayne, The Red Baron, Steezo, Treevor the Mason, Oll' I and Wa Bidi. Each suggestion includes a complementary lesser creature; both slots remain freely editable. The original three co-op suggestions and saved starter identifiers remain supported.

Guide opens tabular references for six elements and their advanced branches, all 57 mixed fields, 171 spells and 12 statuses. Search and filters narrow mixtures and spells; individual rules expand in place. Selected-character rows use actual affinity and status modifiers, while generic views explicitly show base values. Tower healing reductions are labelled separately. The modal is mounted outside navigation containers, traps native dialog focus and blocks gameplay shortcuts while open. Existing Story rules also expose the guide without introducing Tower-specific healing rules there.

## Verification

Dedicated tests cover deterministic partial disclosures, forbidden pre-entry kit details, unchanged encounters, all seven legal starter pairs, canonical reference registries, individual scout allowances, save/reload/build persistence, reserved spells, exhausted rooms, forged reports, and six-player concurrent sharing/checkpoint behaviour. The HTTP smoke exercises actual six-squad battles after scouting and verifies the floor-two reset. Browser checks exercise the report, guide filters, Escape/focus return, saved scouting and phone layout. Automated tests and viewport checks do not establish human balance or physical-device performance.
