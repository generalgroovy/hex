import {readFile,readdir,access} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root=fileURLToPath(new URL('../',import.meta.url));
const handbook=path.join(root,'docs/handbook');
const files=[path.join(root,'README.md'),...(await readdir(handbook)).filter(name=>name.endsWith('.md')).map(name=>path.join(handbook,name))];
let links=0;const missing=[];
for(const file of files){
 const source=await readFile(file,'utf8');
 for(const match of source.matchAll(/!?\[[^\]]*\]\((<[^>]+>|[^)\s]+)(?:\s+"[^"]*")?\)/g)){
  const href=match[1].replace(/^<|>$/g,'');
  if(/^(?:[a-z][a-z\d+.-]*:|#|\/\/)/i.test(href))continue;
  const target=decodeURIComponent(href.split('#')[0].split('?')[0]);
  if(!target)continue;
  links++;
  try{await access(path.resolve(path.dirname(file),target))}
  catch{missing.push(`${path.relative(root,file)} -> ${target}`)}
 }
}
if(missing.length){console.error(missing.join('\n'));process.exitCode=1}
else console.log(`Handbook links passed: ${links} local targets in ${files.length} documents.`);
