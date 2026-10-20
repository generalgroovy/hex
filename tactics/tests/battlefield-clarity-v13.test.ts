import assert from 'node:assert/strict';
import test from 'node:test';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import ts from 'typescript';
import {createSimGame,legalMoves,resolveRound,type SimState,type TeamPlan} from '../lib/tactics-v13.ts';
import {visibleStatusStack,resolutionFacing,screenFacing} from '../lib/battlefield-clarity-v13.ts';
import {planningForecast} from '../lib/planning-forecast-v13.ts';
import {formatTile} from '../lib/board-labels-v9.ts';

type Props=Parameters<typeof import('../app/components/PixelBattlefieldV13.tsx').default>[0];
type ElementNode={type:unknown;props:Record<string,any>};
type EffectSlot={deps?:unknown[];cleanup?:()=>void};

/** Execute the real component's hooks and toolbar events without a DOM.
 * Geometry, touch hit targets and visual fit still require the browser checks. */
function board(initial:Props,viewport?:{width:number;height:number}) {
  const slots:unknown[]=[];
  let index=0,dirty=false,props=initial,tree:ElementNode;
  const effects:Array<()=>void>=[];
  const react={
    useState:(initial:unknown)=>{
      const slot=index++;
      if(!(slot in slots)){const value=typeof initial==='function'?initial():initial;slots[slot]=viewport&&value&&typeof value==='object'&&'width' in value&&'height' in value?viewport:value;}
      return [slots[slot],(next:unknown)=>{const value=typeof next==='function'?next(slots[slot]):next;if(!Object.is(slots[slot],value)){slots[slot]=value;dirty=true;}}];
    },
    useRef:(initial:unknown)=>{const slot=index++;if(!(slot in slots))slots[slot]={current:initial};return slots[slot];},
    useMemo:(compute:()=>unknown)=>{index++;return compute();},
    useId:()=>{index++;return 'camera-test';},
    useEffect:(effect:()=>void|(()=>void),deps?:unknown[])=>{
      const slot=index++,previous=slots[slot] as EffectSlot|undefined;
      if(previous&&deps?.length===previous.deps?.length&&deps?.every((dep,i)=>Object.is(dep,previous.deps![i])))return;
      slots[slot]={deps};
      effects.push(()=>{previous?.cleanup?.();const cleanup=effect();(slots[slot] as EffectSlot).cleanup=typeof cleanup==='function'?cleanup:undefined;});
    },
  };
  const require=createRequire(import.meta.url),modules=new Map<string,{exports:any}>();
  function load(filename:string):any {
    const cached=modules.get(filename);if(cached)return cached.exports;
    const module={exports:{}};modules.set(filename,module);
    const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
    const localRequire=(specifier:string):unknown=>{
      if(specifier==='react')return react;
      if(specifier.endsWith('.css'))return {};
      if(!specifier.startsWith('.'))return require(specifier);
      const target=resolve(dirname(filename),specifier);
      const found=['','.ts','.tsx','.js','.json'].map(suffix=>target+suffix).find(path=>existsSync(path));
      assert.ok(found,`missing component dependency ${specifier}`);
      return /\.tsx?$/.test(found)?load(found):require(found);
    };
    new Function('require','module','exports','setTimeout','clearTimeout',js)(localRequire,module,module.exports,()=>1,()=>{});
    return module.exports;
  }
  const Component=load(fileURLToPath(new URL('../app/components/PixelBattlefieldV13.tsx',import.meta.url))).default;
  function render(next:Partial<Props>={}) {
    props={...props,...next};let runs=0;
    do{dirty=false;index=0;tree=Component(props);effects.splice(0).forEach(effect=>effect());assert.ok(++runs<20,'camera effects settle');}while(dirty);
  }
  function nodes(node:unknown):ElementNode[] {
    if(Array.isArray(node))return node.flatMap(nodes);
    if(!node||typeof node!=='object'||!('props' in node))return [];
    const element=node as ElementNode;return [element,...nodes(element.props.children)];
  }
  const text=(node:unknown):string=>Array.isArray(node)?node.map(text).join(''):node&&typeof node==='object'&&'props' in node?text((node as ElementNode).props.children):node===null||node===undefined?'':String(node);
  function click(label:string) {
    const button=nodes(tree).find(node=>node.type==='button'&&(node.props['aria-label']===label||text(node.props.children).trim()===label));
    assert.ok(button,`missing camera button ${label}`);assert.ok(!button.props.disabled,`${label} is enabled`);
    button.props.onClick();render();
  }
  render();
  return {render,click,get nodes(){return nodes(tree);},get text(){return text(tree);},get overview(){return tree.props.className.split(' ').includes('px-tactical-overview');},get focused(){return tree.props.className.split(' ').includes('px-focused');},get viewBox(){return nodes(tree).find(node=>node.type==='svg')!.props.viewBox as string;}};
}

