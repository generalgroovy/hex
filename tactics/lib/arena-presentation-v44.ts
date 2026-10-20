/** Public planning adapter only. It never resolves, saves or submits the
 * two-side presentation snapshot as an Arena match. Native Arena remains the
 * authority for legality, ownership, damage and recorded replay contacts. */
import type {SimState as PresentedState} from './tactics-v16.ts';
import type {SimState as ArenaState} from './tactics-v18.ts';
import type {SimState as PlanningState} from './tactics-v20.ts';
import {spellArea as nativeArea} from './tactics-v18.ts';
import {spellArea as legacyArea} from './tactics-v16.ts';
import {getSpell,effectiveSpell} from './spells-v16.ts';
import {projectedVolley as legacyVolley} from './planned-volley-v16.ts';
import {projectedVolley} from './planned-volley-v20.ts';
import {planningForecast as forecast} from './planning-forecast-v20.ts';
import {targetImpactPreview} from './target-impact-v41.ts';
const planningState=(state:PresentedState)=>({...state,rulesVersion:20,teams:[0,1],playerCount:2}) as unknown as PlanningState;
const area:typeof legacyArea=(state,unitId,spellId,target,from)=>nativeArea({...state,teams:[0,1],playerCount:2} as unknown as ArenaState,unitId,spellId,target,from);
const volley:typeof legacyVolley=(state,player,plan,stationaryRivals=false)=>projectedVolley(planningState(state),player,plan,stationaryRivals);
/** Every upcoming Arena exchange uses volume contacts, even when the currently
 * displayed historical exchange has no projectileModel marker. */
export const ARENA_SPELL_RULES={getSpell,effectiveSpell,spellArea:area,projectedVolley:volley};
/** The drawing adapter collapses team seats onto one colour side. It must not
 * turn an uncontrolled teammate's missing order into a known Guard/hold. */
export function arenaHasPrivateAlliedOrders(state:PresentedState,controllableUnitIds:readonly string[]):boolean{
 const controlled=new Set(controllableUnitIds);
 return state.units.some(unit=>unit.owner===0&&unit.hp>0&&!controlled.has(unit.id));
}
export function arenaPlanningForecast(state:PresentedState,plan:Parameters<typeof forecast>[2],unitId:string|null,spellId?:string,aim?:Parameters<typeof forecast>[5],controllableUnitIds?:readonly string[]){
 if(controllableUnitIds&&arenaHasPrivateAlliedOrders(state,controllableUnitIds))return null;
 return forecast(planningState(state),0,plan,unitId,spellId,aim);
}
export function arenaTargetImpactPreview(state:PresentedState,plan:Parameters<typeof targetImpactPreview>[2],unitId:string|null,spellId?:string,aim?:Parameters<typeof targetImpactPreview>[5],controllableUnitIds?:readonly string[]){
 if(controllableUnitIds&&arenaHasPrivateAlliedOrders(state,controllableUnitIds))return null;
 return targetImpactPreview(planningState(state),0,plan,unitId,spellId,aim);
}
