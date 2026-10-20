import type {Element} from './game.ts';
import {CHAMPIONS,type Champion} from './roster-v13.ts';
import {getSignature,type Spell} from './spells-v15.ts';

export const RACES = [...new Set(CHAMPIONS.map(champion=>champion.race))].sort();
export const SPELL_ROLES = [
  {id:'all',label:'All roles'},
  {id:'damage',label:'Damage'},
  {id:'healing',label:'Healing'},
  {id:'control',label:'Control'},
  {id:'support',label:'Protection & support'},
] as const;
export type SpellRole = typeof SPELL_ROLES[number]['id'];

export function titleCase(value:string):string {
  return value.replace(/(^|[\s-])\S/g,letter=>letter.toUpperCase());
}

function words(value:string):string[] {
  return value.normalize('NFKD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim().split(/\s+/).filter(Boolean);
}
function includesQuery(text:string,query:string):boolean {
  const haystack=words(text).join(' ');
  return words(query).every(word=>haystack.includes(word));
}

/** Race and affinity filters compose with text; none of them alter the roster. */
export function matchesChampion(champion:Champion,query:string,race='all',element:Element|'all'='all'):boolean {
  if(race!=='all'&&champion.race!==race)return false;
  if(element!=='all'&&!champion.affinities[element])return false;
  return includesQuery(`${champion.name} ${champion.race} ${Object.keys(champion.affinities).join(' ')} ${getSignature(champion.id).name}`,query);
}

export function spellHasRole(spell:Spell,role:SpellRole):boolean {
  switch(role){
    case 'all':return true;
    case 'damage':return spell.damage>0;
    case 'healing':return spell.heal>0||(spell.drain??0)>0;
    case 'control':return !!(spell.push||spell.wall||spell.freeze||spell.steal||spell.harmful?.some(effect=>['blind','chilled','rooted','concussed','wither'].includes(effect.id)));
    case 'support':return !!(spell.cleanse||spell.recharge||[...(spell.friendly??[]),...(spell.self??[])].some(effect=>['ward','clarity','anchored','haste'].includes(effect.id)));
  }
}

/** Search includes effects and shape so a player can look for "push", "burn" or "ring". */
export function matchesSpell(spell:Spell,query:string,role:SpellRole='all'):boolean {
  return spellHasRole(spell,role)&&includesQuery(`${spell.name} ${spell.element} ${spell.branch} level ${spell.level} ${spell.description} ${spellFootprintLabel(spell)}`,query);
}

export function spellFootprintLabel(spell:Pick<Spell,'shape'|'radius'>):string {
  switch(spell.shape){
    case 'hex':return 'Single hex';
    case 'line':return 'Lane';
    case 'burst':return `Burst · ${1+3*spell.radius*(spell.radius+1)} hexes`;
    case 'ring':return `Ring · ${6*spell.radius} hexes`;
    case 'sweep':return `Sweep · ${1+2*(spell.radius||1)} hexes`;
    case 'wall':return 'Wall · 3 hexes';
  }
}
