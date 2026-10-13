"""Read-only raw review and exact-byte archive; never runs the engine or edits source."""
from pathlib import Path
from collections import Counter
import hashlib
import json
import math
import statistics

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/iteration-20261013/movement-cast-contiguous-timing'
BASE = ROOT / '.godot/iteration-20261013/movement-cast-timing/runs'
EXPECTED = {
    ('garden_idle', 'forward'): '667ecd48d9c8bf149db3e6e6fae4cb98d77536eceb9b771018171e9e236bbcb0',
    ('garden_idle', 'reverse'): 'fc6fa3fc5102cca1e86aeac7ca23611cc9e3e9a5e008f564201320ee4761f786',
    ('fire_close', 'forward'): '6ec84c9793a93d068f05166d4f0711e04c4f1adaef658a814e179728c4feadcc',
    ('fire_close', 'reverse'): 'cfa175fda538856277d7cadb76c4f129bda03b3a651d4c42bc21278e1f4476ce',
    ('bootstrap_roster_mantle', 'forward'): 'ed0226f63a6e782b7d89338feae212d1429e183c6c239e0eacfe9a9513897d5b',
    ('bootstrap_roster_mantle', 'reverse'): 'aaf778b744d9c1581765fb5f6b69d79c96df5f7b47a9716d81ec658e236aa1b7',
}
CHILDREN = ['setup_resources_status', 'reaction_contact_ratios', 'hex_pre_movement',
            'movement', 'admission_offer', 'combat_player', 'release_store']
BRANCHES = ['actors_entered', 'dead_at_entry', 'dead_after_status', 'missing_command',
            'admission_offers', 'release_results']
checks = 0
payloads = {}

def check(ok, message):
    global checks
    checks += 1
    if not ok:
        raise AssertionError(message)

def digest(raw):
    return hashlib.sha256(raw).hexdigest()

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def resolve(uri):
    check(isinstance(uri, str) and uri.startswith('res://'), 'resource path')
    p = (ROOT / uri[6:]).resolve()
    check(p.is_relative_to(ROOT), 'root containment')
    return p

def archive(path, relative):
    raw = path.read_bytes()
    previous = payloads.get(relative)
    check(previous is None or previous['sha256'] == digest(raw), 'duplicate archive mapping')
    payloads[relative] = {'original_path': path.relative_to(ROOT).as_posix(),
                          'path': relative, 'bytes': len(raw), 'sha256': digest(raw)}
    destination = OUT / relative
    if destination.exists():
        check(destination.read_bytes() == raw, 'existing archive exact')
    else:
        destination.parent.mkdir(parents=True, exist_ok=True)
        with destination.open('xb') as f:
            f.write(raw)
        check(destination.read_bytes() == raw, 'archive readback')

def numbers(values):
    return all(type(x) in (int, float) and math.isfinite(x) and x >= 0 for x in values)

def stats(values):
    values = list(values)
    if not values:
        return None
    ordered = sorted(values)
    return {'n': len(values), 'mean': round(statistics.mean(values), 6),
            'median': round(statistics.median(values), 6),
            'p95_nearest_rank': ordered[math.ceil(len(values) * .95) - 1],
            'min': ordered[0], 'max': ordered[-1]}

