"""Offline recomputation/archive only. Never launches an engine or changes runtime."""
from pathlib import Path
from collections import Counter
import hashlib
import json
import math
import statistics

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'docs/iteration-20261013/terrain-worker'
PROBE = ROOT / '.godot/iteration-20261013/terrain-worker'
EXPECTED = {
    'forward': 'e9697d25ba44874ac03cae3062f99527d45baf1f5264b797a3a568f43ebf8d0a',
    'reverse': '03a8b9e32db3a45986e42bce967421828946dc47fcaabfa3a85000eb1c9bd873',
    'functional': 'b6ca525df36a5e84ebc8eadf30bc405da4ba7c0aa0ebc1536631b9f1fb330a4a',
}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def stats(values):
    values = list(values)
    if not values:
        return {'count': 0}
    ordered = sorted(values)
    return {'count': len(values), 'mean': statistics.mean(values),
            'median': statistics.median(values), 'p95': ordered[math.ceil(.95*len(values))-1],
            'min': ordered[0], 'max': ordered[-1]}

payloads = []
def archive(source, relative):
    source = Path(source)
    dest = OUT / relative
    data = source.read_bytes()
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        assert dest.read_bytes() == data, f'Existing archive differs: {relative}'
    else:
        dest.write_bytes(data)
    payloads.append({'source': source.relative_to(ROOT).as_posix(),
                     'path': relative, 'bytes': len(data), 'sha256': sha(source)})

runs = {}
sources = {}
for name in ('forward', 'reverse'):
    source = PROBE / f'native-{name}-a.json'
    assert sha(source) == EXPECTED[name]
    run = json.loads(source.read_text(encoding='utf-8-sig'))
    assert run['passed'] and not run['errors']
    assert len(run['cases']) == 64 and len(run['early_walking']) == 8 and len(run['cancellation']) == 2
    assert run['reverse'] == (name == 'reverse')
    runs[name] = run
    for path, digest in run['sources'].items():
        local = ROOT / path.removeprefix('res://')
        assert sha(local) == digest, path
        assert sources.get(path, digest) == digest
        sources[path] = digest
    for case in run['cases']:
        assert case['warmup'] == (case['cycle'] < 2)
        closed = case['closed_status']
        assert closed['closed'] and closed['pending'] == 0 and not closed['error']
        assert case['walking_unready_frames'] == 0
        if case['role'] == 'after':
            assert closed['tasks_started'] > 0 and closed['tasks_started'] == closed['tasks_joined']
            assert closed['active_hash_tasks'] == closed['validation_pending'] == 0
        for pump in case['pumps']:
            status = pump['status']
            assert 0 <= status['pending'] <= 2 and pump['whole_pump_us'] >= 0
            if case['role'] == 'after':
                assert status['decode_pending'] + status['validation_pending'] == status['pending']
                assert status['tasks_started'] - status['tasks_joined'] == status['active_hash_tasks']
                assert status['peak_stored_validation_bytes'] <= 2 * 1024**2
                assert status['peak_transient_validation_bytes'] <= 3 * 1024**2
    archive(source, f'native/{name}.json')
    for suffix, dest in (('.log','stdout.log'),('.log.err','stderr.log')):
        log = PROBE / f'native-{name}-a{suffix}'
        if suffix.endswith('.err'): assert log.stat().st_size == 0
        archive(log, f'native/{name}-{dest}')

functional_path = ROOT / '.godot/iteration-20261013/terrain-worker-runs/functional-a/receipt.json'
assert sha(functional_path) == EXPECTED['functional']
functional = json.loads(functional_path.read_text())
assert functional['passed'] and functional['checks'] == 162 and not functional['errors'] and len(functional['cases']) == 10
for path, digest in functional['source_hashes'].items():
    assert sha(ROOT / path.removeprefix('res://')) == digest, path
    assert sources.get(path, digest) == digest
    sources[path] = digest
for case in functional['cases']:
    assert case['status']['closed'] and case['status']['pending'] == case['status']['validation_pending'] == 0
    for path, requests in case['loader_requests'].items():
        assert case['loader_gets'].get(path, 0) + case['loader_finalizations'].get(path, 0) == requests
archive(functional_path, 'functional/receipt.json')
for suffix, dest in (('.log','stdout.log'),('.log.err','stderr.log')):
    log = PROBE / f'functional-a{suffix}'
    if suffix.endswith('.err'): assert log.stat().st_size == 0
    archive(log, 'functional/' + dest)

