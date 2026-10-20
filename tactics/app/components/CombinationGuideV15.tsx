"use client";
import {useState} from 'react';
import {ELEMENT_ORDER,combinationFor} from '../../lib/combinations-v15';
import type {Element} from '../../lib/game';
import ElementIcon from './ElementIcon';

/** A small interactive recipe, rather than a wall of sixty-three rules. */
export default function CombinationGuide(){
 const [ingredients,setIngredients]=useState<Element[]>(['fire','water']);
 const result=combinationFor(ingredients);
 return <div className="tx-combination-guide">
  <p>Choose ingredients to see the complete field. Adding an element transforms the mixture.</p>
  <div role="group" aria-label="Mixture ingredients" className="tx-mixture-ingredients">{ELEMENT_ORDER.map(element=><button key={element} aria-pressed={ingredients.includes(element)} onClick={()=>setIngredients(old=>old.includes(element)?old.filter(e=>e!==element):[...old,element])}><ElementIcon element={element} size={21}/><span>{element[0].toUpperCase()+element.slice(1)}</span></button>)}</div>
  <div className="tx-mixture-result" aria-live="polite">{result?<><strong>{result.symbol} {result.name}</strong><p>{result.description}</p></>:<p>Choose at least one element.</p>}</div>
  <small>Water, marsh, forest, ruins and high ground can supply an ingredient before spells land. Inspect the hex to check its ground.</small>
 </div>;
}