def group_summary(groups):
    if not groups:
        return None
    steps = [row for g in groups for row in g['step_rows']]
    plain = [g['plain']['loop_elapsed_us'] for g in groups]
    observed = [g['observed']['loop_elapsed_us'] for g in groups]
    return {
        'groups': len(groups), 'steps': len(steps),
        'actual_order_counts': dict(Counter('>'.join(g['actual_order']) for g in groups)),
        'plain_loop_us': stats(plain), 'observed_loop_us': stats(observed),
        'paired_observed_minus_plain_loop_us': stats(b-a for a, b in zip(plain, observed)),
        'observed_slower_pairs': sum(b > a for a, b in zip(plain, observed)),
        'observed_faster_pairs': sum(b < a for a, b in zip(plain, observed)),
        'plain_parent_per_step_us': stats(x for g in groups for x in g['plain']['parent_us']),
        'observed_parent_per_step_us': stats(s['parent_us'] for s in steps),
        'observed_parent_residual_per_step_us': stats(s['parent_residual_us'] for s in steps),
        'plain_outer_minus_parent_per_group_us': stats(g['plain']['loop_elapsed_us']-sum(g['plain']['parent_us']) for g in groups),
        'observed_outer_minus_parent_per_group_us': stats(g['observed']['loop_elapsed_us']-sum(g['observed']['parent_us']) for g in groups),
        'child_per_step_us': {name: stats(s['child_us'][i] for s in steps) for i, name in enumerate(CHILDREN)},
        'executions': {name: sum(s['executions'][i] for s in steps) for i, name in enumerate(CHILDREN)},
        'branches': {name: sum(s['branches'][i] for s in steps) for i, name in enumerate(BRANCHES)},
        'buffer_prepare_per_group_us': {arm: stats(g[arm]['buffer_prepare_us'] for g in groups) for arm in ('plain', 'observed')},
    }

def outliers(groups, key, count=8):
    return [{'process': g['_process'], 'serial': g['serial'], 'phase': g['phase'],
             'steps': g['steps'], 'tick_before': g['tick_before'], 'tick_after': g['boundary']['tick'],
             'actual_order': g['actual_order'], 'plain_loop_us': g['plain']['loop_elapsed_us'],
             'observed_loop_us': g['observed']['loop_elapsed_us'],
             'plain_parent_sum_us': sum(g['plain']['parent_us']),
             'observed_parent_sum_us': sum(g['observed']['parent_us']),
             'child_sum_us': sum(g['observed']['child_us']),
             'event_types': sorted({str(e.get('type')) for row in g['observed']['events'] for e in row}),
             'workload_before': g['workload_before'], 'workload_after': g['workload_after']}
            for g in sorted(groups, key=key, reverse=True)[:count]]

check(not (OUT / 'review.json').exists(), 'fresh review output')
frozen = read(OUT / 'source-pin-review.json')
check(frozen['passed'] is True and frozen['verified_source_pin_count'] == 335, 'frozen source review')
pins = {r['original_path']: r['sha256'] for r in frozen['source_pins']}
for row in frozen['source_pins']:
    if row['archived_path']:
        check(digest((OUT / row['archived_path']).read_bytes()) == row['sha256'], 'frozen copied input')
