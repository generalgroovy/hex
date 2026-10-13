from pathlib import Path
import collections
import hashlib
import json
import re
import shutil

ROOT = Path.cwd()
BASE = ROOT / '.godot/iteration-20261013/movement-cast-attribution'
OUT = ROOT / 'docs/iteration-20261013/movement-cast-functional-b'
EXPECTED = {
    'garden_idle': 240, 'fire_default': 480, 'fire_close': 480, 'mantle': 480,
    'movement_chain': 240, 'missing_command': 1, 'dead_at_entry': 1,
    'legacy_paid': 120, 'wrong_tick': 1, 'paid_status_death': 96,
    'campus_wall': 160, 'paid_black_ice': 240, 'zero_one_eight_groups': 9,
}
EVENTS = {'cast_started', 'cast_refused', 'projectile_spawned', 'projectile_hit',
          'spell_status_hit', 'hex_pressure', 'defeated'}
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
digest = lambda value: isinstance(value, str) and re.fullmatch('[0-9a-f]{64}', value)

assert not OUT.exists(), 'Fresh review/archive output required'
found = {p.parent.name.removeprefix('functional-').removesuffix('-b'): p
         for p in (BASE / 'runs').glob('functional-*-b/receipt.json')}
assert set(found) == set(EXPECTED), 'Exactly all thirteen distinct selected cases required'
common_pins = None
reviews = []
source_files = []
checks = attempts = completed = ended = 0

