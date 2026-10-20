import test from 'node:test';
import assert from 'node:assert/strict';
import { CHAMPIONS as OLD_CHAMPIONS } from '../lib/roster.ts';
import { SPELLS as OLD_SPELLS } from '../lib/spells.ts';
import { createSimGame as createV6, restoreSimState as restoreV6 } from '../lib/tactics.ts';
import { CHAMPIONS, ALL_SPELLS, SPELLS, MOVE_RANGE, POINTS_TO_WIN, MAX_ROUNDS, availableSpellIds, getSignature, createSimGame, restoreSimState, resolveRound, validatePlan, validateLoadout, defaultLoadout, spellCost, getSpell, getCell, legalCasts, legalMoves, movementPath, movementCost, movementBudget, terrainCover, isCellSolid, castAvailability, chooseAIPlan, spellArea } from '../lib/tactics-v7.ts';
import { SIGNATURES } from '../lib/spells-v7.ts';
import type { Order, SimState, SimUnit, TeamPlan } from '../lib/tactics-v7.ts';

const empty = (): TeamPlan => ({ orders: [] });
const plan = (...orders: Order[]): TeamPlan => ({ orders });
const cast = (unit: SimUnit, spellId: string, q = unit.q, r = unit.r): Order => ({ unitId: unit.id, spellId, cast: { q, r } });
const equip = (unit: SimUnit, ...ids: string[]) => { unit.loadout = [...ids, ...SPELLS.map(spell => spell.id).filter(id => !ids.includes(id))].slice(0, 4); };
/** Deliberately synthetic clear geometry isolates combat rules; restore tests use untouched seeded geometry. */
function duel(champion = 'oh_tipi'): SimState {
  const others = CHAMPIONS.filter(entry => entry.id !== champion).slice(0, 2).map(entry => entry.id);
  const state = createSimGame([[champion, ...others], ['oh_tipi', 's_wayne', 'treevor_mason']]);
  for (const cell of state.cells) { cell.biome = 'plain'; cell.terrain = 'plain'; cell.height = 0; cell.well = false; }
  Object.assign(state.units[0], { q: 0, r: 0 }); Object.assign(state.units[3], { q: 2, r: 0 });
  return state;
}
function noGuard(unit: SimUnit): Order { equip(unit, 'mend'); return cast(unit, 'mend'); }

test('rules 7 gives every original champion exactly four points without adding or deleting elements', () => {
  assert.equal(CHAMPIONS.length, 30); assert.equal(MOVE_RANGE, 4); assert.equal(POINTS_TO_WIN, 16); assert.equal(MAX_ROUNDS, 20);
  for (const champion of CHAMPIONS) {
    const original = OLD_CHAMPIONS.find(entry => entry.id === champion.id)!;
    assert.deepEqual(Object.keys(champion.affinities).sort(), Object.keys(original.affinities).sort());
    assert.equal(Object.values(champion.affinities).reduce((sum, value) => sum + value, 0), 4);
    assert.ok(Object.values(champion.affinities).every(value => value === 1 || value === 2));
    assert.equal(champion.affinities[champion.element], 2);
    assert.equal(champion.name, original.name); assert.equal(champion.sprite, original.sprite);
    assert.deepEqual(validateLoadout(champion.id, defaultLoadout(champion.id)), defaultLoadout(champion.id));
  }
  assert.ok(OLD_CHAMPIONS.every(champion => Object.values(champion.affinities).reduce((sum, value) => sum + value, 0) === 3));
});

