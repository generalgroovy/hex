from pathlib import Path
import hashlib, json, math, sys
from PIL import Image

root = Path(r'C:\Users\sende\Projects\hex')
out = root / 'docs/verification/hex-viewport-20260923'
assert Path.cwd().resolve() == root.resolve()
attempt = sys.argv[1]
assert attempt in ['v2', 'v3']
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
receipt_path = root / f'.godot/hex-viewport-candidate-{attempt}.json'
j = read(receipt_path)
assert j['failures'] == 0 and j['assertions'] == 2970 and not j.get('partial', False)
assert (j['visibility_cases_completed'], j['pixel_cases_completed'], j['timing_cases_completed']) == (103, 55, 4)
assert j['runtime_identity'] == read(out / 'baseline.json')['runtime_identity']
assert len(j['source_sha256']) == 13
freeze = read(out / 'attempts' / attempt / 'freeze.json')
preserved = {row['source']: out / row['preserved'] for row in freeze['files']}
for name, digest in j['source_sha256'].items():
    assert sha(preserved.get(name, root / name)) == digest, name
assert sha(root / 'content/runtime/runtime_build_identity_v1.json') == j['runtime_identity_sha256']
assert not (root / f'.godot/hex-probe-viewport-{attempt}/probe.log.err').read_bytes()
images = []
assert len({c['case'] for c in j['pixel_cases']}) == 55
for c in j['pixel_cases']:
    assert c['pixel_equal'] and c['positive_visible_control']
    d = c['diagnostics']
    assert d['counts_complete'] and d['full_total'] == d['retained_total'] + d['rejected_total']
    for material, count in d['full_by_material'].items():
        assert count == d['retained_by_material'][material] + d['rejected_by_material'][material]
    if c['representative_png']:
        folder = root / f'.godot/hex-viewport-candidate-{attempt}-frames'
        a = folder / (c['case'] + '-baseline.png')
        b = folder / (c['case'] + '-candidate.png')
        with Image.open(a) as x, Image.open(b) as y:
            assert x.size == y.size == (1280, 720)
            pixels = x.convert('RGBA').tobytes()
            assert pixels == y.convert('RGBA').tobytes()
        assert hashlib.sha256(pixels).hexdigest() == c['rgba_sha256']
        assert sha(a) == sha(b)
        images.append({'case': c['case'], 'png_sha256': sha(a), 'rgba_sha256': c['rgba_sha256']})
assert len(images) == 9
timings = []
for c in j['timing_cases']:
    assert len(c['rows']) == 80 and c['actors'] == 8 and c['topology_cells'] == 2766 and c['world_tick'] == 160
    flat = {arm: {key: [] for key in ['ground', 'draw', 'present']} for arm in ['production_current', 'candidate']}
    for i, row in enumerate(c['rows']):
        cycle, offset = divmod(i, 20)
        block, index = divmod(offset, 5)
        order = ['production_current', 'candidate', 'candidate', 'production_current'] if cycle % 2 == 0 else ['candidate', 'production_current', 'production_current', 'candidate']
        assert (row['cycle'], row['block'], row['index'], row['arm']) == (cycle, block, index, order[block])
        for key in flat[row['arm']]:
            assert row[key + '_us'] > 0
            flat[row['arm']][key].append(row[key + '_us'])
    assert flat == c['samples']
    misses = {}
    for arm, series in flat.items():
        misses[arm] = {}
        for key, values in series.items():
            assert len(values) == 40
            ordered = sorted(values)
            expected = {'samples': 40, 'max': max(values)}
            expected.update({f'p{p}': ordered[math.ceil(40*p/100)-1] for p in [50,95,99]})
            assert expected == c['summary_us'][arm][key], (c['case'], arm, key)
            misses[arm][key] = sum(v > 16667 for v in values)
    timings.append({'case': c['case'], 'mode': c['mode'], 'summary_us': c['summary_us'], 'above_16667us': misses})
report = {'status':'passed', 'attempt': attempt, 'receipt_sha256': sha(receipt_path),
          'scope':'Independent artifact, RGBA, order and arithmetic audit. Not a new engine run or capacity acceptance.',
          'pixel_cases':55, 'timed_rows':320, 'images':images, 'timing':timings}
target = out / ('audit-' + attempt + '.json')
assert not target.exists(), 'preserve existing audit'
target.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(f'PASS: {attempt};13 source hashes,55 controls,9 decoded PNG pairs,320 raw timing rows and24 percentile series')
for row in timings:
    a,b = (row['summary_us'][x]['draw'] for x in ['production_current','candidate'])
    print(row['case'],row['mode'],'draw p50/p95',a['p50'],a['p95'],'->',b['p50'],b['p95'],'present misses',row['above_16667us']['candidate']['present'])
