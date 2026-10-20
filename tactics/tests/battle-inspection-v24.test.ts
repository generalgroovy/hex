import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {STATUS_DEFINITIONS,type Status,type StatusId} from '../lib/spells-v20.ts';
import {activeStatusInsights,statusInsight,insightPosition} from '../lib/battle-inspection-v24.ts';
import {REFERENCE_STATUSES} from '../lib/combat-reference.ts';

test('inspection covers every active status and preserves the canonical removal rule',()=>{
 for(const status of STATUS_DEFINITIONS){const insight=statusInsight(status.id,{turns:2,power:1});assert.ok(insight);assert.equal(insight.name,status.name);assert.equal(insight.color,status.color);assert.equal(insight.clearRule,REFERENCE_STATUSES.find(entry=>entry.id===status.id)!.clearRule);assert.equal(insight.durationLabel,'2 rounds left');assert.ok(insight.effect.length>15);}
 assert.equal(statusInsight('invented',{turns:1,power:1}),undefined);assert.equal(statusInsight('burn',undefined),undefined);assert.equal(statusInsight('burn',{turns:0,power:1}),undefined);
});

test('live Ward, Burn and Wither use actual strength, and control descriptions preserve player options',()=>{
 assert.match(statusInsight('ward',{turns:2,power:5})!.effect,/Absorb 5 ordinary spell damage/);
 assert.equal(statusInsight('ward',{turns:1,power:3})!.durationLabel,'1 round left');
 assert.match(statusInsight('burn',{turns:1,power:1})!.effect,/Take 1 damage/);
 assert.match(statusInsight('wither',{turns:2,power:1})!.effect,/1 less total healing/);
 assert.match(statusInsight('rooted',{turns:1,power:1})!.effect,/Casting and Guard still work/);
 assert.match(statusInsight('anchored',{turns:1,power:1})!.effect,/Voluntary movement is unaffected/);
 assert.match(statusInsight('haste',{turns:1,power:1})!.effect,/Does not stack with a current/);
 assert.match(statusInsight('blind',{turns:1,power:1})!.effect,/Self spells still target only the caster/);
});

test('expired statuses never occupy UI and movement/casting restrictions lead the stack',()=>{
 const entries=activeStatusInsights({ward:{turns:2,power:4},wet:{turns:0,power:1},rooted:{turns:1,power:1},blind:{turns:1,power:1}});
 assert.deepEqual(entries.map(entry=>entry.id),['rooted','blind','ward']);
 assert.equal(entries.at(-1)!.powerLabel,'4');assert.equal(entries[0].powerLabel,undefined);
});

test('hover card fits phone, landscape and desktop edges without clipping below or to the right',()=>{
 for(const viewport of [{width:360,height:640},{width:640,height:360},{width:1366,height:768},{width:280,height:320}]){
  for(const anchor of [{left:0,right:30,top:0,bottom:30},{left:viewport.width-30,right:viewport.width,top:viewport.height-30,bottom:viewport.height},{left:100,right:130,top:viewport.height/2,bottom:viewport.height/2+30}]){
   const box=insightPosition(anchor,{width:300,height:220},viewport);
   assert.ok(box.left>=8);assert.ok(box.top>=8);assert.ok(box.left+box.width<=viewport.width-8);assert.ok(box.top+Math.min(220,box.maxHeight)<=viewport.height-8);
  }
 }
 const narrow=insightPosition({left:30,right:60,top:40,bottom:70},{width:300,height:700},{width:280,height:320});assert.equal(narrow.width,264);assert.equal(narrow.maxHeight,304);assert.equal(narrow.top,8);
});

const require=createRequire(import.meta.url),cache=new Map<string,{exports:Record<string,unknown>}>();
function load(filename:string):Record<string,unknown>{
 const existing=cache.get(filename);if(existing)return existing.exports;
 const module={exports:{} as Record<string,unknown>};cache.set(filename,module);
 const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 const local=(specifier:string):unknown=>{if(specifier.endsWith('.css'))return {};if(!specifier.startsWith('.'))return require(specifier);const path=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js'].map(ext=>path+ext).find(existsSync);assert.ok(found);return /\.tsx?$/.test(found)?load(found):require(found)};
 new Function('require','module','exports',js)(local,module,module.exports);return module.exports;
}
const component=load(fileURLToPath(new URL('../app/components/BattleInsightV24.tsx',import.meta.url)));

test('status chips provide a named touch and keyboard action without mounting closed popovers',()=>{
 const Chips=component.StatusChips as ComponentType<{statuses:Partial<Record<StatusId,Status>>}>;
 const html=renderToStaticMarkup(createElement(Chips,{statuses:{ward:{turns:2,power:5},burn:{turns:1,power:1}}}));
 assert.match(html,/aria-label="Ward 5, 2 rounds left\. Inspect effect\."/);assert.match(html,/aria-haspopup="dialog"/);assert.match(html,/aria-expanded="false"/);assert.match(html,/>2r</);assert.doesNotMatch(html,/role="dialog"/);assert.equal((html.match(/<button /g)??[]).length,2);
 assert.equal(renderToStaticMarkup(createElement(Chips,{statuses:{}})),'');
});

test('vitals retain exact health and Flux even when meters show proportional fill',()=>{
 const Vitals=component.CombatVitals as ComponentType<{unit:{hp:number;maxHp:number;flux:number;maxFlux:number}}>;
 const html=renderToStaticMarkup(createElement(Vitals,{unit:{hp:3,maxHp:12,flux:4,maxFlux:6}}));
 assert.match(html,/<b>3<\/b>\/12 HP/);assert.match(html,/<b>4<\/b>\/6 Flux/);assert.match(html,/--fill:25%/);
});
