import test from 'node:test';
import assert from 'node:assert/strict';
import {CHAMPIONS} from '../lib/roster-v13.ts';
import {CREATURES} from '../lib/campaign-creatures-v20.ts';
import {getCreatureSpell,getSignature,teachingForEnemy} from '../lib/spells-v20.ts';
import {readCampaignProfile,validateCampaignProfile,campaignAffinityBudget,campaignAffinityRankCap,CAMPAIGN_ENCOUNTERS,CAMPAIGN_FIELD_ENCOUNTERS,campaignFieldEncounters,campaignEncounterStatus,createCampaignGame,restoreCampaignGame,applyCampaignProgress,updateCampaignHero,type CampaignProfile} from '../lib/story-v20.ts';
import {createCampaignSession,restoreCampaignSession} from '../lib/campaign-storage-v20.ts';
import {resolveRound,availableUnitSpellIds,castAvailability,legalCasts,validatePlan,type SimState,type TeamPlan} from '../lib/tactics-v20.ts';
import {createCampaignGame as createOld,readCampaignProfile as readOld,restoreCampaignGame as restoreOld} from '../lib/story-v19.ts';
const empty=():TeamPlan=>({orders:[]});
const profileAt=(index:number)=>validateCampaignProfile({...readCampaignProfile(null),defeated:CHAMPIONS.slice(0,index).map(hero=>hero.id)});
const kill=(unit:SimState['units'][number])=>{unit.hp=0;unit.flux=0;unit.statuses={};unit.cooldowns={};delete unit.guard};
function actualDefeat(){
 const profile=readCampaignProfile(null),state=createCampaignGame(profile,'oh_tipi'),hero=state.units.find(unit=>unit.kind==='hero')!,victim=state.units.find(unit=>unit.owner===1&&unit.kind==='creature')!;
 Object.assign(hero,{q:0,r:0});Object.assign(victim,{q:1,r:0,hp:1});
 const next=resolveRound(state,[{orders:[{unitId:hero.id,spellId:'water_jet',cast:{q:1,r:0}}]},empty()]);assert.equal(next.units.find(unit=>unit.id===victim.id)!.hp,0);assert.deepEqual(restoreCampaignGame(next),next);return {profile,state,next,victim};
}

test('all story and field encounters construct strict restorable states with native own techniques',()=>{
 for(const encounter of CAMPAIGN_ENCOUNTERS){const state=createCampaignGame(profileAt(encounter.index),encounter.id);assert.deepEqual(restoreCampaignGame(state),state)}
 const late=profileAt(20);assert.equal(campaignFieldEncounters(late).length,CREATURES.length);assert.equal(new Set(CAMPAIGN_FIELD_ENCOUNTERS.map(entry=>entry.mapId)).size,CREATURES.length);
 for(const creature of CREATURES){const state=createCampaignGame(late,`field:${creature.id}`);assert.deepEqual(restoreCampaignGame(state),state);const actor=state.units.find(unit=>unit.owner===1&&unit.creatureId===creature.id)!;assert.equal(actor.loadout[0],getCreatureSpell(creature.id).id);assert.ok(castAvailability(state,actor.id,actor.loadout[0]).available);assert.ok(!availableUnitSpellIds(state,actor.id).includes(getSignature(actor.championId).id));}
});

test('each of the 93 native creature techniques actually casts and restores with its complete effects',()=>{
 const profile=profileAt(20);
 for(const creature of CREATURES){
  const state=createCampaignGame(profile,`field:${creature.id}`),actor=state.units.find(unit=>unit.owner===1&&unit.creatureId===creature.id)!,spellId=actor.loadout[0],targets=legalCasts(state,actor.id,undefined,spellId),aim=targets.find(point=>point.q===actor.q&&point.r===actor.r)??targets[0];
  assert.ok(aim,creature.id);const next=resolveRound(state,[empty(),{orders:[{unitId:actor.id,spellId,cast:{q:aim.q,r:aim.r}}]}]);
  assert.ok(next.lastResolution.some(event=>event.kind==='cast'&&event.unitId===actor.id&&event.spellId===spellId),creature.id);assert.deepEqual(restoreCampaignGame(next),next,creature.id);
 }
});

