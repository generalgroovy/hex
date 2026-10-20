import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {createTowerRun,towerFloorRooms,type TowerRoom} from '../lib/tower-v23.ts';
import type {TowerRouteParty,TowerFriendDestination} from '../lib/tower-route-party-v43.ts';

const nodeRequire=createRequire(import.meta.url),modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown>{
 const cached=modules.get(filename);if(cached)return cached.exports;
 const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
 const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 const local=(specifier:string):unknown=>{if(specifier.endsWith('.css'))return {};if(!specifier.startsWith('.'))return nodeRequire(specifier);const path=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(ext=>path+ext).find(existsSync);assert.ok(found);return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found)};
 new Function('require','module','exports',js)(local,module,module.exports);return module.exports;
}
const Component=loadSource(fileURLToPath(new URL('../app/components/TowerPartyRouteV43.tsx',import.meta.url))).default as (props:any)=>any;
const rooms=towerFloorRooms(createTowerRun('PARTY-UI-43','steam',3)),noop=()=>{};
function friend(seat:number,roomId:string|null,extra:Partial<TowerFriendDestination>={}):TowerFriendDestination{return {seat,name:`Friend ${seat}`,phase:'route',floor:1,roomId,roomName:rooms.find(room=>room.id===roomId)?.name??null,roomKind:roomId?'combat':null,withYou:false,action:roomId?{kind:'join',roomId}:null,...extra};}
function model(friends:TowerFriendDestination[],counts:Record<string,number>={}):TowerRouteParty{return {ownChoiceId:null,roomPlayers:{},choosingSeats:friends.filter(friend=>friend.phase==='route'&&!friend.roomId).map(friend=>friend.seat),encounterCounts:counts,friends};}
const html=(party:TowerRouteParty,options:Record<string,unknown>={})=>renderToStaticMarkup(createElement(Component,{party,rooms,onJoin:noop,onWatch:noop,...options})).replaceAll('&#x27;',"'").replaceAll('&amp;','&');
function nodes(node:any,predicate:(node:any)=>boolean):any[]{if(node===null||node===undefined||typeof node!=='object')return [];if(Array.isArray(node))return node.flatMap(child=>nodes(child,predicate));return [...(predicate(node)?[node]:[]),...nodes(node.props?.children,predicate)];}
const text=(node:any):string=>Array.isArray(node)?node.map(text).join(''):node&&typeof node==='object'?text(node.props?.children):node===null||node===undefined?'':String(node);
const buttons=(tree:any)=>nodes(tree,node=>node.type==='button');

test('friends sharing one exact destination receive one named Join fight control',()=>{
 const party=model([friend(1,'floor-1-0'),friend(2,'floor-1-0')],{'floor-1-0':6}),markup=html(party);
 assert.match(markup,/aria-label="Friends’ destinations"/);assert.equal((markup.match(/<article /g)??[]).length,1);assert.equal((markup.match(/>Join fight/g)??[]).length,1);
 assert.match(markup,/aria-label="Join Friend 1, Friend 2 on path a"/);assert.match(markup,/data-seat="1"/);assert.match(markup,/data-seat="2"/);
});

test('identically named rooms remain separate groups and use distinct path labels',()=>{
 const repeated=rooms.map(room=>({...room,name:'The same room'})),party=model([friend(1,'floor-1-0'),friend(2,'floor-1-1')],{'floor-1-0':4,'floor-1-1':4}),markup=html(party,{rooms:repeated});
 assert.equal((markup.match(/<article /g)??[]).length,2);assert.equal((markup.match(/>Join fight/g)??[]).length,2);
 assert.match(markup,/Path A · The same room/);assert.match(markup,/Path B · The same room/);assert.match(markup,/Join Friend 1 on path a/);assert.match(markup,/Join Friend 2 on path b/);
});

