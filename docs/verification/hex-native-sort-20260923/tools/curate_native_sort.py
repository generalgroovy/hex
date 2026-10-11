from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, shutil, sys

root = Path(r'C:\Users\sende\Projects\hex')
assert Path.cwd() == root
out = root / 'docs/verification/hex-native-sort-20260923'
version = sys.argv[1]
assert version in ['v1', 'v2', 'v3']
def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()
def read(path):
    return json.loads(path.read_text(encoding='utf-8'))
baseline = read(out / 'baseline.json')
freeze = read(out / f'freeze-{version}/freeze.json')
for item in baseline['protected']:
    assert sha(root / item['path']) == item['sha256'], item['path']
for item in freeze['files']:
    assert sha(root / item['path']) == sha(out / item['preserved']) == item['sha256'], item['path']
run = out / 'runs' / version
assert not run.exists()
run.mkdir(parents=True)
records = []
paths = [root / f'.godot/hex-native-sort-candidate-{version}.json',
         root / f'.godot/hex-probe-native-sort-candidate-{version}/probe.log',
         root / f'.godot/hex-probe-native-sort-candidate-{version}/probe.log.err',
         out / f'probe-{version}.out', root / '.godot/run_native_sort.ps1',
         root / '.godot/curate_native_sort.py']
for source in paths:
    if not source.exists():
        continue
    target = run / source.name
    shutil.copy2(source, target)
    records.append({'source': source.relative_to(root).as_posix(),
                    'preserved': target.relative_to(out).as_posix(), 'sha256': sha(target)})
receipt_path = run / f'hex-native-sort-candidate-{version}.json'
audit = {'utc': datetime.now(timezone.utc).isoformat(), 'protected_hashes': len(baseline['protected']),
         'frozen_files': len(freeze['files']), 'files': records, 'status': 'failed-or-incomplete',
         'scope': 'Exact files and raw whole-hash timing audit; no capacity, frame or network claim.'}
if receipt_path.exists():
    receipt = read(receipt_path)
    if receipt.get('failures', -1) == 0 and receipt.get('profile_cases_completed') == 3:
        assert receipt['equivalence_cases_completed'] == 42
        assert receipt['ownership_cases_completed'] == 1
        assert len(receipt['source_sha256']) == 13
        for name, expected in receipt['source_sha256'].items():
            assert sha(root / name) == expected, name
        assert receipt['runtime_identity'] == baseline['runtime_identity']
        assert not (run / 'probe.log.err').read_bytes()
        def stats(samples):
            ordered = sorted(samples)
            assert len(ordered) == 56 and min(ordered) > 0
            return {'samples': 56, 'min': ordered[0], 'max': ordered[-1],
                    **{f'p{p}': ordered[(56*p+99)//100-1] for p in [50, 95, 99]},
                    'over_8333_us': sum(x > 8333 for x in ordered),
                    'over_16667_us': sum(x > 16667 for x in ordered)}
        rows = []
        for case in receipt['cases']:
            flat = {name: [] for name in ['production_current', 'candidate_native_sort']}
            assert len(case['blocks']) == 16
            for i, block in enumerate(case['blocks']):
                order = ['production_current', 'candidate_native_sort', 'candidate_native_sort', 'production_current']
                if (i//4) % 2:
                    order = ['candidate_native_sort', 'production_current', 'production_current', 'candidate_native_sort']
                assert (block['cycle'], block['block'], block['implementation']) == (i//4, i%4, order[i%4])
                assert len(block['samples_us']) == 7
                flat[block['implementation']].extend(block['samples_us'])
            for name, samples in flat.items():
                assert samples == case['implementations'][name]['samples_us']
                assert stats(samples) == case['implementations'][name]['statistics_us']
            row = {'case': case['case'], 'production_us': stats(flat['production_current']),
                   'candidate_us': stats(flat['candidate_native_sort'])}
            rows.append(row)
            print(json.dumps(row))
        assert [row['case'] for row in rows] == ['production-empty', 'legal-paid-29-active', 'synthetic-all-nonempty']
        audit.update(status='passed', assertions=receipt['assertions'], source_hashes=13,
                     blocks=48, samples=336, rows=rows)
(run / 'audit.json').write_text(json.dumps(audit, indent=2) + '\n', encoding='utf-8')
print(f"D9 {version} preservation: {audit['status']}; {len(records)} files; {len(baseline['protected'])} protected hashes")
