# Multiplayer rules 17

Open `/skirmish`, or choose **Multiplayer · 2–6** from camp. The public game serves private invitation rooms. A room code invites another seat; a separate random player key authorizes that seat's actions. Closing and reopening the same browser restores the seat when storage is available.

## Company creation

Each player brings three distinct character appearances from the 30-character roster. Each character can be named and equipped with four different unlocked catalogue spells, plus the chosen character's signature. Appearance has no bonus health or Flux. Characters start with 8 health and 6 maximum Flux.

Each character has exactly five affinity points, at most three elements, and no affinity above three. The character's native primary element stays highest (ties are allowed) with at least two points. All three characters together cost 15 affinity. Server validation rejects extra stats, unaffordable or duplicate spells, borrowed signatures and illegal allocations before reserving a seat. These equal budgets constrain starting power; they do not establish a competitive metagame.

Story progression and existing rules-16 games remain separate and unchanged. The creator saves the last legal company in the browser. Rooms preserve the company locked at entry.

## Match formats and map seeds

- Free-for-all: two through six players, last surviving company wins.
- Teams: four or six players, alternating seats form two teams; last surviving team wins.
- Three characters per player, one separate starting sector per seat.
- Reproducible seeds, 271 to 547 hexes as player count grows, with connected routes, forests, shallows, marsh, ruins and high ground.
- A simultaneous wipe or the 20-round limit produces a draw.

Players ready individually. Only the host can start a full, ready room. All companies plan privately against the same public state. Movement resolves together before one global spell volley; overlapping fields and midflight projectile clashes include all seats. Team support and harm use actual team identity, while each player can command only their own three characters.

Planning lasts 90 seconds. Following an exchange, the next deadline includes 7.8 seconds for automatic animation before the next full planning window. At the server deadline, new orders are rejected. An authenticated connected client requests timeout resolution; missing companies hold and Guard. There is no background room scheduler when everyone is disconnected. Review and replay remain available while the remote planning clock continues.

Plans are immutable after submission. Compare-and-swap writes make concurrent joins and the final six submissions safe; retries recover the same seat or completed round receipt. A rematch requires every player, keeps the same companies and seed, and creates a fresh match identity. Rooms expire after seven days.

## Presentation

Desktop combat places own characters and actions on the left, other companies on the right, and the battlefield between them. Phone layouts keep the board above a compact command dock with a company overview drawer. Movement, casting, effects and review have explicit phases. Multi-round reconnects show the current state without inventing an animation from an old snapshot.

Scorched, frozen, flooded and blighted trees, plants and ruins use the established pixel palette. Ground and props change at Impact and revert when the authoritative field expires. Fire plus Water displays Steam without a scorched canopy. Fixed scenery does not sway. The multiplayer camera frames active participants rather than distant characters that only Guard.

## Verification commands

```powershell
node --experimental-strip-types --test tests/*.test.ts
node node_modules/typescript/bin/tsc --noEmit
node scripts/run-framework.mjs build
node --experimental-strip-types tests/http-v17-smoke.mjs http://127.0.0.1:8787
node --experimental-strip-types tests/http-v16-smoke.mjs http://127.0.0.1:8787
```

The new D1 table is introduced by the append-only `0001_tiny_master_mold.sql` migration. Existing room tables and legacy rules are retained. The HTTP suite creates test rooms and exercises six independent seats, real AI orders, sealed-plan privacy, complete matches, rematches, and a 3v3 exchange. Automated simulations and responsive viewport checks are not a substitute for human balance playtests or physical-device performance measurements.