test('48 configurable spells retain footprints and scale positive reach by one; signatures occupy no equip slot', () => {
  assert.equal(SPELLS.length, 48); assert.equal(SIGNATURES.length, 30); assert.equal(ALL_SPELLS.length, 78);
  assert.equal(new Set(ALL_SPELLS.map(spell => spell.id)).size, 78);
  for (const original of OLD_SPELLS) {
    const current = getSpell(original.id);
    assert.equal(current.range, original.range ? original.range + 1 : 0);
    for (const field of ['cost', 'cooldown', 'shape', 'radius', 'damage', 'heal', 'harm'] as const) assert.equal(current[field], original[field]);
  }
  const effects = new Set<string>();
  for (const champion of CHAMPIONS) {
    const signature = getSignature(champion.id), equipped = defaultLoadout(champion.id);
    assert.equal(signature.signatureChampionId, champion.id); assert.equal(spellCost(champion.id, signature.id), 3); assert.equal(signature.cooldown, 3);
    assert.deepEqual(availableSpellIds(champion.id, equipped), [...equipped, signature.id]);
    assert.throws(() => validateLoadout(champion.id, [signature.id, ...equipped.slice(0, 3)]));
    const { id: _id, name: _name, description: _description, signatureChampionId: _champion, ...effect } = signature;
    effects.add(JSON.stringify(effect));
  }
  assert.equal(effects.size, 30, 'signatures have mechanically distinct definitions, not different labels for one action');
});

test('all 30 signatures resolve from a legal public position and restore their cooldown/event state exactly', () => {
  for (const champion of CHAMPIONS) {
    const others = CHAMPIONS.filter(entry => entry.id !== champion.id).slice(0, 2).map(entry => entry.id);
    const state = createSimGame([[champion.id, ...others], ['oh_tipi', 's_wayne', 'treevor_mason']]);
    const unit = state.units[0], signature = getSignature(champion.id);
    const target = legalCasts(state, unit.id, undefined, signature.id)[0]; assert.ok(target, champion.id);
    const before = structuredClone(state), result = resolveRound(state, [plan(cast(unit, signature.id, target.q, target.r)), empty()]);
    assert.deepEqual(state, before, 'resolution does not mutate its snapshot');
    assert.ok(result.lastResolution.some(event => event.kind === 'cast' && event.spellId === signature.id), champion.id);
    assert.equal(result.units[0].cooldowns[signature.id], 3);
    assert.deepEqual(restoreSimState(result), result, champion.id);
  }
});

test('signature ownership, action exclusivity, Flux and complete-round recovery are enforced server-side', () => {
  const state = createSimGame(), unit = state.units[0], signature = getSignature(unit.championId), foreign = getSignature(state.units[1].championId);
  const target = legalCasts(state, unit.id, undefined, signature.id).find(cell => cell.q === unit.q && cell.r === unit.r)!;
  assert.equal(castAvailability(state, unit.id, foreign.id).available, false);
  assert.throws(() => validatePlan(state, 0, plan(cast(unit, foreign.id))));
  const forged = structuredClone(state); forged.units[0].loadout[0] = foreign.id;
  assert.equal(castAvailability(forged, unit.id, foreign.id).available, false, 'foreign signature cannot become owned by a forged equip slot');
  assert.throws(() => validatePlan(state, 0, plan({ ...cast(unit, signature.id, target.q, target.r), guard: true })));
  assert.throws(() => validatePlan(state, 0, plan(cast(unit, signature.id), cast(unit, unit.loadout[0]))));
  unit.flux = 2; assert.equal(castAvailability(state, unit.id, signature.id).available, false); unit.flux = 6;
  let result = resolveRound(state, [plan(cast(unit, signature.id)), empty()]);
  assert.equal(result.units[0].flux, 5, '3 spent and 2 regenerated; no free signature action');
  for (const remaining of [3, 2, 1]) {
    assert.equal(result.units[0].cooldowns[signature.id], remaining);
    assert.equal(castAvailability(result, unit.id, signature.id).available, false);
    result = resolveRound(result, [empty(), empty()]);
  }
  assert.equal(castAvailability(result, unit.id, signature.id).available, true);
});

test('strict restore rejects foreign signature cooldowns, forged permanent biomes and cross-version saves', () => {
  const state = createSimGame(), old = createV6();
  assert.deepEqual(restoreSimState(state), state); assert.deepEqual(restoreV6(old), old);
  assert.throws(() => restoreSimState(old)); assert.throws(() => restoreV6(state));
  const stolen = structuredClone(state); stolen.units[0].cooldowns[getSignature(stolen.units[1].championId).id] = 1; assert.throws(() => restoreSimState(stolen));
  const changed = structuredClone(state); changed.cells[0].biome = changed.cells[0].biome === 'forest' ? 'plain' : 'forest'; assert.throws(() => restoreSimState(changed));
  const occupied = structuredClone(state), ruin = occupied.cells.find(cell => cell.biome === 'ruins')!;
  Object.assign(occupied.units[0], { q: ruin.q, r: ruin.r }); assert.throws(() => restoreSimState(occupied));
});

