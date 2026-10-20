import assert from 'node:assert/strict';
import test from 'node:test';
import {changeCampaignAppearance,campaignDraftHint} from '../lib/campaign-workshop-v19.ts';
import {canonicalBuild} from '../lib/character-creation-v17.ts';
import {CHAMPIONS,affinityTotal,allocateAffinityBudget} from '../lib/roster-v13.ts';
import {validateCampaignHero,campaignAffinityRankCap} from '../lib/campaign-profile-v19.ts';
import {repairLoadout,getSignature} from '../lib/spells-v16.ts';

test('a five-point build can temporarily release a point before reassigning it',()=>{
 const hero=canonicalBuild('oh_tipi'),draft={...hero,affinities:{water:3,fire:1}};
 assert.equal(campaignDraftHint(draft),'Assign 1 affinity point to use this build.');
 const reassigned={...draft,affinities:{water:3,fire:2},loadout:repairLoadout(hero.championId,hero.loadout,{water:3,fire:2},[])};
 assert.equal(campaignDraftHint(reassigned),null);
 assert.equal(affinityTotal(validateCampaignHero(reassigned,5,[]).affinities),5);
});

test('appearance changes keep a custom name and earned investment across every avatar',()=>{
 const base=canonicalBuild('oh_tipi'),affinities=allocateAffinityBudget(base.championId,14),learned=CHAMPIONS.map(hero=>getSignature(hero.id).id);
 const hero={...base,name:'River Keeper',affinities,loadout:repairLoadout(base.championId,base.loadout,affinities,learned)};
 for(const avatar of CHAMPIONS){
  const next=changeCampaignAppearance(hero,avatar.id,learned);
  assert.equal(next.name,'River Keeper');assert.equal(affinityTotal(next.affinities),14);
  assert.equal(validateCampaignHero(next,14,learned).championId,avatar.id);
 }
});

test('appearance changes preserve five-point legality and unfinished names stay drafts',()=>{
 for(const avatar of CHAMPIONS){const next=changeCampaignAppearance(canonicalBuild('oh_tipi'),avatar.id,[]);assert.equal(validateCampaignHero(next,5,[]).name,avatar.name)}
 assert.equal(campaignDraftHint({...canonicalBuild('oh_tipi'),name:' '}),'Choose a name to use this build.');
});

test('early victories raise the element cap gradually and avatar changes preserve that cap',()=>{
 const base=canonicalBuild('oh_tipi');
 for(let wins=1;wins<=3;wins++){
  const cap=campaignAffinityRankCap({defeated:CHAMPIONS.slice(0,wins).map(hero=>hero.id)}),budget=5+wins;
  const affinities={...base.affinities,water:(base.affinities.water??0)+wins};
  const current={...base,affinities};
  for(const avatar of CHAMPIONS){
   const next=changeCampaignAppearance(current,avatar.id,[],cap);
   assert.equal(affinityTotal(next.affinities),budget);assert.ok(Object.values(next.affinities).every(rank=>rank!<=cap));
   assert.equal(validateCampaignHero(next,budget,[]).championId,avatar.id);
  }
 }
});