function initial(state:SimState=createSimGame()):Props {
  return {state,plan:{orders:[]},player:0,selected:state.units[0].id,kind:'move',onCell:()=>{},interactive:true,legalTargets:legalMoves(state,state.units[0].id)};
}

test('a new battle exposes both teams and all five wells before any orders',()=>{
  const props=initial(),b=board(props);
  assert.equal(b.focused,false);
  assert.equal(b.nodes.filter(node=>node.props['data-unit-marker']).length,6);
  assert.equal(b.nodes.filter(node=>node.props['data-well']).length,5);
  const overview=b.viewBox;
  const next=props.state.units[2];
  b.render({selected:next.id,focusRequest:1,legalTargets:legalMoves(props.state,next.id)});
  assert.equal(b.viewBox,overview);
  assert.equal(b.focused,false);
  b.click('Focus');assert.equal(b.focused,true);
  b.click('Overview');assert.equal(b.focused,false);assert.equal(b.viewBox,overview);
});

test('an adaptive Focus can always return directly to Overview',()=>{
  const props=initial(),b=board(props),overview=b.viewBox;
  b.click('Focus');
  b.render({kind:'cast',spellId:'water_jet',legalTargets:props.state.cells.filter(cell=>cell.q<=0)});
  const focus=b.viewBox;
  assert.notEqual(focus,overview);
  b.click('Overview');assert.equal(b.viewBox,overview);
  b.click('Focus');assert.equal(b.viewBox,focus);
});

test('phone Focus keeps champion artwork, names, bars and statuses instead of overview markers',()=>{
  const props=initial();props.state.units[0].statuses.burn={turns:2,power:1};
  const b=board(props,{width:390,height:287});
  assert.equal(b.overview,true);b.click('Focus');
  assert.equal(b.overview,false,'adaptive 44px hexes are still character Focus');
  assert.equal(b.nodes.filter(node=>node.props['data-unit-marker']).length,0);
  assert.equal(b.nodes.filter(node=>node.type==='foreignObject').length,6,'all champion artwork remains rendered');
  assert.ok(b.nodes.some(node=>node.props['data-status']==='burn'));
  assert.ok(b.nodes.some(node=>node.props.className==='px-active-name'));
  b.click('Overview');assert.equal(b.overview,true);
});

test('manual pan survives aiming, and deliberate action changes restore planning context',()=>{
  const props=initial(),b=board(props);
  b.click('Focus');const original=b.viewBox;
  b.click('Show battlefield pan controls');b.click('Pan right');const panned=b.viewBox;
  assert.notEqual(panned,original);
  b.render({aimTarget:{q:-3,r:0},affectedTargets:[{q:-3,r:0}]});
  assert.equal(b.viewBox,panned,'hover preview is not a camera instruction');
  b.render({kind:'cast',spellId:'water_jet'});
  assert.equal(b.viewBox,original,'new action restores selected character and legal-space context');
});