test('marsh entry costs two without stacking climb, and a four-effort route respects the cost', () => {
  const state = duel(), actor = state.units[0];
  for (const cell of state.cells) cell.biome = cell.r === 0 && cell.q >= 0 && cell.q <= 4 ? 'plain' : 'ruins';
  const marsh = getCell(state, 1, 0)!; marsh.biome = 'marsh'; marsh.terrain = 'water';
  assert.equal(movementCost(getCell(state, 0, 0)!, marsh), 2); assert.equal(movementCost(marsh, getCell(state, 2, 0)!), 1);
  assert.equal(movementPath(state, actor.id, { q: 3, r: 0 })?.length, 3);
  assert.equal(movementPath(state, actor.id, { q: 4, r: 0 }), null);
  marsh.height = 1; assert.equal(movementCost(getCell(state, 0, 0)!, marsh), 2, 'marsh and climb do not stack'); marsh.height = 0;
  actor.statuses.haste = { turns: 1, power: 1 }; assert.equal(movementPath(state, actor.id, { q: 4, r: 0 })?.length, 4);
  actor.statuses.chilled = { turns: 1, power: 1 }; assert.equal(movementBudget(actor), 4); delete actor.statuses.haste; assert.equal(movementBudget(actor), 3);
});

test('permanent ruins block routes, spell sight, line footprints and displacement even beneath an effect', () => {
  const state = duel(), actor = state.units[0], enemy = state.units[3], ruin = getCell(state, 1, 0)!;
  ruin.biome = 'ruins'; ruin.terrain = 'earth'; equip(actor, 'stone', 'fire_lance');
  assert.equal(isCellSolid(ruin), true); assert.ok(!legalMoves(state, actor.id).some(cell => cell === ruin));
  assert.ok(!legalCasts(state, actor.id, undefined, 'stone').some(cell => cell.q === 2 && cell.r === 0));
  assert.equal(spellArea(state, actor.id, 'fire_lance', enemy).length, 0);
  ruin.terrain = 'steam'; ruin.elements = ['fire', 'water', 'earth']; ruin.ttl = 1;
  assert.equal(isCellSolid(ruin), true, 'temporary visual field does not erase permanent collision');
  ruin.biome = 'plain'; Object.assign(enemy, { q: 1, r: 0 }); const wall = getCell(state, 2, 0)!; wall.biome = 'ruins'; wall.terrain = 'earth'; equip(actor, 'gust');
  const result = resolveRound(state, [plan(cast(actor, 'gust', 1, 0)), plan(noGuard(enemy))]);
  assert.deepEqual({ q: result.units[3].q, r: result.units[3].r }, { q: 1, r: 0 });
  assert.ok(result.lastResolution.some(event => event.kind === 'bounce' && event.unitId === enemy.id));
});

test('forest mitigates aggregate nonpiercing spell damage once; piercing, Burn and environmental harm bypass it', () => {
  const state = duel('treevor_mason'), actor = state.units[0], ally = state.units[1], enemy = state.units[3];
  Object.assign(ally, { q: 0, r: 1 }); const forest = getCell(state, enemy.q, enemy.r)!; forest.biome = 'forest'; forest.terrain = 'earth';
  equip(actor, 'stone', 'shatter'); equip(ally, 'stone'); const enemyOrder = noGuard(enemy);
  assert.equal(terrainCover(forest), 1);
  const hit = resolveRound(state, [plan(cast(actor, 'stone', 2, 0), cast(ally, 'stone', 2, 0)), plan(enemyOrder)]);
  assert.equal(hit.units[3].hp, 8, '3 damage once-covered, healed3 in the same exchange');
  assert.equal(hit.lastResolution.find(event => event.kind === 'damage' && event.unitId === enemy.id)?.amount, 3);
  const pierced = resolveRound(state, [plan(cast(actor, 'shatter', 2, 0)), plan(enemyOrder)]);
  assert.equal(pierced.lastResolution.find(event => event.kind === 'damage' && event.unitId === enemy.id)?.amount, 3);
  enemy.statuses.burn = { turns: 1, power: 1 };
  const burn = resolveRound(state, [empty(), plan(enemyOrder)]);
  assert.equal(burn.lastResolution.find(event => event.kind === 'damage' && event.unitId === enemy.id)?.amount, 1);
  equip(actor, 'ember'); const magma = resolveRound(state, [plan(cast(actor, 'ember', 2, 0)), plan(enemyOrder)]);
  assert.ok(magma.lastResolution.some(event => event.kind === 'surface' && event.unitId === enemy.id && event.amount === 1));
});

