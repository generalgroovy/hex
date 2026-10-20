/** Deterministic bot diagnostic. Not evidence of human enjoyment or win rates. */
import {createHash} from 'node:crypto';
import {readFileSync,writeFileSync} from 'node:fs';
import {TOWER_SOLO_STARTERS,createTowerRun,towerRoomChoices,chooseTowerRoom,towerBattleConfig} from '../lib/tower-v23.ts';
import {createTowerBattle,chooseAIPlan,resolveRound,restoreSimState,validatePlan} from '../lib/tactics-v22.ts';
import {enemyThreatPreview} from '../lib/enemy-threat-v42.ts';
import * as rules from '../lib/tactics-v22.ts';
const seeds=['FOCUS42-A','FOCUS42-B'];
const results=[];
for(const seed of seeds)for(const starter of TOWER_SOLO_STARTERS){
  const run=createTowerRun(seed,starter.id),room=towerRoomChoices(run).find(room=>room.kind==='combat')??towerRoomChoices(run)[0];
  const entered=chooseTowerRoom(run,room.id);
  let state=createTowerBattle(towerBattleConfig(entered)),rounds=0,crits=0,clashes=0,ms=0;
  while(state.winner===null&&rounds<16){
    const began=performance.now();
    const plans=[chooseAIPlan(state,0),chooseAIPlan(state,1)];
    ms+=performance.now()-began;
    plans.forEach((plan,seat)=>validatePlan(state,seat,plan));
    state=resolveRound(state,plans);
    restoreSimState(JSON.parse(JSON.stringify(state)));
    crits+=state.lastResolution.filter(event=>event.critical).length;
    clashes+=state.lastResolution.filter(event=>event.kind==='clash').length;
    rounds++;
  }
  if(state.winner===null)throw new Error(`${starter.id}/${seed} did not terminate`);
  const result={seed,starter:starter.heroId,room:room.kind,rounds,winner:state.winner,critEvents:crits,clashes,allyHp:state.units.filter(unit=>unit.owner===0).reduce((sum,unit)=>sum+unit.hp,0),aiMs:Math.round(ms)};
  results.push(result);console.log(JSON.stringify(result));
}
const state=createTowerBattle(towerBattleConfig(chooseTowerRoom(createTowerRun('THREAT42','steam'),'floor-1-0')));
const times=[];
for(const unit of state.units.filter(unit=>unit.owner===1)){
  const start=performance.now(),preview=enemyThreatPreview(state,unit.id,{...rules,spellGeometry:rules.battleSpell});
  times.push({id:unit.id,ms:Math.round(performance.now()-start),move:preview.move.length,attack:preview.attack.length});
}
const report={
  created:new Date().toISOString(),spellModel:'focused',
  sourceSha256:Object.fromEntries(['lib/tactics-v22.ts','lib/spell-profile-v42.ts','lib/tower-v23.ts','lib/enemy-threat-v42.ts'].map(path=>[path,createHash('sha256').update(readFileSync(new URL(`../${path}`,import.meta.url))).digest('hex')])),
  limits:'Fourteen deterministic opening encounters across seven suggested starters and two seeds. Both sides use current AI. This checks legality, replay restoration and bounded pacing; it does not establish human balance, win rates, long-run reward balance, or commercial appeal.',
  results,threatTiming:times,
  summary:{battles:results.length,minimumRounds:Math.min(...results.map(result=>result.rounds)),maximumRounds:Math.max(...results.map(result=>result.rounds)),medianRounds:[...results].sort((a,b)=>a.rounds-b.rounds)[Math.floor(results.length/2)].rounds,alliesWon:results.filter(result=>result.winner===0).length,enemiesWon:results.filter(result=>result.winner===1).length,draws:results.filter(result=>result.winner==='draw').length}
};
writeFileSync(new URL('../../../work/hex42-pacing.json',import.meta.url),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report.summary));
