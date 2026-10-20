import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import ts from 'typescript';
import {createSimGame,validatePlan,type TeamPlan} from '../lib/tactics-v13.ts';

// Exercise the shipped component functions with the browser/network boundary
// replaced. Historical combat remains in its original engine and is tested
// separately; this checks that an old route can actually reach the new match.
function componentFunction(file: string, name: string, environment: Record<string, unknown>) {
  const source = ts.createSourceFile(file, readFileSync(new URL(`../${file}`, import.meta.url), 'utf8'), ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
  let found: ts.FunctionDeclaration | undefined;
  const visit = (node: ts.Node) => { if (ts.isFunctionDeclaration(node) && node.name?.text === name) found = node; ts.forEachChild(node, visit); };
  visit(source);
  assert.ok(found, `${file} must expose the ${name} interaction`);
  const javascript = ts.transpileModule(found.getText(source), { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.None } }).outputText;
  return new Function(...Object.keys(environment), `${javascript}; return ${name};`)(...Object.values(environment));
}

test('HTTP protocol header parsing recognizes current and historical versions without accepting malformed values', () => {
  const protocol = componentFunction('app/api/rooms/_shared.ts', 'protocol', { exports: {} });
  for (let version = 1; version <= 16; version++) {
    assert.equal(protocol(new Request('https://example.test', { headers: { 'X-Confluence-Protocol': String(version) } })), version);
  }
  assert.equal(protocol(new Request('https://example.test')), 1);
  for (const value of ['09', '9.0', '014', '14.0', '015', '016', '16.0', '17', 'invalid']) {
    assert.equal(protocol(new Request('https://example.test', { headers: { 'X-Confluence-Protocol': value } })), value);
  }
});

for (const file of ['app/TacticsGameV15.tsx', 'app/TacticsGameV14.tsx', 'app/TacticsGameV13.tsx', 'app/TacticsGameV12.tsx', 'app/TacticsGameV11.tsx', 'app/TacticsGameV10.tsx', 'app/TacticsGameV9.tsx', 'app/V8Game.tsx', 'app/V7Game.tsx', 'app/V6Game.tsx', 'app/V5Game.tsx', 'app/V4Game.tsx', 'app/V3Game.tsx', 'app/SimGame.tsx', 'app/classic/page.tsx']) {
  test(`${file}: existing room reads observe v16, rematches consent explicitly, and new seats use current setup`, async () => {
    const classic = file.includes('/classic/');
    const session = { code: '23456789ABCD', token: 'a'.repeat(64), seat: 0 };
    const calls: { url: string; init: RequestInit }[] = [];
    const navigations: string[] = [];
    const accepted: unknown[] = [];
    const currentRoom = { code: session.code, version: 4, rulesVersion: 16, status: 'active', state: { rulesVersion: 16 } };
    const noop = () => {};
    const environment: Record<string, unknown> = {
      mode: 'online', loadoutsReady:true, roster: ['oh_tipi', 'haara', 's_wayne'], firstRoster: null, firstCompany: null, selectedMapId: 'reach:WELLSPRING',
      joining: false, code: '', name: 'Player', room: { version: 3 },
      requestBusy: { current: false }, activeSession: { current: session }, epoch: { current: 0 }, generation: { current: 0 },
      revision: { current: -1 }, reconnectError: { current: '' }, storageWarning: { current: '' },
      setError: noop, setNotice: noop, setBusy: noop, setConnected: noop, setSelected: noop, setActiveStory: noop,
      current: () => true, readSeat: () => null, savedSession: () => null,
      localStorage: { setItem: noop }, location: { assign: (url: string) => navigations.push(url), replace: (url: string) => navigations.push(url) },
      fetch: async (url: string, init: RequestInit) => { calls.push({ url, init }); return { ok: true, status: 200 }; },
      responseData: async () => ({ room: currentRoom }), readRoomResponse: async () => ({ room: currentRoom }),
      acceptRoom: (room: unknown) => accepted.push(room),
    };
    const refresh = componentFunction(file, classic ? 'refreshRoom' : 'refresh', environment);
    await refresh(session, 0);
    assert.equal(calls.length, 1);
    assert.equal((calls[0].init.headers as Record<string, string>)['X-Confluence-Protocol'], '16');
    assert.deepEqual(accepted, [currentRoom]);

    const accept = componentFunction(file, 'acceptRoom', environment);
    accept(currentRoom, 0);
    assert.equal(navigations.pop(), `/?room=${session.code}`, 'updated snapshots must leave the historical engine before installing new state');

    calls.length = 0;
    const rematch = componentFunction(file, 'rematch', environment);
    await rematch();
    assert.equal(calls.length, 1);
    assert.equal(calls[0].url, `/api/rooms/${session.code}/rematch`);
    assert.equal(JSON.parse(calls[0].init.body as string).protocolVersion, 16);

    calls.length = 0;
    const launch = componentFunction(file, 'launch', environment);
    await launch();
    assert.deepEqual(navigations, ['/']);
    assert.equal(calls.length, 0, 'new seats must be created through the current game and its retained join-key flow');

    const invitedLaunch = componentFunction(file, 'launch', { ...environment, joining: true, code: session.code, normalizeCode: (code: string) => code, matchCode: (code: string) => code });
    await invitedLaunch();
    assert.equal(navigations.at(-1), `/?room=${session.code}`);
    assert.equal(calls.length, 0, 'an invitation without a saved seat must preserve its code during handoff');
  });
}

test('the frozen v13 client still submits v13 sealed plans while current rematch consent uses v16',async()=>{
  const game=createSimGame(),plan:TeamPlan={orders:[{unitId:'0-oh_tipi',guard:true}]};
  const session={code:'23456789ABCD',token:'a'.repeat(64),seat:0};
  const room={code:session.code,matchId:'released-v13-match',version:2,rulesVersion:13,state:game};
  const calls:{url:string;init:RequestInit}[]=[],accepted:unknown[]=[],errors:unknown[]=[];
  const noop=()=>{};
  const requestBusy={current:false};
  const lock=componentFunction('app/TacticsGameV13.tsx','lockPlan',{
    canPlan:true,requestBusy,mode:'online',game,seat:0,plan,room,
    validatePlan,chime:noop,setError:(error:unknown)=>errors.push(error),setBusy:noop,setConnected:noop,setNotice:noop,
    activeSession:{current:session},epoch:{current:0},current:()=>true,
    fetch:async(url:string,init:RequestInit)=>{calls.push({url,init});return {ok:true,status:200}},
    responseData:async()=>({room}),acceptRoom:(value:unknown)=>accepted.push(value),
  });
  await lock();
  assert.deepEqual(errors,['']);assert.equal(calls.length,1);
  assert.equal(calls[0].url,`/api/rooms/${session.code}/plan`);
  assert.deepEqual(JSON.parse(calls[0].init.body as string),{
    matchId:room.matchId,round:game.round,plan:validatePlan(game,0,plan),protocolVersion:13,
  });
  assert.deepEqual(accepted,[room]);assert.equal(requestBusy.current,false);
});
