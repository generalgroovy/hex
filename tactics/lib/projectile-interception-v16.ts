import type {Element,Point} from './game.ts';
import type {Spell} from './spells-v16.ts';

export type Projectile={unitId:string;from:Point;to:Point;element:Element};
export type ProjectileClash={participants:string[];meeting:Point;flightFraction:number;q:number;r:number;radius:1|2;elements:Element[]};
const ELEMENT_ORDER:readonly Element[]=['fire','water','earth','air','light','dark'];

/** Helpful spells and stationary effects do not become accidental shields. */
export function isTravellingProjectile(spell:Spell,from:Point,to:Point,friendlyTarget=false):boolean {
  if(from.q===to.q&&from.r===to.r)return false;
  if(spell.shape==='wall'||spell.heal>0&&spell.harm==='enemy'&&friendlyTarget)return false;
  return Boolean(spell.damage||spell.push||spell.harmful?.length||spell.steal);
}

type Fraction={n:number;d:number};
const gcd=(a:number,b:number):number=>b?gcd(b,a%b):a;
function reduced(n:number,d:number):Fraction {if(d<0){n=-n;d=-d;}const divisor=gcd(Math.abs(n),d);return {n:n/divisor,d:d/divisor};}
/** Relative motion is solved with integer cross-products, not frame sampling. */
function meetingTime(a:Projectile,b:Projectile):Fraction|undefined {
  const dq=a.from.q-b.from.q,dr=a.from.r-b.from.r;
  const vq=(a.to.q-a.from.q)-(b.to.q-b.from.q),vr=(a.to.r-a.from.r)-(b.to.r-b.from.r);
  if(!vq&&!vr)return undefined;
  const time=reduced(vq?-dq:-dr,vq||vr);
  if(time.n<=0||time.n>=time.d)return undefined;
  return dq*time.d+vq*time.n===0&&dr*time.d+vr*time.n===0?time:undefined;
}

/** The nearest axial hex uses the actual hex-plane metric, with a canonical tie. */
export function nearestClashHex(cells:readonly Point[],point:Point):Point {
  if(!cells.length)throw new Error('A clash needs battlefield hexes.');
  return [...cells].sort((a,b)=>{
    const aq=a.q-point.q,ar=a.r-point.r,bq=b.q-point.q,br=b.r-point.r;
    return (aq*aq+aq*ar+ar*ar)-(bq*bq+bq*br+br*br)||a.q-b.q||a.r-b.r;
  })[0];
}
export function interceptionFieldArea<T extends Point>(cells:readonly T[],clash:Pick<ProjectileClash,'q'|'r'|'radius'>):T[] {
  return cells.filter(cell=>Math.max(Math.abs(cell.q-clash.q),Math.abs(cell.r-clash.r),Math.abs(cell.q+cell.r-clash.q-clash.r))<=clash.radius);
}

/** All releases share one linear flight clock. Only equal spacetime consumes a spell.
 * Endpoints remain ordinary simultaneous impacts; already consumed spells cannot clash again.
 */
export function findProjectileClashes(projectiles:readonly Projectile[],cells:readonly Point[]):ProjectileClash[] {
  const ordered=[...projectiles].sort((a,b)=>a.unitId.localeCompare(b.unitId));
  if(new Set(ordered.map(projectile=>projectile.unitId)).size!==ordered.length)throw new Error('Each caster releases at most one projectile.');
  const candidates:{a:Projectile;b:Projectile;time:Fraction}[]=[];
  for(let left=0;left<ordered.length;left++)for(let right=left+1;right<ordered.length;right++){
    const a=ordered[left],b=ordered[right],time=meetingTime(a,b);if(time)candidates.push({a,b,time});
  }
  candidates.sort((a,b)=>a.time.n*b.time.d-b.time.n*a.time.d||a.a.unitId.localeCompare(b.a.unitId)||a.b.unitId.localeCompare(b.b.unitId));
  const consumed=new Set<string>(),clashes:ProjectileClash[]=[];
  while(candidates.length){
    const time=candidates[0].time,simultaneous:typeof candidates=[];
    while(candidates.length&&candidates[0].time.n*time.d===time.n*candidates[0].time.d)simultaneous.push(candidates.shift()!);
    const remaining=simultaneous.filter(pair=>!consumed.has(pair.a.unitId)&&!consumed.has(pair.b.unitId));
    while(remaining.length){
      const initial=remaining.shift()!,group=new Set([initial.a.unitId,initial.b.unitId]);
      let changed=true;
      while(changed){changed=false;for(let index=remaining.length-1;index>=0;index--){const pair=remaining[index];if(group.has(pair.a.unitId)||group.has(pair.b.unitId)){group.add(pair.a.unitId);group.add(pair.b.unitId);remaining.splice(index,1);changed=true;}}}
      const members=ordered.filter(projectile=>group.has(projectile.unitId)),flightFraction=time.n/time.d;
      const first=members[0],meeting={q:first.from.q+(first.to.q-first.from.q)*flightFraction,r:first.from.r+(first.to.r-first.from.r)*flightFraction};
      const anchor=nearestClashHex(cells,meeting);
      clashes.push({participants:members.map(projectile=>projectile.unitId),meeting,flightFraction,q:anchor.q,r:anchor.r,radius:members.length>=3?2:1,elements:ELEMENT_ORDER.filter(element=>members.some(projectile=>projectile.element===element))});
      members.forEach(projectile=>consumed.add(projectile.unitId));
    }
  }
  return clashes;
}
