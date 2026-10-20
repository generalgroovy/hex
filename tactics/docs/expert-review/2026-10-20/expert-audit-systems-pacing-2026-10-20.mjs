import {writeFileSync} from 'node:fs';
import {createTowerRun,chooseTowerRoom,towerBattleConfig} from '../../../lib/tower-v23.ts';
import {createTowerBattle,chooseAIPlan,resolveRound} from '../../../lib/tactics-v22.ts';
const results=[];
for(const starter of ['stone','steezo']){
 let s=createTowerBattle(towerBattleConfig(chooseTowerRoom(createTowerRun('FOCUS42-B',starter),'floor-1-0')));const rounds=[];
 while(s.winner===null&&s.round<17){const plans=[chooseAIPlan(s,0),chooseAIPlan(s,1)],n=resolveRound(s,plans);rounds.push({round:s.round,plans,casts:n.lastResolution.filter(x=>x.kind==='cast').length,damage:n.lastResolution.filter(x=>x.kind==='damage').map(({unitId,amount,cause})=>({unitId,amount,cause:cause??'exchange'})),defeated:n.lastResolution.filter(x=>x.kind==='defeat').map(x=>x.unitId),hp:n.units.map(x=>[x.id,x.hp])});s=n;}
 results.push({starter,seed:'FOCUS42-B',winner:s.winner,rounds});
}
if (process.env.HEX_AUDIT_OUTPUT) writeFileSync(process.env.HEX_AUDIT_OUTPUT,JSON.stringify(results,null,2));console.log(JSON.stringify(results.map(x=>({starter:x.starter,winner:x.winner,rounds:x.rounds.length,collapseDamage:x.rounds.flatMap(y=>y.damage).filter(d=>d.cause==='collapse').reduce((s,d)=>s+d.amount,0),final:x.rounds.at(-1)})),null,2));
