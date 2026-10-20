"use client";

import type {TowerRoom} from '../../lib/tower-v23';
import {towerRoomIntel} from '../../lib/tower-scouting';
import type {ScoutReport} from '../../lib/tower-scouting-actions';
import ElementIcon from './ElementIcon';
import PixelChampion from './PixelChampion';
import CombatCreature from './CombatCreatureV19';
import './tower-scouting.css';

/** Only the scouting projection may enter this pre-entry view. */
export function TowerRoomReport({room,compact=false,scoutReports=[],cooperative=false}:{room:TowerRoom;compact?:boolean;scoutReports?:readonly ScoutReport[];cooperative?:boolean}){
 const report=towerRoomIntel(room);
 const knownIdentities=new Set([...(report.knownEnemy?[report.knownEnemy.enemyId]:[]),...scoutReports.filter(clue=>clue.kind==='identity').map(clue=>clue.enemyId)]);
 const unknowns=scoutReports.length?[
  ...(knownIdentities.size<report.enemyCount?['Some enemy identities']:[]),
  'Unseen spells',
  ...(report.environment===undefined&&!scoutReports.some(clue=>clue.kind==='environment')?['Terrain']:[]),
 ]:report.unknowns;
 const rows=(clues:readonly ScoutReport[])=>clues.map(clue=><div key={clue.id}><dt>{clue.label}</dt><dd>{clue.element&&<span className="t23-clue-elements" aria-hidden="true"><ElementIcon element={clue.element} size={18}/></span>}{clue.detail}</dd></div>);
 return <section className="t23-scout" data-profile={report.profile} data-compact={compact} aria-label={`${report.heading} for ${room.name}`}>
  <div className="t23-scout-meta"><strong>{report.risk}</strong>{report.profile!=='service'&&<span>{report.enemyCount} {report.enemyCount===1?'enemy':'enemies'}{cooperative&&<small title="Joining squads bring their own opposition into the shared battle."> + allies’ foes</small>}</span>}</div>
  <h4>{report.heading}</h4>
  {report.knownEnemy&&<div className="t23-sighting">
   {report.knownEnemy.creatureId?<CombatCreature creatureId={report.knownEnemy.creatureId} size={46}/>:<PixelChampion id={report.knownEnemy.championId} size={46} paused/>}
   <span><strong>{report.knownEnemy.name}</strong><small>Enemy {report.knownEnemy.position} · {report.knownEnemy.kind==='champion'?'Champion':'Elemental'}</small></span>
  </div>}
  <dl className="t23-clues">{report.clues.filter(clue=>!report.knownEnemy||clue.label!=='Spotted').map((clue,index)=><div key={`${clue.label}-${index}`}><dt>{clue.label}</dt><dd>{!!clue.elements?.length&&<span className="t23-clue-elements" aria-hidden="true">{clue.elements.map(element=><ElementIcon key={element} element={element} size={18}/>)}</span>}{clue.detail}</dd></div>)}</dl>
  {!!scoutReports.length&&<div className="t23-revealed"><h4>Scouted · {scoutReports.length}</h4><dl className="t23-clues">{rows(scoutReports.slice(-3))}</dl>{scoutReports.length>3&&<details><summary>{scoutReports.length-3} earlier {scoutReports.length===4?'report':'reports'}</summary><dl className="t23-clues">{rows(scoutReports.slice(0,-3))}</dl></details>}</div>}
  <p className="t23-unknown"><span aria-hidden="true">?</span><span><b>Unknown</b> {unknowns.join(' · ')}</span></p>
 </section>;
}
