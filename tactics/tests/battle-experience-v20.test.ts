import test from 'node:test';
import assert from 'node:assert/strict';
import {readCampaignProfile,createCampaignGame,validateCampaignProfile,updateCampaignCompanions} from '../lib/story-v20.ts';
import {CHAMPIONS} from '../lib/roster-v13.ts';
import {CREATURES} from '../lib/campaign-creatures-v20.ts';
import {getCreatureSpell,getSpell,spellElements} from '../lib/spells-v20.ts';
import {castAvailability,legalCasts,resolveRound,type SimEvent,type TeamPlan} from '../lib/tactics-v20.ts';
import {roundOutcomes,nextUnplannedId,queuedOrderLabel,phaseLedger,compactEvents,learnedSpellNotice} from '../lib/battle-experience-v20.ts';
import {planningForecast} from '../lib/planning-forecast-v20.ts';
import {projectedVolley} from '../lib/planned-volley-v20.ts';

const fresh=()=>createCampaignGame(readCampaignProfile(null),'oh_tipi');
const empty=():TeamPlan=>({orders:[]});

test('actual consequences use health and Flux snapshots, not raw damage, healing or overheal amounts',()=>{
 const before=fresh(),after=structuredClone(before),hero=before.units[0],next=after.units[0];
 hero.hp=5;hero.flux=4;next.hp=6;next.flux=2;
 after.lastResolution=[{kind:'damage',unitId:hero.id,amount:5,text:'Five damage'},{kind:'heal',unitId:hero.id,amount:9,text:'Nine healing including overheal'}];
 const outcome=roundOutcomes(before,after).find(row=>row.id===hero.id)!;
 assert.deepEqual([outcome.hpBefore,outcome.hpAfter,outcome.hpDelta],[5,6,1]);
 assert.deepEqual([outcome.fluxBefore,outcome.fluxAfter,outcome.fluxDelta],[4,2,-2]);
 assert.equal(outcome.defeated,false);
 next.hp=0;assert.equal(roundOutcomes(before,after).find(row=>row.id===hero.id)!.defeated,true);
 hero.hp=0;assert.equal(roundOutcomes(before,after).find(row=>row.id===hero.id)!.defeated,false,'An already fallen actor is not announced as newly defeated');
});

test('outcomes retain every actor and distinguish new, shortened and expired statuses',()=>{
 const before=fresh(),after=structuredClone(before),old=before.units[0],next=after.units[0];
 old.statuses={burn:{turns:1,power:1},ward:{turns:2,power:1},wet:{turns:1,power:1}};
 next.statuses={ward:{turns:1,power:1},haste:{turns:1,power:1},wet:{turns:1,power:1}};
 next.displayName='Reed';after.units.reverse();
 const rows=roundOutcomes(before,after),row=rows.find(entry=>entry.id===old.id)!;
 assert.equal(rows.length,before.units.length);assert.equal(row.name,'Reed');
 assert.ok(row.changes.includes('Burn ended'));assert.ok(row.changes.includes('Ward 1r'));assert.ok(row.changes.includes('Haste 1r'));
 assert.ok(!row.changes.some(change=>change.startsWith('Wet')),'An unchanged condition should not appear as a fresh consequence');
 assert.deepEqual([row.hpBefore,row.hpAfter],[old.hp,next.hp],'Snapshot matching is by actor ID rather than array position');
});

test('next planning selection wraps, skips finished and fallen actors, and treats a move-only order as unfinished',()=>{
 const state=fresh(),[a,b,c]=state.units.filter(unit=>unit.owner===0);
 assert.equal(nextUnplannedId(state,empty(),null),a.id);
 assert.equal(nextUnplannedId(state,{orders:[{unitId:a.id,guard:true},{unitId:b.id,move:{q:b.q,r:b.r}}]},a.id),b.id);
 assert.equal(nextUnplannedId(state,{orders:[{unitId:a.id,guard:true},{unitId:b.id,cast:{q:0,r:0},spellId:b.loadout[0]}]},a.id),c.id);
 assert.equal(nextUnplannedId(state,{orders:[{unitId:b.id,guard:true},{unitId:c.id,guard:true}]},b.id),a.id);
 b.hp=0;c.respawn=1;
 assert.equal(nextUnplannedId(state,empty(),a.id),a.id);
 assert.equal(nextUnplannedId(state,{orders:[{unitId:a.id,guard:true}]},a.id),a.id,'All ready keeps a usable live selection');
 a.hp=0;assert.equal(nextUnplannedId(state,empty(),a.id),null,'Enemies are never selected as the next controllable actor');
});

test('queued labels recognize new own spell IDs and keep move-only auto-Guard explicit',()=>{
 const state=fresh(),creature=state.units.find(unit=>unit.owner===0&&unit.creatureId)!;
 const spell=getCreatureSpell(creature.creatureId!),cast={q:creature.q,r:creature.r};
 assert.match(queuedOrderLabel(state,{orders:[{unitId:creature.id,spellId:spell.id,cast}]},creature.id),new RegExp(spell.name));
 assert.match(queuedOrderLabel(state,{orders:[{unitId:creature.id,move:cast}]},creature.id),/^→ .* · Auto Guard$/);
 assert.equal(queuedOrderLabel(state,empty(),'missing'),'');
 assert.equal(learnedSpellNotice([]),'');assert.match(learnedSpellNotice([spell.name]),/after this battle/);
});

