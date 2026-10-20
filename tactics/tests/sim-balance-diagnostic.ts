/**
 * Bounded V3 diagnostic. Run: node --experimental-strip-types tests/sim-balance-diagnostic.ts
 * Ten complementary squad pairs × three cyclic deployments × two public-state
 * policies × two exchanged seats = 120 games. These fixtures do not certify
 * human balance, strategic depth, enjoyment, browser performance or commercial success.
 */
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import {
  CHAMPIONS, MAX_ROUNDS, chooseAIPlan, createSimGame, distance, getCell,
  isAlive, resolveRound, restoreSimState, validatePlan,
} from '../lib/sim.ts';
import type { Player, SimState, TeamPlan } from '../lib/sim.ts';

const ids = CHAMPIONS.map((champion) => champion.id);
const pairs: [string[], string[]][] = [];
for (let second = 1; second < ids.length; second++) for (let third = second + 1; third < ids.length; third++) {
  const left = [ids[0], ids[second], ids[third]];
  pairs.push([left, ids.filter((id) => !left.includes(id))]);
}
const rotate = (roster: string[], steps: number) => [...roster.slice(steps), ...roster.slice(0, steps)];
type Policy = { name: string; plan: (state: SimState, player: Player) => TeamPlan };
const policies: Policy[] = [
  { name: 'native', plan: chooseAIPlan },
  { name: 'cautious-hold', plan: (state, player) => {
    const plan = chooseAIPlan(state, player);
    const enemies = state.units.filter((unit) => unit.owner !== player && isAlive(unit));
    // An independent public-state policy variant: preserve a wounded well holder.
    // It cannot inspect, predict or obtain the opponent's submitted plan.
    for (const order of plan.orders) {
      const unit = state.units.find((entry) => entry.id === order.unitId)!;
      const landing = order.move ?? unit;
      if (unit.hp <= 3 && getCell(state, landing.q, landing.r)?.well && enemies.some((enemy) => distance(enemy, landing) <= 2)) {
        delete order.cast; order.guard = true;
      }
    }
    return validatePlan(state, player, plan);
  } },
];

function physics(state: SimState, inverted = false) {
  const sign = inverted ? -1 : 1;
  const owner = (player: Player) => inverted ? 1 - player : player;
  const coordinate = (value: number) => value === 0 ? 0 : value * sign;
  return {
    round: state.round, version: state.version,
    scores: inverted ? [...state.scores].reverse() : state.scores,
    winner: typeof state.winner === 'number' ? owner(state.winner) : state.winner,
    units: state.units.map((unit) => ({
      owner: owner(unit.owner), championId: unit.championId,
      q: coordinate(unit.q), r: coordinate(unit.r), hp: unit.hp,
      guard: unit.guard ?? false, respawn: unit.respawn ?? null,
    })).sort((a, b) => a.owner - b.owner || a.championId.localeCompare(b.championId)),
    cells: state.cells.map((cell) => ({
      q: coordinate(cell.q), r: coordinate(cell.r), well: cell.well, height: cell.height,
      terrain: cell.terrain, ttl: cell.ttl ?? null,
      elements: cell.elements ?? [], reactions: cell.reactions ?? [],
    })).sort((a, b) => a.q - b.q || a.r - b.r),
  };
}

