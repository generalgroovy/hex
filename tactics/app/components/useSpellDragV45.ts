"use client";
import {useState,type DragEvent,type KeyboardEvent} from 'react';
import {SPELL_DRAG_TYPE,readDraggedSpell,adjacentSpellSlot} from '../../lib/loadout-interaction-v45';

/** Drag is a shortcut. The same operation remains available through ordinary buttons. */
export function useSpellDragV45(allowed:readonly string[],place:(id:string,slot:number)=>void){
 const [dragged,setDragged]=useState<string|null>(null),[over,setOver]=useState<number|null>(null);
 function finish(){setDragged(null);setOver(null)}
 function source(id:string,enabled=true){return {
  draggable:enabled,
  onDragStart:(event:DragEvent<HTMLElement>)=>{
   if(!enabled||!allowed.includes(id)){event.preventDefault();return}
   event.dataTransfer.setData(SPELL_DRAG_TYPE,id);event.dataTransfer.effectAllowed='move';setDragged(id);
  },
  onDragEnd:finish,
 }}
 function target(slot:number){return {
  'data-spell-drop':dragged!==null,
  'data-spell-over':over===slot,
  onDragOver:(event:DragEvent<HTMLElement>)=>{if(dragged&&allowed.includes(dragged)){event.preventDefault();event.dataTransfer.dropEffect='move';setOver(slot)}},
  onDragLeave:()=>setOver(current=>current===slot?null:current),
  onDrop:(event:DragEvent<HTMLElement>)=>{
   event.preventDefault();const id=readDraggedSpell(event.dataTransfer.getData(SPELL_DRAG_TYPE),allowed);
   if(id&&id===dragged)place(id,slot);finish();
  },
 }}
 function reorder(event:KeyboardEvent<HTMLElement>,id:string,slot:number){
  if(!event.altKey)return;const next=adjacentSpellSlot(slot,event.key);
  if(next===null)return;event.preventDefault();place(id,next);
  const group=event.currentTarget.parentElement;
  requestAnimationFrame(()=>group?.querySelector<HTMLElement>(`[data-spell-slot="${next}"]`)?.focus());
 }
 return {source,target,reorder};
}
