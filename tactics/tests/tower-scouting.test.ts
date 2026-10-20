import test from 'node:test';
import assert from 'node:assert/strict';
import type {Element} from '../lib/game.ts';
import {getChampion} from '../lib/roster-v13.ts';
import {createTowerRun,towerRoomChoices,chooseTowerRoom,towerBattleConfig,validateTowerStarter,type TowerRoom} from '../lib/tower-v23.ts';
import {towerRoomIntel} from '../lib/tower-scouting.ts';
import {createTowerBattle} from '../lib/tactics-v22.ts';
import {generateArena} from '../lib/arena-v17.ts';
import {towerMotifFromMapId} from '../lib/tower-terrain-v44.ts';

test('combat forks provide different evidence, always name an actual affinity and retain meaningful unknowns',()=>{
 for(const seed of ['SIX23','EMBER','MAP25','PUDDLE'])for(const floor of [1,2,4,5,7,8,9]){
  const run={...createTowerRun(seed),floor},rooms=towerRoomChoices(run).filter(room=>room.enemies.length);
  assert.equal(new Set(rooms.map(room=>towerRoomIntel(room).profile)).size,rooms.length);
  for(const room of rooms){
   const intel=towerRoomIntel(room),known=intel.clues.flatMap(clue=>clue.elements??[]);
   assert.equal(intel.enemyCount,room.enemies.length);
   assert.ok(known.length>=1);
   for(const element of known)assert.ok(room.enemies.some(enemy=>(enemy.affinities[element]??0)>0),`${room.id}: fabricated ${element} cue`);
   assert.ok(intel.unknowns.length>=1);
   assert.ok(intel.reward.includes('defeated foes'));
   assert.equal(intel.risk,floor===9?'Final battle':room.kind==='elite'?'Elite battle':'Battle');
   if(intel.profile==='terrain')assert.equal(intel.environment,room.environment);
   else {assert.equal(intel.environment,undefined);assert.ok(intel.unknowns.includes('Terrain'));}
   if(intel.knownEnemy){
    const actual=room.enemies.find(enemy=>(enemy.creatureId??enemy.championId)===(intel.knownEnemy!.creatureId??intel.knownEnemy!.championId));assert.ok(actual);
    assert.equal(intel.knownEnemy.enemyId,actual.id);assert.equal(intel.knownEnemy.position,room.enemies.indexOf(actual)+1);
    assert.ok(known.includes(getChampion(actual.championId).element));
    if(room.enemies.some(enemy=>!enemy.creatureId))assert.equal(intel.knownEnemy.kind,'champion');
   }
  }
 }
});

test('scouting never serializes full enemy kits, stats or an unrevealed terrain effect',()=>{
 const run=createTowerRun('SAFECLUES');
 for(let floor=1;floor<=9;floor++)for(const room of towerRoomChoices({...run,floor}).filter(room=>room.enemies.length)){
  const intel=towerRoomIntel(room),json=JSON.stringify(intel);
  for(const key of ['loadout','affinities','hp','maxHp','maxFlux','mapId','enemies'])assert.equal(Object.hasOwn(intel,key),false);
  if(intel.knownEnemy)assert.deepEqual(Object.keys(intel.knownEnemy).sort(),['championId','enemyId','kind','name','position',...(intel.knownEnemy.creatureId?['creatureId']:[])].sort());
  for(const enemy of room.enemies)for(const spell of enemy.loadout)assert.ok(!json.includes(`"${spell}"`));
  if(intel.profile!=='terrain')for(const phrase of ['Six central','Flooded centre','Burning centre','Central current','Clear ground'])assert.ok(!json.includes(phrase));
 }
});

test('seeded scouting survives reloads and party edits without changing battles or the source room',()=>{
 const run=createTowerRun('CONSISTENT'),before=JSON.stringify(run),rooms=towerRoomChoices(run),roomBefore=JSON.stringify(rooms);
 for(const room of rooms){
  const first=towerRoomIntel(room);
  assert.deepEqual(towerRoomIntel(JSON.parse(JSON.stringify(room)) as TowerRoom),first);
  first.clues[0].detail='caller edit';first.clues[0].elements?.push('dark');first.unknowns.push('caller edit');
  assert.notDeepEqual(first,towerRoomIntel(room));
  const entered=chooseTowerRoom(run,room.id),battle=towerBattleConfig(entered);
  assert.deepEqual(battle.enemies,room.enemies);assert.equal(battle.environment,room.environment);
 }
 assert.equal(JSON.stringify(run),before);assert.equal(JSON.stringify(rooms),roomBefore);
 const edited={...run,party:run.party.map(actor=>({...actor,displayName:'Another name',hp:1,loadout:[...actor.loadout].reverse()}))};
 assert.deepEqual(towerRoomChoices(edited).map(towerRoomIntel),rooms.map(towerRoomIntel));
});

test('even a single visible creature leaves its battlefield unknown and boss clues stay partial',()=>{
 const start=validateTowerStarter({starterId:'steam',members:[{kind:'creature',creatureId:'creature-fire-cinder'},{kind:'creature',creatureId:'creature-water-puddle'}]});
 const run=createTowerRun('LITTLE',start),room=towerRoomChoices(run)[0],intel=towerRoomIntel(room);
 assert.equal(room.enemies.length,1);assert.equal(intel.profile,'sighting');assert.ok(intel.knownEnemy);assert.ok(intel.unknowns.includes('Terrain'));assert.equal(intel.environment,undefined);
 const boss=towerRoomChoices({...run,floor:9})[0],summit=towerRoomIntel(boss);
 assert.equal(summit.risk,'Final battle');assert.ok(summit.unknowns.includes('Enemy identities and spells'));assert.ok(summit.clues.flatMap(c=>c.elements??[]).length>=1);assert.equal(summit.knownEnemy,undefined);
});

