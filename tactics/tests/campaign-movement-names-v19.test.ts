import test from 'node:test';
import assert from 'node:assert/strict';
import {createCampaignGame,readCampaignProfile,presentCampaign,CAMPAIGN_ENCOUNTERS} from '../lib/story-v19.ts';
import {projectAlliedMovement} from '../lib/movement-preview-v16.ts';

test('movement advice names the real hero and creatures, including contested followers',()=>{
 const profile=readCampaignProfile(null);profile.hero.name='Reed';
 const state=presentCampaign(createCampaignGame(profile,CAMPAIGN_ENCOUNTERS[0].id));
 state.cells=state.cells.map(cell=>({...cell,terrain:'plain',biome:'plain',height:0}));
 const [hero,puddle,cinder]=state.units.filter(unit=>unit.owner===0),rival=state.units.find(unit=>unit.owner===1)!;
 Object.assign(hero,{q:0,r:0});Object.assign(puddle,{q:1,r:0});Object.assign(cinder,{q:2,r:0});Object.assign(rival,{q:3,r:0,displayName:'River Keeper'});
 const blocked=projectAlliedMovement(state,0,{orders:[{unitId:hero.id,move:{q:1,r:0}}]});
 assert.match(blocked.get(hero.id)!.reason!,/^Puddle stays/);
 const sharing=projectAlliedMovement(state,0,{orders:[{unitId:hero.id,move:{q:4,r:0}},{unitId:cinder.id,move:{q:4,r:0}}]});
 assert.match(sharing.get(hero.id)!.reason!,/shared with Cinder/);
 const contested=projectAlliedMovement(state,0,{orders:[{unitId:hero.id,move:{q:3,r:0}},{unitId:puddle.id,move:{q:0,r:0}}]});
 assert.match(contested.get(hero.id)!.contestedReason!,/^River Keeper occupies/);
 assert.match(contested.get(puddle.id)!.contestedReason!,/^Depends on Reed leaving/);
});
