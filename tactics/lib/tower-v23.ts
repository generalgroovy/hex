import {TOWER_CHARMS,TOWER_SCROLLS,towerCharm,carryTowerSupplies,type TowerCharmId} from './tower-supplies-v45.ts';
/** A run owns its party, spell library and wounds. Campaign progress never enters the tower. */
import type {Element} from './game.ts';
import {CHAMPIONS,getChampion,allocateAffinityBudget,affinityTotal,validateAffinityAllocation,type AffinityAllocation} from './roster-v13.ts';
import {CREATURES,getCreature,teamPerkEffects} from './campaign-creatures-v20.ts';
import {ALL_SPELLS,TEACHABLE_SPELLS,getSpell,getSignature,teachingForEnemy,defaultLoadout,spellAccess,spellCost,validateLoadout,type Spell} from './spells-v20.ts';
import {createTowerBattle,restoreSimState,validateTowerBattleConfig,validatePlan,type TowerActor,type TowerBattleConfig,type SimState,type TeamPlan} from './tactics-v22.ts';
import {validateFloorScouting,type FloorScouting} from './tower-scouting-state.ts';
import {reachableTowerRooms,towerBranchCount} from './tower-route-map.ts';
import {TOWER_MOTIFS,TOWER_MOTIF_INFO} from './tower-terrain-v44.ts';
export type {TowerActor} from './tactics-v22.ts';