const started = performance.now();
const runs: { policy: string; pair: number; deployment: number; swapped: boolean; roster: [string[], string[]]; winner: Player | 'draw'; rounds: number; scores: [number, number] }[] = [];
let mirroredRoundChecks = 0;
let totalCasts = 0;
let totalFizzes = 0;
const reactionCounts: Record<string, number> = {};
for (const policy of policies) for (const [pairIndex, pair] of pairs.entries()) for (let deployment = 0; deployment < 3; deployment++) {
  const rosters: [string[], string[]] = [rotate(pair[0], deployment), rotate(pair[1], deployment)];
  const histories: SimState[][] = [];
  for (const swapped of [false, true]) {
    const roster: [string[], string[]] = swapped ? [rosters[1], rosters[0]] : rosters;
    let state = createSimGame(roster);
    const history: SimState[] = [];
    for (let turn = 0; state.winner === null && turn < MAX_ROUNDS; turn++) {
      const plans: [TeamPlan, TeamPlan] = [policy.plan(state, 0), policy.plan(state, 1)];
      state = resolveRound(state, plans);
      restoreSimState(state);
      history.push(state);
      for (const event of state.lastResolution) {
        if (event.kind === 'cast') totalCasts++;
        if (event.kind === 'fizzle') totalFizzes++;
        if (event.kind === 'reaction') for (const element of ['steam', 'magma', 'quagmire', 'penumbra']) {
          const cell = getCell(state, event.q!, event.r!);
          if (cell?.reactions?.includes(element as never)) reactionCounts[element] = (reactionCounts[element] ?? 0) + 1;
        }
      }
    }
    assert.notEqual(state.winner, null, 'Every complete game must terminate by the round cap.');
    histories.push(history);
    runs.push({ policy: policy.name, pair: pairIndex, deployment, swapped, roster, winner: state.winner as Player | 'draw', rounds: history.length, scores: state.scores });
  }
  assert.equal(histories[0].length, histories[1].length, 'Exchanged-seat games must finish in the same round.');
  for (let index = 0; index < histories[0].length; index++) {
    assert.deepEqual(physics(histories[0][index], true), physics(histories[1][index]), `${policy.name}, pair ${pairIndex}, deployment ${deployment}, round ${index + 1}: seat exchange changed physical outcome`);
    mirroredRoundChecks++;
  }
}
const wins = ([0, 1] as const).map((seat) => runs.filter((run) => run.winner === seat).length);
const result = {
  rulesVersion: 3,
  sourceSha256: Object.fromEntries(['lib/sim.ts', 'lib/game.ts', 'tests/sim-balance-diagnostic.ts'].map((path) => [path, createHash('sha256').update(readFileSync(new URL(`../${path}`, import.meta.url))).digest('hex')])),
  fixture: 'All 20 unique squads in 10 complementary pairs; 3 cyclic deployment orders; native and cautious-hold policies; each matchup repeated with squads exchanging seats. Fully deterministic, no random seed or parameter search.',
  games: runs.length, seatWins: wins, draws: runs.filter((run) => run.winner === 'draw').length,
  cappedGames: runs.filter((run) => run.rounds === MAX_ROUNDS).length,
  averageRounds: runs.reduce((sum, run) => sum + run.rounds, 0) / runs.length,
  mirroredRoundChecks, totalCasts, totalFizzes, reactionCounts,
  policies: policies.map((policy) => {
    const games = runs.filter((run) => run.policy === policy.name);
    return { name: policy.name, games: games.length, seatWins: [0, 1].map((seat) => games.filter((run) => run.winner === seat).length), draws: games.filter((run) => run.winner === 'draw').length };
  }),
  squadResultsByChampion: ids.map((championId) => {
    const appearances = runs.flatMap((run) => ([0, 1] as const).filter((seat) => run.roster[seat].includes(championId)).map((seat) => ({ won: run.winner === seat, draw: run.winner === 'draw' })));
    return { championId, games: appearances.length, wins: appearances.filter((game) => game.won).length, draws: appearances.filter((game) => game.draw).length };
  }),
  elapsedNodeMs: Math.round(performance.now() - started),
  limitations: [
    'Paired-seat equality verifies geometry/resolution and these policy tie breaks; it is a correctness invariant, not evidence of human skill balance.',
    'Complementary squads only, 3 of 6 roster permutations, one map, two related shallow policies. No hidden opponent orders are accessible to either policy.',
    'Champion squad results confound teammates, opponent composition, deployment and bot decisions; they do not isolate champion strength.',
    'No human playtests, phone/browser timing, network latency or commercial success claim. Elapsed Node time is diagnostic runtime only.',
  ],
  runs,
};
writeFileSync(new URL('./sim-balance-diagnostic-results.json', import.meta.url), `${JSON.stringify(result, null, 2)}\n`);
const { runs: _runs, ...summary } = result;
console.log(JSON.stringify(summary, null, 2));
