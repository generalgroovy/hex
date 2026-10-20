import {readFileSync,writeFileSync} from 'node:fs';
import {CHAMPIONS} from '../../../lib/roster-v13.ts';
const source=JSON.parse(readFileSync(process.env.HEX_CANONICAL_CAST ?? 'C:/Users/sende/Projects/hex/content/champions/foundation_champions_v1.json','utf8')).champions;
const normal=(x)=>Object.keys(x).map(k=>k==='wind'?'air':k).sort().join(',');
const discrepancies=CHAMPIONS.flatMap(c=>{const o=source.find(x=>x.id===c.id);if(!o)return [{id:c.id,missing:true}];const differences=[];if(c.name!==o.display_name)differences.push('name');if(c.race!==o.ancestry)differences.push('ancestry');if(c.body!==o.body_type)differences.push('body');if(normal(c.affinities)!==normal(o.affinity_points))differences.push('element-membership');return differences.length?[{id:c.id,differences}]:[];});
const report={original:source.length,hosted:CHAMPIONS.length,originalAncestries:new Set(source.map(x=>x.ancestry)).size,hostedAncestries:new Set(CHAMPIONS.map(x=>x.race)).size,discrepancies,rankAdaptation:CHAMPIONS.map(c=>({id:c.id,original:source.find(x=>x.id===c.id).affinity_points,hosted:c.affinities,primary:c.element}))};
if (process.env.HEX_AUDIT_OUTPUT) writeFileSync(process.env.HEX_AUDIT_OUTPUT,JSON.stringify(report,null,2));console.log(JSON.stringify({...report,rankAdaptation:report.rankAdaptation.slice(0,4)},null,2));