for label, count in EXPECTED.items():
    path = found[label]
    data = json.loads(path.read_text(encoding='utf-8-sig'))
    assert data['schema'] == 'hex-movement-cast-attribution-v1'
    assert data['passed'] is True and data['errors'] == [] and data['mode'] == 'functional'
    assert data['selected_case'] == label and data['reverse_initial_order'] is False
    assert data['cleanup'] == {'ended_worlds': 2, 'remaining_worlds': 0}
    assert len(data['cases']) == 1 and data['cases'][0]['label'] == label
    assert type(data['checks']) is int and data['checks'] > 0
    if common_pins is None:
        common_pins = data['source_hashes']
        assert len(common_pins) == 329
        for name, value in common_pins.items():
            assert name.startswith('res://') and '..' not in name and digest(value)
            target = ROOT / name[6:]
            assert target.resolve().is_relative_to(ROOT.resolve()) and sha(target) == value, name
    else:
        assert data['source_hashes'] == common_pins, 'All thirteen use one exact source checkpoint'
    case = data['cases'][0]
    if label == 'zero_one_eight_groups':
        assert [row['steps'] for row in case['rows']] == [0, 1, 8, 0]
        assert [(row['tick_before'], row['tick_after']) for row in case['rows']] == [(0, 0), (0, 1), (1, 9), (9, 9)]
        rows = [attempt for group in case['rows'] for attempt in group['attempts']]
    else:
        assert case['actual_recorded_attempts'] == count
        assert case['completed_ticks'] == (0 if label == 'wrong_tick' else count)
        rows = case['rows']
    assert len(rows) == count
    orders = collections.Counter()
    lanes = [0] * 7
    branches = collections.Counter()
    retained_events = []
    for index, row in enumerate(rows):
        okay = label != 'wrong_tick'
        assert row['expected_success'] is okay
        assert row['plain']['success'] is okay and row['observed_cost']['success'] is okay
        assert row['tick_before'] == index and row['tick_after'] == index + int(okay)
        expected_order = ['observed', 'plain'] if index % 2 == 0 else ['plain', 'observed']
        assert row['actual_order'] == expected_order
        assert row['plain']['serial'] == 2 * index + 1 + expected_order.index('plain')
        assert row['observed_cost']['serial'] == 2 * index + 1 + expected_order.index('observed')
        observation = row['observation']
        assert observation['unfinished_interval'] is False
        values = observation['elapsed_us']
        executions = observation['executions']
        assert len(values) == len(executions) == 7
        assert all(type(v) is int and v >= 0 for v in values + executions)
        assert sum(values) <= row['parent_us'] <= row['observed_cost']['whole_step_us']
        assert row['parent_us'] - sum(values) == row['parent_residual_us']
        entered = observation['actors_entered']
        surviving = entered - observation['dead_at_entry'] - observation['dead_after_status']
        assert surviving >= 0 and executions[0] == entered
        assert all(executions[j] == surviving for j in [1, 3, 4, 5, 6])
        assert executions[2] == (0 if label == 'legacy_paid' else surviving)
        assert observation['admission_offers'] <= executions[4]
        assert observation['release_results'] <= executions[6]
        assert digest(row['state_hash']) and isinstance(row['events'], list)
        assert re.fullmatch('(?:[0-9a-f]{2})*', row['commands_hex'])
        if okay:
            assert row['last_error'] == ''
            assert digest(row['packet_sha256']) if label != 'legacy_paid' else row['packet_sha256'] == ''
        else:
            assert 'command tick 1 does not match world tick 0' in row['last_error']
            assert row['packet_sha256'] == '' and executions == [0] * 7
            assert 'surfaces_expiry' in row['existing_last_step_us'] and 'command_order' not in row['existing_last_step_us']
        for j, value in enumerate(executions): lanes[j] += value
        for name in ['actors_entered', 'dead_at_entry', 'dead_after_status', 'missing_command', 'admission_offers', 'release_results']:
            branches[name] += observation[name]
        retained_events += [{'completed_tick': row['tick_after'], 'event': event}
                            for event in row['events'] if event.get('type') in EVENTS]
        orders['/'.join(expected_order)] += 1
    record = case.get('record')
    paid = None
    if record is not None:
        assert lanes == record['executions'] and dict(branches) == record['branches']
        assert retained_events == record['events']
        assert record['attempted_ticks'] == count
        assert rows[-1]['state_hash'] == case['final_state_hash']
        starts = [r for r in retained_events if r['event']['type'] == 'cast_started']
        refusals = [r for r in retained_events if r['event']['type'] == 'cast_refused']
        releases = [r for r in retained_events if r['event']['type'] == 'projectile_spawned']
        assert len(starts) == record['admissions'] and len(refusals) == record['refusals'] and len(releases) == record['releases']
        assert record['requested_casts'] == len(starts) + len(refusals)
        if label != 'legacy_paid': assert record['matter_paid'] == 600 * len(starts)
        assert record['resource_errors'] == []
        paid = {'requests': record['requested_casts'], 'admissions': len(starts), 'refusals': len(refusals),
                'releases': len(releases), 'matter_paid': record['matter_paid'], 'matter_expired': record['matter_expired'],
                'flight_seen': record['flight_seen'], 'ground_seen': record['ground_seen'], 'product_seen': record['product_seen']}
        if label in {'fire_default', 'fire_close', 'mantle'}:
            assert record['requested_casts'] == 4 and record['flight_seen'] and record['ground_seen']
            assert [r['tick'] for r in record['requests']] == [0, 120, 240, 360]
        if label == 'fire_close':
            assert len(starts) == len(releases) == 4 and not refusals and record['product_seen']
            assert all(r['pending_before'] == r['recovery_before'] == r['cooldown_before'] == 0 for r in record['requests'])
        if label == 'mantle': assert len(refusals) > 0
        if label == 'paid_status_death':
            assert branches['dead_after_status'] == 1 and record['death_cleared_pending']
            assert record['death_expired_matter'] == 600 and record['burn_damage'] > 0 and record['death_ground_damage'] == 0
        if label == 'campus_wall': assert record['wall_contact_seen'] and record['wall_skim_seen'] and record['wall_exit_seen']
        if label == 'paid_black_ice': assert record['product_321_seen'] and record['black_ice_slow_seen'] and not record['direct_chill_at_field_slow']
        if label == 'movement_chain': assert all(record[k] for k in ['sprint_seen', 'slide_seen', 'air_seen', 'air_dodge_seen', 'chain_seen'])
    log_files = []
    for suffix in ['-parse.log', '-parse.log.err', '.log', '.log.err']:
        log = BASE / ('runs/functional-' + label + '-b' + suffix)
        assert log.is_file()
        if suffix.endswith('.err'): assert log.stat().st_size == 0
        log_files.append({'path': log.relative_to(ROOT).as_posix(), 'bytes': log.stat().st_size, 'sha256': sha(log)})
        source_files.append((log, Path('runs') / (label + suffix)))
    assert f'selected_case={label} cases=1 checks={data["checks"]}' in (BASE / ('runs/functional-' + label + '-b.log')).read_text()
    source_files.append((path, Path('runs') / label / 'receipt.json'))
    reviews.append({'label': label, 'receipt_original': path.relative_to(ROOT).as_posix(), 'receipt_sha256': sha(path),
                    'checks': data['checks'], 'attempts': count, 'completed_ticks': 0 if label == 'wrong_tick' else count,
                    'wall_elapsed_ms': data['wall_elapsed_ms'], 'order_counts': dict(orders), 'executions': lanes,
                    'branches': dict(branches), 'paid': paid, 'logs': log_files})
    checks += data['checks']; attempts += count; completed += 0 if label == 'wrong_tick' else count; ended += 2

