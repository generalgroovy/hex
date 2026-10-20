import test from 'node:test';
import assert from 'node:assert/strict';
import {CHAMPIONS} from '../lib/roster-v13.ts';
import {canonicalBuild} from '../lib/character-creation-v17.ts';
import {getSignature} from '../lib/spells-v16.ts';
import {readCampaignProfile,validateCampaignProfile,updateCampaignHero,updateCampaignCompanions,campaignAffinityBudget,campaignAffinityRankCap,learnedCampaignSignatures,availableCampaignCreatures,campaignEncounters,createCampaignGame,awardCampaignVictory,type CampaignProfile} from '../lib/story-v19.ts';
import {createSimGame,resolveRound,restoreSimState,availableUnitSpellIds,castAvailability,legalCasts,validatePlan,type SimState,type TeamPlan} from '../lib/tactics-v19.ts';
const empty=():TeamPlan=>({orders:[]});
const kill=(unit:SimState['units'][number])=>{unit.hp=0;unit.flux=0;unit.statuses={};unit.cooldowns={};delete unit.guard;};
const flat=(state:SimState)=>{state.cells=state.cells.map(({q,r,well})=>({q,r,well,terrain:'plain',height:0,biome:'plain'}));return state;};
function bondFixture(){
 const profile=readCampaignProfile(null),state=flat(createCampaignGame(profile,'oh_tipi')),hero=state.units.find(unit=>unit.kind==='hero')!,water=state.units.find(unit=>unit.owner===0&&unit.creatureId==='creature-water-puddle')!,fire=state.units.find(unit=>unit.owner===0&&unit.creatureId==='creature-fire-cinder')!;
 Object.assign(hero,{q:0,r:0,hp:5,flux:1});Object.assign(water,{q:1,r:0});Object.assign(fire,{q:0,r:1});state.cells.find(cell=>cell.q===0&&cell.r===0)!.well=false;return {state,hero,water,fire};
}

test('creation and earned advancement retain one signature identity and four legal configured spells',()=>{
 let profile=readCampaignProfile(null);assert.equal(campaignAffinityBudget(profile),5);
 assert.throws(()=>updateCampaignHero(profile,{...profile.hero,affinities:{water:4,fire:1}}));
 assert.throws(()=>updateCampaignHero(profile,{...profile.hero,affinities:{water:2,fire:3}}));
 assert.throws(()=>updateCampaignHero(profile,{...profile.hero,affinities:{water:2,fire:1,earth:1,air:1}}));
 profile=validateCampaignProfile({...profile,defeated:CHAMPIONS.slice(0,3).map(hero=>hero.id)});
 const advanced=updateCampaignHero(profile,{...profile.hero,name:'River',affinities:{water:6,fire:2},loadout:['maelstrom','deep_freeze','ember','cleansing_tide']});
 assert.equal(campaignAffinityBudget(advanced),8);assert.equal(advanced.hero.loadout.length,4);assert.equal(learnedCampaignSignatures(advanced).length,3);
 const game=createCampaignGame(advanced,CHAMPIONS[3].id),hero=game.units.find(unit=>unit.kind==='hero')!;assert.deepEqual(hero.affinities,{water:6,fire:2});assert.ok(availableUnitSpellIds(game,hero.id).includes(getSignature(hero.championId).id));assert.deepEqual(restoreSimState(game),game);
});

