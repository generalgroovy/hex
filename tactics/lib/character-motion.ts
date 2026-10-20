/**
 * Timing notes for the original H.E.X. atlas: eight facings, four poses,
 * and a common planted foot at (64, 104) in each 128px cell.
 * These are performance choices, not combat speed or stat modifiers.
 */
export type MotionVoice = 'current'|'spark'|'root'|'poise'|'flutter'|'prowl'|'forge'|'ritual';
export type CharacterMotion = Readonly<{
  voice:MotionVoice;
  /** The silhouette's perceived weight, useful when authoring nearby effects. */
  mass:'light'|'medium'|'heavy';
  note:string;
  idleMs:number;
  idlePhase:number;
  gaitMs:number;
  castMs:number;
  hitMs:number;
  anticipation:number;
  release:number;
  settle:number;
  stride:number;
  lean:number;
  recoil:number;
  squash:number;
}>;

const profile=(value:CharacterMotion):CharacterMotion=>Object.freeze(value);

/** Deliberately authored by identity; a race alone does not determine personality. */
export const CHARACTER_MOTION:Readonly<Record<string,CharacterMotion>>=Object.freeze({
  oh_tipi:profile({voice:'current',mass:'medium',note:'A measured tide: gather low, roll forward, return to the same footing.',idleMs:5600,idlePhase:730,gaitMs:380,castMs:440,hitMs:330,anticipation:1.4,release:2,settle:.7,stride:1.1,lean:1.8,recoil:1.8,squash:.018}),
  s_wayne:profile({voice:'ritual',mass:'light',note:'Keeps the cloak still; one small, exact flourish releases the spell.',idleMs:7100,idlePhase:2270,gaitMs:320,castMs:410,hitMs:300,anticipation:.7,release:1.4,settle:.3,stride:.8,lean:1.1,recoil:2.3,squash:.012}),
  red_baron:profile({voice:'poise',mass:'heavy',note:'Regal and rigid, with a short deliberate recoil behind the armour.',idleMs:7900,idlePhase:3410,gaitMs:430,castMs:440,hitMs:380,anticipation:.9,release:1.6,settle:.5,stride:.7,lean:1.4,recoil:1.1,squash:.008}),
  grace_reava:profile({voice:'flutter',mass:'light',note:'A sylph glides into the gesture, then softly alights.',idleMs:4800,idlePhase:1510,gaitMs:270,castMs:420,hitMs:280,anticipation:.8,release:2.3,settle:.4,stride:1.7,lean:2.1,recoil:2.6,squash:.016}),
  wa_bidi:profile({voice:'spark',mass:'light',note:'Coiled goblin knees, a quick spark and a tiny checked overshoot.',idleMs:5300,idlePhase:3130,gaitMs:245,castMs:390,hitMs:260,anticipation:1.7,release:2.4,settle:.9,stride:1.6,lean:2.8,recoil:2.5,squash:.025}),
  steezo:profile({voice:'forge',mass:'light',note:'Plants the gadget, braces, then gives a clipped recoil.',idleMs:6100,idlePhase:870,gaitMs:285,castMs:400,hitMs:290,anticipation:1.3,release:1.9,settle:.6,stride:1.2,lean:2.2,recoil:2.2,squash:.021}),
  treevor_mason:profile({voice:'root',mass:'heavy',note:'A heavy tree shifts from the roots; the crown settles last.',idleMs:8400,idlePhase:4200,gaitMs:480,castMs:440,hitMs:410,anticipation:1.7,release:1.3,settle:.8,stride:.6,lean:.9,recoil:.8,squash:.014}),
  oll_i:profile({voice:'prowl',mass:'heavy',note:'A broad predator lowers its shoulders before a compact lunge.',idleMs:6400,idlePhase:2130,gaitMs:350,castMs:420,hitMs:340,anticipation:1.8,release:2.2,settle:.9,stride:1.2,lean:2.3,recoil:1.5,squash:.022}),
  fluup:profile({voice:'spark',mass:'heavy',note:'An eager orc winds up through the shoulders, then checks the weight.',idleMs:5800,idlePhase:3890,gaitMs:365,castMs:430,hitMs:350,anticipation:1.9,release:2,settle:1,stride:1.1,lean:2.5,recoil:1.4,squash:.024}),
  nico_lai:profile({voice:'forge',mass:'light',note:'Precise gnomish footwork and an almost mechanical trigger snap.',idleMs:6700,idlePhase:2830,gaitMs:260,castMs:395,hitMs:275,anticipation:1.1,release:1.7,settle:.4,stride:.9,lean:1.7,recoil:2.1,squash:.017}),
  spai_si:profile({voice:'prowl',mass:'medium',note:'A held sidelong lean becomes a sharp, controlled release.',idleMs:6900,idlePhase:1090,gaitMs:310,castMs:405,hitMs:305,anticipation:1.2,release:2.1,settle:.5,stride:1.1,lean:2.4,recoil:2,squash:.018}),
  leaf_hidden:profile({voice:'current',mass:'medium',note:'Small branch sway, broad water gesture, patient recovery.',idleMs:8200,idlePhase:5310,gaitMs:420,castMs:440,hitMs:370,anticipation:1.1,release:1.5,settle:.6,stride:.7,lean:1.2,recoil:1.2,squash:.013}),
  ha_rekt:profile({voice:'root',mass:'heavy',note:'The wyrm braces under its wings; power rises without a weightless hop.',idleMs:7600,idlePhase:1740,gaitMs:440,castMs:435,hitMs:390,anticipation:1.6,release:1.8,settle:.8,stride:.8,lean:1.6,recoil:1.1,squash:.015}),
  dr_apex:profile({voice:'root',mass:'heavy',note:'Stone barely yields; a deep preparation ends with a firm stop.',idleMs:9200,idlePhase:6550,gaitMs:510,castMs:440,hitMs:420,anticipation:1.3,release:.9,settle:.4,stride:.4,lean:.65,recoil:.65,squash:.007}),
  haara:profile({voice:'flutter',mass:'light',note:'An open, upward gesture with a soft flower-like settle.',idleMs:5900,idlePhase:2470,gaitMs:300,castMs:430,hitMs:290,anticipation:.7,release:1.9,settle:.5,stride:1.3,lean:1.5,recoil:2.2,squash:.014}),
  hesus_christo:profile({voice:'poise',mass:'medium',note:'An elf turns a grounded stance into an economical palm strike.',idleMs:7400,idlePhase:4620,gaitMs:345,castMs:420,hitMs:315,anticipation:1,release:1.7,settle:.5,stride:.9,lean:1.8,recoil:1.6,squash:.011}),
  grimm_bow:profile({voice:'root',mass:'heavy',note:'A troll loads its weight slowly and lets the shoulders follow through.',idleMs:8100,idlePhase:3210,gaitMs:465,castMs:440,hitMs:400,anticipation:1.9,release:1.4,settle:.9,stride:.7,lean:1.3,recoil:.9,squash:.019}),
  biggy_bob:profile({voice:'forge',mass:'medium',note:'Dwarven heels stay planted through a stout hammer-like accent.',idleMs:6800,idlePhase:4430,gaitMs:390,castMs:425,hitMs:350,anticipation:1.6,release:1.6,settle:.8,stride:.8,lean:1.6,recoil:1.3,squash:.019}),
  jan_wicked:profile({voice:'ritual',mass:'medium',note:'A quiet held breath, a quick wrist-like accent, no theatrical bounce.',idleMs:7800,idlePhase:2910,gaitMs:340,castMs:415,hitMs:315,anticipation:.9,release:1.8,settle:.4,stride:.8,lean:1.9,recoil:1.8,squash:.012}),
  ba_djoh:profile({voice:'prowl',mass:'heavy',note:'The minotaur loads forward from a wide stance and catches its momentum.',idleMs:7000,idlePhase:1870,gaitMs:425,castMs:435,hitMs:380,anticipation:2,release:2.1,settle:1,stride:1,lean:2.1,recoil:1.2,squash:.023}),
  urzh:profile({voice:'forge',mass:'heavy',note:'A furnace within stone: compressed preparation and a short hot release.',idleMs:8600,idlePhase:5730,gaitMs:490,castMs:440,hitMs:415,anticipation:1.5,release:1.1,settle:.6,stride:.5,lean:.85,recoil:.75,squash:.009}),
  donnok:profile({voice:'forge',mass:'medium',note:'A workmanlike brace, low stomp and immediate return to readiness.',idleMs:7200,idlePhase:3610,gaitMs:405,castMs:430,hitMs:355,anticipation:1.5,release:1.5,settle:.7,stride:.75,lean:1.4,recoil:1.25,squash:.018}),
  djonah_thaan:profile({voice:'ritual',mass:'medium',note:'A vampire waits longer than expected, then releases in a narrow snap.',idleMs:8800,idlePhase:6320,gaitMs:355,castMs:425,hitMs:320,anticipation:.8,release:1.9,settle:.3,stride:.65,lean:2,recoil:1.7,squash:.01}),
  luuh_i_zeh:profile({voice:'prowl',mass:'light',note:'Low spiderkin stillness, quick feet and a tightly folded recoil.',idleMs:7500,idlePhase:5170,gaitMs:235,castMs:390,hitMs:255,anticipation:1.1,release:1.8,settle:.5,stride:.55,lean:2.2,recoil:2.4,squash:.02}),
  juul_i_yaina:profile({voice:'current',mass:'light',note:'A small demon gathers a rolling current, then pulls neatly back.',idleMs:6200,idlePhase:4070,gaitMs:295,castMs:415,hitMs:285,anticipation:1,release:2,settle:.6,stride:1.2,lean:2,recoil:2.3,squash:.018}),
  faab_i_yaina:profile({voice:'poise',mass:'medium',note:'An angel opens the silhouette upward while keeping the landing calm.',idleMs:7300,idlePhase:2280,gaitMs:335,castMs:430,hitMs:325,anticipation:.9,release:2.2,settle:.5,stride:1,lean:1.5,recoil:1.6,squash:.014}),
  joh_haynes:profile({voice:'root',mass:'heavy',note:'A veteran orc uses a restrained shoulder drive, then stands firm.',idleMs:8300,idlePhase:4690,gaitMs:445,castMs:435,hitMs:385,anticipation:1.6,release:1.5,settle:.7,stride:.85,lean:1.5,recoil:1,squash:.017}),
  h_le_ne:profile({voice:'poise',mass:'medium',note:'Lighter stone balances precisely, with a small dry recoil.',idleMs:8900,idlePhase:5860,gaitMs:415,castMs:430,hitMs:370,anticipation:1,release:1.2,settle:.35,stride:.6,lean:1,recoil:.9,squash:.008}),
  fimu_yashiha:profile({voice:'current',mass:'light',note:'A young tree bends like a reed and gently finds centre again.',idleMs:6600,idlePhase:1230,gaitMs:325,castMs:425,hitMs:310,anticipation:.9,release:1.7,settle:.6,stride:1,lean:1.7,recoil:1.9,squash:.016}),
  sai_laas:profile({voice:'flutter',mass:'light',note:'A restless nymph springs lightly into an airy, quick-curving gesture.',idleMs:5100,idlePhase:3530,gaitMs:250,castMs:400,hitMs:270,anticipation:1.2,release:2.4,settle:.6,stride:1.8,lean:2.4,recoil:2.5,squash:.023}),
});

