import assert from 'node:assert/strict';
import test from 'node:test';
import { ARENA_STARTS, ARENA_STREAMS, ARENA_TERRACES, baseTerrainAt } from '../lib/arena.ts';
import { BOARD_RADIUS, BOARD_SIZE, MOVE_RANGE, SPELLS, chooseAIPlan, distance, cellElements, createSimGame, getCell, getSpell, legalCasts, legalMoves, movementBudget, movementCost, movementPath, previewPlan, resolveRound, restoreSimState, spellArea, spellRange, validatePlan } from '../lib/tactics.ts';
import { createSimGame as createV5, restoreSimState as restoreV5, spellArea as areaV5 } from '../lib/tactics-v5.ts';
import type { Point, SimState, SimUnit, TeamPlan } from '../lib/tactics.ts';
const empty: TeamPlan = { orders: [] };
const key = ({q,r}: Point) => `${q || 0},${r || 0}`;
const keys = (points: Point[]) => points.map(key).sort();
const at = (unit: SimUnit, q: number, r: number) => Object.assign(unit, { q, r });
const equip = (unit: SimUnit, spell: string) => { unit.loadout = [spell, ...SPELLS.filter((entry) => entry.id !== spell).slice(0,3).map((entry) => entry.id)]; };
const cast = (unit: SimUnit, spellId: string, q: number, r: number) => ({ unitId: unit.id, spellId, cast: { q,r } });
const rotate = ({q,r}: Point): Point => ({q: -r || 0,r: q+r || 0});
const dirs = [{q:1,r:0},{q:1,r:-1},{q:0,r:-1},{q:-1,r:0},{q:-1,r:1},{q:0,r:1}];
function reachable(state: SimState, start: Point, blocked = new Set<string>()) {
 const seen = new Set([key(start)]); const queue = [start];
 for (let i=0;i<queue.length;i++) for (const dir of dirs) { const next = getCell(state,queue[i].q+dir.q,queue[i].r+dir.r); if (next && !seen.has(key(next)) && !blocked.has(key(next))) {seen.add(key(next));queue.push(next);} }
 return seen;
}

test('v6 doubles the arena to127 connected mirrored cells with three neutral wells and persistent distinct terrain',()=>{
 const state=createSimGame(); assert.equal(state.rulesVersion,6);assert.equal(BOARD_RADIUS,6);assert.equal(BOARD_SIZE,127);assert.equal(MOVE_RANGE,3);assert.equal(state.cells.length,127);
 assert.equal(new Set(keys(state.cells)).size,127);assert.deepEqual(keys(state.cells.filter(c=>c.well)),['0,-4','0,0','0,4']);
 assert.equal(ARENA_TERRACES.length,12);assert.equal(ARENA_STREAMS.length,12);assert.equal(state.cells.filter(c=>c.height).length,12);
 for(const cell of state.cells){const mirror=getCell(state,-cell.q,-cell.r)!;assert.equal(cell.height,mirror.height);assert.equal(cell.terrain,mirror.terrain);assert.equal(cell.well,mirror.well);if(cell.well)assert.equal(cell.terrain,'plain');}
 for(const unit of state.units){assert.equal(getCell(state,unit.q,unit.r)!.height,0);assert.equal(reachable(state,unit).size,127);}
 assert.deepEqual(restoreSimState(state),state);
 const old=createV5();assert.equal(old.rulesVersion,5);assert.equal(old.cells.length,61);assert.deepEqual(restoreV5(old),old);assert.throws(()=>restoreSimState(old));assert.throws(()=>restoreV5(state));
 assert.equal(areaV5(old,old.units[0].id,'tidal_surge',{q:-1,r:0}).length,3);
});

