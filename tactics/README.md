# H.E.X.

Simultaneous elemental tactics: create a hero and a creature company for the story, or play with friends in a private online match for two to six players. Opposing orders stay private; co-op allies can coordinate drafts. Movement resolves first, and spells travel and interact together. Victory means eliminating the opposing company; springs provide Flux, never victory points.

[Play the tower](https://hex.onetruepath.chatgpt.site/tower) · [Play the campaign](https://hex.onetruepath.chatgpt.site/story) · [Play online](https://hex.onetruepath.chatgpt.site/skirmish)

[Design and implementation handbook](docs/handbook/README.md) · [Current release](docs/release-v45.md) · [Development setup](docs/handbook/DEVELOPMENT.md) · [Continuation brief](docs/handbook/CONTINUATION.md)

This directory is the web tactics game. In [generalgroovy/hex](https://github.com/generalgroovy/hex) it lives under `tactics/`, alongside the separate original Godot game at repository root. The release-45 gameplay baseline is `947019572508ad0e20bb1dbbfe19c0ebeeee7148`. The handoff includes accepted raw art inputs, packers, catalogues, tests and release evidence; no player saves or hosting credentials are included.

New encounters use the explicit `focused-v44` spell profile; saved profiles keep their original spell behavior. New Tower runs use versioned terrain motifs and scout-stable support variants. Compatibility routes and historical tests are retained deliberately.

## Tower

`/tower` uses rules 22 combat with finite projectile contact and compatible legacy replays. Seven solo suggestions are editable starting points: Oh Tipi, S. Wayne, The Red Baron, Steezo, Treevor, Oll’ I and Wa Bidi. Choose any two distinct characters: any of thirty configurable champions or twelve lesser elemental creatures, with no required champion/creature split. Each champion has five affinity points, at most three elements, and four legal spells; its native element stays highest. Creatures keep canonical two-affinity kits. Reassign champion budgets and learned spells between rooms. Opposition scales to the starting squad's immutable affinity total, so earned growth does not secretly strengthen enemies. Nine seeded floors offer partial scouting reports, elite fights, recruitment, recovery, and tuition with an explicit health cost. Each living champion can reveal one random new detail about a chosen battle door per floor. Some enemy spells remain concealed until entry; known rewards and costs stay explicit.

Health carries between rooms. After a victory, surviving fighters recover one health and fallen allies return with one; Flux, cooldowns and statuses reset for the next fight. Each defeated enemy teaches its own technique within the run. Then choose one reward: a usable new spell, affinity training, recovery, or a recruit. Champions keep four equipped spells, plus their signature when its three-point affinity requirement is met. Learning a draft opens the loadout editor so the player can explicitly choose what to replace. Creatures retain their authored techniques and positional bonds.

New release-45 runs add one charm and one scroll slot per fighter. Four charms grant a bounded opening condition; six scrolls each allow one printed-strength cast at zero Flux regardless of affinity, using the normal action. Release consumes the scroll even when intercepted; an unreleased fizzle does not. Selected combat floors can offer equipment without displacing needed recovery and affinity training. Give or swap supplies between fighters between rooms. Existing runs retain their earlier reward model.

The party grows from two to three. Recruitment offers named champions and elemental creatures; a full party requires an explicit replacement, with starting champions protected. Room layouts, opposition and offers are deterministic, and reloading cannot reroll a reward. Run progress, battle, draft orders and previous round live together in `hex-confluence-tower-v23`. Rules & saves provides validated export/import. Earlier saves remain playable at `/tower/legacy-v22` and `/tower/legacy`. Tower progress never grants campaign or competitive power.

`/tower?play=friends` supports two to six players, each with their own two-character squad. Choose connected rooms on the seeded hex route: matching doors place squads in one shared battle, while separate paths split the party. Everyone chooses before the doors open; each owner locks only their own orders, and shared rounds resolve together. Enemies and map space scale with the squads entering. Each player claims their own reward, and the next floor opens when everyone finishes. Discoveries are shared at the stairs. Existing active private encounters finish safely, then adopt shared doors on their next floor. Older shared-squad rooms remain at `/tower/coop/legacy-v22`.

Tower fights deploy closer to the action. Overtime reduces each fighter's total healing by one from round six, and by two from round nine. The rule applies to both sides, including terrain and creature bonds. Ordinary fights start closing ground at round six; bosses at round eight. Victory always requires actual elimination. The Guide provides compact tables for elements, all mixtures, spells and statuses, with searchable catalogues and selected-character values. The route has seeded branching paths and a reachable middle rendezvous; previous room histories remain readable. See [Shared battles](docs/tower-shared-battles.md), [Scouting and reference design](docs/tower-scouting.md), [Tower 23 squad and co-op design](docs/tower-v23.md), [Tower 22 combat verification](docs/tower-v22.md), and [the preserved Tower 21 design](docs/tower-v21.md).

## Campaign

`/story` uses rules 20. Create a named hero from the thirty original H.E.X. appearances, assign five affinity points across up to three elements, and equip four spells. The appearance retains its signature element and creator discount. First victories earn affinity up to eighteen; each element has six levels. The per-element ceiling starts at three and rises to four, five and six over the first three victories. Preparation is free between battles and fixed during a battle.

Command your hero and two elemental creatures through thirty ordered encounters. Encounters 1–10 have one enemy champion and two minions, 11–20 have two champions and one minion, and 21–30 have three champions. Opposition is authored and fixed. Inspect every opponent's actual moves before entering. Completed encounters remain replayable without duplicate rewards.

Recruit from 93 creatures: six pure species per base element, plus all 57 mixed-element lineages. Lesser, standard and greater classes have distinct health, Flux and spell kits. Companions unlock through campaign progress. Partner bonds reward complementary elements and positioning: a surviving recipient must be within two hexes of both living allied creatures. Matching benefits do not stack, and defeated sources stop contributing.

Every champion and creature species teaches one unique spell on its first actual defeat, even in a lost battle. The library includes 171 spells: 48 base spells, 30 champion signatures and 93 creature techniques. Search by spell, source or effect; inspect and compare before explicitly equipping. Optional field encounters make every unlocked creature technique obtainable without awarding extra affinity. Mixed techniques carry every ingredient into projectile collisions and ground reactions.

The campaign profile, battle, draft orders and previous round are saved together in one browser-local record. Settings provides validated save export/import and full or instant playback. Round reports retain all actor events and show HP, Flux and status changes. Undo, redo, clear-order and next-unplanned controls support planning.

The campaign profile and battle save are browser-local. Existing story victories and signatures migrate into a separate profile without replacing the old save keys. `/v19` retains unfinished battles from the previous campaign; `/v16` retains earlier story, practice and local modes. Historical routes, including `/classic`, remain available; old root invitation and seeded-map links route to their original rules.

[Campaign progression and usability audit](docs/campaign-v20-audit.md) · [Campaign foundation](docs/campaign-v19.md)

## Online

`/skirmish` uses rules 18: two to six players, three created characters per player, exactly five affinity per character, and four equipped spells. A character can also use its signature when its native element has three affinity points. Four- and six-player games also support teams. Seeded arenas and separate deployment areas scale with player count. Friends join through private match codes; each browser keeps its own private seat key.

The server validates sealed plans, ownership, versions and legal builds. Public-state bots cannot read opponents' orders. Reconnect in the same browser to resume your seat. Older rules 17 invitations remain supported at `/skirmish/legacy`.

Closing ground prevents endless stalling in new campaign and online matches. The boundary is announced before it advances. Damage applies after movement, spells and displacement, ignoring Guard and Ward; a draw requires actual simultaneous elimination. The schedule scales from eighteen rounds for two companies to twenty-six for six.

[Elimination and closing ground](docs/endgame-v18.md) · [Multiplayer architecture](docs/multiplayer-v17.md)

## Development

React/Vinext, Cloudflare Workers and D1. Node 24 is tested; Node >=22.13 is required. Use `npm.cmd` when PowerShell blocks `npm.ps1`.

```sh
npm run install:ci
npm run db:local
npm run dev -- --host 127.0.0.1
npm run typecheck
npm test
npm run docs:check
npm run build
npm run assets:check
```

For a fresh local multiplayer database, `npm run db:local` applies the SQL migrations in `drizzle/` with a migration ledger. Do not blindly apply it to an older manually initialized database; see [database setup and recovery](docs/handbook/DEVELOPMENT.md). `0002_silly_franklin_storm.sql` preserves shared-battle co-op; `0003_nervous_swarm.sql` adds the independent squad climb table. Then start the built Worker and run the versioned HTTP smoke:

```sh
npm start
node --experimental-strip-types tests/http-v18-smoke.mjs http://127.0.0.1:8787
node --experimental-strip-types tests/http-tower-v23-smoke.mjs http://127.0.0.1:8787
```

Do not share local persistence between simultaneous development and built Worker servers. Local and hosted databases are separate. Campaign 20 needs no database migration. Preserve `.openai/hosting.json` and the Sites integration.

## Source map

- `lib/story-v20.ts`, `campaign-profile-v20.ts`, `campaign-encounters-v20.ts`, `campaign-storage-v20.ts`: ordered travel, creation, progression, migration and rewards.
- `lib/campaign-creatures-v20.ts`, `creature-spells-v20.ts`, `spells-v20.ts`, `tactics-v20.ts`: combat creature kits, positional bonds and simultaneous campaign combat.
- `app/components/CampaignGameV20.tsx`, `CampaignWorkshopV20.tsx`, `CampaignReviewV20.tsx`: campaign planning, enemy inspection and preparation.
- `lib/tactics-v18.ts`, `skirmish-rooms-v18.ts`, `app/api/skirmishes-v18/`: versioned Arena rules and room persistence.
- `lib/arena-v17.ts`, `endgame-v18.ts`: seeded geography and the closing frontier.
- `lib/spells-v16.ts`, `combinations-v16.ts`: spell footprints, affinity scaling and all elemental mixtures.
- `app/components/PixelBattlefieldV16.tsx`: shared presentation adapter only; campaign and multiplayer states always use their own resolvers.
- `app/components/CombatCreatureV19.tsx`, `CreatureBodyV19.tsx`: grounded creature sprites and action poses.
- `public/pixel/manifest.json`: provenance of the original character atlases.

Automated tests establish specific correctness properties. Bot battles expose pacing and matchup problems; they do not establish human difficulty or enjoyment. Browser viewport checks do not substitute for physical-phone testing. Publication and public endpoint verification are separate release evidence.