test('dispel and expiring spell fields reveal the original seeded biome and retain its rules', () => {
  const state = createSimGame(), actor = state.units[0]; equip(actor, 'shatter');
  const target = state.cells.find(cell => cell.biome === 'ruins' && legalCasts(state, actor.id, undefined, 'shatter').some(aim => aim.q === cell.q && aim.r === cell.r));
  assert.ok(target, 'seed supplies an accessible ruin for the fixture');
  let result = resolveRound(state, [plan(cast(actor, 'shatter', target.q, target.r)), empty()]);
  assert.equal(getCell(result, target.q, target.r)!.biome, 'ruins'); assert.equal(isCellSolid(getCell(result, target.q, target.r)!), true);
  result = resolveRound(result, [empty(), empty()]);
  assert.equal(getCell(result, target.q, target.r)!.terrain, 'earth'); assert.equal(getCell(result, target.q, target.r)!.ttl, undefined);
  assert.deepEqual(restoreSimState(result), result);
});

test('Current Anchor combines Burn prevention now with push resistance next round in one action', () => {
  const state = duel('oh_tipi'), actor = state.units[0], enemy = state.units[3]; actor.hp = 4; actor.statuses.burn = { turns: 1, power: 1 };
  equip(enemy, 'ember', 'gale'); const signature = getSignature(actor.championId);
  const first = resolveRound(state, [plan(cast(actor, signature.id)), plan(cast(enemy, 'ember', 0, 0))]);
  assert.equal(first.units[0].hp, 5, 'Wet suppresses old/new Burn; Fire+Water Steam halves the hit to1; healing2 applies');
  assert.ok(first.units[0].statuses.anchored); assert.equal(first.units[0].statuses.burn, undefined);
  const second = resolveRound(first, [plan(cast(first.units[0], 'water_jet', 1, 0)), plan(cast(first.units[3], 'gale', 0, 0))]);
  assert.deepEqual({ q: second.units[0].q, r: second.units[0].r }, { q: 0, r: 0 }, 'no Guard used; the prepared anchor resists Gale');
  assert.equal(spellCost(actor.championId, 'stoneheart'), 4, 'off-affinity Stoneheart cannot replace this three-Flux combination');
  assert.equal(getSpell('cleansing_tide').friendly?.some(effect => effect.id === 'anchored'), false);
});

test("Mason's Stance creates wall gaps around allies while giving their next-exchange protection", () => {
  const state = duel('treevor_mason'), actor = state.units[0], ally = state.units[1]; Object.assign(ally, { q: 2, r: 0 }); Object.assign(state.units[3], { q: 5, r: 0 });
  const signature = getSignature(actor.championId), result = resolveRound(state, [plan(cast(actor, signature.id, 2, 0)), empty()]);
  assert.equal(getCell(result, 2, 0)!.barrier, undefined, 'occupied gap remains usable');
  assert.equal(result.units[1].statuses.ward?.power, 2); assert.ok(result.units[1].statuses.anchored);
  const walls = spellArea(state, actor.id, signature.id, { q: 2, r: 0 }).filter(cell => cell.q !== 2 || cell.r !== 0);
  assert.equal(walls.length, 2); for (const cell of walls) assert.equal(getCell(result, cell.q, cell.r)!.barrier, 1);
  assert.equal(getSpell('raise_cairn').friendly, undefined, 'ordinary wall leaves occupants unprotected');
});

