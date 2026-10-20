import type {CreatureFamily} from './inhabitants-v16.ts';
export type CreatureMotionAction='idle'|'walk'|'cast'|'hit'|'defeat';
type Offset=readonly [number,number];
export type CreatureMotion={frames:readonly Offset[];duration:number};
/** Family gait, grounded anticipation and a held final pose. No idle animation. */
export function creatureMotion(family:CreatureFamily,action:CreatureMotionAction):CreatureMotion{
 const heavy=['bison','tortoise','garden'].includes(family),winged=['bird','moth','heron'].includes(family),low=['serpent','salamander','toad'].includes(family);
 if(action==='idle')return {frames:[[0,0]],duration:0};
 if(action==='walk')return {frames:heavy?[[0,0],[1,-1],[0,1],[-1,0]]:winged?[[0,0],[1,-3],[0,-1],[-1,1]]:low?[[0,0],[2,1],[1,-1],[-1,1]]:[[0,0],[1,-2],[0,1],[-1,-1]],duration:heavy?720:winged?560:low?600:480};
 // The release frame starts at the common 360 ms projectile anticipation boundary.
 if(action==='cast')return {frames:heavy?[[0,1],[1,2],[-2,0],[0,0]]:winged?[[0,0],[2,2],[-3,-4],[0,-1]]:low?[[0,1],[3,2],[-4,0],[0,0]]:[[0,1],[2,3],[-3,-1],[0,0]],duration:720};
 if(action==='hit')return {frames:heavy?[[2,0],[1,1],[-1,0],[0,0]]:[[3,1],[2,2],[-1,0],[0,0]],duration:heavy?480:400};
 return {frames:winged?[[0,-1],[1,3],[-1,7],[-2,10]]:heavy?[[0,0],[1,1],[-1,3],[-2,4]]:[[0,0],[1,2],[-1,5],[-2,7]],duration:heavy?960:800};
}
export const CREATURE_MATERIAL_SHADOWS:Record<CreatureFamily,string>={
 fox:'M-20-12h5v8h9v5H-19ZM4-13h8v9H5M-15-24h8v3h-8',
 otter:'M-17-14h6v10h9v5h-16ZM6-13h9v7H8M-10-21h12v3h-12',
 tortoise:'M-20-13h39v3h-39M-13-25h3v10h-3M2-25h3v10H2',
 bird:'M-14-16h7v9H8v4H-8v-4h-6M5-20h8v4H5',
 moth:'M-28-25h7v4h-7M21-25h7v4h-7M-13-17h5v7h-5M8-17h5v7H8',
 cat:'M-17-14h5v7h6v5h-11M6-17h5v9H6M-14-24h13v3h-13',
 heron:'M-8-13h28v4H-8M-11-26h3v11h-3M6-17h8v3H6',
 salamander:'M-19-10h31v4h-31M-21-13h7v3h-7',
 toad:'M-20-8h39v4h-39M-17-21h4v6h-4M14-21h4v6h-4',
 stag:'M-11-14h21v5h-21M-17-31h4v8h-4M-19-34h7v3h-7',
 serpent:'M-21-23h3v9h-3M-11-9H9v3h-20M-22-32h10v3h-10',
 bison:'M-19-16h6v8h26v3h-26M13-23h5v12h-5M-25-14h15v4h-15',
 garden:'M-21-19h42v4h-42M-14-9h5v7h-5M9-9h4v7H9M-16-25H8v3h-24',
};