export const DEFAULT_MOTION=CHARACTER_MOTION.oh_tipi;
export function characterMotion(id:string):CharacterMotion {return CHARACTER_MOTION[id]||DEFAULT_MOTION}
export function spriteFacing(facing:number):number {return Number.isFinite(facing)?Math.max(0,Math.min(7,Math.round(facing))):0}

export type CharacterCastAnimation={name:string;poseName:string;css:string;durationMs:number;releaseMs:number;restMs:number};
/**
 * Animate the four real atlas rows rather than deforming a painted character.
 * The spell release is an absolute time supplied by combat; personality lives
 * in preparation and recovery, never in a different projectile launch time.
 * Translations are whole render pixels and the planted Y coordinate never moves.
 */
export function characterCastAnimation(id:string,size:number,facing:number,releaseMs=120):CharacterCastAnimation {
  const motion=characterMotion(id),scale=size/128,sign=spriteFacing(facing)>=5?-1:1;
  const lead=Math.max(0,Math.round(releaseMs)),durationMs=lead+motion.castMs;
  const hold={current:.62,spark:.28,root:.74,poise:.7,flutter:.52,prowl:.34,forge:.42,ritual:.8}[motion.voice];
  const restMs=lead+Math.round(motion.castMs*hold);
  const anticipation=Math.round(motion.anticipation*scale)*-sign,release=Math.round(motion.release*scale)*sign;
  const accent=motion.voice==='spark'||motion.voice==='prowl'?1:0;
  const name=`px-crafted-${id.replace(/[^a-z0-9_]/gi,'')}-${Math.round(size)}-${spriteFacing(facing)}-${lead}`;
  const poseName=`${name}-poses`,pct=(ms:number)=>Number((ms/durationMs*100).toFixed(6));
  const css=`@keyframes ${name}{0%{transform:translateX(0)}${pct(lead*.7)}%{transform:translateX(${anticipation}px)}${pct(lead)}%{transform:translateX(${release}px)}${pct(lead+motion.castMs*hold*.55)}%{transform:translateX(${-accent*sign}px)}${pct(restMs)}%{transform:translateX(0)}100%{transform:translateX(0)}}@keyframes ${poseName}{0%{background-position-y:0}${pct(lead)}%{background-position-y:${-3*size}px}${pct(restMs)}%,100%{background-position-y:0}}`;
  return {name,poseName,css,durationMs,releaseMs:lead,restMs};
}

