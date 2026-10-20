import assert from 'node:assert/strict';
import test from 'node:test';
import {CHAMPIONS,getChampion,allocateAffinityBudget,teamAffinityTotal} from '../lib/roster-v13.ts';
import {CHAMPIONS as canonical} from '../lib/roster-v11.ts';
import {CHARACTER_DESIGN} from '../lib/character-design-v13.ts';
import {defaultLoadout,validateLoadout,repairLoadout,getSpell,getSignature,effectiveSpell,spellAccess} from '../lib/spells-v13.ts';
import {nextAffinityStep} from '../lib/affinity-preview-v13.ts';
import {STORY_ENCOUNTERS,STORY_PROGRESS_KEY,readStoryProgress,storyAffinityBudget,storyAffinities,storyTeamAffinities,setStoryAffinity,encounterAffinities,encounterLoadouts,encounterSignature,recommendStoryEncounter,createStoryGame,awardStoryVictory} from '../lib/story-v13.ts';
import {restoreSimState,MAX_ROUNDS,type SimState} from '../lib/tactics-v13.ts';
import {createStoryGame as oldStoryGame,awardStoryVictory as oldAward} from '../lib/story-v12.ts';
const roster=['oh_tipi','wa_bidi','treevor_mason'];
const progress=(count=0)=>readStoryProgress({format:1,defeated:STORY_ENCOUNTERS.slice(0,count).map(entry=>entry.id)});
const won=<T extends {round:number;version:number;winner:unknown;scores:unknown}>(state:T):T=>({...state,round:MAX_ROUNDS,version:MAX_ROUNDS+1,winner:0,scores:[16,12]});

test('all 30 current identities preserve canonical data and provide distinct legal native starter kits',()=>{
 assert.equal(CHAMPIONS.length,30);assert.equal(Object.keys(CHARACTER_DESIGN).length,30);
 const kits=new Set<string>();
 for(const champion of CHAMPIONS){
  const old=canonical.find(entry=>entry.id===champion.id)!;
  assert.deepEqual({...champion,description:old.description},old,'only current description changes');
  assert.equal(getChampion(champion.id),champion);
  const design=CHARACTER_DESIGN[champion.id],kit=defaultLoadout(champion.id);
  assert.deepEqual(kit,design.kit);assert.deepEqual(validateLoadout(champion.id,kit),kit);
  assert.ok(design.role.length>0&&design.description.length>30);
  assert.doesNotMatch(design.description,/stamina|race perks|racial|health reserves|recovery rate/i);
  assert.equal(new Set(kit).size,4);assert.ok(!kit.includes(getSignature(champion.id).id));
  const ingredients=new Set(kit.map(id=>getSpell(id).element));
  assert.deepEqual([...ingredients].sort(),Object.keys(champion.affinities).sort(),'starter kit can express every native ingredient');
  assert.ok(kit.some(id=>getSpell(id).damage>0),'a ready offensive tool remains');
  assert.ok(kit.some(id=>{const spell=getSpell(id);return spell.heal||spell.push||spell.cleanse||spell.friendly?.length||spell.harmful?.length;}),'kit includes a consequential non-damage verb');
  kits.add([...kit].sort().join('|'));
 }
 assert.equal(kits.size,30,'distinct kits are different tools, not just slot permutations');
});

test('all 30 encounters retain fixed strength and legal role upgrades without losing native ingredients',()=>{
 for(const [index,encounter] of STORY_ENCOUNTERS.entries()){
  const allocations=encounterAffinities(encounter.id),kits=encounterLoadouts(encounter.id),game=createStoryGame(encounter.id,roster);
  assert.equal(game.rulesVersion,13);assert.deepEqual(restoreSimState(game),game);
  assert.equal(teamAffinityTotal(encounter.opponents,allocations),(5+Math.floor(index/3))*3);
  for(const id of encounter.opponents){
   assert.deepEqual(validateLoadout(id,kits[id],allocations[id]),kits[id]);
   assert.deepEqual([...new Set(kits[id].map(spell=>getSpell(spell).element))].sort(),Object.keys(getChampion(id).affinities).sort());
   const authored=CHARACTER_DESIGN[id];
   for(const [slot,spellId] of kits[id].entries())if(spellId!==authored.kit[slot]){
    assert.ok(authored.upgrades.some(upgrade=>upgrade.slot===slot&&upgrade.spellId===spellId));
    assert.equal(getSpell(spellId).element,getSpell(authored.kit[slot]).element);
   }
  }
  assert.ok(encounter.focus.length>0&&encounter.lesson.length>40&&encounter.lesson.length<260);
 }
 assert.equal(new Set(STORY_ENCOUNTERS.map(entry=>entry.focus)).size,30);
 assert.equal(new Set(STORY_ENCOUNTERS.map(entry=>entry.lesson)).size,30);
});

