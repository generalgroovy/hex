import {access} from 'node:fs/promises';
import {resolve,relative,sep} from 'node:path';
import {pathToFileURL} from 'node:url';

const dist=resolve(process.argv[2]??'dist'),client=resolve(dist,'client');
let checked=0;
for(const directory of ['server','server/ssr']){
 const source=resolve(dist,directory,'__vite_rsc_assets_manifest.js');
 const {default:manifest}=await import(pathToFileURL(source).href);
 const references=new Set(Object.values({...manifest.clientReferenceDeps,...manifest.serverResources}).flatMap(deps=>[...deps.js,...deps.css]));
 const bootstrap=manifest.bootstrapScriptContent.match(/^import\(("[^"]+")\)$/);if(!bootstrap)throw new Error('Unexpected RSC bootstrap format. Review asset verification.');references.add(JSON.parse(bootstrap[1]));
 for(const asset of references){
  if(typeof asset!=='string'||!asset.startsWith('/')||asset.startsWith('//')||asset.includes('?')||asset.includes('#'))throw new Error(`Unexpected local RSC asset reference in ${directory}.`);
  const target=resolve(client,asset.slice(1)),within=relative(client,target);if(within==='..'||within.startsWith(`..${sep}`))throw new Error('RSC asset reference leaves client output.');
  try{await access(target)}catch{throw new Error(`Missing emitted RSC asset (${directory}): ${asset}`);}checked++;
 }
}
console.log(`RSC asset integrity passed: ${checked} references across server and SSR manifests.`);