test('resolution frames the exchange and restores the exact chosen camera',()=>{
  const props=initial(),b=board(props),unit=props.state.units[0];
  const target=legalMoves(props.state,unit.id).find(point=>point.q!==unit.q||point.r!==unit.r)!;
  const next=resolveRound(props.state,[{orders:[{unitId:unit.id,move:{q:target.q,r:target.r}}]},{orders:[]}]);
  const overview=b.viewBox;
  b.render({state:next,previousState:props.state,resolving:true,interactive:false});
  assert.equal(b.focused,true);
  b.render({resolving:false,interactive:true});
  assert.equal(b.focused,false);assert.equal(b.viewBox,overview);
  b.click('Focus');b.click('Show battlefield pan controls');b.click('Pan right');const panned=b.viewBox;
  b.render({resolving:true,interactive:false});b.render({resolving:false,interactive:true});
  assert.equal(b.focused,true);assert.equal(b.viewBox,panned);
});

test('unselected rivals show the most consequential live statuses with duration and overflow',()=>{
  const props=initial(),rival=props.state.units.find(unit=>unit.owner===1)!;
  rival.statuses={ward:{turns:2,power:1},burn:{turns:1,power:1},rooted:{turns:2,power:1},haste:{turns:0,power:1}};
  const stack=visibleStatusStack(rival.statuses);
  assert.deepEqual(stack.visible.map(([id])=>id),['rooted','burn']);assert.equal(stack.hidden,1);
  const b=board(props);b.click('Focus');
  assert.ok(b.nodes.some(node=>node.props['data-status-unit']===rival.id));
  assert.ok(b.nodes.some(node=>node.props['data-status']==='rooted'));
  assert.ok(b.nodes.some(node=>node.props['data-status']==='burn'));
  assert.ok(!b.nodes.some(node=>node.props['data-status']==='haste'));
  const tile=b.nodes.find(node=>node.props['data-tile']&&String(node.props['aria-label']).includes('rival,')&&String(node.props['aria-label']).includes('Rooted'));
  assert.ok(tile);assert.match(tile.props['aria-label'],/Ward, 2 rounds/);
  b.click('Overview');assert.equal(b.nodes.filter(node=>node.props['data-status-unit']).length,0);
});

test('a character selected during resolution receives its Focus when planning resumes',()=>{
  const props=initial(),b=board(props);b.click('Focus');const original=b.viewBox;
  const next=props.state.units[2];
  b.render({selected:next.id,resolving:true,interactive:false,focusRequest:1,legalTargets:[]});
  b.render({resolving:false,interactive:true,legalTargets:legalMoves(props.state,next.id)});
  const after=b.viewBox;assert.notEqual(after,original);
  assert.equal(b.nodes.find(node=>node.props['data-tile']&&node.props.tabIndex===0)?.props['data-tile'],formatTile(next),'keyboard tile focus follows the new selected character');
  b.click('Center selected character');assert.equal(b.viewBox,after);
});

test('affected hexes display the shared forecast field and grouped counts without mutating state',()=>{
  const props=initial(),unit=props.state.units[1],cell=props.state.cells.find(cell=>cell.q===unit.q&&cell.r===unit.r)!;
  cell.terrain='water';cell.elements=['water'];cell.ttl=2;
  const before=JSON.stringify(props.state),plan:TeamPlan={orders:[{unitId:unit.id,spellId:'ember',cast:{q:unit.q,r:unit.r}}]};
  const forecast=planningForecast(props.state,0,plan,unit.id,'ember',unit);
  assert.ok(forecast?.groups.some(group=>group.name==='Steam'));
  const b=board({...props,selected:unit.id,kind:'cast',spellId:'ember',plan,aimTarget:unit,affectedTargets:forecast!.cells,forecast});
  assert.ok(b.nodes.some(node=>node.props['data-forecast-field']==='steam'));
  assert.match(b.nodes.find(node=>node.props['data-tile']===formatTile(cell))!.props['aria-label'],/Planned field: Steam/);
  assert.match(b.text,/Planned.*Steam/);assert.match(b.text,/Rival orders may change fields/);
  assert.equal(JSON.stringify(props.state),before);
});

