import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import test from 'node:test';
import ts from 'typescript';
import {availableSpellIds,effectiveSpell,getSpell} from '../lib/spells-v15.ts';
import {castAvailability,createSimGame,getChampion,isAlive,legalCasts,legalMoves,validatePlan,type Order,type SimState,type TeamPlan} from '../lib/tactics-v15.ts';
import {editMovement} from '../lib/order-editing-v15.ts';
import {planReadiness} from '../lib/battle-guidance-v15.ts';
import {canonicalPlan} from '../lib/room-plans.ts';
import {formatTile} from '../lib/board-labels-v9.ts';

// Exercise the shipped handlers and selected-order markup together. Real rules
// decide legality; only React setters and the audible selection cue are isolated.
const source=ts.createSourceFile('TacticsGame.tsx',readFileSync(new URL('../app/TacticsGameV15.tsx',import.meta.url),'utf8'),ts.ScriptTarget.Latest,true,ts.ScriptKind.TSX);
const handlers=new Map<string,string>(),fragments=new Map<string,string>();
const compile=(code:string)=>ts.transpileModule(code,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX}}).outputText;
function visit(node:ts.Node){
  if(ts.isFunctionDeclaration(node)&&node.name)handlers.set(node.name.text,compile(node.getText(source)));
  if(ts.isJsxElement(node)){
    const className=node.openingElement.attributes.properties.find(attribute=>ts.isJsxAttribute(attribute)&&attribute.name.getText(source)==='className') as ts.JsxAttribute|undefined;
    if(className?.initializer&&ts.isStringLiteral(className.initializer)){
      if(className.initializer.text.includes('tx-selected-order'))fragments.set('order',node.getText(source));
      if(className.initializer.text==='tx-order-notice')fragments.set('notice',node.getText(source));
    }
  }
  ts.forEachChild(node,visit);
}
visit(source);
type Node={type:unknown;props:Record<string,any>};
const children=(node:unknown):Node[]=>Array.isArray(node)?node.flatMap(children):node&&typeof node==='object'&&'props' in node?[node as Node,...children((node as Node).props.children)]:[];
const text=(node:unknown):string=>Array.isArray(node)?node.map(text).join(' '):node&&typeof node==='object'&&'props' in node?text((node as Node).props.children):node===null||node===undefined||typeof node==='boolean'?'':String(node);

function arena(){
  const state=createSimGame();
  for(const cell of state.cells){cell.biome='plain';cell.height=0;cell.terrain='plain';delete cell.elements;delete cell.reactions;delete cell.barrier;delete cell.ice;delete cell.ttl;}
  Object.assign(state.units[0],{q:0,r:0});
  return state;
}
function harness(state:SimState,initial:TeamPlan){
  const env:Record<string,any>={game:state,planningGame:state,plan:structuredClone(initial),planHistory:[],selected:state.units[0].id,seat:0,canPlan:true,kind:'move',spellId:'water_jet',hoverAim:{q:1,r:0},focusRequest:0,error:'',notice:'',inspect:null,
    editMovement,canonicalPlan,availableSpellIds,castAvailability,getChampion,getSpell,legalCasts,legalMoves,alive:isAlive,coord:formatTile,same:(a:{q:number;r:number},b:{q:number;r:number})=>a.q===b.q&&a.r===b.r,chime:()=>{},nextCharacter:()=>{},
  };
  for(const field of ['plan','planHistory','selected','kind','spellId','hoverAim','focusRequest','error','notice','inspect'])env[`set${field[0].toUpperCase()}${field.slice(1)}`]=(value:unknown)=>{env[field]=typeof value==='function'?value(env[field]):value;};
  function derive(){
    env.unit=state.units.find(unit=>unit.id===env.selected);env.champion=env.unit?getChampion(env.unit.championId):null;
    env.order=env.plan.orders.find((order:Order)=>order.unitId===env.selected);
    env.chosenSpell=env.unit?effectiveSpell(env.unit.championId,env.spellId||env.unit.loadout[0],env.unit.affinities):null;
    env.readiness=planReadiness(state,env.seat,env.plan);
    env.targets=env.unit?(env.kind==='move'?legalMoves(state,env.unit.id):legalCasts(state,env.unit.id,env.order?.move,env.chosenSpell.id)):[];
  }
  function call(name:string,...args:unknown[]){derive();const code=handlers.get(name);assert.ok(code,`actual ${name} handler exists`);const result=new Function(...Object.keys(env),`${code};return ${name};`)(...Object.values(env))(...args);derive();return result;}
  for(const name of ['revisePlan','editOrder','changeMove','selectUnit','undoPlan','chooseSpell'])env[name]=(...args:unknown[])=>call(name,...args);
  function render(fragment:'order'|'notice'){
    derive();const jsx=fragments.get(fragment);assert.ok(jsx,`actual ${fragment} markup exists`);
    const code=compile(`const render=()=>(${jsx});`);
    return new Function('require','exports',...Object.keys(env),`${code};return render();`)(createRequire(import.meta.url),{},...Object.values(env));
  }
  function click(label:string){const button=children(render('order')).find(node=>node.type==='button'&&node.props['aria-label']===label);assert.ok(button,`order control ${label} exists`);assert.equal(button.props.disabled,false);button.props.onClick();derive();}
  derive();return {env,call,render,click};
}