test('terrain and radius mutations cannot be smuggled through v6 save restoration',()=>{
 const state=createSimGame();
 for(const mutate of [(s:SimState)=>{s.cells.pop();},(s:SimState)=>{getCell(s,0,2)!.terrain='plain';},(s:SimState)=>{getCell(s,-2,1)!.height=0;},(s:SimState)=>{getCell(s,0,0)!.well=false;},(s:SimState)=>{getCell(s,0,0)!.terrain='water';}]) {const changed=structuredClone(state);mutate(changed);assert.throws(()=>restoreSimState(changed));}
});

test('deployments require an approach round but can reach a well by the second move without a mandatory choke',()=>{
 const state=createSimGame();
 for(const unit of state.units){ assert.ok(!legalMoves(state,unit.id).some(c=>c.well),'no opening score');let second=false;for(const move of legalMoves(state,unit.id)){const future=structuredClone(state);at(future.units.find(u=>u.id===unit.id)!,move.q,move.r);if(legalMoves(future,unit.id).some(c=>c.well)){second=true;break;}}assert.ok(second,unit.id);}
 // A single legal three-hex cairn can block a route, but cannot sever all routes between the starts and wells.
 const unit=state.units[0]; const starts=ARENA_STARTS.flat();const wells=state.cells.filter(c=>c.well);
 for(const cell of state.cells)for(const dir of dirs){const origin={q:cell.q-dir.q,r:cell.r-dir.r};if(!getCell(state,origin.q,origin.r))continue;const blocked=new Set(spellArea(state,unit.id,'raise_cairn',cell,origin).filter(c=>!c.well&&!starts.some(p=>key(p)===key(c))).map(key));const seen=reachable(state,starts[0],blocked);for(const target of [...starts,...wells])assert.ok(seen.has(key(target)),`isolated ${key(target)} by ${key(cell)}`);}
});

test('movement scale preserves climb effort, Haste, Chilled and Rooted ordering',()=>{
 const state=createSimGame();const unit=at(state.units[0],0,0);
 assert.equal(movementBudget(unit),3);assert.ok(movementPath(state,unit.id,{q:0,r:3}));assert.equal(movementPath(state,unit.id,{q:0,r:4}),null);
 assert.equal(movementCost(getCell(state,-1,1)!,getCell(state,-2,1)!),2);assert.equal(movementCost(getCell(state,-2,1)!,getCell(state,-1,1)!),1);
 unit.statuses.chilled={turns:1,power:1};assert.equal(movementBudget(unit),2);assert.equal(movementPath(state,unit.id,{q:0,r:3}),null);
 unit.statuses.haste={turns:1,power:1};assert.equal(movementBudget(unit),3);delete unit.statuses.chilled;assert.equal(movementBudget(unit),4);unit.statuses.rooted={turns:1,power:1};assert.equal(movementBudget(unit),0);assert.equal(legalMoves(state,unit.id).length,0);
});

test('scaled centre reach respects elevation and Blind while self-casts stay self-only',()=>{
 const state=createSimGame();const unit=at(state.units[0],0,0);equip(unit,'ember');
 assert.equal(getSpell('ember').range,3);assert.equal(getSpell('fire_lance').range,5);assert.equal(getSpell('fault_line').range,4);assert.equal(getSpell('immolate').range,2);
 assert.ok(legalCasts(state,unit.id,undefined,'ember').some(c=>key(c)==='0,3'));assert.ok(!legalCasts(state,unit.id,undefined,'ember').some(c=>key(c)==='0,4'));
 unit.statuses.blind={turns:1,power:1};assert.ok(!legalCasts(state,unit.id,undefined,'ember').some(c=>key(c)==='0,3'));delete unit.statuses.blind;
 at(unit,-2,2);assert.equal(spellRange(unit,getSpell('ember'),getCell(state,-2,2)!,getCell(state,-2,6)!),4);assert.ok(legalCasts(state,unit.id,undefined,'ember').some(c=>key(c)==='-2,6'));
 unit.statuses.blind={turns:1,power:1};assert.equal(spellRange(unit,getSpell('ember'),getCell(state,-2,2)!,getCell(state,-2,6)!),3);
 equip(unit,'slipstream');assert.deepEqual(keys(legalCasts(state,unit.id,undefined,'slipstream')),['-2,2']);
});