test('every Story signature preview equals the actual boss at its fixed encounter allocation',()=>{
 for(const encounter of STORY_ENCOUNTERS){
  const game=createStoryGame(encounter.id,roster),boss=game.units.find(unit=>unit.owner===1&&unit.championId===encounter.championId)!;
  assert.deepEqual(encounterSignature(encounter.id),effectiveSpell(boss.championId,getSignature(boss.championId).id,boss.affinities));
 }
 assert.equal(encounterSignature('oh_tipi').range,getSignature('oh_tipi').range+1,'first encounter does not receive rank5 reach');
 assert.notEqual(encounterSignature('oh_tipi').range,effectiveSpell('oh_tipi',getSignature('oh_tipi').id,{water:5}).range);
});

test('recommendations use allocated company strength, exclude victories and never scale encounters',()=>{
 const fresh=progress();assert.equal(recommendStoryEncounter(fresh,roster)?.encounterId,'oh_tipi');
 const earned=progress(6),before=JSON.stringify(earned);
 const recommendation=recommendStoryEncounter(earned,roster)!;
 assert.equal(recommendation.companyAffinity,15,'unspent budget does not inflate actual strength');
 assert.equal(recommendation.encounterId,'treevor_mason');
 const trained=Object.fromEntries(roster.map(id=>[id,allocateAffinityBudget(id,10)]));
 const fixedBefore=encounterAffinities('hesus_christo');
 const stronger=recommendStoryEncounter(earned,roster,trained)!;
 assert.equal(stronger.companyAffinity,30);assert.equal(stronger.opponentAffinity,30);assert.equal(stronger.encounterId,'hesus_christo');
 assert.deepEqual(encounterAffinities('hesus_christo'),fixedBefore);assert.equal(JSON.stringify(earned),before);
 assert.equal(recommendStoryEncounter(progress(30),roster),null);
});

test('next-point previews show the immediate rank, true unlocks and fixed control duration',()=>{
 for(const element of ['fire','water','earth','air','light','dark'] as const){
  for(let rank=0;rank<6;rank++){
   const next=nextAffinityStep(element,rank)!;assert.equal(next.rank,rank+1);assert.ok(next.spellIds.length>0);
   for(const id of next.spellIds){
    assert.equal(getSpell(id).element,element);assert.equal(getSpell(id).level,next.rank);
    assert.equal(spellAccess('oh_tipi',id,{[element]:rank+1}).unlocked,true);
    assert.equal(spellAccess('oh_tipi',id,rank?{[element]:rank}:{}).unlocked,false);
   }
  }
  assert.equal(nextAffinityStep(element,6),null);
 }
 assert.match(nextAffinityStep('light',0)!.effect,/Unlocks/);assert.equal(nextAffinityStep('light',0)!.rank,1);
 assert.match(nextAffinityStep('water',3)!.effect,/Control duration stays fixed/);
 assert.throws(()=>nextAffinityStep('fire',-1),/between 0 and 6/);
});

test('earned affinity and legal custom choices survive current defaults and third-element removal',()=>{
 assert.equal(STORY_PROGRESS_KEY,'hex-confluence-story-v11');
 let current=setStoryAffinity(progress(3),'oh_tipi',{water:4,fire:2,light:2});
 assert.equal(storyAffinityBudget(current),8);assert.deepEqual(storyAffinities(current,'oh_tipi'),{water:4,fire:2,light:2});
 const custom=['deep_freeze','mend','ember','undertow'];
 assert.deepEqual(repairLoadout('oh_tipi',custom,storyAffinities(current,'oh_tipi')),custom);
 current=setStoryAffinity(current,'oh_tipi',{water:4,fire:2});
 const repaired=repairLoadout('oh_tipi',custom,storyTeamAffinities(current,roster).oh_tipi);
 assert.equal(repaired[0],'deep_freeze');assert.equal(repaired[2],'ember');assert.equal(repaired[3],'undertow');assert.notEqual(repaired[1],'mend');
 assert.deepEqual(validateLoadout('oh_tipi',repaired,{water:4,fire:2}),repaired);
});

test('new Story rewards require rules13 and preserve existing progress without farming replays',()=>{
 const fresh=progress(),victory=won(createStoryGame('oh_tipi',roster));
 const earned=awardStoryVictory(fresh,'oh_tipi',victory);assert.deepEqual(earned.defeated,['oh_tipi']);assert.equal(storyAffinityBudget(earned),6);
 assert.deepEqual(awardStoryVictory(earned,'oh_tipi',victory),earned);
 const legacy=won(oldStoryGame('oh_tipi',roster));assert.deepEqual(awardStoryVictory(fresh,'oh_tipi',legacy),fresh);
 assert.deepEqual(oldAward(fresh,'oh_tipi',legacy).defeated,['oh_tipi'],'frozen story rewards still work with frozen rules');
 assert.deepEqual(awardStoryVictory(fresh,'oh_tipi',{...victory,inhabitants:[]}),fresh);
 assert.deepEqual(awardStoryVictory(fresh,'oh_tipi',{...victory,winner:1,scores:[12,16]} as SimState),fresh);
});
