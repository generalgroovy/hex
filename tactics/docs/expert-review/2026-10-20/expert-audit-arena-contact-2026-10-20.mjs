import {writeFileSync} from 'node:fs';
import {createSimGame,resolveRound,plannedProjectileClashes,validatePlan,legalCasts} from '../../../lib/tactics-v18.ts';
import {findProjectileClashes as volume} from '../../../lib/projectile-interception-v20.ts';
const state=createSimGame({seed:'AUDIT-ARENA-CONTACT',rosters:[['red_baron','oh_tipi','treevor_mason'],['wa_bidi','haara','steezo']]});
for(const c of state.cells){c.terrain='plain';c.biome='plain';c.height=0;c.well=false;delete c.ttl;delete c.elements;delete c.reactions;delete c.ice;delete c.barrier;}
const places=[[-2,0],[0,-2],[-5,0],[4,-4],[5,-2],[0,5]];
state.units.forEach((u,i)=>Object.assign(u,{q:places[i][0],r:places[i][1]}));
const orders=[{unitId:'0-red_baron',spellId:'ember',cast:{q:2,r:0}},{unitId:'0-oh_tipi',spellId:'water_jet',cast:{q:1,r:2}}];
const plan=validatePlan(state,0,{orders});
const next=resolveRound(state,[plan,{orders:[]}]);
const shots=orders.map(o=>{const u=state.units.find(u=>u.id===o.unitId);return{unitId:u.id,from:{q:u.q,r:u.r},to:o.cast,element:o.spellId==='ember'?'fire':'water'};});
const result={source:'592855cbd88c070683d0c1fdc1fa0eaf235a0514',scope:'Actual current Arena legal simultaneous volley on controlled flat ground',legal:orders.map(o=>legalCasts(state,o.unitId,undefined,o.spellId).some(p=>p.q===o.cast.q&&p.r===o.cast.r)),casts:next.lastResolution.filter(e=>e.kind==='cast'),actualClashes:next.lastResolution.filter(e=>e.kind==='clash'),forecast:plannedProjectileClashes(state,plan),volumeRuleResult:volume(shots,state.cells)};
if (process.env.HEX_AUDIT_OUTPUT) writeFileSync(process.env.HEX_AUDIT_OUTPUT,JSON.stringify(result,null,2));console.log(JSON.stringify(result,null,2));
