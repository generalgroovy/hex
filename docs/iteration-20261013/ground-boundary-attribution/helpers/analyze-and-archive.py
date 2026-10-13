"""Read-only input verification; writes one fresh owned evidence archive."""
from pathlib import Path
import hashlib, json, math, shutil, statistics

repo = Path(r'C:/Users/sende/Projects/hex')
base = repo / '.godot/iteration-20261013/ground-boundary'
dest = repo / 'docs/iteration-20261013/ground-boundary-attribution'
assert not dest.exists(), 'Archive must be fresh'
dest.mkdir()
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def source(p): return repo / p.removeprefix('res://')
def save(p, value):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(value, indent=2)+'\n', encoding='utf-8')
def copy(p, q):
    q.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(p,q)
    assert sha(p)==sha(q)
def stats(xs):
    a=sorted(xs)
    return dict(count=len(a),mean=statistics.mean(a),median=statistics.median(a),p95=a[math.ceil(len(a)*.95)-1],minimum=a[0],maximum=a[-1]) if a else dict(count=0)

docs={}; summaries={}; native=[]; images=0; measured=0; warmups=0; controls=0
for mode in ('forward','reverse'):
    path=base/f'runs/probe-{mode}-a/receipt.json'
    d=json.loads(path.read_text(encoding='utf-8'))
    assert d['passed'] and d['checks']==7188 and not d['errors'] and len(d['cases'])==22
    assert bool(d['reverse_order'])==(mode=='reverse')
    assert (base/f'runs/probe-{mode}-a.log.err').stat().st_size==0
    docs[mode]=d
    copy(path,dest/f'raw/{mode}.json')
    for extension in ('log','log.err'):
        copy(base/f'runs/probe-{mode}-a.{extension}',dest/f'raw/{mode}.{extension}')
    native.append(dict(mode=mode,receipt_sha256=sha(path),checks=d['checks'],cases=len(d['cases']),stderr_bytes=0))
    for c in d['cases']:
        assert c['exact_rgba_first_and_final']
        for role,img in c['images'].items():
            p=source(img['path']); assert sha(p)==img['sha256']
            copy(p,dest/f'images/{mode}/{p.name}'); images+=1
        assert len(c['rows'])==(32 if c['timed'] else 1)
        assert len(c['warmups'])==(4 if c['timed'] else 0)
        measured+=len(c['rows']) if c['timed'] else 0
        controls+=len(c['rows']) if not c['timed'] else 0
        warmups+=len(c['warmups'])
        for row in c['warmups']+c['rows']:
            assert row['actual_order']==(['observed','plain'] if ((row['index']%2==0)!=(mode=='reverse')) else ['plain','observed'])
            assert row['plain']['okay'] and row['observed']['okay'] and row['plain']['authority_unchanged'] and row['observed']['authority_unchanged']
            assert row['cache_after']['plain']==row['cache_after']['observed']
            a=row['observed']['attribution']
            assert a['mesh_us']+a['command_us']<=a['submit_us']
            assert a['mask_us']+a['points_us']+a['submit_us']<=a['outline_us']
            assert a['prefix_us']<=a['topology_us']+a['mask_us']
            assert a['bundle_us']+a['topology_us']+a['outline_us']<=row['observed']['ground_us']
        if c['timed']:
            summaries.setdefault(c['label'],[]).extend(dict(run=mode,**r) for r in c['rows'])

assert docs['forward']['source_hashes']==docs['reverse']['source_hashes']
assert images==88 and measured==768 and warmups==96 and controls==20
for path,expected in docs['forward']['source_hashes'].items():
    p=source(path); assert sha(p)==expected, f'Source drift: {p}'
    copy(p,dest/'sources'/path.removeprefix('res://'))
for name in ('manifest.json','README.md'):
    copy(base/name,dest/'prepared'/name)