test('long lanes retain alternative clear shortest routes and cannot pass a complete barrier',()=>{
 const state=createSimGame();const unit=at(state.units[0],0,0);equip(unit,'fire_lance');
 assert.equal(spellArea(state,unit.id,'fire_lance',{q:0,r:5}).length,5);
 getCell(state,0,2)!.barrier=1;assert.ok(!legalCasts(state,unit.id,undefined,'fire_lance').some(c=>key(c)==='0,5'));assert.deepEqual(spellArea(state,unit.id,'fire_lance',{q:0,r:5}),[]);
 delete getCell(state,0,2)!.barrier;const lane=spellArea(state,unit.id,'fire_lance',{q:1,r:2});assert.ok(lane.length>3,'diagonal lane includes all clear tied shortest paths');assert.ok(!lane.some(c=>key(c)==='0,0'));
});

test('selective large areas have explicit cost and cooldown tradeoffs; rings leave a seven-hex safe interior',()=>{
 const state=createSimGame();const unit=at(state.units[0],0,0);
 for(const id of ['wildfire','rainfall','quake','blight']){const spell=getSpell(id);assert.equal(spellArea(state,unit.id,id,{q:0,r:0}).length,19);assert.equal(spell.cost,5);assert.equal(spell.cooldown,3);}
 for(const id of ['maelstrom','cyclone']){const area=spellArea(state,unit.id,id,{q:0,r:0});assert.equal(area.length,12);assert.ok(!area.some(c=>Math.max(Math.abs(c.q),Math.abs(c.r),Math.abs(c.q+c.r))<2));}
 for(const id of ['inferno','eclipse','sunburst','sanctuary'])assert.equal(spellArea(state,unit.id,id,{q:0,r:0}).length,7);
 assert.ok(spellArea(state,unit.id,'wildfire',{q:6,r:0}).length<19);
});

test('five-hex crescents and three-hex walls rotate exactly in all six directions and clip only at the board edge',()=>{
 const state=createSimGame();const unit=at(state.units[0],0,0);
 for(const [id,initial] of [['tidal_surge',[{q:3,r:0},{q:3,r:-1},{q:3,r:-2},{q:2,r:1},{q:1,r:2}]],['raise_cairn',[{q:3,r:0},{q:3,r:-1},{q:3,r:1}]]] as const){let target:Point={q:3,r:0};let expected:Point[]=initial.map(p=>({...p}));for(let i=0;i<6;i++){assert.deepEqual(keys(spellArea(state,unit.id,id,target)),keys(expected));target=rotate(target);expected=expected.map(rotate);}}
 assert.deepEqual(spellArea(state,unit.id,'tidal_surge',{q:1,r:1}),[]);assert.deepEqual(spellArea(state,unit.id,'tidal_surge',{q:0,r:0}),[]);
 assert.deepEqual(keys(spellArea(state,unit.id,'raise_cairn',{q:6,r:0})),['6,-1','6,0']);
 assert.deepEqual(keys(spellArea(state,unit.id,'tidal_surge',{q:0,r:3},{q:0,r:0})),['-1,3','-2,3','0,3','1,2','2,1']);
});

