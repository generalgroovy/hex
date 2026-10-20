import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import {createElement,isValidElement,type ReactNode,type ReactElement} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import * as roster from '../lib/roster-v9.ts';
import * as spells from '../lib/spells-v9.ts';
import * as catalogue from '../lib/catalogue-v9.ts';
import * as presentation from '../lib/presentation.ts';
import {CHAMPIONS,getChampion} from '../lib/roster-v9.ts';
import {ALL_SPELLS,getSpell} from '../lib/spells-v9.ts';
import {RACES,matchesChampion,matchesSpell,spellHasRole,spellFootprintLabel} from '../lib/catalogue-v9.ts';

test('roster filters combine race, affinity and forgiving multiword text without conflating them',()=>{
  const wayne=getChampion('s_wayne');
  assert.equal(matchesChampion(wayne,'  s WAYNE  '),true);
  assert.equal(matchesChampion(wayne,'hobbit dark','hobbit','dark'),true);
  assert.equal(matchesChampion(wayne,'shadow budget','hobbit','light'),true);
  assert.equal(matchesChampion(wayne,'wayne','goblin','dark'),false);
  assert.equal(matchesChampion(wayne,'wayne','hobbit','water'),false);
  assert.equal(matchesChampion(wayne,'wayne water'),false);
  assert.deepEqual(RACES,[...new Set(CHAMPIONS.map(champion=>champion.race))].sort());
});

test('spell search finds effects and footprints, with role filters based on actual effects',()=>{
  assert.equal(matchesSpell(getSpell('gale'),'push 2','control'),true);
  assert.equal(matchesSpell(getSpell('maelstrom'),'12 ring','control'),true);
  assert.equal(matchesSpell(getSpell('cleansing_tide'),'cleanse','healing'),true);
  assert.equal(matchesSpell(getSpell('siphon'),'heal','healing'),true);
  assert.equal(matchesSpell(getSpell('raise_cairn'),'barrier','control'),true);
  assert.equal(matchesSpell(getSpell('stone'),'','healing'),false);
  assert.equal(matchesSpell(getSpell('mend'),'','damage'),false);
  assert.equal(matchesSpell(getSpell('water_jet'),'','control'),false,'Wet alone does not hinder movement or casting');
  assert.equal(spellHasRole(getSpell('slipstream'),'support'),true);
  assert.equal(spellHasRole(getSpell('soul_chain'),'support'),false,'self-applied Wither is not protection');
});

test('catalogue footprints describe the actual ring, fan and burst sizes rather than their silhouettes',()=>{
  assert.equal(spellFootprintLabel(getSpell('wildfire')),'Burst · 19 hexes');
  assert.equal(spellFootprintLabel(getSpell('inferno')),'Burst · 7 hexes');
  assert.equal(spellFootprintLabel(getSpell('tidal_surge')),'Sweep · 5 hexes');
  assert.equal(spellFootprintLabel(getSpell('maelstrom')),'Ring · 12 hexes');
  assert.equal(spellFootprintLabel(getSpell('fire_lance')),'Lane');
  assert.equal(spellFootprintLabel(getSpell('raise_cairn')),'Wall · 3 hexes');
  for(const spell of ALL_SPELLS)assert.ok(spellFootprintLabel(spell));
});

const nodeRequire=createRequire(import.meta.url);
const filename=fileURLToPath(new URL('../app/components/CompanyOverviewV9.tsx',import.meta.url));
const javascript=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
const module={exports:{}};
new Function('require','module','exports',javascript)((specifier:string)=>{
  if(specifier.endsWith('.css'))return {};
  if(specifier.endsWith('/roster-v9'))return roster;
  if(specifier.endsWith('/spells-v9'))return spells;
  if(specifier.endsWith('/catalogue-v9'))return catalogue;
  if(specifier.endsWith('/presentation'))return presentation;
  if(specifier.endsWith('/PixelChampion')||specifier.endsWith('/ElementIcon'))return ()=>null;
  return nodeRequire(specifier);
},module,module.exports);
type OverviewProps=import('../app/components/CompanyOverviewV9.tsx').CompanyOverviewV9Props;
const Overview=(module.exports as {default:(props:OverviewProps)=>ReactElement}).default;
function elements(node:ReactNode):ReactElement<Record<string,unknown>>[]{
  if(Array.isArray(node))return node.flatMap(elements);
  if(!isValidElement<Record<string,unknown>>(node))return [];
  return [node,...elements(node.props.children as ReactNode)];
}

test('team overview exposes all three races and fifteen moves, and every spell opens its own slot directly',()=>{
  const ids=['oh_tipi','wa_bidi','treevor_mason'];
  const actions:string[]=[];
  const props:OverviewProps={roster:ids,loadouts:{wa_bidi:['water_jet','mend','gust','stone']},selectedSlot:1,disabled:false,onSelect:slot=>actions.push(`select:${slot}`),onReplace:slot=>actions.push(`replace:${slot}`),onEditSpell:(slot,index)=>actions.push(`spell:${slot}:${index}`)};
  const rendered=Overview(props),all=elements(rendered),buttons=all.filter(node=>node.type==='button');
  assert.equal(all.filter(node=>node.type==='article').length,3);
  assert.equal(buttons.length,18,'one select, one replace, and four spell controls per character');
  for(let slot=0;slot<3;slot++){
    const champion=roster.getChampion(ids[slot]);
    const select=buttons.find(node=>node.props['aria-label']===`Select ${champion.name}`)!;
    const replace=buttons.find(node=>node.props['aria-label']===`Replace ${champion.name}`)!;
    (select.props.onClick as ()=>void)();
    (replace.props.onClick as ()=>void)();
    assert.equal(select.props['aria-pressed'],slot===1);
    for(let index=0;index<4;index++){
      const button=buttons.find(node=>String(node.props['aria-label']).startsWith(`Configure spell ${index+1} for ${champion.name}:`))!;
      (button.props.onClick as ()=>void)();
      assert.ok(String(button.props['aria-label']).includes('Reach'));
      assert.equal(elements(button.props.children as ReactNode).some(child=>child.type==='button'),false,'no nested controls');
    }
  }
  assert.deepEqual(actions,ids.flatMap((_,slot)=>[`select:${slot}`,`replace:${slot}`,...[0,1,2,3].map(index=>`spell:${slot}:${index}`)]));
  const html=renderToStaticMarkup(createElement(Overview,props));
  for(const name of ['Seakin','Goblin','Treefolk','Water Jet','Mend','Gust','Stone','Current Anchor','Scrap Spark','Mason&#x27;s Stance'])assert.ok(html.includes(name),name);
  assert.ok(html.includes('Water</span><b>3</b>'),'affinity names and values stay visible without a tooltip');
  const lockedButtons=elements(Overview({...props,disabled:true})).filter(node=>node.type==='button');
  assert.ok(lockedButtons.every(button=>button.props.disabled===true),'remote waiting room cannot change the submitted team');
});
