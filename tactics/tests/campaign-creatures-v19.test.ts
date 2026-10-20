import test from 'node:test';
import assert from 'node:assert/strict';
import {CREATURES,CREATURE_PERKS,CREATURE_BOND_RADIUS,getCreature,getCreaturePerk,teamPerkEffects,validateCreatureId,creatureAbilitySummary} from '../lib/campaign-creatures-v19.ts';
import {INHABITANT_SPECIES} from '../lib/inhabitants-v16.ts';
import {getChampion} from '../lib/roster-v13.ts';
import {getSpell,spellAccess,spellCost} from '../lib/spells-v16.ts';

test('every element offers six real species, two of each class, with distinct silhouettes and kits',()=>{
 assert.equal(CREATURES.length,93);assert.equal(new Set(CREATURES.map(creature=>creature.id)).size,93);assert.equal(new Set(CREATURES.map(creature=>creature.name)).size,93);
 for(const element of ['fire','water','earth','air','light','dark']){
  const species=CREATURES.filter(creature=>creature.elements.length===1&&creature.elements[0]===element);
  assert.equal(species.length,6);assert.equal(new Set(species.map(creature=>creature.family)).size,6);
  for(const strength of ['lesser','standard','greater'])assert.equal(species.filter(creature=>creature.strengthClass===strength).length,2);
  assert.equal(new Set(species.map(creature=>[...creature.loadout].sort().join('|'))).size,6,'Six entries must not be renamed copies of the same spell kit');
 }
 const mixed=CREATURES.filter(creature=>creature.elements.length>1);assert.equal(mixed.length,57);
 assert.deepEqual(mixed.map(creature=>creature.visualSpeciesId).sort(),INHABITANT_SPECIES.filter(species=>species.elements.length>1).map(species=>species.id).sort());
});

test('creature stats respect the final-collapse bound and every equipped cast is legal and affordable',()=>{
 for(const creature of CREATURES){
  const expected={lesser:[4,4,2],standard:[6,5,3],greater:[8,6,4]}[creature.strengthClass];
  assert.deepEqual([creature.maxHp,creature.maxFlux,creature.loadout.length],expected);
  assert.ok(getChampion(creature.championId));assert.equal(getCreature(creature.id),creature);assert.equal(validateCreatureId(creature.id),creature.id);
  assert.ok(Object.keys(creature.affinities).length<=3);assert.ok(Object.keys(creature.affinities).every(element=>creature.elements.includes(element as never)));
  for(const spellId of creature.loadout){
   const spell=getSpell(spellId);assert.ok(!spell.signatureChampionId,`${creature.name} cannot borrow a proxy signature`);
   assert.ok(creature.elements.includes(spell.element));assert.ok(spellAccess(creature.championId,spellId,creature.affinities).unlocked);
   assert.ok(spellCost(creature.championId,spellId,creature.affinities)<=creature.maxFlux);
  }
  assert.equal(new Set(creature.loadout).size,creature.loadout.length);
  assert.ok(creatureAbilitySummary(creature.id).includes(getSpell(creature.loadout[0]).name));
 }
 assert.throws(()=>getCreature('oh_tipi'));assert.throws(()=>validateCreatureId({id:CREATURES[0].id}));assert.throws(()=>validateCreatureId('invented'));
});

test('bonds require a different nearby living companion and each entry produces an actual bounded benefit',()=>{
 assert.equal(CREATURE_BOND_RADIUS,2);assert.equal(CREATURE_PERKS.length,69);
 const neutral={heal:0,flux:0,ward:0,haste:0,clarity:false,perkIds:[]};
 for(const creature of CREATURES){
  assert.deepEqual(teamPerkEffects([creature.id]),neutral,'A composite cannot activate itself');
  const bond=getCreaturePerk(creature.perkId);assert.ok(bond.partnerElements.length>0);assert.ok(Object.values(bond.mechanics).some(Boolean));
  assert.ok(bond.description.includes('within 2 hexes of both creatures'));assert.ok(bond.description.includes('defeated companions grant nothing'));
  const partner=CREATURES.find(other=>other.id!==creature.id&&other.elements.some(element=>bond.partnerElements.includes(element)))!;
  assert.ok(teamPerkEffects([creature.id,partner.id]).perkIds.includes(bond.id),`${creature.name}'s documented partner activates its actual bond`);
 }
 assert.deepEqual(teamPerkEffects(['creature-fire-cinder','creature-water-puddle']),{heal:1,flux:1,ward:0,haste:0,clarity:false,perkIds:['kindling','warm-current']});
 assert.deepEqual(teamPerkEffects(['creature-fire-cinder','creature-earth-pebble']),neutral,'Having two companions alone does not promise a bond');
 assert.deepEqual(teamPerkEffects(['creature-fire-cinder']),neutral,'Filtering out the defeated or distant source immediately disables the pair');
});

test('every pair is order-independent, benefits never stack, and callers cannot mutate the catalog',()=>{
 for(const left of CREATURES)for(const right of CREATURES){
  const ids=[left.id,right.id],forward=teamPerkEffects(ids),reverse=teamPerkEffects([...ids].reverse());
  assert.deepEqual(forward,reverse);for(const key of ['heal','flux','ward','haste'] as const)assert.ok(forward[key]===0||forward[key]===1);
 }
 const repeated=teamPerkEffects(['creature-fire-cinder','creature-water-puddle','creature-fire-cinder','creature-water-puddle']);
 assert.deepEqual(repeated,teamPerkEffects(['creature-fire-cinder','creature-water-puddle']));
 assert.throws(()=>CREATURES[0].loadout.push('inferno'));assert.throws(()=>{CREATURES[0].affinities.fire=6;});assert.throws(()=>CREATURES[0].elements.push('dark'));
 assert.throws(()=>teamPerkEffects(['unknown']));assert.throws(()=>getCreaturePerk('unknown'));
});

