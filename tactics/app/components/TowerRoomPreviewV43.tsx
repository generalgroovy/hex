"use client";

import type {TowerActor,TowerRoom,TowerRun} from '../../lib/tower-v23';
import {towerTuitionActor} from '../../lib/tower-v23';
import {towerRoomIntel} from '../../lib/tower-scouting';
import {towerScoutOptions,towerScoutReports,towerScoutsAvailable,type ScoutReport} from '../../lib/tower-scouting-actions';
import {getChampion} from '../../lib/roster-v13';
import {getCreature} from '../../lib/campaign-creatures-v20';
import ElementIcon from './ElementIcon';
import PixelChampion from './PixelChampion';
import CombatCreature from './CombatCreatureV19';
import './tower-room-preview-v43.css';

export type TowerRoomPreviewProps={
 room:TowerRoom;
 run:TowerRun;
 onChoose:(roomId:string)=>void;
 onScout?:(actorId:string,roomId:string)=>void;
 scoutReports?:readonly ScoutReport[];
 cooperative?:boolean;
 actionLabel?:string;
 disabled?:boolean;
 chosen?:boolean;
 scoutingLocked?:boolean;
 encounterCount?:number;
 partyNames?:readonly string[];
};
const actorName=(actor:TowerActor)=>actor.displayName??(actor.creatureId?getCreature(actor.creatureId).name:getChampion(actor.championId).name);
function Portrait({actor,size=40}:{actor:Pick<TowerActor,'championId'|'creatureId'>;size?:number}){
 return actor.creatureId?<CombatCreature creatureId={actor.creatureId} size={size}/>:<PixelChampion id={actor.championId} size={size} paused/>;
}
function KnownFact({report}:{report:ScoutReport}){
 return <span className="trp43-fact" data-fact={report.kind} title={report.label}>
  {report.element&&<ElementIcon element={report.element} size={16}/>}
  {report.detail}
 </span>;
}

