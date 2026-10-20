import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,writeFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join,dirname,basename,resolve} from 'node:path';
import {build} from 'vite';
import {rscCssManifestOrder} from '../build/rsc-css-manifest-plugin.mjs';

test('RSC dependency collection runs after real Vite CSS-only chunk removal and keeps its stylesheet',async()=>{
 const root=await mkdtemp(join(tmpdir(),'hex-rsc-css-'));
 try{
  await writeFile(join(root,'entry.js'),"import './terrain.css'; export const terrain='grass';\n");
  await writeFile(join(root,'terrain.css'),'.terrain{color:green}\n');
  async function fixture(correctOrder){let collected;
   const result=await build({root,configFile:false,logLevel:'silent',plugins:[{name:'rsc:virtual:vite-rsc/assets-manifest',generateBundle(_options,bundle){collected={js:Object.values(bundle).filter(file=>file.type==='chunk').map(file=>file.fileName),css:[...new Set(Object.values(bundle).filter(file=>file.type==='chunk').flatMap(file=>[...file.viteMetadata.importedCss]))]};}},...(correctOrder?[rscCssManifestOrder()]:[])],build:{write:false,minify:false,rolldownOptions:{input:join(root,'entry.js'),output:{manualChunks(id){if(id.endsWith('.css'))return 'terrain-style';}}}}});
   const files=new Set(result.output.map(file=>file.fileName));return {collected,missing:collected.js.filter(file=>!files.has(file)),files};
  }
  const before=await fixture(false);assert.ok(before.missing.some(file=>file.includes('terrain-style')),'Fixture must reproduce CSS-only JS placeholder removal');
  const after=await fixture(true);assert.deepEqual(after.missing,[]);assert.ok(after.collected.css.length>0,'CSS remains attached to its importer');for(const file of after.collected.css)assert.ok(after.files.has(file),'The retained stylesheet is emitted');
 }finally{assert.equal(dirname(resolve(root)),resolve(tmpdir()));assert.ok(basename(root).startsWith('hex-rsc-css-'));await rm(root,{recursive:true,force:true});}
});

test('a changed framework hook fails clearly instead of silently masking missing assets',()=>{
 assert.throws(()=>rscCssManifestOrder().configResolved({plugins:[]}),/Review the pinned Vite\/RSC versions/);
});
