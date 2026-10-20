import test from 'node:test';
import assert from 'node:assert/strict';
import {readCampaignProfile,validateCampaignProfile,createCampaignGame,restoreCampaignGame} from '../lib/story-v19.ts';
import {canonicalBuild} from '../lib/character-creation-v17.ts';
import {chooseAIPlan,validatePlan,resolveRound} from '../lib/tactics-v19.ts';

test('the default starting party has a deterministic legal winning path through the opening',()=>{
 let state=createCampaignGame(readCampaignProfile(null),'oh_tipi'),rounds=0;
 while(state.winner===null&&rounds++<18){
  const plans=([0,1] as const).map(owner=>validatePlan(state,owner,chooseAIPlan(state,owner)));
  state=resolveRound(state,plans);assert.deepEqual(restoreCampaignGame(state),state);
 }
 assert.equal(state.winner,0);assert.ok(state.units.some(unit=>unit.owner===0&&unit.hp>0));
});

test('the familiar party can defeat the unchanged second encounter with one earned point and one new spell',()=>{
 const profile=validateCampaignProfile({...readCampaignProfile(null),defeated:['oh_tipi'],hero:{...canonicalBuild('oh_tipi'),affinities:{water:4,fire:2},loadout:['water_jet','tidal_surge','ember','cleansing_tide']}});
 let state=createCampaignGame(profile,'s_wayne'),rounds=0;
 while(state.winner===null&&rounds++<18){
  const plans=([0,1] as const).map(owner=>validatePlan(state,owner,chooseAIPlan(state,owner)));
  state=resolveRound(state,plans);assert.deepEqual(restoreCampaignGame(state),state);
 }
 assert.equal(state.winner,0);assert.ok(state.units.some(unit=>unit.owner===0&&unit.hp>0));
});
