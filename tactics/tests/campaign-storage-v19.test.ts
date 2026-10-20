import assert from 'node:assert/strict';
import test from 'node:test';
import {readCampaignStorage,writeCampaignStorage,type CampaignStorage} from '../lib/campaign-storage-v19.ts';
function memory():CampaignStorage{const entries=new Map<string,string>();return {getItem:key=>entries.get(key)??null,setItem:(key,value)=>{entries.set(key,value)},removeItem:key=>{entries.delete(key)}}}
test('a successful session fallback wins over stale local progress, then clears on local recovery',()=>{
 const local=memory(),session=memory();local.setItem('profile','before');
 const full={...local,setItem(){throw new Error('Quota exceeded')}};
 assert.equal(writeCampaignStorage('profile','victory',full,session),true);
 assert.equal(readCampaignStorage('profile',local,session),'victory');
 assert.equal(writeCampaignStorage('profile','trained',local,session),true);
 assert.equal(session.getItem('profile'),null);assert.equal(readCampaignStorage('profile',local,session),'trained');
});
test('storage failures preserve old data and report a failure instead of claiming persistence',()=>{
 const broken:CampaignStorage={getItem(){throw Error('blocked')},setItem(){throw Error('blocked')},removeItem(){throw Error('blocked')}};
 assert.equal(writeCampaignStorage('profile','new',broken,broken),false);
 assert.equal(readCampaignStorage('profile',broken,broken),null);
});
