/**
 * Bounded deterministic balance diagnostic, not a human balance certification.
 * Run: node --experimental-strip-types tests/balance-diagnostic.ts
 * 10 complementary roster pairs × 3 cyclic deployments × 2 policies × 2 seats
 * = 120 games per rules version. No random seeds, no parallel workers, no tuning.
 */
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import * as v1 from '../lib/game-v1.ts';
import * as v2 from '../lib/game.ts';
import type { GameAction, GameState, Player } from '../lib/game.ts';

type Engine = {
  label: string;
  createGame: (rosters: [string[], string[]]) => GameState;
  applyAction: (state: GameState, player: Player, action: GameAction) => GameState;
  chooseAIAction: (state: GameState) => GameAction;
  legalTargets: (state: GameState, unitId: string, kind: 'move' | 'cast') => v2.Cell[];
};
const currentOnly = process.argv.includes('--current-only');
const allEngines: Engine[] = [
  { label: 'v1', createGame: v1.createGame, applyAction: (state, player, action) => {
    if (action.type === 'guard') throw new Error('Guard cannot reach legacy rules.');
    return v1.applyAction(state, player, action as v1.GameAction);
  }, chooseAIAction: v1.chooseAIAction, legalTargets: v1.legalTargets },
  { label: 'v2', createGame: v2.createGame, applyAction: v2.applyAction, chooseAIAction: v2.chooseAIAction, legalTargets: v2.legalTargets },
];
const engines = allEngines.filter((engine) => !currentOnly || engine.label !== 'v1');
const ids = v2.CHAMPIONS.map((champion) => champion.id);
const rosters: string[][] = [];
for (let a = 0; a < ids.length; a++) for (let b = a + 1; b < ids.length; b++) for (let c = b + 1; c < ids.length; c++) rosters.push([ids[a], ids[b], ids[c]]);
const pairs = rosters.filter((roster) => roster.includes(ids[0])).map((roster) => [roster, ids.filter((id) => !roster.includes(id))] as [string[], string[]]);
const rotate = (roster: string[], offset: number) => [...roster.slice(offset), ...roster.slice(0, offset)];

/** Alternate policy: prioritize immediate combat over the built-in policy's hold/defense evaluation. */
function pressure(engine: Engine, state: GameState): GameAction {
  let best: GameAction | undefined;
  let bestValue = 0;
  for (const unit of state.units.filter((entry) => entry.owner === state.turn && v2.isAlive(entry))) {
    const targets = engine.legalTargets(state, unit.id, 'cast');
    for (const enemy of state.units.filter((entry) => entry.owner !== state.turn && v2.isAlive(entry))) {
      if (!targets.some((cell) => cell.q === enemy.q && cell.r === enemy.r)) continue;
      const action: GameAction = { type: 'cast', unitId: unit.id, q: enemy.q, r: enemy.r };
      // Stop a prediction from crossing a turn boundary, respawning a victim, or awarding held wells.
      const predicted = engine.applyAction({ ...state, ap: 2 }, state.turn, action);
      const after = predicted.units.find((entry) => entry.id === enemy.id)!;
      const actorAfter = predicted.units.find((entry) => entry.id === unit.id)!;
      const dislodged = v2.getCell(state, enemy.q, enemy.r)!.well && (enemy.q !== after.q || enemy.r !== after.r);
      const value = (enemy.hp - after.hp) * 3 + (after.hp <= 0 ? 8 : 0)
        + (dislodged ? 3 : 0) + Math.max(0, actorAfter.hp - unit.hp) + (enemy.guard && !after.guard ? 1 : 0);
      if (value > bestValue) { bestValue = value; best = action; }
    }
  }
  return best ?? engine.chooseAIAction(state);
}

