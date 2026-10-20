import test from 'node:test';
import assert from 'node:assert/strict';
import {createSimGame,type SimEvent} from '../lib/tactics-v16.ts';
import {CHAMPIONS} from '../lib/roster-v11.ts';
import {CHAMPION_REACTIONS,exchangeReaction,placeCharacterSpeech,reactionLine,reactionOnCooldown,speechLines,speechRectsOverlap,type ReactionReason} from '../lib/character-reactions-v45.ts';
import {planningMaterialCells,PLANNING_MATERIAL_BUDGET} from '../lib/planning-material-v45.ts';
import {resolutionCues,instantResolutionCues,PHASE_MS} from '../lib/feedback-v16.ts';
import {materialVoices} from '../lib/game-audio-v16.ts';
const fixture=()=>{const previous=createSimGame(),next=structuredClone(previous);next.version++;next.round++;return {previous,next,unit:next.units[0],other:next.units[3]}};

test('every canonical champion has bounded character lines for each supported reaction',()=>{
 for(const champion of CHAMPIONS){
  assert.ok(CHAMPION_REACTIONS[champion.id],champion.id);
  for(const reason of ['knockout','defeat','critical','burn','flux','fizzle'] as ReactionReason[]){
   const line=reactionLine(champion.id,reason);assert.ok(line.length>3&&line.length<=31);
   assert.ok(speechLines(line).length<=2);assert.ok(speechLines(line).every(line=>line.length<=25));
  }
 }
 assert.notEqual(reactionLine('treevor_mason','burn'),reactionLine('red_baron','burn'));
 assert.equal(reactionLine('steezo','burn','fox'),'Yip?!','creatures never speak their mechanics proxy champion lines');
});
test('one deterministic reaction uses actual public results, with defeat taking priority',()=>{
 const {previous,next,unit,other}=fixture();unit.statuses.burn={turns:2,power:1};other.hp=0;
 next.lastResolution=[{kind:'surface',unitId:unit.id,status:'burn',text:''},{kind:'defeat',unitId:other.id,owner:other.owner,text:''}];
 assert.equal(exchangeReaction(previous,next,0)?.reason,'defeat');
 assert.deepEqual(exchangeReaction(previous,next,0),exchangeReaction(previous,{...next,lastResolution:next.lastResolution.toReversed()},0));
 assert.equal(exchangeReaction(next,next,0),null);assert.equal(exchangeReaction(undefined,next,0),null);
});
test('critical and empty Flux require positive damage or an actual cast; zero damage never means miss',()=>{
 const {previous,next,unit}=fixture();next.lastResolution=[{kind:'damage',unitId:unit.id,critical:true,amount:0,text:''}];
 assert.equal(exchangeReaction(previous,next,0),null);
 next.lastResolution[0].amount=2;assert.equal(exchangeReaction(previous,next,0)?.reason,'critical');
 next.lastResolution=[];unit.flux=0;assert.equal(exchangeReaction(previous,next,0),null);
 next.lastResolution=[{kind:'cast',unitId:unit.id,text:''}];assert.equal(exchangeReaction(previous,next,0)?.reason,'flux');
 next.lastResolution=[{kind:'fizzle',unitId:unit.id,text:''}];assert.equal(exchangeReaction(previous,next,0)?.reason,'fizzle');
});
test('victory speaker requires a single hostile spell author, never mixed or absent attribution',()=>{
 const {previous,next,unit,other}=fixture();other.hp=0;
 const damage={kind:'damage',unitId:other.id,amount:4,text:'',breakdown:{sources:[{unitId:unit.id,kind:'spell',amount:4}],prevented:0,total:4}} as SimEvent&{breakdown:{sources:{unitId?:string;kind:string;amount:number}[];prevented:number;total:number}};
 next.lastResolution=[{kind:'cast',unitId:unit.id,elements:['water'],text:''},damage,{kind:'defeat',unitId:other.id,owner:other.owner,text:''}];
 assert.deepEqual(exchangeReaction(previous,next,0),{unitId:unit.id,reason:'knockout',element:'water',line:reactionLine(unit.championId,'knockout')});
 damage.breakdown.sources.push({kind:'burn',amount:1});assert.equal(exchangeReaction(previous,next,0)?.reason,'defeat');
 damage.breakdown.sources.pop();next.lastResolution.push({kind:'surface',unitId:other.id,amount:1,text:'Wall impact.'});assert.equal(exchangeReaction(previous,next,0)?.reason,'defeat','later surface damage makes knockout attribution uncertain');
 next.lastResolution=next.lastResolution.filter(event=>event.kind!=='damage');assert.equal(exchangeReaction(previous,next,0)?.reason,'defeat');
});
test('repeat reactions rest for two rounds while the same exchange replay and fresh run remain stable',()=>{
 const reaction={unitId:'a',reason:'flux',line:'Out of current.'} as const,history=new Map([['a:flux',4]]);
 assert.equal(reactionOnCooldown(reaction,4,history),false);assert.equal(reactionOnCooldown(reaction,5,history),true);assert.equal(reactionOnCooldown(reaction,6,history),true);assert.equal(reactionOnCooldown(reaction,7,history),false);assert.equal(reactionOnCooldown(reaction,1,history),false);
});
test('speech layout stays inside phone and landscape views, protects actors, and yields to crowding',()=>{
 for(const viewport of [{width:390,height:260},{width:790,height:310},{width:1440,height:700}]){
  const anchor={x:viewport.width/2,y:viewport.height/2},obstacles=[{x:anchor.x-35,y:anchor.y-10,width:70,height:90}];
  const box=placeCharacterSpeech(anchor,viewport,obstacles);assert.ok(box);
  assert.ok(box.x>=8&&box.y>=8&&box.x+box.width<=viewport.width-8&&box.y+box.height<=viewport.height-8);
  assert.ok(obstacles.every(obstacle=>!speechRectsOverlap(box,obstacle,8)));
  assert.equal(placeCharacterSpeech(anchor,viewport,[{x:0,y:0,...viewport}]),null);
 }
 assert.equal(placeCharacterSpeech({x:-1,y:40},{width:390,height:260},[]),null,'off-screen speakers do not acquire disconnected bubbles');
 assert.equal(placeCharacterSpeech({x:500,y:350},{width:1000,height:700},[{x:240,y:160,width:520,height:420}]),null,'distant empty corners never create a leader across the battle');
});
test('speech finds space above real-scale damage and condition readouts without shrinking their protection',()=>{
 const viewport={width:766,height:617},scale=Math.max(1123.1712565104167/766,905.0810384114583/617);
 const foot={x:383,y:390},anchor={x:foot.x,y:foot.y-128/scale},calloutScale=Math.max(1/scale,.7);
 const sprite={x:foot.x-96/scale,y:foot.y-156/scale,width:192/scale,height:192/scale};
 const readout={x:foot.x-110*calloutScale,y:foot.y-Math.max(148/scale,36)-34*calloutScale,width:220*calloutScale,height:94*calloutScale};
 const box=placeCharacterSpeech(anchor,viewport,[sprite,readout],{width:184,height:64});
 assert.ok(box,'a real-size hurt actor has a nearby safe slot above the combat readout');
 assert.ok([sprite,readout].every(obstacle=>!speechRectsOverlap(box,obstacle,8)));
 assert.ok(box.y+box.height<=readout.y-8);
 const closestX=Math.max(box.x,Math.min(box.x+box.width,anchor.x)),closestY=Math.max(box.y,Math.min(box.y+box.height,anchor.y));
 assert.ok(Math.hypot(anchor.x-closestX,anchor.y-closestY)<=96);
});
test('planning animation budget is visible, temporary, varied and deterministic',()=>{
 const {next}=fixture(),elements=['fire','water','earth','air','light','dark'] as const;
 next.cells=next.cells.map((cell,index)=>({...cell,terrain:elements[index%6],elements:[elements[index%6]],ttl:3,height:0}));
 const view={x:450,y:318,width:1100,height:750},live=planningMaterialCells(next.cells,view);
 assert.equal(live.size,PLANNING_MATERIAL_BUDGET);
 assert.deepEqual([...live], [...planningMaterialCells(next.cells.toReversed(),view)]);
 const types=new Set(next.cells.filter(cell=>live.has(`${cell.q},${cell.r}`)).map(cell=>cell.terrain));assert.equal(types.size,6);
 assert.equal(planningMaterialCells(next.cells.map(cell=>({...cell,ttl:undefined})),view).size,0);
 assert.equal(planningMaterialCells(next.cells,{...view,x:100000}).size,0);
 assert.equal(planningMaterialCells(next.cells,view,0).size,0);
});
test('new audible outcomes are distinct, short and prioritized beneath defeat',()=>{
 const critical:SimEvent={kind:'damage',critical:true,unitId:'a',amount:2,text:''},heal:SimEvent={kind:'heal',amount:2,text:''},burn:SimEvent={kind:'surface',status:'burn',unitId:'a',text:''},fizzle:SimEvent={kind:'fizzle',unitId:'a',text:''};
 assert.equal(resolutionCues([critical]).at(-1)?.kind,'critical');
 assert.equal(resolutionCues([heal]).at(-1)?.kind,'heal');
 assert.equal(resolutionCues([burn]).at(-1)?.kind,'burn');
 assert.equal(resolutionCues([fizzle])[0]?.kind,'fizzle');
 assert.equal(resolutionCues([critical,burn,heal,{kind:'defeat',owner:0,text:''}]).at(-1)?.kind,'loss');
 assert.equal(resolutionCues([{...critical,amount:0}]).length,0);
 const motifs=new Set<string>();for(const kind of ['critical','heal','burn','fizzle'] as const){const voices=materialVoices(kind);assert.ok(voices.every(voice=>voice.duration+voice.delay<.3&&voice.volume<=.018));motifs.add(JSON.stringify(voices));}
 assert.equal(motifs.size,4);
 for(const event of [critical,heal,burn,fizzle])assert.ok(instantResolutionCues([event]).every(cue=>cue.at<=260));
 assert.equal(resolutionCues([burn]).at(-1)?.at,PHASE_MS.settle);
});
