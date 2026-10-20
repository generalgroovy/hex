import test from 'node:test';
import assert from 'node:assert/strict';
import {createTowerRun,towerChampion,towerCreature,type TowerReward} from '../lib/tower-v23.ts';
import {effectiveSpell,getSignature,getSpell} from '../lib/spells-v20.ts';
import {trainingSpellStatChanges,towerRewardPreview} from '../lib/tower-reward-preview-v42.ts';

const training=(actorId:string,element:'fire'|'water'|'air'|'light'='water',amount=1):TowerReward=>({id:'train',kind:'train',name:'Practice',description:'',actorId,element,amount});

test('training previews real damage and healing changes, and a newly usable creator signature',()=>{
 const run=createTowerRun('REWARD42','steam'),actor=run.party[0];
 actor.affinities={water:2,air:2,fire:1};
 const preview=towerRewardPreview(run,training(actor.id));
 assert.equal(preview?.kind,'train');if(preview?.kind!=='train')return;
 assert.deepEqual(preview.spells.find(spell=>spell.id==='water_jet')?.changes,[{label:'Centre damage',before:3,after:4},{label:'Inner damage',before:2,after:3}]);
 assert.deepEqual(preview.spells.find(spell=>spell.id==='cleansing_tide')?.changes,[{label:'Centre healing',before:3,after:4},{label:'Inner healing',before:2,after:3}]);
 const signature=preview.unlocks.find(spell=>spell.id===getSignature(actor.championId).id);
 assert.ok(signature?.signature);assert.equal(signature.cost,effectiveSpell(actor.championId,signature.id,{...actor.affinities,water:3}).cost);
 assert.ok(!preview.spells.some(spell=>spell.id===signature.id),'a locked signature is an unlock, not an already equipped improvement');
});

test('training exposes cost, reach and status duration breakpoints from effective spells',()=>{
 const run=createTowerRun('REWARD42','steam'),actor=run.party[0];
 for(const [rank,expected] of [[1,['Flux','Reach']],[3,['Centre wet rounds','Inner wet rounds']],[4,['Reach']],[5,['Centre damage','Inner damage','Rim damage']]] as const){
  actor.affinities={water:rank,air:2};
  const preview=towerRewardPreview(run,training(actor.id));assert.equal(preview?.kind,'train');if(preview?.kind!=='train')return;
  const changes=preview.spells.find(spell=>spell.id==='water_jet')!.changes;
  assert.deepEqual(changes.map(change=>change.label),expected);
  assert.deepEqual(changes,trainingSpellStatChanges(effectiveSpell(actor.championId,'water_jet',actor.affinities),effectiveSpell(actor.championId,'water_jet',{...actor.affinities,water:rank+1})));
 }
});

test('training only labels learned spells or the creator signature as ready now',()=>{
 const run=createTowerRun('REWARD42','steam'),actor=run.party[0];
 actor.affinities={water:2,air:2,fire:1};
 const unlearned=getSpell('frostbite');assert.ok(!run.learnedSpells.includes(unlearned.id));
 const preview=towerRewardPreview(run,training(actor.id));
 assert.equal(preview?.kind,'train');if(preview?.kind!=='train')return;
 assert.ok(!preview.unlocks.some(spell=>spell.id===unlearned.id));
 run.learnedSpells.push(unlearned.id);
 const learned=towerRewardPreview(run,training(actor.id));assert.equal(learned?.kind,'train');if(learned?.kind!=='train')return;
 assert.ok(learned.unlocks.some(spell=>spell.id===unlearned.id));
});

test('recovery states actual capped gains per fighter and unused capacity',()=>{
 const run=createTowerRun('REWARD42','steam');
 run.party[0].hp=2;run.party[1].hp=3;
 const preview=towerRewardPreview(run,{id:'heal',kind:'heal',name:'Rest',description:'',amount:3});
 assert.equal(preview?.kind,'heal');if(preview?.kind!=='heal')return;
 assert.deepEqual(preview.fighters.map(actor=>[actor.before,actor.after,actor.maxHp,actor.gain]),[[2,5,8,3],[3,4,4,1]]);
 assert.equal(preview.total,4);assert.equal(preview.unused,2);
});

test('spell recipients honor affinity, creator cost, maximum Flux and fixed creature kits',()=>{
 const tipi=towerChampion('oh_tipi','tipi'),wayne=towerChampion('s_wayne','wayne'),cinder=towerCreature('creature-fire-cinder','cinder');
 tipi.affinities={water:3,air:1,fire:1};
 wayne.affinities={water:3,dark:3,light:2};
 const signature=getSignature('oh_tipi'),run={party:[tipi,wayne,cinder],learnedSpells:[]};
 const preview=towerRewardPreview(run,{id:'spell',kind:'spell',name:signature.name,description:'',spellId:signature.id});
 assert.equal(preview?.kind,'spell');if(preview?.kind!=='spell')return;
 assert.deepEqual(preview.recipients.map(actor=>actor.id),['tipi','wayne']);
 assert.equal(preview.recipients[0].eligible,true);assert.equal(preview.recipients[0].signature,true);
 assert.equal(preview.recipients[1].eligible,false);assert.equal(preview.recipients[1].reason,'Needs 5 Water');
 tipi.maxFlux=1;
 const expensive=towerRewardPreview(run,{id:'spell',kind:'spell',name:signature.name,description:'',spellId:signature.id});
 assert.equal(expensive?.kind,'spell');if(expensive?.kind!=='spell')return;
 assert.equal(expensive.recipients[0].eligible,false);assert.match(expensive.recipients[0].reason!,/maximum 1/);
});

test('reward inspection cannot change party, library, or the offered reward',()=>{
 const run=createTowerRun('REWARD42','steam'),reward=training(run.party[0].id),before=JSON.stringify({run,reward});
 towerRewardPreview(run,reward);towerRewardPreview(run,{id:'spell',kind:'spell',name:'Wet',description:'',spellId:'water_jet'});
 assert.equal(JSON.stringify({run,reward}),before);
 assert.equal(towerRewardPreview(run,training(run.party[1].id)),null);
});
