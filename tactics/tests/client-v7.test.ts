import test from 'node:test';
import assert from 'node:assert/strict';
import {createClientSessionStore} from '../lib/client-session-v7.ts';
import {createClientSessionStore as legacyClient} from '../lib/client-session.ts';
import {createSimGame, legalCasts} from '../lib/tactics-v7.ts';
import {createSimGame as oldGame} from '../lib/tactics.ts';
import {getSignature, defaultLoadout} from '../lib/spells-v7.ts';
import {gameShortcut} from '../lib/input-v7.ts';
import {readLoadouts} from '../lib/loadouts-v7.ts';

test('signature drafts survive reload without overwriting old-version orders or player keys',()=>{
 const values=new Map<string,string>();
 const storage={getItem:(key:string)=>values.get(key)??null,setItem:(key:string,value:string)=>{values.set(key,value)},removeItem:(key:string)=>{values.delete(key)}};
 const code='23456789ABCD',matchId='12345678-1234-1234-1234-123456789abc',seat=0 as const;
 const old=legacyClient([{kind:'local',storage}]);
 old.rememberSeat({code,seat,token:'a'.repeat(64)});
 const oldState=oldGame(),oldPlan={orders:[{unitId:oldState.units[0].id,guard:true}]};
 old.saveDraft({code,matchId,state:oldState,seat,plan:oldPlan});
 const oldBytes=values.get(`confluence-draft-${code}`);
 const state=createSimGame(),unit=state.units.find(u=>u.owner===0)!;
 const signature=getSignature(unit.championId);
 const target=legalCasts(state,unit.id,unit,signature.id)[0];assert.ok(target);
 const plan={orders:[{unitId:unit.id,spellId:signature.id,cast:{q:target.q,r:target.r}}]};
 const current=createClientSessionStore([{kind:'local',storage}]);
 assert.deepEqual(current.readSeat(code),{code,seat,token:'a'.repeat(64)});
 current.saveDraft({code,matchId,state,seat,plan});
 const reload=createClientSessionStore([{kind:'local',storage}]);
 assert.deepEqual(reload.readDraft({code,matchId,state,seat}),plan);
 assert.equal(reload.readDraft({code,matchId,state:{...state,round:state.round+1},seat}),null);
 current.clearDraft(code);
 assert.equal(values.get(`confluence-draft-${code}`),oldBytes);
 assert.deepEqual(old.readDraft({code,matchId,state:oldState,seat}),oldPlan);
});

test('signature shortcut works without intercepting number entry or browser shortcuts',()=>{
 assert.equal(gameShortcut({key:'5'}),'spell5');
 for(const target of [{tagName:'INPUT'},{tagName:'TEXTAREA'},{tagName:'SELECT'},{isContentEditable:true}])assert.equal(gameShortcut({key:'5',target}),null);
 assert.equal(gameShortcut({key:'5',ctrlKey:true}),null);
 assert.equal(gameShortcut({key:'5',repeat:true}),null);
 assert.equal(gameShortcut({key:'6'}),null);
});

test('custom ordinary kits carry into four-affinity rules; forged signature slots recover independently',()=>{
 const custom=['ember','vacuum','aegis','reap'];
 const result=readLoadouts({oh_tipi:custom,wa_bidi:[getSignature('wa_bidi').id,'gust','stone','mend']});
 assert.deepEqual(result.oh_tipi,custom);
 assert.deepEqual(result.wa_bidi,defaultLoadout('wa_bidi'));
});