test('selected queued movement stays prominent and keeps exact cost when aiming a spell',()=>{
  const props=initial(),unit=props.state.units[0];
  const target=legalMoves(props.state,unit.id).find(point=>point.q!==unit.q||point.r!==unit.r)!;
  const plan:TeamPlan={orders:[{unitId:unit.id,move:{q:target.q,r:target.r}}]};
  const b=board({...props,plan,kind:'cast',spellId:'water_jet'});
  const landing=b.nodes.find(node=>node.props['data-selected-landing']===formatTile(target));
  assert.ok(landing);assert.ok(landing.props['data-movement-effort']>0);assert.equal(landing.props['data-movement-budget'],4);
  assert.ok(b.nodes.find(node=>node.props['data-order-unit']===unit.id)?.props.className.includes('is-selected'));
  assert.ok(b.nodes.some(node=>node.props.className==='px-selected-spell-summary'),'spell consequences are visible in the board readout before choosing an aim');
  assert.match(b.text,/Water Jet · .*damage/);
  assert.ok(!b.nodes.some(node=>node.props['data-tile-reference']===formatTile(target)),'landing badge replaces duplicate coordinate tag');
});

test('known blocked landings and conditional rival occupancy are distinct on legal targets',()=>{
  const props=initial(),unit=props.state.units[0],ally=props.state.units[1],rival=props.state.units[3];
  props.state.cells.forEach(cell=>Object.assign(cell,{terrain:'plain',biome:'plain',height:0,well:false}));
  Object.assign(unit,{q:0,r:0});Object.assign(ally,{q:1,r:0});Object.assign(rival,{q:0,r:1});
  const b=board({...props,legalTargets:legalMoves(props.state,unit.id)});
  assert.ok(b.nodes.find(node=>node.props['data-risk-tile']===formatTile(ally))?.props.className.includes('is-blocked'));
  assert.ok(b.nodes.find(node=>node.props['data-risk-tile']===formatTile(rival))?.props.className.includes('is-contested'));
  assert.match(b.nodes.find(node=>node.props['data-tile']===formatTile(ally))!.props['aria-label'],/will bounce/);
  assert.match(b.nodes.find(node=>node.props['data-tile']===formatTile(rival))!.props['aria-label'],/if they stay/);
});

test('battlefield shows one actual HP change and no unused healing glow',()=>{
  const previous=createSimGame(),next=structuredClone(previous),unit=next.units[0];
  next.version++;
  next.lastResolution=[{kind:'heal',unitId:unit.id,amount:3,text:'heals3'}];
  const b=board({...initial(next),previousState:previous,resolving:true,interactive:false});
  assert.equal(b.nodes.filter(node=>node.props['data-health-feedback']).length,0);
  assert.ok(!b.nodes.some(node=>node.props.className==='px-heal-glow'));
  unit.hp-=2;
  next.lastResolution=[{kind:'damage',unitId:unit.id,amount:4,text:'damage4'},{kind:'heal',unitId:unit.id,amount:3,text:'heals3'},{kind:'surface',unitId:unit.id,amount:1,terrain:'fire',text:'terrain1'}];
  b.render({state:structuredClone(next)});
  assert.equal(b.nodes.filter(node=>node.props['data-health-feedback']===unit.id).length,1);
  assert.match(b.text,/−2 HP/);assert.doesNotMatch(b.text,/−1 TERRAIN/);
  assert.ok(!b.nodes.some(node=>node.props.className==='px-heal-glow'));
  assert.equal(b.nodes.find(node=>node.props['data-health-feedback']===unit.id)!.props.style['--px-event-delay'],'1450ms');
});

test('movement faces the route before turning toward a spell behind the character',()=>{
  const from={q:0,r:0},route=[{q:1,r:0},{q:1,r:1}],cast={from:route[1],to:{q:-1,r:1}};
  assert.equal(resolutionFacing('move',from,route,cast),screenFacing(from,route[0]));
  assert.equal(resolutionFacing('cast',from,route,cast),screenFacing(cast.from,cast.to));
  assert.notEqual(resolutionFacing('move',from,route,cast),resolutionFacing('cast',from,route,cast));
  assert.equal(resolutionFacing('settle',from,route,undefined),screenFacing(route[0],route[1]));
});


