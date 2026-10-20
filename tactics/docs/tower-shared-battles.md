# Shared Tower encounters

A room choice is a commitment at the floor landing, not an immediate private battle. Every surviving squad chooses a reachable door before the floor launches. Players can withdraw their choice while gathering; they must withdraw before scouting or editing that squad. A choice change never resets spent scouts.

Squads choosing the same battle door enter one battlefield. Each brings its own fighters and the exact enemies previewed for that squad's starting strength. Distinct doors remain separate encounters. Safe-room services and reward choices remain personal. The next-floor barrier still waits for every surviving squad to finish its room and choose a reward.

The shared side supports two to six controllers and up to three fighters per controller. Fighter IDs are namespaced by seat. The arena expands from radius 9 to 13 with the number of participating squads; units deploy on distinct walkable hexes near the central fighting area. Enemy health, spell kits, and affinities retain their established class rules. Shared access to creature bonds, healing and elemental combinations follows the normal allied-team rules.

Each controller drafts only its own orders. Allied drafts are visible, the enemy plan is private, and each living squad locks independently. One authoritative exchange resolves after every controller with a surviving fighter locks. A squad whose fighters have fallen watches its allies without blocking their turns. A victorious shared side returns the normal one-health recovery to fallen members, then each squad takes one reward and retains its own progression. Retirement defeats only that controller's fighters and removes its readiness/barrier requirement.

The server stores a shared battlefield once, rather than duplicating it in every squad's run. Snapshots project that battlefield together with the recipient's own plan and canonical progression. Enemy plans and credentials never enter snapshots. Compare-and-swap writes, per-seat steps and request receipts protect simultaneous locks and retries. A completed request cannot resolve an exchange twice.

Old envelopes without the shared-room marker finish their existing private floor under their original behavior. At the next collective floor transition they adopt shared choices. Solo run/save validation remains separate from shared server projections.

Automated service coverage includes two, three and six squads choosing the same door; six squads splitting across three encounters; authority, draft visibility, lock/unlock, exact retries, watching, fallen squads, retirement, individual rewards and synchronized advancement. Simulated terminal fixtures verify progression transitions; bounded actual AI battles separately verify legal combat, replay restoration and elimination deadlines. These checks do not establish human balance or latency on six physical devices.
