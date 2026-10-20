# Architecture and compatibility

This handbook describes the release 45 web game. In the combined H.E.X. repository, this application lives under `tactics/`; paths below are relative to that application, not to the original Godot project. The web game has its own dependencies, build, data migrations, saves, and multiplayer service. The repository folder does not add a `/tactics` URL prefix: the current application routes assume their deployment origin's root.

The most important maintenance rule is to preserve the distinction between **native game state**, **presentation state**, and **private server state**. A successful render is not evidence that a command, save, or multiplayer transition is valid.

For player-facing interaction contracts, see [UX and accessibility](./UX-AND-ACCESSIBILITY.md).

## Source map

| Location | Responsibility |
| --- | --- |
| [`app/`](../../app) | App-router pages, API route handlers, and game-specific React components. |
| [`lib/`](../../lib) | Native combat resolvers, catalogues, seeded generation, validators, storage, previews, network services, and presentation helpers. Most deterministic game behavior lives here. |
| [`public/`](../../public) | Served artwork, sprite sheets, portraits, and fonts. Components and art metadata select these assets. |
| [`db/schema.ts`](../../db/schema.ts), [`drizzle/`](../../drizzle) | D1 table declarations and migration history. Multiplayer stores versioned JSON envelopes, not one SQL row per combatant. |
| [`build/`](../../build), [`scripts/`](../../scripts) | Worker integration, runtime profile selection, build and verification utilities. |
| [`tests/`](../../tests) | Native rules, restore, service, rendering, input, transport, and acceptance tests. Read a test's fixture and assertions before treating it as coverage of a whole mode. |
| [`vite.config.ts`](../../vite.config.ts), [`package.json`](../../package.json) | Framework and worker configuration, dependencies, and entry commands. |

The installed application uses React, TypeScript, Vinext/Vite, and Cloudflare Workers/D1 with Next-compatible routing APIs. It is not a static React-only export. [`scripts/run-framework.mjs`](../../scripts/run-framework.mjs) selects the supported development/build path for the execution profile; production-preview startup uses the generated worker configuration. Follow the repository's setup instructions rather than replacing that path with a generic Next deployment command.

Generated directories such as `dist/`, `.vinext/`, `.next/`, and local `.wrangler/` state are not authoritative source. Local database state also does not represent the hosted D1 database.

## Routes and entry points

| URL | Current entry | Notes |
| --- | --- | --- |
| `/` | [`HexHomeV41`](../../app/components/HexHomeV41.tsx) | Displays Story, Tower, Arena, and browser saves. An incoming `room` or `seed` query redirects to `/v16` to preserve old links. |
| `/story` | [`CampaignGameV20`](../../app/components/CampaignGameV20.tsx) | Local campaign profile and battle session. |
| `/tower` | [`TowerGameV23`](../../app/components/TowerGameV23.tsx) | Solo side of the unified Tower mode. |
| `/tower?play=friends`, `/tower?code=…` | [`CoopTowerV23`](../../app/components/CoopTowerV23.tsx) | Server-authoritative cooperative Tower. |
| `/tower/coop` | Redirect | Preserves old cooperative entry links and forwards their code to `/tower?play=friends`. |
| `/skirmish` | [`SkirmishGameV18`](../../app/components/SkirmishGameV18.tsx) | The mode displayed as **Arena**. There is no separate current `/arena` route. |
| `/saves` | [`BrowserSaves`](../../app/components/BrowserSaves.tsx) | Export/import of allowlisted browser records, including private seat credentials. |
| `/animation-review` | Art review page | Development/review surface; not part of the primary game progression. |

Older `/classic`, versioned `/v…` pages, `/skirmish/legacy`, and Tower legacy pages remain compatibility surfaces. Do not remove them merely because the home menu no longer advertises them. Current APIs are `/api/skirmishes-v18` and `/api/tower-v23`; legacy room and Tower APIs coexist.

## Rules generations are not release numbers