test('a queued cast displays its actual Concussed Flux charge',()=>{
 const state=fresh(),hero=state.units[0],spellId=hero.loadout[0];hero.statuses.concussed={turns:1,power:1};
 const plan:TeamPlan={orders:[{unitId:hero.id,spellId,cast:{q:hero.q,r:hero.r}}]},cost=castAvailability(state,hero.id,spellId).cost;
 assert.ok(queuedOrderLabel(state,plan,hero.id).endsWith(`${cost} F`),'The queued summary and the authoritative affordability check must show the same charge');
});

test('phase ledger partitions all events exactly once including movement and forced-displacement bounces',()=>{
 const state=fresh();state.lastResolution=[
  {kind:'guard',text:'Guard'},
  {kind:'move',text:'Move'},
  {kind:'bounce',text:'simultaneous move blocked'},
  {kind:'cast',text:'Cast'},
  {kind:'clash',text:'Meeting'},
  {kind:'bounce',text:'simultaneous push blocked'},
  {kind:'damage',text:'Damage'},
  {kind:'heal',text:'Healing'},
  {kind:'surface',text:'A status ended'},
  {kind:'defeat',text:'Defeat'},
  {kind:'score',text:'Recovery'},
 ] as SimEvent[];
 const phases=['move','cast','impact','settle'] as const,partition=phases.flatMap(phase=>phaseLedger(state,phase));
 assert.equal(partition.length,state.lastResolution.length);assert.equal(new Set(partition).size,state.lastResolution.length);
 assert.deepEqual(new Set(partition),new Set(state.lastResolution));
 assert.ok(phaseLedger(state,'move').some(event=>event.text==='simultaneous move blocked'));
 assert.ok(phaseLedger(state,'impact').some(event=>event.text==='simultaneous push blocked'));
});

test('the full opening report preserves both identically named opponents actions while compacting repeated field tiles with their count',()=>{
 const before=fresh(),after=resolveRound(before,[empty(),empty()]),guards=after.lastResolution.filter(event=>event.kind==='guard');
 const duplicate=guards.find((event,index)=>guards.some((other,otherIndex)=>index!==otherIndex&&event.text===other.text))!;
 assert.ok(duplicate,'The opening contains an Oh Tipi on each side');
 assert.equal(compactEvents(phaseLedger(after,'cast')).filter(text=>text===duplicate.text).length,2,'Two actors with the same name must not lose an action from the full report');
 const fields:SimEvent[]=[{kind:'reaction',terrain:'steam',q:0,r:0,text:'Steam forms'},{kind:'reaction',terrain:'steam',q:1,r:0,text:'Steam forms elsewhere'}];
 assert.deepEqual(compactEvents(fields),['Steam forms (2 hexes)']);
});

test('a new mixed creature spell forecasts all ingredients on the real map, stays after queuing, and cannot include a rival private order',()=>{
 const mixed=CREATURES.find(creature=>creature.elements.length===3)!,late=validateCampaignProfile({...readCampaignProfile(null),defeated:CHAMPIONS.slice(0,20).map(hero=>hero.id)});
 const profile=updateCampaignCompanions(late,[mixed.id,late.companions[0]]),state=createCampaignGame(profile,CHAMPIONS[20].id),actor=state.units.find(unit=>unit.owner===0&&unit.creatureId===mixed.id)!,spell=getCreatureSpell(mixed.id);
 const aims=legalCasts(state,actor.id,undefined,spell.id),aim=aims.find(cell=>cell.q===actor.q&&cell.r===actor.r)??aims[0];assert.ok(aim);
 const candidate=planningForecast(state,0,empty(),actor.id,spell.id,aim)!;
 const plan:TeamPlan={orders:[{unitId:actor.id,spellId:spell.id,cast:{q:aim.q,r:aim.r}}]},queued=planningForecast(state,0,plan,actor.id)!;
 assert.deepEqual(candidate,queued);assert.equal(candidate.blocked,false);assert.ok(candidate.cells.length>0);
 const volley=projectedVolley(state,0,plan);assert.deepEqual(new Set(volley.fields.map(field=>field.element)),new Set(spellElements(spell)));
 for(const cell of candidate.cells)for(const element of spellElements(spell))assert.ok(cell.elements.includes(element));
 const rival=state.units.find(unit=>unit.owner===1)!;
 const contaminated={orders:[...plan.orders,{unitId:rival.id,spellId:rival.loadout[0],cast:{q:aim.q,r:aim.r}}]};
 assert.deepEqual(planningForecast(state,0,contaminated,actor.id),candidate);
 const resolved=resolveRound(state,[plan,empty()]);
 for(const forecast of candidate.cells){const cell=resolved.cells.find(cell=>cell.q===forecast.q&&cell.r===forecast.r)!;assert.equal(cell.terrain,forecast.field);}
 assert.equal(getSpell(candidate.spellId).id,spell.id);
});
