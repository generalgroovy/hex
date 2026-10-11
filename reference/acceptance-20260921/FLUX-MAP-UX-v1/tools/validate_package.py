"""Check standalone artifact structure, references, source copies and safe candidate tool."""
from __future__ import annotations
import ast,hashlib,json,re,subprocess,sys,tempfile,xml.etree.ElementTree as ET
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];checks=[]
def record(name,ok,detail=None):checks.append({'name':name,'status':'PASS' if ok else 'FAIL','detail':detail})
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for p in ROOT.rglob('*.json'):
 if p.name=='manifest.json' or p.name=='package_checks.json':continue
 try:json.loads(p.read_text());ok=True
 except Exception:ok=False
 record('json:'+str(p.relative_to(ROOT)),ok)
for p in (ROOT/'tools').glob('*.py'):
 try:ast.parse(p.read_text());ok=True
 except SyntaxError:ok=False
 record('python-syntax:'+p.name,ok)
for p in (ROOT/'artifacts').glob('*.svg'):
 try:ET.parse(p);ok=True
 except Exception:ok=False
 record('svg:'+p.name,ok)
for p in (ROOT/'artifacts').glob('*.png'):
 with Image.open(p) as im:sz=im.size;im.verify()
 record('png:'+p.name,sz==(1280,720) if '1280x720' in p.name else all(n>0 for n in sz),list(sz))
for p in ROOT.glob('*.md'):
 for url in re.findall(r'\]\(([^)]+)\)',p.read_text()):
  if '://' in url or url.startswith('#'):continue
  record('link:'+p.name+':'+url,(p.parent/url.split('#')[0]).is_file())
html=(ROOT/'preview/index.html').read_text()
for url in re.findall(r'href="([^"]+)"',html):
 record('preview-link:'+url,(ROOT/'preview'/url).resolve().is_file())
record('preview-no-remote-dependency',not re.search(r'(?:src|href)=["\']https?://',html))
base=json.loads((ROOT/'evidence/source/repository/content/maps/sanctum_campus_g2_v1.json').read_text());design=json.loads((ROOT/'HEX_LAYOUT.json').read_text())
for a in design['anchors']:
 if a['coordinate_status']!='STATIC_VERIFIED':continue
 obj=base
 try:
  for key in a['source_pointer'].strip('/').split('/'):obj=obj[int(key)] if isinstance(obj,list) else obj[key]
  point=obj.get('position') if isinstance(obj,dict) else obj
  ok=point==a['world_px']
 except Exception:ok=False
 record('anchor-source-pointer:'+str(a['id']),ok)
records={r['path']:r for r in json.loads((ROOT/'evidence/source/INPUT_MANIFEST.json').read_text())['records']}
for p in (ROOT/'evidence/source').rglob('*'):
 if not p.is_file():continue
 rel=str(p.relative_to(ROOT/'evidence/source'))
 if rel in records:record('source-copy:'+rel,sha(p)==records[rel]['sha256'] and p.stat().st_size==records[rel]['bytes'])
sc=json.loads((ROOT/'data/station_copy.json').read_text());got=[s for g in sc['proposed_destinations'] for s in g['station_ids']];record('twelve-stations-accounted',len(got)==12 and set(got)=={s['id'] for s in base['stations']})
with tempfile.TemporaryDirectory() as tmp:
 tmp=Path(tmp);candidate=tmp/'candidate.json';restored=tmp/'restored.json';original=ROOT/'evidence/source/repository/content/maps/sanctum_campus_g2_v1.json';tool=ROOT/'tools/apply_pilot.py'
 def run(*args):return subprocess.run([sys.executable,str(tool),*map(str,args)],capture_output=True,text=True)
 f=run('--source',original,'--output',candidate);record('safe-tool-forward',f.returncode==0 and candidate.read_bytes()==(ROOT/'pilot/campus_candidate.json').read_bytes())
 b=run('--rollback','--source',candidate,'--output',restored);record('safe-tool-exact-byte-rollback',b.returncode==0 and restored.read_bytes()==original.read_bytes())
 record('safe-tool-refuses-overwrite',run('--source',original,'--output',candidate).returncode==2)
 record('safe-tool-refuses-in-place',run('--source',original,'--output',original).returncode==2)
 bad=tmp/'changed.json';bad.write_text('{}');record('safe-tool-refuses-changed-source',run('--source',bad,'--output',tmp/'x.json').returncode==2)
 record('safe-tool-refuses-missing-parent',run('--source',original,'--output',tmp/'missing'/'x.json').returncode==2)
report={'status':'PACKAGE_STRUCTURE_CHECKS','scope':'Local JSON/SVG/PNG, generated-document references, exact copied sources, source coordinate pointers and safe separate-file candidate creation only','count':len(checks),'passed':sum(c['status']=='PASS' for c in checks),'failed':sum(c['status']=='FAIL' for c in checks),'checks':checks}
(ROOT/'evidence/package_checks.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:report[k] for k in ['status','count','passed','failed']},indent=2))
for c in checks:
 if c['status']=='FAIL':print(c)
raise SystemExit(bool(report['failed']))
