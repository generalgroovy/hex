import assert from 'node:assert/strict';
import test from 'node:test';
import {createSimGame} from '../lib/tactics-v17.ts';
import {presentArena,normalizeArenaCode,validArenaSession,arenaDraftKey,SEAT_COLORS} from '../lib/skirmish-client-v17.ts';

test('six-seat presentation preserves authoritative cells, units and events without collapsing enemy alliances into rules',()=>{
 const state=createSimGame({playerCount:6,mode:'teams',seed:'VIEW-TEST'});
 state.lastResolution=[{kind:'move',unitId:state.units[7].id,owner:2,text:'Moved',from:{q:0,r:0},to:{q:1,r:0}}];
 const original=structuredClone(state),view=presentArena(state,3);
 assert.equal(view.rulesVersion,16);assert.equal(view.units.length,18);assert.equal(view.cells.length,state.cells.length);
 assert.deepEqual(view.units.filter(unit=>unit.owner===0).map(unit=>unit.id).sort(),state.units.filter(unit=>[1,3,5].includes(unit.owner)).map(unit=>unit.id).sort());
 assert.equal(view.lastResolution[0].owner,1);assert.deepEqual(state,original);
 state.winner=1;assert.equal(presentArena(state,3).winner,0);assert.equal(presentArena(state,2).winner,1);
});
test('free-for-all seats retain their complete company and have five distinct rival colors',()=>{
 const state=createSimGame({playerCount:6,mode:'free-for-all',seed:'SIX-SIDES'});
 for(let seat=0;seat<6;seat++){const view=presentArena(state,seat as 0|1|2|3|4|5);assert.equal(view.units.filter(unit=>unit.owner===0).length,3);assert.equal(view.units.filter(unit=>unit.owner===1).length,15);}
 assert.equal(new Set(SEAT_COLORS).size,6);
});
test('invitation links and per-match draft identities do not mix player keys or rounds',()=>{
 assert.equal(normalizeArenaCode('https://example.test/skirmish?room=ABCD1234EFGH'),'ABCD1234EFGH');
 assert.equal(normalizeArenaCode('abcd 1234 efgh'),'ABCD1234EFGH');
 assert.equal(normalizeArenaCode('https://example.test/skirmish'),'');
 const session={code:'ABCD1234EFGH',token:'a'.repeat(64),seat:5};assert.equal(validArenaSession(session,'ABCD1234EFGH'),true);assert.equal(validArenaSession({...session,seat:6}),false);assert.equal(validArenaSession(session,'DIFFERENT'),false);
 assert.notEqual(arenaDraftKey({code:'ROOM',matchId:'one'},1),arenaDraftKey({code:'ROOM',matchId:'two'},1));assert.notEqual(arenaDraftKey({code:'ROOM',matchId:'one'},1),arenaDraftKey({code:'ROOM',matchId:'one'},2));
});
