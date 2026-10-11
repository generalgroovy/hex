from pathlib import Path
import hashlib, json, math

root = Path(r'C:\Users\sende\Projects\hex')
assert Path.cwd() == root
out = root / 'docs/verification/hex-native-sort-20260923'
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream, 'sha256').hexdigest()
assert not (out / 'integrated-audit.json').exists()
freeze = read(out / 'integration-freeze-v1/freeze.json')
for item in freeze['files'] + read(out / 'integration-baseline.json')['protected']:
    assert sha(root / item['path']) == item['sha256'], item['path']
old = (out / 'integration-baseline-source/src/sim/hex/hex_chemistry_world.gd').read_bytes()
new = (root / 'src/sim/hex/hex_chemistry_world.gd').read_bytes()
marker = b'func _stable_hash_cells() -> Array:'
assert old.split(marker)[0] == new.split(marker)[0]
record = b'\tvar result: Array = []'
assert old.split(marker)[1].split(record, 1)[1] == new.split(marker)[1].split(record, 1)[1]
focused = read(out / 'focused-v1.json')
assert focused['result'] == 'passed' and focused['executed']['suite_count'] == 8
receipt = read(root / '.godot/hex-native-sort-candidate-integrated-v1.json')
assert receipt['profile_version'] == 'hex-native-sort-integrated-v1'
assert receipt['failures'] == 0 and receipt['equivalence_cases_completed'] == 42
assert receipt['ownership_cases_completed'] == 1 and receipt['profile_cases_completed'] == 3
assert receipt['runtime_identity'] == freeze['identity']
assert len(receipt['source_sha256']) == 14
for name, expected in receipt['source_sha256'].items(): assert sha(root/name) == expected, name
assert not (root / '.godot/hex-probe-native-sort-integrated-v1/probe.log.err').read_bytes()
def stats(samples):
    ordered = sorted(samples)
    assert min(ordered) > 0
    return {'samples': len(ordered), 'min': ordered[0], 'max': ordered[-1],
            **{f'p{p}': ordered[math.ceil(len(ordered)*p/100)-1] for p in [50,95,99]},
            'over_8333_us': sum(x>8333 for x in ordered), 'over_16667_us': sum(x>16667 for x in ordered)}
rows=[]
for case in receipt['cases']:
    flat = {name: [] for name in ['production_current','candidate_native_sort']}
    assert len(case['blocks']) == 16
    for i, block in enumerate(case['blocks']):
        order = ['production_current','candidate_native_sort','candidate_native_sort','production_current'] if (i//4)%2 == 0 else ['candidate_native_sort','production_current','production_current','candidate_native_sort']
        assert (block['cycle'],block['block'],block['implementation']) == (i//4,i%4,order[i%4])
        assert len(block['samples_us']) == 7 and stats(block['samples_us']) == block['statistics_us']
        flat[block['implementation']].extend(block['samples_us'])
    for name,samples in flat.items():
        assert len(samples) == 56 and samples == case['implementations'][name]['samples_us']
        assert stats(samples) == case['implementations'][name]['statistics_us']
    row={'case':case['case'],'integrated_us':stats(flat['production_current']),
         'preserved_prototype_us':stats(flat['candidate_native_sort'])}
    rows.append(row)
    print(json.dumps(row))
audit={'status':'passed','identity':freeze['identity'],'assertions':receipt['assertions'],
       'focused_suites':8,'focused_assertions':focused['executed']['assertion_count'],
       'measured_source_hashes':14,'raw_samples':336,'ordered_blocks':48,
       'world_prefix_and_record_projection_unchanged':True,'rows':rows,
       'scope':'Integrated-versus-prototype measurement; historical v1 is the old/new comparison.'}
(out/'integrated-audit.json').write_text(json.dumps(audit,indent=2)+'\n',encoding='utf-8')
print('PASS: frozen integrated public hash, source boundaries, Focused and timing audit')
