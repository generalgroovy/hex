import assert from 'node:assert/strict';
import test from 'node:test';
import {campaignSpellEntry,campaignSpellLibrary,equipCampaignSpell,compareCampaignSpells,repairedSpellSlots,changeCampaignAppearance} from '../lib/campaign-workshop-v20.ts';
import {readCampaignProfile,validateCampaignHero} from '../lib/campaign-profile-v20.ts';
import {ALL_SPELLS,ENEMY_SPELLS,getCreatureSpell,getSignature,effectiveSpell,repairLoadout,spellAccess} from '../lib/spells-v20.ts';
import {CREATURES} from '../lib/campaign-creatures-v20.ts';
import {CHAMPIONS,affinityTotal} from '../lib/roster-v13.ts';

test('the library exposes every actual enemy source one-to-one without inventing a teacher for core spells',()=>{
 const profile=readCampaignProfile(null),entries=campaignSpellLibrary(profile,profile.hero,{filter:'all'});
 assert.equal(entries.length,ALL_SPELLS.length);assert.equal(entries.filter(entry=>entry.origin).length,ENEMY_SPELLS.length);
 assert.equal(new Set(entries.flatMap(entry=>entry.origin?[entry.origin.sourceId]:[])).size,123);
 assert.equal(entries.filter(entry=>!entry.origin).length,48);
 for(const source of ENEMY_SPELLS)assert.equal(entries.find(entry=>entry.spell.id===source.spellId)?.origin?.sourceId,source.sourceId);
});
test('teaching and affinity remain independent visible requirements and filters do not pretend learned means ready',()=>{
 const profile=readCampaignProfile(null),creature=CREATURES.find(entry=>entry.strengthClass==='greater'&&entry.elements.length===1&&entry.elements[0]==='earth')!,spell=getCreatureSpell(creature.id);
 const unknown=campaignSpellEntry(profile,profile.hero,spell.id);
 assert.equal(unknown.ready,false);assert.equal(unknown.learned,false);assert.equal(unknown.requiredAffinity,6);assert.equal(unknown.requirements.length,2);
 assert.ok(unknown.requirements.some(reason=>reason.includes(creature.name)));assert.ok(unknown.requirements.some(reason=>reason.includes('Earth affinity 0/6')));
 const learned={...profile,learnedSpells:[spell.id]},known=campaignSpellEntry(learned,learned.hero,spell.id);
 assert.equal(known.learned,true);assert.equal(known.ready,false);assert.deepEqual(known.requirements,['Earth affinity 0/6.']);
 assert.ok(campaignSpellLibrary(learned,learned.hero,{filter:'learned'}).some(entry=>entry.spell.id===spell.id));
 assert.ok(!campaignSpellLibrary(learned,learned.hero,{filter:'ready'}).some(entry=>entry.spell.id===spell.id));
});
test('search finds a source by name, respects every query word, and filters by element',()=>{
 const profile=readCampaignProfile(null),spell=getCreatureSpell('creature-fire-cinder');
 assert.ok(campaignSpellLibrary(profile,profile.hero,{query:'CINDER',filter:'all'}).some(entry=>entry.spell.id===spell.id));
 assert.ok(!campaignSpellLibrary(profile,profile.hero,{query:'Cinder impossible-word',filter:'all'}).length);
 assert.ok(campaignSpellLibrary(profile,profile.hero,{element:'water',filter:'all'}).every(entry=>entry.spell.element==='water'));
});
test('preparing a new campaign encounter shows its actual focused area and repaired Light role',()=>{
 const profile=readCampaignProfile(null);
 const water=campaignSpellEntry(profile,profile.hero,'water_jet').effective;
 const light=campaignSpellEntry(profile,profile.hero,'sunburst').effective;
 assert.equal(water.radius,2);
 assert.equal(light.pierce,true);
 assert.equal(light.harmful,undefined);
 assert.match(compareCampaignSpells(water,light).find(row=>row.label==='Area')!.candidate,/Radius 2/);
 assert.ok(campaignSpellLibrary(profile,profile.hero,{query:'piercing',filter:'all'}).some(entry=>entry.spell.id==='sunburst'));
});
test('equipping requires actual knowledge, preserves the other slots, and swapping never duplicates or drops a spell',()=>{
 const profile=readCampaignProfile(null),spell=getCreatureSpell('creature-fire-cinder');
 assert.throws(()=>equipCampaignSpell(profile,profile.hero,1,spell.id),/Defeat Cinder/);
 const known={...profile,learnedSpells:[spell.id]},before=[...profile.hero.loadout],equipped=equipCampaignSpell(known,known.hero,1,spell.id);
 assert.equal(equipped.loadout[1],spell.id);assert.equal(equipped.loadout[0],before[0]);assert.equal(equipped.loadout[2],before[2]);assert.equal(equipped.loadout[3],before[3]);assert.deepEqual(profile.hero.loadout,before);
 const swapped=equipCampaignSpell(known,equipped,3,spell.id);
 assert.equal(swapped.loadout[3],spell.id);assert.equal(swapped.loadout[1],before[3]);assert.deepEqual([...swapped.loadout].sort(),[...equipped.loadout].sort());
 assert.throws(()=>equipCampaignSpell(known,known.hero,0,getSignature(known.hero.championId).id),/fixed fifth slot/);
 assert.throws(()=>equipCampaignSpell(known,known.hero,4,spell.id),/four spell slots/);
});
test('comparisons use current effective costs and effects, and repair notices identify the changed slot',()=>{
 const profile=readCampaignProfile(null),current=effectiveSpell(profile.hero.championId,'water_jet',profile.hero.affinities),candidate=effectiveSpell(profile.hero.championId,'cleansing_tide',profile.hero.affinities),rows=compareCampaignSpells(current,candidate);
 assert.equal(rows.find(row=>row.label==='Flux')?.candidate,String(candidate.cost));
 assert.equal(rows.find(row=>row.label==='Damage')?.current,String(current.damage));
 assert.equal(rows.find(row=>row.label==='Healing')?.candidate,String(candidate.heal));
 assert.deepEqual(repairedSpellSlots(['water_jet','undertow','ember','cleansing_tide'],['water_jet','frostbite','ember','cleansing_tide']),['Slot 2: Undertow → Frostbite']);
});
test('new appearance allocations respect early progression caps and keep valid learned creature choices',()=>{
 const profile=readCampaignProfile(null),taught=getCreatureSpell('creature-fire-cinder').id,learned=[taught],current={...profile.hero,name:'Brook',affinities:{water:4,fire:2},loadout:repairLoadout(profile.hero.championId,['water_jet',taught,'ember','cleansing_tide'],{water:4,fire:2},learned)};
 for(const avatar of CHAMPIONS){const changed=changeCampaignAppearance(current,avatar.id,learned,4);assert.equal(changed.name,'Brook');assert.equal(affinityTotal(changed.affinities),6);assert.ok(Object.values(changed.affinities).every(rank=>rank!<=4));assert.equal(validateCampaignHero(changed,6,learned).championId,avatar.id);if(spellAccess(avatar.id,taught,changed.affinities,learned).unlocked)assert.equal(changed.loadout[1],taught)}
});
