import {readFile, mkdir, copyFile, writeFile} from 'node:fs/promises';
import {resolve, join, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';

// Copies canonical art without cropping, resampling, recolouring, or rewriting PNGs.
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const hexRoot = resolve(process.argv[2] || 'C:/Users/sende/Projects/hex');
const sourceDirectory = join(hexRoot, 'assets/sprites/pixel_cast_v1');
const manifestBytes = await readFile(join(sourceDirectory, 'manifest.json'));
const original = JSON.parse(manifestBytes.toString('utf8'));
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
if (original.cell.join(',') !== '128,128' || original.pivot.join(',') !== '64,104' || original.rows.length !== 4 || original.directions.length !== 8) throw new Error('Unexpected original sprite contract.');
const rosterText = await readFile(join(root, 'lib/roster.ts'), 'utf8');
const rosterIds = [...rosterText.matchAll(/"id":\s*"([a-z0-9_]+)"/g)].map(match => match[1]);
if (rosterIds.length !== 30 || new Set(rosterIds).size !== 30) throw new Error('Expected thirty unique canonical roster identities.');
const destination = join(root, 'public/pixel/champions');
await mkdir(destination, {recursive:true});
const characters = [];
for (const id of rosterIds) {
  const entry = original.characters.find(character => character.id === id);
  if (!entry || entry.atlas !== `${id}.png`) throw new Error(`Missing safe canonical sprite: ${id}`);
  const source = join(sourceDirectory, entry.atlas);
  const bytes = await readFile(source);
  if (bytes.readUInt32BE(16) !== 1024 || bytes.readUInt32BE(20) !== 512) throw new Error(`Unexpected atlas dimensions: ${id}`);
  await copyFile(source, join(destination, entry.atlas));
  const copied = await readFile(join(destination, entry.atlas));
  if (!bytes.equals(copied)) throw new Error(`Sprite copy changed original pixels: ${id}`);
  characters.push({id, body:entry.body, displayHeight:entry.display_height, sprite:`/pixel/champions/${entry.atlas}`, source:`assets/sprites/pixel_cast_v1/${entry.atlas}`, bytes:bytes.length, sha256:sha256(bytes), sourceRgbaSha256:entry.rgba_sha256});
}
const manifest = {version:1, source:'H.E.X. original repository; pixel_cast_v1', sourceManifest:'assets/sprites/pixel_cast_v1/manifest.json', sourceManifestSha256:sha256(manifestBytes), transformation:'None. Original PNG bytes copied intact; browser clips atlas frames.', cell:original.cell, pivot:original.pivot, directions:original.directions, rows:original.rows, characters};
await writeFile(join(root, 'public/pixel/manifest.json'), JSON.stringify(manifest,null,2)+'\n');
console.log(JSON.stringify({characters:characters.length, bytes:characters.reduce((total,entry)=>total+entry.bytes,0), byteIdentityVerified:true, cell:original.cell, pivot:original.pivot}));