measured = [(name, c) for name, r in runs.items() for c in r['cases'] if not c['warmup']]
assert len(measured) == 96
views = []
for view in ('garden','large28','partial_edge','single_full'):
    by_role = {}
    for role in ('before','after'):
        group = [c for _, c in measured if c['view'] == view and c['role'] == role]
        assert len(group) == 12
        by_role[role] = {
            'cases': 12,
            'required_tiles': sorted({len(c['required_ids']) for c in group}),
            'arrival_through_halo_pump_us': stats(p['whole_pump_us'] for c in group for p in c['pumps'] if p['phase'] == 'arrival'),
            'first_ready_zero_based_index': stats(c['first_ready_frame'] for c in group),
            'first_ready_pump_count': stats(c['first_ready_frame']+1 for c in group),
            'first_ready_wall_ms': stats(c['first_ready_wall_us']/1000 for c in group),
            'halo_drained_pump_count': stats(c['halo_drained_frame']+1 for c in group),
            'halo_drained_wall_ms': stats(c['halo_drained_wall_us']/1000 for c in group),
            'all_phase_main_pump_cpu_ms': stats(sum(p['whole_pump_us'] for p in c['pumps'])/1000 for c in group),
            'worker_hash_elapsed_ms_separate': stats(c['profile'].get('worker_elapsed_usec',0)/1000 for c in group),
            'nested_main_stage_ms_per_case': {key: stats(c['profile']['elapsed_usec'].get(key,0)/1000 for c in group) for key in sorted({k for c in group for k in c['profile']['elapsed_usec']})},
            'fully_drained_walking_unready_frames': sum(c['walking_unready_frames'] for c in group),
        }
    pairs = []
    for name, run in runs.items():
        for cycle in range(2,8):
            old = next(c for c in run['cases'] if c['view']==view and c['cycle']==cycle and c['role']=='before')
            new = next(c for c in run['cases'] if c['view']==view and c['cycle']==cycle and c['role']=='after')
            assert old['actual_arm_order'] == new['actual_arm_order']
            pairs.append({'run':name,'cycle':cycle,'candidate_first':new['actual_arm_order'][0]=='after',
                          'ready_pump_delta':new['first_ready_frame']-old['first_ready_frame'],
                          'ready_wall_delta_ms':(new['first_ready_wall_us']-old['first_ready_wall_us'])/1000,
                          'all_phase_main_cpu_delta_ms':(sum(p['whole_pump_us'] for p in new['pumps'])-sum(p['whole_pump_us'] for p in old['pumps']))/1000})
    strata = []
    for first in (False,True):
        selected = [p for p in pairs if p['candidate_first']==first]
        assert len(selected)==6
        strata.append({'candidate_first':first,'pairs':len(selected), **{key:stats(p[key] for p in selected) for key in ('ready_pump_delta','ready_wall_delta_ms','all_phase_main_cpu_delta_ms')}})
    views.append({'view':view,'roles':by_role,'paired_rows':pairs,'order_strata':strata})

early=[]
for name, run in runs.items():
    for item in run['early_walking']:
        assert len(item['trace'])==24 and item['final_requested_position']==item['final_last_ready_position']
        early.append({'run':name, **{key:item[key] for key in ('role','view','first_ready_frame','first_ready_wall_us','unfinished_halo_at_start','unready_frames','longest_unready_run','requested_path_px','last_ready_proxy_path_px','final_requested_position','final_last_ready_position')}})

for path in sorted(sources):
    archive(ROOT / path.removeprefix('res://'), 'sources/' + path.removeprefix('res://'))
archive(Path(__file__), 'analyze-worker-streaming.py')
for name in ('README.md','stream-parse.log','stream-parse.log.err','hash-job-parse.log','hash-job-parse.log.err','functional-parse.log','functional-parse.log.err','comparison-parse.log','comparison-parse.log.err'):
    archive(PROBE/name, 'qualification/'+name)

report = {
    'schema':'hex.terrain-worker-independent-review.v1','passed':True,
    'status':'ignored_prototype_functional_and_isolated_native_passed; production_adoption_pending_actual_Bootstrap_routes',
    'functional':{'checks':162,'cases':10,'actual_joins':sum(c['actual_join_calls'] for c in functional['cases']),
                  'scope':functional['scope'],'per_generation_note':'Successful reconfigure resets public task counters; the fixture retains actual join/token counters across that boundary.'},
    'native_runs':{name:{'checks':run['checks'],'cases':64,'warmup_cases':16,'measured_cases':48,'early_walks':8,'cancellation_cases':2,'errors':run['errors']} for name,run in runs.items()},
    'source_files_verified':len(sources),'views':views,'early_camera_demand':early,
    'cancellation':[{ 'run':name,'role':c['role'],'first_ready_pumps':c['first_ready_frame']+1,'first_ready_wall_us':c['first_ready_wall_us'],'suspend_us':c['suspend_us'],'closed_status':c['closed_status']} for name,run in runs.items() for c in run['cancellation']],
    'scope':runs['forward']['scope'],
    'interpretation_limits':[
        'No production code is changed; exact source hashes bind these isolated prototypes only.',
        'Arrival p95 pools whole pump calls through full halo drain, not gameplay frame intervals. First-ready pump count adds one to the raw zero-based completion index.',
        'Twelve measured sequential arm pairs per view across two processes; two warmup cycles/process remain raw. OS/resource/driver cache history is uncontrolled.',
        'Main CPU and worker elapsed can overlap. Their sum is not critical-path or process CPU time; worker time can include descheduling.',
        'Texture creation is driver submission and endpoint readback is excluded from pump clocks; no GPU execution claim.',
        'Early walking is 24 fixed camera-demand samples, not actual Bootstrap or human input. Required latency of one-tile cases must remain separate from larger-view improvement.',
        'Functional tasks are genuine, but loader tokens/pump clock are synthetic; the injected join failure is a non-disposing error control.',
        'Stored validation payloads and conservative transient overlap are logical counts, not RSS or a hard memory ceiling.',
    ],
}
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
(OUT/'archive-manifest.json').write_text(json.dumps({'schema':'hex.terrain-worker-archive.v1','payloads':payloads,'payload_count':len(payloads),'payload_bytes':sum(p['bytes'] for p in payloads),'notes':'Byte-exact source/evidence payloads; review and this manifest are generated independently and excluded from their own hash list.'},indent=2)+'\n',encoding='utf-8')
print(json.dumps({'archive':str(OUT),'payloads':len(payloads),'payload_bytes':sum(p['bytes'] for p in payloads),'views':[{'view':v['view'],'old':{k:v['roles']['before'][k] for k in ('arrival_through_halo_pump_us','first_ready_pump_count','first_ready_wall_ms','all_phase_main_pump_cpu_ms')},'new':{k:v['roles']['after'][k] for k in ('arrival_through_halo_pump_us','first_ready_pump_count','first_ready_wall_ms','all_phase_main_pump_cpu_ms')},'order_strata':v['order_strata']} for v in views],'early':early},indent=2))
