import test from 'node:test';
import assert from 'node:assert/strict';
import {prepareTowerEntry,acknowledgeTowerEntry,preservesTowerEditor} from '../lib/tower-client-v22.ts';
import type {CampaignStorage} from '../lib/campaign-storage-v20.ts';
import type {TowerRoomSnapshot} from '../lib/tower-rooms-v22.ts';

function storage(blocked=false):CampaignStorage{const data=new Map<string,string>();return {getItem:key=>data.get(key)??null,setItem:(key,value)=>{if(blocked)throw new Error('Storage unavailable');data.set(key,value)},removeItem:key=>{data.delete(key)}};}
test('unknown create outcome retries the same seat key, acknowledged creation starts a fresh climb',()=>{
 for(const blocked of [false,true]){const local=storage(blocked),session=storage();let issued=0;const fresh=()=>String(++issued).repeat(64);
  const first=prepareTowerEntry('same form',fresh,local,session);assert.equal(first,'1'.repeat(64));
  assert.equal(prepareTowerEntry('same form',fresh,local,session),first);assert.equal(issued,1);
  acknowledgeTowerEntry(local,session);
  assert.equal(prepareTowerEntry('same form',fresh,local,session),'2'.repeat(64));assert.equal(issued,2);
  assert.equal(prepareTowerEntry('different form',fresh,local,session),'3'.repeat(64));
 }
});
test('a partner build save preserves the current route editor; entering a room or another climb closes it',()=>{
 const snapshot=(phase:string,floor=1,runId='run')=>({code:'ROOM',runId,session:{run:{phase,floor}}}) as TowerRoomSnapshot;
 assert.equal(preservesTowerEditor(snapshot('route'),snapshot('route')),true);
 for(const next of [snapshot('battle'),snapshot('reward'),snapshot('route',2),snapshot('route',1,'other')])assert.equal(preservesTowerEditor(snapshot('route'),next),false);
 assert.equal(preservesTowerEditor(null,snapshot('route')),false);
});