all_groups = {}
results = []
qualified = {}
total_engine_checks = 0
for (label, order), expected in EXPECTED.items():
    folder = BASE / f'probe-{order}-{label}-a'
    path = folder / 'receipt.json'
    check(digest(path.read_bytes()) == expected, 'root receipt hash '+label+order)
    d = read(path)
    check(d['passed'] is True and d['errors'] == [] and d['mode'] == 'timing', 'receipt acceptance')
    check(d['schema'] == 'hex-movement-cast-contiguous-timing-v1', 'schema')
    check(d['selected_case'] == label and len(d['cases']) == 1, 'selected inventory')
    check(d['reverse_initial_order'] is (order == 'reverse'), 'process order')
    check(d['child_names'] == CHILDREN and d['branch_names'] == BRANCHES, 'lane inventory')
    check(d['cleanup'] == {'ended_worlds': 2, 'factory_owned': False, 'remaining_worlds': 0}, 'cleanup')
    check(type(d['checks']) is int and d['checks'] > 0, 'check count')
    total_engine_checks += d['checks']
    qualification = d['qualification']; qpath = resolve(qualification['path'])
    check(digest(qpath.read_bytes()) == qualification['sha256'], 'qualification digest')
    check(d['source_hashes'] == dict(pins, **{qualification['path']: qualification['sha256']}), 'exact 336-source map')
    q = read(qpath); qc = q['cases'][0]
    check(q['passed'] is True and q['errors'] == [] and q['mode'] == 'functional', 'functional prerequisite')
    check(q['selected_case'] == label and len(q['cases']) == 1, 'functional case')
    check(q['cleanup']['ended_worlds'] == 2 and q['cleanup']['remaining_worlds'] == 0, 'functional cleanup')
    for uri, sha in q['source_hashes'].items():
        check(pins.get(uri) == sha, 'functional pinned input')
    if label in qualified:
        check(qualified[label] == qualification, 'same qualification both orders')
    qualified[label] = qualification
    archive(qpath, f'qualifications/{label}/receipt.json')
    c = d['cases'][0]; ticks = 240 if label == 'garden_idle' else 480
    check(c['label'] == label and c['completed_ticks'] == ticks and c['actual_recorded_attempts'] == ticks, 'tick inventory')
    check(c['final_state_hash'] == qc['final_state_hash'] and c['qualification_record'] == qc['record'], 'final qualified state/record')
    qr = {int(row['tick_after']): row for row in qc['rows']}
    check(len(qr) == ticks, 'unique functional ticks')
    groups = c['groups']; cycles = 26 if label == 'garden_idle' else 52
    schedule = [(phase, n) for cy in range(cycles) for phase in ['warmup' if cy < 2 else 'measured'] for n in (0, 1, 8)]
    schedule += [('verification_tail', 6)] if label == 'garden_idle' else [('verification_tail', 8), ('verification_tail', 4)]
    check([(g['phase'], g['steps']) for g in groups] == schedule, 'exact warm/measured/tail schedule')
    before = 0; event_counts = Counter()
    for serial, g in enumerate(groups):
        n = g['steps']; after = before+n
        check(g['serial'] == serial and g['tick_before'] == before and g['valid'] is True, 'serial/valid/continuity')
        want = ['observed','plain'] if (serial % 2 == 0) != (order == 'reverse') else ['plain','observed']
        check(g['actual_order'] == want, 'actual recorded order')
        check(g['boundary']['tick'] == after and g['workload_before']['tick'] == before and g['workload_after']['tick'] == after, 'tick boundary')
        check(len(g['step_rows']) == n, 'step row length')
        boundary = qr[after] if after else c['initial_boundary']
        check(g['boundary']['state_hash'] == boundary['state_hash'] and g['boundary']['packet_sha256'] == boundary['packet_sha256'], 'strict qualified endpoint')
        for arm in ('plain', 'observed'):
            a = g[arm]
            check(a['attempted'] == n and a['ticks'] == list(range(before+1,after+1)), 'arm step count')
            check(a['success'] == [1]*n and a['errors'] == ['']*n and a['unfinished'] == [0]*n, 'successful/closed arm')
            check(len(a['parent_us']) == n and len(a['child_us']) == n*7 and len(a['branches']) == n*6 and len(a['executions']) == n*7, 'bounded lane shape')
            check(numbers(a['parent_us']+a['child_us']+a['branches']+a['executions']+[a['loop_elapsed_us'],a['buffer_prepare_us']]), 'finite nonnegative clocks/counts')
            check(sum(a['parent_us']) <= a['loop_elapsed_us'], 'parent inside outer group')
            check(a['events'] == [qr[t]['events'] for t in range(before+1,after+1)], 'every retained event vs functional')
        check(all(x == 0 for key in ('child_us','executions','branches') for x in g['plain'][key]), 'plain child observer disabled')
        check(g['observed']['events'] == g['plain']['events'], 'paired ordered event equality')
        for i, s in enumerate(g['step_rows']):
            tick = before+i+1; reference = qr[tick]; observation = reference['observation']
            check(s['tick'] == tick and s['events'] == reference['events'], 'step qualified event')
            check(s['executions'] == observation['executions'], 'qualified executions')
            check(s['branches'] == [observation[key] for key in BRANCHES], 'qualified branches')
            check(s['child_us'] == g['observed']['child_us'][i*7:(i+1)*7] and s['executions'] == g['observed']['executions'][i*7:(i+1)*7] and s['branches'] == g['observed']['branches'][i*6:(i+1)*6], 'step/group lane parity')
            check(s['parent_us'] == g['observed']['parent_us'][i] and s['parent_residual_us'] == s['parent_us']-sum(s['child_us']) >= 0, 'disjoint child containment')
            event_counts.update(str(e.get('type')) for e in s['events'])
        check(g['boundary']['matter_paid'] == g['workload_after']['matter_paid'] and g['boundary']['matter_expired'] == g['workload_after']['matter_expired'], 'payment boundary witness')
        g['_process'] = order; before = after
    check(before == ticks, 'complete trajectory')
    check(groups[-1]['boundary']['matter_paid'] == qc['record']['matter_paid'] and groups[-1]['boundary']['matter_expired'] == qc['record']['matter_expired'], 'qualified final payment')
    archive(path, f'raw/{label}/{order}/receipt.json')
    for suffix in ('.log','.log.err','-parse.log','-parse.log.err'):
        log = folder.parent / (folder.name+suffix)
        if suffix.endswith('.err'):
            check(log.read_bytes() == b'', 'empty stderr '+str(log))
        archive(log, f'raw/{label}/{order}/{log.name}')
    all_groups.setdefault(label, []).extend(groups)
    measured = [g for g in groups if g['phase']=='measured']
    results.append({'case': label, 'process': order, 'receipt_sha256': expected, 'checks': d['checks'],
                    'source_pins': len(d['source_hashes']), 'wall_elapsed_ms': d['wall_elapsed_ms'],
                    'qualification': qualification, 'groups':len(groups), 'completed_ticks':ticks,
                    'actual_all_event_counts':dict(event_counts), 'record':qc['record'],
                    'initial_roster':c['initial_boundary']['roster'], 'roster_proof':c['roster_proof'],
                    'all_measured':group_summary(measured),
                    'by_steps':{str(n):group_summary([g for g in measured if g['steps']==n]) for n in (0,1,8)},
                    'warmup':group_summary([g for g in groups if g['phase']=='warmup']),
                    'tail':group_summary([g for g in groups if g['phase']=='verification_tail'])})

