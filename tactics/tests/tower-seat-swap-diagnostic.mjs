import { TOWER_SOLO_STARTERS, chooseTowerRoom, createTowerRun, towerBattleConfig } from '../lib/tower-v23.ts';
import { chooseAIPlan, createTowerBattle, resolveRound } from '../lib/tactics-v22.ts';

const seeds = Array.from({ length: 8 }, (_, index) => `HEX-SWAP-${index + 1}`);
const maximumExchanges = 28;
const results = [];

for (const starter of TOWER_SOLO_STARTERS) {
  for (const seed of seeds) {
    const run = chooseTowerRoom(createTowerRun(seed, starter.id), 'floor-1-0');
    const base = towerBattleConfig(run);

    for (const swapped of [false, true]) {
      const config = swapped
        ? {
            ...base,
            id: `${base.id}:seat-swap`,
            allies: base.enemies,
            enemies: base.allies,
            controllers: Object.fromEntries(base.enemies.map((actor) => [actor.id, 0])),
          }
        : base;
      let state = createTowerBattle(config);
      let exchanges = 0;
      while (state.winner === null && exchanges < maximumExchanges) {
        state = resolveRound(state, [chooseAIPlan(state, 0), chooseAIPlan(state, 1)]);
        exchanges++;
      }

      results.push({
        starter: starter.id,
        seed,
        partySeat: swapped ? 1 : 0,
        winner: state.winner,
        partyWon: state.winner !== null && state.winner !== 'draw' && state.winner === (swapped ? 1 : 0),
        exchanges,
        capped: state.winner === null,
      });
    }
  }
}

const summary = TOWER_SOLO_STARTERS.map((starter) => {
  const games = results.filter((result) => result.starter === starter.id);
  const meanExchanges = games.reduce((sum, game) => sum + game.exchanges, 0) / games.length;
  return {
    starter: starter.id,
    games: games.length,
    partyWins: games.filter((game) => game.partyWon).length,
    seat0Wins: games.filter((game) => game.winner === 0).length,
    seat1Wins: games.filter((game) => game.winner === 1).length,
    draws: games.filter((game) => game.winner === 'draw').length,
    capped: games.filter((game) => game.capped).length,
    meanExchanges: Number(meanExchanges.toFixed(2)),
  };
});

console.log(JSON.stringify({
  experiment: 'Paired first-room AI-vs-AI diagnostic with the starter party in each seat.',
  seeds,
  maximumExchanges,
  limitations: 'One Tower room per seed and starter; deterministic game AI on both sides. This measures side symmetry and opening pace only, not human balance, comprehension, or fun.',
  summary,
  overall: {
    games: results.length,
    partyWins: results.filter((game) => game.partyWon).length,
    seat0Wins: results.filter((game) => game.winner === 0).length,
    seat1Wins: results.filter((game) => game.winner === 1).length,
    draws: results.filter((game) => game.winner === 'draw').length,
    capped: results.filter((game) => game.capped).length,
  },
}, null, 2));