| Concern | Current implementation | Compatibility boundary |
| --- | --- | --- |
| Arena combat | [`tactics-v18.ts`](../../lib/tactics-v18.ts) | Native `rulesVersion: 18`; supports its own multiplayer state and validator. |
| Story combat | [`tactics-v20.ts`](../../lib/tactics-v20.ts) | Native `rulesVersion: 20`; campaign progression is separate from battle resolution. |
| Tower combat | [`tactics-v22.ts`](../../lib/tactics-v22.ts) | Native `rulesVersion: 22`; Tower run/session/network code uses later file names. |
| Tower run and session | [`tower-v23.ts`](../../lib/tower-v23.ts) | Run and session `format: 3`; route, battle, reward, and terminal phases. |
| Tower networking | [`tower-rooms-v23.ts`](../../lib/tower-rooms-v23.ts) | Protocol 23. This does not mean it resolves battles with a hypothetical `tactics-v23`. |
| Spell area model | [`spell-profile-v42.ts`](../../lib/spell-profile-v42.ts) | `CURRENT_SPELL_MODEL` is `focused-v44`; saved `focused` and absent legacy models retain their own behavior. |
| Projectile model | Native combat state and [`projectile-interception-v20.ts`](../../lib/projectile-interception-v20.ts) | Saved replay geometry respects its model; current resolution opts into volume contacts. |
| Tower encounter model | [`tower-terrain-v44.ts`](../../lib/tower-terrain-v44.ts) and run flags | `encounterModel: 'motifs44'` opts into new geometry; absent flags preserve earlier saved encounters. |
| Tower supplies | [`tower-supplies-v45.ts`](../../lib/tower-supplies-v45.ts) | `suppliesModel: 'v45'` opts new runs into charms/scrolls. Older runs do not silently acquire this reward model. |

A `V16` component can be current presentation code. A `V42` helper can serve release 45. These names record compatibility history; neither renaming every file nor changing every version number is an upgrade strategy.

New battle constructors use the current spell model. A pending saved battle, its command panel, Guide, replay, and effect preview must use **that battle's saved model**. Passing the current default into a legacy battle changes what the interface promises without changing the authoritative result.

## Native data and presentation

Shared foundations include [`roster-v13.ts`](../../lib/roster-v13.ts) for champions and affinities and [`combinations-v16.ts`](../../lib/combinations-v16.ts) for six pure elemental fields and their 57 multi-element combinations. Story and Tower use [`spells-v20.ts`](../../lib/spells-v20.ts) for spells/access/effective values and [`campaign-creatures-v20.ts`](../../lib/campaign-creatures-v20.ts) for creatures and perks. Arena's native resolver imports [`spells-v16.ts`](../../lib/spells-v16.ts); its champion-only catalogue does not acquire creature techniques because a shared Guide or renderer can display them. Each native resolver decides which definitions are legal and how they apply.

The main data flow is:

```text
Legal build + saved model + seed
                ↓
Native state → legal local command draft → native validation/resolution
     ↓                                            ↓
Public presentation adapter             next state + resolved events
     ↓                                            ↓
Board, Guide, conditional previews       local playback + consequence review
```

[`PixelBattlefieldV16`](../../app/components/PixelBattlefieldV16.tsx) is the shared board. Story, Arena, and Tower adapt native units/events for it through their host components and presentation helpers, including [`story-v20.ts`](../../lib/story-v20.ts) and [`arena-presentation-v44.ts`](../../lib/arena-presentation-v44.ts). The renderer does not replace a mode's native resolver.

The board receives spell-rule callbacks rather than assuming every game uses the original V16 spell implementation. Tower's [`tower-preview-v45.ts`](../../lib/tower-preview-v45.ts) supplies native legality, area, and per-order spell interpretation to shared preview helpers. This matters for scrolls: a scroll is a normal casting action with its own cost, printed strength, and consumption rules, not an ordinary equipped spell evaluated through the champion's affinity.

[`planned-volley-v20.ts`](../../lib/planned-volley-v20.ts), [`planning-forecast-v20.ts`](../../lib/planning-forecast-v20.ts), and [`target-impact-v41.ts`](../../lib/target-impact-v41.ts) make conditional predictions from permitted information. [`combat-consequence-v44.ts`](../../lib/combat-consequence-v44.ts) explains resolved events. Keep those two jobs separate: a forecast cannot assume hidden rival orders, while a consequence report should not infer damage from animation alone.

The local playback clock in [`playback-clock-v44.ts`](../../lib/playback-clock-v44.ts) coordinates visual phases, CSS/WAAPI animations, and sound through the presentation hooks. Pause, speed, phase-step, replay, and instant results are local viewing controls. They never resolve another round, submit readiness, or advance the cooperative floor barrier.

