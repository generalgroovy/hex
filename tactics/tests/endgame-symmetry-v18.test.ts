import test from 'node:test';
import assert from 'node:assert/strict';
import {createSimGame,resolveRound,type SimState,type Player,type PlayerCount,type TeamPlan} from '../lib/tactics-v18.ts';
import {endgameForecast,collapseDamageAt,endgamePositionValue} from '../lib/endgame-v18.ts';
import {arenaStarts} from '../lib/arena-v17.ts';
import type {Point} from '../lib/game.ts';

const rotate=(point:Point,turns:number):Point=>{let {q,r}=point;for(let i=0;i<turns;i++)[q,r]=[-r,q+r];return {q:q||0,r:r||0};};
const guards=(count:number):TeamPlan[]=>Array.from({length:count},()=>({orders:[]}));
const kill=(unit:SimState['units'][number])=>{unit.hp=0;unit.flux=0;unit.statuses={};unit.cooldowns={};delete unit.guard;};

test('every hex direction and deployment seat receives equal collapse timing and public bot exposure utility',()=>{
  for(const playerCount of [2,3,4,5,6] as PlayerCount[]){
    const state=createSimGame({playerCount}),camps=arenaStarts(state.mapId),zone=endgameForecast(state);
    for(let round=zone.firstClosureRound-2;round<=zone.finalRound;round++){
      const at={...state,round};
      const exposure=camps.map(camp=>camp.map(point=>collapseDamageAt(at,point)));
      for(const seat of exposure)assert.deepEqual(seat,exposure[0]);
      for(const point of state.cells){
        const damage=collapseDamageAt(at,point),utility=endgamePositionValue(at,point,4);
        for(let turns=0;turns<6;turns++){
          const moved=rotate(point,turns),reflected={q:moved.r,r:moved.q};
          assert.equal(collapseDamageAt(at,moved),damage);assert.equal(collapseDamageAt(at,reflected),damage);
          assert.equal(endgamePositionValue(at,moved,4),utility);assert.equal(endgamePositionValue(at,reflected,4),utility);
        }
      }
    }
  }
});

test('six contested centre landings bounce and perish together under every rotation and cyclic seat numbering',()=>{
  const directions=[{q:1,r:0},{q:1,r:-1},{q:0,r:-1},{q:-1,r:0},{q:-1,r:1},{q:0,r:1}];
  for(let turns=0;turns<6;turns++)for(let offset=0;offset<6;offset++){
    const state=createSimGame({playerCount:6});state.round=26;state.version=26;
    state.cells=state.cells.map(({q,r,well})=>({q,r,well,terrain:'plain',height:0,biome:'plain'}));
    const plans=guards(6);
    for(let seat=0;seat<6;seat++){
      const owner=(seat+offset)%6 as Player,unit=state.units.find(unit=>unit.owner===owner)!;
      state.units.filter(other=>other.owner===owner&&other.id!==unit.id).forEach(kill);
      Object.assign(unit,rotate(directions[seat],turns));
      plans[owner]={orders:[{unitId:unit.id,move:{q:0,r:0},guard:true}]};
    }
    state.units.reverse();
    const result=resolveRound(state,plans);
    assert.equal(result.winner,'draw');assert.equal(result.units.filter(unit=>unit.hp>0).length,0);
    assert.equal(result.lastResolution.filter(event=>event.kind==='bounce').length,6);
    assert.equal(result.lastResolution.filter(event=>event.kind==='defeat').length,6);
    assert.equal(result.lastResolution.filter(event=>event.cause==='collapse').length,6);
  }
});

test('holding the final centre awards exactly that seat or its team regardless of processing order',()=>{
  for(const mode of ['free-for-all','teams'] as const)for(let seat=0;seat<6;seat++){
    const state=createSimGame({playerCount:6,mode});state.round=26;state.version=26;
    const holder=state.units.find(unit=>unit.owner===seat)!;Object.assign(holder,{q:0,r:0});
    state.units.reverse();
    const result=resolveRound(state,guards(6));
    assert.equal(result.winner,state.teams[seat]);assert.deepEqual(result.units.filter(unit=>unit.hp>0).map(unit=>unit.id),[holder.id]);
    assert.equal(result.lastResolution.filter(event=>event.kind==='defeat').length,17);
    assert.equal(new Set(result.lastResolution.filter(event=>event.kind==='defeat').map(event=>event.unitId)).size,17);
  }
});