type Result = {
  rules: string; policy: string; pair: number; deployment: number; seatsReversed: boolean;
  rosters: [string[], string[]]; winner: Player | 'draw'; scores: [number, number]; rounds: number; actions: number; guards: number;
};
const results: Result[] = [];
for (const engine of engines) {
  for (const policy of ['builtin', 'pressure'] as const) {
    for (let pair = 0; pair < pairs.length; pair++) {
      for (let deployment = 0; deployment < 3; deployment++) {
        const squads = pairs[pair].map((roster) => rotate(roster, deployment)) as [string[], string[]];
        for (const seatsReversed of [false, true]) {
          const matchRosters: [string[], string[]] = seatsReversed ? [squads[1], squads[0]] : squads;
          let state = engine.createGame(matchRosters);
          let actions = 0; let guards = 0;
          while (state.winner === null && actions <= v2.MAX_ROUNDS * 4) {
            const action = policy === 'pressure' ? pressure(engine, state) : engine.chooseAIAction(state);
            if (action.type === 'guard') guards++;
            state = engine.applyAction(state, state.turn, action); actions++;
            const alive = state.units.filter(v2.isAlive);
            assert.equal(new Set(alive.map((unit) => `${unit.q},${unit.r}`)).size, alive.length);
            assert.ok(state.units.every((unit) => unit.hp >= 0 && unit.hp <= unit.maxHp));
          }
          assert.notEqual(state.winner, null, 'Every game must terminate within its action/round budget.');
          results.push({ rules: engine.label, policy, pair, deployment, seatsReversed, rosters: matchRosters,
            winner: state.winner!, scores: state.scores, rounds: state.round, actions, guards });
        }
      }
    }
  }
}

function summarize(games: Result[]) {
  const wins = [games.filter((game) => game.winner === 0).length, games.filter((game) => game.winner === 1).length];
  return {
    games: games.length, seatWins: wins, draws: games.filter((game) => game.winner === 'draw').length,
    meanRounds: Number((games.reduce((sum, game) => sum + game.rounds, 0) / games.length).toFixed(2)),
    roundCapGames: games.filter((game) => game.rounds === v2.MAX_ROUNDS).length,
    guardActions: games.reduce((sum, game) => sum + game.guards, 0),
    championResults: Object.fromEntries(ids.map((id) => {
      const appearances = games.flatMap((game) => game.rosters.map((roster, seat) => ({ roster, seat, winner: game.winner }))).filter((entry) => entry.roster.includes(id));
      const won = appearances.filter((entry) => entry.winner === entry.seat).length;
      const drawn = appearances.filter((entry) => entry.winner === 'draw').length;
      return [id, { games: appearances.length, wins: won, draws: drawn, scoreRate: Number(((won + drawn / 2) / appearances.length).toFixed(3)) }];
    })),
  };
}
const report = {
  experiment: 'Final source rules and unchanged initial state. No in-memory rule patches.',
  scope: 'Paired-seat complementary squads; all 20 rosters; 3 cyclic deployments; built-in and immediate-pressure policies; 120 games per version.',
  limits: 'Deterministic shallow bots, complementary squads only, three of six possible roster orders, one map. Champion results are associations with squads containing that champion, not isolated strength. Findings do not establish human balance, optimal play, statistical independence, or commercial appeal. Structurally motivated candidates were specified before bounded runs; results informed selection. This final run verifies the retained source rules.',
  sourceSHA256: Object.fromEntries(['game-v1.ts', 'game.ts'].map((file) => [file, createHash('sha256').update(readFileSync(new URL(`../lib/${file}`, import.meta.url))).digest('hex')])),
  summary: Object.fromEntries(engines.map((engine) => [engine.label, summarize(results.filter((game) => game.rules === engine.label))])),
  byPolicy: Object.fromEntries(engines.flatMap((engine) => ['builtin', 'pressure'].map((policy) => [`${engine.label}-${policy}`, summarize(results.filter((game) => game.rules === engine.label && game.policy === policy))]))),
  results,
};
writeFileSync(new URL(currentOnly ? './balance-final-diagnostic-results.json' : './balance-diagnostic-results.json', import.meta.url), `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify({ experiment: report.experiment, scope: report.scope, limits: report.limits, sourceSHA256: report.sourceSHA256, summary: report.summary, byPolicy: report.byPolicy }, null, 2));