test('Open-Lane Charge trades damage for moving an enemy beyond an adjacent scoring well', () => {
  const state = duel('ba_djoh'), actor = state.units[0], enemy = state.units[3]; equip(actor, 'fault_line');
  getCell(state, 3, 0)!.well = true; const response = plan(noGuard(enemy));
  const ordinary = resolveRound(state, [plan(cast(actor, 'fault_line', 2, 0)), response]);
  const signature = resolveRound(state, [plan(cast(actor, getSignature(actor.championId).id, 2, 0)), response]);
  assert.equal(ordinary.units[3].q, 3); assert.equal(ordinary.scores[1], 1, 'one-step Fault Line puts this enemy onto another well');
  assert.equal(signature.units[3].q, 4); assert.equal(signature.scores[1], 0, 'two-step signature clears both hexes');
  assert.equal(getSignature(actor.championId).damage, 1); assert.equal(getSpell('fault_line').damage, 2, 'longer displacement has a direct damage tradeoff');
});

test('practice may select a signature without equipping it and does not read the previous Guard as a future order', () => {
  const state = duel('juul_i_yaina'), actor = state.units[0], enemy = state.units[3];
  actor.loadout = ['mend', 'clear_sight', 'aegis', 'tailwind']; actor.statuses.rooted = { turns: 1, power: 1 };
  for (const unit of state.units) if (unit !== actor && unit !== enemy) { unit.hp = 0; unit.respawn = 3; }
  const before = structuredClone(state), choice = chooseAIPlan(state, 0);
  assert.equal(choice.orders[0].spellId, getSignature(actor.championId).id);
  assert.deepEqual(state, before); assert.deepEqual(chooseAIPlan(state, 0), choice);
  enemy.guard = true; assert.deepEqual(chooseAIPlan(state, 0), choice);
  const result = resolveRound(state, [choice, plan(noGuard(enemy))]);
  assert.equal(result.units[3].q, 4, 'signature really displaces two hexes'); assert.ok(result.units[3].statuses.wet);
});

test('practice reaches an objective through seeded ruins and weighted terrain without repeating its approach', () => {
  for (const seed of ['ROUTE0', 'ROUTE7', 'ROUTE18', 'ROUTE29', 'ROUTE33', 'ROUTE47']) for (let slot = 0; slot < 3; slot++) {
    let state = createSimGame(undefined, `frontier:${seed}`); const actorId = state.units[slot].id;
    // Isolate navigation; other units cannot win the match and hide a stuck mage.
    for (const unit of state.units) if (unit.id !== actorId) { unit.hp = 0; unit.respawn = 20; }
    const visited = new Set<string>(); let arrived = false;
    for (let round = 0; round < 6; round++) {
      const actor = state.units.find(unit => unit.id === actorId)!;
      if (getCell(state, actor.q, actor.r)!.well) { arrived = true; break; }
      const coordinate = `${actor.q},${actor.r}`;
      assert.ok(!visited.has(coordinate), `${seed}, slot${slot} repeated ${coordinate} before reaching its well`); visited.add(coordinate);
      state = resolveRound(state, [chooseAIPlan(state, 0), empty()]);
    }
    assert.equal(arrived, true, `${seed}, slot${slot} must reach a well within five moves`);
  }
});

test('all 30 champions play deterministic legal complete practice matches with restorable public states', () => {
  for (let index = 0; index < 5; index++) {
    const rosters: [string[], string[]] = [CHAMPIONS.slice(index * 3, index * 3 + 3).map(champion => champion.id), CHAMPIONS.slice(15 + index * 3, 18 + index * 3).map(champion => champion.id)];
    let state = createSimGame(rosters, `frontier:SQUADS${index}`);
    while (state.winner === null) {
      const plans: [TeamPlan, TeamPlan] = [chooseAIPlan(state, 0), chooseAIPlan(state, 1)];
      if (state.round === 1) assert.deepEqual(chooseAIPlan(state, 0), plans[0]);
      state = resolveRound(state, plans); assert.deepEqual(restoreSimState(state), state);
      assert.ok(state.round <= MAX_ROUNDS);
    }
  }
});
