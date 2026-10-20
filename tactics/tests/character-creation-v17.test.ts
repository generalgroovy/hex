import assert from 'node:assert/strict';
import test from 'node:test';
import {CHAMPIONS} from '../lib/roster-v13.ts';
import {canonicalBuild,validateCharacterBuild,validateCompany} from '../lib/character-creation-v17.ts';
import {defaultLoadout} from '../lib/spells-v16.ts';
test('all thirty appearances enter with the same five-point budget and four legal spells',()=>{
 for(const hero of CHAMPIONS){const c=canonicalBuild(hero.id);assert.deepEqual(validateCharacterBuild(c),c);assert.equal(Object.values(c.affinities).reduce((a,b)=>a+(b??0),0),5);assert.equal(new Set(c.loadout).size,4);}
});
test('custom affinity choices change the available kit but never grant extra stats or free signature elements',()=>{
 const c=canonicalBuild('oh_tipi'),affinities={water:3,dark:2} as const;
 const custom=validateCharacterBuild({...c,name:'  Estuary  ',affinities,loadout:defaultLoadout(c.championId,affinities,[])});assert.equal(custom.name,'Estuary');assert.deepEqual(custom.affinities,affinities);
 for(const bad of [{water:4,fire:1},{water:3,fire:3},{water:1,dark:3,fire:1},{water:2,fire:1,earth:1,air:1},{water:3},{water:3,dark:-1}])assert.throws(()=>validateCharacterBuild({...c,affinities:bad}));
 assert.throws(()=>validateCharacterBuild({...c,hp:99}));assert.throws(()=>validateCharacterBuild({...c,loadout:Array(4).fill(c.loadout[0])}));
});
test('a company has three distinct appearances and fifteen affinity points',()=>{
 const team=['oh_tipi','wa_bidi','treevor_mason'].map(canonicalBuild);assert.equal(validateCompany(team).length,3);assert.throws(()=>validateCompany([...team.slice(0,2),team[0]]));assert.throws(()=>validateCompany(team.slice(0,2)));
});