pooled = {}
for label, groups in all_groups.items():
    measured = [g for g in groups if g['phase']=='measured']
    def events(g):
        return {str(e.get('type')) for row in g['observed']['events'] for e in row}
    predicates = {
        'admission_event':lambda g:'cast_started' in events(g),
        'release_event':lambda g:bool(events(g) & {'cast_released','projectile_spawned'}),
        'refusal_event':lambda g:'cast_refused' in events(g),
        'pending_at_group_start':lambda g:g['workload_before']['local_pending_ticks']>0,
        'cooldown_at_group_start':lambda g:g['workload_before']['local_cooldown_ticks']>0,
        'flight_at_either_boundary':lambda g:max(g['workload_before']['flights'],g['workload_after']['flights'])>0,
        'ground_at_either_boundary':lambda g:max(g['workload_before']['ground_parts'],g['workload_after']['ground_parts'])>0,
        'product_at_either_boundary':lambda g:max(g['workload_before']['products'],g['workload_after']['products'])>0,
    }
    pooled[label] = {
        'all_measured':group_summary(measured),
        'by_steps':{str(n):group_summary([g for g in measured if g['steps']==n]) for n in (0,1,8)},
        'by_invocation_order':{order:group_summary([g for g in measured if g['actual_order'][0]==order]) for order in ('plain','observed')},
        'order_and_steps':{order:{str(n):group_summary([g for g in measured if g['actual_order'][0]==order and g['steps']==n]) for n in (0,1,8)} for order in ('plain','observed')},
        'overlapping_phase_strata':{name:group_summary([g for g in measured if predicate(g)]) for name,predicate in predicates.items()},
        'largest_observed_groups':outliers(measured,lambda g:g['observed']['loop_elapsed_us']),
        'largest_positive_observer_differences':outliers(measured,lambda g:g['observed']['loop_elapsed_us']-g['plain']['loop_elapsed_us']),
        'largest_negative_observer_differences':outliers(measured,lambda g:g['plain']['loop_elapsed_us']-g['observed']['loop_elapsed_us']),
    }

