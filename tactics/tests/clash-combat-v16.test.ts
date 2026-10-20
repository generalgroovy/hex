import test from 'node:test';
import assert from 'node:assert/strict';
import {findProjectileClashes,isTravellingProjectile,interceptionFieldArea,type Projectile} from '../lib/projectile-interception-v16.ts';
import {createSimGame,resolveRound,restoreSimState,getSpell,effectiveSpell,getCell,spellArea,previewPlan,plannedProjectileClashes,castAvailability,chooseAIPlan,validatePlan,type SimState,type TeamPlan} from '../lib/tactics-v16.ts';
import {getSpell as oldSpell} from '../lib/spells-v15.ts';
import type {Element,Point} from '../lib/game.ts';

const empty=():TeamPlan=>({orders:[]});
const board=createSimGame().cells;
const projectile=(unitId:string,from:Point,to:Point,element:Element='fire'):Projectile=>({unitId,from,to,element});
const flat=():SimState=>{const state=createSimGame();state.cells=state.cells.map(({q,r})=>({q,r,well:false,terrain:'plain',height:0,biome:'plain'}));return state;};
const canonical=(state:SimState)=>({...state,units:[...state.units].sort((a,b)=>a.id.localeCompare(b.id))});
function duel(canonicalMap=false):{state:SimState;plans:[TeamPlan,TeamPlan]} {
  const state=canonicalMap?createSimGame():flat(),left=state.units[0],right=state.units[3];
  Object.assign(left,{q:-1,r:0});Object.assign(right,{q:1,r:0});
  return {state,plans:[{orders:[{unitId:left.id,spellId:'ember',cast:{q:1,r:0}}]},{orders:[{unitId:right.id,spellId:'water_jet',cast:{q:-1,r:0}}]}]};
}

test('opposing projectiles meet at the exact midpoint and form one canonical Steam field',()=>{
  const {state,plans}=duel(),before=JSON.stringify(state),next=resolveRound(state,plans);
  const clash=next.lastResolution.find(event=>event.kind==='clash')!;
  assert.deepEqual(clash.participants,['0-oh_tipi','1-oh_tipi']);assert.equal(clash.flightFraction,.5);assert.deepEqual(clash.meeting,{q:0,r:0});assert.equal(clash.radius,1);assert.equal(clash.terrain,'steam');
  assert.equal(next.cells.filter(cell=>cell.terrain==='steam').length,7);
  assert.equal(next.units[0].hp,state.units[0].hp);assert.equal(next.units[3].hp,state.units[3].hp);
  assert.ok(!next.lastResolution.some(event=>event.kind==='damage'||event.kind==='push'));
  assert.equal(next.units[0].flux,Math.min(state.units[0].maxFlux,state.units[0].flux-castAvailability(state,state.units[0].id,'ember').cost+2));
  assert.equal(JSON.stringify(state),before);
  assert.deepEqual(canonical(resolveRound({...state,units:[...state.units].reverse()},plans)),canonical(next));
});

test('crossing the same location at different flight fractions does not intercept',()=>{
  const a=projectile('a',{q:-2,r:0},{q:2,r:0}),b=projectile('b',{q:0,r:-1},{q:0,r:3},'water');
  assert.deepEqual(findProjectileClashes([a,b],board),[]);
  const simultaneous={...b,from:{q:0,r:-2},to:{q:0,r:2}};
  assert.equal(findProjectileClashes([a,simultaneous],board)[0].flightFraction,.5);
});

test('shared endpoints remain ordinary impacts; self casts and supportive casts do not intercept',()=>{
  assert.deepEqual(findProjectileClashes([projectile('a',{q:-2,r:0},{q:0,r:0}),projectile('b',{q:0,r:-2},{q:0,r:0})],board),[]);
  assert.equal(isTravellingProjectile(getSpell('cleansing_tide'),{q:-1,r:0},{q:1,r:0}),false);
  assert.equal(isTravellingProjectile(getSpell('raise_cairn'),{q:-1,r:0},{q:1,r:0}),false);
  assert.equal(isTravellingProjectile(getSpell('radiant_bolt'),{q:-1,r:0},{q:1,r:0},true),false);
  assert.equal(isTravellingProjectile(getSpell('radiant_bolt'),{q:-1,r:0},{q:1,r:0}),true);
  assert.equal(isTravellingProjectile(getSpell('ember'),{q:0,r:0},{q:0,r:0}),false);
});

