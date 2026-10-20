import test from 'node:test';
import assert from 'node:assert/strict';
import {CHAMPIONS} from '../lib/roster-v13.ts';
import {CREATURES,getCreature} from '../lib/campaign-creatures-v20.ts';
import {CREATURES as oldCreatures} from '../lib/campaign-creatures-v19.ts';
import * as oldSpells from '../lib/spells-v16.ts';
import {ALL_SPELLS,CREATURE_SPELLS,TEACHABLE_SPELLS,ENEMY_SPELLS,SPELLS,getSpell,getSignature,getCreatureSpell,creatureLoadout,enemySpell,spellOrigin,teachingForEnemy,spellElements,spellAccess,spellCost,effectiveSpell,validateLoadout,repairLoadout,defaultLoadout,availableSpellIds,validateLearnedSpells,validateLearnedSignatures,spellScalingSummary,type Spell} from '../lib/spells-v20.ts';
const allLearned=TEACHABLE_SPELLS.map(spell=>spell.id);
const fingerprint=(spell:Spell)=>JSON.stringify({elements:spellElements(spell),shape:spell.shape,radius:spell.radius,damage:spell.damage,heal:spell.heal,harm:spell.harm,harmful:spell.harmful,friendly:spell.friendly,self:spell.self,push:spell.push,cleanse:spell.cleanse,dispel:spell.dispel,wall:spell.wall,pierce:spell.pierce,freeze:spell.freeze,drain:spell.drain,steal:spell.steal,recharge:spell.recharge,selfDamage:spell.selfDamage,bonus:spell.bonus,bonusDamage:spell.bonusDamage});

test('every enemy type teaches exactly one distinct technique with a resolvable source',()=>{
 assert.equal(CREATURE_SPELLS.length,93);assert.equal(TEACHABLE_SPELLS.length,123);assert.equal(ALL_SPELLS.length,171);assert.equal(ENEMY_SPELLS.length,123);
 assert.equal(new Set(ENEMY_SPELLS.map(source=>source.sourceId)).size,123);assert.equal(new Set(ENEMY_SPELLS.map(source=>source.spellId)).size,123);assert.equal(new Set(ALL_SPELLS.map(spell=>spell.id)).size,171);assert.equal(new Set(ALL_SPELLS.map(spell=>spell.name)).size,171);
 for(const creature of CREATURES){const spell=getCreatureSpell(creature.id),source=spellOrigin(spell.id)!;assert.equal(source.creatureId,creature.id);assert.equal(source.name,creature.name);assert.equal(source.kind,'creature');assert.equal(enemySpell(source.sourceId),source);assert.equal(teachingForEnemy({championId:creature.championId,creatureId:creature.id}),spell);assert.equal(spell.creatureId,creature.id);}
 for(const champion of CHAMPIONS){const spell=getSignature(champion.id);assert.equal(teachingForEnemy({championId:champion.id}),spell);assert.equal(spellOrigin(spell.id)!.championId,champion.id);}
 for(const spell of SPELLS)assert.equal(spellOrigin(spell.id),null);
 assert.throws(()=>enemySpell('creature:unknown'));assert.throws(()=>getCreatureSpell('oh_tipi'));
});

test('creature techniques differ in actual resolution effects, not just names, costs or reach',()=>{
 const seen=new Map<string,string>();
 for(const spell of CREATURE_SPELLS){const key=fingerprint(spell);assert.ok(!seen.has(key),`${spell.name} duplicates ${seen.get(key)}`);seen.set(key,spell.name);assert.ok(spell.counterplay&&spell.counterplay.length>35);assert.ok(spell.description.includes('Area:'));}
 for(const creature of CREATURES){const spell=getCreatureSpell(creature.id);assert.deepEqual(spellElements(spell),creature.elements.length>1?creature.elements:[spell.element]);if(creature.elements.length>1)assert.ok(spell.description.includes('Leaves '));}
});

test('native creature kits keep class slot counts and can pay for their own techniques',()=>{
 for(const creature of CREATURES){
  const old=oldCreatures.find(entry=>entry.id===creature.id)!,spell=getCreatureSpell(creature.id),context=[spell.id];
  assert.deepEqual(creature.loadout,[spell.id,...old.loadout.slice(1)]);assert.deepEqual(creatureLoadout(creature.id),creature.loadout);assert.equal(creature.loadout.length,old.loadout.length);assert.equal(new Set(creature.loadout).size,creature.loadout.length);
  assert.equal(spellAccess(creature.championId,spell.id,creature.affinities).unlocked,false,'Proxy affinity never grants native creature identity implicitly');
  assert.equal(spellAccess(creature.championId,spell.id,creature.affinities,context).unlocked,true);assert.ok(spellCost(creature.championId,spell.id,creature.affinities)<=creature.maxFlux);
  for(const id of creature.loadout)assert.equal(spellAccess(creature.championId,id,creature.affinities,context).unlocked,true);
  const effective=effectiveSpell(creature.championId,spell.id,creature.affinities);assert.equal(effective.cost,spellCost(creature.championId,spell.id,creature.affinities));assert.ok(effective.damage<=4);assert.ok(effective.heal<=4);assert.ok(effective.range<=6);assert.ok(effective.cooldown>=1);
  for(const channel of ['harmful','friendly','self'] as const)for(const mark of effective[channel]??[]){assert.ok(mark.turns<=(['rooted','chilled','blind','concussed'].includes(mark.id)?1:['burn','ward','resolve'].includes(mark.id)?2:3));assert.ok((mark.power??1)<=(mark.id==='ward'?5:1));}
  if(creature.elements.length>=4){assert.ok(effective.cost>=5);assert.ok(effective.cooldown>=3);assert.ok(spell.radius<=1);}
 }
 assert.throws(()=>getCreature(CREATURES[0].id).loadout.push('ember'));
});

