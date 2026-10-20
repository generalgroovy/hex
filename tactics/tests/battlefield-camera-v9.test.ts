import assert from 'node:assert/strict';
import test from 'node:test';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import ts from 'typescript';
import {createSimGame,legalMoves,resolveRound,type SimState,type TeamPlan} from '../lib/tactics-v9.ts';

type Props=Parameters<typeof import('../app/components/PixelBattlefieldV9.tsx').default>[0];
type ElementNode={type:unknown;props:Record<string,any>};
type EffectSlot={deps?:unknown[];cleanup?:()=>void};

/** Execute the real component's hooks and toolbar events without a DOM.
 * Geometry, touch hit targets and visual fit still require the browser checks. */
function board(initial:Props) {
  const slots:unknown[]=[];
  let index=0,dirty=false,props=initial,tree:ElementNode;
  const effects:Array<()=>void>=[];
  const react={
    useState:(initial:unknown)=>{
      const slot=index++;
      if(!(slot in slots))slots[slot]=typeof initial==='function'?initial():initial;
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
  const Component=load(fileURLToPath(new URL('../app/components/PixelBattlefieldV9.tsx',import.meta.url))).default;
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
  return {render,click,get focused(){return tree.props.className.split(' ').includes('px-focused');},get viewBox(){return nodes(tree).find(node=>node.type==='svg')!.props.viewBox as string;}};
}

function initial(state:SimState=createSimGame()):Props {
  return {state,plan:{orders:[]},player:0,selected:state.units[0].id,kind:'move',onCell:()=>{},interactive:true};
}

test('Overview survives character switches, repeat selection and planned movement',()=>{
  const props=initial(),b=board(props);
  assert.equal(b.focused,true);
  b.click('− Overview');const overview=b.viewBox;
  assert.equal(b.focused,false);
  const next=props.state.units[1];
  b.render({selected:next.id,focusRequest:1});
  assert.equal(b.focused,false);assert.equal(b.viewBox,overview);
  b.render({focusRequest:2});
  assert.equal(b.focused,false,'selecting the same portrait does not undo Overview');
  const landing=legalMoves(props.state,next.id).find(point=>point.q!==next.q||point.r!==next.r)!;
  const plan:TeamPlan={orders:[{unitId:next.id,move:{q:landing.q,r:landing.r}}]};
  b.render({plan});
  assert.equal(b.focused,false);assert.equal(b.viewBox,overview,'planning a move keeps the whole-map context');
});

test('Center and Focus explicitly restore the selected character after Overview',()=>{
  const props=initial(),b=board(props);const first=b.viewBox;
  b.click('− Overview');b.render({selected:props.state.units[2].id,focusRequest:1});
  b.click('Center selected character');
  assert.equal(b.focused,true);assert.notEqual(b.viewBox,first,'Center uses the new selected character');
  const selectedView=b.viewBox;
  b.click('− Overview');b.click('+ Focus');
  assert.equal(b.focused,true);assert.equal(b.viewBox,selectedView);
});

test('focused view continues following character selection without an extra camera click',()=>{
  const props=initial(),b=board(props);const first=b.viewBox;
  b.render({selected:props.state.units[2].id,focusRequest:1});
  assert.equal(b.focused,true);assert.notEqual(b.viewBox,first);
});

test('resolution temporarily frames the action and returns to the chosen Overview',()=>{
  const props=initial(),b=board(props);
  const unit=props.state.units[0],target=legalMoves(props.state,unit.id).find(point=>point.q!==unit.q||point.r!==unit.r)!;
  const next=resolveRound(props.state,[{orders:[{unitId:unit.id,move:{q:target.q,r:target.r}}]},{orders:[]}]);
  b.click('− Overview');const overview=b.viewBox;
  b.render({state:next,previousState:props.state,resolving:true,interactive:false});
  assert.equal(b.focused,true,'the actual exchange is still framed during playback');
  b.render({resolving:false,interactive:true});
  assert.equal(b.focused,false);assert.equal(b.viewBox,overview);
});