/** Room decisions receive only the baseline projection and canonical earned reports. */
export default function TowerRoomPreviewV43({room,run,onChoose,onScout,scoutReports=[],cooperative=false,actionLabel,disabled=false,chosen=false,scoutingLocked=false,encounterCount,partyNames=[]}:TowerRoomPreviewProps){
 const intel=towerRoomIntel(room),reports=towerScoutReports(run,room.id,scoutReports),options=towerScoutOptions(run,room.id,scoutReports);
 const scouts=towerScoutsAvailable(run),available=new Set(scouts.map(actor=>actor.id)),champions=run.party.filter(actor=>!actor.creatureId);
 const service=intel.profile==='service',payer=towerTuitionActor(run),event=room.kind==='event',canPay=!event||payer.hp>=3;
 const count=encounterCount??intel.enemyCount;
 const knownEnemies=room.enemies.flatMap((enemy,index)=>{
  const facts=reports.filter(report=>report.enemyId===enemy.id),baseline=intel.knownEnemy?.enemyId===enemy.id;
  const identity=baseline||facts.some(report=>report.kind==='identity');
  return baseline||facts.length?[{enemy,index,identity,facts}]:[];
 });
 const ground=reports.find(report=>report.kind==='environment');
 const baselineClues=intel.clues.filter(clue=>clue.label!=='Spotted'&&!(event&&clue.label==='Cost'));
 const primaryLabel=chosen?'Destination chosen':!canPay?'Requires 3 HP':actionLabel??(cooperative?'Choose room':'Enter room');
 return <article className="trp43" data-kind={room.floor===9?'boss':room.kind} data-chosen={chosen} aria-label={`${room.name} room preview`}>
  <header className="trp43-heading">
   <div><span className="trp43-kind">{intel.risk}</span><h3>{room.name}</h3></div>
   {chosen?<strong className="trp43-selection">Your destination</strong>:scoutingLocked?<span className="trp43-selection" data-preview="true">Preview</span>:null}
  </header>
  {!!partyNames.length&&<p className="trp43-together"><strong>Together</strong><span>{partyNames.join(' · ')}</span></p>}
  {!service&&<div className="trp43-threats">
   <div className="trp43-section-label"><strong>{count} {count===1?'enemy':'enemies'}</strong>{cooperative&&<span title="Squads choosing the same room fight together. Each squad brings its own foes.">{encounterCount===undefined?'Your squad’s foes':'Combined encounter'}</span>}</div>
   {!!knownEnemies.length&&<div className="trp43-enemies">{knownEnemies.map(({enemy,index,identity,facts})=>{
    const health=facts.find(report=>report.kind==='health'),affinities=facts.filter(report=>report.kind==='affinity'),spells=facts.filter(report=>report.kind==='spell'),identityReport=facts.find(report=>report.kind==='identity');
    const identityDetail=identityReport?.detail.split(' · ').slice(1).join(' · ')??(enemy.creatureId?'Elemental':'Champion');
    return <section className="trp43-enemy" key={enemy.id} aria-label={`Known details for enemy ${index+1}`}>
     <header>
      {identity?<Portrait actor={enemy}/>:<span className="trp43-unseen" aria-hidden="true">?</span>}
      <span className="trp43-enemy-copy"><strong>{identity?actorName(enemy):`Enemy ${index+1}`}</strong>{identity&&<small>Enemy {index+1} · {identityDetail}</small>}</span>
      {health&&<b className="trp43-health">{health.detail}</b>}
     </header>
     {!!affinities.length&&<div className="trp43-facts" aria-label={`Known affinities for enemy ${index+1}`}>{affinities.map(report=><KnownFact key={report.id} report={report}/>)}</div>}
     {!!spells.length&&<div className="trp43-facts trp43-spells" aria-label={`Known spells for enemy ${index+1}`}><small>Spells</small>{spells.map(report=><KnownFact key={report.id} report={report}/>)}</div>}
    </section>;
   })}</div>}
  </div>}
  {!!baselineClues.length&&<dl className="trp43-clues">{baselineClues.map((clue,index)=><div key={`${clue.label}-${index}`}><dt>{clue.label==='Affinities detected'?'Traces':clue.label}</dt><dd>{clue.elements?.map(element=><ElementIcon key={element} element={element} size={17}/>)}{clue.detail}</dd></div>)}</dl>}
  {ground&&<dl className="trp43-clues"><div><dt>Terrain</dt><dd>{ground.detail}</dd></div></dl>}
  {!service&&<p className="trp43-unknown">{options.remaining>0?'Some details unscouted · ':''}Unseen spells</p>}
  {!service&&onScout&&<section className="trp43-scouting" aria-label="Champion scouts">
   <div className="trp43-section-label"><strong>Scout <span>{scouts.length} left</span></strong><span title="Each living champion reveals one random detail per floor. Reports are shared with friends.">1 detail per champion</span></div>
   <div className="trp43-scouts">{champions.map(actor=>{
    const ready=available.has(actor.id),exhausted=!options.remaining,blocked=disabled||scoutingLocked||!ready||exhausted;
    const explanation=scoutingLocked?'Withdraw your destination before scouting.':!ready?(actor.hp<=0?'Defeated champions cannot scout.':'Already scouted this floor.'):exhausted?'The remaining details stay hidden until you enter.':`Reveal one random detail with ${actorName(actor)}.`;
    return <button type="button" key={actor.id} data-ready={ready} disabled={blocked} title={explanation} aria-label={`Scout ${room.name} with ${actorName(actor)}`} onClick={()=>onScout(actor.id,room.id)}><Portrait actor={actor} size={28}/><span>{actorName(actor)}<small>{ready?(exhausted?'Nothing more to scout':'Scout'):(actor.hp<=0?'Defeated':'Used')}</small></span></button>;
   })}</div>
   {!champions.length&&<small>Champions can scout.</small>}
  </section>}
  <div className="trp43-reward"><strong>{service?'Offer':'Reward'}</strong><p>{intel.reward}</p></div>
  {event&&<p className="trp43-cost" data-blocked={!canPay}><strong>2 HP · {actorName(payer)}</strong><span>{canPay?`${payer.hp} → ${payer.hp-2} HP`:`${payer.hp} HP · needs 3`}</span></p>}
  <button type="button" className="t22-primary trp43-enter" disabled={disabled||chosen||!canPay} aria-label={`${primaryLabel}: ${room.name}`} onClick={()=>onChoose(room.id)}>{primaryLabel}<span aria-hidden="true">{chosen?'✓':'→'}</span></button>
 </article>;
}