test('fractional axial meetings choose one stable nearest hex without moving the flight point',()=>{
  const casts=[projectile('a',{q:0,r:0},{q:3,r:0}),projectile('b',{q:1,r:0},{q:0,r:0},'water')];
  const [clash]=findProjectileClashes(casts,board);
  assert.equal(clash.flightFraction,.25);assert.deepEqual(clash.meeting,{q:.75,r:0});assert.equal(clash.q,1);assert.equal(clash.r,0);
  assert.deepEqual(findProjectileClashes([...casts].reverse(),[...board].reverse()),[clash]);
});

test('earliest meeting consumes a projectile so a later crossing cannot reuse it',()=>{
  const casts=[projectile('a',{q:0,r:0},{q:4,r:0}),projectile('b',{q:2,r:0},{q:-2,r:0},'water'),projectile('c',{q:3,r:-3},{q:3,r:1},'earth')];
  const clashes=findProjectileClashes(casts,board);
  assert.equal(clashes.length,1);assert.deepEqual(clashes[0].participants,['a','b']);assert.equal(clashes[0].flightFraction,.25);
});

test('three and six simultaneous arrivals form one complete neutral mixture, independent of input ordering',()=>{
  const casts=[projectile('a',{q:-2,r:0},{q:2,r:0}),projectile('b',{q:2,r:0},{q:-2,r:0},'water'),projectile('c',{q:0,r:-2},{q:0,r:2},'earth'),projectile('d',{q:0,r:2},{q:0,r:-2},'air'),projectile('e',{q:-2,r:2},{q:2,r:-2},'light'),projectile('f',{q:2,r:-2},{q:-2,r:2},'dark')];
  for(const count of [3,6]){
    const selected=casts.slice(0,count),clashes=findProjectileClashes(selected,board);
    assert.equal(clashes.length,1);assert.equal(clashes[0].radius,2);assert.equal(clashes[0].participants.length,count);assert.equal(clashes[0].elements.length,count);assert.equal(interceptionFieldArea(board,clashes[0]).length,19);
    assert.deepEqual(findProjectileClashes([...selected].reverse(),board),clashes);
    assert.deepEqual(findProjectileClashes([...selected.slice(1),selected[0]],board),clashes);
  }
});

test('three real casts replace all direct effects with their full Hot Spring recipe',()=>{
  const state=flat(),left=state.units[0],right=state.units[3],earth=state.units[2];
  Object.assign(left,{q:-2,r:0});Object.assign(right,{q:2,r:0});Object.assign(earth,{q:0,r:-2});
  const result=resolveRound(state,[{orders:[{unitId:left.id,spellId:'ember',cast:{q:2,r:0}},{unitId:earth.id,spellId:'stone',cast:{q:0,r:2}}]},{orders:[{unitId:right.id,spellId:'water_jet',cast:{q:-2,r:0}}]}]);
  assert.equal(result.lastResolution.filter(event=>event.kind==='clash').length,1);
  assert.equal(result.cells.filter(cell=>cell.terrain==='hot_spring').length,19);
  assert.ok(!result.lastResolution.some(event=>event.kind==='damage'));
});

test('same-element collision forms the elemental field and never doubles direct damage',()=>{
  const {state,plans}=duel();plans[1].orders[0].spellId='ember';
  const result=resolveRound(state,plans),clash=result.lastResolution.find(event=>event.kind==='clash')!;
  assert.deepEqual(clash.elements,['fire']);assert.equal(clash.terrain,'fire');
  assert.equal(result.units[0].hp,state.units[0].hp-1);assert.equal(result.units[3].hp,state.units[3].hp-1);
  assert.ok(result.lastResolution.filter(event=>event.kind==='damage').every(event=>event.amount===1));
});