## Tower generation and progression

Tower has nine floors and one shared mode with solo and cooperative entry. A legal initial squad contains two freely chosen characters. The route records the number of occupied launch seats; regular floor width is players plus two, from three solo lanes to eight for six players. The summit has one boss destination.

[`tower-route-map.ts`](../../lib/tower-route-map.ts) generates deterministic links, including a common rendezvous so split squads can meet again. [`arena-v17.ts`](../../lib/arena-v17.ts) provides seeded board generation; opted-in Tower motifs add terrain structure. Preserve the saved seed, model flags, room identity, and encounter variant when rebuilding a battle.

Room clues and scout results are generated in [`tower-scouting.ts`](../../lib/tower-scouting.ts) and its state/action helpers. A champion can scout one aspect per floor. Reports have provenance and encounter compatibility; a different squad's variant must not reveal a foe that is absent from the viewer's room.

Choosing the same destination joins squads in one battle. Different destinations produce separate battles at the same depth. Joined composition is assembled by [`tower-shared-battle-v23.ts`](../../lib/tower-shared-battle-v23.ts), preserving lead enemies and valid revealed facts. Split encounters can offer more distinct teaching opportunities; they do not receive spells from enemies that were never defeated. Learned spells are shared at the floor barrier.

## Authoritative cooperative service

[`tower-rooms-v23.ts`](../../lib/tower-rooms-v23.ts) is the Tower authority; the browser sends intentions, not replacement battles. It validates builds, ownership, phase, action fields, native orders, rewards, supplies, and run/step identity before persisting a transition.

### Identity and visibility

- Invitations use a 12-character room code. The code permits joining available seats; it is not the credential for controlling an existing squad.
- A seat has a random 32-byte token, encoded as 64 hexadecimal characters. Requests carry it as a bearer token. D1 stores a SHA-256 token hash.
- Rejoining with an existing token recovers that seat even after the run starts. A new player cannot take an occupied or already-started seat by supplying the room code alone.
- The private envelope contains token hashes and precomputed enemy plans. `snapshot()` constructs the public response explicitly; neither is returned.
- In a joined cooperative battle, teammates' current drafts are intentionally shared for coordination. Watching another friendly squad does not transfer ownership. This is different from competitive Arena, which exposes lock state and the caller's own submitted plan, not opponents' sealed orders.
- Enemy AI orders are prepared at the start of a battle/step or after the preceding resolution, before the next player orders are submitted.

Browser backups can include seat tokens. Treat such a backup as access to those seats, not as a harmless settings export.

### Concurrency and safe retries

Each room row contains a JSON envelope and a monotonic database `version`. A write uses compare-and-swap:

```sql
UPDATE tower_rooms_v23
SET data_json = ?, version = version + 1, updated_at = ?, expires_at = ?
WHERE code = ? AND version = ? AND expires_at > ?
RETURNING *
```

Conflicts reload the authoritative row and retry within a bound. Actions also carry `runId`, `stepId`, and `requestId`. The service retains the latest 32 per-player request receipts with a stable payload digest:

- Repeating the same request identity and body returns the current snapshot without applying the action again.
- Reusing an identity with a different body returns `REQUEST_CHANGED`.
- An obsolete run or step returns `STALE_STEP`.
- Creating/joining reuses a client-generated token so a lost response does not create another seat.

[`tower-client-v23.ts`](../../lib/tower-client-v23.ts) adds at most two transport retries, after 250 ms and 700 ms, for eligible idempotent requests on network failures or HTTP 502/503/504. It preserves the exact serialized body and identity. Aborts/timeouts and business-rule failures are not automatically retried. Do not “fix” a stale action by assigning it a fresh request ID and resubmitting it against a different decision.

### Two independent barriers

1. **Combat readiness:** every participating seat with living controlled fighters submits its own orders. The service combines permitted allied orders and resolves against the sealed enemy plan. A joint link requires the participating plans to opt in.
2. **Floor readiness:** every remaining squad completes its room and reward decision before the next floor opens. Learned spells are shared there; the barrier does not grant free healing.

Room selection has its own gathering stage: players may replace their selected destination directly before launch. Withdrawing selection unlocks scouting and squad editing. Local playback and inspection do not alter these barriers.

There is no automatic Tower turn timeout or host takeover of an absent player's squad. An absent player can hold progress; returning with the original credential or that player's explicit retirement is the supported path.

