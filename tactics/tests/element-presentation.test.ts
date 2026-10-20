import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {createElement,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {ALL_SPELLS as currentSpells,ELEMENT_BRANCHES,effectiveSpell} from '../lib/spells-v16.ts';
import {ALL_SPELLS as oldSpells} from '../lib/spells-v9.ts';
import {ALL_SPELLS as v13Spells} from '../lib/spells-v13.ts';
import {ADVANCED_ELEMENT_KINDS,ADVANCED_ELEMENT_NAMES,ELEMENT_PALETTES,elementPresentation,spellPresentation} from '../lib/element-presentation.ts';
import type {Element} from '../lib/game.ts';
import type {ElementIconProps} from '../app/components/ElementIcon.tsx';
import * as presentation from '../lib/element-presentation.ts';

const require=createRequire(import.meta.url);
const source=readFileSync(new URL('../app/components/ElementIcon.tsx',import.meta.url),'utf8');
const compiled=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX}}).outputText;
const module={exports:{} as {default:ComponentType<ElementIconProps>}};
new Function('require','module','exports',compiled)((id:string)=>id.includes('element-presentation')?presentation:require(id),module,module.exports);
const Icon=module.exports.default;
const render=(props:ElementIconProps)=>renderToStaticMarkup(createElement(Icon,props));
const elements=Object.keys(ELEMENT_PALETTES) as Element[];

test('every current and archived spell receives its authored family and branch, including all signatures',()=>{
  assert.deepEqual(ADVANCED_ELEMENT_NAMES,ELEMENT_BRANCHES);
  for(const spell of [...oldSpells,...v13Spells,...currentSpells]){
    const actual=spellPresentation(spell),advanced=spell.branch===ELEMENT_BRANCHES[spell.element];
    assert.equal(actual.advanced,advanced,spell.id);
    assert.equal(actual.kind,advanced?ADVANCED_ELEMENT_KINDS[spell.element]:spell.element,spell.id);
    assert.equal(actual.family,spell.element);
    assert.equal(actual.palette,ELEMENT_PALETTES[spell.element]);
    const html=render({spell});
    assert.ok(html.includes(`data-element-kind="${actual.kind}"`),spell.id);
  }
  for(const signature of currentSpells.filter(spell=>spell.signatureChampionId)){
    const scaled=effectiveSpell(signature.signatureChampionId!,signature.id,{[signature.element]:6});
    assert.equal(spellPresentation(signature).kind,spellPresentation(scaled).kind,signature.id);
    assert.equal(spellPresentation(signature).advanced,true,signature.id);
  }
});

test('display names, spell levels, costs, signature status and freeze mechanics cannot change emblems',()=>{
  for(const element of elements){
    assert.equal(spellPresentation({element,branch:'Unrecognised branch'}).kind,element);
    assert.equal(spellPresentation({element}).kind,element);
    const base={element,branch:elementPresentation(element).name,name:'Lightning Ice Metal',level:6,freeze:true};
    assert.equal(spellPresentation(base).kind,element);
    const advanced={...base,branch:ELEMENT_BRANCHES[element],name:'Simple spell',level:1,freeze:false};
    assert.equal(spellPresentation(advanced).kind,ADVANCED_ELEMENT_KINDS[element]);
  }
  assert.equal(spellPresentation(currentSpells.find(spell=>spell.id==='rainfall')!).kind,'ice');
  assert.equal(currentSpells.find(spell=>spell.id==='rainfall')!.freeze,undefined,'Snowmelt visual identity must not invent freezing');
  assert.match(render({element:'fire',advanced:true,spell:{element:'water',branch:'Water'}}),/data-element-kind="water"/,'canonical spell wins over accidental fallback props');
});

test('twelve authored silhouettes share six exact family ramps and remain inside the integer pixel grid',()=>{
  const silhouettes=new Set<string>();
  for(const element of elements)for(const advanced of [false,true]){
    const html=render({element,advanced}),paths=[...html.matchAll(/<path[^>]+d="([^"]+)"/g)].map(match=>match[1]);
    assert.ok(paths.length>=4);
    assert.ok(!silhouettes.has(paths[0]),`${element}/${advanced} has its own silhouette`);silhouettes.add(paths[0]);
    for(const match of html.matchAll(/<path[^>]+fill="([^"]+)"/g))assert.ok(Object.values(ELEMENT_PALETTES[element]).includes(match[1]),`${element} uses only its family ramp`);
    assert.match(html,/shape-rendering="crispEdges"/);
    assert.doesNotMatch(html,/<(?:text|filter|image|animate|linearGradient)\b/);
    for(const path of paths){
      const tokens=path.match(/[MmHhVvZz]|-?\d+(?:\.\d+)?/g)!;let x=0,y=0,startX=0,startY=0;
      for(let index=0;index<tokens.length;){
        const command=tokens[index++];
        if(command==='M'){x=Number(tokens[index++]);y=Number(tokens[index++]);startX=x;startY=y;}
        else if(command==='H')x=Number(tokens[index++]);
        else if(command==='V')y=Number(tokens[index++]);
        else if(command==='h')x+=Number(tokens[index++]);
        else if(command==='v')y+=Number(tokens[index++]);
        else if(command==='z'||command==='Z'){x=startX;y=startY;}
        else assert.fail(`Non-pixel path command ${command}`);
        assert.ok(Number.isInteger(x)&&Number.isInteger(y)&&x>=0&&x<=24&&y>=0&&y<=24,`${element}/${advanced}: ${x},${y} in ${path}`);
      }
    }
    assert.equal(elementPresentation(element,advanced).palette,ELEMENT_PALETTES[element]);
  }
  assert.equal(silhouettes.size,12);
});

test('decorative emblems stay quiet, standalone emblems have explicit accessible names',()=>{
  const decorative=render({element:'fire',size:18,className:'spell-emblem'});
  assert.match(decorative,/aria-hidden="true"/);assert.match(decorative,/width="18"/);assert.match(decorative,/class="spell-emblem"/);
  assert.doesNotMatch(decorative,/<title>|role="img"/);
  const standalone=render({element:'fire',advanced:true,label:elementPresentation('fire',true).accessibleLabel});
  assert.match(standalone,/role="img"/);assert.match(standalone,/aria-label="Lightning · Fire"/);
  assert.match(standalone,/<title>Lightning · Fire<\/title>/);assert.doesNotMatch(standalone,/aria-hidden/);
});