for label,qinfo in qualified.items():
    if label == 'bootstrap_roster_mantle':
        folder=resolve(qinfo['path']).parent
        for suffix in ('.log','.log.err','-parse.log','-parse.log.err'):
            log=folder.parent/(folder.name+suffix)
            if suffix.endswith('.err'): check(log.read_bytes()==b'', 'roster prerequisite stderr')
            archive(log,f'qualifications/{label}/{log.name}')
archive(ROOT/'.godot/iteration-20261013/movement-cast-roster-functional-review.json','qualifications/bootstrap_roster_mantle/independent-functional-review.json')
archive(Path(__file__), 'review-movement-cast-contiguous.py')
report = {'schema':'hex-contiguous-movement-cast-independent-review-v1','passed':True,
          'independent_checks':checks+1,'engine_checks_sum':total_engine_checks,'receipt_count':6,
          'total_groups':sum(len(v) for v in all_groups.values()),
          'measured_groups':sum(g['phase']=='measured' for gs in all_groups.values() for g in gs),
          'warmup_groups':sum(g['phase']=='warmup' for gs in all_groups.values() for g in gs),
          'tail_groups':sum(g['phase']=='verification_tail' for gs in all_groups.values() for g in gs),
          'total_paired_completed_steps':sum(g['steps'] for gs in all_groups.values() for g in gs),
          'runtime_identity':frozen['runtime_identity'],'source_review_sha256':digest((OUT/'source-pin-review.json').read_bytes()),
          'quantiles':'Nearest-rank p95, statistics.median; samples are phase-correlated paired groups, not independent frames.',
          'scope':'Native main-thread elapsed intervals, not thread CPU counters. Seven children are disjoint inside the observed movement/cast parent; all other step work and bounded event/scalar storage remain in outer group clocks. Observed extra lane/branch copying and clock/bookkeeping cost are real observer overhead. Existing nine-stage/cumulative observers are enabled in both arms. Full packet/state/serialization verification is between groups; boundary cache/thermal effects remain. Per-step retained event/branch/execution parity is independently rechecked against exact full-functional traces. Interior timing states were not separately snapshotted. Zero groups measure actual empty-loop overhead. One-actor Garden/Fire and five-actor prepared Bootstrap-factory Mantle exclude rendering, separate exhibition courts and actual Bootstrap process/catch-up. No gameplay speedup, GPU, physical input, FPS or matched foreground attribution claim.',
          'process_results':results,'pooled':pooled,'archived_payloads':list(payloads.values())}
target=OUT/'review.json'
with target.open('x',encoding='utf-8',newline='\n') as f: json.dump(report,f,indent=2);f.write('\n')
check(read(target)==report,'review readback')
print(json.dumps({'review':str(target.relative_to(ROOT)), 'sha256':digest(target.read_bytes()),
                  'checks':checks,'engine_checks':total_engine_checks,'groups':report['total_groups'],
                  'measured':report['measured_groups'],'warmups':report['warmup_groups'],'tails':report['tail_groups']}))
for label,summary in pooled.items():
    measured=summary['all_measured']
    print(label, 'parent',measured['observed_parent_per_step_us'],
          'children',{n:s['mean'] for n,s in measured['child_per_step_us'].items()})
    for n in ('1','8'):
        s=summary['by_steps'][n]
        print('steps',n,'plain',s['plain_loop_us'],'observed',s['observed_loop_us'],'delta',s['paired_observed_minus_plain_loop_us'])