### Retention and HTTP boundary

An unfinished Tower room has a seven-day inactivity expiry. A successful authenticated mutation extends it; reads, polling, and receipt replays do not. Finished rooms keep their existing expiry. The snapshot includes the exact expiry for the recovery interface.

The API checks same-origin requests when an Origin header is present, rejects mismatched `X-Confluence-Protocol` values, accepts bounded JSON bodies, rate-limits requests in D1, and returns private/no-store responses. A missing database binding is an unavailable service, not permission to fall back to browser-authoritative multiplayer. See [`tower-http-v23.ts`](../../lib/tower-http-v23.ts), the shared bounded body reader in [`tower-http-v22.ts`](../../lib/tower-http-v22.ts), and [`app/api/tower-v23/_shared.ts`](../../app/api/tower-v23/_shared.ts).

Arena is a separate contract in [`skirmish-rooms-v18.ts`](../../lib/skirmish-rooms-v18.ts): protocol 18, sealed plans, a 90-second planning deadline, timeout resolution of missing orders as Guard, and expiry fixed from creation. Tower's sliding expiry and no-timeout behavior must not be described as universal multiplayer behavior.

## Browser persistence and restore

| Data | Storage contract |
| --- | --- |
| Story | [`campaign-storage-v20.ts`](../../lib/campaign-storage-v20.ts) validates an atomic session containing profile and optional battle/draft/previous state. Current session key: `hex-confluence-campaign-session-v20`. |
| Solo Tower | Native `TowerSession` format 3 under `hex-confluence-tower-v23`; restored battle identity must match its run. |
| Co-op Tower | `hex-tower-coop-seat-v23:<code>` stores credentials; `hex-tower-coop-last-v23` identifies the last room; pending entry identity supports recovery after a lost response. The battle itself remains authoritative in D1. |
| Arena | `confluence-arena-session-v18`, per-room seat records, and per-match drafts. These use their own helpers; do not assume all modes have identical fallback precedence. |
| Presentation | `hex-presentation-v44`: sound, motion preference, and audio mix. It is not combat state. |

The shared Story/Tower storage helper prefers a session fallback when present because that can be newer than a failed local-storage write. A successful local write clears the fallback. Both writes can fail, so a UI warning is meaningful; “saved” cannot be assumed merely because React state changed.

[`browser-backup.ts`](../../lib/browser-backup.ts) exports only allowlisted H.E.X. keys from local and session storage. Import validates the transport envelope and size bounds, previews conflicts, defaults to adding missing records, and can explicitly replace records. Local/session pairs are handled together to avoid an old fallback shadowing an imported save. Writes are verified and rollback is attempted on failure; a failure can still report incomplete rollback if browser storage refuses restoration.

Backup import does not itself validate every embedded native battle. The mode's loader does that when opening it. It also cannot recreate expired D1 rooms, recover lost server data, or migrate the hosted database to another deployment.

The internal `confluence` names in keys, headers, and tables are compatibility identifiers. The displayed game name is H.E.X.; changing branding is not authorization to invalidate existing saves or invitations.

## Safe change boundaries

Before changing a shared rule:

1. Identify every native resolver and saved-model branch affected.
2. Keep old pending states/replays reproducible, or provide an explicit tested migration with recovery.
3. Update native legality and resolution before adapting command previews, Guide values, renderer callbacks, and event explanations.
4. For a new network action, validate ownership, phase, payload, run/step identity, receipt replay, and compare-and-swap behavior on the server.
5. Check that public snapshots and errors still omit sealed orders and credentials.
6. Test both new and legacy fixtures, including restore after the changed event, not just the initial state.

Useful targeted evidence lives in [`tower-rooms-v23.test.ts`](../../tests/tower-rooms-v23.test.ts), [`tower-shared-battle-v23.test.ts`](../../tests/tower-shared-battle-v23.test.ts), [`tower-client-v23.test.ts`](../../tests/tower-client-v23.test.ts), [`tower-supplies-service-v45.test.ts`](../../tests/tower-supplies-service-v45.test.ts), [`spell-profile-v42.test.ts`](../../tests/spell-profile-v42.test.ts), and [`browser-backup.test.ts`](../../tests/browser-backup.test.ts). Passing these is evidence of their assertions, not a substitute for production HTTP checks, real device input, listening, or human playtesting.
