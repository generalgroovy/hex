from pathlib import Path
import hashlib, json, shutil, subprocess, zipfile, math
from PIL import Image

root = Path(r'C:\Users\sende\Projects\hex')
out = root / 'docs/verification/hex-loom-availability-20260923'
assert Path.cwd().resolve() == root.resolve()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):
    with path.open('rb') as f: return hashlib.file_digest(f,'sha256').hexdigest()
assert not (out/'evidence-map.json').exists(), 'Do not overwrite sealed evidence'
records = []
def preserve(source, target):
    if source.is_dir():
        for child in sorted(source.rglob('*')):
            if child.is_file() and 'isolated-roaming' not in child.parts:
                preserve(child,target/child.relative_to(source))
        return
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,target)
    assert sha(source) == sha(target)
    records.append({'source':source.relative_to(root).as_posix(), 'preserved':target.relative_to(out).as_posix(), 'sha256':sha(target)})

for path in sorted(out.glob('*.json')):
    data = read(path)
    if isinstance(data,dict) and data.get('tier') and data.get('isolation',{}).get('appdata_path'):
        path_root = (root/data['isolation']['appdata_path']).parent
        preserve(path_root,out/'gates'/path_root.name)
for pattern in ['hex-probe-loom-availability-*','loom-availability-*',
                'movement-cast-loom-availability-*','movement-advanced-loom-availability-*',
                'water-loom-availability-*','terrain-loom-availability-*']:
    for path in sorted((root/'.godot').glob(pattern)):
        preserve(path,out/'final-runs'/path.name)
for path in sorted((root/'docs/verification/hex-acceptance-20260921').glob('loom-availability-*')):
    preserve(path,out/'loom'/path.name)
for pattern in ['*loom_availability*.py','*loom_availability*.ps1']:
    for path in sorted((root/'.godot').glob(pattern)):
        preserve(path,out/'tools'/path.name)

package = root/'exports/hex-loom-availability-20260923-v2'
failed_package = root/'exports/hex-loom-availability-20260923'
preserve(failed_package/'logs',out/'failed-package-v1/logs')
preserve(failed_package/'FAILED-VALIDATION.txt',out/'failed-package-v1/FAILED-VALIDATION.txt')
failed_files = [{'path':p.relative_to(root).as_posix(),'sha256':sha(p)} for p in sorted((failed_package/'windows').glob('*')) if p.is_file()]
(out/'failed-package-v1/receipt.json').write_text(json.dumps({'result':'failed','stage':'exact EXE native launch',
    'source_build_id':'p55-c5d0f6accb97','watchdog_seconds':120,
    'cause':'Export class cache referenced three evidence copies under excluded docs paths; parse errors prevented Bootstrap initialization.',
    'files':failed_files,'class_cache':'class-cache-failed-v1.cfg','repair':'Evidence .gdignore plus canonical class-path guard immediately after export; production code unchanged.'},indent=2)+'\n')
meta = read(package/'receipt.json')
preserve(package/'receipt.json',out/'package/receipt.json')
preserve(package/'logs',out/'package/logs')
for name in ['BUILD-STATE.json','SOURCE-IDENTITY.json','SHA256SUMS.txt','README-FIRST.txt','PLAY-HEX.cmd']:
    preserve(package/'windows'/name,out/'package'/name)
assert sha(package/'windows/hex.pck') == meta['pack_sha256']
assert sha(Path(meta['zip'])) == meta['zip_sha256']
entries = []
with zipfile.ZipFile(meta['zip']) as archive:
    assert archive.testzip() is None
    for entry in archive.infolist():
        if entry.is_dir(): continue
        name = Path(entry.filename).name
        digest = hashlib.sha256(archive.read(entry)).hexdigest()
        assert digest == sha(package/'windows'/name)
        entries.append({'name':name,'sha256':digest})
assert len(entries) == len(list((package/'windows').glob('*')))
(out/'package-audit.json').write_text(json.dumps({'status':'passed','build_id':meta['build_id'],
    'pck_sha256':meta['pack_sha256'],'zip_sha256':meta['zip_sha256'],'entries':entries},indent=2)+'\n')

freeze = read(out/'final-freeze-v2/freeze.json')
protected = read(out/'baseline.json')['protected'] + freeze['files']
protected += [item for item in read(out/'baseline.json')['baseline_sources'] if item['path'] == 'tests/run_all.gd']
protected += [{'path':item['source'],'sha256':item['sha256']} for item in read(root/'docs/verification/hex-viewport-20260923/attempts/v3/freeze.json')['files'] if item['source'].startswith('tests/')]
for item in protected: assert sha(root/item['path']) == item['sha256'],item['path']
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip()
assert read(root/'content/runtime/runtime_build_identity_v1.json') == freeze['identity']
(out/'preservation-audit.json').write_text(json.dumps({'status':'passed','protected_files':protected,
    'staged_changes':False,'checkpoint_promoted':False},indent=2)+'\n')
fallback = root/'exports/hex-render-frame-20260923'
fallback_meta = read(fallback/'receipt.json')
with zipfile.ZipFile(fallback_meta['zip']) as archive:
    assert archive.testzip() is None
    for entry in archive.infolist():
        if not entry.is_dir():
            assert hashlib.sha256(archive.read(entry)).hexdigest() == sha(fallback/'windows'/Path(entry.filename).name)

rows = []
for run in ['loom-availability-after-v2','loom-availability-pck-v1']:
    receipt = read(root/'.godot'/run/'receipt.json')
    assert receipt['passed'] and not receipt['failures']
    for row in receipt['frames']:
        values = sorted(row['modal_query_us'])
        assert len(values) == 128
        percentile = lambda p: values[math.ceil(len(values)*p/100)-1]
        rows.append({'run':run,'case':row['label'],'samples':len(values),'p50_us':percentile(50),
                     'p95_us':percentile(95),'p99_us':percentile(99)})
pixel_rows = []
for row in read(root/'.godot/loom-availability-pck-v1/receipt.json')['frames']:
    before = root/'.godot/loom-availability-after-v2'/row['image']
    after = root/'.godot/loom-availability-pck-v1'/row['image']
    a = Image.open(before).convert('RGBA')
    b = Image.open(after).convert('RGBA')
    pixel_rows.append({'image':row['image'],'same_dimensions':a.size==b.size,
                       'equal_rgba':a.tobytes()==b.tobytes(),'source_sha256':sha(before),'pck_sha256':sha(after)})
(out/'modal-cost-and-pixels.json').write_text(json.dumps({'scope':'Read-only modal availability query only; not frame, simulation or network performance.',
    'timings':rows,'source_pck_pixels':pixel_rows},indent=2)+'\n')
for item in records: assert sha(out/item['preserved']) == item['sha256']
(out/'evidence-map.json').write_text(json.dumps({'scope':'E1 source/PCK UI captures, exact Windows journeys, Full and logs. Isolated profiles retained at original locations; personal profiles never copied.', 'files':records},indent=2)+'\n')
print('PASS:',len(records),'preserved files;',len(protected),'frozen/protected hashes;',len(entries),'ZIP entries')
print('Source/PCK RGBA pairs equal:',sum(x['equal_rgba'] for x in pixel_rows),'/',len(pixel_rows))
print(json.dumps(rows,indent=2))