test('earned affinity unlocks one new rank per victory without a first-victory respec shortcut',()=>{
 const start=readCampaignProfile(null);assert.equal(campaignAffinityRankCap(start),3);
 const first=validateCampaignProfile({...start,defeated:['oh_tipi']});assert.equal(campaignAffinityRankCap(first),4);
 assert.throws(()=>updateCampaignHero(first,{...first.hero,affinities:{water:6},loadout:['water_jet','tidal_surge','maelstrom','cleansing_tide']}),/rank 4/);
 const normal=updateCampaignHero(first,{...first.hero,affinities:{water:4,fire:1,air:1}});assert.equal(normal.hero.affinities.water,4);
 const second=validateCampaignProfile({...start,defeated:['oh_tipi','s_wayne']});assert.equal(campaignAffinityRankCap(second),5);
 assert.throws(()=>updateCampaignHero(second,{...second.hero,affinities:{water:6,fire:1},loadout:['water_jet','tidal_surge','maelstrom','cleansing_tide']}),/rank 5/);
 assert.equal(campaignAffinityRankCap({defeated:CHAMPIONS.slice(0,3).map(hero=>hero.id)}),6);
 assert.equal(campaignAffinityRankCap({defeated:CHAMPIONS.map(hero=>hero.id)}),6);
});

test('migration preserves noncontiguous victories and repairs damaged newer fields independently',()=>{
 const legacy={format:2,defeated:['oh_tipi','haara'],affinities:{oh_tipi:{water:4,fire:2}}};
 const migrated=readCampaignProfile(null,JSON.stringify(legacy));assert.equal(campaignAffinityBudget(migrated),7);assert.deepEqual(migrated.hero.affinities,{water:4,fire:2});assert.ok(learnedCampaignSignatures(migrated).includes(getSignature('haara').id));
 assert.equal(campaignEncounters(migrated).find(entry=>entry.available&&!entry.completed)?.id,'s_wayne');
 const damaged={...migrated,hero:{...migrated.hero,name:'Reed',affinities:{water:99}},companions:['not-a-creature','creature-fire-cinder']};
 const repaired=readCampaignProfile(JSON.stringify(damaged));assert.deepEqual(repaired.defeated,migrated.defeated);assert.equal(repaired.hero.name,'Reed');assert.equal(repaired.hero.championId,'oh_tipi');assert.ok(repaired.companions.includes('creature-fire-cinder'));assert.deepEqual(validateCampaignProfile(repaired),repaired);
});

test('earlier over-ranked profiles retain victories, identity and earned budget during repair',()=>{
 const current=validateCampaignProfile({...readCampaignProfile(null),defeated:['oh_tipi']});
 const old={...current,hero:{...current.hero,name:'River',affinities:{water:6},loadout:['water_jet','maelstrom','tidal_surge','cleansing_tide']}};
 const original=structuredClone(old),repaired=readCampaignProfile(JSON.stringify(old));
 assert.deepEqual(old,original);assert.deepEqual(repaired.defeated,['oh_tipi']);assert.equal(repaired.hero.name,'River');assert.equal(repaired.hero.championId,'oh_tipi');assert.equal(campaignAffinityBudget(repaired),6);assert.ok(Object.values(repaired.hero.affinities).every(rank=>(rank??0)<=4));assert.deepEqual(validateCampaignProfile(repaired),repaired);
 const legacy={format:2,defeated:['oh_tipi'],affinities:{oh_tipi:{water:6,fire:2}}};const migrated=readCampaignProfile(null,JSON.stringify(legacy));assert.deepEqual(migrated.defeated,['oh_tipi']);assert.equal(campaignAffinityBudget(migrated),6);assert.deepEqual(validateCampaignProfile(migrated),migrated);
});

test('recruit classes and mixed lineages unlock from victories without allowing duplicate companions',()=>{
 const start=readCampaignProfile(null);assert.ok(availableCampaignCreatures(start).every(creature=>creature.strengthClass==='lesser'&&creature.elements.length===1));assert.throws(()=>updateCampaignCompanions(start,[start.companions[0],start.companions[0]]));
 const stage=validateCampaignProfile({...start,defeated:CHAMPIONS.slice(0,10).map(hero=>hero.id)});assert.ok(availableCampaignCreatures(stage).some(creature=>creature.strengthClass==='greater'));assert.ok(availableCampaignCreatures(stage).some(creature=>creature.elements.length===3));assert.ok(availableCampaignCreatures(stage).every(creature=>creature.elements.length<=3));
});

