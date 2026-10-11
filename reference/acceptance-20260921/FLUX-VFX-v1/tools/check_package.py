#!/usr/bin/env python3
"""Check exact manifest inventory and dependencies. Standard library only.
This does not validate Godot integration or human readability.
"""
from __future__ import annotations
import hashlib,json,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def main():
 manifest=json.loads((ROOT/'manifest.json').read_text());errors=[];expected=set()
 for row in manifest['outputs']:
  rel=row['path'];p=(ROOT/rel).resolve();expected.add(rel)
  if not p.is_relative_to(ROOT.resolve()) or not p.is_file():errors.append('Missing/unsafe file: '+rel);continue
  if hashlib.sha256(p.read_bytes()).hexdigest()!=row['sha256']:errors.append('SHA-256 mismatch: '+rel)
  if p.stat().st_size!=row['bytes']:errors.append('Byte-count mismatch: '+rel)
 actual={p.relative_to(ROOT).as_posix() for p in ROOT.rglob('*') if p.is_file() and p.name!='manifest.json' and '__pycache__' not in p.parts}
 if expected!=actual:errors.append('Inventory mismatch: '+str(sorted(expected^actual)))
 required=['HANDOFF.md','manifest.json','definitions/materials.proposed.json','definitions/palette.json','definitions/atlas-layout.json','preview-standalone.html','index.html','evidence/verification.json','integration/INTEGRATION.md','integration/CAPTURE-CHECKLIST.md']
 for rel in required:
  if not (ROOT/rel).is_file():errors.append('Required output missing: '+rel)
 for rel in re.findall(r'(?:src|href)="([^"]+)"',(ROOT/'index.html').read_text()):
  if rel.startswith(('data:','#','http:','https:')):continue
  if not (ROOT/rel).is_file():errors.append('HTML dependency/link missing: '+rel)
 for item in json.loads((ROOT/'definitions/atlas-layout.json').read_text())['atlases']:
  if not (ROOT/item['path']).is_file():errors.append('Atlas missing: '+item['path'])
 for p in ROOT.rglob('*'):
  if p.suffix.lower() in ['.ttf','.otf','.woff','.woff2']:errors.append('Unexpected font file: '+str(p))
 result={'status':'PASS' if not errors else 'FAIL','payload_files':len(expected),'errors':errors,'scope':'Exact local package inventory, hashes and links; NOT Godot/human acceptance'}
 print(json.dumps(result,indent=2));return 0 if not errors else 1
if __name__=='__main__':sys.exit(main())
