/** A seeded graph, shared by route validation and its hex-map presentation. */
export type TowerRouteNode={id:string;floor:number;lane:number;next:string[]};
const hash=(text:string)=>{let value=2166136261;for(const char of text){value^=char.charCodeAt(0);value=Math.imul(value,16777619)>>>0;}return value;};
/** The launch population is fixed for the climb; legacy/solo routes have three branches. */
export function towerBranchCount(routePlayers=1):number {
 if(!Number.isSafeInteger(routePlayers)||routePlayers<1||routePlayers>6)throw new Error('Tower routes support one to six players.');
 return routePlayers+2;
}
export function towerRouteGraph(seed:string,routePlayers=1):TowerRouteNode[]{
 const width=towerBranchCount(routePlayers),nodes:TowerRouteNode[]=[];
 for(let floor=1;floor<=9;floor++)for(let lane=0;lane<(floor===9?1:width);lane++){
  let next:number[];
  if(floor===9)next=[];
  else if(floor===8)next=[0];
  else if(width===3)next=lane===0?[0,1]:lane===2?[1,2]:hash(`${seed}:path:${floor}`)%2?[0,1]:[1,2];
  else {
   // Every route keeps its own branch and a nearby alternative, while sharing
   // one rendezvous so squads that split can fight together on the next floor.
   const meeting=Math.floor((width-1)/2);
   const nearby=Array.from({length:width},(_,value)=>value).filter(value=>value!==lane&&value!==meeting).sort((a,b)=>Math.abs(a-lane)-Math.abs(b-lane)||hash(`${seed}:path:${floor}:${lane}:${a}`)-hash(`${seed}:path:${floor}:${lane}:${b}`));
   next=[...new Set([lane,meeting,...nearby])].slice(0,3).sort((a,b)=>a-b);
  }
  nodes.push({id:`floor-${floor}-${lane}`,floor,lane,next:next.map(value=>`floor-${floor+1}-${value}`)});
 }
 return nodes;
}
export function reachableTowerRooms(seed:string,floor:number,history:readonly {id:string;floor:number}[],routePlayers=1):string[]{
 const graph=towerRouteGraph(seed,routePlayers),previous=history.find(room=>room.floor===floor-1);
 // Old saves without an immediately preceding room retain the full current fork.
 return previous?(graph.find(node=>node.id===previous.id)?.next??[]):graph.filter(node=>node.floor===floor).map(node=>node.id);
}
