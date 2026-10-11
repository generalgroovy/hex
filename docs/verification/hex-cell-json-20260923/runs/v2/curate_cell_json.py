from pathlib import Path
from datetime import datetime, timezone
import hashlib,json,math,re,shutil,sys
root=Path(r'C:\Users\sende\Projects\hex')
assert Path.cwd()==root
out=root/'docs/verification/hex-cell-json-20260923'
version=sys.argv[1]
assert version in ['v1','v2','v3']
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream,'sha256').hexdigest()
baseline=read(out/'baseline.json'); freeze=read(out/f'freeze-{version}/freeze.json')
for item in baseline['protected']+freeze['files']:
    assert sha(root/item['path'])==item['sha256'],item['path']
run=out/'runs'/version
assert not run.exists()
run.mkdir(parents=True)
files=[]
for source in [root/f'.godot/hex-cell-json-candidate-{version}.json',
               root/f'.godot/hex-probe-cell-json-candidate-{version}/probe.log',
               root/f'.godot/hex-probe-cell-json-candidate-{version}/probe.log.err',
               out/f'probe-{version}.out',root/'.godot/run_cell_json.ps1',root/'.godot/curate_cell_json.py']:
    if not source.exists(): continue
    target=run/source.name
    shutil.copy2(source,target)
    files.append({'source':source.relative_to(root).as_posix(),'preserved':target.relative_to(out).as_posix(),'sha256':sha(target)})
audit={'utc':datetime.now(timezone.utc).isoformat(),'status':'failed-or-incomplete','files':files,
       'protected_hashes':len(baseline['protected']),'frozen_files':len(freeze['files']),
       'scope':'Test-only complete hash comparison; unchanged D9 runtime. No frame or capacity claim.'}
receipt_path=run/f'hex-cell-json-candidate-{version}.json'
if receipt_path.exists():
    receipt=read(receipt_path)
    if receipt.get('failures',-1)==0 and receipt.get('profile_cases_completed')==3:
        script=(root/'tests/performance/profile_hex_cell_json_candidate.gd').read_text(encoding='utf-8')
        extra=int(re.search(r'CELL_JSON_EXTRA_EQUIVALENCE_CASES\s*:=\s*(\d+)',script).group(1))
        assert receipt['equivalence_cases_completed']==42+extra
        assert receipt['ownership_cases_completed']==1
        assert len(receipt['source_sha256'])==15
        for name,expected in receipt['source_sha256'].items(): assert sha(root/name)==expected,name
        assert receipt['runtime_identity']==baseline['runtime_identity']
        assert not (run/'probe.log.err').read_bytes()
        def stats(samples):
            ordered=sorted(samples)
            assert min(ordered)>0
            return {'samples':len(ordered),'min':ordered[0],'max':ordered[-1],
                    **{f'p{p}':ordered[math.ceil(len(ordered)*p/100)-1] for p in [50,95,99]},
                    'over_8333_us':sum(x>8333 for x in ordered),'over_16667_us':sum(x>16667 for x in ordered)}
        rows=[]
        for case in receipt['cases']:
            flat={name:[] for name in ['production_current','candidate_cell_json']}
            assert len(case['blocks'])==16
            for i,block in enumerate(case['blocks']):
                order=['production_current','candidate_cell_json','candidate_cell_json','production_current'] if (i//4)%2==0 else ['candidate_cell_json','production_current','production_current','candidate_cell_json']
                assert (block['cycle'],block['block'],block['implementation'])==(i//4,i%4,order[i%4])
                assert len(block['samples_us'])==7 and stats(block['samples_us'])==block['statistics_us']
                flat[block['implementation']].extend(block['samples_us'])
            for name,samples in flat.items():
                assert len(samples)==56 and samples==case['implementations'][name]['samples_us']
                assert stats(samples)==case['implementations'][name]['statistics_us']
            row={'case':case['case'],'production_us':stats(flat['production_current']),
                 'candidate_us':stats(flat['candidate_cell_json'])}
            rows.append(row); print(json.dumps(row))
        assert [row['case'] for row in rows]==['production-empty','legal-paid-29-active','synthetic-all-nonempty']
        audit.update(status='passed',assertions=receipt['assertions'],equivalence_cases=42+extra,
                     measured_source_hashes=15,ordered_blocks=48,raw_samples=336,rows=rows)
(run/'audit.json').write_text(json.dumps(audit,indent=2)+'\n',encoding='utf-8')
print(f'D10 {version}: {audit["status"]}; {len(files)} artifacts; {len(baseline["protected"])} protected hashes')
