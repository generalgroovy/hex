/** Bounded V4 diagnostic; no tuning or hidden-plan access. Run with node --experimental-strip-types. */
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { CHAMPIONS, SPELLS, MAX_ROUNDS, chooseAIPlan, createSimGame, getCell, isAlive, resolveRound, restoreSimState, validatePlan } from '../lib/tactics-v4.ts';

const seed = 0x48455834;
let randomState = seed;
function random() { randomState = (Math.imul(randomState, 1664525) + 1013904223) >>> 0; return randomState / 4294967296; }
const ids = CHAMPIONS.map((champion) => champion.id);
for (let index = ids.length - 1; index > 0; index--) { const swap = Math.floor(random() * (index + 1)); [ids[index], ids[swap]] = [ids[swap], ids[index]]; }
const teams = Array.from({ length: 10 }, (_, index) => ids.slice(index * 3, index * 3 + 3));
const rotate = (roster, steps) => [...roster.slice(steps), ...roster.slice(0, steps)];
const custom = Object.fromEntries(CHAMPIONS.map((champion, index) => [champion.id, [0, 13, 26, 39].map((offset) => SPELLS[(index * 4 + offset) % SPELLS.length].id)]));
assert.equal(new Set(Object.values(custom).flat()).size, 48);
const policies = [
  { name: 'native', plan: chooseAIPlan },
  { name: 'reserve-and-hold', plan: (state, player) => {
    const plan = chooseAIPlan(state, player);
    for (const order of plan.orders) {
      const unit = state.units.find((entry) => entry.id === order.unitId); const landing = order.move ?? unit;
      if (unit.flux <= 2 || (unit.hp <= 3 && getCell(state, landing.q, landing.r)?.well)) { delete order.cast; delete order.spellId; order.guard = true; }
    }
    return validatePlan(state, player, plan);
  } },
];
function physical(state, flipped = false) {
  const sign = flipped ? -1 : 1; const owner = (value) => flipped ? 1 - value : value; const position = (value) => value * sign || 0;
  return {
    round: state.round, version: state.version, scores: flipped ? [...state.scores].reverse() : state.scores,
    winner: typeof state.winner === 'number' ? owner(state.winner) : state.winner,
    units: state.units.map((unit) => ({ championId: unit.championId, owner: owner(unit.owner), q: position(unit.q), r: position(unit.r), hp: unit.hp, flux: unit.flux, guard: unit.guard ?? false, respawn: unit.respawn ?? null, loadout: unit.loadout, cooldowns: unit.cooldowns, statuses: unit.statuses })).sort((a, b) => a.owner - b.owner || a.championId.localeCompare(b.championId)),
    cells: state.cells.map((cell) => ({ ...cell, q: position(cell.q), r: position(cell.r) })).sort((a, b) => a.q - b.q || a.r - b.r),
  };
}
const started = performance.now(); const runs = []; let mirroredRoundChecks = 0; let castCount = 0; let fizzleCount = 0; const spellsCast = new Set();
for (const policy of policies) for (let pair = 0; pair < teams.length; pair += 2) for (let deployment = 0; deployment < 3; deployment++) for (const profile of ['default', 'catalog']) {
  const squads = [rotate(teams[pair], deployment), rotate(teams[pair + 1], deployment)]; const histories = [];
  for (const swapped of [false, true]) {
    const rosters = swapped ? [squads[1], squads[0]] : squads;
    const loadouts = profile === 'catalog' ? rosters.map((roster) => Object.fromEntries(roster.map((id) => [id, custom[id]]))) : undefined;
    let state = createSimGame(rosters, 'confluence', loadouts); const history = [];
    for (let round = 0; state.winner === null && round < MAX_ROUNDS; round++) {
      const plans = [policy.plan(state, 0), policy.plan(state, 1)]; state = resolveRound(state, plans); restoreSimState(state); history.push(state);
      assert.equal(new Set(state.units.filter(isAlive).map((unit) => `${unit.q},${unit.r}`)).size, state.units.filter(isAlive).length);
      for (const event of state.lastResolution) { if (event.kind === 'cast') { castCount++; spellsCast.add(event.spellId); } if (event.kind === 'fizzle') fizzleCount++; }
    }
    assert.notEqual(state.winner, null); histories.push(history);
    runs.push({ policy: policy.name, pair: pair / 2, deployment, profile, swapped, rosters, winner: state.winner, scores: state.scores, rounds: history.length });
  }
  assert.equal(histories[0].length, histories[1].length);
  for (let index = 0; index < histories[0].length; index++) { assert.deepEqual(physical(histories[0][index], true), physical(histories[1][index]), `Mirror invariant: ${policy.name}, pair${pair / 2}, deployment${deployment}, ${profile}, round${index + 1}`); mirroredRoundChecks++; }
}
const result = {
  rulesVersion: 4, seed,
  sourceSha256: Object.fromEntries(['lib/tactics.ts', 'lib/spells.ts', 'lib/roster.ts', 'tests/tactics-diagnostic.mjs'].map((path) => [path, createHash('sha256').update(readFileSync(new URL(`../${path}`, import.meta.url))).digest('hex')])),
  fixture: 'Seeded shuffle of all30 champions into10 squads; five opposing squad pairs; three cyclic deployments; default and all48-spell catalog loadout profiles; two related public-state policies; paired exchanged seats. 120 games, no parameter tuning.',
  games: runs.length, seatWins: [0, 1].map((seat) => runs.filter((run) => run.winner === seat).length), draws: runs.filter((run) => run.winner === 'draw').length,
  cappedGames: runs.filter((run) => run.rounds === MAX_ROUNDS).length, averageRounds: runs.reduce((sum, run) => sum + run.rounds, 0) / runs.length,
  mirroredRoundChecks, castCount, fizzleCount, distinctSpellsCast: spellsCast.size, unusedSpells: SPELLS.filter((spell) => !spellsCast.has(spell.id)).map((spell) => spell.id),
  policies: policies.map((policy) => ({ name: policy.name, seatWins: [0, 1].map((seat) => runs.filter((run) => run.policy === policy.name && run.winner === seat).length), draws: runs.filter((run) => run.policy === policy.name && run.winner === 'draw').length })),
  elapsedNodeMs: Math.round(performance.now() - started),
  limitations: ['Seeded fixtures cover every identity and equip every spell but only five squad pairings and three deployment permutations. They do not cover all team/loadout matchups.', 'Seat symmetry verifies engine and policy invariants. These related shallow bots do not prove human balance, strategic depth, enjoyable pacing, browser performance or commercial potential.', 'Spells equipped but not cast reflect AI limitations. Every spell has a separate legal-resolution test; neither check proves every tactical interaction.'],
  runs,
};
if (process.argv[2]) writeFileSync(process.argv[2], `${JSON.stringify(result, null, 2)}\n`);
const { runs: _runs, ...summary } = result; console.log(JSON.stringify(summary, null, 2));