test('field targets respect tier gates, are deterministic, and offer every creature at full recruitment access',()=>{
 const fresh=readCampaignProfile(null),locked=CREATURES.find(creature=>creature.strengthClass==='greater')!;
 assert.ok(campaignFieldEncounters(fresh).every(entry=>CREATURES.find(creature=>creature.id===entry.targetCreatureId)!.strengthClass==='lesser'));assert.equal(campaignEncounterStatus(fresh,`field:${locked.id}`).available,false);assert.throws(()=>createCampaignGame(fresh,`field:${locked.id}`));
 assert.deepEqual(createCampaignGame(fresh,`field:${fresh.companions[0]}`),createCampaignGame(fresh,`field:${fresh.companions[0]}`));
});

test('one actual enemy defeat teaches exactly its own spell before victory and survives a later loss',()=>{
 const {profile,next,victim}=actualDefeat(),spell=teachingForEnemy(victim).id,initialLibrary=[...next.learnedSignatures[0]],progress=applyCampaignProgress(profile,next);
 assert.equal(next.winner,null);assert.deepEqual(progress.learned.map(reward=>reward.spellId),[spell]);assert.equal(progress.victory,false);assert.equal(progress.affinityGained,0);assert.equal(campaignAffinityBudget(progress.profile),5);assert.ok(progress.profile.learnedSpells.includes(spell));assert.deepEqual(next.learnedSignatures[0],initialLibrary);
 const duplicate=applyCampaignProgress(progress.profile,next);assert.deepEqual(duplicate.profile,progress.profile);assert.deepEqual(duplicate.learned,[]);
 const losing=structuredClone(next);losing.units.filter(unit=>unit.owner===0).forEach(kill);const result=resolveRound(losing,[empty(),empty()]);assert.equal(result.winner,1);
 const afterLoss=applyCampaignProgress(progress.profile,result);assert.ok(afterLoss.profile.learnedSpells.includes(spell));assert.equal(afterLoss.profile.defeated.length,0);assert.equal(afterLoss.affinityGained,0);
});

test('victory teaches every remaining enemy and awards story affinity only once; field wins award no affinity',()=>{
 const profile=readCampaignProfile(null),state=createCampaignGame(profile,'oh_tipi');state.units.filter(unit=>unit.owner===1).forEach(kill);const result=resolveRound(state,[empty(),empty()]),won=applyCampaignProgress(profile,result);
 assert.equal(won.learned.length,3);assert.equal(won.victory,true);assert.equal(won.affinityGained,1);assert.equal(campaignAffinityRankCap(won.profile),4);assert.deepEqual(applyCampaignProgress(won.profile,result).learned,[]);assert.equal(applyCampaignProgress(won.profile,result).affinityGained,0);
 const field=createCampaignGame(profile,`field:${profile.companions[0]}`);field.units.filter(unit=>unit.owner===1).forEach(kill);const fieldResult=resolveRound(field,[empty(),empty()]),learned=applyCampaignProgress(profile,fieldResult);assert.equal(learned.affinityGained,0);assert.equal(learned.victory,false);assert.deepEqual(learned.profile.defeated,[]);assert.equal(learned.learned.length,3);
});