test('colliding Ice retains its frozen footprint and natural substrate joins the complete mixture',()=>{
  const frozen=duel();frozen.state.units[0].loadout=['frostbite','water_jet','undertow','cleansing_tide'];frozen.plans[0].orders[0].spellId='frostbite';
  const ice=resolveRound(frozen.state,frozen.plans);
  assert.equal(ice.cells.filter(cell=>cell.ice).length,7);assert.ok(ice.cells.filter(cell=>cell.ice).every(cell=>cell.terrain==='water'));
  assert.equal(ice.units[3].statuses.chilled,undefined,'intercepted Frostbite does not apply its direct Chilled');
  const grounded=duel();getCell(grounded.state,0,0)!.terrain='earth';
  const result=resolveRound(grounded.state,grounded.plans);
  assert.equal(getCell(result,0,0)?.terrain,'hot_spring');assert.equal(getCell(result,1,0)?.terrain,'steam');
});

test('projectiles release from actual post-movement positions, independently of order arrays',()=>{
  const state=flat(),left=state.units[0],right=state.units[3];Object.assign(left,{q:-3,r:0});Object.assign(right,{q:3,r:0});
  const plans:[TeamPlan,TeamPlan]=[{orders:[{unitId:left.id,move:{q:-1,r:0},spellId:'ember',cast:{q:1,r:0}}]},{orders:[{unitId:right.id,move:{q:1,r:0},spellId:'water_jet',cast:{q:-1,r:0}}]}];
  const result=resolveRound(state,plans),clash=result.lastResolution.find(event=>event.kind==='clash')!;
  assert.deepEqual(clash.meeting,{q:0,r:0});assert.equal(clash.flightFraction,.5);
  assert.deepEqual(result.lastResolution.find(event=>event.kind==='cast'&&event.unitId===left.id)?.from,{q:-1,r:0});
  assert.ok(result.lastResolution.findIndex(event=>event.kind==='move')<result.lastResolution.findIndex(event=>event.kind==='cast'));
});

test('a consumed line spell leaves no damage or field along its original ray',()=>{
  const state=flat(),wind=state.units[1],fire=state.units[3];Object.assign(wind,{q:-2,r:0,affinities:{air:3,fire:2},loadout:['wind_shear','gust','tailwind','ember']});Object.assign(fire,{q:2,r:0});
  const result=resolveRound(state,[{orders:[{unitId:wind.id,spellId:'wind_shear',cast:{q:2,r:0}}]},{orders:[{unitId:fire.id,spellId:'ember',cast:{q:-2,r:0}}]}]);
  assert.ok(result.lastResolution.some(event=>event.kind==='clash'));
  assert.equal(result.units[3].hp,fire.hp);assert.equal(getCell(result,2,0)?.terrain,'plain');assert.equal(getCell(result,-2,0)?.terrain,'plain');
  assert.equal(getCell(result,0,0)?.terrain,'arcstorm');
});

test('intercepted casts retain their Flux cost, cooldown and self-inflicted consequences',()=>{
  const state=flat(),left=state.units[1],right=state.units[3];Object.assign(left,{q:-1,r:0});Object.assign(right,{q:1,r:0});
  const result=resolveRound(state,[{orders:[{unitId:left.id,spellId:'immolate',cast:{q:1,r:0}}]},{orders:[{unitId:right.id,spellId:'water_jet',cast:{q:-1,r:0}}]}]);
  const after=result.units.find(unit=>unit.id===left.id)!;
  assert.equal(after.hp,left.hp-1);assert.equal(after.cooldowns.immolate,getSpell('immolate').cooldown);
  assert.equal(after.flux,left.flux-castAvailability(state,left.id,'immolate').cost+2);
  assert.equal(result.units[3].hp,right.hp);
});

test('a crossed healing spell still reaches its ally and cannot cancel an attack',()=>{
  const state=flat(),water=state.units[0],ally=state.units[1],foe=state.units[3];Object.assign(water,{q:-2,r:0});Object.assign(ally,{q:2,r:0,hp:3});Object.assign(foe,{q:0,r:-2});
  const result=resolveRound(state,[{orders:[{unitId:water.id,spellId:'cleansing_tide',cast:{q:2,r:0}}]},{orders:[{unitId:foe.id,spellId:'ember',cast:{q:0,r:2}}]}]);
  assert.ok(!result.lastResolution.some(event=>event.kind==='clash'));assert.ok(result.units[1].hp>ally.hp);
  assert.equal(getCell(result,0,2)?.terrain,'fire');
});