test('direct engine creation and restore enforce ordered travel, including forged otherwise valid battles',()=>{
 const profile=readCampaignProfile(null);assert.throws(()=>createSimGame({profile,encounterId:'s_wayne'}));
 const advanced=validateCampaignProfile({...profile,defeated:['oh_tipi']}),state=createCampaignGame(advanced,'s_wayne');
 state.campaign.profile=profile;state.learnedSignatures=[[],[]];assert.throws(()=>restoreSimState(state),/not unlocked/);
});

test('nearby living bond partners heal and recharge once; distance, death and enemy ownership stop it',()=>{
 const fixture=bondFixture(),near=resolveRound(fixture.state,[empty(),empty()]);assert.equal(near.units.find(unit=>unit.id===fixture.hero.id)!.hp,6);assert.equal(near.units.find(unit=>unit.id===fixture.hero.id)!.flux,5);
 const distant=bondFixture();Object.assign(distant.fire,{q:0,r:3});const apart=resolveRound(distant.state,[empty(),empty()]);assert.equal(apart.units.find(unit=>unit.id===distant.hero.id)!.hp,5);assert.equal(apart.units.find(unit=>unit.id===distant.hero.id)!.flux,4);
 const dead=bondFixture();kill(dead.fire);const without=resolveRound(dead.state,[empty(),empty()]);assert.equal(without.units.find(unit=>unit.id===dead.hero.id)!.hp,5);assert.equal(without.units.find(unit=>unit.id===dead.fire.id)!.hp,0);
 const enemyProfile=validateCampaignProfile({...readCampaignProfile(null),defeated:['oh_tipi','s_wayne'],companions:['creature-water-puddle','creature-earth-pebble']});
 const hostile=flat(createCampaignGame(enemyProfile,'red_baron')),hero=hostile.units.find(unit=>unit.kind==='hero')!;Object.assign(hero,{q:0,r:0,hp:5});Object.assign(hostile.units.find(unit=>unit.creatureId==='creature-water-puddle')!,{q:1,r:0});Object.assign(hostile.units.find(unit=>unit.owner===0&&unit.creatureId==='creature-earth-pebble')!,{q:-1,r:0});Object.assign(hostile.units.find(unit=>unit.owner===1&&unit.kind==='creature')!,{q:0,r:1});
 const result=resolveRound(hostile,[empty(),empty()]);assert.equal(result.units.find(unit=>unit.id===hero.id)!.hp,5);
});

test('a companion killed during the exchange grants no after-exchange heal and cannot revive',()=>{
 const {state,hero,fire}=bondFixture();fire.hp=1;const attacker=state.units.find(unit=>unit.owner===1&&unit.kind==='champion')!;Object.assign(attacker,{q:2,r:1});
 const next=resolveRound(state,[empty(),{orders:[{unitId:attacker.id,spellId:'water_jet',cast:{q:fire.q,r:fire.r}}]}]);
 assert.equal(next.units.find(unit=>unit.id===fire.id)!.hp,0);assert.equal(next.units.find(unit=>unit.id===hero.id)!.hp,5);assert.equal(next.lastResolution.filter(event=>event.kind==='defeat'&&event.unitId===fire.id).length,1);
});

