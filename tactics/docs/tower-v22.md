# Tower 22

The tower is a nine-floor run. The player builds an elemental party through visible choices and wins each battle by defeating all opponents. Rules 22 are isolated from campaign 20, competitive 18 and legacy tower 21. Existing saves are preserved; `/tower/legacy` continues rules 21.

## Character preparation

All thirty champion appearances are available. A new champion spends exactly five affinity points across at most three elements, with its native element highest and at least two. Four distinct affinity-legal spells fill the configurable loadout. Its creator signature remains separate, with the established two-affinity and two-Flux discount. A broad 2/2/1 build can trade access to the signature for breadth; the interface shows its requirement. HP and Flux are fixed at 8 and 6. Starting creatures are authored lesser, two-affinity companions.

Between rooms, champion affinity can be reassigned within the existing earned budget and the same signature rules. Equipped spells must belong to the run's library. Reconfiguration neither heals the actor nor creates progression. Creature kits remain authored, preserving their roles and party bonds. Saved builds, imports, and network actions use the same authoritative validators.

## Cooperative play

Two players join a private room through its invitation code. Each controls a founding champion. The third companion alternates controllers by floor, and cannot replace either founder. Friendly drafts are shared for planning. Enemy orders are selected before either player's draft, then stored privately. Both players lock before the server resolves one simultaneous round.

Link volley is exclusive to co-op. Both players must consent. Two casts from different controllers, with different primary elements, must reach the same occupied enemy hex after movement. Each caster must have one extra Flux after paying for its spell. A successful Link spends that Flux and deals one additional damage, once per volley. Interception, a moved target, insufficient Flux or missing consent prevents the bonus. Its effect stays on the actual victim and its report names the participating casters.

Room and reward choices require agreement. A player can change their vote before agreement; a stale vote cannot enter a later floor. Both players finish reviewing a concluded battle before choosing its reward. A player whose fighters have fallen is automatically ready, so the surviving partner can continue. The same browser can reconnect to its stored seat. Rooms remain available for seven days after creation, including while disconnected.

The server stores only hashes of seat keys. Snapshots contain no opponent AI plan. Compare-and-swap transactions prevent simultaneous requests resolving twice. Request IDs and payload digests make uncertain retries safe and reject altered replay payloads. Ownership, budgets, action context, JSON size and same-origin requests are validated independently of the client. The new `tower_rooms` table leaves existing multiplayer tables unchanged.

## Pacing and choices

Parties deploy three hexes from the centre while retaining the larger seeded arena. Enemy decisions account for movement commitment, hazards, effective healing and coordinated attacks. Guard, cover, displacement and field interactions retain their normal rules.

Overtime prevents passive healing loops: from round six, each fighter's aggregate healing is reduced by one; from round nine, by two. This is applied once to total spell, terrain, drain and bond healing, not once per source. Both sides follow the same rule, it cannot be cleansed, and the interface displays the current reduction. Closing ground begins on round six in ordinary encounters and round eight for bosses, with an explicit boundary preview. No round limit awards a points victory or a forced draw.

Seeded room variants can start six central hexes flooded, burning or carrying an air current for two exchanges. The room preview describes the actual condition. These change approaches and elemental mixing without adding permanent enemy stat modifiers. Training rewards favour the champion's primary element; a new element is offered only when it can unlock an already-owned spell. Paid tuition can grant two affinity, distinguishing it from free camp training. At the sixth-floor camp, a party still carrying a lesser creature can choose a sturdier standard companion alongside healing or training. The dedicated recruitment room offers greater companions.

## Visual language

Projectiles use six distinct pixel trails and remain visible when zoomed out. Midair interaction cards show actual ingredients and the resulting mixture. Area boundaries follow the actual affected cells. Connected persistent fields share an outside contour, and steam clears the centre of an occupied hex so the fighter remains visible. Terrain motion pauses during movement and casting. Scenery does not sway. Reduced-motion presentation does not reveal effects before their impact.

Both modes separate movement, casting, effects and an untimed review. Co-op shows partner orders while keeping their fighters read-only. Phone layouts retain the map, three-party overview, spell buttons and ready action in the viewport; optional information uses inspections and dialogs.

## Verification boundary

Model and service tests cover authored creature kits, all champion build identities, save validation, controller ownership, Links, healing aggregation, reward eligibility, actual defeat learning, concurrent room operations and reconnect behavior. Browser checks cover desktop and 360×640 layouts, custom creation, two independent seats, voting, shared orders, lock/unlock, resolution and reconnect. These are browser viewport checks, not physical-device tests.

The balance report records seeded bot climbs with their explicit drafting policy. Such trials expose pacing and strategy failures; they do not establish human win rates or prove enjoyment. Final release evidence is recorded in `tower-v22-verification.md`.
