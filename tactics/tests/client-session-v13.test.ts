import assert from 'node:assert/strict';
import test from 'node:test';
import {createClientSessionStore} from '../lib/client-session-v13.ts';
import {createSimGame} from '../lib/tactics-v13.ts';
import {canonicalPlan} from '../lib/room-plans.ts';

test('v12 drafts retain fixed kits, reject mutations, and leave historical drafts intact',()=>{
 const entries=new Map<string,string>();
 const storage={getItem:(key:string)=>entries.get(key)??null,setItem:(key:string,value:string)=>{entries.set(key,value)},removeItem:(key:string)=>{entries.delete(key)}};
 const context={code:'23456789ABCD',matchId:'12345678-1234-1234-1234-123456789abc',seat:0 as const,state:createSimGame()};
 const unit=context.state.units[0],plan={orders:[{unitId:unit.id,guard:true as const}]};
 storage.setItem(`confluence-draft-v11-${context.code}`,'old draft');
 const store=createClientSessionStore([{kind:'local',storage}]);
 assert.equal(store.saveDraft({...context,plan}),'local');
 assert.deepEqual(createClientSessionStore([{kind:'local',storage}]).readDraft(context),plan);
 assert.throws(()=>store.saveDraft({...context,plan:{orders:[],loadouts:[{unitId:unit.id,spells:unit.loadout}]}}),/fixed|camp/i);
 assert.throws(()=>canonicalPlan({orders:[],loadouts:[{unitId:unit.id,spells:unit.loadout}]},12),/fixed/);
 assert.doesNotThrow(()=>canonicalPlan({orders:[],loadouts:[{unitId:unit.id,spells:unit.loadout}]},11));
 assert.equal(store.readDraft({...context,state:{...context.state,round:2}}),null);
 store.clearDraft(context.code);assert.equal(store.readDraft(context),null);
 assert.equal(storage.getItem(`confluence-draft-v11-${context.code}`),'old draft');
});