test('natural streams prime Steam in preview and resolver, then return after finite field lifetime',()=>{
 const state=createSimGame();const unit=at(state.units[0],0,0);equip(unit,'ember');const target=getCell(state,0,2)!;
 assert.deepEqual(cellElements(target),['water']);const plan={orders:[cast(unit,'ember',0,2)]};assert.ok(previewPlan(state,0,plan).some(line=>line.includes('Steam')));
 const hot=resolveRound(state,[plan,empty]);const steam=getCell(hot,0,2)!;assert.equal(steam.terrain,'steam');assert.deepEqual(steam.elements,['fire','water']);assert.equal(steam.ttl,1);assert.deepEqual(restoreSimState(hot),hot);
 const faded=resolveRound(hot,[empty,empty]);const stream=getCell(faded,0,2)!;assert.equal(stream.terrain,'water');assert.equal(stream.ttl,undefined);assert.equal(stream.elements,undefined);assert.deepEqual(restoreSimState(faded),faded);
 const quiet=resolveRound(faded,[empty,empty]);assert.equal(getCell(quiet,0,2)!.terrain,'water');assert.ok(!quiet.lastResolution.some(e=>e.kind==='reaction'));
 const corrupted=structuredClone(hot);getCell(corrupted,0,2)!.elements=['fire'];getCell(corrupted,0,2)!.reactions=[];getCell(corrupted,0,2)!.terrain='fire';assert.throws(()=>restoreSimState(corrupted));
});

test('terraces offer reach but prime Magma, and expired overlays preserve raised Earth',()=>{
 const state=createSimGame();at(state.units[0],-1,0);equip(state.units[0],'ember');at(state.units[3],-2,0);const before=state.units[3].hp;
 const hot=resolveRound(state,[{orders:[cast(state.units[0],'ember',-2,0)]},empty]);assert.equal(getCell(hot,-2,0)!.terrain,'magma');assert.equal(hot.units[3].hp,before-2,'Guard absorbs1 of spell2, Magma adds1');
 const faded=resolveRound(hot,[empty,empty]);assert.equal(getCell(faded,-2,0)!.terrain,'earth');assert.equal(getCell(faded,-2,0)!.height,1);assert.deepEqual(restoreSimState(faded),faded);
});

test('wide fields resolve every preview hex, keep allied collateral, and survive restore',()=>{
 const state=createSimGame();const unit=at(state.units[0],0,0);equip(unit,'wildfire');at(state.units[1],0,2);at(state.units[3],1,1);
 const plan={orders:[cast(unit,'wildfire',0,0)]};assert.ok(previewPlan(state,0,plan).some(s=>s.includes('friendly fire risk')));
 const resolved=resolveRound(state,[plan,empty]);const expected=spellArea(state,unit.id,'wildfire',{q:0,r:0});assert.deepEqual(keys(resolved.cells.filter(c=>c.elements?.includes('fire'))),keys(expected));assert.ok(resolved.units[1].statuses.burn);assert.ok(resolved.units[3].statuses.burn);assert.deepEqual(restoreSimState(resolved),resolved);
});

test('all48 scaled spells legally resolve and strict saves roundtrip',()=>{
 for(const spell of SPELLS){const state=createSimGame();const unit=at(state.units[0],0,0);equip(unit,spell.id);const target=spell.range?{q:0,r:1}:unit;const plan={orders:[cast(unit,spell.id,target.q,target.r)]};validatePlan(state,0,plan);const resolved=resolveRound(state,[plan,empty]);assert.ok(resolved.lastResolution.some(e=>e.kind==='cast'&&e.spellId===spell.id),spell.id);assert.deepEqual(restoreSimState(resolved),resolved,spell.id);}
});

