"""Read-only archive audit and guarded extraction; executes no supplied code."""
from pathlib import Path, PurePosixPath
from collections import Counter, defaultdict
from datetime import datetime, timezone
import hashlib, io, json, stat, subprocess, zipfile
from PIL import Image

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
STAGE = ROOT / 'reference/acceptance-20260921'
PACKS = Path(r'C:\Users\sende\Documents\HEX Handoff')
NAMES = ['FLUX-ANIMATION-v1', 'FLUX-CHEMISTRY-v1', 'FLUX-MAP-UX-v1', 'FLUX-VFX-v1']
def sha(data): return hashlib.sha256(data).hexdigest()
def write_json(path, data): path.write_text(json.dumps(data, indent=2)+'\n', encoding='utf-8')
STAGE.mkdir(parents=True, exist_ok=True)
(STAGE / '.gdignore').write_text('# Audit staging only; never runtime acceptance.\n', encoding='utf-8')
current = defaultdict(list)
for folder in ['assets', 'art_batches']:
    for p in (ROOT / folder).rglob('*.png'):
        current[sha(p.read_bytes())].append(p.relative_to(ROOT).as_posix())
packs=[]
for name in NAMES:
    archive=PACKS/(name+'.zip')
    with zipfile.ZipFile(archive) as z:
        entries=z.infolist(); seen=set(); inventory=[]
        for entry in entries:
            p=PurePosixPath(entry.filename)
            assert not p.is_absolute() and '..' not in p.parts and ':' not in entry.filename and '\\' not in entry.filename, entry.filename
            assert p.parts[0]==name and entry.filename.casefold() not in seen, entry.filename
            assert not stat.S_ISLNK(entry.external_attr >> 16), entry.filename
            seen.add(entry.filename.casefold())
            dest=STAGE.joinpath(*p.parts).resolve()
            assert STAGE.resolve() in dest.parents, dest
            if entry.is_dir(): continue
            data=z.read(entry)
            if dest.exists(): assert dest.read_bytes()==data, 'Refusing overwrite: '+str(dest)
            else:
                dest.parent.mkdir(parents=True,exist_ok=True); dest.write_bytes(data)
            item={'path': str(p.relative_to(name)), 'bytes':len(data),'sha256':sha(data)}
            if p.suffix.lower() in ['.png','.gif','.apng']:
                with Image.open(io.BytesIO(data)) as img:
                    rgba=img.convert('RGBA'); alpha=rgba.getchannel('A'); histogram=alpha.histogram()
                    item['image']={'dimensions':list(img.size),'mode':img.mode,'frames':getattr(img,'n_frames',1),'alpha_min_max':list(alpha.getextrema()),'transparent_pixels':histogram[0],'partial_alpha_pixels':sum(histogram[1:255]),'opaque_pixels':histogram[255],'rgba_sha256':sha(rgba.tobytes())}
                item['existing_duplicates']=current.get(item['sha256'],[])
            inventory.append(item)
        manifest=json.loads(z.read(name+'/manifest.json'))
        index={i['path']:i for i in inventory}
        failures=[]
        for item in manifest['outputs']:
            actual=index.get(item['path'])
            if actual is None or actual['sha256']!=item['sha256'] or actual['bytes']!=item['bytes']: failures.append(item['path'])
        packs.append({'name':name,'archive_sha256':sha(archive.read_bytes()),'archive_bytes':archive.stat().st_size,'files':len(inventory),'manifest_outputs':len(manifest['outputs']),'manifest_failures':failures,'safe_paths_and_no_symlinks':True,'license_named_files':[i['path'] for i in inventory if 'license' in i['path'].lower()],'input_packet_id':manifest.get('input_packet_id'),'input_manifest_sha256':manifest.get('input_manifest_sha256'),'images':sum('image' in i for i in inventory),'image_duplicate_files':sum(bool(i.get('existing_duplicates')) for i in inventory),'inventory':inventory})
inputs=json.loads((STAGE/'FLUX-VFX-v1/evidence/input-manifest.json').read_text(encoding='utf-8'))
comparison=[]
for entry in inputs['records']:
    if not entry['path'].startswith('repository/'): continue
    rel=entry['path'][len('repository/'):]; live=ROOT/rel
    actual=sha(live.read_bytes()) if live.exists() else None
    comparison.append({'path':rel,'input_sha256':entry['sha256'],'live_sha256':actual,'status':'match' if actual==entry['sha256'] else 'missing' if actual is None else 'changed'})
report={'status':'STATIC_AUDIT_ONLY_NO_RUNTIME_ACCEPTANCE','utc':datetime.now(timezone.utc).isoformat(),'repository':str(ROOT),'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'staging':str(STAGE),'supplied_scripts_executed':False,'godot_executed':False,'current_unique_png_hashes':len(current),'current_png_files':sum(map(len,current.values())),'inputs_summary':dict(Counter(i['status'] for i in comparison)),'input_comparison':comparison,'packs':packs}
write_json(OUT/'inventory.json',report)
print(json.dumps({k:v for k,v in report.items() if k not in ['input_comparison','packs']},indent=2))
for p in packs: print(json.dumps({k:v for k,v in p.items() if k!='inventory'}))
