"""Verify every inventoried file and require a complete safe-path inventory. Read-only."""
import hashlib,json,sys
from pathlib import Path,PurePosixPath
ROOT=Path(__file__).resolve().parents[1]
m=json.loads((ROOT/'manifest.json').read_text());seen=set();errors=[]
for item in m['outputs']:
 p=item['path'];rel=PurePosixPath(p)
 if rel.is_absolute() or '..' in rel.parts or p in seen or '\\' in p:errors.append('Unsafe or duplicate path: '+p);continue
 seen.add(p);f=ROOT/p
 if not f.is_file():errors.append('Missing: '+p);continue
 if f.stat().st_size!=item['bytes'] or hashlib.sha256(f.read_bytes()).hexdigest()!=item['sha256']:errors.append('Changed: '+p)
actual={p.relative_to(ROOT).as_posix() for p in ROOT.rglob('*') if p.is_file() and p!=ROOT/'manifest.json' and '__pycache__' not in p.parts}
if actual!=seen:errors.append('Inventory mismatch: '+str(sorted(actual^seen)))
print(json.dumps({'status':'PASS' if not errors else 'FAIL','outputs_checked':len(seen),'errors':errors},indent=2))
raise SystemExit(bool(errors))
