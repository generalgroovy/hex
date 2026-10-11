from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, shutil, subprocess, zipfile
from PIL import Image

root = Path(r'C:\Users\sende\Projects\hex')
assert Path.cwd() == root
out = root / 'docs/verification/hex-native-sort-20260923'
assert not (out/'evidence-map.json').exists()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream,'sha256').hexdigest()
records=[]
def preserve(source,target):
    if source.is_dir():
        for child in sorted(source.rglob('*')):
            if child.is_file() and 'isolated-roaming' not in child.parts:
                preserve(child,target/child.relative_to(source))
        return
    assert not target.exists(), target
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,target)
    assert sha(source)==sha(target)
    records.append({'source':source.relative_to(root).as_posix(),'preserved':target.relative_to(out).as_posix(),'sha256':sha(target)})

for tier in ['focused','full']:
    receipt=read(out/f'{tier}-v1.json')
    assert receipt['result']=='passed'
    folder=(root/receipt['isolation']['appdata_path']).parent
    preserve(folder,out/'gates'/folder.name)
for pattern in ['hex-probe-native-sort-*','hex-native-sort-candidate-integrated-v1.json',
                'hex-snapshot-stages-native-sort-v1.json','unified-wellspring-render-profile-native-sort-v1.json',
                'gallery-native-sort-*','character-native-sort-*','movement-cast-native-sort-*',
                'movement-advanced-native-sort-*','water-native-sort-*','terrain-native-sort-*']:
    for path in sorted((root/'.godot').glob(pattern)):
        if path.name=='hex-probe-native-sort-candidate-v1': continue
        preserve(path,out/'final-runs'/path.name)
for path in sorted((root/'docs/verification/hex-acceptance-20260921').glob('native-sort-*')):
    preserve(path,out/'loom'/path.name)
for pattern in ['*native_sort*.py','*native_sort*.ps1','*native_integration*.py']:
    for path in sorted((root/'.godot').glob(pattern)):
        preserve(path,out/'tools'/path.name)
preserve(root/'.godot/gallery_pose_control.gd',out/'tools/gallery_pose_control.gd')

package=root/'exports/hex-native-sort-20260923'
meta=read(package/'receipt.json')
preserve(package/'receipt.json',out/'package/receipt.json')
preserve(package/'logs',out/'package/logs')
for name in ['BUILD-STATE.json','SOURCE-IDENTITY.json','SHA256SUMS.txt','README-FIRST.txt','PLAY-HEX.cmd']:
    preserve(package/'windows'/name,out/'package'/name)
assert sha(package/'windows/hex.pck')==meta['pack_sha256']
assert sha(Path(meta['zip']))==meta['zip_sha256']
entries=[]
with zipfile.ZipFile(meta['zip']) as archive:
    assert archive.testzip() is None
    for entry in archive.infolist():
        if entry.is_dir(): continue
        name=Path(entry.filename).name
        digest=hashlib.sha256(archive.read(entry)).hexdigest()
        assert digest==sha(package/'windows'/name)
        entries.append({'name':name,'sha256':digest})
assert len(entries)==7==len(list((package/'windows').glob('*')))
(out/'package-audit.json').write_text(json.dumps({'status':'passed','build_id':meta['build_id'],
    'pck_sha256':meta['pack_sha256'],'zip_sha256':meta['zip_sha256'],'entries':entries},indent=2)+'\n',encoding='utf-8')

freeze=read(out/'integration-freeze-v1/freeze.json')
protected_by_path={item['path']:item for item in read(out/'integration-baseline.json')['protected']}
for item in read(out/'freeze-v1/freeze.json')['files']+freeze['files']:
    protected_by_path[item['path']]=item
protected=list(protected_by_path.values())
for item in protected: assert sha(root/item['path'])==item['sha256'],item['path']
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip()
assert read(root/'content/runtime/runtime_build_identity_v1.json')==freeze['identity']
(out/'preservation-audit.json').write_text(json.dumps({'utc':datetime.now(timezone.utc).isoformat(),
    'status':'passed','protected_files':protected,'staged_changes':False,'checkpoint_promoted':False},indent=2)+'\n',encoding='utf-8')

old_root=root/'docs/verification/hex-gallery-availability-20260923'
old_audit=read(old_root/'pose-control-audit.json')
old_images={row['image']:row['pck_sha256'] for row in old_audit['pixels']}
current=root/'.godot/gallery-native-sort-pck-v1'
gallery=read(current/'receipt.json')
assert gallery['passed'] and not gallery['failures'] and len(gallery['frames'])==9
pixel_rows=[]
for row in gallery['frames']:
    name=row['image']
    matches=[p for p in (old_root/'pose-control').rglob(name) if sha(p)==old_images[name]]
    assert matches,name
    old=matches[0]
    new=current/name
    a=Image.open(old).convert('RGBA'); b=Image.open(new).convert('RGBA')
    pixel_rows.append({'image':name,'equal_rgba':a.size==b.size and a.tobytes()==b.tobytes(),
        'e2_preserved':old.relative_to(root).as_posix(),'e2_sha256':sha(old),'d9_sha256':sha(new)})
(out/'gallery-pixel-audit.json').write_text(json.dumps({'scope':'Exact D9 PCK versus preserved E2 controlled south-facing Gallery frames; arranged pose, not free motion acceptance.','pixels':pixel_rows},indent=2)+'\n',encoding='utf-8')
for item in records: assert sha(out/item['preserved'])==item['sha256']
(out/'evidence-map.json').write_text(json.dumps({'scope':'D9 integrated source/Full/rendered stress/exact Windows journeys. Historical prototype evidence stays under runs/v1. Isolated profiles remain at original paths.','files':records},indent=2)+'\n',encoding='utf-8')
print(f'PASS: {len(records)} artifacts; {len(protected)} protected/frozen hashes; {len(entries)} ZIP entries')
print(f'Gallery exact RGBA pairs: {sum(item["equal_rgba"] for item in pixel_rows)}/{len(pixel_rows)}')