test('together and unreachable groups never present a misleading join button',()=>{
 const party=model([friend(1,'floor-1-0',{withYou:true,action:{kind:'preview',roomId:'floor-1-0'},reason:'already-together'}),friend(2,'floor-1-4',{action:{kind:'preview',roomId:'floor-1-4'},reason:'different-path'})]);
 const markup=html(party);assert.match(markup,/With you/);assert.match(markup,/Different path/);assert.doesNotMatch(markup,/Join fight|Go together/);
 const locked=html(model([friend(1,'floor-1-0',{action:{kind:'preview',roomId:'floor-1-0'},reason:'floor-locked'})]));
 assert.doesNotMatch(locked,/Different path|Join fight|Go together/);assert.match(locked,/Wait|Unavailable|Waiting/);
});

test('safe stops use Go together while fights and waiting friends retain accurate actions',()=>{
 const camp={...rooms[0],kind:'camp',enemies:[]} as TowerRoom;
 const party=model([friend(1,camp.id,{roomKind:'camp'}),friend(2,null,{phase:'battle',action:{kind:'watch',seat:2}}),friend(3,null,{phase:'barrier'}),friend(4,null)]),markup=html(party,{rooms:[camp]});
 assert.match(markup,/Go together/);assert.doesNotMatch(markup,/Join fight/);assert.match(markup,/Watch fight/);assert.match(markup,/aria-label="[^"]*Friend 2[^"]*"/);
 assert.match(markup,/At the stairs/);assert.match(markup,/Choosing:/);assert.match(markup,/Friend 4/);
});

test('join and watch callbacks target the exact room and seat; offline controls are disabled',()=>{
 const joined:string[]=[],watched:number[]=[],party=model([friend(1,'floor-1-3'),friend(2,null,{phase:'battle',action:{kind:'watch',seat:2}})],{'floor-1-3':4});
 const props={party,rooms,onJoin:(id:string)=>joined.push(id),onWatch:(seat:number)=>watched.push(seat)},tree=Component(props);
 const join=buttons(tree).find(node=>text(node).includes('Join fight'))!,watch=buttons(tree).find(node=>text(node).includes('Watch fight'))!;
 assert.ok(join);assert.ok(watch);join.props.onClick();watch.props.onClick();assert.deepEqual(joined,['floor-1-3']);assert.deepEqual(watched,[2]);
 const disabled=buttons(Component({...props,disabled:true}));assert.equal(disabled.length,2);assert.ok(disabled.every(button=>button.props.disabled===true));
});

test('long valid player names remain complete and only the selected room identifier controls joining',()=>{
 const first='abcdefghijklmnopqrstuvwx',second='ABCDEFGHIJKLMNOPQRSTUVWX',party=model([friend(1,'floor-1-7',{name:first}),friend(2,'floor-1-7',{name:second})],{'floor-1-7':6});
 const high={...rooms[0],id:'floor-1-7'},markup=html(party,{rooms:[high]});
 assert.ok(markup.includes(first));assert.ok(markup.includes(second));assert.match(markup,/Path H/);assert.equal((markup.match(/>Join fight/g)??[]).length,1);
 const join=buttons(Component({party,rooms:[high],onJoin:noop,onWatch:noop}))[0];assert.ok(join.props['aria-label'].includes(first));assert.ok(join.props['aria-label'].includes(second));
 assert.equal(html(model([])),'');
});


test('an unaffordable friend event shows the HP requirement instead of an invalid shortcut',()=>{
 const event={...rooms[0],id:'floor-3-2',floor:3,kind:'event',enemies:[]} as TowerRoom;
 const party=model([friend(1,event.id,{floor:3,roomKind:'event',action:{kind:'preview',roomId:event.id},reason:'low-health'})]);
 const markup=html(party,{rooms:[event]});assert.match(markup,/Requires 3 HP/);assert.doesNotMatch(markup,/Go together|Join fight|Different path/);
 assert.equal(buttons(Component({party,rooms:[event],onJoin:noop,onWatch:noop})).length,0);
});
