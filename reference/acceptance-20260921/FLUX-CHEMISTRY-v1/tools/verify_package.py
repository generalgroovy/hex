#!/usr/bin/env python3
"""Verify this delivered audit package. Does NOT launch or simulate FLUX.

Usage:
    python tools/verify_package.py
    python tools/verify_package.py --source-zip /path/to/FLUX-SOURCE-PACKET.zip
Python 3.9+; standard library only. Read-only; prints a JSON validation report.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path, PurePosixPath

def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)

def read_json(path: Path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def safe_relative(name: str) -> bool:
    p = PurePosixPath(name)
    return bool(name) and not p.is_absolute() and '..' not in p.parts and '\\' not in name and ':' not in name

def main() -> int:
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source-zip',type=Path)
    args=ap.parse_args()
    root=Path(__file__).resolve().parents[1]
    checks=[]
    try:
        manifest=read_json(root/'manifest.json')
        require(manifest['task_id']=='CHEMISTRY','Wrong task_id')
        require(manifest['status']=='PROPOSAL','Package must remain a proposal')
        require(manifest['human_acceptance']=='PENDING','Human acceptance must remain pending')
        listed=set()
        for item in manifest['outputs']:
            name=item['path']
            require(safe_relative(name),f'Unsafe output path: {name}')
            require(name not in listed,f'Duplicate output: {name}')
            listed.add(name)
            data=(root/name).read_bytes()
            require(len(data)==item['bytes'],f'Byte mismatch: {name}')
            require(digest(data)==item['sha256'],f'Hash mismatch: {name}')
        actual={p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.name!='.DS_Store'}
        require(actual==listed|{'manifest.json'},f'Unlisted or missing files: {actual ^ (listed|{"manifest.json"})}')
        checks.append({'name':'manifest output paths/bytes/SHA-256','status':'PASS','output_count':len(listed)})
        packet=read_json(root/'evidence/INPUT_MANIFEST.source.json')
        require(digest((root/'evidence/INPUT_MANIFEST.source.json').read_bytes())==manifest['input_manifest_sha256'],'Input manifest hash mismatch')
        exps=read_json(root/'EXPERIMENTS.json')['experiments']
        require(1<=len(exps)<=6,'Experiment count must be at most six')
        require([e['order'] for e in exps]==list(range(1,len(exps)+1)),'Experiment ordering')
        require(len({e['id'] for e in exps})==len(exps),'Duplicate experiment IDs')
        cases=read_json(root/'evidence/TEST_PLAN.json')
        case_ids={x['id'] for x in cases['deterministic_cases']}
        drill_ids={x['id'] for x in cases['human_drills']}
        for e in exps:
            require(e['status']=='NOT_RUN',f'{e["id"]}: fabricated execution status')
            require(1<=len(e['candidate_variables'])<=2,f'{e["id"]}: too many changed variables')
            require(e['changed_variable_count']==len(e['candidate_variables']),'Variable count mismatch')
            for p in e['candidate_variables']:
                require(all(k in p for k in ('baseline','candidate','units','baseline_source','proposed_live_location')),'Incomplete parameter')
                require(bool(p['units']) and bool(p['baseline_source']),'Parameter lacks units/source')
            for m in e['measured_outcomes']:
                require(m['result'] is None and m['status']=='NOT_RUN',f'{e["id"]}: invented result')
            require(e['evidence']==[],f'{e["id"]}: unexecuted experiment has evidence')
            require(set(e['deterministic_cases'])<=case_ids,'Unknown deterministic case')
            require(set(e['human_drills'])<=drill_ids,'Unknown human drill')
            require(bool(e['hypothesis']) and bool(e['acceptance_criteria']) and bool(e['rollback_criteria']) and bool(e['cost_implications']),'Incomplete experiment')
        for collection in ('deterministic_cases','human_drills'):
            for item in cases[collection]:
                require(item['status']=='NOT_RUN' and item['evidence']==[],'Invented game/human result')
        checks.append({'name':'six-or-fewer experiments; variables, costs, rollback and honest NOT_RUN results','status':'PASS','experiment_count':len(exps),'deterministic_cases':len(case_ids),'human_drills':len(drill_ids)})
        registry=read_json(root/'evidence/SOURCE_REFERENCES.json')
        source={r['alias']:r for r in registry['sources']}
        rx=re.compile(r'\b('+'|'.join(sorted(source,key=len,reverse=True))+r'):L(\d+)-L(\d+)')
        excerpts=(root/'evidence/SOURCE_EXCERPTS.txt').read_text()
        ref_count=0
        for name in listed:
            p=root/name
            if p.suffix not in ('.md','.json'):
                continue
            for key,a,b in rx.findall(p.read_text()):
                a,b=int(a),int(b)
                require(1<=a<=b<=source[key]['line_count'],f'Invalid source lines: {key}:{a}-{b}')
                require(any(lo<=a and hi>=b for lo,hi in source[key]['excerpt_line_ranges']),f'Unbundled source range: {key}:{a}-{b}')
                require(f'=== {key}: {source[key]["path"]} ===' in excerpts,f'Missing excerpt section {key}')
                ref_count+=1
        checks.append({'name':'source-reference bounds and bundled range coverage','status':'PASS','reference_occurrences':ref_count})
        if args.source_zip:
            raw=args.source_zip.read_bytes()
            require(digest(raw)==manifest['source_archive_sha256'],'Wrong source ZIP snapshot')
            with zipfile.ZipFile(args.source_zip) as z:
                require(z.testzip() is None,'Source ZIP CRC failure')
                require(len(z.namelist())==len(set(z.namelist())),'Duplicate source archive entries')
                for r in packet['records']:
                    require(safe_relative(r['path']),'Unsafe source path')
                    d=z.read(r['path'])
                    require(len(d)==r['bytes'] and digest(d)==r['sha256'],f'Source record mismatch: {r["path"]}')
                for item in registry['sources']:
                    d=z.read(item['path'])
                    require(digest(d)==item['sha256'],'Referenced source hash mismatch')
                    source_lines=d.decode('utf-8-sig').splitlines()
                    require(len(source_lines)==item['line_count'],'Referenced source line-count mismatch')
                    for lo,hi in item['excerpt_line_ranges']:
                        for n in range(lo,hi+1):
                            section = excerpts.split(f'=== {item["alias"]}: {item["path"]} ===',1)[1].split('\n=== ',1)[0]
                            require(f'L{n}: {source_lines[n-1]}' in section,f'Changed source excerpt: {item["alias"]}:{n}')
            checks.append({'name':'original source ZIP and input records; exact source excerpts','status':'PASS','record_count':len(packet['records'])})
        else:
            checks.append({'name':'original source ZIP comparison','status':'NOT_RUN','reason':'No --source-zip supplied'})
        print(json.dumps({'status':'STATIC_VERIFIED','checks':checks,'game_tests':'NOT_RUN','experiments':'NOT_RUN','human_drills':'NOT_RUN'},indent=2))
        return 0
    except (OSError,ValueError,KeyError,TypeError,zipfile.BadZipFile) as exc:
        print(json.dumps({'status':'FAILED','error':str(exc),'completed_checks':checks},indent=2),file=sys.stderr)
        return 1

if __name__=='__main__':
    raise SystemExit(main())
