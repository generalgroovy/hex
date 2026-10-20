import {findProjectileClashes as findPointMeetings,nearestClashHex,type Projectile as BaseProjectile,type ProjectileClash} from './projectile-interception-v16.ts';
import type {Element,Point} from './game.ts';
export {interceptionFieldArea,isTravellingProjectile,nearestClashHex} from './projectile-interception-v16.ts';
export type {ProjectileClash};
export type Projectile=BaseProjectile&{elements?:readonly Element[]};
const ORDER:readonly Element[]=['fire','water','earth','air','light','dark'];
/** A material core occupies a quarter hex. Cosmetic sparks and trails cannot
 * intercept a spell, and zoom never changes this world-space envelope. */
export const PROJECTILE_RADIUS=1/4;
const CONTACT_DISTANCE=PROJECTILE_RADIUS*2;
type Fraction={n:number;d:number};
type Candidate={a:Projectile;b:Projectile;time:Fraction};
const ingredients=(projectiles:readonly Projectile[],participants:readonly string[])=>ORDER.filter(element=>projectiles.some(projectile=>participants.includes(projectile.unitId)&&(projectile.elements??[projectile.element]).includes(element)));
const at=(projectile:Projectile,time:number):Point=>({q:projectile.from.q+(projectile.to.q-projectile.from.q)*time,r:projectile.from.r+(projectile.to.r-projectile.from.r)*time});

/** The volley has one simultaneous, linear clock. Test the whole relative
 * trajectory, not sampled frames or an intersection of two timeless lines.
 * A contact resolves at closest approach; exact centre meetings retain their
 * established timing, so three-to-six converging elements still fuse once.
 */
function contactTime(a:Projectile,b:Projectile):Fraction|undefined {
 // Shared aims are ordinary impacts: their fields combine on the target.
 if(a.to.q===b.to.q&&a.to.r===b.to.r)return undefined;
 const q=a.from.q-b.from.q,r=a.from.r-b.from.r;
 const vq=(a.to.q-a.from.q)-(b.to.q-b.from.q),vr=(a.to.r-a.from.r)-(b.to.r-b.from.r);
 const d=2*(vq*vq+vq*vr+vr*vr),n=-(2*q*vq+q*vr+r*vq+2*r*vr);
 if(!d||n<=0||n>=d)return undefined;
 const dq=q*d+vq*n,dr=r*d+vr*n;
 return dq*dq+dq*dr+dr*dr<=CONTACT_DISTANCE*CONTACT_DISTANCE*d*d?{n,d}:undefined;
}

/** Only saved pre-volume replays use the historical point solver. */
export function findLegacyProjectileClashes(projectiles:readonly Projectile[],cells:readonly Point[]):ProjectileClash[]{
 return findPointMeetings(projectiles,cells).map(clash=>({...clash,elements:ingredients(projectiles,clash.participants)}));
}

export function findProjectileClashes(projectiles:readonly Projectile[],cells:readonly Point[]):ProjectileClash[]{
 const ordered=[...projectiles].sort((a,b)=>a.unitId.localeCompare(b.unitId));
 if(new Set(ordered.map(projectile=>projectile.unitId)).size!==ordered.length)throw new Error('Each caster releases at most one projectile.');
 const candidates:Candidate[]=[];
 for(let left=0;left<ordered.length;left++)for(let right=left+1;right<ordered.length;right++){
  const a=ordered[left],b=ordered[right],time=contactTime(a,b);if(time)candidates.push({a,b,time});
 }
 candidates.sort((a,b)=>a.time.n*b.time.d-b.time.n*a.time.d||a.a.unitId.localeCompare(b.a.unitId)||a.b.unitId.localeCompare(b.b.unitId));
 const consumed=new Set<string>(),clashes:ProjectileClash[]=[];
 while(candidates.length){
  const time=candidates[0].time,simultaneous:Candidate[]=[];
  while(candidates.length&&candidates[0].time.n*time.d===time.n*candidates[0].time.d)simultaneous.push(candidates.shift()!);
  const remaining=simultaneous.filter(pair=>!consumed.has(pair.a.unitId)&&!consumed.has(pair.b.unitId));
  while(remaining.length){
   const initial=remaining.shift()!,group=new Set([initial.a.unitId,initial.b.unitId]);
   let changed=true;
   while(changed){changed=false;for(let index=remaining.length-1;index>=0;index--){const pair=remaining[index];if(group.has(pair.a.unitId)||group.has(pair.b.unitId)){group.add(pair.a.unitId);group.add(pair.b.unitId);remaining.splice(index,1);changed=true;}}}
   const members=ordered.filter(projectile=>group.has(projectile.unitId)),flightFraction=time.n/time.d;
   const positions=members.map(projectile=>at(projectile,flightFraction));
   const meeting={q:positions.reduce((sum,point)=>sum+point.q,0)/positions.length,r:positions.reduce((sum,point)=>sum+point.r,0)/positions.length};
   const anchor=nearestClashHex(cells,meeting);
   clashes.push({participants:members.map(projectile=>projectile.unitId),meeting,flightFraction,q:anchor.q,r:anchor.r,radius:members.length>=3?2:1,elements:ingredients(members,members.map(projectile=>projectile.unitId))});
   members.forEach(projectile=>consumed.add(projectile.unitId));
  }
 }
 return clashes;
}