test('own-plan forecast warns about friendly interception and does not promise the lost target damage',()=>{
  const state=flat(),water=state.units[0],fire=state.units[1];Object.assign(water,{q:-2,r:0});Object.assign(fire,{q:2,r:0});
  const plan:TeamPlan={orders:[{unitId:water.id,spellId:'water_jet',cast:{q:2,r:0}},{unitId:fire.id,spellId:'ember',cast:{q:-2,r:0}}]};
  assert.equal(plannedProjectileClashes(state,plan).length,1);
  const lines=previewPlan(state,0,plan);assert.ok(lines.some(line=>line.includes('In-flight meeting')&&line.includes('Steam')));
  assert.ok(!lines.some(line=>line.includes('friendly fire risk')));
});

test('larger footprints keep damage/cost stable and preserve precision, ring holes and wall shape',()=>{
  const state=flat(),unit=state.units[0];unit.affinities={water:6,fire:6,earth:6};Object.assign(unit,{q:0,r:0});
  for(const id of ['wildfire','inferno','rainfall','quake','blight','sunburst','sanctuary','tidal_surge','maelstrom','raise_cairn','frostbite','cleansing_tide','thunderclap']){assert.equal(getSpell(id).damage,oldSpell(id).damage);assert.equal(getSpell(id).cost,oldSpell(id).cost);}
  assert.equal(spellArea(state,unit.id,'wildfire',{q:1,r:0}).length,37);
  assert.equal(spellArea(state,unit.id,'inferno',{q:1,r:0}).length,19);
  assert.equal(spellArea(state,unit.id,'cleansing_tide',{q:1,r:0}).length,7);
  assert.equal(spellArea(state,unit.id,'tidal_surge',{q:1,r:0}).length,7);
  assert.equal(spellArea(state,unit.id,'raise_cairn',{q:1,r:0}).length,5);
  assert.equal(spellArea(state,unit.id,'maelstrom',{q:1,r:0}).length,18);
  assert.ok(!spellArea(state,unit.id,'maelstrom',{q:1,r:0}).some(cell=>cell.q===1&&cell.r===0));
  assert.equal(spellArea(state,unit.id,'ember',{q:1,r:0}).length,1);
  assert.match(getSpell('wildfire').description,/37-hex burst/);assert.match(effectiveSpell(unit.championId,'maelstrom',unit.affinities).description,/18-hex ring/);
  assert.match(getSpell('raise_cairn').description,/5-hex barrier/);assert.doesNotMatch(getSpell('raise_cairn').description,/3-hex/);
});

test('authoritative clashes round-trip through saved state and forged replay geometry is rejected',()=>{
  const {state,plans}=duel(true);restoreSimState(state);const result=resolveRound(state,plans);
  assert.deepEqual(restoreSimState(result),result);
  for(const mutate of [
    (state:SimState)=>{state.lastResolution.find(event=>event.kind==='clash')!.flightFraction=.7;},
    (state:SimState)=>{state.lastResolution.find(event=>event.kind==='clash')!.meeting={q:1,r:0};},
    (state:SimState)=>{state.lastResolution.find(event=>event.kind==='clash')!.participants=['0-oh_tipi','0-wa_bidi'];},
    (state:SimState)=>{state.lastResolution.find(event=>event.kind==='clash')!.radius=2;},
    (state:SimState)=>{state.lastResolution.find(event=>event.kind==='clash')!.elements=['fire'];},
    (state:SimState)=>{state.lastResolution=state.lastResolution.filter(event=>event.kind!=='clash');},
    (state:SimState)=>{state.lastResolution.push({...state.lastResolution.find(event=>event.kind==='clash')!});},
  ]){const forged=structuredClone(result);mutate(forged);assert.throws(()=>restoreSimState(forged));}
});

test('current combat AI supplies legal non-intercepting allied drafts',()=>{
  const state=createSimGame();const plan=chooseAIPlan(state,0);validatePlan(state,0,plan);assert.deepEqual(plannedProjectileClashes(state,plan),[]);
});
