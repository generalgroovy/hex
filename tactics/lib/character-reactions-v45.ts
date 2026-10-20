import type {SimState} from './tactics-v16.ts';
import type {CreatureFamily} from './inhabitants-v16.ts';
import type {Element} from './game.ts';
export type ReactionReason='knockout'|'defeat'|'critical'|'burn'|'flux'|'fizzle';
export type CharacterReaction={unitId:string;reason:ReactionReason;line:string;element?:Element};
type Voice=readonly [string,string,string,string,string];
const reasons:ReactionReason[]=['knockout','defeat','critical','burn','flux','fizzle'];
/** These are responses to public results, never predictions or hints at sealed orders. */
export const CHAMPION_REACTIONS:Readonly<Record<string,Voice>>={
 oh_tipi:['Taking a shore break.','Right in the gills.','Boiled. How original.','Out of current.','A fish out of range.'],
 s_wayne:['Tea break.','Quite rude.','My good coat!','Pocket is empty.','The other one, then.'],
 red_baron:['Already tried that.','Right in the afterlife.','Still flammable, yes.','Running on old bones.','The grave can wait.'],
 grace_reava:['Landing early.','That caught the wind.','Warm front. Too warm.','Need a second wind.','Wrong breeze.'],
 wa_bidi:['Strategic floor time.','Hey! That was my head.','Not the eyebrows!','Nothing in the tank.','Practice shot.'],
 steezo:['Warranty claim.','Good engineering. Ow.','That bit was untested.','Needs a new battery.','Calibration shot.'],
 treevor_mason:['Just replant me.','That left a ring.','I am not kindling.','Sap is running low.','Branch miscalculation.'],
 oll_i:['Down. Not housebroken.','Right in the snout.','My fur!','No howl left.','That tile had it coming.'],
 fluup:['Floor is sturdy.','Good punch. Hate it.','Too crispy.','Need a snack.','Meant to do that.'],
 nico_lai:['Rebooting. Slowly.','Lost a screw there.','Hotter than specified.','Battery says no.','Measure twice. Next time.'],
 spai_si:['A brief disappearance.','Found the weak spot.','I prefer a mild roast.','All out of tricks.','A diversion. Obviously.'],
 leaf_hidden:['Back to the undergrowth.','How did you see me?','My camouflage!','Let me photosynthesize.','The leaf moved.'],
 ha_rekt:['Wing down.','Right under the scales.','This is usually my job.','Embers only.','Warning shot.'],
 dr_apex:['A geological pause.','That needs a patch.','Thermal expansion. Ow.','Reserves depleted.','Revising the hypothesis.'],
 haara:['Roots need rest.','Not very neighborly.','My garden disagrees.','One moment to bloom.','That was for the weeds.'],
 hesus_christo:['A moment of reflection.','That was unkind.','Rather warm in here.','Faith. No Flux.','A lesson in humility.'],
 grimm_bow:['Taking the low ground.','I felt that one.','Smells like regret.','Bow needs a breather.','Wind owes me one.'],
 biggy_bob:['Well. Floor inspection.','That dent is staying.','Not near the beard!','Empty barrel.','Checking the sights.'],
 jan_wicked:['A short intermission.','Rude but effective.','Coat is ruined.','Last spark spent.','You saw nothing.'],
 ba_djoh:['Grounded. Literally.','Mind the horns!','Well done? Hardly.','Snort. Empty.','Small target.'],
 urzh:['Rock bottom.','That chipped.','Hot stone treatment?','No charge left.','Wrong rock.'],
 donnok:['Drum solo postponed.','Missed a beat there.','Not the drumsticks!','Lost the rhythm.','Offbeat. Very offbeat.'],
 djonah_thaan:['Five more centuries.','A pointed remark.','Terrible for the skin.','Running rather dry.','A polite warning.'],
 luuh_i_zeh:['Legs need a minute.','Eight legs. One bruise.','Not the silk!','Web supply empty.','Loose thread.'],
 juul_i_yaina:['Dramatic exit.','A little personal.','This was not my fire.','All out of mischief.','Suspense!'],
 faab_i_yaina:['Wings need a rest.','Halo needs straightening.','Scorched feathers.','Light needs a refill.','A mercy. Probably.'],
 joh_haynes:['Sitting this one out.','Fine. That was good.','Too much seasoning.','Nothing left to throw.','Testing the floor.'],
 h_le_ne:['Settling. Like stone.','A new fault line.','My edges are glowing.','Reserves are quiet.','That rock offended me.'],
 fimu_yashiha:['Going to seed.','A knot in my plans.','Not firewood!','A little rain, please.','Pruning the wrong branch.'],
 sai_laas:['Resting by the roots.','That was sharp.','No more summer, thanks.','Dew tank is empty.','For the butterflies.'],
};
const victories:Readonly<Record<string,string>>={
 oh_tipi:'Back with the tide.',s_wayne:'Tea, anyone?',red_baron:'I know a good crypt.',grace_reava:'A change in the wind.',wa_bidi:'That one was on purpose.',
 steezo:'Test successful!',treevor_mason:'That settles the roots.',oll_i:'Stay.',fluup:'Good floor. Catch well.',nico_lai:'Within specifications.',
 spai_si:'And now, the exit.',leaf_hidden:'Nothing to see here.',ha_rekt:'Scales tip my way.',dr_apex:'Results are conclusive.',haara:'A little room to grow.',
 hesus_christo:'Take a moment.',grimm_bow:'Found the range.',biggy_bob:'That will hold.',jan_wicked:'One less appointment.',ba_djoh:'Clear the lane.',
 urzh:'Stone settles it.',donnok:'And that is the beat.',djonah_thaan:'A short nap, then.',luuh_i_zeh:'All tied up.',juul_i_yaina:'Curtain.',
 faab_i_yaina:'Rest those wings.',joh_haynes:'That will do.',h_le_ne:'Fault found.',fimu_yashiha:'Room for a new leaf.',sai_laas:'Quiet by the water.',
};
const creatureVoice:Record<CreatureFamily,string>={fox:'Yip?!',otter:'Chrr?',tortoise:'Hmph.',bird:'Cheep!',moth:'Fff.',cat:'Mrrp?!',heron:'Kraak!',salamander:'Sss!',toad:'Brrp.',stag:'Huff.',serpent:'Hiss!',bison:'Hrrmph.',garden:'Rustle...'};
export function reactionLine(championId:string,reason:ReactionReason,creatureFamily?:CreatureFamily):string{
 if(creatureFamily)return creatureVoice[creatureFamily];
 if(reason==='knockout')return victories[championId]??'That will do.';
 return (CHAMPION_REACTIONS[championId]??['A little rest.','Good hit.','Too warm.','Out of Flux.','Not that time.'])[reasons.indexOf(reason)-1];
}
export function reactionOnCooldown(reaction:CharacterReaction|null,round:number,history:ReadonlyMap<string,number>):boolean{
 if(!reaction)return false;const seen=history.get(`${reaction.unitId}:${reaction.reason}`);
 return seen!==undefined&&round>seen&&round-seen<3;
}
/** Exactly one actor speaks. Priority is stable across event ordering and replays. */
export function exchangeReaction(previous:SimState|undefined,next:SimState,player:0|1,creatures:Readonly<Record<string,CreatureFamily>>={}):CharacterReaction|null{
 if(!previous||previous.version===next.version)return null;
 const events=next.lastResolution,candidates:{unitId:string;reason:ReactionReason;element?:Element}[]=[];
 for(const unit of next.units){
  const old=previous.units.find(entry=>entry.id===unit.id);if(!old||old.hp<=0)continue;
  let reason:ReactionReason|undefined;
  if(events.some(event=>event.kind==='defeat'&&event.unitId===unit.id)){
   reason='defeat';
   const damage=events.filter(event=>event.kind==='damage'&&event.unitId===unit.id&&(event.amount??0)>0);
   const sources=damage.flatMap(event=>(event as typeof event&{breakdown?:{sources:{unitId?:string;kind:string;amount:number}[]}}).breakdown?.sources??[]);
   const allAttributed=damage.length>0&&damage.every(event=>(event as typeof event&{breakdown?:{sources:unknown[]}}).breakdown?.sources.length);
   const casterId=sources[0]?.unitId,caster=next.units.find(entry=>entry.id===casterId);
   const laterSurface=events.some(event=>event.kind==='surface'&&event.unitId===unit.id&&(event.amount??0)>0);
   if(!laterSurface&&allAttributed&&sources.length&&sources.every(source=>source.kind==='spell'&&source.unitId===casterId)&&caster&&caster.owner!==unit.owner&&caster.hp>0&&caster.respawn===undefined){
    const cast=events.find(event=>event.kind==='cast'&&event.unitId===caster.id);
    candidates.push({unitId:caster.id,reason:'knockout',element:cast?.elements?.length===1?cast.elements[0]:undefined});
   }
  }
  else if(events.some(event=>event.kind==='damage'&&event.unitId===unit.id&&event.critical&&(event.amount??0)>0))reason='critical';
  else if(unit.hp>0&&unit.statuses.burn&&!old.statuses.burn)reason='burn';
  else if(unit.hp>0&&unit.flux===0&&old.flux>0&&events.some(event=>event.kind==='cast'&&event.unitId===unit.id))reason='flux';
  else if(unit.hp>0&&events.some(event=>event.kind==='fizzle'&&event.unitId===unit.id))reason='fizzle';
  if(reason){const damage=events.find(event=>event.kind==='damage'&&event.unitId===unit.id&&event.critical&&(event.amount??0)>0);candidates.push({unitId:unit.id,reason,element:reason==='burn'?'fire':reason==='critical'&&damage?.elements?.length===1?damage.elements[0]:undefined})}
 }
 candidates.sort((a,b)=>reasons.indexOf(a.reason)-reasons.indexOf(b.reason)||Number(next.units.find(unit=>unit.id===b.unitId)?.owner===player)-Number(next.units.find(unit=>unit.id===a.unitId)?.owner===player)||a.unitId.localeCompare(b.unitId));
 const chosen=candidates[0];if(!chosen)return null;
 const unit=next.units.find(entry=>entry.id===chosen.unitId)!;
 return {...chosen,line:reactionLine(unit.championId,chosen.reason,creatures[unit.id])};
}
export type SpeechRect={x:number;y:number;width:number;height:number};
export const speechRectsOverlap=(a:SpeechRect,b:SpeechRect,gap=0)=>a.x<b.x+b.width+gap&&a.x+a.width+gap>b.x&&a.y<b.y+b.height+gap&&a.y+a.height+gap>b.y;
/** Screen-pixel geometry keeps type readable at every zoom. A crowded view stays quiet. */
export function placeCharacterSpeech(anchor:{x:number;y:number},viewport:{width:number;height:number},obstacles:SpeechRect[],size={width:184,height:58}):SpeechRect|null{
 if(viewport.width<220||viewport.height<150||anchor.x<0||anchor.x>viewport.width||anchor.y<0||anchor.y>viewport.height)return null;
 const width=Math.min(size.width,viewport.width-16),height=size.height,gap=8;
 const candidates=[
  {x:anchor.x+28,y:anchor.y-height-12},{x:anchor.x-width-28,y:anchor.y-height-12},
  {x:anchor.x-width/2,y:anchor.y-height-42},{x:anchor.x+36,y:anchor.y+20},{x:anchor.x-width-36,y:anchor.y+20},
  // A health/condition readout can miss the fixed above-head slot by only a
  // few pixels. Place against its measured boundary before trying corners.
  ...obstacles.flatMap(obstacle=>[
   {x:anchor.x-width/2,y:obstacle.y-height-gap-1},
   {x:anchor.x-width/2,y:obstacle.y+obstacle.height+gap+1},
   {x:obstacle.x+obstacle.width+gap+1,y:anchor.y-height/2},
   {x:obstacle.x-width-gap-1,y:anchor.y-height/2},
  ]),
  {x:viewport.width-width-8,y:8},{x:8,y:8},{x:viewport.width-width-8,y:viewport.height-height-8},{x:8,y:viewport.height-height-8},
 ].map(point=>({x:Math.round(Math.max(8,Math.min(viewport.width-width-8,point.x))),y:Math.round(Math.max(8,Math.min(viewport.height-height-8,point.y))),width,height}));
 return candidates.find(candidate=>{
  const nearestX=Math.max(candidate.x,Math.min(candidate.x+candidate.width,anchor.x)),nearestY=Math.max(candidate.y,Math.min(candidate.y+candidate.height,anchor.y));
  return Math.hypot(anchor.x-nearestX,anchor.y-nearestY)<=96&&!obstacles.some(obstacle=>speechRectsOverlap(candidate,obstacle,gap));
 })??null;
}
export function speechLines(text:string,max=25):string[]{
 const words=text.split(/\s+/),lines:string[]=[];let line='';
 for(const word of words){if(line&&line.length+word.length+1>max){lines.push(line);line=word}else line=line?`${line} ${word}`:word}
 if(line)lines.push(line);return lines;
}