test('borrowed techniques require a known victory and sufficient affinity in a real four-slot kit',()=>{
 for(const spell of CREATURE_SPELLS){
  const creature=getCreature(spell.creatureId!),hero=creature.championId,affinities={[spell.element]:6};
  assert.equal(spellAccess(hero,spell.id,affinities,[]).unlocked,false);assert.match(spellAccess(hero,spell.id,affinities,[]).reason!,/Defeat /);
  assert.equal(spellAccess(hero,spell.id,{[spell.element]:spell.level-1},[spell.id]).unlocked,false);assert.match(spellAccess(hero,spell.id,{[spell.element]:spell.level-1},[spell.id]).reason!,/Requires /);
  assert.equal(spellAccess(hero,spell.id,affinities,[spell.id]).unlocked,true);
  const base=defaultLoadout(hero,affinities),loadout=[spell.id,...base.slice(1)];assert.deepEqual(validateLoadout(hero,loadout,affinities,[spell.id]),loadout);assert.throws(()=>validateLoadout(hero,loadout,affinities,[]));
  assert.deepEqual(repairLoadout(hero,loadout,affinities,[spell.id]),loadout);assert.ok(availableSpellIds(hero,loadout,affinities,[spell.id]).includes(spell.id));assert.ok(!availableSpellIds(hero,loadout,affinities,[]).includes(spell.id));
 }
 assert.deepEqual(validateLearnedSpells(allLearned),[...allLearned].sort());assert.deepEqual(validateLearnedSignatures(allLearned),[...allLearned].sort());assert.throws(()=>validateLearnedSpells(['ember']));assert.throws(()=>validateLearnedSpells([allLearned[0],allLearned[0]]));assert.throws(()=>validateLearnedSpells(['invented']));
});

test('champion creator discounts, old spell scaling and old catalogue remain unchanged',()=>{
 for(const champion of CHAMPIONS){const signature=getSignature(champion.id),affinities={[signature.element]:6};assert.equal(spellAccess(champion.id,signature.id,affinities).requiredAffinity,3);assert.equal(spellCost(champion.id,signature.id,affinities),signature.cost-2);const borrower=CHAMPIONS.find(other=>other.id!==champion.id)!;assert.equal(spellAccess(borrower.id,signature.id,affinities,[signature.id]).requiredAffinity,5);assert.equal(spellCost(borrower.id,signature.id,affinities),signature.cost);}
 for(const spell of oldSpells.ALL_SPELLS){assert.deepEqual(getSpell(spell.id),spell);assert.deepEqual(effectiveSpell('oh_tipi',spell.id,{water:6,fire:4,light:2}),oldSpells.effectiveSpell('oh_tipi',spell.id,{water:6,fire:4,light:2}));}
 assert.equal(oldSpells.ALL_SPELLS.length,78);assert.throws(()=>oldSpells.getSpell(CREATURE_SPELLS[0].id));assert.ok(oldCreatures.every(creature=>!creature.loadout.some(id=>id.startsWith('creature_spell:'))));
});

test('derived descriptions and scaling agree with bounded new effects without mutating bases',()=>{
 for(const spell of CREATURE_SPELLS){const before=JSON.stringify(spell),creature=getCreature(spell.creatureId!);for(let rank=1;rank<=6;rank++){const effective=effectiveSpell(creature.championId,spell.id,{[spell.element]:rank});assert.deepEqual(spellElements(effective),spellElements(spell));assert.equal(effective.radius,spell.radius);assert.equal(effective.push,spell.push);assert.equal(effective.selfDamage,spell.selfDamage);if(effective.damage)assert.ok(effective.description.includes(`Deal ${effective.damage}`));if(effective.heal)assert.ok(effective.description.includes(`for ${effective.heal}.`));assert.ok(spellScalingSummary(creature.championId,spell.id,{[spell.element]:rank}).length>0);}assert.equal(JSON.stringify(spell),before);}
 const mixed=CREATURE_SPELLS.find(spell=>spell.fieldElements)!;assert.throws(()=>mixed.fieldElements!.push('fire'));assert.throws(()=>{mixed.damage=99;});
});