assert attempts == 2548 and completed == 2547 and ended == 26
for name in ['README.md', 'canonical-pins.json', 'manifest.json', 'source-transform.json',
             'compare-movement-cast.gd', 'observed_world.gd', 'functional_fixtures.gd', 'sim_world.before.gd']:
    source_files.append((BASE / name, Path('inputs') / name))
source_files.append((ROOT / '.godot/iteration-20261013/run-movement-cast-attribution.ps1', Path('inputs/run-movement-cast-attribution.ps1')))
for path in sorted((BASE / 'functional-timeout-a').iterdir()):
    assert path.is_file()
    source_files.append((path, Path('initial-timeout-a') / path.name))

OUT.mkdir()
archive_records = []
for source, relative in source_files:
    destination = OUT / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    assert not destination.exists()
    shutil.copyfile(source, destination)
    assert sha(source) == sha(destination)
    archive_records.append({'path': relative.as_posix(), 'original': source.relative_to(ROOT).as_posix(),
                            'bytes': destination.stat().st_size, 'sha256': sha(destination)})
review = {'schema': 'hex-movement-cast-functional-all-thirteen-review-v1', 'passed': True,
          'case_count': 13, 'checks': checks, 'attempts': attempts, 'completed_ticks': completed,
          'intentionally_rejected_prefixes': 1, 'ended_worlds': ended, 'remaining_worlds': 0,
          'identical_current_source_pins': len(common_pins), 'cases': reviews,
          'scope': 'Independent raw selected-case inventory, counts, serial/order, branch lanes, paid events, digest presence, current source pins and log recount. Pinned driver performs full strict packet equality on each successful Hex tick; the raw receipts retain its packet/state digests. All thirteen original cases are required and present. Clocks are functional containment witnesses, not accepted native cost samples or Bootstrap/render/physical-input/FPS evidence. Initial all-case timeout remains unqualified and preserved; no cause or completed coverage inferred.'}
for name, document in [('review.json', review)]:
    with (OUT / name).open('x', encoding='utf-8', newline='\n') as handle:
        json.dump(document, handle, indent=2); handle.write('\n')
    assert json.loads((OUT / name).read_text()) == document
shutil.copyfile(Path(__file__), OUT / 'review-functional-b.py')
(OUT / 'README.md').write_text(
    '# All thirteen functional attribution partitions\n\n'
    f'Passed: {checks:,} checks, 2,548 attempted boundaries and 2,547 completed ticks. '
    'The one declared wrong-tick prefix is compared as a failed mutation, without rollback or successful-packet assumptions. '
    'All 26 worlds ended collection, all 13 receipts use the same 329 current source pins, and all parser/run stderr files are empty.\n\n'
    'This archive contains exact helpers, raw receipts/logs, the independently checked aggregate and the preserved initial external-timeout inputs/logs. '
    'No profile contents or binaries are included. Functional elapsed values are not accepted timing samples. '
    'The separate timing companion has its own proof cadence and gates.\n', encoding='utf-8')
for name in ['review.json', 'review-functional-b.py', 'README.md']:
    path = OUT / name
    archive_records.append({'path': name, 'original': None, 'bytes': path.stat().st_size, 'sha256': sha(path)})
manifest = {'schema': 'hex-exact-evidence-archive-v1', 'records': archive_records,
            'payload_count': len(archive_records), 'payload_bytes': sum(r['bytes'] for r in archive_records),
            'runtime_build': 'p61-500be306a26a', 'profile_contents_included': False}
with (OUT / 'manifest.json').open('x', encoding='utf-8', newline='\n') as handle:
    json.dump(manifest, handle, indent=2); handle.write('\n')
print(json.dumps({'archive': OUT.relative_to(ROOT).as_posix(), 'cases': 13, 'checks': checks,
                  'attempts': attempts, 'completed': completed, 'review_sha256': sha(OUT / 'review.json'),
                  'manifest_sha256': sha(OUT / 'manifest.json'), 'payload_count': len(archive_records)}, indent=2))
