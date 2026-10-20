import {writeFileSync} from 'node:fs';
import {createTowerBattle,resolveRound,battleSpell,castAvailability} from '../../../lib/tactics-v22.ts';
import {defaultLoadout,getSpell} from '../../../lib/spells-v20.ts';
import {profileSpell,spellProfileBands} from '../../../lib/spell-profile-v42.ts';
const make=(id,championId,affinities,spells)=>({id,championId,affinities,loadout:spells??defaultLoadout(championId,affinities),hp:8,maxHp:8,maxFlux:6});
const hero=make('light','haara',{light:3,air:1,water:1},['sunburst','radiant_bolt','mend','clear_sight']);
const rival=make('rival','wa_bidi',{fire:3,water:1,air:1});
function plain(state){for(const c of state.cells){c.terrain='plain';c.biome='plain';c.height=0;c.well=false;delete c.ttl;delete c.elements;delete c.reactions;delete c.ice;delete c.barrier;}return state;}
function lightCase(substrate,spellId){const s=plain(createTowerBattle({id:'audit',mapId:'arena:2:AUDIT',allies:[hero],enemies:[rival],learnedSpells:[]}));Object.assign(s.units[0],{q:-4,r:0});Object.assign(s.units[1],{q:0,r:0});s.cells.find(c=>c.q===0&&c.r===0).terrain=substrate;const n=resolveRound(s,[{orders:[{unitId:'light',spellId,cast:{q:0,r:0}}]},{orders:[]}]);return {spell:spellId,substrate,cost:castAvailability(s,'light',spellId).cost,effective:battleSpell(s,'light',spellId),target:{hp:n.units[1].hp,statuses:n.units[1].statuses},events:n.lastResolution.filter(e=>e.unitId==='rival'),field:n.cells.find(c=>c.q===0&&c.r===0).terrain};}
const light=[lightCase('plain','sunburst'),lightCase('earth','sunburst'),lightCase('plain','radiant_bolt')];
const channels=['essence_theft','inspire','siphon','signature_nico_lai','signature_juul_i_yaina'].map(id=>{const s=profileSpell(getSpell(id),'focused');return {id,shape:s.shape,radius:s.radius,bands:spellProfileBands(s)};});
const result={source:'592855cbd88c070683d0c1fdc1fa0eaf235a0514',scope:'Small actual Tower resolver fixtures on controlled flat ground; not population balance or playtest evidence',light,channels};
if (process.env.HEX_AUDIT_OUTPUT) writeFileSync(process.env.HEX_AUDIT_OUTPUT,JSON.stringify(result,null,2));
console.log(JSON.stringify({light:light.map(x=>({spell:x.spell,substrate:x.substrate,cost:x.cost,damage:x.effective.damage,cooldown:x.effective.cooldown,radius:x.effective.radius,target:x.target,field:x.field})),channels:channels.map(x=>({id:x.id,centre:x.bands?.centre,rim:x.bands?.rim}))},null,2));
