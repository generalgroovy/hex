import assert from 'node:assert/strict';
import test from 'node:test';
import {createSimGame,type Seat,type TeamPlan} from '../lib/tactics-v18.ts';
import {endgameForecast} from '../lib/endgame-v18.ts';
import {companyOrderSummary,nextCompanyAction,opponentGroups,landingBoundaryNote,frontierReadout,legacyArenaUrl} from '../lib/skirmish-ui-v18.ts';
import {presentArena,arenaDraftKey,normalizeArenaCode,type ArenaPlayer} from '../lib/skirmish-client-v18.ts';
import {arenaDraftKey as legacyDraftKey} from '../lib/skirmish-client-v17.ts';

test('order readouts distinguish movement from a completed action and cycle only through living own characters',()=>{
 const state=createSimGame({playerCount:6,mode:'teams',seed:'UI-ORDERS'}),own=state.units.filter(unit=>unit.owner===3);
 const plan:TeamPlan={orders:[{unitId:own[0].id,guard:true},{unitId:own[1].id,move:{q:0,r:0}},{unitId:own[2].id,spellId:own[2].loadout[0],cast:{q:0,r:0}}]};
 const summary=companyOrderSummary(state,3,plan);
 assert.deepEqual(summary.map(entry=>entry.ready),[true,false,true]);
 assert.equal(summary[0].action,'Guard');assert.equal(summary[1].action,'Choose action');assert.match(summary[1].movement,/^Move /);
 assert.equal(nextCompanyAction(state,3,plan,own[0].id),own[1].id);
 own[1].hp=0;assert.equal(nextCompanyAction(state,3,plan,own[0].id),own[2].id);
 assert.equal(companyOrderSummary(state,3,plan)[1].label,'Defeated');
 own.forEach(unit=>unit.hp=0);assert.equal(nextCompanyAction(state,3,plan,own[0].id),null);
});

test('team company groups expose public allegiance and put defeated seats last without mixing the acting company',()=>{
 const state=createSimGame({playerCount:6,mode:'teams',seed:'UI-TEAMS'});
 const players:ArenaPlayer[]=Array.from({length:6},(_,seat)=>({seat:seat as Seat,name:`Player ${seat+1}`,characters:[],team:state.teams[seat]}));
 state.units.filter(unit=>unit.owner===0).forEach(unit=>unit.hp=0);
 const groups=opponentGroups({players,mode:'teams'},state,3);
 assert.deepEqual(groups.map(group=>group.id),['allies','enemies']);
 assert.deepEqual(groups[0].players.map(player=>player.seat),[1,5]);
 assert.deepEqual(groups[1].players.map(player=>player.seat),[2,4,0]);
 assert.equal(groups.flatMap(group=>group.players).some(player=>player.seat===3),false);
 assert.equal(opponentGroups({players,mode:'free-for-all'},state,3)[0].players.length,5);
});

test('landing warnings name actual damage now and the next scheduled closure, including the two-round gap',()=>{
 for(const playerCount of [2,6] as const){
  const base=createSimGame({playerCount,seed:'UI-BOUNDARY'}),first=playerCount+8,radius=base.boardRadius;
  assert.equal(landingBoundaryNote({...base,round:first-3},{q:radius,r:0}),null);
  const warning=landingBoundaryNote({...base,round:first-2},{q:radius,r:0});
  assert.deepEqual(warning&&{severity:warning.severity,damage:warning.damage,round:warning.round},{severity:'future',damage:1,round:first});
  const current=landingBoundaryNote({...base,round:first},{q:radius,r:0});
  assert.deepEqual(current&&{severity:current.severity,damage:current.damage,round:current.round},{severity:'danger',damage:1,round:first});
  const next=landingBoundaryNote({...base,round:first},{q:radius-2,r:0});
  assert.equal(next?.severity,'future');assert.equal(next?.round,first+2);assert.equal(next?.damage,2);
  assert.equal(landingBoundaryNote({...base,round:first},{q:0,r:0}),null);
 }
});

test('frontier readout is quiet before warning and accurate for each current boundary and the final centre',()=>{
 const state=createSimGame({playerCount:2,seed:'UI-FRONTIER'});
 assert.equal(frontierReadout(endgameForecast(state)),null);
 assert.match(frontierReadout(endgameForecast({...state,round:8}))!.title,/starts round 10/);
 const closing=frontierReadout(endgameForecast({...state,round:10}))!;
 assert.match(closing.title,/1 damage/);assert.match(closing.detail,/next closure round 12/);
 assert.deepEqual(frontierReadout(endgameForecast({...state,round:18})),{title:'Centre only',detail:'8 damage outside after spells'});
});

test('presentation keeps every seat, the collapse event and original data intact without running legacy rules',()=>{
 const state=createSimGame({playerCount:6,mode:'teams',seed:'UI-PROJECTION'});
 state.lastResolution=[{kind:'damage',cause:'collapse',unitId:state.units[7].id,owner:2,q:3,r:0,amount:2,text:'Closing ground'}];
 const original=structuredClone(state),view=presentArena(state,3);
 assert.equal(view.rulesVersion,16);assert.equal(view.units.length,18);assert.equal(view.cells.length,state.cells.length);
 assert.equal(view.units.filter(unit=>unit.owner===0).length,9);
 assert.deepEqual(view.lastResolution[0],{...state.lastResolution[0],owner:1});assert.deepEqual(state,original);
 state.winner=1;assert.equal(presentArena(state,3).winner,0);assert.equal(presentArena(state,2).winner,1);
});

test('new drafts cannot overwrite legacy plans and legacy room routing keeps the exact invitation identity',()=>{
 const identity={code:'ABCD1234EFGH',matchId:'same-match'};
 assert.notEqual(arenaDraftKey(identity,1),legacyDraftKey(identity,1));
 assert.notEqual(arenaDraftKey(identity,1),arenaDraftKey(identity,2));
 assert.equal(normalizeArenaCode('https://example.test/skirmish?room=ABCD1234EFGH'),identity.code);
 assert.equal(legacyArenaUrl(identity.code),'/skirmish/legacy?room=ABCD1234EFGH');
 assert.equal(legacyArenaUrl('CODE&other=1'),'/skirmish/legacy?room=CODE%26other%3D1');
});