copy(repo/'.godot/iteration-20261013/run-ground-boundary.ps1',dest/'helpers/run-ground-boundary.ps1')
copy(Path(__file__),dest/'helpers/analyze-and-archive.py')
fields=('bundle_us','topology_us','prefix_us','outline_us','mask_us','points_us','mesh_us','command_us','submit_us')
for label,rows in list(summaries.items()):
    source_case=next(c for c in docs['forward']['cases'] if c['label']==label)
    entry=dict(plain_us=stats([r['plain']['ground_us'] for r in rows]),
        observed_us=stats([r['observed']['ground_us'] for r in rows]),
        observer_delta_us=stats([r['observed']['ground_us']-r['plain']['ground_us'] for r in rows]),
        children={f:stats([r['observed']['attribution'][f] for r in rows]) for f in fields},
        coverage=source_case['coverage'],world_tick=source_case['world_tick'],matter_paid=source_case['matter_paid'],
        measured_new_meshes=sum(r['new_meshes'] for r in rows),measured_new_topologies=sum(r['new_topologies'] for r in rows),
        fallback_delta=sum(r['cache_after']['plain']['fallbacks']-r['cache_before']['plain']['fallbacks'] for r in rows),
        mask_hit_delta=sum(r['cache_after']['plain']['edge_mask_hits']-r['cache_before']['plain']['edge_mask_hits'] for r in rows),
        mesh_hit_delta=sum(r['cache_after']['plain']['hits']-r['cache_before']['plain']['hits'] for r in rows),
        counts={f:stats([r['observed']['attribution'][f] for r in rows]) for f in ('topology_calls','prefix_calls','outline_calls','mask_calls','points_calls','submit_calls')},
        by_order={},by_run={})
    for first in ('plain','observed'):
        subset=[r for r in rows if r['actual_order'][0]==first]
        entry['by_order'][first+'_first']=dict(plain_us=stats([r['plain']['ground_us'] for r in subset]),observed_us=stats([r['observed']['ground_us'] for r in subset]),delta_us=stats([r['observed']['ground_us']-r['plain']['ground_us'] for r in subset]))
    for run in docs:
        subset=[r for r in rows if r['run']==run]
        entry['by_run'][run]=dict(plain_us=stats([r['plain']['ground_us'] for r in subset]),observed_us=stats([r['observed']['ground_us'] for r in subset]))
    summaries[label]=entry
review=dict(schema='hex.ground.boundary-independent-review.v1',status='ATTRIBUTION_PASSED_NO_OPTIMIZATION',native=native,
    source_hashes_equal=True,current_source_hashes_rechecked=True,png_hashes_verified=images,measured_pairs=measured,warmup_pairs=warmups,pixel_control_pairs=controls,
    all_actual_order_checks=True,all_clock_containment_checks=True,all_cache_counter_checks=True,
    cases=summaries,
    limits=['Observed child clocks include wrapper/timer overhead; they are attribution estimates, not plain-cost decomposition.',
        'Prefix is nested inside topology or mask; mask/points/submit are nested inside outline; mesh/command are nested inside submit. Do not sum parents and children.',
        'Plain/observed share concrete frozen paid authority and persistent native resources; order effects remain recorded.',
        'Prepared world construction, packet/coverage/hash checks and image readback are outside submission clocks. Production bundle work stays inside.',
        'Offscreen native draw submission only; no Bootstrap, physical input, GPU/present, whole-frame, foreground or FPS qualification.',
        'No runtime optimization is implemented or justified solely by these observer samples.'])
save(dest/'review.json',review)
manifest=[]
for p in sorted(dest.rglob('*')):
    if p.is_file(): manifest.append(dict(path=p.relative_to(dest).as_posix(),bytes=p.stat().st_size,sha256=sha(p)))
save(dest/'archive-manifest.json',dict(schema='hex.ground.boundary-archive.v1',files=manifest,total_bytes=sum(x['bytes'] for x in manifest)))
for label,x in summaries.items():
    print(label, 'plain/observed/delta',*[round(x[k]['mean'],3) for k in ('plain_us','observed_us','observer_delta_us')],
        'bundle/topology/outline/prefix/mask/points/mesh/command',*[round(x['children'][k]['mean'],3) for k in fields[:-1]],
        'orderdelta',*[round(y['delta_us']['mean'],3) for y in x['by_order'].values()],
        'builds',x['measured_new_meshes'],x['measured_new_topologies'])
print('ARCHIVE',len(manifest),sum(x['bytes'] for x in manifest),sha(dest/'review.json'))