test('safe services reveal unavoidable costs and party rules instead of hiding those stakes',()=>{
 const run=createTowerRun('SERVICES');
 for(const floor of [3,6])for(const room of towerRoomChoices({...run,floor})){
  const intel=towerRoomIntel(room);assert.equal(intel.profile,'service');assert.equal(intel.risk,'No battle');assert.equal(intel.enemyCount,0);
  if(room.kind==='event'){assert.ok(intel.clues.some(c=>c.detail.includes('pays 2 HP')&&c.detail.includes('at least 3 HP')));assert.ok(intel.reward.includes('up to 2 affinity'));}
  if(room.kind==='recruit'){assert.ok(intel.reward.includes('Party limit: 3'));assert.ok(intel.clues.some(c=>c.detail.includes('Starting champions stay')));}
  if(room.kind==='camp')assert.ok(intel.clues.some(c=>c.detail.includes('No health cost')));
 }
});

test('current and legacy field reports match actual starting fields while traces never invent an element',()=>{
 const expected={
  plain:{label:'Clear ground',detail:'No starting elemental field.'},
  flooded:{label:'Flooded centre',detail:'Six central hexes start flooded for 2 exchanges: slower passage; ready for freezing or steam.'},
  embers:{label:'Burning centre',detail:'Six central hexes start burning for 2 exchanges: hazardous footing; ready for an elemental mix.'},
  draft:{label:'Central current',detail:'Six central hexes carry a current for 2 exchanges: extra movement when starting there.'},
 };
 for(const legacy of [false,true]){
  const seen=new Set<string>();
  for(let seed=0;seed<16;seed++){
   const run=createTowerRun(`FIELD${seed}`);if(legacy){delete run.encounterModel;delete run.encounterVariant;}
   for(const room of towerRoomChoices(run)){
    const intel=towerRoomIntel(room);if(intel.profile!=='terrain')continue;
    seen.add(room.environment);assert.equal(intel.environment,room.environment);
    const clue=intel.clues.find(clue=>clue.label===expected[room.environment].label);
    assert.deepEqual(clue,expected[room.environment]);
    if(legacy){assert.equal(towerMotifFromMapId(room.mapId),undefined);assert.deepEqual(intel.clues[0],clue);}
    const battle=createTowerBattle(towerBattleConfig(chooseTowerRoom(run,room.id)));
    const fields=battle.cells.filter(cell=>cell.ttl!==undefined);
    assert.equal(fields.length,room.environment==='plain'?0:6);
    const ingredient=({flooded:'water',embers:'fire',draft:'air'} as const)[room.environment as 'flooded'|'embers'|'draft'];
    for(const cell of fields){assert.equal(cell.ttl,2);assert.deepEqual(cell.elements,[ingredient]);}
    const affinities=new Set<Element>(room.enemies.flatMap(enemy=>Object.keys(enemy.affinities) as Element[]));
    assert.ok(intel.clues.flatMap(c=>c.elements??[]).every(element=>affinities.has(element)));
   }
  }
  assert.deepEqual([...seen].sort(),['draft','embers','flooded','plain']);
 }
});

test('new ground reports distinguish exact physical motif clues from starting elemental fields',()=>{
 const expected={
  crossing:{label:'Split crossing',detail:'Marshy banks slow the water crossing. Dry passages offer quicker routes; the water is ready for ice or steam.'},
  courtyard:{label:'Broken courtyard',detail:'A broken wall interrupts direct shots. Open gates and covered flanks give two ways around it.'},
  grove:{label:'Terraced grove',detail:'Raised ground overlooks a sheltered approach. Forest cover protects a flank but can change when spells land.'},
 },seen=new Set<string>();
 for(let seed=0;seed<16;seed++)for(const room of towerRoomChoices(createTowerRun(`FIELD${seed}`))){
  const intel=towerRoomIntel(room);if(intel.profile!=='terrain')continue;
  const motif=towerMotifFromMapId(room.mapId);assert.ok(motif);seen.add(motif);
  assert.deepEqual(intel.clues[0],expected[motif]);
  const cells=generateArena(room.mapId),at=(q:number,r:number)=>cells.find(cell=>cell.q===q&&cell.r===r)!;
  if(motif==='crossing'){
   assert.equal(at(0,3).biome,'water');assert.equal(at(-1,3).biome,'marsh');assert.equal(at(1,3).biome,'marsh');
   for(const r of [-2,2])assert.equal(at(0,r).biome,'plain');
  }else if(motif==='courtyard'){
   assert.equal(at(0,1).biome,'ruins');
   for(const r of [-2,2]){assert.equal(at(0,r).biome,'plain');assert.equal(at(-1,r).biome,'forest');assert.equal(at(1,r).biome,'forest');}
  }else{
   const flanks=[at(-1,3),at(1,3)];
   assert.ok(flanks.some(cell=>cell.biome==='earth'&&cell.height===1));
   assert.ok(flanks.some(cell=>cell.biome==='forest'));
  }
 }
 assert.deepEqual([...seen].sort(),['courtyard','crossing','grove']);
});