test('Hold removes only movement, preserves a legal cast and teammates, and Undo restores the exact plan',()=>{
  const state=arena(),unit=state.units[0],other=state.units[1];
  const plan:TeamPlan={orders:[{unitId:unit.id,move:{q:2,r:0},spellId:'water_jet',cast:{q:3,r:0}},{unitId:other.id,guard:true}]};
  validatePlan(state,0,plan);const before=structuredClone({state,plan}),h=harness(state,plan);
  h.click('Hold position; remove only this move');
  assert.equal(h.env.order.move,undefined);assert.deepEqual(h.env.order.cast,{q:3,r:0});assert.equal(h.env.order.spellId,'water_jet');assert.equal(h.env.order.guard,undefined);
  assert.deepEqual(h.env.plan.orders.find((order:Order)=>order.unitId===other.id),plan.orders[1]);
  assert.ok(h.env.readiness.readyIds.includes(unit.id));assert.equal(h.env.kind,'cast');assert.equal(h.env.hoverAim,null);assert.equal(h.env.notice,'');
  assert.match(text(h.render('order')),/Stay.*Water Jet/);validatePlan(state,0,h.env.plan);
  h.call('undoPlan');assert.deepEqual(h.env.plan,plan);assert.equal(h.env.planHistory.length,0);assert.equal(h.env.selected,unit.id);
  assert.deepEqual({state,plan},before,'editing never mutates the board or original order objects');
});

test('Hold preserves deliberate Guard and stays a complete action',()=>{
  const state=arena(),unit=state.units[0],h=harness(state,{orders:[{unitId:unit.id,move:{q:2,r:0},guard:true}]});
  h.click('Hold position; remove only this move');
  assert.equal(h.env.order.move,undefined);assert.equal(h.env.order.guard,true);assert.equal(h.env.order.cast,undefined);
  assert.ok(h.env.readiness.readyIds.includes(unit.id));assert.equal(h.env.kind,'move');assert.match(text(h.render('order')),/Stay.*Guard/);
  validatePlan(state,0,h.env.plan);
});

test('removing a move-dependent cast leaves a visible incomplete order and actionable inline Undo',()=>{
  const state=arena(),unit=state.units[0],plan:TeamPlan={orders:[{unitId:unit.id,move:{q:2,r:0},spellId:'water_jet',cast:{q:6,r:0}}]};
  validatePlan(state,0,plan);assert.ok(!legalCasts(state,unit.id,undefined,'water_jet').some(cell=>cell.q===6&&cell.r===0));
  const h=harness(state,plan);h.click('Hold position; remove only this move');
  assert.equal(h.env.order.cast,undefined);assert.equal(h.env.order.spellId,undefined);assert.equal(h.env.order.guard,undefined);
  assert.ok(h.env.readiness.remainingIds.includes(unit.id));assert.match(text(h.render('order')),/Stay.*Choose spell/);
  const notice=h.render('notice');assert.equal(notice.props.role,'status');assert.match(text(notice),/Water Jet cannot reach.*Choose a new aim or Undo/);
  const undo=children(notice).find(node=>node.type==='button'&&text(node)==='Undo');assert.ok(undo);undo.props.onClick();
  assert.deepEqual(h.env.plan,plan);assert.equal(h.env.planHistory.length,0);validatePlan(state,0,h.env.plan);
});

test('choosing another legal destination retains its existing cast and changes one undoable order',()=>{
  const state=arena(),unit=state.units[0],other=state.units[1],plan:TeamPlan={orders:[{unitId:unit.id,move:{q:2,r:0},spellId:'water_jet',cast:{q:3,r:0}},{unitId:other.id,guard:true}]};
  const h=harness(state,plan);h.call('cell',1,0);
  assert.deepEqual(h.env.order.move,{q:1,r:0});assert.deepEqual(h.env.order.cast,{q:3,r:0});assert.equal(h.env.order.spellId,'water_jet');assert.equal(h.env.kind,'cast');
  assert.deepEqual(h.env.plan.orders.find((order:Order)=>order.unitId===other.id),plan.orders[1]);assert.equal(h.env.planHistory.length,1);assert.equal(h.env.notice,'');
  validatePlan(state,0,h.env.plan);h.call('undoPlan');assert.deepEqual(h.env.plan,plan);
});

test('movement edits respect the planning lock and never accept an unreachable destination',()=>{
  const state=arena(),unit=state.units[0],plan:TeamPlan={orders:[{unitId:unit.id,move:{q:2,r:0},guard:true}]};
  const h=harness(state,plan);h.env.canPlan=false;h.call('changeMove');assert.deepEqual(h.env.plan,plan);assert.equal(h.env.planHistory.length,0);
  h.env.canPlan=true;assert.throws(()=>h.call('changeMove',{q:9,r:9}),/out of reach/);assert.deepEqual(h.env.plan,plan);assert.equal(h.env.planHistory.length,0);
});
