import {writeFileSync,mkdirSync} from 'node:fs';
import {dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createTowerRun,chooseTowerRoom,towerBattleConfig} from '../lib/tower-v23.ts';
import {canonicalBuild} from '../lib/character-creation-v17.ts';
import {createTowerBattle,chooseAIPlan,resolveRound,restoreSimState} from '../lib/tactics-v22.ts';
import {CURRENT_SPELL_MODEL} from '../lib/spell-profile-v42.ts';
const output=process.argv[2]??fileURLToPath(new URL('../work/balance-v44-final.json',import.meta.url));
mkdirSync(dirname(output),{recursive:true});
const results=[],seed='FOCUS42-B';
const cases=['steam','dusk','baron','steezo','stone','oll_i','wa_bidi',{starterId:'steam',members:['oh_tipi','steezo'].map(championId=>({kind:'champion',build:canonicalBuild(championId)}))}];
for(const starter of cases){
 const label=typeof starter==='string'?starter:'custom-two-champions';
 const initial=createTowerBattle(towerBattleConfig(chooseTowerRoom(createTowerRun(seed,starter),'floor-1-0')));
 for(const model of [CURRENT_SPELL_MODEL]){
  let s=structuredClone(initial);s.spellModel=model;const rounds=[],times=[];
  while(s.winner===null&&s.round<17){
   const start=performance.now(),plans=[chooseAIPlan(s,0),chooseAIPlan(s,1)],ms=performance.now()-start;times.push(ms);
   const n=resolveRound(s,plans);restoreSimState(n);
   rounds.push({round:s.round,plans,ms,events:n.lastResolution.filter(e=>['cast','clash','damage','heal','defeat','fizzle'].includes(e.kind)),hp:n.units.map(u=>[u.id,u.hp])});s=n;
  }
  const item={starter:label,seed,mapId:initial.mapId,model,winner:s.winner,rounds,meanPlanningMs:times.reduce((a,b)=>a+b,0)/times.length,maxPlanningMs:Math.max(...times),collapseDamage:rounds.flatMap(r=>r.events).filter(e=>e.cause==='collapse').reduce((sum,e)=>sum+e.amount,0)};results.push(item);
  writeFileSync(output,JSON.stringify({scope:'Eight final native AI diagnostics on one seed; not human balance evidence',results},null,2));
  console.log(JSON.stringify({starter:label,model,winner:s.winner,rounds:rounds.length,collapseDamage:item.collapseDamage,meanPlanningMs:Math.round(item.meanPlanningMs),maxPlanningMs:Math.round(item.maxPlanningMs)}));
 }
}

