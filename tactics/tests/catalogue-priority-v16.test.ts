import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import ts from 'typescript';
import {CHAMPIONS} from '../lib/roster-v13.ts';
import {ALL_SPELLS,defaultLoadout,getSignature,spellAccess,validateLoadout} from '../lib/spells-v16.ts';

// Exercise the shipped client function against real rules, without a DOM mock.
const source=ts.createSourceFile('TacticsGame.tsx',readFileSync(new URL('../app/TacticsGame.tsx',import.meta.url),'utf8'),ts.ScriptTarget.Latest,true,ts.ScriptKind.TSX);
const declaration=source.statements.find(node=>ts.isFunctionDeclaration(node)&&node.name?.text==='orderSpellCatalogue');
assert.ok(declaration,'the current client catalogue sorter exists');
const js=ts.transpileModule(declaration.getText(source),{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.CommonJS}}).outputText;
const order=new Function('spellAccess','validateLoadout',`${js};return orderSpellCatalogue`)(spellAccess,validateLoadout) as (spells:typeof ALL_SPELLS,id:string,slot:number,kit:string[],allocation:typeof CHAMPIONS[number]['affinities'],learned:readonly string[])=>typeof ALL_SPELLS;

test('every starter character sees valid replacements before occupied or locked spells in each slot',()=>{
 for(const champion of CHAMPIONS){
  const kit=defaultLoadout(champion.id),choices=ALL_SPELLS.filter(spell=>spell.signatureChampionId!==champion.id);
  for(let slot=0;slot<4;slot++){
   const valid=choices.filter(spell=>{if(kit[slot]===spell.id)return false;try{validateLoadout(champion.id,kit.map((id,index)=>index===slot?spell.id:id),champion.affinities);return true}catch{return false}});
   const sorted=order(choices,champion.id,slot,kit,champion.affinities,[]);
   assert.deepEqual(sorted.slice(0,valid.length).map(spell=>spell.id),valid.map(spell=>spell.id),`${champion.id} slot ${slot+1}`);
   assert.equal(sorted[valid.length].id,kit[slot],'current spell follows valid replacements');
  }
 }
});

test('filters are preserved exactly, order is stable, and source catalogue and kit are untouched',()=>{
 const champion=CHAMPIONS[0],kit=defaultLoadout(champion.id),choices=ALL_SPELLS.filter(spell=>spell.element==='water'),before=choices.map(spell=>spell.id),beforeKit=[...kit];
 const sorted=order(choices,champion.id,1,kit,champion.affinities,[]);
 assert.deepEqual(new Set(sorted.map(spell=>spell.id)),new Set(before));
 assert.deepEqual(order(choices,champion.id,1,kit,champion.affinities,[]),sorted);
 assert.deepEqual(choices.map(spell=>spell.id),before);assert.deepEqual(kit,beforeKit);
 assert.deepEqual(order([],champion.id,1,kit,champion.affinities,[]),[]);
});

test('a learned signature enters the replacement group only when its complete affinity gate is met',()=>{
 const champion=CHAMPIONS[0],other=CHAMPIONS.find(entry=>entry.id!==champion.id&&getSignature(entry.id).element==='fire')!;
 const signature=getSignature(other.id),allocation={...champion.affinities,fire:5},kit=defaultLoadout(champion.id,allocation),choices=ALL_SPELLS.filter(spell=>spell.signatureChampionId!==champion.id);
 const locked=order(choices,champion.id,0,kit,allocation,[]),unlocked=order(choices,champion.id,0,kit,allocation,[signature.id]);
 assert.ok(locked.findIndex(spell=>spell.id===signature.id)>locked.findIndex(spell=>spell.id===kit[0]));
 assert.ok(unlocked.findIndex(spell=>spell.id===signature.id)<unlocked.findIndex(spell=>spell.id===kit[0]));
});