export const TOWER_SESSION_KEY='hex-confluence-tower-v23';
export const TOWER_FLOORS=9;
export type TowerPhase='route'|'battle'|'reward'|'won'|'lost';
export type TowerBuild={championId:string;name:string;affinities:AffinityAllocation;loadout:string[]};
export type TowerMemberInput={kind:'champion';build:TowerBuild}|{kind:'creature';creatureId:string};
export type TowerStart={starterId:string;members:[TowerMemberInput,TowerMemberInput]};
export type TowerStarterInput=string|TowerStart;
export type TowerRoom={id:string;floor:number;kind:'combat'|'elite'|'recruit'|'camp'|'event';name:string;flavor:string;description:string;enemies:TowerActor[];mapId:string;environment:NonNullable<TowerBattleConfig['environment']>};
export type TowerRun={format:3;mode:'solo';suppliesModel?:'v45';routePlayers?:number;encounterModel?:'motifs44';encounterVariant?:0|1|2;starts:[TowerStart];seed:string;starterId:string;floor:number;phase:TowerPhase;party:TowerActor[];learnedSpells:string[];history:TowerRoom[];currentRoom:TowerRoom|null;scouting?:FloorScouting};
export type TowerReward={id:string;kind:'spell'|'train'|'heal'|'recruit'|'charm'|'scroll';charmId?:TowerCharmId;name:string;description:string;flavor?:string;spellId?:string;actorId?:string;element?:Element;amount?:number;actor?:TowerActor};
export type TowerSession={format:3;run:TowerRun;battle:SimState|null;plan:TeamPlan;previous?:SimState};
const clone=<T>(value:T):T=>JSON.parse(JSON.stringify(value));
const plain=(value:unknown):value is Record<string,unknown>=>!!value&&typeof value==='object'&&!Array.isArray(value)&&[Object.prototype,null].includes(Object.getPrototypeOf(value));
const knownSpells=new Set(ALL_SPELLS.map(spell=>spell.id)),teachable=new Set(TEACHABLE_SPELLS.map(spell=>spell.id));
const elements:Element[]=['fire','water','earth','air','light','dark'];
const title=(value:string)=>value.charAt(0).toUpperCase()+value.slice(1);
function hash(value:string):number{let number=2166136261;for(const character of value){number^=character.charCodeAt(0);number=Math.imul(number,16777619)>>>0;}return number;}
function shuffled<T>(values:readonly T[],seed:string):T[]{
 const result=[...values];let state=hash(seed);
 const random=()=>{state=(state+0x6d2b79f5)|0;let value=state;value=Math.imul(value^(value>>>15),value|1);value^=value+Math.imul(value^(value>>>7),value|61);return ((value^(value>>>14))>>>0)/4294967296;};
 for(let index=result.length-1;index>0;index--){const other=Math.floor(random()*(index+1));[result[index],result[other]]=[result[other],result[index]];}
 return result;
}
function seedText(input:string):string{if(typeof input!=='string')throw new Error('Use a seed of 1–24 letters or numbers.');const seed=input.trim().toUpperCase();if(!/^[A-Z0-9][A-Z0-9 -]{0,23}$/.test(seed))throw new Error('Use a seed of 1–24 letters or numbers.');return seed;}
export function towerChampion(id:string,actorId:string,budget=5):TowerActor{const champion=getChampion(id),affinities=allocateAffinityBudget(id,budget);return {id:actorId,championId:id,displayName:champion.name,affinities,loadout:defaultLoadout(id,affinities),hp:8,maxHp:8,maxFlux:6};}
export function towerCreature(id:string,actorId:string):TowerActor{const creature=getCreature(id);return {id:actorId,championId:creature.championId,creatureId:id,displayName:creature.name,affinities:{...creature.affinities},loadout:[...creature.loadout],hp:creature.maxHp,maxHp:creature.maxHp,maxFlux:creature.maxFlux};}
const starterPresets=[
 {id:'steam',name:'Oh Tipi & Cinder',description:'Water controls the ground. Fire turns it into cover.',heroId:'oh_tipi',companionId:'creature-fire-cinder',party:[towerChampion('oh_tipi','hero'),towerCreature('creature-fire-cinder','companion')]},
 {id:'stone',name:'Treevor & Puddle',description:'Earth holds a lane. Water keeps the front line standing.',heroId:'treevor_mason',companionId:'creature-water-puddle',party:[towerChampion('treevor_mason','hero'),towerCreature('creature-water-puddle','companion')]},
 {id:'dusk',name:'S. Wayne & Whisk',description:'Dark drains. Light restores. Whisk pulls enemies out of cover.',heroId:'s_wayne',companionId:'creature-air-whisk',party:[{...towerChampion('s_wayne','hero'),loadout:['wither_bolt','siphon','radiant_bolt','mend'] as string[]},towerCreature('creature-air-whisk','companion')]},
] as const;
const soloStarterPresets=[
 {id:'baron',name:'The Red Baron & Burrpaw',description:'Burrpaw roots a target. The Baron follows with fire and Backdraft.',heroId:'red_baron',companionId:'creature-earth-burrpaw',party:[towerChampion('red_baron','hero'),towerCreature('creature-earth-burrpaw','companion')]},
 {id:'steezo',name:'Steezo & Pip',description:'Pip supplies Haste and Flux. Steezo keeps pressure on a clear firing lane.',heroId:'steezo',companionId:'creature-air-pip',party:[towerChampion('steezo','hero'),towerCreature('creature-air-pip','companion')]},
 {id:'oll_i',name:"Oll’ I & Morrow",description:'Oll’ I pierces protection and can heal Morrow. Morrow attacks and drains health.',heroId:'oll_i',companionId:'creature-dark-morrow',party:[towerChampion('oll_i','hero'),towerCreature('creature-dark-morrow','companion')]},
 {id:'wa_bidi',name:'Wa Bidi & Wick',description:'Wa Bidi spends health for burst damage. Wick restores health and grants Clarity.',heroId:'wa_bidi',companionId:'creature-light-wick',party:[towerChampion('wa_bidi','hero'),towerCreature('creature-light-wick','companion')]},
] as const;
const allStarterPresets=[...starterPresets,...soloStarterPresets].map(starter=>({...starter,members:starter.party.map(actor=>actor.creatureId?{kind:'creature' as const,creatureId:actor.creatureId}:{kind:'champion' as const,build:{championId:actor.championId,name:actor.displayName!,affinities:{...actor.affinities},loadout:[...actor.loadout]}}) as [TowerMemberInput,TowerMemberInput]}));
/** Keep the shared-climb suggestions and saved starter identities unchanged. */
export const TOWER_STARTERS=allStarterPresets.filter(starter=>starterPresets.some(preset=>preset.id===starter.id));
export const TOWER_SOLO_STARTERS=['steam','dusk','baron','steezo','stone','oll_i','wa_bidi'].map(id=>allStarterPresets.find(starter=>starter.id===id)!);
function kitSpells(party:readonly TowerActor[]):string[]{return [...new Set(party.flatMap(actor=>[...actor.loadout,...(!actor.creatureId?[getSignature(actor.championId).id]:[])]))].sort();}
export function towerBuildSpells(build:Pick<TowerBuild,'championId'|'affinities'>,learnedSpells:string[]=[]):Spell[]{
 getChampion(build.championId);validateAffinityAllocation(build.affinities,18);
 const library=learnedSpells.filter(id=>teachable.has(id));
 return ALL_SPELLS.filter(spell=>spell.id!==getSignature(build.championId).id&&spellAccess(build.championId,spell.id,build.affinities,library).unlocked&&spellCost(build.championId,spell.id,build.affinities)<=6);
}
export function validateTowerBuild(input:unknown,budget=5,learnedSpells:string[]=[]):TowerBuild {
 if(!plain(input)||Object.keys(input).some(key=>!['championId','name','affinities','loadout'].includes(key))||typeof input.championId!=='string'||!Number.isSafeInteger(budget)||budget<5||budget>18)throw new Error('Choose a valid champion build.');
 const champion=getChampion(input.championId),affinities=validateAffinityAllocation(input.affinities,budget),primary=affinities[champion.element]??0;
 if(affinityTotal(affinities)!==budget||primary<2||Object.values(affinities).some(rank=>rank!>primary||rank!>Math.min(6,budget-2)))throw new Error(`Spend ${budget} affinity points. Keep ${title(champion.element)} highest (at least 2), with at most three elements.`);
 if(typeof input.name!=='string'||!input.name.trim()||input.name.trim().length>48||/[\x00-\x1f\x7f<>]/.test(input.name))throw new Error('Use a short, plain character name.');
 const loadout=validateLoadout(champion.id,input.loadout,affinities,learnedSpells.filter(id=>teachable.has(id)));
 if(loadout.some(id=>spellCost(champion.id,id,affinities)>6))throw new Error('Choose spells you can afford with 6 Flux.');
 return {championId:champion.id,name:input.name.trim(),affinities:Object.fromEntries(elements.filter(element=>affinities[element]).map(element=>[element,affinities[element]])),loadout};
}
export function validateTowerStarter(input:TowerStarterInput):TowerStart {
 const value=typeof input==='string'?{starterId:input}:input;
 if(!plain(value)||Object.keys(value).some(key=>!['starterId','members'].includes(key)))throw new Error('Choose two starting characters.');
 const preset=allStarterPresets.find(candidate=>candidate.id===value.starterId);if(!preset)throw new Error('Choose a starting suggestion.');
 const supplied=('members' in value?value.members:undefined)??preset.members;
 if(!Array.isArray(supplied)||supplied.length!==2)throw new Error('Choose exactly two starting characters.');
 const members=supplied.map(member=>{
  if(!plain(member))throw new Error('Choose a valid starting character.');
  if(member.kind==='champion'&&Object.keys(member).every(key=>['kind','build'].includes(key)))return {kind:'champion' as const,build:validateTowerBuild(member.build)};
  if(member.kind==='creature'&&Object.keys(member).every(key=>['kind','creatureId'].includes(key))&&typeof member.creatureId==='string'){
   const creature=getCreature(member.creatureId);if(creature.strengthClass==='lesser'&&affinityTotal(creature.affinities)===2)return {kind:'creature' as const,creatureId:creature.id};
  }
  throw new Error('Start with a five-affinity champion or a lesser, two-affinity creature.');
 }) as [TowerMemberInput,TowerMemberInput];
 const identity=(member:TowerMemberInput)=>member.kind==='champion'?member.build.championId:member.creatureId;
 if(identity(members[0])===identity(members[1]))throw new Error('Choose two different characters.');
 return {starterId:preset.id,members};
}
const builtActor=(build:TowerBuild,id:string):TowerActor=>({id,championId:build.championId,displayName:build.name,affinities:{...build.affinities},loadout:[...build.loadout],hp:8,maxHp:8,maxFlux:6});
const memberActor=(member:TowerMemberInput,id:string):TowerActor=>member.kind==='champion'?builtActor(member.build,id):towerCreature(member.creatureId,id);
export function createTowerRun(seed:string,starter:TowerStarterInput='steam',routePlayers=1,encounterVariant:0|1|2=0):TowerRun {
 towerBranchCount(routePlayers);
  if(![0,1,2].includes(encounterVariant))throw new Error('Choose a valid encounter role.');
 const start=validateTowerStarter(starter),party=start.members.map((member,index)=>memberActor(member,index?'companion':'hero'));
  return {format:3,mode:'solo',suppliesModel:'v45',routePlayers,encounterModel:'motifs44',encounterVariant,starts:[start],seed:seedText(seed),starterId:start.starterId,floor:1,phase:'route',party,learnedSpells:kitSpells(party),history:[],currentRoom:null};
}
export function towerStartingAffinity(run:Pick<TowerRun,'starts'>):4|7|10 {
 return run.starts[0].members.reduce<number>((sum,member)=>sum+(member.kind==='champion'?5:2),0) as 4|7|10;
}
export function towerReplaceableActors(run:TowerRun):TowerActor[] {
 const protectedIds=new Set(run.starts[0].members.flatMap((member,index)=>member.kind==='champion'?[index?'companion':'hero']:[]));
 return run.party.filter(actor=>!protectedIds.has(actor.id));
}
export function towerTuitionActor(run:TowerRun):TowerActor{return run.party[0];}
export function towerController(run:TowerRun,actorId:string):0 {
 if(!run.party.some(actor=>actor.id===actorId))throw new Error('That fighter is not in the party.');return 0;
}
export function towerControlledActorIds(run:TowerRun,seat:0|1):string[]{return seat===0?run.party.map(actor=>actor.id):[];}
const rooms=[
 {name:'Boiler room',flavor:'The kettle has joined the opposition.'},
 {name:'Overgrown landing',flavor:'The plants have filed for sole occupancy.'},
 {name:'Lost property',flavor:'Everything here belongs to someone with a grudge.'},
 {name:'Drafty stairwell',flavor:'The breeze is taking this personally.'},
 {name:'Night shift',flavor:'They were promised a quiet evening.'},
 {name:'Sunroom',flavor:'No running. Apparently spells are fine.'},
 {name:'Roof garden',flavor:'Please do not feed the thunder.'},
 {name:'Staff kitchen',flavor:'Someone has enchanted the soup again.'},
];
type EncounterRun=Pick<TowerRun,'seed'|'floor'|'mode'|'starts'|'encounterModel'|'encounterVariant'>;
function battleEnemies(run:EncounterRun,lane:number,elite:boolean):TowerActor[]{
 const salt=`${run.seed}:floor:${run.floor}:lane:${lane}`,floor=run.floor,power=towerStartingAffinity(run),tier=power===4?-1:power===10?1:0;
 const lesser=shuffled(CREATURES.filter(creature=>creature.strengthClass==='lesser'),`${salt}:lesser`),standard=shuffled(CREATURES.filter(creature=>creature.strengthClass==='standard'),`${salt}:standard`);
 const champions=shuffled(CHAMPIONS,`${salt}:champion`),result:TowerActor[]=[];
 const addCreature=(id:string)=>result.push(towerCreature(id,`enemy-${result.length}`));
 const addChampion=(index:number,budget:number)=>result.push(towerChampion(champions[index].id,`enemy-${result.length}`,budget));
 if(floor<=2){
  const attacks=(creature:typeof lesser[number])=>creature.loadout.some(id=>getSpell(id).damage>=2);
  // Two native creature kits need a readable first fight, not a healing race.
  // The first victory offers recruits; floor two then uses the regular pair.
  if(floor===1&&tier===-1&&!elite)addCreature(lesser.find(attacks)!.id);
  else {
  const first=tier===1?standard[0]:lesser[0],primary=getChampion(first.championId).element,pool=elite?standard:lesser;
  // Early pairs need two elemental identities and a source of pressure. Two
  // pure healers/warders otherwise teach waiting for collapse, not combat.
  // A one-damage controller is not an attacker: pairing it with a warder can
  // lock a starter out of all damage before it has any opportunity to draft.
  const second=pool.find(creature=>getChampion(creature.championId).element!==primary&&(attacks(first)||attacks(creature)))!;
  addCreature(first.id);addCreature(second.id);
  }
 }
 else if(floor<=5){addChampion(0,Math.max(5,5+tier+Number(elite)));addCreature((elite||tier===1?standard[0]:lesser[0]).id);if(floor===5&&elite)addCreature(lesser[1].id);}
 else if(floor<9){addChampion(0,7+tier+Number(elite));addCreature((tier===-1?lesser[0]:standard[0]).id);addCreature((elite||tier===1?standard[1]:lesser[tier===-1?1:0]).id);}
 else{addChampion(0,8+tier);addChampion(1,7+tier);addCreature((tier===-1?lesser[0]:standard[0]).id);}
  if(run.encounterModel==='motifs44'){
   const index=result.findLastIndex(actor=>!!actor.creatureId),original=result[index];
   // Keep the lead teacher. Extra squads vary one supporting role, established
   // before scouting, rather than changing a revealed encounter on entry.
   if(original?.creatureId&&index>0){
    const definition=getCreature(original.creatureId),variant=run.encounterVariant??0;
    const promote=tier>=0&&floor>=7&&(elite||floor===9),strengthClass=promote?'greater':definition.strengthClass;
    const primary=getChampion(original.championId).element,otherElements=new Set(result.filter((_,i)=>i!==index).map(actor=>getChampion(actor.championId).element));
    const hasPressure=result.some((actor,i)=>i!==index&&actor.loadout.some(id=>getSpell(id).damage>=2));
    const pool=shuffled(CREATURES.filter(creature=>creature.strengthClass===strengthClass&&creature.elements.length<=2&&(!promote||creature.elements.includes(primary))&&!result.some(actor=>actor.creatureId===creature.id)&&(!otherElements.has(getChampion(creature.championId).element)||floor>2)&&(hasPressure||creature.loadout.some(id=>getSpell(id).damage>=2))),`${salt}:roles`);
    pool.sort((a,b)=>Number(getChampion(b.championId).element===primary)-Number(getChampion(a.championId).element===primary)||Number(b.role!==definition.role)-Number(a.role!==definition.role));
    const replacement=pool[promote?variant%pool.length:variant-1];
    if(replacement&&(promote||variant>0))result[index]=towerCreature(replacement.id,original.id);
   }
  }
  return result;
}
function roomAt(run:EncounterRun,lane:number,kind:TowerRoom['kind']):TowerRoom{
 const roomSeed=`${run.seed}:${run.floor}:${lane}`,entry=rooms[hash(roomSeed)%rooms.length],boss=run.floor===9;
 const camp=run.floor===3?{name:'Tea break',flavor:'The biscuits are structural. Dip carefully.'}:run.floor===6?{name:'The laundry',flavor:'Nothing here fits. The bandages will.'}:{name:'Quiet landing',flavor:'Even the stairs need a breather.'};
 const recruit=run.floor===3?{name:'Spare chair',flavor:'One vacancy. Several opinions.'}:run.floor===5?{name:'Unscheduled interview',flavor:'References optional. Teeth acceptable.'}:{name:'Team meeting',flavor:'Everyone wants a say in the route.'};
 const event=run.floor===3?{name:'Questionable tuition',flavor:'The tutor has excellent aim and no teaching licence.'}:{name:'Study group',flavor:'The textbook bit the last person.'};
 const scene=kind==='recruit'?recruit:kind==='camp'?camp:kind==='event'?event:entry;
 const battle=kind==='combat'||kind==='elite',name=boss?'The upstairs neighbours':kind==='elite'?`${entry.name} · overtime`:scene.name;
 const flavor=boss?'They have complained about every floor below.':scene.flavor;
 const environment:TowerRoom['environment']=battle?(['flooded','embers','draft','plain'] as const)[(hash(`${run.seed}:weather:${run.floor}`)+lane)%4]:'plain';
 const ground={plain:'',flooded:' Six central hexes begin flooded for two exchanges: slower passage, ready for freezing or steam.',embers:' Six central hexes burn for two exchanges: hazardous footing, ready for an elemental mix.',draft:' Six central hexes carry a two-exchange current: extra movement when starting there.'}[environment];
 const description=(boss?'Defeat the entire opposing party to clear the tower.':kind==='elite'?'Hard fight. Choose a spell, up to 2 affinity, or recovery after victory.':kind==='combat'?'Win a spell, affinity, or recovery. All allies recover 1 health after victory.':kind==='recruit'?'Invite a champion or creature. Party limit: 3.':kind==='camp'?(run.floor===6?'Recover health, train, or recruit a sturdier elemental companion.':'Recover health, train an affinity, or study a spell.'):'Your first fighter spends 2 health. Choose a spell, up to 2 affinity, or an available recruit. Requires at least 3 health.')+ground;
  const motif=run.encounterModel==='motifs44'?TOWER_MOTIFS[(hash(`${run.seed}:motif:${run.floor}`)+lane)%TOWER_MOTIFS.length]:undefined;
  const mapId=`arena:2:TOWER-${hash(roomSeed).toString(36).toUpperCase()}-${run.floor}${motif?`:m44-${motif}`:''}`;
  return {id:`floor-${run.floor}-${lane}`,floor:run.floor,kind,name,flavor,description:description+(motif&&battle?` ${TOWER_MOTIF_INFO[motif].detail}`:''),enemies:battle?battleEnemies(run,lane,kind==='elite'):[],mapId,environment};
}
/** Every displayed fork is reproducible from the seed, including its enemy preview. */
export function towerFloorRooms(run:TowerRun):TowerRoom[]{
 if(run.phase!=='route')return [];
 if(run.floor===9)return [roomAt(run,0,'combat')];
 const kinds:TowerRoom['kind'][]=run.floor===3?['recruit','camp','event']:run.floor===6?['camp','recruit','event']:['combat','elite',run.floor===5?'recruit':run.floor===8?'camp':'combat'];
 return Array.from({length:towerBranchCount(run.routePlayers)},(_,lane)=>roomAt(run,lane,kinds[lane%kinds.length]));
}
export function towerRoomChoices(run:TowerRun):TowerRoom[]{
 const reachable=new Set(reachableTowerRooms(run.seed,run.floor,run.history,run.routePlayers));
 return towerFloorRooms(run).filter(room=>reachable.has(room.id));
}
export function chooseTowerRoom(run:TowerRun,roomId:string):TowerRun{
 const current=validateTowerRun(run);if(current.phase!=='route')throw new Error('Finish this room first.');
 const room=towerRoomChoices(current).find(candidate=>candidate.id===roomId);if(!room)throw new Error('Choose one of the available rooms.');
 const tuitionIds=[towerTuitionActor(current).id],tuition=2;
 if(room.kind==='event'&&current.party.some(actor=>tuitionIds.includes(actor.id)&&actor.hp<=tuition))throw new Error('The first fighter needs at least 3 health for tuition.');
 const party=room.kind==='event'?current.party.map(actor=>tuitionIds.includes(actor.id)?{...actor,hp:actor.hp-tuition}:actor):current.party;
 return {...current,party,currentRoom:room,phase:room.enemies.length?'battle':'reward'};
}
function runLibrary(run:TowerRun):string[]{return run.learnedSpells.filter(id=>teachable.has(id));}
export function towerBattleConfig(run:TowerRun):TowerBattleConfig{
 if(run.phase!=='battle'||!run.currentRoom?.enemies.length)throw new Error('This room has no battle.');
 return validateTowerBattleConfig({id:`tower:${run.seed}:${run.currentRoom.id}`,mapId:run.currentRoom.mapId,allies:clone(run.party),enemies:clone(run.currentRoom.enemies),learnedSpells:runLibrary(run),mode:run.mode,controllers:Object.fromEntries(run.party.map(actor=>[actor.id,towerController(run,actor.id)])),encounter:run.floor===9?'boss':run.currentRoom.kind==='elite'?'elite':'combat',environment:run.currentRoom.environment});
}
export function finishTowerBattle(run:TowerRun,input:unknown):TowerRun{
 const current=validateTowerRun(run),battle=restoreSimState(input);
 if(current.phase!=='battle'||JSON.stringify(battle.tower)!==JSON.stringify(towerBattleConfig(current)))throw new Error('That battle does not belong to this room.');
 if(battle.winner===null)throw new Error('The battle is still in progress.');
 const learnedSpells=[...new Set([...current.learnedSpells,...battle.units.filter(unit=>unit.owner===1&&unit.hp===0).map(unit=>teachingForEnemy(unit).id)])].sort();
 if(battle.winner!==0)return {...current,learnedSpells,party:current.party.map(actor=>({...carryTowerSupplies(actor,battle.units.find(unit=>unit.owner===0&&unit.id===actor.id)!.spentScroll),hp:battle.units.find(unit=>unit.owner===0&&unit.id===actor.id)!.hp})),phase:'lost'};
 const party=current.party.map(actor=>{const unit=battle.units.find(candidate=>candidate.id===actor.id&&candidate.owner===0);if(!unit)throw new Error('A party member is missing from this battle.');return {...carryTowerSupplies(actor,unit.spentScroll),hp:Math.min(actor.maxHp??8,unit.hp+1)};});
 return {...current,party,learnedSpells,phase:current.floor===TOWER_FLOORS?'won':'reward',...(current.floor===TOWER_FLOORS?{history:[...current.history,current.currentRoom!]}:{})};
}
function trainingRewards(run:TowerRun,count:number):TowerReward[]{
 const choices:TowerReward[]=[];
 for(const actor of run.party.filter(candidate=>!candidate.creatureId)){
  const primary=getChampion(actor.championId).element;
  for(const element of elements.filter(element=>(actor.affinities[element]??0)>0||Object.keys(actor.affinities).length<3)){
   const rank=actor.affinities[element]??0,amount=Math.min(count,6-rank,18-affinityTotal(actor.affinities),element===primary?6:(actor.affinities[primary]??0)-rank);
   if(amount<=0)continue;
   if(rank===0&&!run.learnedSpells.some(id=>getSpell(id).element===element&&spellAccess(actor.championId,id,{...actor.affinities,[element]:amount},runLibrary(run)).unlocked))continue;
   choices.push({id:`train:${actor.id}:${element}`,kind:'train',name:`${title(element)} practice`,actorId:actor.id,element,amount,description:`${actor.displayName}: ${title(element)} ${rank} → ${rank+amount}. Existing spells scale; higher-level spells become eligible for drafts.`});
  }
 }
 // One displayed training slot must improve a real kit. Keep secondary options
 // in the pool, but first offer a signature affinity while it can still grow.
 return shuffled(choices,`${run.seed}:${run.floor}:${run.currentRoom?.id}:training`).sort((a,b)=>Number(b.element===getChampion(run.party.find(actor=>actor.id===b.actorId)!.championId).element)-Number(a.element===getChampion(run.party.find(actor=>actor.id===a.actorId)!.championId).element));
}
function spellRewards(run:TowerRun):TowerReward[]{
 const heroes=run.party.filter(actor=>!actor.creatureId),owned=new Set(run.learnedSpells);
 const candidates=ALL_SPELLS.filter(spell=>!owned.has(spell.id)&&heroes.some(actor=>spellAccess(actor.championId,spell.id,actor.affinities,[...runLibrary(run),...(teachable.has(spell.id)?[spell.id]:[])]).unlocked&&spellCost(actor.championId,spell.id,actor.affinities)<=(actor.maxFlux??6)));
 const preferred=new Set(run.currentRoom?.enemies.flatMap(actor=>actor.creatureId?[getCreature(actor.creatureId).loadout[0]]:[getSignature(actor.championId).id]));
 return shuffled(candidates,`${run.seed}:${run.floor}:${run.currentRoom?.id}:spells`).sort((a,b)=>Number(preferred.has(b.id))-Number(preferred.has(a.id))).map(spell=>{const actor=heroes.find(actor=>spellAccess(actor.championId,spell.id,actor.affinities,[...runLibrary(run),...(teachable.has(spell.id)?[spell.id]:[])]).unlocked&&spellCost(actor.championId,spell.id,actor.affinities)<=(actor.maxFlux??6))!;return {id:`spell:${spell.id}`,kind:'spell',name:spell.name,spellId:spell.id,actorId:actor.id,description:`Learn for this run. ${actor.displayName} can equip it: ${spellCost(actor.championId,spell.id,actor.affinities)} Flux · ${title(spell.element)} ${spell.level}.`};});
}
function recruitRewards(run:TowerRun):TowerReward[]{
 const owned=new Set(run.party.map(actor=>actor.creatureId??actor.championId)),seed=`${run.seed}:${run.floor}:${run.currentRoom?.id}:recruits`;
 const champions=shuffled(CHAMPIONS.filter(champion=>!owned.has(champion.id)),`${seed}:champions`).slice(0,2).map((champion,index)=>towerChampion(champion.id,`recruit-${run.floor}-${index}`,run.floor>=6?7:5));
  const creatures=shuffled(CREATURES.filter(creature=>!owned.has(creature.id)&&creature.strengthClass===(run.floor>=6?'greater':'standard')),`${seed}:creatures`);
  if(run.encounterModel==='motifs44'){
   const current=run.party.flatMap(actor=>actor.creatureId?[actor.creatureId]:[]),before=new Set(teamPerkEffects(current).perkIds);
   const parties=run.party.length<3?[run.party]:towerReplaceableActors(run).map(replaced=>run.party.filter(actor=>actor.id!==replaced.id));
   const benefit=(id:string)=>Math.max(...parties.map(party=>{const after=teamPerkEffects([...party.flatMap(actor=>actor.creatureId?[actor.creatureId]:[]),id]).perkIds;return after.filter(id=>!before.has(id)).length-[...before].filter(id=>!after.includes(id)).length;}));
   creatures.sort((a,b)=>benefit(b.id)-benefit(a.id));
  }
 const actors=[champions[0],towerCreature(creatures[0].id,`recruit-${run.floor}-creature`),champions[1]];
 return actors.map(actor=>({id:`recruit:${actor.creatureId??actor.championId}`,kind:'recruit',name:actor.displayName!,actor,description:`${actor.hp} health · ${Object.entries(actor.affinities).map(([element,rank])=>`${title(element)} ${rank}`).join(' / ')}. ${run.party.length<3?'Joins your party.':'Replaces one recruit or creature; starting champions stay.'}`}));
}
function campCompanion(run:TowerRun):TowerReward|undefined {
 if(run.floor!==6)return;
 const younger=run.party.filter(actor=>actor.creatureId&&getCreature(actor.creatureId).strengthClass==='lesser').sort((a,b)=>(a.maxHp??8)-(b.maxHp??8)||a.id.localeCompare(b.id))[0];
 if(!younger)return;
 const primary=getChampion(younger.championId).element,pool=CREATURES.filter(creature=>creature.strengthClass==='standard'&&getChampion(creature.championId).element===primary&&!run.party.some(actor=>actor.creatureId===creature.id));
 const creature=shuffled(pool,`${run.seed}:camp-companion:${primary}`)[0];if(!creature)return;
 const actor=towerCreature(creature.id,'camp-6-companion');
 return {id:`recruit:${creature.id}`,kind:'recruit',name:creature.name,actor,description:`A sturdier companion: ${actor.maxHp} health, ${affinityTotal(actor.affinities)} affinity. Replaces a companion and teaches its native kit. Founding champions stay.`};
}
export function towerSupplyReward(run:TowerRun):TowerReward|undefined {
 if(run.suppliesModel!=='v45'||!run.currentRoom||!['combat','elite'].includes(run.currentRoom.kind)||![1,2,4,7,8].includes(run.floor))return;
 const salt=`${run.seed}:${run.floor}:${run.currentRoom?.id}:supply`;
 if(run.floor%2===1){const pool=TOWER_CHARMS.filter(item=>!run.party.every(actor=>actor.charmId===item.id)),item=shuffled(pool,salt)[0];if(item)return {id:`charm:${item.id}`,kind:'charm',charmId:item.id,name:item.name,description:item.description};}
 const pool=TOWER_SCROLLS.filter(id=>!run.party.every(actor=>actor.scrollSpellId===id)),id=shuffled(pool,salt)[0];
 if(id)return {id:`scroll:${id}`,kind:'scroll',spellId:id,name:`${getSpell(id).name} scroll`,description:'One cast · 0 Flux · any affinity. Uses your cast action. Printed strength; consumed on release.'};
}
export function towerRewardChoices(run:TowerRun):TowerReward[]{
 if(run.phase!=='reward'||!run.currentRoom)return [];
 const kind=run.currentRoom.kind;if(kind==='recruit')return recruitRewards(run);
 const train=trainingRewards(run,kind==='elite'||kind==='event'?2:1),spells=spellRewards(run),missing=run.party.reduce((sum,actor)=>sum+(actor.maxHp??8)-actor.hp,0);
 const heal:TowerReward={id:'heal:party',kind:'heal',name:kind==='camp'?'Bandages & biscuits':'Catch your breath',amount:kind==='camp'?4:3,description:`Each ally recovers up to ${kind==='camp'?4:3} health. ${missing} health missing across the party.`};
 const companion=kind==='camp'?campCompanion(run):undefined;
 const choices:TowerReward[]=kind==='camp'?[...(missing?[heal]:[]),...train.slice(0,1),...(companion?[companion]:[]),...spells.slice(0,1),...train.slice(1),...spells.slice(1)]:kind==='event'?[...spells.slice(0,2),...train]:[...spells.slice(0,1),...train.slice(0,1),...(missing?[heal]:[]),...spells.slice(1),...train.slice(1)];
 // Native creature kits do not accept spell drafts or affinity training. Offer
 // real recruits instead of an empty reward page (or useless full-health heal).
 if(!run.party.some(actor=>!actor.creatureId))choices.push(...recruitRewards(run));
 if(choices.length===0)choices.push(...recruitRewards(run));
 const supply=towerSupplyReward(run);if(supply){const recovery=choices.find(choice=>choice.kind==='heal'),first=choices.find(choice=>choice.kind==='train')??choices[0],second=recovery&&recovery!==first?recovery:choices.find(choice=>choice!==first);choices.splice(0,choices.length,...[first,second,supply].filter((choice):choice is TowerReward=>!!choice));}
 return choices.filter((choice,index,array)=>array.findIndex(candidate=>candidate.id===choice.id)===index).slice(0,3);
}
export function claimTowerReward(run:TowerRun,rewardId:string,replaceActorId?:string,recipientActorId?:string):TowerRun{
 const current=validateTowerRun(run);if(current.phase!=='reward')throw new Error('There is no reward to claim.');
 const reward=towerRewardChoices(current).find(choice=>choice.id===rewardId);if(!reward)throw new Error('Choose an offered reward.');
 let party=clone(current.party),learnedSpells=[...current.learnedSpells];
 if(reward.kind==='charm'||reward.kind==='scroll'){const actor=party.find(actor=>actor.id===recipientActorId);if(!actor)throw new Error('Choose a fighter for this supply.');if(reward.kind==='charm')actor.charmId=reward.charmId!;else actor.scrollSpellId=reward.spellId!;}else if(recipientActorId!==undefined)throw new Error('This reward does not need a supply recipient.');
 if(reward.kind==='spell')learnedSpells.push(reward.spellId!);
 if(reward.kind==='heal')party=party.map(actor=>({...actor,hp:Math.min(actor.maxHp??8,actor.hp+reward.amount!)}));
 if(reward.kind==='train')party=party.map(actor=>actor.id===reward.actorId?{...actor,affinities:{...actor.affinities,[reward.element!]:(actor.affinities[reward.element!]??0)+reward.amount!}}:actor);
 if(reward.kind==='recruit'){
  if(party.length===3){const replaceable=new Set(towerReplaceableActors(current).map(actor=>actor.id)),index=party.findIndex(actor=>actor.id===replaceActorId&&replaceable.has(actor.id));if(index<0)throw new Error('Choose a recruit or creature to replace. Starting champions stay.');party.splice(index,1);}
  party.push(clone(reward.actor!));learnedSpells.push(...kitSpells([reward.actor!]));
 }
 const advanced={...current};delete advanced.scouting;
 return validateTowerRun({...advanced,party,learnedSpells:[...new Set(learnedSpells)].sort(),floor:current.floor+1,phase:'route',history:[...current.history,current.currentRoom!],currentRoom:null});
}
export function towerAvailableSpells(run:TowerRun,actorId:string):Spell[]{
 const actor=run.party.find(candidate=>candidate.id===actorId);if(!actor)throw new Error('Choose a party member.');
 if(actor.creatureId)return actor.loadout.map(getSpell);
 const signature=getSignature(actor.championId).id;
 return run.learnedSpells.filter(id=>id!==signature&&spellAccess(actor.championId,id,actor.affinities,runLibrary(run)).unlocked).map(getSpell);
}
export function updateTowerLoadout(run:TowerRun,actorId:string,loadout:readonly string[]):TowerRun{
 const current=validateTowerRun(run);if(current.phase!=='route')throw new Error('Change spells between rooms.');
 const actor=current.party.find(candidate=>candidate.id===actorId);if(!actor||actor.creatureId)throw new Error('Creatures keep their own spell kits.');
 if(loadout.some(id=>!current.learnedSpells.includes(id)))throw new Error('That spell has not been learned in this run.');
 const next=validateLoadout(actor.championId,loadout,actor.affinities,runLibrary(current));return {...current,party:current.party.map(candidate=>candidate.id===actorId?{...candidate,loadout:next}:candidate)};
}
export function updateTowerBuild(run:TowerRun,actorId:string,build:TowerBuild):TowerRun {
 const current=validateTowerRun(run);if(current.phase!=='route')throw new Error('Change builds between rooms.');
 const actor=current.party.find(candidate=>candidate.id===actorId);if(!actor||actor.creatureId)throw new Error('Creatures keep their own affinities and spells.');
 if(build.championId!==actor.championId)throw new Error('A champion keeps their appearance and signature throughout the climb.');
 const next=validateTowerBuild(build,affinityTotal(actor.affinities),runLibrary(current));
 if(next.loadout.some(id=>!current.learnedSpells.includes(id)))throw new Error('Equip spells already learned in this run.');
 return validateTowerRun({...current,party:current.party.map(candidate=>candidate.id===actorId?{...candidate,displayName:next.name,affinities:next.affinities,loadout:next.loadout}:candidate)});
}
/** Checkpoint sharing changes knowledge only; access and equipped slots remain local. */
export function shareTowerSpells(run:TowerRun,spellIds:readonly string[]):TowerRun {
 const current=validateTowerRun(run);
 if(current.phase!=='won'&&(current.phase!=='route'||current.floor===1))throw new Error('Share spells after completing a floor.');
 if(!Array.isArray(spellIds)||spellIds.length>ALL_SPELLS.length*6||spellIds.some(id=>typeof id!=='string'||!knownSpells.has(id)))throw new Error('The shared spell library is invalid.');
 return validateTowerRun({...current,learnedSpells:[...new Set([...current.learnedSpells,...spellIds])].sort()});
}
/** Strict structural validation; unknown saves are rejected rather than silently starting over. */
export function validateTowerRun(input:unknown):TowerRun{
 if(!plain(input)||input.format!==3||Object.keys(input).some(key=>!['format','mode','suppliesModel','starts','seed','starterId','floor','phase','party','learnedSpells','history','currentRoom','scouting','routePlayers','encounterModel','encounterVariant'].includes(key)))throw new Error('This tower run could not be read.');
 if(input.suppliesModel!==undefined&&input.suppliesModel!=='v45')throw new Error('Unsupported tower supplies.');
 if(input.encounterModel!==undefined&&input.encounterModel!=='motifs44'||input.encounterVariant!==undefined&&(![0,1,2].includes(input.encounterVariant as number)||input.encounterModel!=='motifs44'))throw new Error('Unsupported tower encounter generation.');
 if(typeof input.seed!=='string'||seedText(input.seed)!==input.seed||!allStarterPresets.some(starter=>starter.id===input.starterId)||!Number.isSafeInteger(input.floor)||(input.floor as number)<1||(input.floor as number)>TOWER_FLOORS||!['route','battle','reward','won','lost'].includes(input.phase as string))throw new Error('Tower route is invalid.');
 if(!Array.isArray(input.party)||input.party.length<2||input.party.length>3||!Array.isArray(input.learnedSpells)||input.learnedSpells.length>ALL_SPELLS.length||new Set(input.learnedSpells).size!==input.learnedSpells.length||input.learnedSpells.some(id=>typeof id!=='string'||!knownSpells.has(id)))throw new Error('Tower party or spell library is invalid.');
 if(input.routePlayers!==undefined)towerBranchCount(input.routePlayers as number);
 const run=input as unknown as TowerRun;
 if(run.mode!=='solo'||!Array.isArray(run.starts)||run.starts.length!==1)throw new Error('Invalid tower founders.');
 const starts:[TowerStart]=[validateTowerStarter(run.starts[0])];
 if(starts[0].starterId!==run.starterId||starts[0].members.some((member,index)=>{if(member.kind==='creature')return false;const actor=run.party.find(actor=>actor.id===(index?'companion':'hero'));return !actor||actor.championId!==member.build.championId||actor.creatureId;}))throw new Error('Starting champions must stay with the party.');
 if(run.phase==='lost'&&run.party.some(actor=>actor.hp!==0))throw new Error('A lost run must have a defeated party.');
 if(run.party.some(actor=>(actor.charmId||actor.scrollSpellId)&&run.suppliesModel!=='v45'))throw new Error('Supplies do not belong to this run.');
 const config=validateTowerBattleConfig({id:'tower-validation',mapId:'arena:2:TOWER-CHECK',allies:run.phase==='lost'?run.party.map(actor=>({...actor,hp:1})):run.party,enemies:[towerCreature('creature-fire-cinder','check-enemy')],learnedSpells:runLibrary(run)});
 if(run.floor===1&&run.phase==='route'){
  const initial=starts[0].members.map((member,index)=>memberActor(member,index?'companion':'hero'));
  if(config.allies.length!==2||config.allies.some((actor,index)=>{const original=initial[index];return !!actor.charmId||!!actor.scrollSpellId||actor.id!==original.id||actor.championId!==original.championId||actor.creatureId!==original.creatureId||actor.hp!==original.hp||affinityTotal(actor.affinities)!==affinityTotal(original.affinities);})||JSON.stringify([...run.learnedSpells].sort())!==JSON.stringify(kitSpells(initial)))throw new Error('A new climb must match its chosen starting pair.');
 }
 if(config.allies.some(actor=>actor.loadout.some(id=>!run.learnedSpells.includes(id))))throw new Error('A prepared spell is missing from the run library.');
 if(new Set(run.party.map(actor=>actor.creatureId??actor.championId)).size!==run.party.length)throw new Error('Each party member must be different.');
 const completed=run.phase==='won'?9:run.floor-1;
 if(!Array.isArray(run.history)||run.history.length!==completed)throw new Error('Tower room history is incomplete.');
 const roomMechanics=(room:TowerRoom)=>JSON.stringify({id:room.id,floor:room.floor,kind:room.kind,enemies:room.enemies,mapId:room.mapId,environment:room.environment});
 const history:TowerRoom[]=[];let currentRoom:TowerRoom|null=null;
 for(let index=0;index<run.history.length;index++){
  const historical=run.history[index],expected=towerFloorRooms({...run,floor:index+1,phase:'route'}).find(room=>room.id===historical?.id);
  if(!expected||roomMechanics(expected)!==roomMechanics(historical))throw new Error('Tower room history changed.');history.push(expected);
 }
 if(run.phase==='route'){if(run.currentRoom!==null)throw new Error('A route choice is already pending.');}
 else {const expected=towerFloorRooms({...run,phase:'route'}).find(room=>room.id===run.currentRoom?.id);if(!expected||roomMechanics(expected)!==roomMechanics(run.currentRoom!))throw new Error('This room is not on the tower route.');if(['battle','lost','won'].includes(run.phase)&&!expected.enemies.length)throw new Error('This room has no battle.');if(run.phase==='won'&&run.floor!==9)throw new Error('The tower is not cleared yet.');currentRoom=expected;}
 const scouting=run.scouting===undefined?undefined:validateFloorScouting(run,towerFloorRooms({...run,phase:'route'}),run.scouting);
 // Prose is presentation, not save identity: future copy edits must not erase a climb.
 return clone({...run,starts,party:config.allies.map(actor=>run.phase==='lost'?{...actor,hp:0}:actor),history,currentRoom,...(scouting?{scouting}:{})});
}
function restoredPlan(state:SimState,input:unknown):TeamPlan{
 if(state.winner!==null)return {orders:[]};
 try{const checked=validatePlan(state,0,input),supplied=plain(input)&&Array.isArray(input.orders)?new Set(input.orders.filter(plain).map(order=>order.unitId)):new Set();return {orders:checked.orders.filter(order=>supplied.has(order.unitId)),...(checked.link!==undefined?{link:checked.link}:{})};}catch{return {orders:[]}}
}
export function createTowerSession(run:TowerRun,battle:SimState|null=null,plan:TeamPlan={orders:[]},previous?:SimState):TowerSession{
 const current=validateTowerRun(run);if(current.phase!=='battle'){if(battle!==null)throw new Error('This room does not accept a pending battle.');return {format:3,run:current,battle:null,plan:{orders:[]}};}
 const state=battle?restoreSimState(battle):createTowerBattle(towerBattleConfig(current));
 if(JSON.stringify(state.tower)!==JSON.stringify(towerBattleConfig(current)))throw new Error('This battle belongs to another tower room.');
 let prior:SimState|undefined;try{if(previous){const restored=restoreSimState(previous);if(restored.winner===null&&restored.version+1===state.version&&JSON.stringify(restored.tower)===JSON.stringify(state.tower))prior=restored;}}catch{}
 return {format:3,run:current,battle:state,plan:restoredPlan(state,plan),...(prior?{previous:prior}:{})};
}
export function restoreTowerSession(input:unknown):TowerSession{
 let value=input;if(typeof value==='string'){if(value.length>8000000)throw new Error('This tower save is too large.');try{value=JSON.parse(value)}catch{throw new Error('This tower save is not valid JSON.');}}
 if(!plain(value)||value.format!==3||Object.keys(value).some(key=>!['format','run','battle','plan','previous'].includes(key)))throw new Error('Unsupported tower save.');
 const run=validateTowerRun(value.run);
 if(run.phase==='battle'){if(!plain(value.battle))throw new Error('The pending tower battle is missing.');return createTowerSession(run,restoreSimState(value.battle),value.plan as TeamPlan,value.previous as SimState|undefined);}
 if(value.battle!==null)throw new Error('This tower save contains an unexpected battle.');return createTowerSession(run);
}

/** Swaps existing slots between rooms; never creates an extra copy. */
export function transferTowerSupply(run:TowerRun,fromId:string,toId:string,slot:'charm'|'scroll'):TowerRun {
 const current=validateTowerRun(run);if(current.phase!=='route'||current.suppliesModel!=='v45')throw new Error('Move supplies between rooms.');
 if(!['charm','scroll'].includes(slot)||fromId===toId)throw new Error('Choose another fighter.');
 const party=clone(current.party),from=party.find(actor=>actor.id===fromId),to=party.find(actor=>actor.id===toId),key=slot==='charm'?'charmId':'scrollSpellId';
 if(!from||!to||!from[key])throw new Error('Choose an equipped supply and a party member.');
 const old=to[key];(to as Record<string,unknown>)[key]=from[key];if(old)(from as Record<string,unknown>)[key]=old;else delete from[key];
 return validateTowerRun({...current,party});
}