test('bond range follows final movement positions and support statuses last exactly the next exchange',()=>{
 const leaving=bondFixture(),left=resolveRound(leaving.state,[{orders:[{unitId:leaving.fire.id,move:{q:0,r:4}}]},empty()]);
 assert.equal(left.units.find(unit=>unit.id===leaving.hero.id)!.hp,5);
 const arriving=bondFixture();Object.assign(arriving.fire,{q:0,r:4});const joined=resolveRound(arriving.state,[{orders:[{unitId:arriving.fire.id,move:{q:0,r:1}}]},empty()]);
 assert.equal(joined.units.find(unit=>unit.id===arriving.hero.id)!.hp,6);
 for(const [companions,status] of [
  [['creature-fire-wicktail','creature-earth-pebble'],'ward'],
  [['creature-water-brookling','creature-air-pip'],'haste'],
  [['creature-light-wick','creature-dark-duskmote'],'clarity'],
 ] as const){
  const profile=updateCampaignCompanions(readCampaignProfile(null),companions),state=flat(createCampaignGame(profile,'oh_tipi'));
  const hero=state.units.find(unit=>unit.kind==='hero')!,sources=state.units.filter(unit=>unit.owner===0&&unit.kind==='creature');Object.assign(hero,{q:0,r:0});Object.assign(sources[0],{q:1,r:0});Object.assign(sources[1],{q:0,r:1});
  const next=resolveRound(state,[empty(),empty()]);assert.deepEqual(next.units.find(unit=>unit.id===hero.id)!.statuses[status],{turns:1,power:1});
  Object.assign(next.units.find(unit=>unit.id===sources[1].id)!,{q:0,r:4});const expired=resolveRound(next,[empty(),empty()]);assert.equal(expired.units.find(unit=>unit.id===hero.id)!.statuses[status],undefined);
 }
});

test('Wither taxes aggregate spell and bond healing once, while bond alone remains countered',()=>{
 const profile=updateCampaignHero(readCampaignProfile(null),canonicalBuild('haara'));
 const make=()=>{const state=flat(createCampaignGame(profile,'oh_tipi')),hero=state.units.find(unit=>unit.kind==='hero')!,sources=state.units.filter(unit=>unit.owner===0&&unit.kind==='creature');Object.assign(hero,{q:0,r:0,hp:2,statuses:{wither:{turns:1,power:1}}});Object.assign(sources[0],{q:1,r:0});Object.assign(sources[1],{q:0,r:1});return {state,hero};};
 const {state,hero}=make(),healed=resolveRound(state,[{orders:[{unitId:hero.id,spellId:'mend',cast:{q:0,r:0}}]},empty()]);
 assert.equal(healed.units.find(unit=>unit.id===hero.id)!.hp,6,'2 health + 4 Mend + 1 bond - 1 Wither');
 assert.equal(healed.lastResolution.filter(event=>event.kind==='heal'&&event.unitId===hero.id).reduce((sum,event)=>sum+(event.amount??0),0),4);
 const alone=make(),blocked=resolveRound(alone.state,[empty(),empty()]);assert.equal(blocked.units.find(unit=>unit.id===alone.hero.id)!.hp,2);
 const stronger=make();stronger.hero.statuses.wither!.power=2;const reduced=resolveRound(stronger.state,[{orders:[{unitId:stronger.hero.id,spellId:'mend',cast:{q:0,r:0}}]},empty()]);assert.equal(reduced.units.find(unit=>unit.id===stronger.hero.id)!.hp,5);
});

test('defeating the champion alone does not win; every living minion counts and first victory awards once',()=>{
 const profile=readCampaignProfile(null),state=createCampaignGame(profile,'oh_tipi');state.units.filter(unit=>unit.owner===1&&unit.kind==='champion').forEach(kill);
 const ongoing=resolveRound(state,[empty(),empty()]);assert.equal(ongoing.winner,null);assert.equal(ongoing.units.filter(unit=>unit.owner===1&&unit.hp>0).length,2);
 ongoing.units.filter(unit=>unit.owner===1).forEach(kill);const result=resolveRound(ongoing,[empty(),empty()]);assert.equal(result.winner,0);assert.deepEqual(restoreSimState(result),result);
 const awarded=awardCampaignVictory(profile,'oh_tipi',result);assert.equal(campaignAffinityBudget(awarded),6);assert.deepEqual(awarded.defeated,['oh_tipi']);assert.deepEqual(awardCampaignVictory(awarded,'oh_tipi',result),awarded);
 assert.deepEqual(awardCampaignVictory(profile,'s_wayne',result),profile);
});
