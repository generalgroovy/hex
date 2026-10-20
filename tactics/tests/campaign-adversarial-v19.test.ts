import test from 'node:test';
import assert from 'node:assert/strict';
import {CAMPAIGN_ENCOUNTERS,readCampaignProfile,validateCampaignProfile,campaignAffinityBudget,availableCampaignCreatures,createCampaignGame,restoreCampaignGame,awardCampaignVictory,campaignEncounters} from '../lib/story-v19.ts';
import {getSignature,defaultLoadout} from '../lib/spells-v16.ts';
import {allocateAffinityBudget} from '../lib/roster-v13.ts';
import {availableUnitSpellIds,legalCasts,resolveRound,validatePlan} from '../lib/tactics-v19.ts';
import {restoreSimState as restoreOnline} from '../lib/tactics-v18.ts';

function profileAt(index:number){
 const initial=readCampaignProfile(null),defeated=CAMPAIGN_ENCOUNTERS.slice(0,index).map(encounter=>encounter.id);
 const budget=campaignAffinityBudget({defeated}),affinities=allocateAffinityBudget(initial.hero.championId,budget);
 const pool=availableCampaignCreatures({defeated});
 const ranked=[...pool].sort((a,b)=>b.maxHp-a.maxHp||a.id.localeCompare(b.id));
 return validateCampaignProfile({...initial,defeated,hero:{...initial.hero,affinities,loadout:defaultLoadout(initial.hero.championId,affinities)},companions:ranked.slice(0,2).map(creature=>creature.id)});
}

test('all thirty encounter boundaries construct six real actors with the promised enemy composition',()=>{
 for(const encounter of CAMPAIGN_ENCOUNTERS){
  const profile=profileAt(encounter.index),state=createCampaignGame(profile,encounter.id);
  assert.equal(state.units.length,6);assert.equal(state.units.filter(unit=>unit.owner===0&&unit.kind==='hero').length,1);
  assert.equal(state.units.filter(unit=>unit.owner===0&&unit.kind==='creature').length,2);
  assert.equal(state.units.filter(unit=>unit.owner===1&&unit.kind==='champion').length,Math.floor(encounter.index/10)+1);
  assert.deepEqual(restoreCampaignGame(state),state);
  assert.equal(new Set(state.units.map(unit=>`${unit.q},${unit.r}`)).size,6);
  assert.throws(()=>restoreOnline(state),'Campaign state cannot replace a multiplayer save');
 }
});

test('creature proxy identities cannot grant an unequipped champion signature',()=>{
 const state=createCampaignGame(profileAt(10),CAMPAIGN_ENCOUNTERS[10].id);
 for(const unit of state.units.filter(unit=>unit.kind==='creature')){
  const signature=getSignature(unit.championId).id;
  assert.ok(!availableUnitSpellIds(state,unit.id).includes(signature));
  assert.deepEqual(legalCasts(state,unit.id,undefined,signature),[]);
  assert.throws(()=>validatePlan(state,unit.owner,{orders:[{unitId:unit.id,spellId:signature,cast:{q:unit.q,r:unit.r}}]}));
 }
});

test('locked travel and forged creature stats, identity, spells and campaign provenance are rejected',()=>{
 const profile=profileAt(0),state=createCampaignGame(profile,CAMPAIGN_ENCOUNTERS[0].id);
 assert.throws(()=>createCampaignGame(profile,CAMPAIGN_ENCOUNTERS[1].id));
 for(const mutate of [
  (copy:any)=>{copy.units[1].maxHp=8;copy.units[1].hp=8;},
  (copy:any)=>{copy.units[1].kind='champion';delete copy.units[1].creatureId;},
  (copy:any)=>{copy.units[1].loadout.push(getSignature(copy.units[1].championId).id);},
  (copy:any)=>{copy.campaign.encounterId=CAMPAIGN_ENCOUNTERS[1].id;},
 ]){const copy=structuredClone(state);mutate(copy);assert.throws(()=>restoreCampaignGame(copy));}
 assert.deepEqual(awardCampaignVictory(profile,CAMPAIGN_ENCOUNTERS[0].id,{...state,winner:0}),profile);
});

test('stalling resolves through actual defeats, never a round-limit draw with survivors',()=>{
 for(const index of [0,9,10,19,20,29]){
  let state=createCampaignGame(profileAt(index),CAMPAIGN_ENCOUNTERS[index].id),rounds=0;
  while(state.winner===null&&rounds<26){
   const original=structuredClone(state),next=resolveRound(state,[{orders:[]},{orders:[]}]);
   assert.deepEqual(state,original);assert.deepEqual(restoreCampaignGame(next),next);state=next;rounds++;
  }
  assert.notEqual(state.winner,null);assert.ok(rounds<=18);
  if(state.winner==='draw')assert.equal(state.units.filter(unit=>unit.hp>0).length,0);
 }
});

test('a migrated noncontiguous victory cannot unlock intervening encounters',()=>{
 const won=CAMPAIGN_ENCOUNTERS[20].id,legacy={format:2,defeated:[won],affinities:{}};
 const profile=readCampaignProfile(null,legacy),entries=campaignEncounters(profile);
 assert.deepEqual(profile.defeated,[won]);assert.equal(campaignAffinityBudget(profile),6);
 assert.deepEqual(entries.filter(entry=>entry.available).map(entry=>entry.index),[0,20]);
 assert.deepEqual(legacy,{format:2,defeated:[won],affinities:{}});
});
