import assert from 'node:assert/strict';
import test from 'node:test';
import {createClientSessionStore} from '../lib/client-session-v11.ts';
import {createSimGame,prepareTeam,legalCasts,type TeamPlan} from '../lib/tactics-v11.ts';
import {getChampion} from '../lib/roster-v11.ts';
import {SIGNATURES} from '../lib/spells-v11.ts';
import {canonicalPlan} from '../lib/room-plans.ts';

const code='23456789ABCD',matchId='12345678-1234-1234-1234-123456789abc';
function memoryStorage(){const map=new Map<string,string>();return {getItem:(key:string)=>map.get(key)??null,setItem:(key:string,value:string)=>{map.set(key,value)},removeItem:(key:string)=>{map.delete(key)}}}

test('v11 drafts preserve fixed-affinity equipment and signatures across reload without changing historical drafts',()=>{
  const signature=SIGNATURES.find(spell=>spell.element==='water'&&spell.signatureChampionId!=='oh_tipi')!;
  const roster=['oh_tipi','haara','s_wayne'];
  const state=createSimGame([roster,roster],undefined,undefined,[[signature.id],[]],[{oh_tipi:{...getChampion('oh_tipi').affinities,water:5}},{}]);
  const unit=state.units.find(unit=>unit.owner===0&&unit.championId==='oh_tipi')!;
  const plan:TeamPlan={orders:[],loadouts:[{unitId:unit.id,spells:[signature.id,...unit.loadout.slice(1)]}]};
  const projected=prepareTeam(state,0,plan),target=legalCasts(projected,unit.id,undefined,signature.id)[0];assert.ok(target);
  plan.orders=[{unitId:unit.id,spellId:signature.id,cast:{q:target.q,r:target.r}}];
  const storage=memoryStorage(),context={code,matchId,state,seat:0 as const};
  storage.setItem(`confluence-draft-v10-${code}`,'historical draft');
  const store=createClientSessionStore([{kind:'local',storage}]);assert.equal(store.saveDraft({...context,plan}),'local');
  const reloaded=createClientSessionStore([{kind:'local',storage}]);assert.deepEqual(reloaded.readDraft(context),canonicalPlan(plan,11));
  assert.equal(reloaded.readDraft({...context,state:{...state,round:2}}),null);
  assert.throws(()=>store.saveDraft({...context,plan:{orders:[],training:[{unitId:unit.id,element:'water'}]}}));
  reloaded.clearDraft(code);assert.equal(reloaded.readDraft(context),null);assert.equal(storage.getItem(`confluence-draft-v10-${code}`),'historical draft');
});

test('v11 canonical wire rejects affinity mutation but preserves released v10 preparation bytes',()=>{
  const training={orders:[],training:[{unitId:'0-oh_tipi',element:'water' as const}]};
  assert.deepEqual(canonicalPlan(training,10),training);assert.throws(()=>canonicalPlan(training,11),/Story/);
  assert.deepEqual(canonicalPlan({orders:[],training:[]},11),{orders:[]});
});