test('one-search movement retains every destination and exact tie path from the prior per-target algorithm',()=>{
 const legacyPath=(state:SimState,unit:SimUnit,target:Point)=>{
  if(key(unit)===key(target))return null;const start=getCell(state,unit.q,unit.r)!;const budget=movementBudget(unit);const queue=[{cell:start,cost:0,path:[] as typeof state.cells}];const costs=new Map([[key(start),0]]);const sign=unit.owner===0?1:-1;
  while(queue.length){queue.sort((a,b)=>a.cost-b.cost||sign*(a.cell.q-b.cell.q||a.cell.r-b.cell.r));const current=queue.shift()!;if(key(current.cell)===key(target))return current.path;for(const dir of dirs){const cell=getCell(state,current.cell.q+dir.q,current.cell.r+dir.r);if(!cell||cell.barrier)continue;const cost=current.cost+movementCost(current.cell,cell);if(cost>budget||cost>=(costs.get(key(cell))??Infinity))continue;costs.set(key(cell),cost);queue.push({cell,cost,path:[...current.path,cell]});}}return null;
 };
 for(const condition of ['normal','haste','chilled','rooted','barriers','quagmire']){const state=createSimGame();at(state.units[0],-1,0);at(state.units[3],1,0);for(const unit of [state.units[0],state.units[3]]){if(['haste','chilled','rooted'].includes(condition))unit.statuses[condition as 'haste'|'chilled'|'rooted']={turns:1,power:1};}
  if(condition==='barriers')for(const p of [{q:0,r:0},{q:0,r:1},{q:0,r:-1}])getCell(state,p.q,p.r)!.barrier=1;
  if(condition==='quagmire')for(const p of [{q:0,r:0},{q:0,r:1}])Object.assign(getCell(state,p.q,p.r)!,{terrain:'quagmire',elements:['water','earth'],reactions:['quagmire'],ttl:1});
  for(const unit of [state.units[0],state.units[3]]){const expected=[];for(const target of state.cells){const path=legacyPath(state,unit,target);assert.deepEqual(movementPath(state,unit.id,target),path,`${condition} ${unit.id} ${key(target)}`);if(path)expected.push(target);}assert.deepEqual(legalMoves(state,unit.id),expected);}
 }
});


test('the practice squad takes three objective approaches instead of converging every mage on the centre',()=>{
 const state=createSimGame();const before=structuredClone(state);const plan=chooseAIPlan(state,0);assert.deepEqual(state,before);assert.deepEqual(plan,chooseAIPlan(state,0));
 const wells=state.cells.filter(cell=>cell.well);const nearest=plan.orders.map(order=>{const unit=state.units.find(candidate=>candidate.id===order.unitId)!;const landing=order.move??unit;return [...wells].sort((a,b)=>distance(a,landing)-distance(b,landing))[0];});
 assert.equal(new Set(keys(nearest)).size,3);
 const mirrored=chooseAIPlan(state,1);assert.deepEqual(plan.orders.map(order=>({champion:order.unitId.slice(2),move:order.move?{q:-order.move.q||0,r:-order.move.r||0}:null,cast:order.cast?{q:-order.cast.q||0,r:-order.cast.r||0}:null,spell:order.spellId,guard:order.guard})),mirrored.orders.map(order=>({champion:order.unitId.slice(2),move:order.move??null,cast:order.cast??null,spell:order.spellId,guard:order.guard})));
});


test('practice bot breaks a revealed centre-well Guard collision loop without seeing sealed enemy orders',()=>{
 const state=createSimGame();const left=state.units[0],right=state.units[3];at(left,-2,0);at(right,2,0);equip(left,'stone');equip(right,'stone');
 for(const unit of state.units.filter(unit=>unit!==left&&unit!==right)){unit.hp=0;unit.respawn=state.round+2;}
 const first=resolveRound(state,[{orders:[{unitId:left.id,move:{q:0,r:0},guard:true}]},{orders:[{unitId:right.id,move:{q:0,r:0},guard:true}]}]);
 assert.equal(first.lastResolution.filter(event=>event.kind==='bounce').length,2);const plans=[chooseAIPlan(first,0),chooseAIPlan(first,1)] as [TeamPlan,TeamPlan];
 for(const plan of plans){assert.ok(plan.orders[0].move);assert.notEqual(key(plan.orders[0].move!),'0,0','do not immediately repeat the known blocked destination');}
 const approached=resolveRound(first,plans);assert.ok(distance(approached.units[0],approached.units[3])<4);assert.ok(!approached.lastResolution.some(event=>event.kind==='bounce'));
 assert.deepEqual(chooseAIPlan(first,0),plans[0],'decision is deterministic from public history');
});