/** All distances are original-atlas pixels, scaled once with the rendered cell. */
export function characterMotionStyle(id:string,size:number,facing:number):Record<string,string|number> {
  const motion=characterMotion(id),scale=size/128,direction=spriteFacing(facing);
  const sign=direction>=5?-1:1;
  return {
    '--px-idle-duration':`${motion.idleMs}ms`,'--px-idle-phase':`${-motion.idlePhase}ms`,
    '--px-gait-duration':`${motion.gaitMs}ms`,'--px-cast-duration':`${motion.castMs}ms`,'--px-hit-duration':`${motion.hitMs}ms`,
    '--px-anticipation':`${motion.anticipation*scale}px`,'--px-release':`${motion.release*scale}px`,
    '--px-settle':`${motion.settle*scale}px`,'--px-stride':`${motion.stride*scale}px`,
    '--px-lean':`${motion.lean*sign}deg`,'--px-recoil':`${motion.recoil*scale*-sign}px`,
    '--px-cast-x':`${motion.release*scale*sign}px`,'--px-counter-x':`${motion.anticipation*scale*-sign}px`,
    '--px-squash':1-motion.squash,'--px-stretch':1+motion.squash,
    '--px-step-lift':`${motion.mass==='light'?Math.max(1,Math.round(scale)):0}px`,
    '--px-hit-pixel':`${Math.round(motion.recoil*scale)*-sign}px`,
    '--px-hit-return':`${sign}px`,
  };
}
