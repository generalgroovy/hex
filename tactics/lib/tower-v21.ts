/** A run owns its party, spell library and wounds. Campaign progress never enters the tower. */
import type {Element} from './game.ts';
import {CHAMPIONS,getChampion,allocateAffinityBudget,affinityTotal,type AffinityAllocation} from './roster-v13.ts';
import {CREATURES,getCreature} from './campaign-creatures-v20.ts';
import {ALL_SPELLS,TEACHABLE_SPELLS,getSpell,getSignature,teachingForEnemy,defaultLoadout,spellAccess,spellCost,validateLoadout,type Spell} from './spells-v20.ts';
import {createTowerBattle,restoreSimState,validateTowerBattleConfig,validatePlan,type TowerActor,type TowerBattleConfig,type SimState,type TeamPlan} from './tactics-v21.ts';
export type {TowerActor} from './tactics-v21.ts';

export const TOWER_SESSION_KEY='hex-confluence-tower-v21';
export const TOWER_FLOORS=9;
export type TowerPhase='route'|'battle'|'reward'|'won'|'lost';
export type TowerRoom={id:string;floor:number;kind:'combat'|'elite'|'recruit'|'camp'|'event';name:string;flavor:string;description:string;enemies:TowerActor[];mapId:string};
export type TowerRun={format:1;seed:string;starterId:string;floor:number;phase:TowerPhase;party:TowerActor[];learnedSpells:string[];history:TowerRoom[];currentRoom:TowerRoom|null};
export type TowerReward={id:string;kind:'spell'|'train'|'heal'|'recruit';name:string;description:string;flavor?:string;spellId?:string;actorId?:string;element?:Element;amount?:number;actor?:TowerActor};
export type TowerSession={format:1;run:TowerRun;battle:SimState|null;plan:TeamPlan;previous?:SimState};
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
export const TOWER_STARTERS=[
 {id:'steam',name:'Oh Tipi & Cinder',description:'Water controls the ground. Fire turns it into cover.',heroId:'oh_tipi',companionId:'creature-fire-cinder',party:[towerChampion('oh_tipi','hero'),towerCreature('creature-fire-cinder','companion')]},
 {id:'stone',name:'Treevor & Puddle',description:'Earth holds a lane. Water keeps the front line standing.',heroId:'treevor_mason',companionId:'creature-water-puddle',party:[towerChampion('treevor_mason','hero'),towerCreature('creature-water-puddle','companion')]},
 {id:'dusk',name:'S. Wayne & Wick',description:'Dark weakens the enemy. Light patches up the consequences.',heroId:'s_wayne',companionId:'creature-light-wick',party:[towerChampion('s_wayne','hero'),towerCreature('creature-light-wick','companion')]},
] as const;
function kitSpells(party:readonly TowerActor[]):string[]{return [...new Set(party.flatMap(actor=>[...actor.loadout,...(!actor.creatureId?[getSignature(actor.championId).id]:[])]))].sort();}
export function createTowerRun(seed:string,starterId:string):TowerRun{const starter=TOWER_STARTERS.find(candidate=>candidate.id===starterId);if(!starter)throw new Error('Choose a starting pair.');const party=clone(starter.party) as unknown as TowerActor[];return {format:1,seed:seedText(seed),starterId,floor:1,phase:'route',party,learnedSpells:kitSpells(party),history:[],currentRoom:null};}
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
function battleEnemies(run:Pick<TowerRun,'seed'|'floor'>,lane:number,elite:boolean):TowerActor[]{
 const salt=`${run.seed}:floor:${run.floor}:lane:${lane}`,floor=run.floor;
 const lesser=shuffled(CREATURES.filter(creature=>creature.strengthClass==='lesser'),`${salt}:lesser`),standard=shuffled(CREATURES.filter(creature=>creature.strengthClass==='standard'),`${salt}:standard`);
 const champions=shuffled(CHAMPIONS,`${salt}:champion`),result:TowerActor[]=[];
 const addCreature=(id:string)=>result.push(towerCreature(id,`enemy-${result.length}`));
 const addChampion=(index:number,budget:number)=>result.push(towerChampion(champions[index].id,`enemy-${result.length}`,budget));
 if(floor<=2){
  const first=lesser[0],primary=getChampion(first.championId).element,pool=elite?standard:lesser;
  // Early pairs need two elemental identities and a source of pressure. Two
  // pure healers/warders otherwise teach waiting for collapse, not combat.
  const attacks=(creature:typeof first)=>creature.loadout.some(id=>getSpell(id).damage>0);
  const second=pool.find(creature=>getChampion(creature.championId).element!==primary&&(attacks(first)||attacks(creature)))!;
  addCreature(first.id);addCreature(second.id);
 }
 else if(floor<=5){addChampion(0,5+Number(elite));addCreature((elite?standard[0]:lesser[0]).id);if(floor===5&&elite)addCreature(lesser[1].id);}
 else if(floor<9){addChampion(0,7+Number(elite));addCreature(standard[0].id);addCreature((elite?standard[1]:lesser[0]).id);}
 else{addChampion(0,8);addChampion(1,7);addCreature(standard[0].id);}
 return result;
}
function roomAt(run:Pick<TowerRun,'seed'|'floor'>,lane:number,kind:TowerRoom['kind']):TowerRoom{
 const roomSeed=`${run.seed}:${run.floor}:${lane}`,entry=rooms[hash(roomSeed)%rooms.length],boss=run.floor===9;
 const camp=run.floor===3?{name:'Tea break',flavor:'The biscuits are structural. Dip carefully.'}:run.floor===6?{name:'The laundry',flavor:'Nothing here fits. The bandages will.'}:{name:'Quiet landing',flavor:'Even the stairs need a breather.'};
 const recruit=run.floor===3?{name:'Spare chair',flavor:'One vacancy. Several opinions.'}:run.floor===5?{name:'Unscheduled interview',flavor:'References optional. Teeth acceptable.'}:{name:'Team meeting',flavor:'Everyone wants a say in the route.'};
 const event=run.floor===3?{name:'Questionable tuition',flavor:'The tutor has excellent aim and no teaching licence.'}:{name:'Study group',flavor:'The textbook bit the last person.'};
 const scene=kind==='recruit'?recruit:kind==='camp'?camp:kind==='event'?event:entry;
 const battle=kind==='combat'||kind==='elite',name=boss?'The upstairs neighbours':kind==='elite'?`${entry.name} · overtime`:scene.name;
 const flavor=boss?'They have complained about every floor below.':scene.flavor;
 const description=boss?'Defeat the entire opposing party to clear the tower.':kind==='elite'?'Hard fight. Choose a spell, up to 2 affinity, or recovery after victory.':kind==='combat'?'Win a spell, affinity, or recovery. Survivors and fallen allies recover 1 health.':kind==='recruit'?'Invite a champion or creature. Party limit: 3.':kind==='camp'?'Recover health, train an affinity, or study a spell.': 'Starting champion spends 2 health. Choose a spell or train an affinity. Requires at least 3 health.';
 return {id:`floor-${run.floor}-${lane}`,floor:run.floor,kind,name,flavor,description,enemies:battle?battleEnemies(run,lane,kind==='elite'):[],mapId:`arena:2:TOWER-${hash(roomSeed).toString(36).toUpperCase()}-${run.floor}`};
}
/** Every displayed fork is reproducible from the seed, including its enemy preview. */
export function towerRoomChoices(run:TowerRun):TowerRoom[]{
 if(run.phase!=='route')return [];
 if(run.floor===9)return [roomAt(run,0,'combat')];
 if(run.floor===3)return [roomAt(run,0,'recruit'),roomAt(run,1,'camp'),roomAt(run,2,'event')];
 if(run.floor===6)return [roomAt(run,0,'camp'),roomAt(run,1,'recruit'),roomAt(run,2,'event')];
 return [roomAt(run,0,'combat'),roomAt(run,1,'elite'),roomAt(run,2,run.floor===5?'recruit':run.floor===8?'camp':'combat')];
}
export function chooseTowerRoom(run:TowerRun,roomId:string):TowerRun{
 const current=validateTowerRun(run);if(current.phase!=='route')throw new Error('Finish this room first.');
 const room=towerRoomChoices(current).find(candidate=>candidate.id===roomId);if(!room)throw new Error('Choose one of the available rooms.');
 if(room.kind==='event'&&current.party[0].hp<3)throw new Error('Your starting champion needs at least 3 health for tuition.');
 const party=room.kind==='event'?current.party.map((actor,index)=>index===0?{...actor,hp:actor.hp-2}:actor):current.party;
 return {...current,party,currentRoom:room,phase:room.enemies.length?'battle':'reward'};
}
function runLibrary(run:TowerRun):string[]{return run.learnedSpells.filter(id=>teachable.has(id));}
export function towerBattleConfig(run:TowerRun):TowerBattleConfig{
 if(run.phase!=='battle'||!run.currentRoom?.enemies.length)throw new Error('This room has no battle.');
 return validateTowerBattleConfig({id:`tower:${run.seed}:${run.currentRoom.id}`,mapId:run.currentRoom.mapId,allies:clone(run.party),enemies:clone(run.currentRoom.enemies),learnedSpells:runLibrary(run)});
}
export function finishTowerBattle(run:TowerRun,input:unknown):TowerRun{
 const current=validateTowerRun(run),battle=restoreSimState(input);
 if(current.phase!=='battle'||JSON.stringify(battle.tower)!==JSON.stringify(towerBattleConfig(current)))throw new Error('That battle does not belong to this room.');
 if(battle.winner===null)throw new Error('The battle is still in progress.');
 const learnedSpells=[...new Set([...current.learnedSpells,...battle.units.filter(unit=>unit.owner===1&&unit.hp===0).map(unit=>teachingForEnemy(unit).id)])].sort();
 if(battle.winner!==0)return {...current,learnedSpells,party:current.party.map(actor=>({...actor,hp:battle.units.find(unit=>unit.owner===0&&unit.id===actor.id)!.hp})),phase:'lost'};
 const party=current.party.map(actor=>{const unit=battle.units.find(candidate=>candidate.id===actor.id&&candidate.owner===0);if(!unit)throw new Error('A party member is missing from this battle.');return {...actor,hp:Math.min(actor.maxHp??8,unit.hp+1)};});
 return {...current,party,learnedSpells,phase:current.floor===TOWER_FLOORS?'won':'reward',...(current.floor===TOWER_FLOORS?{history:[...current.history,current.currentRoom!]}:{})};
}
function trainingRewards(run:TowerRun,count:number):TowerReward[]{
 const choices:TowerReward[]=[];
 for(const actor of run.party.filter(candidate=>!candidate.creatureId)){
  const primary=getChampion(actor.championId).element;
  for(const element of elements.filter(element=>(actor.affinities[element]??0)>0)){
   const rank=actor.affinities[element]??0,amount=Math.min(count,6-rank,18-affinityTotal(actor.affinities),element===primary?6:(actor.affinities[primary]??0)-rank);
   if(amount<=0)continue;
   choices.push({id:`train:${actor.id}:${element}`,kind:'train',name:`${title(element)} practice`,actorId:actor.id,element,amount,description:`${actor.displayName}: ${title(element)} ${rank} → ${rank+amount}. Existing spells scale; higher-level spells become eligible for drafts.`});
  }
 }
 return shuffled(choices,`${run.seed}:${run.floor}:${run.currentRoom?.id}:training`);
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
 const actors=[champions[0],towerCreature(creatures[0].id,`recruit-${run.floor}-creature`),champions[1]];
 return actors.map(actor=>({id:`recruit:${actor.creatureId??actor.championId}`,kind:'recruit',name:actor.displayName!,actor,description:`${actor.hp} health · ${Object.entries(actor.affinities).map(([element,rank])=>`${title(element)} ${rank}`).join(' / ')}. ${run.party.length<3?'Joins your party.':'Replaces one companion; your starting champion stays.'}`}));
}
export function towerRewardChoices(run:TowerRun):TowerReward[]{
 if(run.phase!=='reward'||!run.currentRoom)return [];
 const kind=run.currentRoom.kind;if(kind==='recruit')return recruitRewards(run);
 const train=trainingRewards(run,kind==='elite'?2:1),spells=spellRewards(run),missing=run.party.reduce((sum,actor)=>sum+(actor.maxHp??8)-actor.hp,0);
 const heal:TowerReward={id:'heal:party',kind:'heal',name:kind==='camp'?'Bandages & biscuits':'Catch your breath',amount:kind==='camp'?4:3,description:`Each ally recovers up to ${kind==='camp'?4:3} health. ${missing} health missing across the party.`};
 const choices:TowerReward[]=kind==='camp'?[...(missing?[heal]:[]),...train.slice(0,1),...spells.slice(0,1),...train.slice(1),...spells.slice(1)]:kind==='event'?[...spells.slice(0,2),...train]:[...spells.slice(0,1),...train.slice(0,1),...(missing?[heal]:[]),...spells.slice(1),...train.slice(1)];
 return choices.filter((choice,index,array)=>array.findIndex(candidate=>candidate.id===choice.id)===index).slice(0,3);
}
export function claimTowerReward(run:TowerRun,rewardId:string,replaceActorId?:string):TowerRun{
 const current=validateTowerRun(run);if(current.phase!=='reward')throw new Error('There is no reward to claim.');
 const reward=towerRewardChoices(current).find(choice=>choice.id===rewardId);if(!reward)throw new Error('Choose an offered reward.');
 let party=clone(current.party),learnedSpells=[...current.learnedSpells];
 if(reward.kind==='spell')learnedSpells.push(reward.spellId!);
 if(reward.kind==='heal')party=party.map(actor=>({...actor,hp:Math.min(actor.maxHp??8,actor.hp+reward.amount!)}));
 if(reward.kind==='train')party=party.map(actor=>actor.id===reward.actorId?{...actor,affinities:{...actor.affinities,[reward.element!]:(actor.affinities[reward.element!]??0)+reward.amount!}}:actor);
 if(reward.kind==='recruit'){
  if(party.length===3){const index=party.findIndex(actor=>actor.id===replaceActorId&&actor.id!=='hero');if(index<0)throw new Error('Choose which companion leaves to make room.');party.splice(index,1);}
  party.push(clone(reward.actor!));learnedSpells.push(...kitSpells([reward.actor!]));
 }
 return validateTowerRun({...current,party,learnedSpells:[...new Set(learnedSpells)].sort(),floor:current.floor+1,phase:'route',history:[...current.history,current.currentRoom!],currentRoom:null});
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
/** Strict structural validation; unknown saves are rejected rather than silently starting over. */
export function validateTowerRun(input:unknown):TowerRun{
 if(!plain(input)||input.format!==1||Object.keys(input).some(key=>!['format','seed','starterId','floor','phase','party','learnedSpells','history','currentRoom'].includes(key)))throw new Error('This tower run could not be read.');
 if(typeof input.seed!=='string'||seedText(input.seed)!==input.seed||!TOWER_STARTERS.some(starter=>starter.id===input.starterId)||!Number.isSafeInteger(input.floor)||(input.floor as number)<1||(input.floor as number)>TOWER_FLOORS||!['route','battle','reward','won','lost'].includes(input.phase as string))throw new Error('Tower route is invalid.');
 if(!Array.isArray(input.party)||input.party.length<2||input.party.length>3||!Array.isArray(input.learnedSpells)||input.learnedSpells.length>ALL_SPELLS.length||new Set(input.learnedSpells).size!==input.learnedSpells.length||input.learnedSpells.some(id=>typeof id!=='string'||!knownSpells.has(id)))throw new Error('Tower party or spell library is invalid.');
 const run=input as unknown as TowerRun,starter=TOWER_STARTERS.find(candidate=>candidate.id===run.starterId)!;
 if(run.party[0]?.id!=='hero'||run.party[0].championId!==starter.heroId||run.party[0].creatureId)throw new Error('The starting champion must stay with the party.');
 if(run.phase==='lost'&&run.party.some(actor=>actor.hp!==0))throw new Error('A lost run must have a defeated party.');
 const config=validateTowerBattleConfig({id:'tower-validation',mapId:'arena:2:TOWER-CHECK',allies:run.phase==='lost'?run.party.map(actor=>({...actor,hp:1})):run.party,enemies:[towerCreature('creature-fire-cinder','check-enemy')],learnedSpells:runLibrary(run)});
 if(config.allies.some(actor=>actor.loadout.some(id=>!run.learnedSpells.includes(id))))throw new Error('A prepared spell is missing from the run library.');
 if(new Set(run.party.map(actor=>actor.creatureId??actor.championId)).size!==run.party.length)throw new Error('Each party member must be different.');
 const completed=run.phase==='won'?9:run.floor-1;
 if(!Array.isArray(run.history)||run.history.length!==completed)throw new Error('Tower room history is incomplete.');
 const roomMechanics=(room:TowerRoom)=>JSON.stringify({id:room.id,floor:room.floor,kind:room.kind,enemies:room.enemies,mapId:room.mapId});
 const history:TowerRoom[]=[];let currentRoom:TowerRoom|null=null;
 for(let index=0;index<run.history.length;index++){
  const historical=run.history[index],expected=towerRoomChoices({...run,floor:index+1,phase:'route'}).find(room=>room.id===historical?.id);
  if(!expected||roomMechanics(expected)!==roomMechanics(historical))throw new Error('Tower room history changed.');history.push(expected);
 }
 if(run.phase==='route'){if(run.currentRoom!==null)throw new Error('A route choice is already pending.');}
 else {const expected=towerRoomChoices({...run,phase:'route'}).find(room=>room.id===run.currentRoom?.id);if(!expected||roomMechanics(expected)!==roomMechanics(run.currentRoom!))throw new Error('This room is not on the tower route.');if(['battle','lost','won'].includes(run.phase)&&!expected.enemies.length)throw new Error('This room has no battle.');if(run.phase==='won'&&run.floor!==9)throw new Error('The tower is not cleared yet.');currentRoom=expected;}
 // Prose is presentation, not save identity: future copy edits must not erase a climb.
 return clone({...run,party:config.allies.map(actor=>run.phase==='lost'?{...actor,hp:0}:actor),history,currentRoom});
}
function restoredPlan(state:SimState,input:unknown):TeamPlan{
 if(state.winner!==null)return {orders:[]};
 try{const checked=validatePlan(state,0,input),supplied=plain(input)&&Array.isArray(input.orders)?new Set(input.orders.filter(plain).map(order=>order.unitId)):new Set();return {orders:checked.orders.filter(order=>supplied.has(order.unitId))};}catch{return {orders:[]}}
}
export function createTowerSession(run:TowerRun,battle:SimState|null=null,plan:TeamPlan={orders:[]},previous?:SimState):TowerSession{
 const current=validateTowerRun(run);if(current.phase!=='battle'){if(battle!==null)throw new Error('This room does not accept a pending battle.');return {format:1,run:current,battle:null,plan:{orders:[]}};}
 const state=battle?restoreSimState(battle):createTowerBattle(towerBattleConfig(current));
 if(JSON.stringify(state.tower)!==JSON.stringify(towerBattleConfig(current)))throw new Error('This battle belongs to another tower room.');
 let prior:SimState|undefined;try{if(previous){const restored=restoreSimState(previous);if(restored.winner===null&&restored.version+1===state.version&&JSON.stringify(restored.tower)===JSON.stringify(state.tower))prior=restored;}}catch{}
 return {format:1,run:current,battle:state,plan:restoredPlan(state,plan),...(prior?{previous:prior}:{})};
}
export function restoreTowerSession(input:unknown):TowerSession{
 let value=input;if(typeof value==='string'){if(value.length>8000000)throw new Error('This tower save is too large.');try{value=JSON.parse(value)}catch{throw new Error('This tower save is not valid JSON.');}}
 if(!plain(value)||value.format!==1||Object.keys(value).some(key=>!['format','run','battle','plan','previous'].includes(key)))throw new Error('Unsupported tower save.');
 const run=validateTowerRun(value.run);
 if(run.phase==='battle'){if(!plain(value.battle))throw new Error('The pending tower battle is missing.');return createTowerSession(run,restoreSimState(value.battle),value.plan as TeamPlan,value.previous as SimState|undefined);}
 if(value.battle!==null)throw new Error('This tower save contains an unexpected battle.');return createTowerSession(run);
}