test('migration preserves saved19 identity and infers only defeated lineups; old battles stay frozen',()=>{
 const old={...readOld(null),defeated:['oh_tipi'],hero:{...readOld(null).hero,name:'Reed'}},original=structuredClone(old),profile=readCampaignProfile(null,JSON.stringify(old));
 assert.deepEqual(old,original);assert.equal(profile.hero.name,'Reed');assert.deepEqual(profile.defeated,['oh_tipi']);assert.equal(profile.learnedSpells.length,3);assert.ok(profile.learnedSpells.includes(getSignature('oh_tipi').id));assert.ok(profile.learnedSpells.includes(getCreatureSpell('creature-air-pip').id));
 const oldBattle=createOld(readOld(null),'oh_tipi');assert.deepEqual(restoreOld(oldBattle),oldBattle);assert.throws(()=>restoreCampaignGame(oldBattle));
 const legacy=readCampaignProfile(null,null,{format:2,defeated:['oh_tipi'],affinities:{}});assert.ok(legacy.learnedSpells.length>=1);assert.ok(legacy.learnedSpells.every(id=>!id.startsWith('creature_spell:')),'Old ambient creatures were never defeated combat actors');
 const damaged={...profile,hero:{...profile.hero,affinities:{water:99}},learnedSpells:[...profile.learnedSpells,'fake']},repaired=readCampaignProfile(damaged);assert.deepEqual(repaired.defeated,profile.defeated);assert.deepEqual(repaired.learnedSpells,profile.learnedSpells);assert.equal(repaired.hero.name,'Reed');
});

test('learning unlocks ownership but does not bypass affinity or alter the fixed battle kit',()=>{
 const {profile,next,victim}=actualDefeat(),progress=applyCampaignProgress(profile,next),spell=getCreatureSpell(victim.creatureId!).id;
 assert.throws(()=>updateCampaignHero(progress.profile,{...profile.hero,loadout:[spell,...profile.hero.loadout.slice(1)]}));
 assert.deepEqual(next.campaign.profile,profile);assert.deepEqual(next.learnedSignatures[0],profile.learnedSpells);assert.ok(!availableUnitSpellIds(next,'0-hero').includes(spell));
});

test('atomic sessions recover knowledge and replay, reset bad drafts, and keep untouched actors unplanned',()=>{
 const {profile,state,next,victim}=actualDefeat(),session=createCampaignSession(profile,next,empty(),state),restored=restoreCampaignSession(JSON.stringify(session));
 assert.ok(restored.profile.learnedSpells.includes(teachingForEnemy(victim).id));assert.deepEqual(restored.match?.previous,state);assert.deepEqual(restored.match?.plan,{orders:[]});assert.deepEqual(restoreCampaignSession(restored),restored);
 const raw=structuredClone(session);raw.match!.plan={orders:[{unitId:'missing',guard:true}]};raw.match!.previous={...state,version:99};const repaired=restoreCampaignSession(raw);assert.equal(repaired.match?.previous,undefined);assert.deepEqual(repaired.match?.plan,{orders:[]});assert.deepEqual(repaired.match?.state,next);
 const one={orders:[{unitId:'0-hero',guard:true}]},oneSession=createCampaignSession(profile,state,one);assert.equal(oneSession.match?.plan.orders.length,1);
 assert.deepEqual(createCampaignSession(restored.profile,null).profile,restored.profile);
});

test('forged libraries, creature techniques and stale campaign provenance are rejected',()=>{
 const profile=readCampaignProfile(null),state=createCampaignGame(profile,'oh_tipi');
 const copy=structuredClone(state);copy.learnedSignatures[0]=[getCreatureSpell('creature-fire-cinder').id];assert.throws(()=>restoreCampaignGame(copy));
 const bad=structuredClone(state),creature=bad.units.find(unit=>unit.kind==='creature')!;creature.loadout[0]=getSignature(creature.championId).id;assert.throws(()=>restoreCampaignGame(bad));
 const later=createCampaignGame(profileAt(2),'red_baron');assert.throws(()=>applyCampaignProgress(profile,later));
 assert.throws(()=>validateCampaignProfile({...profile,learnedSpells:['missing']}));assert.throws(()=>restoreCampaignSession({format:1,profile,match:{state:{},plan:empty()}}));
});
